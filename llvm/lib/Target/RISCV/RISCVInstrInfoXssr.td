//===-- RISCVInstrInfoXfrep.td - RISC-V 'Xfrep' instructions ---*- tablegen -*-===//
//
// Copyright 2021 ETH Zurich, University of Bologna.
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the RISC-V instructions from the custom 'Xssr'
// instruction set extension.
//
//===----------------------------------------------------------------------===//

def OPC_CUSTOM1     : RISCVOpcode<0b0101011>;

let hasSideEffects = 1, mayLoad = 0, mayStore = 0 in {

  class SSRInstImmRead<bits<3> funct3, string opcodestr>
      : RVInst<(outs GPR:$rd), (ins uimm12:$uimm12), opcodestr, "$rd, $uimm12", [], InstFormatOther> {
    bits<12> uimm12;
    bits<5> rd;
    bits<7> funct7;

    let Inst{31-20} = uimm12;
    let Inst{19-15} = 0b00000; // rs1 = 0
    let Inst{14-12} = funct3; 
    let Inst{11-7}  = rd;
    let Opcode = OPC_CUSTOM1.Value;
  }

  class SSRInstImmWrite<bits<3> funct3, string opcodestr>
      : RVInst<(outs), (ins GPR:$rs1, uimm12:$uimm12), opcodestr, "$rs1, $uimm12", [], InstFormatOther> {
    bits<12> uimm12;
    bits<5> rs1;
    bits<7> funct7;

    let Inst{31-20} = uimm12;
    let Inst{19-15} = rs1;
    let Inst{14-12} = funct3; 
    let Inst{11-7}  = 0b00000; // rd = 0
    let Opcode = OPC_CUSTOM1.Value;
  }

  class SSRInstRegRead<bits<7> funct7, bits<3> funct3, string opcodestr>
    : RVInstR<funct7, funct3, OPC_CUSTOM1, (outs GPR:$rd),
              (ins GPR:$rs2), opcodestr, "$rd, $rs2"> {
    let Inst{19-15} = 0b00001;  // rs1 = 0b00001
  }
  class SSRInstRegWrite<bits<7> funct7, bits<3> funct3, string opcodestr>
    : RVInstR<funct7, funct3, OPC_CUSTOM1, (outs),
              (ins GPR:$rs1, GPR:$rs2), opcodestr, "$rs1, $rs2"> {
    let Inst{11-7} = 0b00001;  // rd = 0b00001
  }
}// hasSideEffects = 1, mayLoad = 0, mayStore = 0

//===----------------------------------------------------------------------===//
// Instructions
//===----------------------------------------------------------------------===//

let Predicates = [HasExtXssr] in {
  def SCFGRI : SSRInstImmRead  <0b001, "scfgri">, Sched<[]>;
  def SCFGWI : SSRInstImmWrite <0b010, "scfgwi">, Sched<[]>;
  def SCFGR  : SSRInstRegRead  <0b0000000, 0b001, "scfgr">,  Sched<[]>;
  def SCFGW  : SSRInstRegWrite <0b0000000, 0b010, "scfgw">,  Sched<[]>;
} // Predicates = [HasExtXssr]


//===----------------------------------------------------------------------===//
// Pseudo Instructions
//===----------------------------------------------------------------------===//

class SPseudoSetup1D:
      Pseudo<(outs),
             (ins uimm5:$ssr, GPR:$rep, GPR:$bound, GPR:$stride, GPR:$ptr),[]> {
  let mayLoad = 1;
  let mayStore = 1;
  let hasSideEffects = 1;
  let usesCustomInserter = 0;
}

class SPseudoSetupRepetition:
      Pseudo<(outs),
             (ins GPR:$ssr, GPR:$rep),[]> {
  let mayLoad = 1;
  let mayStore = 1;
  let hasSideEffects = 1;
  let usesCustomInserter = 0;
}

class SPseudoSetupBoundStride:
      Pseudo<(outs),
             (ins GPR:$ssr, GPR:$bound, GPR:$stride),[]> {
  let mayLoad = 1;
  let mayStore = 1;
  let hasSideEffects = 1;
  let usesCustomInserter = 0;
}

class SPseudoPush:
      Pseudo<(outs), (ins uimm5:$ssr, FPR64:$val),[]> {
  let mayLoad = 0;
  let mayStore = 1;
  let hasSideEffects = 1;
  let usesCustomInserter = 0;
}

class SPseudoStoreMove: //instead of using these could give isBarrier = 1 to ssr csrrsi/csrrci
      Pseudo<(outs FPR64:$ssr), (ins FPR64:$val),[]> {
  let mayLoad = 0;
  let mayStore = 1;
  let hasSideEffects = 1;
  let usesCustomInserter = 0;
}

class SPseudoPop:
      Pseudo<(outs FPR64:$val), (ins uimm5:$ssr),[]> {
  let mayLoad = 1;
  let mayStore = 1;
  let hasSideEffects = 1;
  let usesCustomInserter = 0;
}

class SPseudoLoadMove:
      Pseudo<(outs FPR64:$val), (ins FPR64:$ssr),[]> {
  let mayLoad = 1;
  let mayStore = 1;
  let hasSideEffects = 1;
  let usesCustomInserter = 0;
}

class SPseudoRW:
      Pseudo<(outs), (ins GPR:$ssr, GPR:$dim, GPR:$ptr),[]> {
  let mayLoad = 1;
  let mayStore = 1;
  let hasSideEffects = 1;
  let usesCustomInserter = 0;
}

class SPseudoRWImm:
      Pseudo<(outs), (ins uimm5:$ssr, uimm5:$dim, GPR:$ptr),[]> {
  let mayLoad = 1;
  let mayStore = 1;
  let hasSideEffects = 1;
  let usesCustomInserter = 0;
}

class SPseudoEnDis:
      Pseudo<(outs), (ins),[]> {
  let mayLoad = 1;
  let mayStore = 1;
  let hasSideEffects = 1;
  let usesCustomInserter = 0;
}

class SPseudoBarrier: 
      Pseudo<(outs), (ins uimm5:$ssr),[]> {
  let hasSideEffects = 1;
  let usesCustomInserter = 0;
}

let Predicates = [HasExtXssr] in {
  def PseudoSSRSetup_1D_R : SPseudoSetup1D;
  def PseudoSSRSetup_1D_W : SPseudoSetup1D;
  def PseudoSSRPush  : SPseudoPush;
  def PseudoSSRPop   : SPseudoPop;
  def PseudoStoreMove : SPseudoStoreMove;
  def PseudoLoadMove  : SPseudoLoadMove;

  foreach dim = [1, 2, 3, 4] in {
    def PseudoSSRSetupBoundStride_#dim#D : SPseudoSetupBoundStride;
  }

  def PseudoSSREnable   : SPseudoEnDis;
  def PseudoSSRDisable  : SPseudoEnDis;
  def PseudoSSRRead     : SPseudoRW;
  def PseudoSSRWrite    : SPseudoRW;
  def PseudoSSRReadImm  : SPseudoRWImm;
  def PseudoSSRWriteImm : SPseudoRWImm;
  def PseudoSSRSetupRepetition   : SPseudoSetupRepetition;
  def PseudoSSRBarrier : SPseudoBarrier;

  // pattern matching on intrinsic and resulting in pseudo instruction
  def : Pat<(int_riscv_ssr_setup_1d_r timm:$ssr, GPR:$rep, GPR:$bound, GPR:$stride, GPR:$ptr),
          (PseudoSSRSetup_1D_R timm:$ssr, GPR:$rep, GPR:$bound, GPR:$stride, GPR:$ptr)>;
  def : Pat<(int_riscv_ssr_setup_1d_w timm:$ssr, GPR:$rep, GPR:$bound, GPR:$stride, GPR:$ptr),
          (PseudoSSRSetup_1D_W timm:$ssr, GPR:$rep, GPR:$bound, GPR:$stride, GPR:$ptr)>;
  
  def : Pat<(int_riscv_ssr_setup_bound_stride_1d GPR:$ssr, GPR:$bound, GPR:$stride),
          (PseudoSSRSetupBoundStride_1D GPR:$ssr, GPR:$bound, GPR:$stride)>;
  def : Pat<(int_riscv_ssr_setup_bound_stride_2d GPR:$ssr, GPR:$bound, GPR:$stride),
          (PseudoSSRSetupBoundStride_2D GPR:$ssr, GPR:$bound, GPR:$stride)>;
  def : Pat<(int_riscv_ssr_setup_bound_stride_3d GPR:$ssr, GPR:$bound, GPR:$stride),
          (PseudoSSRSetupBoundStride_3D GPR:$ssr, GPR:$bound, GPR:$stride)>;
  def : Pat<(int_riscv_ssr_setup_bound_stride_4d GPR:$ssr, GPR:$bound, GPR:$stride),
          (PseudoSSRSetupBoundStride_4D GPR:$ssr, GPR:$bound, GPR:$stride)>;

  def : Pat<(int_riscv_ssr_read GPR:$ssr, GPR:$dim, GPR:$ptr),
          (PseudoSSRRead GPR:$ssr, GPR:$dim, GPR:$ptr)>;
  def : Pat<(int_riscv_ssr_write GPR:$ssr, GPR:$dim, GPR:$ptr),
          (PseudoSSRWrite GPR:$ssr, GPR:$dim, GPR:$ptr)>;
  def : Pat<(int_riscv_ssr_read_imm timm:$ssr, timm:$dim, GPR:$ptr),
          (PseudoSSRReadImm timm:$ssr, timm:$dim, GPR:$ptr)>;
  def : Pat<(int_riscv_ssr_write_imm timm:$ssr, timm:$dim, GPR:$ptr),
          (PseudoSSRWriteImm timm:$ssr, timm:$dim, GPR:$ptr)>;

  def : Pat<(int_riscv_ssr_push timm:$ssr, FPR64:$val),
          (PseudoSSRPush timm:$ssr, FPR64:$val)>;
  def : Pat<(int_riscv_ssr_pop timm:$ssr),
          (PseudoSSRPop timm:$ssr)>;

  def : Pat<(int_riscv_ssr_setup_repetition GPR:$ssr, GPR:$rep),
          (PseudoSSRSetupRepetition GPR:$ssr, GPR:$rep)>;

  def : Pat<(int_riscv_ssr_enable), (PseudoSSREnable)>;
  def : Pat<(int_riscv_ssr_disable), (PseudoSSRDisable)>;

  def : Pat<(int_riscv_ssr_barrier timm:$ssr),
          (PseudoSSRBarrier timm:$ssr)>;

} // Predicates = [HasExtXssr]
