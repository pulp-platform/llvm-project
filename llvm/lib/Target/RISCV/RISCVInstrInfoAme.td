//===-- RISCVInstrInfoZvame.td - RISC-V Zvame instructions -*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the Zvame (Attached Matrix Extension) instructions.
// Major Opcode: CUSTOM-2 (0x5B)
//
//===----------------------------------------------------------------------===//

#ifndef RISCV_INSTR_INFO_ZVAME
#define RISCV_INSTR_INFO_ZVAME

//===----------------------------------------------------------------------===//
// Base Classes and Operands
//===----------------------------------------------------------------------===//

class RVInstZvame<dag outs, dag ins, string opcodestr, string argstr>
    : RVInst<outs, ins, opcodestr, argstr, [], InstFormatR> {
  let Predicates = [HasStdExtAme]; // Adjust predicate name as needed
  let Opcode = OPC_CUSTOM_2.Value;   // 0x5B
}

//===----------------------------------------------------------------------===//
// Datatype Management
//===----------------------------------------------------------------------===//

class RVInstZvameDataType<dag outs, dag ins, string opcodestr, string argstr, bits<7> funct7, bits<3> funct3>
    : RVInstZvame<outs, ins, opcodestr, argstr> {
  let Inst{31-25} = funct7;
  let Inst{14-12} = funct3;
}

class RVInstAgettyp<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstZvameDataType<outs, ins, opcodestr, argstr, 0b0000001, 0b101> {
  bits<5> xd;
  bits<2> ad;
  let Inst{24-17} = 0b00000000;
  let Inst{16-15} = ad;
  let Inst{11-7}  = xd;
}

class RVInstMgettyp<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstZvameDataType<outs, ins, opcodestr, argstr, 0b0000010, 0b101> {
  bits<5> xd;
  bits<5> ms1;
  let Inst{24-20} = 0b00000;
  let Inst{19-15} = ms1;
  let Inst{11-7}  = xd;
}

class RVInstAsettyp<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstZvameDataType<outs, ins, opcodestr, argstr, 0b0000011, 0b001> {
  bits<5> xs1;
  bits<2> ad_set;
  let Inst{24-20} = 0b00000;
  let Inst{19-15} = xs1;
  let Inst{11-10} = 0b00;
  let Inst{9-8}   = ad_set;
  let Inst{7}     = 0b0;
}

class RVInstMsettyp<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstZvameDataType<outs, ins, opcodestr, argstr, 0b0000100, 0b101> {
  bits<5> md;
  bits<5> xs1;
  let Inst{24-20} = 0b00000;
  let Inst{19-15} = xs1;
  let Inst{11-7}  = md;
}

//===----------------------------------------------------------------------===//
// Unary Elementwise
//===----------------------------------------------------------------------===//

class RVInstZvameUnary<dag outs, dag ins, string opcodestr, string argstr, bits<7> funct7, bits<3> funct3, bits<5> funct5>
    : RVInstZvame<outs, ins, opcodestr, argstr> {
  bits<5> md;
  bits<5> ms1;
  let Inst{31-25} = funct7;
  let Inst{24-20} = funct5;
  let Inst{19-15} = ms1;
  let Inst{14-12} = funct3;
  let Inst{11-7}  = md;
}

class RVInstMbcast_x<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstZvame<outs, ins, opcodestr, argstr> {
  bits<5> md;
  bits<5> xs1;
  let Inst{31-25} = 0b0000111;
  let Inst{24-20} = 0b00000;
  let Inst{19-15} = xs1;
  let Inst{14-12} = 0b001;
  let Inst{11-7}  = md;
}

//===----------------------------------------------------------------------===//
// Binary Elementwise
//===----------------------------------------------------------------------===//

class RVInstZvameBinary<dag outs, dag ins, string opcodestr, string argstr, bits<7> funct7, bits<3> funct3>
    : RVInstZvame<outs, ins, opcodestr, argstr> {
  bits<5> md;
  bits<5> ms1;
  bits<5> ms2;
  let Inst{31-25} = funct7;
  let Inst{24-20} = ms2;
  let Inst{19-15} = ms1;
  let Inst{14-12} = funct3;
  let Inst{11-7}  = md;
}

//===----------------------------------------------------------------------===//
// Scalar Binary (.x)
//===----------------------------------------------------------------------===//

class RVInstZvameScalarBinary<dag outs, dag ins, string opcodestr, string argstr, bits<7> funct7, bits<3> funct3>
    : RVInstZvame<outs, ins, opcodestr, argstr> {
  bits<5> md;
  bits<5> xs1;
  bits<5> ms2;
  let Inst{31-25} = funct7;
  let Inst{24-20} = ms2;
  let Inst{19-15} = xs1;
  let Inst{14-12} = funct3;
  let Inst{11-7}  = md;
}

//===----------------------------------------------------------------------===//
// Shift/Scale
//===----------------------------------------------------------------------===//

class RVInstMshift_ew<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstZvame<outs, ins, opcodestr, argstr> {
  bits<5> md;
  bits<5> ms1;
  bits<7> imm;
  let Inst{31-27} = 0b00000;
  let Inst{26-20} = imm;
  let Inst{19-15} = ms1;
  let Inst{14-12} = 0b011;
  let Inst{11-7}  = md;
}

//===----------------------------------------------------------------------===//
// Prefix & Reduce
//===----------------------------------------------------------------------===//

class RVInstZvamePrefixReduce<dag outs, dag ins, string opcodestr, string argstr, bits<7> funct7, bits<5> funct5>
    : RVInstZvame<outs, ins, opcodestr, argstr> {
  bits<5> md;
  bits<5> ms1;
  let Inst{31-25} = funct7;
  let Inst{24-20} = funct5;
  let Inst{19-15} = ms1;
  let Inst{14-12} = 0b100;
  let Inst{11-7}  = md;
}

//===----------------------------------------------------------------------===//
// Matrix Multiply (2D)
//===----------------------------------------------------------------------===//

class RVInstZvameMatMul2D<dag outs, dag ins, string opcodestr, string argstr, bits<7> funct7>
    : RVInstZvame<outs, ins, opcodestr, argstr> {
  bits<2> acc;
  bits<5> ms1;
  bits<5> ms2;
  let Inst{31-25} = funct7;
  let Inst{24-20} = ms2;
  let Inst{19-15} = ms1;
  let Inst{14-12} = 0b111;
  let Inst{11-10} = 0b00;
  let Inst{9-8}   = acc;
  let Inst{7}     = 0b0;
}

//===----------------------------------------------------------------------===//
// Accumulator Management
//===----------------------------------------------------------------------===//

class RVInstMzero_2d<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstZvame<outs, ins, opcodestr, argstr> {
  bits<2> acc;
  let Inst{31-25} = 0b0001111;
  let Inst{24-20} = 0b00000;
  let Inst{19-15} = 0b00000;
  let Inst{14-12} = 0b000;
  let Inst{11-10} = 0b00;
  let Inst{9-8}   = acc;
  let Inst{7}     = 0b0;
}

class RVInstMmov_a_m<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstZvame<outs, ins, opcodestr, argstr> {
  bits<5> md;
  bits<2> areg;
  let Inst{31-22} = 0b0011000000; // 0x0C0
  let Inst{21-20} = areg;
  let Inst{19-15} = 0b00000;
  let Inst{14-12} = 0b001;
  let Inst{11-7}  = md;
}

class RVInstMmov_m_m<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstZvame<outs, ins, opcodestr, argstr> {
  bits<5> md;
  bits<5> ms;
  let Inst{31-25} = 0b0100000;
  let Inst{24-20} = ms;
  let Inst{19-15} = 0b00000;
  let Inst{14-12} = 0b001;
  let Inst{11-7}  = md;
}

//===----------------------------------------------------------------------===//
// Load/Store
//===----------------------------------------------------------------------===//

class RVInstZvameLoad<dag outs, dag ins, string opcodestr, string argstr, bits<7> funct7>
    : RVInstZvame<outs, ins, opcodestr, argstr> {
  bits<5> md;
  bits<5> xs1;
  let Inst{31-25} = funct7;
  let Inst{24-20} = 0b00000;
  let Inst{19-15} = xs1;
  let Inst{14-12} = 0b110;
  let Inst{11-7}  = md;
}

class RVInstZvameStore<dag outs, dag ins, string opcodestr, string argstr, bits<7> funct7>
    : RVInstZvame<outs, ins, opcodestr, argstr> {
  bits<5> msd;
  bits<5> xs1;
  let Inst{31-25} = funct7;
  let Inst{24-20} = 0b00000;
  let Inst{19-15} = xs1;
  let Inst{14-12} = 0b110;
  let Inst{11-7}  = msd;
}

//===----------------------------------------------------------------------===//
// Instruction Definitions
//===----------------------------------------------------------------------===//

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in {

  // --- Datatype Management ---
  def AGETTYP  : RVInstAgettyp <(outs GPR:$xd), (ins ACC:$ad), "agettyp", "$xd, $ad">;
  def MGETTYP  : RVInstMgettyp <(outs GPR:$xd), (ins MR:$ms1), "mgettyp", "$xd, $ms1">;
  def ASETTYP  : RVInstAsettyp <(outs), (ins GPR:$xs1, ACC:$ad_set), "asettyp", "$ad_set, $xs1">;
  def MSETTYP  : RVInstMsettyp <(outs), (ins MR:$md, GPR:$xs1), "msettyp", "$md, $xs1">;

  // --- Unary Elementwise ---
  def MABS_EW       : RVInstZvameUnary<(outs MR:$md), (ins MR:$ms1), "mabs.ew", "$md, $ms1", 0b0000000, 0b100, 0b00000>;
  def MEXP2_EW      : RVInstZvameUnary<(outs MR:$md), (ins MR:$ms1), "mexp2.ew", "$md, $ms1", 0b0000101, 0b100, 0b00000>;
  def MLOG2_EW      : RVInstZvameUnary<(outs MR:$md), (ins MR:$ms1), "mlog2.ew", "$md, $ms1", 0b0000110, 0b100, 0b00000>;
  def MBCAST_X      : RVInstMbcast_x  <(outs MR:$md), (ins GPR:$xs1), "mbcast.x", "$md, $xs1">;
  def MCONV_EW      : RVInstZvameUnary<(outs MR:$md), (ins MR:$ms1), "mconv.ew", "$md, $ms1", 0b0001000, 0b101, 0b00000>;
  def MCOLUNZIP_EW  : RVInstZvameUnary<(outs MR:$md), (ins MR:$ms1), "mcolunzip.ew", "$md, $ms1", 0b0001001, 0b100, 0b10000>;
  def MCOLZIP_EW    : RVInstZvameUnary<(outs MR:$md), (ins MR:$ms1), "mcolzip.ew", "$md, $ms1", 0b0001010, 0b100, 0b00000>;
  def MROWUNZIP_EW  : RVInstZvameUnary<(outs MR:$md), (ins MR:$ms1), "mrowunzip.ew", "$md, $ms1", 0b0001011, 0b100, 0b10000>;

  // --- Binary Elementwise ---
  def MADD_EW       : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "madd.ew", "$md, $ms1, $ms2", 0b0000000, 0b000>;
  def MSUB_EW       : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "msub.ew", "$md, $ms1, $ms2", 0b1000000, 0b000>;
  def MMUL_EW       : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mmul.ew", "$md, $ms1, $ms2", 0b0011100, 0b000>;
  def MABSDIFF_EW   : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mabsdiff.ew", "$md, $ms1, $ms2", 0b0010000, 0b000>;
  def MAND_EW       : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mand.ew", "$md, $ms1, $ms2", 0b1110000, 0b000>;
  def MOR_EW        : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mor.ew", "$md, $ms1, $ms2", 0b1001000, 0b000>;
  def MXOR_EW       : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mxor.ew", "$md, $ms1, $ms2", 0b1101000, 0b000>;
  def MANDNOT_EW    : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mandnot.ew", "$md, $ms1, $ms2", 0b0001000, 0b000>;
  def MORNOT_EW     : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mornot.ew", "$md, $ms1, $ms2", 0b0101000, 0b000>;
  def MMAX_EW       : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mmax.ew", "$md, $ms1, $ms2", 0b1010000, 0b000>;
  def MMIN_EW       : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mmin.ew", "$md, $ms1, $ms2", 0b0110000, 0b000>;
  def MMEAN_EW      : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mmean.ew", "$md, $ms1, $ms2", 0b0100000, 0b000>;
  def MHDIFF_EW     : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mhdiff.ew", "$md, $ms1, $ms2", 0b1100000, 0b000>;
  def MGATHER_EW    : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mgather.ew", "$md, $ms1, $ms2", 0b0001100, 0b000>;
  def MROWZIP_EW    : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mrowzip.ew", "$md, $ms1, $ms2", 0b1101100, 0b000>;

  // --- Scalar Binary (.x) ---
  def MADD_EW_X     : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "madd.ew.x", "$md, $xs1, $ms2", 0b0000000, 0b010>;
  def MSUB_EW_X     : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "msub.ew.x", "$md, $xs1, $ms2", 0b1000000, 0b010>;
  def MMUL_EW_X     : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mmul.ew.x", "$md, $xs1, $ms2", 0b0100100, 0b010>;
  def MABSDIFF_EW_X : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mabsdiff.ew.x", "$md, $xs1, $ms2", 0b1010000, 0b010>;
  def MAND_EW_X     : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mand.ew.x", "$md, $xs1, $ms2", 0b1110000, 0b010>;
  def MOR_EW_X      : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mor.ew.x", "$md, $xs1, $ms2", 0b1001000, 0b010>;
  def MXOR_EW_X     : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mxor.ew.x", "$md, $xs1, $ms2", 0b1101000, 0b010>;
  def MANDNOT_EW_X  : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mandnot.ew.x", "$md, $xs1, $ms2", 0b0001000, 0b010>;
  def MORNOT_EW_X   : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mornot.ew.x", "$md, $xs1, $ms2", 0b0101000, 0b010>;
  def MMAX_EW_X     : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mmax.ew.x", "$md, $xs1, $ms2", 0b1100000, 0b010>;
  def MMIN_EW_X     : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mmin.ew.x", "$md, $xs1, $ms2", 0b0100000, 0b010>;
  def MMEAN_EW_X    : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mmean.ew.x", "$md, $xs1, $ms2", 0b0010000, 0b010>;
  def MHDIFF_EW_X   : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mhdiff.ew.x", "$md, $xs1, $ms2", 0b0110000, 0b010>;

  // --- Compare & Select ---
  def MCMPGE_EW     : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mcmpge.ew", "$md, $ms1, $ms2", 0b0011000, 0b000>;
  def MCMPLT_EW     : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mcmplt.ew", "$md, $ms1, $ms2", 0b1011000, 0b000>;
  def MCMPGE_EW_X   : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mcmpge.ew.x", "$md, $xs1, $ms2", 0b0011000, 0b010>;
  def MCMPLT_EW_X   : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mcmplt.ew.x", "$md, $xs1, $ms2", 0b1011000, 0b010>;
  def MCMOVGE_EW    : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mcmovge.ew", "$md, $ms1, $ms2", 0b0000100, 0b000>;
  def MCMOVLT_EW    : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mcmovlt.ew", "$md, $ms1, $ms2", 0b1000100, 0b000>;
  def MSELGE_EW     : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mselge.ew", "$md, $ms1, $ms2", 0b0111000, 0b000>;
  def MSELLT_EW     : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "msellt.ew", "$md, $ms1, $ms2", 0b1111000, 0b000>;

  // --- Fused Multiply-Add Variants ---
  def MMULACC_EW      : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mmulacc.ew", "$md, $ms1, $ms2", 0b1011100, 0b000>;
  def MMULACCNEG_EW   : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mmulaccneg.ew", "$md, $ms1, $ms2", 0b0000010, 0b000>;
  def MMULADD_EW      : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mmuladd.ew", "$md, $ms1, $ms2", 0b0111100, 0b000>;
  def MMULSUB_EW      : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mmulsub.ew", "$md, $ms1, $ms2", 0b1111100, 0b000>;
  def MMULACC_EW_X    : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mmulacc.ew.x", "$md, $xs1, $ms2", 0b1100100, 0b010>;
  def MMULACCNEG_EW_X : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mmulaccneg.ew.x", "$md, $xs1, $ms2", 0b0110100, 0b010>;
  def MMULADD_EW_X    : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mmuladd.ew.x", "$md, $xs1, $ms2", 0b0010100, 0b010>;
  def MMULSUB_EW_X    : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mmulsub.ew.x", "$md, $xs1, $ms2", 0b1010100, 0b010>;
  def MMULNEG_EW      : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mmulneg.ew", "$md, $ms1, $ms2", 0b1000010, 0b000>;
  def MMULNEG_EW_X    : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mmulneg.ew.x", "$md, $xs1, $ms2", 0b1110100, 0b010>;

  // --- Log/Exp with Bias ---
  def MLOG2SUB_EW    : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mlog2sub.ew", "$md, $ms1, $ms2", 0b0110100, 0b000>;
  def MSUBLOG2_EW    : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "msublog2.ew", "$md, $ms1, $ms2", 0b1110100, 0b000>;
  def MLOG2SUB_EW_X  : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mlog2sub.ew.x", "$md, $xs1, $ms2", 0b0111000, 0b010>;
  def MSUBLOG2_EW_X  : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "msublog2.ew.x", "$md, $xs1, $ms2", 0b1111000, 0b010>;

  // --- Shift/Scale ---
  def MLDEXP_EW      : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mldexp.ew", "$md, $ms1, $ms2", 0b0100100, 0b000>;
  def MRDEXP_EW      : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mrdexp.ew", "$md, $ms1, $ms2", 0b0010100, 0b000>;
  def MLDEXP_EW_X    : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mldexp.ew.x", "$md, $xs1, $ms2", 0b0000100, 0b010>;
  def MLDEXPACC_EW   : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mldexpacc.ew", "$md, $ms1, $ms2", 0b1100100, 0b000>;
  def MRDEXPACC_EW   : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mrdexpacc.ew", "$md, $ms1, $ms2", 0b1010100, 0b000>;
  def MLDEXPACC_EW_X : RVInstZvameScalarBinary<(outs MR:$md), (ins GPR:$xs1, MR:$ms2), "mldexpacc.ew.x", "$md, $xs1, $ms2", 0b1000100, 0b010>;
  def MSHIFT_EW      : RVInstMshift_ew <(outs MR:$md), (ins MR:$ms1, simm7:$imm), "mshift.ew", "$md, $ms1, $imm">;

  // --- Prefix & Reduce ---
  def MPREFIXADD_ROW : RVInstZvamePrefixReduce<(outs MR:$md), (ins MR:$ms1), "mprefixadd.row", "$md, $ms1", 0b0001100, 0b01000>;
  def MPREFIXADD_COL : RVInstZvamePrefixReduce<(outs MR:$md), (ins MR:$ms1), "mprefixadd.col", "$md, $ms1", 0b0001101, 0b11000>;
  def MPREFIXMAX_ROW : RVInstZvamePrefixReduce<(outs MR:$md), (ins MR:$ms1), "mprefixmax.row", "$md, $ms1", 0b0001110, 0b01000>;
  def MPREFIXMAX_COL : RVInstZvamePrefixReduce<(outs MR:$md), (ins MR:$ms1), "mprefixmax.col", "$md, $ms1", 0b0001111, 0b11000>;
  def MREDUCEADD_ROW : RVInstZvamePrefixReduce<(outs MR:$md), (ins MR:$ms1), "mreduceadd.row", "$md, $ms1", 0b0010000, 0b11100>;
  def MREDUCEADD_COL : RVInstZvamePrefixReduce<(outs MR:$md), (ins MR:$ms1), "mreduceadd.col", "$md, $ms1", 0b0010001, 0b10100>;
  def MREDUCEMAX_ROW : RVInstZvamePrefixReduce<(outs MR:$md), (ins MR:$ms1), "mreducemax.row", "$md, $ms1", 0b0010010, 0b11100>;
  def MREDUCEMAX_COL : RVInstZvamePrefixReduce<(outs MR:$md), (ins MR:$ms1), "mreducemax.col", "$md, $ms1", 0b0010011, 0b10100>;

  // --- Scatter ---
  def MSCATADD_COL   : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mscatadd.col", "$md, $ms1, $ms2", 0b0100010, 0b000>;
  def MSCATADD_ROW   : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mscatadd.row", "$md, $ms1, $ms2", 0b1001100, 0b000>;
  def MSCATMAX_COL   : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mscatmax.col", "$md, $ms1, $ms2", 0b1100010, 0b000>;
  def MSCATMAX_ROW   : RVInstZvameBinary<(outs MR:$md), (ins MR:$ms1, MR:$ms2), "mscatmax.row", "$md, $ms1, $ms2", 0b0101100, 0b000>;

  // --- Matrix Multiply (2D) ---
  def MMUL_2D        : RVInstZvameMatMul2D<(outs ACC:$acc), (ins MR:$ms1, MR:$ms2), "mmul.2d", "$acc, $ms1, $ms2", 0b0000000>;
  def MMULACC_2D     : RVInstZvameMatMul2D<(outs ACC:$acc), (ins MR:$ms1, MR:$ms2), "mmulacc.2d", "$acc, $ms1, $ms2", 0b1000000>;
  def MMULACCNEG_2D  : RVInstZvameMatMul2D<(outs ACC:$acc), (ins MR:$ms1, MR:$ms2), "mmulaccneg.2d", "$acc, $ms1, $ms2", 0b1100000>;
  def MMULNEG_2D     : RVInstZvameMatMul2D<(outs ACC:$acc), (ins MR:$ms1, MR:$ms2), "mmulneg.2d", "$acc, $ms1, $ms2", 0b0100000>;
  def MMULAT_2D      : RVInstZvameMatMul2D<(outs ACC:$acc), (ins MR:$ms1, MR:$ms2), "mmulat.2d", "$acc, $ms1, $ms2", 0b0010000>;
  def MMULATACC_2D   : RVInstZvameMatMul2D<(outs ACC:$acc), (ins MR:$ms1, MR:$ms2), "mmulatacc.2d", "$acc, $ms1, $ms2", 0b1010000>;
  def MMULBT_2D      : RVInstZvameMatMul2D<(outs ACC:$acc), (ins MR:$ms1, MR:$ms2), "mmulbt.2d", "$acc, $ms1, $ms2", 0b0110000>;
  def MMULBTACC_2D   : RVInstZvameMatMul2D<(outs ACC:$acc), (ins MR:$ms1, MR:$ms2), "mmulbtacc.2d", "$acc, $ms1, $ms2", 0b1110000>;

  // --- Accumulator Management ---
  def MZERO_2D       : RVInstMzero_2d <(outs), (ins ACC:$acc), "mzero.2d", "$acc">;
  def MMOV_A_M       : RVInstMmov_a_m <(outs MR:$md), (ins ACC:$areg), "mmov.a.m", "$md, $areg">;
  def MMOV_M_M       : RVInstMmov_m_m <(outs MR:$md), (ins MR:$ms), "mmov.m.m", "$md, $ms">;

  // --- Load/Store ---
  def MLS            : RVInstZvameLoad <(outs), (ins MR:$md, GPR:$xs1), "mls", "$md, $xs1", 0b0000001>;
  def MLS_RM         : RVInstZvameLoad <(outs), (ins MR:$md, GPR:$xs1), "mls.rm", "$md, $xs1", 0b0000000>;
  def MLS_CM         : RVInstZvameLoad <(outs), (ins MR:$md, GPR:$xs1), "mls.cm", "$md, $xs1", 0b0000010>;
  
  def MSS            : RVInstZvameStore<(outs), (ins MR:$msd, GPR:$xs1), "mss", "$msd, $xs1", 0b0010100>;
  def MSS_RM         : RVInstZvameStore<(outs), (ins MR:$msd, GPR:$xs1), "mss.rm", "$msd, $xs1", 0b0011000>;
  def MSS_CM         : RVInstZvameStore<(outs), (ins MR:$msd, GPR:$xs1), "mss.cm", "$msd, $xs1", 0b0001000>;
}

#endif // RISCV_INSTR_INFO_ZVAME