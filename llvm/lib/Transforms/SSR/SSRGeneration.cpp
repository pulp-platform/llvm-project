//===-- SSRGeneration.cpp - Generate SSR --------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/Transforms/SSR/SSRGeneration.h"
#include "llvm/InitializePasses.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Target/TargetMachine.h"

#include "llvm/IR/Instruction.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/InstrTypes.h"
#include "llvm/IR/IRBuilder.h"

#include "llvm/Transforms/Utils/BasicBlockUtils.h"

#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ScalarEvolutionExpressions.h"
#include "llvm/Analysis/AffineAccessAnalysis.h"
#include "llvm/Analysis/MemorySSA.h"
#include "llvm/Analysis/MemorySSAUpdater.h"
#include "llvm/Transforms/Utils/ScalarEvolutionExpander.h"

#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/FormatVariadic.h"

#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/IntrinsicsRISCV.h"
#include "llvm/IR/InlineAsm.h"

#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/TinyPtrVector.h"
#include "llvm/ADT/ilist.h"

#include <llvm/IR/DebugLoc.h>
#include <llvm/IR/DebugInfoMetadata.h>

#include <array>
#include <vector>
#include <map>
#include <utility>
#include <algorithm>
#include <queue>
#include <limits>

#define DEBUG_TYPE "ssr"

#define NUM_SSR 3U 
#define SSR_MAX_DIM 4U

//both are inclusive! 
#define SSR_SCRATCHPAD_BEGIN 0x100000
#define SSR_SCRATCHPAD_END 0x120000

//current state of hw: only allow doubles
#define CHECK_TYPE(T, I) (T == Type::getDoubleTy(I->getParent()->getContext()))

//for gain estimation
#define EST_LOOP_TC 25
#define EST_MUL_COST 3
#define EST_MEMOP_COST 2

using namespace llvm;

namespace llvm {

cl::opt<bool> InferSSR(
  "infer-ssr", 
  cl::init(false), 
  cl::desc("Enable inference of SSR streams.")
);

cl::opt<bool> SSRNoIntersectCheck(
  "ssr-no-intersect-check", 
  cl::init(false), 
  cl::desc("Do not generate intersection checks (unsafe). Use `restrict` key-word instead if possible.")
);

cl::opt<bool> SSRNoTCDMCheck(
  "ssr-no-tcdm-check", 
  cl::init(false),
  cl::desc("Assume all data of inferred streams is inside TCDM.")
);

cl::opt<bool> SSRNoBoundCheck(
  "ssr-no-bound-check", 
  cl::init(false),
  cl::desc("Do not generate checks that make sure the inferred stream's access is executed at least once.")
);

cl::opt<bool> SSRConflictFreeOnly(
  "ssr-conflict-free-only", 
  cl::init(false),
  cl::desc("Only infer streams if they have no conflicts with other memory accesses.")
);

cl::opt<bool> SSRNoInline(
  "ssr-no-inline", 
  cl::init(false),
  cl::desc("prevent functions that contain SSR streams from being inlined.")
);

cl::opt<bool> SSRBarrier(
  "ssr-barrier",
  cl::init(false),
  cl::desc("Enable the insertion of a spinning loop that waits for the stream to be done before it is disabled.")
);

cl::opt<bool> SSRVerbose(
  "ssr-verbose",
  cl::init(false),
  cl::desc("Write information about inferred streams to stderr.")
);

} //end of namespace llvm


static constexpr char SSRFnAttr[] = "SSR"; //used to tag functions that contain SSR streams

static constexpr Intrinsic::ID riscSSRIntrinsics[] = {
  Intrinsic::RISCVIntrinsics::riscv_ssr_barrier, 
  Intrinsic::RISCVIntrinsics::riscv_ssr_disable,
  Intrinsic::RISCVIntrinsics::riscv_ssr_enable,
  Intrinsic::RISCVIntrinsics::riscv_ssr_setup_repetition,
  Intrinsic::RISCVIntrinsics::riscv_ssr_pop,
  Intrinsic::RISCVIntrinsics::riscv_ssr_push, 
  Intrinsic::RISCVIntrinsics::riscv_ssr_read,
  Intrinsic::RISCVIntrinsics::riscv_ssr_read_imm,
  Intrinsic::RISCVIntrinsics::riscv_ssr_write,
  Intrinsic::RISCVIntrinsics::riscv_ssr_write_imm,
  Intrinsic::RISCVIntrinsics::riscv_ssr_setup_1d_r,
  Intrinsic::RISCVIntrinsics::riscv_ssr_setup_1d_w,
  Intrinsic::RISCVIntrinsics::riscv_ssr_setup_bound_stride_1d,
  Intrinsic::RISCVIntrinsics::riscv_ssr_setup_bound_stride_2d,
  Intrinsic::RISCVIntrinsics::riscv_ssr_setup_bound_stride_3d,
  Intrinsic::RISCVIntrinsics::riscv_ssr_setup_bound_stride_4d,
};


namespace {

template<typename NodeT>
struct ConflictTree {
  void insertNode(const NodeT *Node, unsigned value, const NodeT *Parent) {
    assert((values.find(Node) == values.end() || children.find(Node) == children.end()) && "not yet inserted");
    values.insert(std::make_pair(Node, value));
    children.insert(std::make_pair(Node, std::move(std::vector<const NodeT *>())));
    if (!Parent) { //this is root
      assert(!Root && "Parent = nullptr, but root already exists");
      Root = Node;
    } else {
      auto p = children.find(Parent);
      assert(p != children.end() && "parent cannot be found");
      p->getSecond().push_back(Node);
    }
  }

  //picks nodes in the tree such that their combined value (conmbineFunc, needs to be associative & commutative) is the highest possible
  //prioritizes parent over children
  std::vector<const NodeT *> findBest(const std::function<unsigned(unsigned, unsigned)> &combineFunc) {
    std::vector<const NodeT *> res;
    if (!Root) return res;
    findBest(Root, combineFunc, res);
    return res;
  }

private:
  unsigned findBest(const NodeT *N, const std::function<unsigned(unsigned, unsigned)> &combineFunc, std::vector<const NodeT *> &res) {
    unsigned size = res.size();
    unsigned val = 0u;
    auto &chs = children.find(N)->getSecond();
    if (!chs.empty()) {
      for (const NodeT *C : chs) val = combineFunc(val, findBest(C, combineFunc, res));
    }
    unsigned nval = values.find(N)->second;
    if (val > nval) {
      return val;
    } else {
      while (res.size() > size) res.pop_back();
      res.push_back(N);
      return nval;
    }
  }

  DenseMap<const NodeT *, unsigned> values;
  DenseMap<const NodeT *, std::vector<const NodeT *>> children;
  const NodeT *Root = nullptr;
};

// copy Phi-nodes from predecessor Basic Block (BB)
void copyPHIsFromPred(BasicBlock *BB){
  BasicBlock *Pred = nullptr;
  for (BasicBlock *B : predecessors(BB)) {
    if (!Pred) Pred = B;
    assert(Pred == B && "BB has only one predecessor");
  }
  assert(Pred && "BB has a Predecessor");
  for (Instruction &I : *Pred){
    if (auto *Phi = dyn_cast<PHINode>(&I)){
      PHINode *PhiC = PHINode::Create(Phi->getType(), 1u, Twine(Phi->getName()).concat(".copy"), BB->getFirstNonPHI());
      //Phi->replaceAllUsesWith(PhiC);
      Phi->replaceUsesOutsideBlock(PhiC, Pred); //all users outside of Pred are now using PhiC
      PhiC->addIncoming(Phi, Pred);
    }
  }
}

///splits block, redirects all predecessor to first half of split, copies phi's
std::pair<BasicBlock *, BasicBlock *> splitAt(Instruction *X, const Twine &name){
  assert(!isa<PHINode>(X) && "should not split at phi");
  BasicBlock *Two = X->getParent();
  BasicBlock *One = BasicBlock::Create(Two->getContext(), name, Two->getParent(), Two);
  Instruction *BR = BranchInst::Create(Two, One);
  //DTU.applyUpdates(cfg::Update<BasicBlock *>(cfg::UpdateKind::Insert, One, Two));
  BasicBlock::iterator it = Two->begin();
  while (it != X->getIterator()) {
    BasicBlock::iterator it_next = std::next(it);
    it->removeFromParent();
    it->insertBefore(BR);
    it = it_next;
  }
  //BasicBlock *One = splitBlockBefore(Two, X, &DTU, nullptr, nullptr, name);
  std::vector<Instruction *> toChange;
  for (auto *BB : predecessors(Two)){
    if (BB == One) continue;
    Instruction *T = BB->getTerminator();
    for (unsigned i = 0; i < T->getNumOperands(); i++){
      Value *OP = T->getOperand(i);
      if (dyn_cast<BasicBlock>(OP) == Two){
        toChange.push_back(T);
      }
    }
  }
  for (Instruction *T : toChange) {
    for (unsigned i = 0; i < T->getNumOperands(); i++){
      Value *OP = T->getOperand(i);
      if (dyn_cast<BasicBlock>(OP) == Two){
        T->setOperand(i, One); //if an operand of the terminator of a predecessor of Two points to Two it should now point to One
        /*cfg::Update<BasicBlock *> upd[]{
          cfg::Update<BasicBlock *>(cfg::UpdateKind::Insert, T->getParent(), One),
          cfg::Update<BasicBlock *>(cfg::UpdateKind::Delete, T->getParent(), Two),
        };
        DTU.applyUpdates(upd);*/
      }
    }
  }
  return std::make_pair(One, Two);
}

///clones code from BeginWith up to EndBefore
///assumes all cf-paths from begin lead to end (or return)
///assumes there is a phi node for each value defined in the region that will be cloned in the block of EndBefore that is live after EndBefore
///returns the branch that splits region from coloned region and the pair of branches that jump to EndBefore at the end
std::pair<BranchInst *, std::pair<BranchInst *, BranchInst *>> cloneRegion(Instruction *BeginWith, Instruction *EndBefore){
  LLVM_DEBUG(dbgs()<<"cloning from "<<*BeginWith<<" up to "<<*EndBefore<<"\n");

  auto p = splitAt(BeginWith, "split.before");
  BasicBlock *Head = p.first;
  BasicBlock *Begin = p.second;

  p = splitAt(EndBefore, "fuse.prep");
  BranchInst *BRFuse = cast<BranchInst>(p.first->getTerminator());
  BasicBlock *End = p.second;
  copyPHIsFromPred(End); //copy Phi's from Fuse to End

  std::deque<BasicBlock *> q; //bfs queue
  q.push_back(Begin);
  DenseSet<BasicBlock *> vis; //bfs visited set
  DenseMap<Value *, Value *> clones; //value in orig -> value in clone (INV: orig and clone are of same class)
  std::vector<std::pair<unsigned, Instruction *>> operandsCleanup; //store operands that reference instructions that are not cloned yet
  
  while (!q.empty()){
    BasicBlock *C = q.front(); q.pop_front();
    if (C == End || vis.find(C) != vis.end()) continue;
    vis.insert(C);
    BasicBlock *Cc = BasicBlock::Create(C->getContext(), Twine(C->getName()).concat(".clone"), C->getParent(), C);
    clones.insert(std::make_pair(C, Cc)); //BasicBlock <: Value, needed for branches
    IRBuilder<> builder(Cc);
    for (Instruction &I : *C){
      Instruction *Ic = I.clone();
      assert(Ic->use_empty() && "no uses of clone");
      if (I.getType()->isVoidTy() || I.getType()->isLabelTy()) Ic = builder.Insert(Ic); //insert without name
      else Ic = builder.Insert(Ic, Twine(I.getName()).concat(".clone"));
      for (unsigned i = 0; i < Ic->getNumOperands(); i++){
        auto A = clones.find(Ic->getOperand(i));
        if (A != clones.end()){
          Ic->setOperand(i, A->second); //this also updates uses of A->second
          //check users update in A->second
          bool userUpdate = false; for (User *U : A->second->users()) {userUpdate = userUpdate || U == Ic; } assert(userUpdate && "user is updated on setOperand");
          //if (isa<BasicBlock>(A->first)) DTU.applyUpdates(cfg::Update<BasicBlock *>(cfg::UpdateKind::Insert, Cc, cast<BasicBlock>(A->second)));
        }else{
          operandsCleanup.push_back(std::make_pair(i, Ic));
        }
      }
      clones.insert(std::make_pair(&I, Ic)); //add Ic as clone of I
    }
    auto succs = successors(C);
    for (auto S = succs.begin(); S != succs.end(); ++S) {
      q.push_back(*S);
    }
  }
  //operandCleanup
  for (const auto &p : operandsCleanup){ //p.first = index of operand that needs to be changed to clone in p.second
    auto A = clones.find(p.second->getOperand(p.first));
    if (A != clones.end()){
      p.second->setOperand(p.first, A->second);
      //if (isa<BasicBlock>(A->first)) DTU.applyUpdates(cfg::Update<BasicBlock *>(cfg::UpdateKind::Insert, p.second->getParent(), cast<BasicBlock>(A->second)));
    }//else did not find ==> was defined before region 
  }
  //incoming blocks of phi nodes are not operands ==> handle specially
  for (const auto &p : clones){ //all clones of phi-nodes appear in here
    if (auto *Phi = dyn_cast<PHINode>(p.second)){
      for (auto B = Phi->block_begin(); B != Phi->block_end(); ++B){
        const auto &c = clones.find(*B);
        if (c != clones.end()){
          *B = cast<BasicBlock>(c->second); //overwrite with clone of block if it was cloned
        }
      }
    }
  }
  //change terminator of Head to be CondBr with TakeOrig as cond
  BranchInst *HeadBr = cast<BranchInst>(Head->getTerminator()); //always BranchInst because of splitBlockBefore
  BasicBlock *HeadSucc = HeadBr->getSuccessor(0);
  BasicBlock *HeadSuccClone = cast<BasicBlock>(clones.find(HeadSucc)->second);
  HeadBr->eraseFromParent();
  HeadBr = BranchInst::Create(
    HeadSucc, //branch-cond = true -> go to non-clone (here SSR will be inserted)
    HeadSuccClone,
    ConstantInt::get(Type::getInt1Ty(HeadSucc->getContext()), 0u), 
    Head
  );
  //DTU.applyUpdates(cfg::Update<BasicBlock *>(cfg::UpdateKind::Insert, Head, HeadSuccClone));
  //handle phi nodes in End
  for (Instruction &I : *End){
    if (auto *Phi = dyn_cast<PHINode>(&I)){
      for (auto *B : Phi->blocks()){ //yes Phi->blocks() will change during loop ==> does not matter
        auto p = clones.find(B);
        if (p != clones.end()){
          Value *Bval = Phi->getIncomingValueForBlock(B);
          auto v = clones.find(Bval);
          if (v != clones.end()){
            Phi->addIncoming(v->second, cast<BasicBlock>(p->second)); //add clone value & block as input
          }else {
            //v->first is constant or it is defined before cloned region begins
            Phi->addIncoming(Bval, cast<BasicBlock>(p->second));
          }
        }
      }
    }
  }
  LLVM_DEBUG(dbgs()<<"done cloning \n");

  return std::make_pair(HeadBr, std::make_pair(BRFuse, cast<BranchInst>(clones.find(BRFuse)->second)));
}

BasicBlock *getSingleExitBlock(const Loop *L) {
  BasicBlock *Ex = L->getExitBlock();
  if (Ex) return Ex;
  SmallVector<BasicBlock *, 1U> exits;
  L->getExitBlocks(exits);
  for (BasicBlock *BB : exits){
    if (!Ex) Ex = BB;
    if (Ex != BB) return nullptr;
  }
  return Ex;
}

void printInfo(ExpandedAffAcc &E) {
  errs()
    <<(E.Access->isWrite() ? "write" : "read ")
    <<" stream of dimension "
    <<E.getDimension();
  const auto &DL = E.Access->getAccesses()[0]->getDebugLoc();
  if (DL.get()) {
    errs()  
      <<" orig. on line "
      <<DL.getLine();
  }
  errs()
    <<" with base address SCEV "
    <<*E.Access->getBaseAddr(E.getDimension())
    <<".\n";
}

//code for run-time checks for TCDM
Value *GenerateTCDMCheck(ExpandedAffAcc &E, Instruction *Point) {
  IRBuilder<> builder(Point);
  Value *c1 = builder.CreateICmpULE(ConstantInt::get(E.LowerBound->getType(), SSR_SCRATCHPAD_BEGIN), E.LowerBound, "beg.check");
  Value *c2 = builder.CreateICmpULE(E.UpperBound, ConstantInt::get(E.UpperBound->getType(), SSR_SCRATCHPAD_END), "end.check");
  return builder.CreateAnd(c1, c2, "tcdm.check");
}

//generate code for SSR setup
void GenerateSSRSetup(ExpandedAffAcc &E, unsigned dmid, Instruction *Point){
  assert(Point);
  Module *mod = Point->getModule();
  IRBuilder<> builder(Point);
  Type *i32 = Type::getInt32Ty(Point->getContext());
  unsigned dim = E.getDimension();
  LLVM_DEBUG(dbgs()<<"SSR Setup for stream with dim = "<<dim<<"\n");
  if (SSRVerbose) {
    errs()<<"Inferring "; printInfo(E);
  }
  assert(dim <= SSR_MAX_DIM);
  Constant *Dim = ConstantInt::get(i32, dim - 1U); //dimension - 1, ty=i32
  Constant *DMid = ConstantInt::get(i32, dmid); //ty=i32
  bool isStore = E.Access->isWrite();

  Intrinsic::RISCVIntrinsics functions[] = {
    Intrinsic::riscv_ssr_setup_bound_stride_1d,
    Intrinsic::riscv_ssr_setup_bound_stride_2d,
    Intrinsic::riscv_ssr_setup_bound_stride_3d,
    Intrinsic::riscv_ssr_setup_bound_stride_4d
  };

  for (unsigned i = 0u; i < dim; i++) {
    Value *Stride = E.Steps[i];
    if (i > 0) Stride = builder.CreateSub(Stride, E.PrefixSumRanges[i-1], formatv("stride.{0}d", i+1));
    Value *Bound = E.Reps[i];
    Function *SSRBoundStrideSetup = Intrinsic::getDeclaration(mod, functions[i]);
    std::array<Value *, 3> bsargs = {DMid, Bound, Stride};
    builder.CreateCall(SSRBoundStrideSetup->getFunctionType(), SSRBoundStrideSetup, ArrayRef<Value *>(bsargs));
  }

  unsigned n_reps = 0u;
  if (isStore){
    Function *SSRPush = Intrinsic::getDeclaration(mod, Intrinsic::riscv_ssr_push);
    for (Instruction *I : E.Access->getAccesses()){
      std::array<Value *, 2> pusharg = {DMid, cast<StoreInst>(I)->getValueOperand()};
      builder.SetInsertPoint(I);
      builder.CreateCall(SSRPush->getFunctionType(), SSRPush, ArrayRef<Value *>(pusharg));
      I->eraseFromParent();
      n_reps++;
    }
  }else{
    Function *SSRPop = Intrinsic::getDeclaration(mod, Intrinsic::riscv_ssr_pop);
    std::array<Value *, 1> poparg = {DMid};
    for (Instruction *I : E.Access->getAccesses()){
      builder.SetInsertPoint(I);
      auto *V = builder.CreateCall(SSRPop->getFunctionType(), SSRPop, ArrayRef<Value *>(poparg), "ssr.pop");
      BasicBlock::iterator ii(I);
      ReplaceInstWithValue(I->getParent()->getInstList(), ii, V);
      n_reps++;
    }
  }

  builder.SetInsertPoint(Point);
  Constant *Rep = ConstantInt::get(i32, n_reps - 1U);
  Function *SSRRepetitionSetup = Intrinsic::getDeclaration(mod, Intrinsic::riscv_ssr_setup_repetition);
  std::array<Value *, 2> repargs = {DMid, Rep};
  builder.CreateCall(SSRRepetitionSetup->getFunctionType(), SSRRepetitionSetup, ArrayRef<Value *>(repargs));

  Function *SSRSetup;
  if (!isStore){
    SSRSetup = Intrinsic::getDeclaration(mod, Intrinsic::riscv_ssr_read_imm); //can take _imm bc dm and dim are constant
  }else{
    SSRSetup = Intrinsic::getDeclaration(mod, Intrinsic::riscv_ssr_write_imm); //can take _imm bc dm and dim are constant
  }
  std::array<Value *, 3> args = {DMid, Dim, E.Addr};
  //NOTE: this starts the prefetching ==> always needs to be inserted AFTER bound/stride and repetition setups !!!
  builder.CreateCall(SSRSetup->getFunctionType(), SSRSetup, ArrayRef<Value *>(args)); 

  return;
}

/// generate a SSR Barrier intrinsic call before InsertBefore
void generateSSRBarrier(Instruction *InsertBefore, unsigned dmid) {
  IRBuilder<> builder(InsertBefore);
  Function *Barrier = Intrinsic::getDeclaration(InsertBefore->getModule(), Intrinsic::riscv_ssr_barrier);
  builder.CreateCall(Barrier->getFunctionType(), Barrier, ConstantInt::get(Type::getInt32Ty(builder.getContext()), dmid));
}

/// generates SSR enable & disable calls
std::pair<Instruction*, Instruction*> generateSSREnDis(Instruction *PhP, Instruction *ExP){
  IRBuilder<> builder(PhP); // ----------- in preheader 
  Module *mod = PhP->getParent()->getModule();
  Function *SSREnable = Intrinsic::getDeclaration(mod, Intrinsic::riscv_ssr_enable);
  Instruction *en = builder.CreateCall(SSREnable->getFunctionType(), SSREnable, ArrayRef<Value *>());

  builder.SetInsertPoint(ExP); // ----------- in exit block
  //generateFPDependency(builder);
  Function *SSRDisable = Intrinsic::getDeclaration(mod, Intrinsic::riscv_ssr_disable);
  Instruction *dis = builder.CreateCall(SSRDisable->getFunctionType(), SSRDisable, ArrayRef<Value *>());

  LLVM_DEBUG(dbgs()<<"generated ssr_enable and ssr_disable\n");

  return std::make_pair(en, dis);
}

//estimate how much it costs to compute the SSR setup data (bounds, strides, base address, etc...)
int getEstExpandCost(AffAcc *A, unsigned dim) {
  int cost = 0;
  cost += A->getBaseAddr(dim)->getExpressionSize();
  for (unsigned i = 1; i < dim; i++) {
    cost += A->getStep(i)->getExpressionSize();
    cost += A->getRep(i)->getExpressionSize();
    cost += EST_MUL_COST; //for range
    if (i > 1) cost += 1; //for addition
  }
  return cost;
}

//estimate the benefit of turning some AffAccs into streams
int getEstGain(ArrayRef<AffAcc *> Accs, const Loop *L, AffineAccess &AAA) {
  int gain = 0;
  DenseSet<AffAcc *> accs;
  for (auto *A : Accs) accs.insert(A);

  DenseSet<const Loop *> contLoops;
  DenseSet<AffAcc *> vis;
  for (AffAcc *A : Accs) {
    vis.insert(A);
    unsigned dim = A->loopToDimension(L);

    //cost of expanding A
    gain -= getEstExpandCost(A, dim);

    //cost of intersection checks
    if (!SSRNoIntersectCheck) {
      for (const auto &p : A->getConflicts(L)) {
        switch (p.second)
        {
        case AffAccConflict::NoConflict:
          break; //nothing to do
        case AffAccConflict::MustNotIntersect: {
          AffAcc *B = p.first;
          if (vis.find(B) != vis.end()) break; //already handled this conflict when A was B
          unsigned dimB = B->loopToDimension(L);
          if (accs.find(B) == accs.end()) gain -= getEstExpandCost(B, dimB);
          gain -= 4u; //2x ICmpULT, 1 OR, 1 AND
          break;
        }
        case AffAccConflict::Bad:
          assert(false && "WARNING: there is a bad conflict for given Accs and L ==> could not expand them here!");
        default:
          llvm_unreachable("uknown conflict type");
        }
      }
    }

    //cost of tcdm checks
    if (!SSRNoTCDMCheck) {
      gain -= 4u; //2x ICmpULT, 2 AND
    }

    int reps = 1;
    for (unsigned d = dim; d >= 1u; d--) { //dimensions that are extended
      int loopTC = EST_LOOP_TC;
      if (A->getRep(d)->getSCEVType() == SCEVTypes::scConstant) 
        loopTC = cast<SCEVConstant>(A->getRep(d))->getAPInt().getLimitedValue(std::numeric_limits<int>::max());
      reps = std::max(reps * loopTC, reps); //prevent overflows

      //prep for boundcheck cost
      contLoops.insert(A->getLoop(d));
    }
    gain += EST_MEMOP_COST * reps; //the number of loads/stores that are removed by inserting a stream

  }

  if (!SSRNoBoundCheck) {
    gain -= 2 * contLoops.size(); // 1 ICmp, 1 AND per loop
  }

  return gain;
}

///expands AffAcc's in L's preheader and inserts TCDM checks, returns ExpandedAffAcc's and writes the final Value* of the checks into Cond
std::vector<ExpandedAffAcc> expandInLoop(const std::vector<AffAcc *> &accs, const Loop *L, AffineAccess &AAA, Value *&Cond) {
  assert(!accs.empty());
  assert(accs.size() <= NUM_SSR);
  assert(L);

  LLVM_DEBUG(dbgs()<<"expanding in Loop: "<<L->getHeader()->getNameOrAsOperand()<<" at depth "<<L->getLoopDepth()<<"\n");

  auto &ctxt = L->getHeader()->getContext();
  IntegerType *i32 = IntegerType::getInt32Ty(ctxt);
  Type *i8Ptr = Type::getInt8PtrTy(ctxt);

  Instruction *PhT = L->getLoopPreheader()->getTerminator();

  //generate Steps, Reps, base addresses, intersect checks, and bound checks
  auto exp = AAA.expandAllAt(accs, L, PhT, Cond, i8Ptr, i32, !SSRNoIntersectCheck, !SSRNoBoundCheck);
  assert(Cond);

  //TCDM Checks
  if (!SSRNoTCDMCheck) {
    IRBuilder<> builder(PhT);
    for (auto &E : exp) {
      Cond = builder.CreateAnd(Cond, GenerateTCDMCheck(E, PhT));
    }
  }
  
  assert(Cond->getType() == Type::getInt1Ty(Cond->getContext()) && "Cond has type bool (i1)");

  return exp;
}

///clones from L's preheader to L's exit uses Cond for CBr between clone and non-clone
///then generates the instrinsics for all in exp
void cloneAndSetup(Instruction *PhT, Instruction *ExP, Value *Cond, std::vector<ExpandedAffAcc> &exp) {
  assert(exp.size() <= NUM_SSR);
  if (exp.size() == 0u) return;

  //generate en/dis range over both loop versions to prevent later runs of this pass to infer streams in the clone version
  // ExP = generateSSREnDis(PhT, ExP).second; //TODO: this might be better here
  

  if (!isa<ConstantInt>(Cond)){ //if Cond is not a constant we cannot make the decision at compile time ==> clone whole region for if-else
    auto p = cloneRegion(PhT, ExP);
    BranchInst *BR = p.first;
    ExP = p.second.first; //terminator of exit block that jumps to original ExP
    BR->setCondition(Cond);
  } else {
    //this should never happen, but it means the runtime checks were somehow known at compile time and turned out false:
    if(cast<ConstantInt>(Cond)->getLimitedValue() == 0u) return; 
  }
  
  unsigned dmid = 0u;
  for (auto &E : exp) {
    GenerateSSRSetup(E, dmid++, PhT);
    if (SSRBarrier) generateSSRBarrier(ExP, dmid);
  }

  generateSSREnDis(PhT, ExP);
}

//predicate to filter AffAccs
//in accordance with HW limitations, i.e., dimension <= 4, type = double, see #defines used
bool isValid(AffAcc *A, const Loop *L) {
  assert(A->isWellFormed(L));
  bool valid = true;
  bool write = A->isWrite();
  for (Instruction *I : A->getAccesses()) {
    if (write) valid &= CHECK_TYPE(cast<StoreInst>(I)->getValueOperand()->getType(), I);
    else valid &= CHECK_TYPE(I->getType(), I);
  }
  valid &= A->loopToDimension(L) <= SSR_MAX_DIM;
  return valid;
}

//should be guaranteed by SimplifyLoops in SSRInferencePass, but the pass says that any guarantees should be rechecked when depended upon.
bool isValidLoop(const Loop *L) {
  assert(L);
  if (!L->getLoopPreheader() || !getSingleExitBlock(L)) return false;
  return true;
}

// collect some information about loop:
// possible streams
// insertion into conflict tree (for mapping to data movers)
bool visitLoop(const Loop *L, DenseMap<const Loop *, std::vector<AffAcc *>> &possible, ConflictTree<Loop> &tree, AffineAccess &AAA, bool isKnownInvalid) {
  assert(L);

  //NOTE: cannot return early in this function, as `possible` and `tree` need to be expanded even if L is not suitable for streams
  
  std::vector<AffAcc *> accs = AAA.getExpandableAccesses(L, SSRConflictFreeOnly);

  if (isKnownInvalid || !isValidLoop(L)) {
    accs.clear(); //make accs empty
    isKnownInvalid = true;
  }

  std::vector<AffAcc *> valid;
  for (AffAcc *A : accs) {
    if (isValid(A, L)) valid.push_back(A);
  }
  //sort by dimension (with read beeing preferred over write)
  auto comp = [L](const AffAcc *A, const AffAcc *B) { 
    unsigned dimA = A->loopToDimension(L);
    unsigned dimB = B->loopToDimension(L);
    return dimA < dimB || (dimA == dimB && (!A->isWrite() && B->isWrite()));
  };
  std::sort(valid.begin(), valid.end(), comp);
  //add possible:
  auto &l = possible.insert(std::make_pair(L, std::move(std::vector<AffAcc *>()))).first->getSecond();
  for (unsigned i = 0u; i < NUM_SSR && i < valid.size(); i++) {
    l.push_back(valid[i]);
  }
  //add to tree:
  int gain = getEstGain(l, L, AAA);
  LLVM_DEBUG(dbgs()<<"est. gain is "<<gain<<" \n");
  unsigned val = (unsigned)std::max(0, gain); 
  tree.insertNode(L, val, L->isOutermost() ? nullptr : L->getParentLoop());

  if (SSRVerbose) {
    for (auto *A : l) {
      errs()
        <<"potential stream with base addr SCEV "
        <<*A->getBaseAddr(L)
        <<" of dimension "
        <<A->loopToDimension(L)
        <<"\n";
    }
    if (!l.empty()) errs()<<"With est. gain = "<<gain<<"\n";
  }

  return !isKnownInvalid;
}

///finds loops already affected by SSR
DenseSet<const Loop *> findLoopsWithSSR(Function &F, LoopInfo &LI) {
  DenseSet<const Loop *> invalid;

  DenseSet<Intrinsic::ID> ids;
  for (Intrinsic::ID x : riscSSRIntrinsics){
    ids.insert(x); //put intrinsics into set for faster lookup
  }

  std::deque<std::pair<BasicBlock *, bool>> worklist;
  DenseSet<BasicBlock *> visUnmarked;
  DenseSet<BasicBlock *> visMarked;
  worklist.push_back(std::make_pair(&F.getEntryBlock(), false));
  while(!worklist.empty()) {
    auto p = worklist.front(); worklist.pop_front();
    BasicBlock *BB = p.first;
    bool marked = p.second;

    if (!BB) continue;
    if (marked) {
      if (visMarked.find(BB) != visMarked.end()) continue;
      visMarked.insert(BB);

      //mark all loops containing this Block invalid
      const Loop *L = LI.getLoopFor(BB); 
      while (L) { 
        invalid.insert(L);
        L = L->getParentLoop();
      }

      //go through instructions in block, if there is an ssr_disable() call, remove the marking for the successors of this block
      for (Instruction &i : *BB) {
        if (isa<IntrinsicInst>(i)) {
          if (cast<IntrinsicInst>(i).getIntrinsicID() == Intrinsic::riscv_ssr_disable) marked = false;
        }
        if (!marked) break; //early exit
      }

    } else {
      if (visUnmarked.find(BB) != visUnmarked.end()) continue;
      visUnmarked.insert(BB);

      for (Instruction &i : *BB) {
        Instruction *I = &i;
        if (CallBase *C = dyn_cast<CallBase>(I)) {
          if (C->hasFnAttr(SSRFnAttr)) {
            LLVM_DEBUG(dbgs()<<"call "<<*C<<" has attribute "<<SSRFnAttr<<"\n");
            //all loops that contain this call cannot have ssr streams, but successors can (we assume correct SSR usage) ==> no need to mark the BB
            const Loop *L = LI.getLoopFor(BB);
            while (L) {
              invalid.insert(L);
              L = L->getParentLoop();
            }
          }
          if (IntrinsicInst *II = dyn_cast<IntrinsicInst>(C)) { 
            if (ids.contains(II->getIntrinsicID())) {
              LLVM_DEBUG(dbgs()<<"Intrinsic Instr "<<*II<<" calls an SSR intrinsic\n");
              marked = true; //mark this (and thus also all following BBs)
            }
          }
          if (C->isInlineAsm()) { //inline asm may contain ssr setup insts!
            LLVM_DEBUG(dbgs()<<"inline asm call "<<*C<<" may contain ssr insts!\n");
            LLVM_DEBUG(C->getType()->dump());
            marked = true;
          }
        }
      }
      if (marked) worklist.push_back(std::make_pair(BB, true)); // if now marked, add to queue again
    }

    for (BasicBlock *BB2 : successors(BB)) {
      worklist.push_back(std::make_pair(BB2, marked));
    }
  }
  if (!invalid.empty()) LLVM_DEBUG(dbgs()<<"Loops that are invalid bc of SSR\n");
  for (auto l : invalid) {
    LLVM_DEBUG(dbgs()<<"header = "<<l->getHeader()->getNameOrAsOperand()<<" at depth = "<<l->getLoopDepth()<<"\n");
  }

  return invalid;
}

} //end of namespace

// main "run" of this pass
PreservedAnalyses SSRGenerationPass::run(Function &F, FunctionAnalysisManager &FAM){
  LLVM_DEBUG(dbgs()<<"SSRInference Flags: ");
  if (InferSSR) LLVM_DEBUG(dbgs()<<"infer-ssr");
  if (SSRNoIntersectCheck) LLVM_DEBUG(dbgs()<<", ssr-no-intersect-check");
  if (SSRNoBoundCheck) LLVM_DEBUG(dbgs()<<", ssr-no-bound-check");
  if (SSRNoTCDMCheck) LLVM_DEBUG(dbgs()<<", ssr-no-tcdm-check");
  if (SSRBarrier) LLVM_DEBUG(dbgs()<<", ssr-barrier");
  if (SSRNoInline) LLVM_DEBUG(dbgs()<<", ssr-no-inline");
  if (SSRConflictFreeOnly) LLVM_DEBUG(dbgs()<<", ssr-conflict-free-only");
  LLVM_DEBUG(dbgs()<<"\n");

  if (!InferSSR) return PreservedAnalyses::all(); //if no SSR inference is enabled, we exit early
  if (F.hasFnAttribute(SSRFnAttr)) return PreservedAnalyses::all(); //this function already contains streams ==> skip

  AffineAccess &AAA = FAM.getResult<AffineAccessAnalysis>(F); //call analysis

  LLVM_DEBUG(dbgs()<<"SSR Generation Pass on function: "<<F.getNameOrAsOperand()<<" ---------------------------------------------------\n");

  bool changed = false;
  auto &toploops = AAA.getLI().getTopLevelLoops();
  DenseMap<const Loop *, ConflictTree<Loop>> trees; //keep track of the conflict tree for each top-level loop
  DenseMap<const Loop *, std::vector<const Loop *>> bestLoops; //keep track of the best results for each tree
  DenseMap<const Loop *, std::vector<AffAcc *>> possible; //keep track of the AffAcc's that can be expanded in each loop
  DenseMap<const Loop*, Value*> conds; //keep track of the condition of the run-time check for each loop
  DenseMap<const Loop*, std::vector<ExpandedAffAcc>> exps; //keep track of the expanded AffAcc's for each loop
  DenseSet<const Loop*> ssrInvalidLoops = findLoopsWithSSR(F, AAA.getLI());

  for (const Loop *T : toploops){
    ConflictTree<Loop> &tree = trees.insert(std::make_pair(T, ConflictTree<Loop>())).first->getSecond();

    //go through all loops in sub-tree of T to build conflict-tree and find possible expands
    std::deque<const Loop *> worklist;
    worklist.push_back(T);
    while (!worklist.empty()) {
      const Loop *L = worklist.front(); worklist.pop_front();
      LLVM_DEBUG(dbgs()<<"visiting loop: "<<L->getHeader()->getNameOrAsOperand()<<"\n");

      visitLoop(L, possible, tree, AAA, ssrInvalidLoops.find(L) != ssrInvalidLoops.end());

      for (const Loop *x : L->getSubLoops()) worklist.push_back(x);
    }

    //find best expands (map best loops to data movers)
    auto f = [](unsigned a, unsigned b){ return a + b; };
    std::vector<const Loop *> best = tree.findBest(f);

    //expand them
    for (const Loop *L : best) {
      auto &acc = possible.find(L)->getSecond();
      if (!acc.empty()) {
        changed = true;
        Value *Cond = nullptr;
        auto exp = expandInLoop(acc, L, AAA, Cond);
        assert(Cond);
        conds.insert(std::make_pair(L, Cond));
        exps.insert(std::make_pair(L, std::move(exp)));
      }
    }

    bestLoops.insert(std::make_pair(T, std::move(best)));
  }

  ///NOTE: as soon as we start cloning (so after this comment), all the analyses are falsified and we do not want to update them 
  ///because that would falsify the AAA (which we do not want to update because it would find less solutions after the cloning).
  ///So all the code that follows does not make use of any of the analyses (except for L->getLoopPreheader & stuff like that which luckily still work)

  for (const Loop *T : toploops) {
    std::vector<const Loop *> &best = bestLoops.find(T)->getSecond(); 
    for (const Loop *L : best) {
      auto p = conds.find(L);
      if (p != conds.end()) {
        BasicBlock *Ex = getSingleExitBlock(L);
        assert(Ex);
        if (SSRVerbose) {
          errs()
            <<"> Function "
            <<L->getHeader()->getParent()->getNameOrAsOperand()
            <<": Expanding SSR streams with "
            <<(L->getLoopDepth()-1)
            <<" containing loops and setup in preheader of loop with header "
            <<L->getHeader()->getNameOrAsOperand()
            <<"\n";
        }
        cloneAndSetup(L->getLoopPreheader()->getTerminator(), &*Ex->getFirstInsertionPt(), p->second, exps.find(L)->getSecond());
      }
    }
  }

  if (!changed) return PreservedAnalyses::all();
  
  F.addFnAttr(StringRef(SSRFnAttr)); //we have inserted a stream, tag accordingly
  if (SSRNoInline) F.addFnAttr(Attribute::AttrKind::NoInline);
  return PreservedAnalyses::none();
}