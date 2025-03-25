//===-- SSRInference.cpp - Infer SSR usage --------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/Transforms/SSR/SSRInference.h"
#include "llvm/InitializePasses.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Target/TargetMachine.h"

#include "llvm/IR/Instruction.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/InstrTypes.h"
#include "llvm/IR/IRBuilder.h"

#include "llvm/Transforms/Utils/BasicBlockUtils.h"
#include "llvm/Transforms/Scalar/ADCE.h"

#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ScalarEvolutionExpressions.h"
#include "llvm/Analysis/AffineAccessAnalysis.h"
#include "llvm/Transforms/Utils/ScalarEvolutionExpander.h"
#include "llvm/Transforms/Utils/FixIrreducible.h"
#include "llvm/Transforms/InstCombine/InstCombine.h"
#include "llvm/Transforms/Scalar/LoopStrengthReduce.h"
#include "llvm/Transforms/Scalar/LoopRotation.h"
#include "llvm/Transforms/Scalar/IndVarSimplify.h"
#include "llvm/Transforms/Scalar/SimplifyCFG.h"
#include "llvm/Transforms/Scalar/LoopFlatten.h"
#include "llvm/Transforms/Scalar/LoopUnrollAndJamPass.h"
#include "llvm/Transforms/Scalar/Reassociate.h"
#include "llvm/Transforms/Scalar/LICM.h"
#include "llvm/Transforms/SSR/SSRGeneration.h"

#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/Casting.h"

#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/IntrinsicsRISCV.h"

#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/TinyPtrVector.h"
#include "llvm/ADT/ilist.h"

#include <array>
#include <vector>

#define DEBUG_TYPE "ssr"

using namespace llvm;

PreservedAnalyses SSRInferencePass::run(Function &F, FunctionAnalysisManager &FAM){
  LLVM_DEBUG(dbgs()<<"SSR Inference Pass on function: "<<F.getNameOrAsOperand()<<"====================================================\n");
  FunctionPassManager FPM(false);
  FPM.addPass(FixIrreduciblePass());//turn some non-loops into loops
  FPM.addPass(LoopSimplifyPass());  //canonicalize loops
  FPM.addPass(LCSSAPass());         //put loops into LCSSA-form

  FPM.addPass(SSRGenerationPass()); //runs AffineAccess analysis and generates SSR intrinsics

  FPM.addPass(LoopSimplifyPass());  //canonicalize loops again
  FPM.addPass(InstCombinePass());   //removes phi nodes from LCSSA
  FPM.addPass(ADCEPass());          //remove potential dead instructions that result from SSR replacement
  FPM.addPass(createFunctionToLoopPassAdaptor(LICMPass())); //LICM of run-time checks if possible
  FPM.addPass(SimplifyCFGPass());   //simplifies CFG again
  FPM.addPass(LoopSimplifyPass());  //canonicalize loops again
  auto pa = FPM.run(F, FAM);
  LLVM_DEBUG(dbgs()<<"SSR Inference Pass on function: "<<F.getNameOrAsOperand()<<" done! =============================================\n");
  return pa;
}
