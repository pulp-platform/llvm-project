//===-- RISCVInstrInfoXdma.td - RISC-V 'Xdma' instructions ---*- tablegen -*-===//
//
// Copyright 2021 ETH Zurich, University of Bologna.
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the RISC-V instructions from the custom 'Xdma'
// instruction set extension.
//
//===----------------------------------------------------------------------===//

def OPC_XDMA     : RISCVOpcode<"XDMA", 0b0101011>;

let hasSideEffects = 1, mayLoad = 1, mayStore = 1 in {
  class DMInstRs1Rs2<bits<7> funct7, dag outs, dag ins, string opcodestr, string argstr>
      : RVInst<outs, ins, opcodestr, argstr, [], InstFormatOther> {
    bits<5> rs2;
    bits<5> rs1;

    let Inst{31-25} = funct7;
    let Inst{24-20} = rs2;
    let Inst{19-15} = rs1;
    let Inst{14-12} = 0b000;
    let Inst{11-7} = 0b00000;
    let Opcode = OPC_XDMA.Value;
  }

  class DMInstRdRs1Uimm5<bits<7> funct7, dag outs, dag ins, string opcodestr, string argstr>
      : RVInst<outs, ins, opcodestr, argstr, [], InstFormatOther> {
    bits<5> rd;
    bits<5> rs1;
    bits<5> uimm5;

    let Inst{31-25} = funct7;
    let Inst{24-20} = uimm5;
    let Inst{19-15} = rs1;
    let Inst{14-12} = 0b000;
    let Inst{11-7} = rd;
    let Opcode = OPC_XDMA.Value;
  }

  class DMInstRdRs1Rs2<bits<7> funct7, string opcodestr>
    : RVInstR<funct7, 0b000, OPC_XDMA, (outs GPR:$rd),
              (ins GPR:$rs1, GPR:$rs2), opcodestr, "$rd, $rs1, $rs2"> {
  }

  class DMInstRdUimm5<bits<7> funct7, string opcodestr>
    : RVInstR<funct7, 0b000, OPC_XDMA, (outs GPR:$rd),
              (ins uimm5:$uimm5), opcodestr, "$rd, $uimm5"> {
    bits<5> uimm5;
    let Inst{24-20} = uimm5;
    let Inst{19-15} = 0b00000; // rs1 = 0
  }

  class DMInstRdRs2<bits<7> funct7, string opcodestr>
    : RVInstR<funct7, 0b000, OPC_XDMA, (outs GPR:$rd),
              (ins GPR:$rs2), opcodestr, "$rd, $rs2"> {
    let Inst{19-15} = 0b00000; // rs1 = 0
  }

  class DMInstRs1<bits<7> funct7, string opcodestr>
    : RVInstR<funct7, 0b000, OPC_XDMA, (outs),
              (ins GPR:$rs1), opcodestr, "$rs1"> {
    let Inst{24-20} = 0b00000; // rs2 = 0
    let Inst{11-7}  = 0b00000; // rd = 0
  }

}// hasSideEffects = 0, mayLoad = 0, mayStore = 0

//===----------------------------------------------------------------------===//
// Instructions
//===----------------------------------------------------------------------===//

let Predicates = [HasExtXdma] in {
  def DMSRC  : DMInstRs1Rs2<0b0000000, (outs), (ins GPR:$rs1, GPR:$rs2),
                            "dmsrc", "$rs1, $rs2">, Sched<[]>;
  def DMDST  : DMInstRs1Rs2<0b0000001, (outs), (ins GPR:$rs1, GPR:$rs2),
                            "dmdst", "$rs1, $rs2">, Sched<[]>;
  def DMSTR  : DMInstRs1Rs2<0b0000110, (outs), (ins GPR:$rs1, GPR:$rs2),
                            "dmstr", "$rs1, $rs2">, Sched<[]>;
  def DMUSER : DMInstRs1Rs2<0b0001000, (outs), (ins GPR:$rs1, GPR:$rs2),
                            "dmuser", "$rs1, $rs2">, Sched<[]>;
  def DMCPYI : DMInstRdRs1Uimm5<0b0000010, (outs GPR:$rd), (ins GPR:$rs1, uimm5:$uimm5),
                            "dmcpyi", "$rd, $rs1, $uimm5">, Sched<[]>;
  def DMCPY  : DMInstRdRs1Rs2<0b0000011, "dmcpy">, Sched<[]>;
  def DMSTATI: DMInstRdUimm5 <0b0000100, "dmstati">, Sched<[]>;
  def DMSTAT : DMInstRdRs2   <0b0000101, "dmstat">, Sched<[]>;
  def DMREP  : DMInstRs1     <0b0000111, "dmrep">, Sched<[]>;
} // Predicates = [HasExtXdma]

//===----------------------------------------------------------------------===//
// Pseudos
//===----------------------------------------------------------------------===//
let hasSideEffects = 1, mayLoad = 1, mayStore = 1 in {
  class DMPseudoOned: Pseudo<(outs GPR:$tid),
                      (ins GPR:$sptr_hi, GPR:$sptr_lo, GPR:$dptr_hi, GPR:$dptr_lo, GPR:$size, GPR:$cfg),[]>{}
  class DMPseudoTwod: Pseudo<(outs GPR:$tid),
                      (ins GPR:$sptr_hi, GPR:$sptr_lo, GPR:$dptr_hi, GPR:$dptr_lo, GPR:$size, GPR:$sstrd, GPR:$dstrd, GPR:$nreps, GPR:$cfg),[]>{}
  class DMPseudoStat: Pseudo<(outs GPR:$stat),
                      (ins GPR:$tid),[]>{}
  class DMPseudoWaitForIdle: Pseudo<(outs), (ins),[]>{}
}

let Predicates = [HasExtXdma] in {
  def PseudoSDMAOned   : DMPseudoOned;
  def PseudoSDMATwod   : DMPseudoTwod;
  def PseudoSDMAStat   : DMPseudoStat;
  def PseudoSDMAWaitForIdle : DMPseudoWaitForIdle;
}

// pattern matching on intrinsic and resulting in pseudo instruction
def : Pat<(int_riscv_sdma_start_oned_legal GPR:$shi, GPR:$slo, GPR:$dhi, GPR:$dlo, GPR:$size, GPR:$cfg),
        (PseudoSDMAOned GPR:$shi, GPR:$slo, GPR:$dhi, GPR:$dlo, GPR:$size, GPR:$cfg)>;
def : Pat<(int_riscv_sdma_start_twod_legal GPR:$shi, GPR:$slo, GPR:$dhi, GPR:$dlo, GPR:$size, GPR:$sstrd, GPR:$dstrd, GPR:$nreps, GPR:$cfg),
        (PseudoSDMATwod GPR:$shi, GPR:$slo, GPR:$dhi, GPR:$dlo, GPR:$size, GPR:$sstrd, GPR:$dstrd, GPR:$nreps, GPR:$cfg)>;
def : Pat<(int_riscv_sdma_stat GPR:$tid),
        (PseudoSDMAStat GPR:$tid)>;
def : Pat<(int_riscv_sdma_wait_for_idle),
        (PseudoSDMAWaitForIdle)>;
