//===-- SSRGeneration.cpp - find prefetchable square affine accesses --------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/Analysis/AffineAccessAnalysis.h"

#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/raw_ostream.h"

#include "llvm/InitializePasses.h"

#include "llvm/IR/Instruction.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/InstrTypes.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/IntrinsicsRISCV.h"
#include "llvm/IR/Dominators.h"

#include "llvm/Transforms/Utils/BasicBlockUtils.h"
#include "llvm/Transforms/Utils/ScalarEvolutionExpander.h"
#include "llvm/Transforms/Utils/LoopVersioning.h"

#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ScalarEvolutionExpressions.h"
#include "llvm/Analysis/MemorySSA.h"
#include "llvm/Analysis/AliasAnalysis.h"
#include "llvm/Analysis/AliasAnalysisEvaluator.h"
#include "llvm/Analysis/AliasSetTracker.h"
#include "llvm/Analysis/DependenceAnalysis.h"
#include "llvm/Analysis/LoopAccessAnalysis.h"

#include "llvm/Support/CommandLine.h"
#include "llvm/Support/FormatVariadic.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/Compiler.h"

#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/TinyPtrVector.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/ilist.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/DenseMap.h"

#include <array>
#include <vector>
#include <iostream>
#include <utility>

#define DEBUG_TYPE "ssr"

using namespace llvm;

//================== AffineAcces, helper functions =========================================

namespace {

//collects the set of unknown values in SCEV
struct SCEVUknownSetFinder {
  DenseSet<Value *> values;
  // return true to follow this node.
  bool follow(const SCEV *S) {
    if (S->getSCEVType() == SCEVTypes::scUnknown) {
      values.insert(cast<SCEVUnknown>(S)->getValue());
    }
    return true; //always true
  }
  // return true to terminate the search.
  bool isDone() { return false; /*continue forever*/ }
};

//finds whether two SCEVs share unknown values
bool shareValues(const SCEV *A, const SCEV *B) {
  SCEVUknownSetFinder finderA;
  SCEVTraversal<SCEVUknownSetFinder> trA(finderA);
  trA.visitAll(A);
  SCEVUknownSetFinder finderB;
  SCEVTraversal<SCEVUknownSetFinder> trB(finderB);
  trB.visitAll(B);
  bool shareValues = false;
  for (Value *V : finderA.values) {
    for (Value *W : finderB.values) {
      shareValues |= V == W;
    }
  }
  return shareValues;
}

//checks whether SCEV contains the SCEVCouldNotCompute expression
bool SCEVContainsCouldNotCompute(const SCEV *S) {
  auto pred = [](const SCEV *X) { return !X || X->getSCEVType() == SCEVTypes::scCouldNotCompute || isa<SCEVCouldNotCompute>(X); };
  return SCEVExprContains(S, std::move(pred));
}

/// guarantees: 
/// L has 1 preheader and 1 dedicated exit
/// L has 1 backedge and 1 exiting block
/// bt SCEV can be expanded to instructions at insertionsPoint
const SCEV *getLoopBTSCEV(const Loop *L, DominatorTree &DT, ScalarEvolution &SE){
  if (!L->isLCSSAForm(DT)
    || !L->getLoopPreheader() 
    || !L->getExitingBlock() 
    || !L->getExitBlock() 
    || !L->hasDedicatedExits() 
    || L->getNumBackEdges() != 1) { 
    return nullptr; 
  }
  if (!SE.hasLoopInvariantBackedgeTakenCount(L)){
    return nullptr;
  }
  const SCEV *bt = SE.getBackedgeTakenCount(L);
  if(!bt || isa<SCEVCouldNotCompute>(bt) || !SE.isAvailableAtLoopEntry(bt, L) || SCEVContainsCouldNotCompute(bt)){
    return nullptr;
  }
  return bt;
}

//casts SCEVs to same type if possible (or always if unsafe = true)
Optional<std::pair<const SCEV *, const SCEV *>> toSameType(const SCEV *LHS, const SCEV *RHS, ScalarEvolution &SE, bool unsafe = false){
  assert(LHS && RHS);
  using PT = std::pair<const SCEV *, const SCEV *>;

  const DataLayout &DL = SE.getDataLayout();
  LLVMContext &ctxt = SE.getContext();

  Type *LT = LHS->getType(), *RT = RHS->getType();
  if (LT == RT) 
    return Optional<PT>(std::make_pair(LHS, RHS)); //trivially the same size
  if (LT->isPointerTy() && RT->isPointerTy()) //if we have pointers to different types
    //PointerType *LTP = cast<PointerType>(LT); PointerType *RTP = cast<PointerType>(RT);
    return Optional<PT>(std::make_pair(
      SE.getPtrToIntExpr(LHS, Type::getIntNTy(ctxt, DL.getMaxPointerSizeInBits())), 
      SE.getPtrToIntExpr(RHS, Type::getIntNTy(ctxt, DL.getMaxPointerSizeInBits()))
    ));

  if (!LT->isSized() || !RT->isSized()) return None;
  if (DL.getTypeSizeInBits(LT).isScalable() || DL.getTypeSizeInBits(RT).isScalable()) return None;

  uint64_t ls = DL.getTypeSizeInBits(LT).getValue(), rs = DL.getTypeSizeInBits(RT).getValue();

  if (ls > rs) {
    if (auto LHSx = dyn_cast<SCEVConstant>(LHS)){
      if (LHSx->getAPInt().getActiveBits() <= rs) 
        return Optional<PT>(std::make_pair(SE.getConstant(RHS->getType(), LHSx->getAPInt().getLimitedValue()), RHS));
    } 
    if (auto RHSx = dyn_cast<SCEVConstant>(RHS)){
      return Optional<PT>(std::make_pair(LHS, SE.getConstant(LHS->getType(), RHSx->getAPInt().getLimitedValue())));
    }
    if (auto LHSx = dyn_cast<SCEVSignExtendExpr>(LHS)) return toSameType(LHSx->getOperand(0), RHS, SE);
    if (auto LHSx = dyn_cast<SCEVZeroExtendExpr>(LHS)) return toSameType(LHSx->getOperand(0), RHS, SE);
    if (auto RHSx = dyn_cast<SCEVTruncateExpr>(RHS)) return toSameType(LHS, RHSx->getOperand(0), SE);
    if (unsafe && LT->isIntegerTy() && RT->isIntegerTy()) return Optional<PT>(std::make_pair(SE.getTruncateExpr(LHS, RHS->getType()), RHS));
    return None;
  }else if (ls < rs){
    auto p = toSameType(RHS, LHS, SE); //swap
    if (!p.hasValue()) return None;
    return Optional<PT>(std::make_pair(p.getValue().second, p.getValue().first)); //swap back
  }
  if (unsafe) return Optional<PT>(std::make_pair(LHS, RHS));
  return None;
}

///checks whether LHS == RHS always holds
bool SCEVEquals(const SCEV *LHS, const SCEV *RHS, ScalarEvolution &SE){
  auto p = toSameType(LHS, RHS, SE);
  if (!p.hasValue()) return false;
  LHS = p.getValue().first;
  RHS = p.getValue().second;
  if (LHS == RHS) return true; //trivially the same if this holds (bc const Ptr)
  else{
    const SCEVPredicate *Peq = SE.getEqualPredicate(LHS, RHS);
    if (Peq->isAlwaysTrue()) return true; //if we arrive at setup addr scev, we are done
  }
  return false;
}

/// check whether BB is on all controlflow paths from header to header
// TODO: could also be done with DT
bool isOnAllControlFlowPaths(BasicBlock *BB, const Loop *L, const DominatorTree &DT){
  BasicBlock *End = L->getHeader();
  std::deque<std::pair<BasicBlock *, bool>> q;
  q.push_back(std::make_pair(End, false)); //start with header (false = BB not yet visited)
  std::set<std::pair<BasicBlock *, bool>> vis; //comp here is less<pair<BasicBlock *, bool>>
  while (!q.empty()){
    auto p = q.front(); q.pop_front();
    if (vis.find(p) != vis.end()) continue;
    vis.insert(p);
    for (BasicBlock *B : successors(p.first)){
      q.push_back(std::make_pair(B, p.second || B == BB));
    }
    //check here whether End is reached with false (not at start of loop bc we also start with End)
    p = q.front();
    if (!p.second && p.first == End) return false; //got to End (header) without ever visiting BB
  }
  return true;
}

//return result of Cmp predicated on Rep > 0 if possible.
// i.e. if we can say that Rep > 0 implies that Cmp is always false or true, we return that, o/w return None
Optional<bool> predicatedICmpOutcome(ICmpInst *Cmp, const SCEV *Rep, ScalarEvolution &SE){
  switch (Cmp->getPredicate())
  {
  case CmpInst::Predicate::ICMP_SGT:
  case CmpInst::Predicate::ICMP_UGT:
  {
    const SCEV *LHS = SE.getSCEV(Cmp->getOperand(0));
    const SCEV *RHS = SE.getSCEV(Cmp->getOperand(1));
    //transform: LHS > RHS <==> LHS - RHS > 0
    const SCEV *LHSmRHS = SE.getMinusSCEV(LHS, RHS);
    //then check whether Rep == LHS - RHS in which case we know: Rep > 0 ==> result of Cmp is true
    if (SCEVEquals(Rep, LHSmRHS, SE)) return Optional<bool>(true);
    else return None;
  }
  case CmpInst::Predicate::ICMP_SLT:
  case CmpInst::Predicate::ICMP_ULT:
  {
    //a < b <==> b > a
    const SCEV *LHS = SE.getSCEV(Cmp->getOperand(1)); //b
    const SCEV *RHS = SE.getSCEV(Cmp->getOperand(0)); //a
    //transform: LHS > RHS <==> LHS - RHS > 0
    const SCEV *LHSmRHS = SE.getMinusSCEV(LHS, RHS);
    //then check whether Rep == LHS - RHS in which case we know: Rep > 0 ==> result of Cmp is true
    if (SCEVEquals(Rep, LHSmRHS, SE)) return Optional<bool>(true);
    else return None;
  }
  case CmpInst::Predicate::ICMP_EQ:
  case CmpInst::Predicate::ICMP_NE:
  {
    //Rep > 0 ==> Rep + x != x
    const SCEV *LHS = SE.getSCEV(Cmp->getOperand(0)); //Rep + x (hopefully)
    const SCEV *RHS = SE.getSCEV(Cmp->getOperand(1)); //x 
    const SCEV *LHSmRHS = SE.getMinusSCEV(LHS, RHS);  //Rep (hopefully)
    if (SCEVEquals(Rep, LHSmRHS, SE)) return Optional<bool>(Cmp->getPredicate() == CmpInst::Predicate::ICMP_NE);
    else return None;
  }
  default:
    return None;
  }
}

//conservative! 
//because SCEVComparePredicate is not in this version of LLVM we have to do this manually ==> will not catch all cases (FIXME)
//predicate is that Rep > 0
bool isOnAllPredicatedControlFlowPaths(BasicBlock *BB, const Loop *L, const DominatorTree &DT, const SCEV *Rep, ScalarEvolution &SE){
  if (isOnAllControlFlowPaths(BB, L, DT)) return true; //is on all paths anyway
  DenseSet<BasicBlock *> vis; //visited set
  std::deque<BasicBlock *> q(1U, L->getHeader()); //iterative BFS with queue
  while (!q.empty()){
    BasicBlock *Current = q.front(); q.pop_front();
    if (Current == BB) continue; //do not continue BFS from BB
    if (vis.find(Current) == vis.end()) continue; //already visited this block
    vis.insert(Current);

    Instruction *T = Current->getTerminator();
    LLVM_DEBUG(T->dump());
    if (BranchInst *BR = dyn_cast<BranchInst>(T)){
      if (BR->isConditional()){
        if (ICmpInst *Cmp = dyn_cast<ICmpInst>(BR->getCondition())){ //FOR NOW: only works with a single ICmpInst as branch condition operand
          LLVM_DEBUG(Cmp->dump());
          auto r = predicatedICmpOutcome(Cmp, Rep, SE);
          if (r.hasValue()){
            if (r.getValue()) q.push_back(BR->getSuccessor(0));
            else q.push_back(BR->getSuccessor(1));
          }else{
            q.push_back(BR->getSuccessor(0));
            q.push_back(BR->getSuccessor(1));
          }
        }
      }else{
        q.push_back(BR->getSuccessor(0)); //add the only successor to queue
      }
    }else{  
      return false; //unknown jump somewhere else ==> BB not on all predicated paths
    }

    if (q.front() == L->getHeader()) return false; //bfs arrived at Header (again) with a path that never went through BB
  }
  return true;
}

//cast to right integer size, insert instruction at `InsPoint`
Value *castToSize(Value *R, Type *ty, Instruction *InsPoint){
  const DataLayout &DL = InsPoint->getParent()->getModule()->getDataLayout();
  IRBuilder<> builder(InsPoint);
  Type *rty = R->getType();
  if (rty == ty) return R;
  if (DL.getTypeSizeInBits(rty) > DL.getTypeSizeInBits(ty)) {
    return builder.CreateTruncOrBitCast(R, ty, "scev.trunc");
  }
  if (DL.getTypeSizeInBits(rty) < DL.getTypeSizeInBits(ty)) {
    return builder.CreateSExtOrBitCast(R, ty, "scev.sext");
  }
  return builder.CreateBitOrPointerCast(R, ty, "scev.cast");
}

// extract the Address Value of MA (nullptr if not available)
Value *getAddress(MemoryUseOrDef *MA) {
  assert(MA && "called getAddress on nullptr");
  assert(MA->getMemoryInst());
  Instruction *I = MA->getMemoryInst();
  if (auto *L = dyn_cast<LoadInst>(I)) return L->getPointerOperand();
  if (auto *S = dyn_cast<StoreInst>(I)) return S->getPointerOperand();
  return nullptr;
}

//find the first L in loops that contains BB
//loops should be a nesting of loops from inner to outermost
const Loop *findFirstContaining(ArrayRef<const Loop *> loops, BasicBlock *BB){
  for (const Loop *L : loops) {
    if (L && L->contains(BB)) {
      return L;
    }
  }
  return nullptr;
}

//find out whether MA stands for some load/store (for some reason they don't always do, maybe bc of DCE?)
bool hasMemInst(MemoryUseOrDef *MA) { return MA && MA->getMemoryInst(); }

//updates L<-M if M is a descendant of L (or if L is nullptr)
void updateIfDescendant(const Loop *&L, const Loop *M) {
  if (!L || (M && L->contains(M))) L = M;
}

//updates L<-M if L is descendant of M OR if M is nullptr
void updateIfAncestor(const Loop *&L, const Loop *M) {
  if (!M || M->contains(L)) L = M;
}

void updateOutermostExpandableExcl(const Loop *&outerMostExpandableExl, AffAccConflict kind, const Loop *innermostCommon, const Loop *deepestMalformed) {
  switch (kind) {
  case AffAccConflict::NoConflict:
    break;
  case AffAccConflict::MustNotIntersect: 
    updateIfAncestor(innermostCommon, deepestMalformed); //updates innermostCommon to deepestMalformed if that one is less "deep"
    LLVM_FALLTHROUGH;
  case AffAccConflict::Bad: 
    updateIfDescendant(outerMostExpandableExl, innermostCommon);
    break;
  default:
    llvm_unreachable("unknown conflict type");
  }
}

//tries to find the sign of SCEV which information given
Optional<int> findSign(const SCEV *S, ScalarEvolution &SE, std::vector<std::pair<const SCEV *, int>> &known) {
  if (!S) return None;

  //in case we know
  for (const auto &p : known) {
    if (SCEVEquals(S, p.first, SE)) return p.second;
  }

  //in case SE knows
  if (SE.isKnownNegative(S)) return -1;
  if (SE.isKnownPositive(S)) return 1;
  if (S->isZero()) return 0;

  //do recursively
  switch (S->getSCEVType())
  {
  case SCEVTypes::scConstant:
    if (S->isZero()) return 0;
    else if (SE.isKnownPositive(S)) return 1;
    else if (SE.isKnownNegative(S)) return -1;
    llvm_unreachable("SE does not know sign of constant value ???");

  case SCEVTypes::scMulExpr: {
    auto l = findSign(cast<SCEVMulExpr>(S)->getOperand(0), SE, known);
    auto r = findSign(cast<SCEVMulExpr>(S)->getOperand(1), SE, known);
    if (!l.hasValue() || !r.hasValue()) return None;
    return r.getValue() * l.getValue();
  }

  case SCEVTypes::scAddExpr: {
    auto l = findSign(cast<SCEVAddExpr>(S)->getOperand(0), SE, known);
    auto r = findSign(cast<SCEVAddExpr>(S)->getOperand(1), SE, known);
    if (!l.hasValue() || !r.hasValue()) return None;
    if (l.getValue() + r.getValue() >= 1) return 1;
    if (l.getValue() + r.getValue() <= -1) return -1;
    return None;
  }

  case SCEVTypes::scPtrToInt:
  case SCEVTypes::scTruncate:
    return findSign(cast<SCEVCastExpr>(S)->getOperand(0), SE, known);

  //TODO: could add max/min, etc...
  
  default:
    return None;
  } 
  llvm_unreachable("");
}

//cast some SCEVs if necessary
const SCEV *getZExtIfNeeded(const SCEV *S, Type *Ty, ScalarEvolution &SE) {
  if (SE.getDataLayout().getTypeSizeInBits(S->getType()) < SE.getDataLayout().getTypeSizeInBits(Ty)) {
    return SE.getZeroExtendExpr(S, Ty);
  }
  return S;
}

//cast some SCEVs if necessary
const SCEV *getSExtIfNeeded(const SCEV *S, Type *Ty, ScalarEvolution &SE) {
  if (SE.getDataLayout().getTypeSizeInBits(S->getType()) < SE.getDataLayout().getTypeSizeInBits(Ty)) {
    return SE.getSignExtendExpr(S, Ty);
  }
  return S;
}

} //end of namespace

//==================  ===========================================================

// ==== LoopRep ====
LoopRep::LoopRep(const Loop *L, ArrayRef<const Loop *> contLoops, ScalarEvolution &SE, DominatorTree &DT) 
  : SE(SE), DT(DT), L(L), containingLoops(contLoops.begin(), contLoops.end()), safeExpandBound(0u)
  {
  RepSCEV = getLoopBTSCEV(L, DT, SE);
  if (RepSCEV) LLVM_DEBUG(dbgs()<<"new LoopRep with rep scev: "<<*RepSCEV<<"\n");
  else LLVM_DEBUG(dbgs()<<"new LoopRep with rep scev: <nullptr> \n");
  
  if (RepSCEV){
    while (safeExpandBound < containingLoops.size() 
      && (!containingLoops[safeExpandBound] 
        || isSafeToExpandAt(RepSCEV, containingLoops[safeExpandBound]->getLoopPreheader()->getTerminator(), SE))){
      safeExpandBound++;
    }
  }
}

bool LoopRep::isAvailable() const { return RepSCEV != nullptr; }
const Loop *LoopRep::getLoop() const { return L; }
const SCEV *LoopRep::getSCEV() const { 
  assert(isAvailable() && "SCEV available"); //not necessary, but forces good practice
  return RepSCEV; 
}

const SCEV *LoopRep::getSCEVPlusOne() const {
  assert(isAvailable() && "SCEV available");
  return SE.getAddExpr(getSCEV(), SE.getConstant(getSCEV()->getType(), 1UL));
}

bool LoopRep::isOnAllCFPathsOfParentIfExecuted() const { //FIXME: maybe cache this result once calculated?
  assert(isAvailable() && "SCEV available");
  return isOnAllPredicatedControlFlowPaths(L->getHeader(), L->getParentLoop(), DT, getSCEVPlusOne(), SE);
}

bool LoopRep::isSafeToExpandBefore(const Loop *L) const {
  assert(isAvailable() && "SCEV available");
  if (L == getLoop()) return true;
  for (unsigned i = 0u; i < safeExpandBound; i++) { //FIXME: linear search -> use map instead
    if (L == containingLoops[i]) return true;
  }
  return false;
}

//code generation for loop rep, will cache the Value holding the results after calling for the first time to prevent excessive code-gen
Value *LoopRep::expandAt(Type *ty, Instruction *InsertBefore){
  assert(ty);
  assert(RepSCEV);
  if (Rep) { //FIXME: currently forces user to call first expand at a point that dominates all possible uses (improvement: could update expand point using DT)
    assert(ty == Rep->getType() && "was already expanded with same type");
    return Rep;
  }
  InsertBefore = InsertBefore ? InsertBefore : L->getLoopPreheader()->getTerminator();
  const SCEV *RepP1 = getSCEVPlusOne(); //we go over the +1 version here because getSCEV() is usually sth like %n-1 so then this becomes just %n
  assert(isSafeToExpandAt(RepP1, InsertBefore, SE) && "bound not expandable here");
  SCEVExpander ex(SE, L->getHeader()->getModule()->getDataLayout(), "rep");
  ex.setInsertPoint(InsertBefore);
  RepPlusOne = castToSize(ex.expandCodeFor(RepP1), ty, InsertBefore);
  IRBuilder<> builder(InsertBefore);
  Rep = builder.CreateSub(RepPlusOne, ConstantInt::get(ty, 1u), "rep");
  return Rep;
}

//code-gen for loop guard, ie. inserts code of rep+1 > 0
Value *LoopRep::expandLoopGuard(Instruction *InsertBefore) {
  assert(RepPlusOne && "expandAt has to be called before this");
  InsertBefore = InsertBefore ? InsertBefore : L->getLoopPreheader()->getTerminator();
  IRBuilder<> builder(InsertBefore);
  return builder.CreateICmpSGT(RepPlusOne, ConstantInt::get(Rep->getType(), 0u, true)); //FIXME: this only works for unsigned Rep's that are < 2^30 (for i32)
}

// ==== AffAcc ====
AffAcc::AffAcc(ArrayRef<Instruction *> accesses, const SCEV *Addr, MemoryUseOrDef *MA, ArrayRef<const Loop *> contLoops, ScalarEvolution &SE) 
  : SE(SE), MA(MA), accesses(accesses.begin(), accesses.end())
{
  assert(!accesses.empty());
  assert(MA); 

  containingLoops.push_back((const Loop *)nullptr); //there is no loop for dim=0
  containingLoops.append(contLoops.begin(), contLoops.end()); //initialize loops

  bool isVolatile = false;
  for (Instruction *I : accesses) //check for volatile mem insts, we don't want to touch those
    isVolatile |= (isa<LoadInst>(I) && cast<LoadInst>(I)->isVolatile()) || (isa<StoreInst>(I) && cast<StoreInst>(I)->isVolatile());
  if (Addr && (SCEVContainsCouldNotCompute(Addr) || isVolatile)) Addr = nullptr; //set to null if contains SCEVCouldNotCompute
  baseAddresses.push_back(Addr);
  if (!Addr) return; //do not look for steps or addresses if SCEV of address is unknown
  steps.push_back((const SCEV *)nullptr); //there is no step for dim=0
  reps.push_back((LoopRep *)nullptr); //there is no rep for dim=0
  findSteps(Addr, (const SCEV *)nullptr, 1u); //find steps
  for (unsigned dim = 1; dim < containingLoops.size(); dim++){
    Addr = SE.SplitIntoInitAndPostInc(containingLoops[dim], Addr).first;
    baseAddresses.push_back(Addr);
  }
}

//fold over A and collect steps in AddRec expressions
//the found steps might not be valid for square affine access patterns ==> `promote` will check this
void AffAcc::findSteps(const SCEV *A, const SCEV *Factor, unsigned loop){
  assert(A);
  assert(baseAddresses.size() == 1 && reps.size() == 1 && "we only know dim=0 so far");

  if (loop >= containingLoops.size()) return;  //we are done

  if (!SE.containsAddRecurrence(A) && loop < containingLoops.size()){ 
    //A is inv to the rest of the loops
    steps.push_back(SE.getConstant(Type::getInt64Ty(this->accesses[0]->getContext()), 0U));
    findSteps(A, Factor, loop + 1u);
  }

  switch (A->getSCEVType())
  {
  //unary expressions that do not change value
  case SCEVTypes::scZeroExtend: //FIXME: this might be unsafe
  case SCEVTypes::scSignExtend:
  case SCEVTypes::scTruncate:
    return findSteps(cast<SCEVCastExpr>(A)->getOperand(0), Factor, loop);

  // TODO: if we want to allow random adds in between then we would need to add the non-recursive part to the base address
  // case SCEVTypes::scAddExpr: {
  //   const SCEV *L = cast<SCEVAddExpr>(A)->getOperand(0);
  //   const SCEV *R = cast<SCEVAddExpr>(A)->getOperand(1);
  //   bool l = SE.containsAddRecurrence(L);
  //   bool r = SE.containsAddRecurrence(R);
  //   if (l && !r) return findSteps(L, Factor, loop);
  //   else if(!l && r) return findSteps(R, Factor, loop);
  //   return;
  // }

  //L * R
  case SCEVTypes::scMulExpr: {
    const SCEV *L = cast<SCEVMulExpr>(A)->getOperand(0);
    const SCEV *R = cast<SCEVMulExpr>(A)->getOperand(1);
    bool l = SE.containsAddRecurrence(L);
    bool r = SE.containsAddRecurrence(R);
    if (l == r) return;
    if (!l && r) std::swap(L, R); 
    assert(SE.containsAddRecurrence(L) && !SE.containsAddRecurrence(R));
    if (Factor) {
      auto p = toSameType(Factor, R, SE, true);
      if (!p.hasValue()) return;
      Factor = SE.getMulExpr(p.getValue().first, p.getValue().second);
    }else Factor = R;
    return findSteps(L, Factor, loop);
  }

  //{<start>,+,Step}<L>
  case SCEVTypes::scAddRecExpr: {
    const auto *S = cast<SCEVAddRecExpr>(A);
    const SCEV *Step;
    if (S->getLoop() == containingLoops[loop]){ //L == containingLoops[loop]
      Step = S->getStepRecurrence(SE);
      if (Factor) {
        auto p = toSameType(Factor, Step, SE, true);
        if (!p.hasValue()) return;
        Step = SE.getMulExpr(p.getValue().first, p.getValue().second);
      }
      steps.push_back(Step);
      return findSteps(S->getStart(), Factor, loop+1);
    }else{ //A is loop-invariant to containingLoops[loop]
      bool occursLater = false; //loop needs to occur later 
      for (unsigned i = loop+1; i < containingLoops.size(); i++) 
        occursLater = occursLater || containingLoops[i] == S->getLoop();
      if (!occursLater) return; 
      steps.push_back(SE.getConstant(Type::getInt64Ty(this->accesses[0]->getContext()), 0U));
      return findSteps(S, Factor, loop+1);
    }    
  }
  default: //in all other cases we cannot safely extract more steps and thus just return
    return;
  }
}

ArrayRef<Instruction *> AffAcc::getAccesses() const { return accesses; }

bool AffAcc::isWrite() const { return isa<MemoryDef>(MA); }

///the nr of times `this` was promoted (-1 means the address is not known)
int AffAcc::getMaxDimension() const { return (int)reps.size() - 1; }

///return the first (as in deepest) Loop L where this->isWellFormed(L) is false
///returns null if there is no such loop
const Loop *AffAcc::getDeepestMalformed() const {
  for (const Loop *L : containingLoops) {
    if (L && !isWellFormed(L)) return L;
  }
  return nullptr;
  /*unsigned malformedStart = (unsigned)(getMaxDimension() + 2); //getMaxDimension() >= -1
  if (containingLoops.size() > malformedStart) return containingLoops[malformedStart];
  else return nullptr;*/
}

///true if this was successfully promoted to the given dimension (ie. nr of promotions is at least `dimension`)
bool AffAcc::isWellFormed(unsigned dimension) const { 
  int md = getMaxDimension();
  return md >= 0 && dimension <= (unsigned)md; 
}

///true if this was successfully promoted to the given dimension (ie. nr of promotions is `dimension`)
///if true, this means that `this` can be expanded in the preheader of `L`
bool AffAcc::isWellFormed(const Loop *L) const { return isWellFormed(loopToDimension(L)); }

///returns the dimension that is defined by `L` (starts at 1)
unsigned AffAcc::loopToDimension(const Loop *L) const {
  assert(L && "L not nullptr");
  for (unsigned d = 1u; d < containingLoops.size(); d++){ //FIXME: linear search -> improve with a <loop,unsigned> map
    if (containingLoops[d] == L) return d;
  }
  llvm_unreachable("The provided loop does not contain `this`!");
}

Value *AffAcc::getAddrValue() const {
  assert(getBaseAddr(0u) && "has an address");
  if (isWrite()) {
    return cast<StoreInst>(accesses[0])->getPointerOperand();
  } else {
    return cast<LoadInst>(accesses[0])->getPointerOperand();
  }
}

///SCEV of base Address for the base address at a given dimension
const SCEV *AffAcc::getBaseAddr(unsigned dim) const { assert(dim < baseAddresses.size()); return baseAddresses[dim]; }

///SCEV of base Address outside of `L`
const SCEV *AffAcc::getBaseAddr(const Loop *L) const { return getBaseAddr(loopToDimension(L)); }

///SCEV of step for the dimension `dim` (that means there is no step for `dim` = 0)
const SCEV *AffAcc::getStep(unsigned dim) const { assert(dim < steps.size()); return steps[dim]; }

///SCEV of rep for the dimension `dim` (that means there is no rep for `dim` = 0)
const SCEV *AffAcc::getRep(unsigned dim) const { 
  assert(dim < reps.size()); 
  if (!reps[dim] || !reps[dim]->isAvailable()) return nullptr;
  return reps[dim]->getSCEV(); 
}

///get Loop for given `dim` (that means there is no Loop for `dim` = 0)
const Loop *AffAcc::getLoop(unsigned dim) const { assert(dim < containingLoops.size()); return containingLoops[dim]; }

///get containing loops from inner- to outermost
ArrayRef<const Loop *> AffAcc::getContainingLoops() const { return ArrayRef<const Loop *>(containingLoops); }

//dump info known for this AffAcc up to some loop L
void AffAcc::dumpInLoop(const Loop *L) const {
  errs()<<"Affine Access of \n";
  int dimension = getMaxDimension();
  if (L) dimension = std::min((int)loopToDimension(L), dimension);
  for (auto *I : accesses) errs()<<*I<<"\n";
  if (dimension < 0) errs()<<"\t<malformed>\n";
  for (int dim = 0; dim <= dimension && dim <= getMaxDimension(); dim++){
    const SCEV *s = getStep(dim);
    const SCEV *r = getRep(dim);
    const SCEV *a = getBaseAddr(dim);
    errs()<<"\tdim = "<<dim<<", step = "; 
    if (s) errs()<<*s;
    else errs()<<"<nullptr>"; 
    errs()<<", rep = ";
    if (r) errs()<<*r;
    else errs()<<"<nullptr>";
    errs()<<", well-formed = "<<this->isWellFormed(dim);
    errs()<<"\n";
    errs()<<"\taddress = ";
    if (a) errs()<<*a;
    else errs()<<"<nullptr>";
    errs()<<"\n";
    errs()<<"\tloop header = ";
    if (getLoop(dim)) errs()<<getLoop(dim)->getHeader()->getNameOrAsOperand();
    else errs()<<"<nullptr>";
    errs()<<"\n";
  }
}

//dump all info known about this AffAcc
void AffAcc::dump() const { dumpInLoop(nullptr); }

//get the actual conflict between this and the AffAcc in the pair for some loop L
AffAccConflict AffAcc::fromConflictPair(const detail::DenseMapPair<AffAcc*, std::pair<const Loop*, AffAccConflict>> &p, const Loop *L) const {
  const Loop *S = p.getSecond().first;
  if (S == L || L->contains(S)) { //if start is L or more "inner" loop
    if (!isWellFormed(L) || !p.first->isWellFormed(L)) return AffAccConflict::Bad; //if either is not well-formed "demote" the conflict to bad (but only if exists)
    return p.getSecond().second;
  }
  return AffAccConflict::NoConflict;
}

//get the actual conflict between this and A for loop L
AffAccConflict AffAcc::getConflict(AffAcc *A, const Loop *L) const {
  auto p = conflicts.find(A);
  if (p != conflicts.end()) {
    return fromConflictPair(*p, L);
  }
  return AffAccConflict::NoConflict;
}

/// returns a vector of (AffAcc *, conflict) pairs containing all the conflicts that `this` has at loop `L`
/// It is guaranteed that conflict is never NoConflict
std::vector<std::pair<AffAcc*, AffAccConflict>> AffAcc::getConflicts(const Loop *L) const {
  std::vector<std::pair<AffAcc*, AffAccConflict>> res;
  for (const auto &p : conflicts) {
    assert(p.first);
    assert(p.getSecond().first);
    AffAccConflict kind = fromConflictPair(p, L);
    if (kind != AffAccConflict::NoConflict) res.push_back(std::make_pair(p.first, kind));
  }
  return res;
}

MemoryUseOrDef *AffAcc::getMemoryAccess() { return MA; }

//add conflict with A, where StartL is innermost shared loop, with conflict classification `kind`
void AffAcc::addConflict(AffAcc *A, const Loop *StartL, AffAccConflict kind){
  assert(StartL);
  assert(conflicts.find(A) == conflicts.end() && "no conflict for A yet");
  assert(kind == AffAccConflict::Bad || (isWellFormed(StartL) && A->isWellFormed(StartL)));
  conflicts.insert(std::make_pair(A, std::make_pair(StartL, kind)));
}

//promote `this` if possible.
//`LR` should be the rep of the next outer loop where this is not (yet) well-formed
// if successful, `this` is well-formed for LR->getLoop() afterwards.
bool AffAcc::promote(LoopRep *LR){
  if (!LR->isAvailable()) return false;
  unsigned newDim = (unsigned)(getMaxDimension() + 1); //getMaxDimension() >= -1
  if (getLoop(newDim) != LR->getLoop()) return false;
  LLVM_DEBUG(dbgs()<<"promote: (1) loops match, ");
  bool possible = true;
  Instruction *Point = LR->getLoop()->getLoopPreheader()->getTerminator();
  //check all current reps and steps
  for (unsigned dim = 1; dim < newDim; dim++){ 
    possible &= isSafeToExpandAt(getStep(dim), Point, SE);
    possible &= reps[dim]->isSafeToExpandBefore(LR->getLoop());
  }
  if (possible) LLVM_DEBUG(dbgs()<<"can expand (2) current rep & step, ");
  //check rep and step of new dimension
  possible &= steps.size() > newDim && isSafeToExpandAt(getStep(newDim), Point, SE);
  possible &= LR->isSafeToExpandBefore(LR->getLoop());
  if (possible) LLVM_DEBUG(dbgs()<<"(3) new rep & step, ");
  //check base address
  possible &= !SCEVContainsCouldNotCompute(getBaseAddr(newDim)) && isSafeToExpandAt(getBaseAddr(newDim), Point, SE);
  if (possible) LLVM_DEBUG(dbgs()<<"and (4) new base addr!");
  LLVM_DEBUG(dbgs()<<"\n");
  if (!possible) return false;

  reps.push_back(LR); //changes getMaxDimension()
  return true;
}

//Code-gen for base address
Value *AffAcc::expandBaseAddr(unsigned dimension, Type *ty, Instruction *InsertBefore){
  assert(isWellFormed(dimension));
  InsertBefore = InsertBefore ? InsertBefore : reps[dimension]->getLoop()->getLoopPreheader()->getTerminator();
  if (!isSafeToExpandAt(getBaseAddr(dimension), InsertBefore, SE)){
    LLVM_DEBUG(dbgs()<<"data not expanable here (note: only preheader guaranteed)\n");
    LLVM_DEBUG(dbgs()<<"SCEV (dim = "<<dimension<<")= "<<*getBaseAddr(dimension)<<"\n");
    LLVM_DEBUG(dbgs()<<"in block:\n"; InsertBefore->getParent()->dump());
    LLVM_DEBUG(dbgs()<<"before inst: "<<*InsertBefore<<"\n");
    LLVM_DEBUG(this->dump());
    llvm_unreachable("cannot expand SCEV at desired location");
  }
  SCEVExpander ex(SE, reps[dimension]->getLoop()->getHeader()->getModule()->getDataLayout(), "addr");
  ex.setInsertPoint(InsertBefore);
  return castToSize(ex.expandCodeFor(getBaseAddr(dimension)), ty, InsertBefore);
}

//code-gen for step
Value *AffAcc::expandStep(unsigned dimension, Type *ty, Instruction *InsertBefore){
  assert(isWellFormed(dimension) && dimension > 0u);
  InsertBefore = InsertBefore ? InsertBefore : reps[dimension]->getLoop()->getLoopPreheader()->getTerminator();
  assert(isSafeToExpandAt(getStep(dimension), InsertBefore, SE) && "data not expanable here (note: only preheader guaranteed)");
  SCEVExpander ex(SE, reps[dimension]->getLoop()->getHeader()->getModule()->getDataLayout(), "step");
  ex.setInsertPoint(InsertBefore);
  return castToSize(ex.expandCodeFor(getStep(dimension)), ty, InsertBefore);
}

//code-gen for rep (calls code-gen of the LoopRep)
Value *AffAcc::expandRep(unsigned dimension, Type *ty, Instruction *InsertBefore){
  assert(isWellFormed(dimension) && dimension > 0u);
  InsertBefore = InsertBefore ? InsertBefore : reps[dimension]->getLoop()->getLoopPreheader()->getTerminator();
  if (!isSafeToExpandAt(getRep(dimension), InsertBefore, SE)) {
    getRep(dimension)->dump();
    InsertBefore->dump();
    InsertBefore->getParent()->dump();
    this->dump();
  }
  return reps[dimension]->expandAt(ty, InsertBefore);
}

//code-gen for all info needed to know the square affine access pattern inside of L
//guaranteed to work if `Point` is the terminator of preheader of L
ExpandedAffAcc AffAcc::expandAt(const Loop *L, Instruction *Point, 
  Type *PtrTy, IntegerType *ParamTy) 
{
  if (!Point) Point = L->getLoopPreheader()->getTerminator();
  IRBuilder<> builder(Point);
  assert(isWellFormed(L));
  std::vector<Value *> reps, steps, ranges, prefixsum_ranges;
  const unsigned dim = loopToDimension(L);
  Value *Addr = expandBaseAddr(dim, PtrTy, Point);
  IntegerType *SizeTy = IntegerType::get(SE.getContext(), (unsigned)SE.getTypeSizeInBits(Addr->getType()));
  Value *psum = nullptr;
  Value *LowerBound = builder.CreatePtrToInt(Addr, SizeTy, "lb");
  Value *UpperBound = LowerBound;
  std::vector<std::pair<const SCEV *, int>> known;
  for (int d = 1u; d < getMaxDimension(); d++) {
    known.push_back(std::make_pair(this->reps[d]->getSCEVPlusOne(), 1));
  }
  for (unsigned i = 1u; i <= dim; i++) {
    reps.push_back(expandRep(i, ParamTy, Point));
    steps.push_back(expandStep(i, ParamTy, Point));
    Value *r = reps.back();
    Value *st = steps.back();
    ranges.push_back(builder.CreateMul(r, st, formatv("range.{0}d", i)));
    if (psum) psum = builder.CreateAdd(psum, ranges.back(), formatv("prefsum.range.{0}d", i));
    else psum = ranges.back();
    prefixsum_ranges.push_back(psum);
    auto sign = findSign(getStep(i), SE, known);
    if (sign.hasValue()) {
      if (sign.getValue() < 0) LowerBound = builder.CreateAdd(LowerBound, builder.CreateSExtOrTrunc(ranges.back(), SizeTy, "lb.dec"));
      else if (sign.getValue() > 0) UpperBound = builder.CreateAdd(UpperBound, builder.CreateZExtOrTrunc(ranges.back(), SizeTy, "ub.inc"));
      //else sign == 0: no action needed
    } else { //we do not know sign! need to test at runtime
      Value *Test = builder.CreateICmpSGE(ranges.back(), ConstantInt::get(ParamTy, 0), "test.nonnegative"); //FIXME: does not work for unsigned values > 2^30
      LowerBound = builder.CreateSelect(
        builder.CreateNot(Test, formatv("not.test.{0}d", i)), 
        builder.CreateSExtOrTrunc(ranges.back(), SizeTy, formatv("range.{0}d.sext", i)), 
        ConstantInt::get(SizeTy, 0)
      );
      UpperBound = builder.CreateSelect(
        Test,
        builder.CreateZExtOrTrunc(ranges.back(), SizeTy, formatv("range.{0}d.zext", i)),
        ConstantInt::get(SizeTy, 0)
      );
    }
  }
  ExpandedAffAcc Aexp(this, Addr, steps, reps, ranges, prefixsum_ranges, LowerBound, UpperBound);
  return Aexp;
}


// ================= MemDep ==============

bool MemDep::alias(Value *A, Value *B) { return !A || !B || AA.alias(A, B) != AliasResult::NoAlias; }
bool MemDep::alias(MemoryUseOrDef *A, MemoryUseOrDef *B) { 
  if (!hasMemInst(A) || !hasMemInst(B)) return false; //the memoryUseOrDef does not correspond to an instruction => no problem
  else return alias(getAddress(A), getAddress(B)); 
}

//returns all MemoryDefs that might clobber MA
//i.e. we cannot be sure at compile-time that they *don't* clobber MA
DenseSet<MemoryUseOrDef *> MemDep::findClobbers(MemoryUseOrDef *MA){
  DenseSet<MemoryUseOrDef *> res;
  std::deque<MemoryAccess *> worklist;
  DenseSet<MemoryAccess *> vis;
  worklist.push_back(MA->getDefiningAccess());
  while (!worklist.empty()) {
    MemoryAccess *A = worklist.front(); worklist.pop_front();
    if (!A) continue;
    if (vis.find(A) != vis.end()) continue;
    if (A == MA) continue;
    vis.insert(A);
    if (MemoryDef *D = dyn_cast<MemoryDef>(A)) {
      if (alias(D, MA)) {
        res.insert(D);
      }
      worklist.push_back(D);
    } else {
      MemoryPhi *P = cast<MemoryPhi>(A);
      for (unsigned i = 0u; i < P->getNumOperands(); i++) {
        worklist.push_back(P->getOperand(i));
      }
    }
  }
  return res;
}

//find all MemoryUse's or MemoryDef's that might be clobbered by MA (might = must OR we do not know at compile-time)
DenseSet<MemoryUseOrDef *> MemDep::findClobberUsers(MemoryDef *MA) {
  DenseSet<MemoryUseOrDef *> res;
  std::deque<MemoryAccess *> worklist;
  DenseSet<MemoryAccess *> vis;
  for (auto U = MA->use_begin(); U != MA->use_end(); ++U) {
    worklist.push_back(cast<MemoryAccess>(U->getUser()));
  }
  while (!worklist.empty()){
    MemoryAccess *A = worklist.front(); worklist.pop_front();
    if (!A) continue;
    if (vis.find(A) != vis.end()) continue;
    vis.insert(A);
    if (MemoryUse *U = dyn_cast<MemoryUse>(A)) {
      if (alias(U, MA)) res.insert(U);
    } else if (MemoryDef *D = dyn_cast<MemoryDef>(A)) {
      if (alias(D, MA)) {
        res.insert(D);
      }
      worklist.push_back(D);
    } else {
      assert(isa<MemoryPhi>(A));
      for (auto U = A->use_begin(); U != A->use_end(); ++U) {
        worklist.push_back(cast<MemoryAccess>(U->getUser()));
      }
    }
  }
  return res;
}

//================== Affine Access ===========================================================

//constructor of analysis result, immediately computes all necessary information
AffineAccess::AffineAccess(
    Function &F, ScalarEvolution &SE, DominatorTree &DT, 
    LoopInfo &LI, MemorySSA &MSSA, AAResults &AA, 
    DependenceInfo &DI
  ) : SE(SE), DT(DT), LI(LI), MSSA(MSSA), AA(AA), DI(DI), MD(MSSA, AA)
{
  for (Loop *L : LI.getTopLevelLoops()){
    auto all = analyze(L, ArrayRef<const Loop *>());
    addAllConflicts(*all);
    all.release();
  }
}

//DFS over loop tree, constructs an AffAcc for each memory access and tries to promote it as far as possible
std::unique_ptr<std::vector<AffAcc *>> AffineAccess::analyze(Loop *Parent, ArrayRef<const Loop *> loopPath){
  LLVM_DEBUG(dbgs()<<"analyze: loop          : "<<Parent->getHeader()->getNameOrAsOperand()<<"\n");

  //LoopRep for Parent
  LoopRep *ParentLR = new LoopRep(Parent, loopPath, SE, DT);
  reps.insert(std::make_pair(Parent, ParentLR)); //add Parent to LoopReps

  //prepare path
  std::vector<const Loop *> path; 
  path.push_back(Parent); //add Parent to path
  for (auto *L : loopPath) path.push_back(L);
  
  //prepare results
  auto all = std::make_unique<std::vector<AffAcc *>>();
  auto &promoted = promotedAccesses.insert(std::make_pair(Parent, SmallVector<AffAcc *, 2u>())).first->getSecond();

  //promote subloop accesses
  for (Loop *L : Parent->getSubLoops()){
    std::unique_ptr<std::vector<AffAcc *>> accs = analyze(L, ArrayRef<const Loop *>(path));
    all->reserve(accs->size());
    LoopRep *LR = reps.find(L)->second; //guaranteed to exist, no check needed
    bool canPromote = LR->isAvailable() && ParentLR->isAvailable() && LR->isOnAllCFPathsOfParentIfExecuted();
    for (AffAcc *A : *accs){
      all->push_back(A);
      if (canPromote){ //L is well-formed and on all CF-paths if its rep is >0 at run-time
        if (A->promote(ParentLR)){
          promoted.push_back(A); //guaranteed to exist
        }
      }
    }
    accs.release();
  }

  //promote accesses from this loop
  for (BasicBlock *BB : Parent->getBlocks()){
    if (LI.getLoopFor(BB) != Parent) continue; //skip BB as it was already processed in a subloop
    for (Instruction &I : *BB){
      MemoryUseOrDef *MA = MSSA.getMemoryAccess(&I);
      if (MA && hasMemInst(MA) && access.find(MA) == access.end()){ //no AffAcc for this memory access yet!
        Value *Addr = getAddress(MA);
        const SCEV *AddrSCEV = nullptr;
        if (Addr) AddrSCEV = SE.getSCEV(Addr);
        AffAcc *A = new AffAcc(ArrayRef<Instruction *>(&I), AddrSCEV, MA, ArrayRef<const Loop *>(path), SE);
        all->push_back(A);
        access.insert(std::make_pair(MA, A));
        if (ParentLR->isAvailable()){
          bool onAllCFPaths = true;
          for (Instruction *I : A->getAccesses()) onAllCFPaths &= isOnAllControlFlowPaths(I->getParent(), Parent, DT);
          if (onAllCFPaths && A->promote(ParentLR)){
            promoted.push_back(A); //guaranteed to exist
          }
        }
      }
    }
  }
  
  LLVM_DEBUG(dbgs()<<"analyze: done with loop: "<<Parent->getHeader()->getNameOrAsOperand()<<"\n");
  
  return all;
}

//given the list of all AffAccs in a loop-tree, this finds all the conflicts between them
void AffineAccess::addAllConflicts(const std::vector<AffAcc *> &all) {
  for (AffAcc *A : all) {
    assert(A);
    const Loop *outerMostExpandableExl = A->getDeepestMalformed();
    DenseSet<MemoryUseOrDef *> c;
    if (A->isWrite()){
      c = MD.findClobberUsers(cast<MemoryDef>(A->getMemoryAccess()));
    } else {
      c = MD.findClobbers(A->getMemoryAccess());
    }
    for (MemoryUseOrDef *D : c) {
      if (A->getMemoryAccess() == D || !hasMemInst(D)) continue;
      auto p = access.find(D);
      if (p == access.end()) continue;
      AffAcc *B = p->second;
      auto r = calcConflict(A, B);
      if (r.first != AffAccConflict::NoConflict) A->addConflict(B, r.second, r.first);
      updateOutermostExpandableExcl(outerMostExpandableExl, r.first, r.second, B->getDeepestMalformed());
      assert(!outerMostExpandableExl || outerMostExpandableExl->contains(A->getMemoryAccess()->getBlock()));
    }

    ArrayRef<const Loop *> loops = A->getContainingLoops();
    for (const Loop *L : loops) {
      if (!L) continue;
      if (L == outerMostExpandableExl) break;
      if (!(!L || A->isWellFormed(L))){
        if (L) LLVM_DEBUG(L->dump());
        if (outerMostExpandableExl) LLVM_DEBUG(outerMostExpandableExl->dump());
        LLVM_DEBUG(A->dump());
        llvm_unreachable("this should not happen!");
      }
      assert(!L || A->isWellFormed(L));
      auto p = expandableAccesses.find(L);
      if (p == expandableAccesses.end()){
        p = expandableAccesses.insert(std::make_pair(L, SmallVector<AffAcc*, 3U>())).first;
      } 
      p->getSecond().push_back(A);
    }
  }
}

//classify conflict between Read and Write
AffAccConflict AffineAccess::calcRWConflict(AffAcc *Read, AffAcc *Write, const Loop *L) const {
  assert(!Read->isWrite());
  assert(Write->isWrite());
  if (!L->contains(Read->getMemoryAccess()->getBlock()) || !L->contains(Write->getMemoryAccess()->getBlock())) return AffAccConflict::NoConflict;
  if (!Read->isWellFormed(L) || !Write->isWellFormed(L)) return AffAccConflict::Bad;
  MemoryUseOrDef *r = Read->getMemoryAccess();
  MemoryUseOrDef *w = Write->getMemoryAccess();
  Value *Addr = getAddress(r);
  Value *DAddr = getAddress(w);
  bool dominates = MSSA.dominates(r, w);
  if (Addr && DAddr && AA.alias(Addr, DAddr) == NoAlias) return AffAccConflict::NoConflict;
  AffAccConflict kind = AffAccConflict::Bad;
  if (!dominates) { //read does not dominate write ==> R maybe after W
    kind = AffAccConflict::MustNotIntersect;
  } else { //read dominates write ==> W is after R
    kind = AffAccConflict::MustNotIntersect;
    //exception: we know that the store always happens to a position already written from if the store is to same address as write (FIXME: CONSERVATIVE)
    //but the steps needs to be != 0 such that there is no dependence from one iteration to the next
    bool nonzeroSteps = true;
    unsigned dr = Read->loopToDimension(L);
    unsigned dw = Write->loopToDimension(L);
    while (Read->isWellFormed(dr) && Write->isWellFormed(dw)) {
      nonzeroSteps &= SE.isKnownNonZero(Read->getStep(dr++)) && SE.isKnownNonZero(Write->getStep(dw++));
    }
    if ((Addr && DAddr && AA.alias(Addr, DAddr) == MustAlias && nonzeroSteps)
      || (accessPatternsAndAddressesMatch(Read, Write, L) && nonzeroSteps)) 
    {
      kind = AffAccConflict::NoConflict;
    }
  }
  return kind;
}

///returns the kind of conflict (and innermost common loop) that A and B have assuming there is some memory dependency
///does not check for the memory dependency itself for to peformance
std::pair<AffAccConflict, const Loop*> AffineAccess::calcConflict(AffAcc *A, AffAcc *B) const {
  assert((A->isWrite() || B->isWrite()) && "conflict between two reads ???");
  const Loop *const innermostCommon = findFirstContaining(A->getContainingLoops(), B->getMemoryAccess()->getBlock());
  if (!innermostCommon) return std::make_pair(AffAccConflict::NoConflict, innermostCommon);
  if (!A->isWrite()) std::swap(A, B); //we know at least one of them is write, swap so that one is A
  AffAccConflict kind = AffAccConflict::Bad; //assume Bad at beginning
  if (A->isWellFormed(innermostCommon) && B->isWellFormed(innermostCommon)) {
    if (B->isWrite()) kind = AffAccConflict::MustNotIntersect; //WaW
    else kind = calcRWConflict(B, A, innermostCommon); //B is read and A is write
  }
  //at this point, even if the two may alias, we assume the chance is high that they do at runtime 
  //if their base addresses share some SCEVUnknowns (ie. some Value's) (FIXME: this is CONSERVATIVE)
  if (kind == AffAccConflict::MustNotIntersect){
    const Loop *L = innermostCommon->getParentLoop();
    const Loop *Last = innermostCommon;
    while (L && A->isWellFormed(L) && B->isWellFormed(L)) { //traverse up the loop-tree up to the point where one of them is not wellformed anymore
      Last = L;
      L = L->getParentLoop();
    }
    if (shareValues(A->getBaseAddr(Last), B->getBaseAddr(Last))) kind = AffAccConflict::Bad;
  }
  return std::make_pair(kind, innermostCommon);
}

//checks whether access patterns (step, rep) match up to some loop L
bool AffineAccess::accessPatternsMatch(const AffAcc *A, const AffAcc *B, const Loop *L) const {
  unsigned dimA = A->loopToDimension(L);
  unsigned dimB = B->loopToDimension(L);
  if (dimA != dimB) return false;
  for (unsigned i = 1u; i <= dimA; i++){
    if (A->getLoop(i) != B->getLoop(i)) return false;
    if (!SCEVEquals(A->getRep(i), B->getRep(i), SE)) return false;
    if (!SCEVEquals(A->getStep(i), B->getStep(i), SE)) return false;
  }
  return true;
}

//checks whether step, rep, and base address matches up to some loop L
bool AffineAccess::accessPatternsAndAddressesMatch(const AffAcc *A, const AffAcc *B, const Loop *L) const {
  if (!accessPatternsMatch(A, B, L)) return false;
  return SCEVEquals(A->getBaseAddr(A->loopToDimension(L)), B->getBaseAddr(B->loopToDimension(L)), SE);
}

//simple access methods
ScalarEvolution &AffineAccess::getSE() const { return this->SE; }
DominatorTree &AffineAccess::getDT()const { return this->DT; }
LoopInfo &AffineAccess::getLI() const { return this->LI; }
MemorySSA &AffineAccess::getMSSA() const { return this->MSSA; }
AAResults &AffineAccess::getAA() const { return this->AA; }
DependenceInfo &AffineAccess::getDI() const { return this->DI; }
SmallVector<Loop *, 4U> AffineAccess::getLoopsInPreorder() const { return this->LI.getLoopsInPreorder(); }

//get accesses with no bad conflicts for some loop L
//guarantees:
// no bad conflicts with any other memory instruction in L
// is well formed for L
// if conflictFreeOnly: has no conflicts at all (only NoConflict) ==> no run-time checks necessary
std::vector<AffAcc *> AffineAccess::getExpandableAccesses(const Loop *L, bool conflictFreeOnly) {
  auto p = expandableAccesses.find(L);
  std::vector<AffAcc *> res;
  if (p == expandableAccesses.end()) return res;
  for (AffAcc *A : p->getSecond()){
    if (!conflictFreeOnly || A->getConflicts(L).empty()) res.push_back(A);
  }
  return res;
}

// code-gen: calls code-gen for all AffAccs in list, 
// generates run-time checks for conflicts,
// generates run-time checks for loop-trip-counts (if repChecks = true)
// ANDs all the rt-checks to a single Value and writes it into BoundCheck
std::vector<ExpandedAffAcc> 
AffineAccess::expandAllAt(ArrayRef<AffAcc *> Accs, const Loop *L, 
  Instruction *Point, Value *&BoundCheck, 
  Type *PtrTy, IntegerType *ParamTy, bool conflictChecks, bool repChecks) 
{
  assert(Point);
  IRBuilder<> builder(Point);

  DenseMap<AffAcc*, ExpandedAffAcc> exps;
  for (AffAcc *A : Accs) { //expand the requested AffAcc's
    exps.insert(std::make_pair(A, std::move(A->expandAt(L, Point, PtrTy, ParamTy))));
  }

  std::vector<Value *> checks;
  if (conflictChecks) {
    DenseSet<AffAcc*> done; //keep track of which were done to not make duplicate checks
    for (AffAcc *A : Accs) {
      auto conflicts = A->getConflicts(L); //get all AffAcc's with which A conflicts
      for (const auto &p : conflicts) {
        AffAcc *B = p.first;
        if (done.find(B) != done.end()) continue; //this conflict was already handled when A was B (symmetry)
        AffAccConflict kind = std::max(p.second, B->getConflict(A, L)); //take worse conflict
        switch (kind)
        {
        case AffAccConflict::NoConflict:
          break; //nothing to do
        case AffAccConflict::MustNotIntersect: {
          auto e = exps.find(B);
          if (e == exps.end()) { //if B was not yet expanded, do that and update the iterator for the pair in exps
            e = exps.insert(std::make_pair(B, std::move(B->expandAt(L, Point, PtrTy, ParamTy)))).first;
          }
          assert(e->first == B);
          ExpandedAffAcc &expB = e->getSecond();
          ExpandedAffAcc &expA = exps.find(A)->getSecond(); //guaranteed to exist
          Value *x = builder.CreateICmpULT(expA.UpperBound, expB.LowerBound, "no.inter.ab");
          Value *y = builder.CreateICmpULT(expB.UpperBound, expA.LowerBound, "no.inter.ba");
          checks.push_back(builder.CreateOr(x, y, "no.intersect"));
          break;
        }
        case AffAccConflict::Bad:
          llvm_unreachable("cannot expand the given accesses because some of them have a bad conflict in L!");
          break;
        default:
          llvm_unreachable("unknown conflict type");
        }
      }
    }
  }

  if (repChecks) {
    DenseSet<const Loop *> loops; //find all relevant loops
    for (auto &p : exps) {
      AffAcc *A = p.first;
      for (unsigned d = 0u; d < A->loopToDimension(L); d++) {
        const Loop *x = A->getLoop(d);
        if (x) loops.insert(x);
      }
    }
    for (const Loop *M : loops) { //generate checks for the loops
      auto p = reps.find(M);
      assert(p != reps.end());
      checks.push_back(p->second->expandLoopGuard(Point));
    }
  }

  if (checks.empty()) BoundCheck = builder.getTrue();
  else BoundCheck = builder.CreateAnd(checks);

  std::vector<ExpandedAffAcc> res;
  for (AffAcc *A : Accs) {
    res.push_back(std::move(exps.find(A)->getSecond())); //(can move because exps not needed anymore)
  }
  return res;
}

//================== Affine Access Analysis ==================================================

AnalysisKey AffineAccessAnalysis::Key;

// run of the analysis pass
AffineAccess AffineAccessAnalysis::run(Function &F, FunctionAnalysisManager &FAM) {
  
  LLVM_DEBUG(dbgs()<<"running AffineAccessAnalysis on "<<F.getName()<<"\n");

  LoopInfo &LI = FAM.getResult<LoopAnalysis>(F);
  DominatorTree &DT = FAM.getResult<DominatorTreeAnalysis>(F);
  ScalarEvolution &SE = FAM.getResult<ScalarEvolutionAnalysis>(F);
  auto &MSSAA = FAM.getResult<MemorySSAAnalysis>(F);
  MemorySSA &MSSA = MSSAA.getMSSA();
  AAResults &AA = FAM.getResult<AAManager>(F);
  DependenceInfo &DI = FAM.getResult<DependenceAnalysis>(F);
  
  return AffineAccess(F, SE, DT, LI, MSSA, AA, DI);
}

//================== Affine Acces Analysis Pass for opt =======================================
PreservedAnalyses AffineAccessAnalysisPass::run(Function &F, FunctionAnalysisManager &FAM) {
  AffineAccess AA = FAM.getResult<AffineAccessAnalysis>(F);
  for (const Loop *L : AA.getLI().getLoopsInPreorder()){
    L->dump();
    for (const AffAcc *A : AA.getExpandableAccesses(L)){
      A->dumpInLoop(L);
    }
  }
  return PreservedAnalyses::all();
}

