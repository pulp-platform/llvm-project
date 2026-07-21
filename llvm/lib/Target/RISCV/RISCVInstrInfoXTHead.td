//===-- RISCVInstrInfoXTHead.td ----------------------------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the vendor extensions defined by T-Head of Alibaba.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Experimental RV64 i32 legalization patterns.
//===----------------------------------------------------------------------===//

// Matrix Memory Instructions
class RVMLoadStore<bits<3> ldst, dag outs, dag ins,
                  string opcodestr, string argstr>
    : RVInst<outs, ins, opcodestr, argstr, [], InstFormatOther> {
  bits<5> rs2;
  bits<5> rs1;
  bits<4> mds3;

  let Inst{31-29} = 0b000;
  let Inst{28-26} = ldst;
  let Inst{25}    = 0b0;
  let Inst{24-20} = rs2;
  let Inst{19-15} = rs1;
  let Inst{14-11} = mds3;
  let Inst{10-7}  = 0b0000;

  let Inst{6-0} = OPC_CUSTOM_0.Value;
}

// Matrix Arithmetic Instructions
class RVMArithBase<dag outs, dag ins, string opcodestr, string argstr>
    : RVInst<outs, ins, opcodestr, argstr, [], InstFormatOther> {

  let Inst{31-29} = 0b001;
  let Inst{25}    = 0b0;
  let Inst{14-11} = 0b0000;
  let Inst{10-7}  = 0b0000;

  let Inst{6-0} = OPC_CUSTOM_0.Value;
}
class RVMMACC<dag outs, dag ins, string opcodestr, string argstr>
    : RVMArithBase<outs, ins, opcodestr, argstr> {
  
  bits<4> ms2;
  bits<4> ms1;
  bits<2> md ;

  let Inst{28-26} = 0b010;
  let Inst{24-23} = md;
  let Inst{22-19} = ms2;
  let Inst{18-15} = ms1;
}
class RVMZeroA<dag outs, dag ins, string opcodestr, string argstr>
    : RVMArithBase<outs, ins, opcodestr, argstr> {

  bits<2> md ;

  let Inst{28-26} = 0b000;
  let Inst{24-23} = md;
  let Inst{22-19} = 0b0000;
  let Inst{18-15} = 0b0000;
}
class RVMZeroM<dag outs, dag ins, string opcodestr, string argstr>
    : RVMArithBase<outs, ins, opcodestr, argstr> {

  bits<4> ms1;

  let Inst{28-26} = 0b001;
  let Inst{24-23} = 0b00;
  let Inst{22-19} = 0b0000;
  let Inst{18-15} = ms1;
}

// Matrix Move Instructions
class RVMMoveBase<dag outs, dag ins, string opcodestr, string argstr>
    : RVInst<outs, ins, opcodestr, argstr, [], InstFormatOther> {

  let Inst{31-29} = 0b010;
  let Inst{25}    = 0b0;
  let Inst{20-19} = 0b00;
  let Inst{10-7}  = 0b0000;

  let Inst{6-0} = OPC_CUSTOM_0.Value;
}
class RVMMoveAM<dag outs, dag ins, string opcodestr, string argstr>
    : RVMMoveBase<outs, ins, opcodestr, argstr> {

  bits<2> ms1;
  bits<4> md ;

  let Inst{28-26} = 0b000;
  let Inst{24-23} = ms1;
  let Inst{22-21} = 0b00;
  let Inst{18-15} = 0b0000;
  let Inst{14-11} = md;
}
class RVMMoveAA<dag outs, dag ins, string opcodestr, string argstr>
    : RVMMoveBase<outs, ins, opcodestr, argstr> {

  bits<2> ms1;
  bits<2> md ;

  let Inst{28-26} = 0b001;
  let Inst{24-23} = ms1;
  let Inst{22-21} = md;
  let Inst{18-15} = 0b0000;
  let Inst{14-11} = 0b0000;
}
class RVMMoveMA<dag outs, dag ins, string opcodestr, string argstr>
    : RVMMoveBase<outs, ins, opcodestr, argstr> {

  bits<2> md;
  bits<4> ms1 ;

  let Inst{28-26} = 0b010;
  let Inst{24-23} = 0b00;
  let Inst{22-21} = md;
  let Inst{18-15} = ms1;
  let Inst{14-11} = 0b0000;
}
class RVMMoveMM<dag outs, dag ins, string opcodestr, string argstr>
    : RVMMoveBase<outs, ins, opcodestr, argstr> {

  bits<4> md;
  bits<4> ms1 ;

  let Inst{28-26} = 0b011;
  let Inst{24-23} = 0b00;
  let Inst{22-21} = 0b00;
  let Inst{18-15} = ms1;
  let Inst{14-11} = md;
}

// Matrix Configuration Instructions
class RVMCfgBase<dag outs, dag ins, string opcodestr, string argstr>
    : RVInst<outs, ins, opcodestr, argstr, [], InstFormatOther> {

  let Inst{31-29} = 0b011;
  let Inst{25}    = 0b0;

  let Inst{6-0} = OPC_CUSTOM_0.Value;
}

class RVMCfgK<dag outs, dag ins, string opcodestr, string argstr> 
  : RVMCfgBase<outs, ins, opcodestr, argstr> {
    bits<5> rs1;
    bits<5> rd;

    let Inst{28-26} = 0b000;
    let Inst{24-20} = 0b00000;
    let Inst{19-15} = rs1;
    let Inst{14-13} = 0b00;
    let Inst{12}    = 0b0;
    let Inst{11-7}  = rd;
}
class RVMCfgM<dag outs, dag ins, string opcodestr, string argstr> 
  : RVMCfgBase<outs, ins, opcodestr, argstr> {
    bits<5> rs1;
    bits<5> rd;
    bits<2> imm2;

    let Inst{28-26} = 0b001;
    let Inst{24-20} = 0b00000;
    let Inst{19-15} = rs1;
    let Inst{14-13} = imm2{1-0};
    let Inst{12}    = 0b0;
    let Inst{11-7}  = rd;
}
class RVMCfgN<dag outs, dag ins, string opcodestr, string argstr> 
  : RVMCfgBase<outs, ins, opcodestr, argstr> {
    bits<5> rs1;
    bits<5> rd;
    bits<2> imm2;

    let Inst{28-26} = 0b010;
    let Inst{24-20} = 0b00000;
    let Inst{19-15} = rs1;
    let Inst{14-13} = imm2{1-0};
    let Inst{12}    = 0b0;
    let Inst{11-7}  = rd;
}
class RVMCfgDT<dag outs, dag ins, string opcodestr, string argstr> 
  : RVMCfgBase<outs, ins, opcodestr, argstr> {
    bits<5> Aimm5;
    bits<5> Bimm5;
    bits<5> Cimm5;

    let Inst{28-26} = 0b011;
    let Inst{24-20} = Cimm5{4-0};
    let Inst{19-15} = Aimm5{4-0};
    let Inst{14-10} = Bimm5{4-0};
    let Inst{9-7}   = 0b000;
}

let Predicates = [HasVendorXTHeadMatrix], DecoderNamespace = "XTHeadMatrix",hasSideEffects = 0, mayLoad = 0, mayStore = 0 in {

  let mayLoad = 1 in {
    def MLD_LHS : RVMLoadStore<0b100, (outs MR:$mds3), (ins GPR:$rs1, GPR:$rs2), "mld.lhs", "$mds3, (${rs1}), $rs2">;
    def MLD_RHS : RVMLoadStore<0b001, (outs MR:$mds3), (ins GPR:$rs1, GPR:$rs2), "mld.rhs", "$mds3, (${rs1}), $rs2">;
  }

  let mayStore = 1 in {
    def MST : RVMLoadStore<0b010, (outs), (ins MR:$mds3, GPR:$rs1, GPR:$rs2), "mst", "$mds3, (${rs1}), $rs2">;
  }

  def MMACC   : RVMMACC <(outs ACC:$md), (ins MR:$ms1, MR:$ms2), "mmacc", "$md, $ms2, $ms1">;
  def MZERO_M : RVMZeroM<(outs MR:$md) , (ins)                 , "mzero.m", "$md">;
  def MZERO_A : RVMZeroA<(outs ACC:$md), (ins)                 , "mzero.a", "$md">;
  
  def MMOV_MM  : RVMMoveMM<(outs MR:$md) , (ins MR:$ms1) , "mmov.mm" , "$md, $ms1">;
  def MMOV_MA  : RVMMoveMA<(outs ACC:$md), (ins MR:$ms1) , "mmov.ma" , "$md, $ms1">;
  def MMOV_AM  : RVMMoveAM<(outs MR:$md) , (ins ACC:$ms1), "mmov.am" , "$md, $ms1">;
  def MMOV_AA  : RVMMoveAA<(outs ACC:$md), (ins ACC:$ms1), "mmov.aa" , "$md, $ms1">;

  let hasSideEffects = 1 in {
    def MCFGK   : RVMCfgK <(outs GPR:$rd), (ins GPR:$rs1             ), "mcfgk"  , "$rd, $rs1">;
    def MCFGM   : RVMCfgM <(outs GPR:$rd), (ins GPR:$rs1, uimm2:$imm2), "mcfgm"  , "$rd, $rs1, $imm2">;
    def MCFGN   : RVMCfgN <(outs GPR:$rd), (ins GPR:$rs1, uimm2:$imm2), "mcfgn"  , "$rd, $rs1, $imm2">;
    def MMAC_DT : RVMCfgDT<(outs),(ins uimm5:$Cimm5, uimm5:$Aimm5, uimm5:$Bimm5), "mmac.dt", "$Cimm5, $Aimm5, $Bimm5">;
  }

}