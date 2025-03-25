//===- SSRReassociatePass.cpp - Reassociate Fast FP insts and move SSR push/pop intrinsics ------------------===//
//
// ???
//
//===----------------------------------------------------------------------===//
//
// FIXME: The reassociation should really be done by the ReassociatePass but it
// for some reason does no reassociate fast FP insts? (maybe because it expects
// a normal out of order processor to vectorize anyway.)
// The reassociation is always done in full an can thus be quite slow when the 
// dependency trees are large. Might want to introduce a max height or sth 
// like that.
// Bubbling the Pushs/Pops might be better done in the pre RA ssr expand pass
// because we have more control over where they land there.
// This is not really meant to be used yet, so debug msg's are output by errs().
//
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/CodeGen/RuntimeLibcalls.h"
#include "llvm/CodeGen/TargetLowering.h"
#include "llvm/CodeGen/TargetPassConfig.h"
#include "llvm/CodeGen/TargetSubtargetInfo.h"
#include "llvm/CodeGen/ValueTypes.h"
#include "llvm/IR/Attributes.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/Constant.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/DataLayout.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/Instruction.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Type.h"
#include "llvm/IR/User.h"
#include "llvm/IR/Value.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/IntrinsicsRISCV.h"
#include "llvm/InitializePasses.h"
#include "llvm/Pass.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Target/TargetMachine.h"
#include <algorithm>
#include <vector>
#include <limits>

using namespace llvm;

#define DEBUG_TYPE "ssr-reassociate"

namespace llvm {
  cl::opt<bool> AggressiveReassociate(
    "ssr-aggressive-reassociation", 
    cl::init(false), 
    cl::desc("Reassociate aggressively and move ssr push/pop out of the way. In particular: reassociate also fast fp-ops")
  );
  
  cl::opt<int> BubbleStreams(
    "ssr-bubble-streams", 
    cl::init(0), 
    cl::desc(
      "Try to schedule pops earlier and pushs later making \"windows\" holding the given nr. of instructions given." 
      "This gives more freedom to the scheduler in unrolled loops. If window is too large then there are not enough registers which leads to unnecessary spills"
      "0 means off (default), negative number means max window size")
  );
}

namespace {

  class SSRReassociate: public FunctionPass {
    const TargetLowering *TLI = nullptr;

  public:
    static char ID; // Pass identification, replacement for typeid

    SSRReassociate() : FunctionPass(ID) {
      initializeSSRReassociatePass(*PassRegistry::getPassRegistry());
    }

    bool runOnFunction(Function &F) override;

  private:
    bool runOnBB(BasicBlock &BB);
  };

} // end anonymous namespace

bool SSRReassociate::runOnFunction(Function &F) {
  bool Modified = false;

  LLVM_DEBUG(dbgs()<<"SSR Reassociate Pass running on: "<<F.getNameOrAsOperand()<<"\n");
  if (BubbleStreams) LLVM_DEBUG(dbgs()<<"bubbling streams by "<<BubbleStreams<<"\n");
  if (AggressiveReassociate) LLVM_DEBUG(dbgs()<<"aggressive reassociate enabled \n");

  for (auto &BB : F) Modified |= runOnBB(BB);

  return Modified;
}

static bool isPushPop(Instruction &I) {
  return isa<IntrinsicInst>(I) && 
    (cast<IntrinsicInst>(I).getIntrinsicID() == Intrinsic::riscv_ssr_push
     || cast<IntrinsicInst>(I).getIntrinsicID() == Intrinsic::riscv_ssr_push);
}

//put pops at top and pushs at bottom
static bool BubbleSSRIntrinsics(BasicBlock::iterator begin, BasicBlock::iterator end) {
  bool Modified = false;
  auto II = begin;
  auto LastInsertedPopSucc = begin;
  auto LastInsertedPush = std::prev(end);
  auto FirstInsertedPush = end;
  while (II != end && II != FirstInsertedPush) {
    auto NII = std::next(II);
    if (isa<IntrinsicInst>(*II)) {
      auto &Intr = cast<IntrinsicInst>(*II);
      if (Intr.getIntrinsicID() == Intrinsic::riscv_ssr_pop) {
        Intr.moveBefore(&*LastInsertedPopSucc);
        LastInsertedPopSucc = std::next(Intr.getIterator());
        Modified = true;
      } else if (Intr.getIntrinsicID() == Intrinsic::riscv_ssr_push) {
        Intr.moveAfter(&*LastInsertedPush);
        LastInsertedPush = Intr.getIterator();
        Modified = true;
        if (FirstInsertedPush == end) FirstInsertedPush = LastInsertedPush;
      }
    }
    II = NII;
  }
  return Modified;
}

//genetates the window that the above function uses to bubble
//windows depend are constrained by bubble_count and by ssr enable/disable calls
static bool BubbleSSRIntrinsics(BasicBlock &BB, unsigned bubble_count) {
  bool Modified = false;
  auto start = BB.getFirstInsertionPt();
  auto finish = start;
  while (start != BB.end()) {
    //increment finish until it hits an ssr enable / disable
    unsigned w = 0; // or until we have bubble_count many instructions (non push/pop instructions) inside the window
    while (finish != BB.end() && finish != BB.getTerminator()->getIterator() && w < bubble_count) {
      assert(finish != BB.end());
      if (isa<IntrinsicInst>(*finish)) {
        auto id = cast<IntrinsicInst>(*finish).getIntrinsicID();
        if (id == Intrinsic::riscv_ssr_enable || id == Intrinsic::riscv_ssr_disable) {
          break;
        }
      }
      if (!isPushPop(*finish) && !finish->isDebugOrPseudoInst()) w++;
      finish++;
    }

    Modified |= BubbleSSRIntrinsics(start, finish);

    if (finish != BB.getTerminator()->getIterator() && finish != BB.end()) finish++; //move past ssr en/dis
    else break; // we are done
    start = finish;
  }

  return Modified;
}

//put pops and pushs as close to their def/use as possible
static bool BubbleSSRIntrinsicsBack(BasicBlock &BB) {
  bool Modified = false;
  auto II = BB.getFirstInsertionPt();
  DenseSet<const Instruction *> vis;
  while (II != BB.end()) {
    auto NII = std::next(II);
    if (vis.find(&*II) != vis.end()) {
      II = NII;
      continue;
    }
    vis.insert(&*II);
    if (isa<IntrinsicInst>(*II)) {
      auto &Intr = cast<IntrinsicInst>(*II);
      if (Intr.getIntrinsicID() == Intrinsic::riscv_ssr_pop) {
        Instruction *UU = nullptr;
        for (User *U : Intr.users()) {
          if (isa<Instruction>(U) && !UU) UU = cast<Instruction>(U);
          else UU = nullptr;
        }
        if (UU) {
          Intr.moveBefore(UU);
          Modified = true;
        }
      } else if (Intr.getIntrinsicID() == Intrinsic::riscv_ssr_push) {
        if (Instruction *D = dyn_cast<Instruction>(Intr.getOperand(1))) {
          Intr.moveAfter(D);
          Modified = true;
        }
      }
    }
    II = NII;
  }
  return Modified;
}

static bool isAssociative(const Value &V) {
  if (!isa<Instruction>(V)) return false;
  const auto &I = cast<Instruction>(V);
  if (I.getType()->isIntegerTy(1u)) return false; //ignore bools
  if(I.isAssociative()) return true;
  if (isa<FPMathOperator>(I) && I.hasAllowReassoc()) return true;
  // if ((I.getType()->isFloatingPointTy() && I.isFast())){ //https://gcc.gnu.org/wiki/FloatingPointMath
  //   switch (I.getOpcode())
  //   {
  //   case Instruction::BinaryOps::FAdd:
  //   case Instruction::BinaryOps::FMul:
  //     return true;  
  //   default:
  //     return false;
  //   }
  // }
  return false;
}

// a bit redundant, but might allow to be extended
static bool isBinop(const Value &I) {
  return isa<BinaryOperator>(I);
}

static unsigned getAndUpdateHeight(const Value &V, DenseMap<const Instruction *, unsigned> &heights); //bc mutual recursion

//assumes children have the correct height, updates the height of I accordingly
static unsigned updateHeightFromChildren(const BinaryOperator &I, DenseMap<const Instruction *, unsigned> &heights) {
  unsigned this_height = 1u + std::max(
    getAndUpdateHeight(*I.getOperand(0), heights),
    getAndUpdateHeight(*I.getOperand(1), heights)
  );
  auto p = heights.insert(std::make_pair(&I, this_height));
  if (!p.second) p.first->getSecond() = this_height; //update value
  return this_height;
}

//updates the height of children recursively then uses updateHeightFromChildren
static unsigned getAndUpdateHeight(const Value &V, DenseMap<const Instruction *, unsigned> &heights) {
  if (!isa<Instruction>(V)) return 0;
  const Instruction &I = cast<Instruction>(V);
  if (!isBinop(I)) return 0;
  auto d = heights.find(&I);
  if (d != heights.end()) return d->second; //if height is available it is correct
  return updateHeightFromChildren(cast<BinaryOperator>(I), heights);
}

//moves OP and all users that are between OP and Point to after Point in the same order
static void moveAfterWithAllUsers(BinaryOperator &OP, Instruction &Point) {
  assert(OP.getParent() == Point.getParent());
  auto II = std::next(Point.getIterator().getReverse()); //start right before point
  auto rend = OP.getIterator().getReverse(); //end just after OP
  SmallPtrSet<const Instruction *, 4u> users; //for faster lookup
  for (auto *U : OP.users()) {
    if (auto *I = dyn_cast<Instruction>(U)) {
      users.insert(I);
    }
  }
  while (II != OP.getParent()->rend() && II != rend) {
    auto NII = std::next(II);
    for (auto *U : II->users()){
      if (auto *I = dyn_cast<Instruction>(U))
        users.insert(I);
    }
    if (users.contains(&*II)) {
      II->moveAfter(&Point);
    }
    II = NII;
    assert(II != OP.getParent()->rend());
  }
  OP.moveAfter(&Point);
}

//we can only rotate if B only depends directly on A without any other def-use path between them
static bool canRotate(const Instruction &A, const Instruction &B) {
  SmallPtrSet<const Instruction *, 4u> users;
  for (auto *U : A.users()) {
    if (auto *I = dyn_cast<Instruction>(U)) users.insert(I);
  }
  auto II = A.getIterator();
  for (; II != A.getParent()->end() && &*II != &B; II++) {
    if (users.contains(&*II)) {
      for (auto *U : II->users()) {
        if (auto *I = dyn_cast<Instruction>(U)) {
          if (I == &B) return false; //additional def-use path
          users.insert(I);
        }
      }
      if (!isa<UnaryInstruction>(*II) && !isa<BinaryOperator>(*II) && !isa<GetElementPtrInst>(*II) && !isa<SelectInst>(*II)) 
        return false; //if user (which will need to be moved is not a "simple" instrucion ==> then cannot do it)
    }
  }
  return II != A.getParent()->end() && &*II == &B; //return true if II now points to B
}

//single rotation counter-clockwise (trees are with root at bottom because thats how they are in LLVM IR)
static BinaryOperator *rotateCC(BinaryOperator &L, BinaryOperator &I, DenseMap<const Instruction *, unsigned> &heights) {
  assert(isAssociative(L) && isAssociative(I) && I.getOperand(0) == &L);
  I.setOperand(0, L.getOperand(1));
  I.replaceAllUsesWith(&L);
  L.setOperand(1, &I);
  L.dropDroppableUses();
  moveAfterWithAllUsers(L, I);
  updateHeightFromChildren(I, heights);
  updateHeightFromChildren(L, heights);
  return &L;
}

//single rotation clock-wise
static BinaryOperator *rotateCW(BinaryOperator &R, BinaryOperator &I, DenseMap<const Instruction *, unsigned> &heights) {
  assert(isAssociative(R) && isAssociative(I) && I.getOperand(1) == &R);
  I.setOperand(1, R.getOperand(0));
  I.replaceAllUsesWith(&R);
  R.setOperand(0, &I);
  R.dropDroppableUses(); //remove debug insts that would otherwise not be dominated by R anymore
  moveAfterWithAllUsers(R, I);
  updateHeightFromChildren(I, heights);
  updateHeightFromChildren(R, heights);
  assert(cast<BinaryOperator>(*I.user_begin()) == &R && std::next(I.user_begin()) == I.user_end() && "the only user of I is R");
  return &R;
}

//try to rotate or double rotate if applicable (see AVL trees)
static BinaryOperator *tryRotateL(Value &Left, Value &Root, DenseMap<const Instruction *, unsigned> &heights) {
  if (isBinop(Left) && isBinop(Root) && isAssociative(Left) && isAssociative(Root)) {
    BinaryOperator &L = cast<BinaryOperator>(Left);
    BinaryOperator &I = cast<BinaryOperator>(Root);
    const unsigned opcode = I.getOpcode();
    if (L.getOpcode() != opcode || L.getParent() != I.getParent()) return nullptr; //cannot do anything
    unsigned lh = getAndUpdateHeight(L, heights);
    if (lh <= 1u) return nullptr; //nothing to do
    auto &L_RChild = *L.getOperand(1);
    if (isBinop(L_RChild) && isAssociative(L_RChild) 
        && getAndUpdateHeight(L_RChild, heights) + 1u == lh) {
      auto &LRC = cast<BinaryOperator>(L_RChild);
      if (LRC.getOpcode() == opcode && LRC.getParent() == I.getParent() && canRotate(LRC, L) && canRotate(L, I)) {
        auto &newL = *rotateCW(LRC, L, heights);
        if (canRotate(newL, I)) return rotateCC(newL, I, heights);
        else return nullptr;
      }
    }
    if (canRotate(L, I)) return rotateCC(L, I, heights);
  }
  return nullptr;
}

//try to rotate or double rotate if applicable (see AVL trees)
static BinaryOperator *tryRotateR(Value &Right, Value &Root, DenseMap<const Instruction *, unsigned> &heights) {
  if (isBinop(Right) && isBinop(Root) && isAssociative(Right) && isAssociative(Root)) {
    BinaryOperator &R = cast<BinaryOperator>(Right);
    BinaryOperator &I = cast<BinaryOperator>(Root);
    const unsigned opcode = I.getOpcode();
    if (R.getOpcode() != opcode || R.getParent() != I.getParent()) return nullptr; //cannot do anything
    unsigned rh = getAndUpdateHeight(R, heights);
    if (rh <= 1u) return nullptr; //nothing to do
    auto &R_LChild = *R.getOperand(0);
    if (isBinop(R_LChild) && isAssociative(R_LChild)
      && getAndUpdateHeight(R_LChild, heights) + 1u == rh) {
        auto &RLC = cast<BinaryOperator>(R_LChild);
        if (RLC.getOpcode() == opcode && RLC.getParent() == I.getParent() && canRotate(RLC, R) && canRotate(R, I)) {
          auto &newR = *rotateCC(RLC, R, heights);
          if (canRotate(newR, I)) return rotateCW(newR, I, heights);
          else return nullptr;
        }
      }
    if (canRotate(R, I)) return rotateCW(R, I, heights);
  }
  return nullptr;
}

//needed to check whether we are actually dealing with a tree
static bool subGraphsIntersect(const Value &X, const Value &Y) {
  if (!isBinop(X) || !isBinop(Y)) return false;
  const auto &A = cast<BinaryOperator>(X);
  const auto &B = cast<BinaryOperator>(Y);
  DenseSet<const BinaryOperator *> seen;
  std::deque<const BinaryOperator *> q;
  const BasicBlock *BB = A.getParent();
  q.push_back(&A);
  while (!q.empty()) {
    const auto *I = q.front(); q.pop_front();
    seen.insert(I);
    if (auto *X = dyn_cast<BinaryOperator>(I->getOperand(0))) {
      if (X && X->getParent() == BB) q.push_back(X);
    }
    if (auto *X = dyn_cast<BinaryOperator>(I->getOperand(1))) {
      if (X && X->getParent() == BB) q.push_back(X);
    }
  }
  assert(q.empty());
  q.push_back(&B);
  while (!q.empty()) {
    const auto *I = q.front(); q.pop_front();
    if (seen.contains(I)) return true;
    if (auto *X = dyn_cast<BinaryOperator>(I->getOperand(0))) {
      if (X && X->getParent() == BB) q.push_back(X);
    }
    if (auto *X = dyn_cast<BinaryOperator>(I->getOperand(1))) {
      if (X && X->getParent() == BB) q.push_back(X);
    }
  }
  return false;
}

//print trees for debugging purposes
static void printDep(Value &I, unsigned lvl, DenseMap<const Instruction *, unsigned> &heights, DenseSet<const Value *> &vis) {
  if (vis.find(&I) != vis.end()) return;
  vis.insert(&I);
  for (unsigned i = 0; i < lvl; i++) errs()<<"| \t";
  unsigned h = 0;
  if (isa<Instruction>(I)) {
    auto p = heights.find(&cast<Instruction>(I));
    if (p != heights.end()) h = p->second;
  }
  errs()<<" h = "<<h<<" ";
  errs()<<I<<"\n";
  if (isBinop(I) && isAssociative(I)){
    auto &X = cast<BinaryOperator>(I);
    for (unsigned i = 0; i < X.getNumOperands(); i++) {
      auto *V = X.getOperand(i);
      if (V) printDep(*V, lvl+1, heights, vis);
    }
  }
}

//try to reassociate tree rooted in Inst (if it is a tree!)
//insts might be moved past Inst and Inst might not be the root anymore afterwards
static bool Reassociate(Value &Inst, DenseMap<const Instruction *, unsigned> &heights) {
  bool Modified = false;
  if (isBinop(Inst) && isAssociative(Inst)) {
    BinaryOperator *I = cast<BinaryOperator>(&Inst);
    unsigned h = updateHeightFromChildren(*I, heights);
    if (h <= 2) return false; //nothing todo
    if (subGraphsIntersect(*I->getOperand(0), *I->getOperand(1))) {
      return false; //Inst is not root of a tree! cannot optimize!
    }
    bool better = true;
    int lminusr = std::numeric_limits<int>::max();
    DenseSet<const BinaryOperator *> vis;
    do {
      if (vis.contains(I)) break;
      vis.insert(I); 
      int new_lminusr = 
        (int)getAndUpdateHeight(*I->getOperand(0), heights) 
        - (int)getAndUpdateHeight(*I->getOperand(1), heights);
      better = std::abs(lminusr) > std::abs(new_lminusr);
      lminusr = new_lminusr;
      BinaryOperator *NewRoot = nullptr;
      if (lminusr >= 2) {
        NewRoot = tryRotateL(*I->getOperand(0), *I, heights); //try to fix at this height
      } else if (lminusr <= -2) {
        NewRoot = tryRotateR(*I->getOperand(1), *I, heights); //try to fix at this height
      }
      if (NewRoot) {
        I = NewRoot;
        Modified = true;
        better = true;
      } else {
        better = false; //defenitely do not repeat if we haven't changed anything anymore
      }
    } while (better);

    bool improved_left = Reassociate(*I->getOperand(0), heights); //fix left subtree
    bool improved_right = Reassociate(*I->getOperand(1), heights); //fix right subtree
    Modified = Modified || improved_left || improved_right;

    updateHeightFromChildren(*I, heights);
  }
  return Modified;
}

//try to reassociate all insts in BB
static bool Reassociate(BasicBlock &BB) {
  bool Modified = false;

  DenseMap<const Instruction *, unsigned> heights;

  auto RI = BB.rbegin();
  while (RI != BB.rend()) {
    if (heights.find(&*RI) == heights.end()) {//only reassociate if this was not part of any tree already
      Modified |= Reassociate(*RI, heights);
    }
    RI++; //yes, this means we miss some instructions, but those are optimized already anyway
  }

  // if (Modified) {
  //   errs()<<"Reassociate in BB: "<<Modified<<"\n";
  //   DenseSet<const Value *> vis;
  //   for (auto RI = BB.rbegin(); RI != BB.rend(); RI++) {
  //     printDep(*RI, 0, heights, vis);
  //   }
  // }

  return Modified;
}

//reassociate and then bubble
bool SSRReassociate::runOnBB(BasicBlock &BB) {
  bool Modified = false;

  if (AggressiveReassociate) {
    Modified |= BubbleSSRIntrinsics(BB, std::numeric_limits<unsigned>::max()); //move pop/pushs out of the way
    Modified |= Reassociate(BB);
    if (BubbleStreams >= 0) Modified |= BubbleSSRIntrinsicsBack(BB); //move them back if needed
  }

  if (BubbleStreams > 0) {
    Modified |= BubbleSSRIntrinsics(BB, (unsigned)BubbleStreams); //bubble to form windows
  }

  return Modified;
}


char SSRReassociate::ID = 0;

INITIALIZE_PASS(SSRReassociate, DEBUG_TYPE, "SSR Reassociate Pass", false, false)

FunctionPass *llvm::createSSRReassociatePass() { return new SSRReassociate(); }
