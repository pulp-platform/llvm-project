//===-- RISCVInstrInfoXvmxdotp.td - RISC-V PULP VMXDOTP extension -- *- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the RISC-V instructions from the non-standard 'Xvmxdotp'
// instruction set extension.
//
//===----------------------------------------------------------------------===//

class RVInstVVXX<RISCVOpcode opcode, dag outs, dag ins, string opcodestr,
                 string argstr>
    : RVInst<outs, ins, opcodestr, argstr, [], InstFormatOther> {
  bits<5> vs4;
  bits<5> rs3;
  bits<5> vs2;
  bits<5> rs1;
  bits<5> vd;

  let Inst{31-27} = rs3;
  let Inst{26-25} = vs4{4-3};
  let Inst{24-20} = vs2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = vs4{2-0};
  let Inst{11-7} = vd;
  let Opcode = opcode.Value;

  let Uses = [VTYPE, VL];
}

class RVInstVVVV<RISCVOpcode opcode, dag outs, dag ins, string opcodestr,
                 string argstr>
    : RVInst<outs, ins, opcodestr, argstr, [], InstFormatOther> {
  bits<5> vs4;
  bits<5> vs3;
  bits<5> vs2;
  bits<5> vs1;
  bits<5> vd;

  let Inst{31-27} = vs3;
  let Inst{26-25} = vs4{4-3};
  let Inst{24-20} = vs2;
  let Inst{19-15} = vs1;
  let Inst{14-12} = vs4{2-0};
  let Inst{11-7} = vd;
  let Opcode = opcode.Value;

  let Uses = [VTYPE, VL];
}

// Vector MX Dot Product Instructions
// TODO: Inform the assembler about EMUL constraints on the various registers.
let hasSideEffects = 0, mayLoad = 0, mayStore = 0,
    Constraints = "@earlyclobber $vd" in {

  def VMXDOTP_WF : RVInstVVXX<RISCVOpcode<"0x5f", 0b1011111>,
      (outs VR:$vd), (ins FPR32:$rs1, VR:$vs2, FPR32:$rs3, VR:$vs4),
      "vmxdotp.wf", "$vd, $rs1, $vs2, $rs3, $vs4">, Sched<[]>;

  def VMXDOTP_WW : RVInstVVVV<RISCVOpcode<"0x7f", 0b1111111>,
      (outs VR:$vd), (ins VR:$vs1, VR:$vs2, VR:$vs3, VR:$vs4),
      "vmxdotp.ww", "$vd, $vs1, $vs2, $vs3, $vs4">, Sched<[]>;

  def VMXDOTP_QF : RVInstVVXX<RISCVOpcode<"0x1f", 0b0011111>,
      (outs VR:$vd), (ins FPR32:$rs1, VR:$vs2, FPR32:$rs3, VR:$vs4),
      "vmxdotp.qf", "$vd, $rs1, $vs2, $rs3, $vs4">, Sched<[]>;

  def VMXDOTP_QQ : RVInstVVVV<RISCVOpcode<"0x3f", 0b0111111>,
      (outs VR:$vd), (ins VR:$vs1, VR:$vs2, VR:$vs3, VR:$vs4),
      "vmxdotp.qq", "$vd, $vs1, $vs2, $vs3, $vs4">, Sched<[]>;

} // Constraints = "@earlyclobber $vd"
