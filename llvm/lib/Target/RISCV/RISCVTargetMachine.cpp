//===-- RISCVTargetMachine.cpp - Define TargetMachine for RISCV -----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Implements the info about RISCV target spec.
//
//===----------------------------------------------------------------------===//

#include "RISCVTargetMachine.h"
#include "MCTargetDesc/RISCVBaseInfo.h"
#include "RISCV.h"
#include "RISCVTargetObjectFile.h"
#include "RISCVTargetTransformInfo.h"
#include "TargetInfo/RISCVTargetInfo.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/Analysis/TargetTransformInfo.h"
#include "llvm/CodeGen/GlobalISel/IRTranslator.h"
#include "llvm/CodeGen/GlobalISel/InstructionSelect.h"
#include "llvm/CodeGen/GlobalISel/Legalizer.h"
#include "llvm/CodeGen/GlobalISel/RegBankSelect.h"
#include "llvm/CodeGen/Passes.h"
#include "llvm/CodeGen/TargetLoweringObjectFileImpl.h"
#include "llvm/CodeGen/TargetPassConfig.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/InitializePasses.h"
#include "llvm/Support/FormattedStream.h"
#include "llvm/Support/TargetRegistry.h"
#include "llvm/Target/TargetOptions.h"
#include "llvm/Transforms/Scalar/Reassociate.h"
#include "llvm/Transforms/Scalar.h"
using namespace llvm;

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeRISCVTarget() {
  RegisterTargetMachine<RISCVTargetMachine> X(getTheRISCV32Target());
  RegisterTargetMachine<RISCVTargetMachine> Y(getTheRISCV64Target());
  auto *PR = PassRegistry::getPassRegistry();
  initializeGlobalISel(*PR);
  initializeRISCVMergeBaseOffsetOptPass(*PR);
  initializeRISCVExpandSSRPass(*PR);
  initializeSNITCHFrepLoopsPass(*PR);
  initializeRISCVExpandSDMAPass(*PR);
  initializeRISCVExpandPseudoPass(*PR);
  initializeRISCVExpandSSRPostRegAllocPass(*PR);
  initializeRISCVCleanupVSETVLIPass(*PR);
}

static StringRef computeDataLayout(const Triple &TT) {
  if (TT.isArch64Bit()) {
    return "e-m:e-p:64:64-i64:64-i128:128-n64-S128";
  } else {
    assert(TT.isArch32Bit() && "only RV32 and RV64 are currently supported");
    if (TT.getVendor() == Triple::HERO) {
      return "e-m:e-p:32:32-p1:64:32-i64:64-n32-S128-P0-A0";
    }
    return "e-m:e-p:32:32-i64:64-n32-S128";
  }
}

static Reloc::Model getEffectiveRelocModel(const Triple &TT,
                                           Optional<Reloc::Model> RM) {
  if (!RM.hasValue())
    return Reloc::Static;
  return *RM;
}

RISCVTargetMachine::RISCVTargetMachine(const Target &T, const Triple &TT,
                                       StringRef CPU, StringRef FS,
                                       const TargetOptions &Options,
                                       Optional<Reloc::Model> RM,
                                       Optional<CodeModel::Model> CM,
                                       CodeGenOpt::Level OL, bool JIT)
    : LLVMTargetMachine(T, computeDataLayout(TT), TT, CPU, FS, Options,
                        getEffectiveRelocModel(TT, RM),
                        getEffectiveCodeModel(CM, CodeModel::Small), OL),
      TLOF(std::make_unique<RISCVELFTargetObjectFile>()) {
  initAsmInfo();

  // RISC-V supports the MachineOutliner.
  setMachineOutliner(true);
}

const RISCVSubtarget *
RISCVTargetMachine::getSubtargetImpl(const Function &F) const {
  Attribute CPUAttr = F.getFnAttribute("target-cpu");
  Attribute TuneAttr = F.getFnAttribute("tune-cpu");
  Attribute FSAttr = F.getFnAttribute("target-features");

  std::string CPU =
      CPUAttr.isValid() ? CPUAttr.getValueAsString().str() : TargetCPU;
  std::string TuneCPU =
      TuneAttr.isValid() ? TuneAttr.getValueAsString().str() : CPU;
  std::string FS =
      FSAttr.isValid() ? FSAttr.getValueAsString().str() : TargetFS;
  std::string Key = CPU + TuneCPU + FS;
  auto &I = SubtargetMap[Key];
  if (!I) {
    // This needs to be done before we create a new subtarget since any
    // creation will depend on the TM and the code generation flags on the
    // function that reside in TargetOptions.
    resetTargetOptions(F);
    auto ABIName = Options.MCOptions.getABIName();
    if (const MDString *ModuleTargetABI = dyn_cast_or_null<MDString>(
            F.getParent()->getModuleFlag("target-abi"))) {
      auto TargetABI = RISCVABI::getTargetABI(ABIName);
      if (TargetABI != RISCVABI::ABI_Unknown &&
          ModuleTargetABI->getString() != ABIName) {
        report_fatal_error("-target-abi option != target-abi module flag");
      }
      ABIName = ModuleTargetABI->getString();
    }
    I = std::make_unique<RISCVSubtarget>(TargetTriple, CPU, TuneCPU, FS, ABIName, *this);
  }
  return I.get();
}

void RISCVTargetMachine::setTargetOptionsWithModuleMetadata(
    const Module &M LLVM_ATTRIBUTE_UNUSED) {
  StringRef ABIName = Options.MCOptions.getABIName();
  if (const MDString *ModuleTargetABI =
          dyn_cast_or_null<MDString>(M.getModuleFlag("target-abi"))) {
    StringRef ModuleABIName = ModuleTargetABI->getString();
    if (!ABIName.empty() && ModuleABIName != ABIName)
      report_fatal_error("-target-abi option != target-abi module flag");
    if (ABIName.empty())
      Options.MCOptions.ABIName = ModuleABIName.str();
  }
}

TargetTransformInfo
RISCVTargetMachine::getTargetTransformInfo(const Function &F) {
  return TargetTransformInfo(RISCVTTIImpl(this, F));
}

// A RISC-V hart has a single byte-addressable address space of 2^XLEN bytes
// for all memory accesses, so it is reasonable to assume that an
// implementation has no-op address space casts. If an implementation makes a
// change to this, they can override it here.
bool RISCVTargetMachine::isNoopAddrSpaceCast(unsigned SrcAS,
                                             unsigned DstAS) const {
  return true;
}

namespace {
class RISCVPassConfig : public TargetPassConfig {
public:
  RISCVPassConfig(RISCVTargetMachine &TM, PassManagerBase &PM)
      : TargetPassConfig(TM, PM) {}

  RISCVTargetMachine &getRISCVTargetMachine() const {
    return getTM<RISCVTargetMachine>();
  }

  void addIRPasses() override;
  bool addInstSelector() override;
  bool addIRTranslator() override;
  bool addLegalizeMachineIR() override;
  bool addRegBankSelect() override;
  bool addGlobalInstructionSelect() override;
  void addPreEmitPass() override;
  void addPreEmitPass2() override;
  void addPreSched2() override;
  void addPreRegAlloc() override;
};
} // namespace

TargetPassConfig *RISCVTargetMachine::createPassConfig(PassManagerBase &PM) {
  return new RISCVPassConfig(*this, PM);
}

void RISCVPassConfig::addIRPasses() {
  //addPass(createSSRReassociatePass()); //slow & incorrect, see top of file for more info
  //addPass(createReassociatePass()); does not reassociate fast FP-ops ???
  //addPass(createSSRStatisticsPass()); //counts number of load/store as well as number of streams
  addPass(createAtomicExpandPass());
  TargetPassConfig::addIRPasses();
}

bool RISCVPassConfig::addInstSelector() {
  addPass(createRISCVISelDag(getRISCVTargetMachine()));

  return false;
}

bool RISCVPassConfig::addIRTranslator() {
  addPass(new IRTranslator(getOptLevel()));
  return false;
}

bool RISCVPassConfig::addLegalizeMachineIR() {
  addPass(new Legalizer());
  return false;
}

bool RISCVPassConfig::addRegBankSelect() {
  addPass(new RegBankSelect());
  return false;
}

bool RISCVPassConfig::addGlobalInstructionSelect() {
  addPass(new InstructionSelect());
  return false;
}

void RISCVPassConfig::addPreSched2() {}

void RISCVPassConfig::addPreEmitPass() { 
  addPass(&BranchRelaxationPassID); 
}

void RISCVPassConfig::addPreEmitPass2() {
  addPass(createRISCVExpandPseudoPass());
  addPass(createPULPFixupHwLoops());
  addPass(createRISCVExpandSSRPostRegAllocPass());
  //FIXME: scheduling the post ra scheduler after ssr expand gives better results but is unsafe 
  //because it might move insts with ssr regs after ssr-disable (or before enable) or reorder them internally (change in order of stream!)
  // addPass(&PostRASchedulerID); 
  //addPass(createSNITCHAutoFrepPass()); //alternative to scheduling and anti-dep-breaking
  
  // Schedule the expansion of AMOs at the last possible moment, avoiding the
  // possibility for other passes to break the requirements for forward
  // progress in the LR/SC block.
  addPass(createRISCVExpandAtomicPseudoPass());
}

void RISCVPassConfig::addPreRegAlloc() {
  addPass(createRISCVExpandSDMAPass());
  addPass(createRISCVExpandSSRPass());
  addPass(createSNITCHFrepLoopsPass());
  if (TM->getOptLevel() != CodeGenOpt::None) {
    addPass(createRISCVMergeBaseOffsetOptPass());
    addPass(createRISCVCleanupVSETVLIPass());
    addPass(createPULPHardwareLoops());
  }
}
