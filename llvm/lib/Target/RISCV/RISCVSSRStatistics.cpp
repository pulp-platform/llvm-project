//===- RISCVSSRStatistics.cpp - Reassociate Fast FP insts and move SSR push/pop intrinsics ------------------===//
//
// ???
//
//===----------------------------------------------------------------------===//
//
// count how many memory accesses there are and at what loop depth
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
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/IntrinsicsRISCV.h"
#include <algorithm>
#include <vector>
#include <limits>

using namespace llvm;

namespace {

  class SSRStatistics: public FunctionPass {
    const TargetLowering *TLI = nullptr;

  public:
    static char ID; // Pass identification, replacement for typeid

    SSRStatistics() : FunctionPass(ID) {
      initializeSSRStatisticsPass(*PassRegistry::getPassRegistry());
    }

    bool runOnFunction(Function &F) override;

    virtual void getAnalysisUsage(AnalysisUsage& AU) const override {
      AU.addRequired<LoopInfoWrapperPass>();
    }
  };

} // end anonymous namespace

bool SSRStatistics::runOnFunction(Function &F) {

  DenseMap<const Loop *, unsigned> ld;
  DenseMap<const Loop *, unsigned> st;
  DenseMap<const Loop *, unsigned> push;
  DenseMap<const Loop *, unsigned> pop;

  const LoopInfo &LI = getAnalysis<LoopInfoWrapperPass>().getLoopInfo();
  std::vector<const Loop *> s;
  for (const auto *L : LI.getTopLevelLoops()) {
    s.push_back(L);
  }
  for (const auto &BB : F) {
    const Loop *L = LI.getLoopFor(&BB);
    if (!L) continue;
    if (ld.find(L) == ld.end()) ld.insert(std::make_pair(L, 0));
    if (st.find(L) == st.end()) st.insert(std::make_pair(L, 0));
    if (push.find(L) == push.end()) push.insert(std::make_pair(L, 0));
    if (pop.find(L) == pop.end()) pop.insert(std::make_pair(L, 0));
    for (const Instruction &I : BB) {
      if (isa<LoadInst>(I)) {
        auto x = ld.find(L);
        assert(x != ld.end());
        x->getSecond() += 1;
      } else if (isa<StoreInst>(I)) {
        auto x = st.find(L);
        assert(x != st.end());
        x->getSecond() += 1;
      } else if (isa<IntrinsicInst>(I)) {
        const auto &In = cast<IntrinsicInst>(I);
        if (In.getIntrinsicID() == Intrinsic::riscv_ssr_pop) {
          auto x = pop.find(L);
          assert(x != pop.end());
          x->getSecond() += 1;
        } else if (In.getIntrinsicID() == Intrinsic::riscv_ssr_push) {
          auto x = push.find(L);
          assert(x != push.end());
          x->getSecond() += 1;
        }
      }
    }
  }

  errs()<<"\""<<F.getNameOrAsOperand()<<"\": {\n";
  for (const auto &p : ld) {
    const Loop *L = p.first;
    errs()<<"\t\""<<L->getHeader()->getNameOrAsOperand()<<"\": {\n";
    errs()<<"\t\t\"depth\": "<<L->getLoopDepth()<<",\n";
    errs()<<"\t\t\"loads\": "<<ld.find(L)->getSecond()<<",\n";
    errs()<<"\t\t\"stores\": "<<st.find(L)->getSecond()<<",\n";
    errs()<<"\t\t\"pushs\": "<<push.find(L)->getSecond()<<",\n";
    errs()<<"\t\t\"pops\": "<<pop.find(L)->getSecond()<<"\n";
    errs()<<"\t},\n";
  }
  errs()<<"},\n";
  

  return false;
}

// bool SSRStatistics::runOnFunction(Function &F) {

//   std::vector<unsigned> n_ld, n_st;
//   constexpr int max_depth = 5;
//   while (n_ld.size() <= max_depth) n_ld.push_back(0);
//   while (n_st.size() <= max_depth) n_st.push_back(0);

//   const LoopInfo &LI = getAnalysis<LoopInfoWrapperPass>().getLoopInfo();
//   for (const auto &BB : F) {
//     unsigned depth = LI.getLoopDepth(&BB);
//     assert(n_ld.size() > depth);
//     assert(n_st.size() > depth);
//     for (const Instruction &I : BB) {
//       if (isa<LoadInst>(I)) {
//         n_ld[depth] += 1;
//       } else if (isa<StoreInst>(I)) {
//         n_st[depth] += 1;
//       }
//     }
//   }

//   errs()<<F.getNameOrAsOperand();
//   for (int i = 0; i <= max_depth; i++) errs()<<", "<<n_ld[i];
//   for (int i = 0; i <= max_depth; i++) errs()<<", "<<n_st[i];
//   errs()<<"\n";

//   return false;
// }

char SSRStatistics::ID = 0;

INITIALIZE_PASS(SSRStatistics, "SSR", "SSR Statistics Pass", false, false)

FunctionPass *llvm::createSSRStatisticsPass() { return new SSRStatistics(); }
