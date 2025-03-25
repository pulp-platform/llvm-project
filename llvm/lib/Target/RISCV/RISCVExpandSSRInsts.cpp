//===-- RISCVExpandSSRInsts.cpp - Expand SSR pseudo instructions ---------===//
//
// Copyright 2021 ETH Zurich, University of Bologna.
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains a pass that expands SSR pseudo instructions into target
// instructions. This pass should be run before register allocation
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// The SSR are configured in a memory-mapped address space accessible through 
// the SCGGW(I)/SCGGR(I) instructions. The (I)mmediate instructions take the 
// address as an immediate. The Address map is as follows:
//
// | Word| Hex  | reg        |
// |-----|------|------------|
// | 0   | 0x00 | status     |
// | 1   | 0x01 | repeat     |
// | 2   | 0x02 | Bound 0    |
// | 3   | 0x03 | Bound 1    |
// | 4   | 0x04 | Bound 2    |
// | 5   | 0x05 | Bound 3    |
// | 6   | 0x06 | Stride 0   |
// | 7   | 0x07 | Stride 1   |
// | 8   | 0x08 | Stride 2   |
// | 9   | 0x09 | Stride 3   |
// |     |      | _reserved_ |
// | 24  | 0x18 | Rptr 0     |
// | 25  | 0x19 | Rptr 1     |
// | 26  | 0x1a | Rptr 2     |
// | 27  | 0x1b | Rptr 3     |
// | 28  | 0x1c | Wptr 0     |
// | 29  | 0x1d | Wptr 1     |
// | 30  | 0x1e | Wptr 2     |
// | 31  | 0x1f | Wptr 3     |
// 
// The data mover is selected in the lower 5 bits, the register offset is encoded
// in the upper 7 bits. The value passed to scfgX is therefore
//             addr = dm + reg << 5
//
// scfgw   rs1 rs2 # rs1=value rs2=addr
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "RISCVInstrInfo.h"
#include "RISCVTargetMachine.h"
#include "RISCVMachineFunctionInfo.h"

#include "llvm/CodeGen/LivePhysRegs.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/LowLevelType.h"
#include "llvm/ADT/SmallSet.h"
#include "llvm/Support/CommandLine.h"

using namespace llvm;

#define DEBUG_TYPE "riscv-ssr"

#define RISCV_EXPAND_SSR_NAME "RISCV SSR pseudo instruction expansion pass"

#define NUM_SSR 3

namespace {

class RISCVExpandSSR : public MachineFunctionPass {
public:
  const RISCVInstrInfo *TII;
  static char ID;

  RISCVExpandSSR() : MachineFunctionPass(ID) {
    initializeRISCVExpandSSRPass(*PassRegistry::getPassRegistry());
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

  StringRef getPassName() const override { return RISCV_EXPAND_SSR_NAME; }

private:

  const MachineFunction *MF;
  RISCVMachineFunctionInfo *RVFI;
  std::vector<MachineInstr *> MoveLoads;
  std::vector<MachineInstr *> MoveStores;

  bool expandMBB(MachineBasicBlock &MBB);
  bool expandMI(MachineBasicBlock &MBB, MachineBasicBlock::iterator MBBI,
                MachineBasicBlock::iterator &NextMBBI);
  bool expandSSR_Setup(MachineBasicBlock &MBB,
                         MachineBasicBlock::iterator MBBI);
  bool expandSSR_PushPop(MachineBasicBlock &MBB,
                         MachineBasicBlock::iterator MBBI);
  bool expandSSR_ReadWrite(MachineBasicBlock &MBB,
                         MachineBasicBlock::iterator MBBI);
  bool expandSSR_ReadWriteImm(MachineBasicBlock &MBB,
                         MachineBasicBlock::iterator MBBI);
  bool expandSSR_BoundStride(MachineBasicBlock &MBB,
                         MachineBasicBlock::iterator MBBI);
  bool expandSSR_EnDis(MachineBasicBlock &MBB,
                         MachineBasicBlock::iterator MBBI);
  bool expandSSR_SetupRep(MachineBasicBlock &MBB,
                         MachineBasicBlock::iterator MBBI);
  bool expandSSR_Barrier(MachineBasicBlock &MBB,
                         MachineBasicBlock::iterator MBBI,
                         MachineBasicBlock::iterator &NextMBBI);
  void handlePushPops();
};

char RISCVExpandSSR::ID = 0;

static Register getSSRFtReg(unsigned streamer) {
  unsigned AssignedReg = RISCV::F0_D + streamer;
  // Advance the iterator to the assigned register until the valid
  // register is found
  const TargetRegisterClass *RC = &RISCV::FPR64RegClass;
  TargetRegisterClass::iterator I = RC->begin();
  for (; *I != AssignedReg; ++I)
    assert(I != RC->end() && "AssignedReg should be a member of provided RC");
  return Register(*I);
}

bool RISCVExpandSSR::runOnMachineFunction(MachineFunction &MF) {
  TII = static_cast<const RISCVInstrInfo *>(MF.getSubtarget().getInstrInfo());
  this->MF = &MF;
  this->RVFI = MF.getInfo<RISCVMachineFunctionInfo>();
  this->MoveLoads.empty();
  this->MoveStores.empty();

  bool Modified = false;
  for (auto &MBB : MF)
    Modified |= expandMBB(MBB);

  handlePushPops();

  /// "Forcefully" add all SSR registers as live-in to all MBB in this MF
  if(Modified) {
    for (auto &MBB : MF) {
      for(unsigned ssr_no = 0; ssr_no < NUM_SSR; ++ssr_no)
        MBB.addLiveIn(getSSRFtReg(ssr_no));
      MBB.sortUniqueLiveIns();
    }
  }

  //errs()<<"\n ========================= DUMP MF ========================== \n";
  //MF.dump();
  //errs()<<"\n ======================= END DUMP MF ========================== \n";

  return Modified;
}

bool RISCVExpandSSR::expandMBB(MachineBasicBlock &MBB) {
  bool Modified = false;

  MachineBasicBlock::iterator MBBI = MBB.begin(), E = MBB.end();
  while (MBBI != E) {
    MachineBasicBlock::iterator NMBBI = std::next(MBBI);
    Modified |= expandMI(MBB, MBBI, NMBBI);
    MBBI = NMBBI;
  }
  MBB.sortUniqueLiveIns();

  return Modified;
}

bool RISCVExpandSSR::expandMI(MachineBasicBlock &MBB,
                                 MachineBasicBlock::iterator MBBI,
                                 MachineBasicBlock::iterator &NextMBBI) {
  // RISCVInstrInfo::getInstSizeInBytes hard-codes the number of expanded
  // instructions for each pseudo, and must be updated when adding new pseudos
  // or changing existing ones.
  switch (MBBI->getOpcode()) {
  case RISCV::PseudoSSRSetup_1D_R:
  case RISCV::PseudoSSRSetup_1D_W:
    return expandSSR_Setup(MBB, MBBI);
  case RISCV::PseudoSSRPush:
  case RISCV::PseudoSSRPop:
    return expandSSR_PushPop(MBB, MBBI);
  case RISCV::PseudoSSRRead:
  case RISCV::PseudoSSRWrite:
    return expandSSR_ReadWrite(MBB, MBBI);
  case RISCV::PseudoSSRReadImm:
  case RISCV::PseudoSSRWriteImm:
    return expandSSR_ReadWriteImm(MBB, MBBI);
  case RISCV::PseudoSSRSetupBoundStride_1D:
  case RISCV::PseudoSSRSetupBoundStride_2D:
  case RISCV::PseudoSSRSetupBoundStride_3D:
  case RISCV::PseudoSSRSetupBoundStride_4D:
    return expandSSR_BoundStride(MBB, MBBI);
  case RISCV::PseudoSSREnable:
  case RISCV::PseudoSSRDisable:
    return expandSSR_EnDis(MBB, MBBI);
  case RISCV::PseudoSSRSetupRepetition:
    return expandSSR_SetupRep(MBB, MBBI);
  case RISCV::PseudoSSRBarrier:
    return expandSSR_Barrier(MBB, MBBI, NextMBBI);
  }

  return false;
}

bool RISCVExpandSSR::expandSSR_Setup(MachineBasicBlock &MBB,
                                          MachineBasicBlock::iterator MBBI) {
  DebugLoc DL = MBBI->getDebugLoc();

  LLVM_DEBUG(dbgs() << "-- Expanding SSR Setup 1D\n");

  // select streamer based on first argument
  int dm_off = (int)MBBI->getOperand(0).getImm();

  // set repeat
  Register RepReg = MBBI->getOperand(1).getReg();
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SCFGWI)).addReg(RepReg).addImm(dm_off+(0x1<<5));
  // set bound 0
  Register BoundReg = MBBI->getOperand(2).getReg();
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SCFGWI)).addReg(BoundReg).addImm(dm_off+(0x2<<5));
  // set stride 0
  Register StrideReg = MBBI->getOperand(3).getReg();
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SCFGWI)).addReg(StrideReg).addImm(dm_off+(0x6<<5));
  // set read/write pointer
  Register PtrReg = MBBI->getOperand(4).getReg();
  if(MBBI->getOpcode() == RISCV::PseudoSSRSetup_1D_R)
    BuildMI(MBB, MBBI, DL, TII->get(RISCV::SCFGWI)).addReg(PtrReg).addImm(dm_off+(0x18<<5));
  if(MBBI->getOpcode() == RISCV::PseudoSSRSetup_1D_W)
    BuildMI(MBB, MBBI, DL, TII->get(RISCV::SCFGWI)).addReg(PtrReg).addImm(dm_off+(0x1c<<5));

  MBBI->eraseFromParent(); // The pseudo instruction is gone now.
  return true;
}

bool RISCVExpandSSR::expandSSR_PushPop(MachineBasicBlock &MBB,
                                          MachineBasicBlock::iterator MBBI) {
  DebugLoc DL = MBBI->getDebugLoc();
  bool isPop = MBBI->getOpcode() == RISCV::PseudoSSRPop;

  // argument index of streamer and dest/source register is switched for push/pop 
  // instructions
  unsigned ssrArgIdx = MBBI->getOpcode() == RISCV::PseudoSSRPush ? 0 : 1;
  unsigned ssrValIdx = ssrArgIdx^1;

  // Get streamer data register from argument
  // ssrX is mapped to floating point temporary ftX
  unsigned streamer = (unsigned)MBBI->getOperand(ssrArgIdx).getImm();
  Register R = getSSRFtReg(streamer);

  LLVM_DEBUG(dbgs() << "-- Expanding SSR " << (isPop?"Pop":"Push") << "\n");
  LLVM_DEBUG(dbgs() << "   Using register " << R << " for SSR streamer "<<streamer<<"\n");

  if(isPop) {
    // Insert a "loading move" this is like a normal move but has side effects
    Register valR = MBBI->getOperand(ssrValIdx).getReg();
    MachineInstr *MI = BuildMI(MBB, MBBI, DL, TII->get(RISCV::PseudoLoadMove), valR).addReg(R, 0).getInstr();
    MBBI->eraseFromParent(); // The pseudo instruction is gone now.
    MI->getOperand(0).setIsDef();
    this->MoveLoads.push_back(MI);
  }
  else {
    Register valR = MBBI->getOperand(ssrValIdx).getReg();
    // Insert a "storing move" this is like a normal move but has side effects
    MachineInstr *MI = BuildMI(MBB, MBBI, DL, TII->get(RISCV::PseudoStoreMove), R)
      .addReg(valR, getRegState(MBBI->getOperand(ssrValIdx)))
      .getInstr();
    MBBI->eraseFromParent(); // The pseudo instruction is gone now.
    this->MoveStores.push_back(MI);
  }

  MBB.addLiveIn(R);
  return true;
}

bool RISCVExpandSSR::expandSSR_ReadWrite(MachineBasicBlock &MBB,
                                          MachineBasicBlock::iterator MBBI) {
  DebugLoc DL = MBBI->getDebugLoc();
  bool isRead = MBBI->getOpcode() == RISCV::PseudoSSRRead;
  MachineRegisterInfo &MRI = MBB.getParent()->getRegInfo();
  
  // select streamer based on first argument
  Register dm_off_reg = (int)MBBI->getOperand(0).getReg();
  // select dimension based on second argument
  Register dim_off_reg = (int)MBBI->getOperand(1).getReg();
  // select read/write based read/write
  int rw_off = isRead ? 0x18 : 0x1c;

  // reg  = (read ? 0x18 : 0x1c) + dim_off_reg
  // addr = reg << 5 + dm_off

  Register dim_off0 = MRI.createVirtualRegister(&RISCV::GPRRegClass);
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::ADDI), dim_off0).addReg(dim_off_reg).addImm(rw_off);
  Register dim_off1 = MRI.createVirtualRegister(&RISCV::GPRRegClass);
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SLLI), dim_off1).addReg(dim_off0).addImm(5);
  Register dim_off2 = MRI.createVirtualRegister(&RISCV::GPRRegClass);
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::ADD), dim_off2).addReg(dim_off1).addReg(dm_off_reg);

  // emit scfgwi at proper location
  Register PtrReg = MBBI->getOperand(2).getReg();
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SCFGW)).addReg(PtrReg).addReg(dim_off2);

  MBBI->eraseFromParent(); // The pseudo instruction is gone now.
  return true;
}

bool RISCVExpandSSR::expandSSR_ReadWriteImm(MachineBasicBlock &MBB,
                                          MachineBasicBlock::iterator MBBI) {
  DebugLoc DL = MBBI->getDebugLoc();

  bool read = MBBI->getOpcode() == RISCV::PseudoSSRReadImm;

  // select streamer based on first argument
  int dm_off = (int)MBBI->getOperand(0).getImm();
  int dim = (int)MBBI->getOperand(1).getImm();
  int ssr_reg = (((read ? 0x18 : 0x1c) + dim) << 5) + dm_off;
  Register PtrReg = MBBI->getOperand(2).getReg();

  // set read/write pointer
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SCFGWI)).addReg(PtrReg).addImm(ssr_reg);

  MBBI->eraseFromParent(); // The pseudo instruction is gone now.
  return true;
}

bool RISCVExpandSSR::expandSSR_SetupRep(MachineBasicBlock &MBB,
                                          MachineBasicBlock::iterator MBBI) {
  DebugLoc DL = MBBI->getDebugLoc();
  MachineRegisterInfo &MRI = MBB.getParent()->getRegInfo();

  // select streamer based on first argument
  Register dm_off_reg = MBBI->getOperand(0).getReg();
  Register dm_off = MRI.createVirtualRegister(&RISCV::GPRRegClass);
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::ADDI), dm_off).addReg(dm_off_reg).addImm(1<<5);

  // emit scfgwi at proper location
  Register PtrReg = MBBI->getOperand(1).getReg();
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SCFGW)).addReg(PtrReg).addReg(dm_off, RegState::Kill);

  MBBI->eraseFromParent(); // The pseudo instruction is gone now.
  return true;
}

bool RISCVExpandSSR::expandSSR_BoundStride(MachineBasicBlock &MBB,
                                          MachineBasicBlock::iterator MBBI) {
  unsigned dim;
  DebugLoc DL = MBBI->getDebugLoc();
  MachineRegisterInfo &MRI = MBB.getParent()->getRegInfo();

  if(MBBI->getOpcode() == RISCV::PseudoSSRSetupBoundStride_1D) dim = 1;
  if(MBBI->getOpcode() == RISCV::PseudoSSRSetupBoundStride_2D) dim = 2;
  if(MBBI->getOpcode() == RISCV::PseudoSSRSetupBoundStride_3D) dim = 3;
  if(MBBI->getOpcode() == RISCV::PseudoSSRSetupBoundStride_4D) dim = 4;

  LLVM_DEBUG(dbgs() << "-- Expanding SSR Bound Stride " << dim << "D\n");

  // select streamer based on first argument
  Register dm_off_reg = MBBI->getOperand(0).getReg();

  // SCFGW rs1 rs2 # rs1=value rs2=addr
  // addr= reg << 5 + dm_off
  // dm_off = 0,1,2,3

  // Build an add to calculate the SSR register
  Register addr_bound = MRI.createVirtualRegister(&RISCV::GPRRegClass);
  Register addr_stride = MRI.createVirtualRegister(&RISCV::GPRRegClass);
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::ADDI), addr_bound).addReg(dm_off_reg).addImm( ((2+(dim-1))<<5));
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::ADDI), addr_stride).addReg(dm_off_reg).addImm( ((6+(dim-1))<<5));

  // set bound
  Register BoundReg = MBBI->getOperand(1).getReg();
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SCFGW)).addReg(BoundReg).addReg(addr_bound, RegState::Kill);
  // set stride
  Register StrideReg = MBBI->getOperand(2).getReg();
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SCFGW)).addReg(StrideReg).addReg(addr_stride, RegState::Kill);
  
  MBBI->eraseFromParent(); // The pseudo instruction is gone now.
  return true;
}

bool RISCVExpandSSR::expandSSR_EnDis(MachineBasicBlock &MBB,
                                          MachineBasicBlock::iterator MBBI) {
  DebugLoc DL = MBBI->getDebugLoc();
  bool isEnable = MBBI->getOpcode() == RISCV::PseudoSSREnable;
  MachineRegisterInfo &MRI = MBB.getParent()->getRegInfo();

  LLVM_DEBUG(dbgs() << "-- Expanding SSR " << (isEnable ? "Enable" : "Disable") << "\n");

  // emit a csrsi/csrci call to the SSR location
  if(isEnable) {
    BuildMI(MBB, MBBI, DL, TII->get(RISCV::CSRRSI))
      .addDef(MRI.createVirtualRegister(&RISCV::GPRRegClass), RegState::Dead)
      .addImm(0x7C0).addImm(1);

    // mark the SSR registers reserved in this machine function
    unsigned ssrEnabledMask = 0;
    for (unsigned n = 0; n != 3; ++n) {
      ssrEnabledMask |= 1 << n;
    }
    RVFI->setUsedSSR(ssrEnabledMask);
  }
  else {
    BuildMI(MBB, MBBI, DL, TII->get(RISCV::CSRRCI))
      .addDef(MRI.createVirtualRegister(&RISCV::GPRRegClass), RegState::Dead)
      .addImm(0x7C0).addImm(1);
  }

  MBBI->eraseFromParent(); // The pseudo instruction is gone now.
  return true;
}

bool RISCVExpandSSR::expandSSR_Barrier(MachineBasicBlock &MBB,
                                      MachineBasicBlock::iterator MBBI,
                                      MachineBasicBlock::iterator &NextMBBI) {
  DebugLoc DL = MBBI->getDebugLoc();
  MachineInstr &MI = *MBBI;
  MachineFunction *MF = MBB.getParent();
  MachineRegisterInfo &MRI = MBB.getParent()->getRegInfo();

  unsigned streamer = (unsigned)MBBI->getOperand(0).getImm();
  
  LLVM_DEBUG(dbgs() << "-- Expanding SSR barrier on DM" << streamer << "\n");

  auto LoopMBB = MF->CreateMachineBasicBlock(MBB.getBasicBlock());
  auto DoneMBB = MF->CreateMachineBasicBlock(MBB.getBasicBlock());

  // Insert new MBBs.
  MF->insert(++MBB.getIterator(), LoopMBB);
  MF->insert(++LoopMBB->getIterator(), DoneMBB);

  // Set up successors and transfer remaining instructions to DoneMBB.
  LoopMBB->addSuccessor(LoopMBB);
  LoopMBB->addSuccessor(DoneMBB);
  DoneMBB->splice(DoneMBB->end(), &MBB, MI, MBB.end());
  DoneMBB->transferSuccessorsAndUpdatePHIs(&MBB);
  MBB.addSuccessor(LoopMBB);
  
  // build loop: %0 = scfgri 0 | DM; srli %0, %0, 31; beq %0, zero, loop
  Register R = MRI.createVirtualRegister(&RISCV::GPRRegClass);
  BuildMI(LoopMBB, DL, TII->get(RISCV::SCFGRI), R).addImm(streamer);
  Register Rs = MRI.createVirtualRegister(&RISCV::GPRRegClass);
  BuildMI(LoopMBB, DL, TII->get(RISCV::SRLI), Rs).addReg(R, RegState::Kill).addImm(31);
  BuildMI(LoopMBB, DL, TII->get(RISCV::BEQ)).addReg(Rs, RegState::Kill).addReg(RISCV::X0).addMBB(LoopMBB);

  NextMBBI = MBB.end();
  MI.eraseFromParent();

  LivePhysRegs LiveRegs;
  computeAndAddLiveIns(LiveRegs, *LoopMBB);
  computeAndAddLiveIns(LiveRegs, *DoneMBB);

  return true;
}

//additional optimisations for MoveLoad or MoveStore
void RISCVExpandSSR::handlePushPops() {
  return;
}

} // end of anonymous namespace

INITIALIZE_PASS(RISCVExpandSSR, "riscv-expand-ssr",
                RISCV_EXPAND_SSR_NAME, false, false)
namespace llvm {

FunctionPass *createRISCVExpandSSRPass() { return new RISCVExpandSSR(); }

} // end of namespace llvm

/*
  //TODO: bundle what is regmerged after reg-alloc to make sure that the FADD/FMUL/FMUL/etc.. do not slip past ssr_disable
  /*
  DenseMap<MachineInstr *, std::pair<MachineInstr *, MachineInstr *>> bundles;
  //pops:
  for (MachineInstr *MI : this->MoveLoads) {
    if (!MI) continue;
    MachineInstr *SingleUser = getUniqueUser(MI, MI->getOperand(0).getReg());
    if (SingleUser && SingleUser->getParent() == MI->getParent()) {
      MI->moveBefore(SingleUser); //we pray that there was no reordering until now that moved SingleUser after the SSRDisable
      auto b = bundles.find(SingleUser);
      if (b == bundles.end()) {
        b = bundles.insert(std::make_pair(SingleUser, std::make_pair(SingleUser, SingleUser))).first;
      }
      if (b->getSecond().first == SingleUser) b->getSecond().first = MI; //if begin of bundle was SingleUser, set to MI
    }
  }
  //pushs: FIXME: currently only works if the defining instruction is pred of MoveStore (how to get def from MachineOperand ???)
  for (MachineInstr *MI : this->MoveStores) {
    Register valR = MI->getOperand(1).getReg();
    MachineInstr *Pred = MI->getPrevNode();
    bool doesDefvalR = false;
    for (auto &MOP : Pred->defs()) doesDefvalR |= MOP.isReg() && MOP.getReg() == valR;
    if (doesDefvalR && MI == getUniqueUser(Pred, valR)) {
      auto b = bundles.find(Pred);
      if (b == bundles.end()) {
        b = bundles.insert(std::make_pair(Pred, std::make_pair(Pred, Pred))).first;
      }
      if (b->getSecond().second == Pred) b->getSecond().second = MI;
    }
  }*/