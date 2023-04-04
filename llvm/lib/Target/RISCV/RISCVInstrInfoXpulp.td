//===-- RISCVInstrInfoPULP.td - RISC-V PULP extension ----- *- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the RISC-V instructions from the non-standard 'PULP'
// instruction set extension.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// RISC-V specific DAG Nodes
//===----------------------------------------------------------------------===//

def uimm1 : Operand<XLenVT>, ImmLeaf<XLenVT, [{return isUInt<1>(Imm);}]> {
  let ParserMatchClass = UImmAsmOperand<1>;
  let EncoderMethod = "getImmOpValue";
  let DecoderMethod = "decodeUImmOperand<1>";
  let MCOperandPredicate = [{
    int64_t Imm;
    if (MCOp.evaluateAsConstantImm(Imm))
      return isUInt<1>(Imm);
    return MCOp.isBareSymbolRef();
  }];
}

def uimm13_lsb0 : Operand<OtherVT>,
                  ImmLeaf<XLenVT, [{return isShiftedUInt<12, 1>(Imm);}]>  {
  let ParserMatchClass = UImmAsmOperand<13, "Lsb0">;
  let EncoderMethod = "getImmOpValueAsr1";
  let DecoderMethod = "decodeUImmOperand<13>";
  let MCOperandPredicate = [{
    int64_t Imm;
    if (MCOp.evaluateAsConstantImm(Imm))
      return isShiftedInt<12, 1>(Imm);
    return MCOp.isBareSymbolRef();
  }];
}

def uimm6 : Operand<XLenVT>, ImmLeaf<XLenVT, [{return isUInt<6>(Imm);}]> {
  let ParserMatchClass = UImmAsmOperand<6>;
  let EncoderMethod = "getImmOpValue";
  let DecoderMethod = "decodeUImmOperand<6>";
  let MCOperandPredicate = [{
    int64_t Imm;
    if (MCOp.evaluateAsConstantImm(Imm))
      return isUInt<6>(Imm);
    return MCOp.isBareSymbolRef();
  }];
}

def uimm6_lsb0 : Operand<OtherVT>,
                 ImmLeaf<XLenVT, [{return isShiftedUInt<5, 1>(Imm);}]>  {
  let ParserMatchClass = UImmAsmOperand<6, "Lsb0">;
  let EncoderMethod = "getImmOpValueAsr1";
  let DecoderMethod = "decodeUImmOperand<13>";
  let MCOperandPredicate = [{
    int64_t Imm;
    if (MCOp.evaluateAsConstantImm(Imm))
      return isShiftedInt<5, 1>(Imm);
    return MCOp.isBareSymbolRef();
  }];
}

def uimm12pcrel : Operand<XLenVT>, ImmLeaf<XLenVT, [{return isUInt<12>(Imm);}]> {
  let ParserMatchClass = UImmAsmOperand<12>;
  let DecoderMethod = "decodeUImmOperand<12>";
}

// tuimm12 predicate - same ass uimm, but use TargetConstant (TImmLeaf)
// instead of Constant (ImmLeaf)
// FIXME: factor common code between uimm12 and tuimm12
def tuimm12 : Operand<XLenVT>, TImmLeaf<XLenVT, [{return isUInt<12>(Imm);}]> {
  let ParserMatchClass = UImmAsmOperand<12>;
  let EncoderMethod = "getImmOpValue";
  let DecoderMethod = "decodeUImmOperand<12>";
  let MCOperandPredicate = [{
    int64_t Imm;
    if (MCOp.evaluateAsConstantImm(Imm))
      return isUInt<12>(Imm);
    return MCOp.isBareSymbolRef();
  }];
  let OperandType = "OPERAND_UIMM12";
  let OperandNamespace = "RISCVOp";
}

// tuimm5 predicate - same ass uimm, but use TargetConstant (TImmLeaf)
// instead of Constant (ImmLeaf)
// FIXME: factor common code between uimm5 and tuimm5
def tuimm5 : Operand<XLenVT>, TImmLeaf<XLenVT, [{return isUInt<5>(Imm);}]> {
  let ParserMatchClass = UImmAsmOperand<5>;
  let DecoderMethod = "decodeUImmOperand<5>";
  let OperandType = "OPERAND_UIMM5";
  let OperandNamespace = "RISCVOp";
}

def powerOf2Minus1      : TImmLeaf<XLenVT, [{ return isPowerOf2_32(Imm+1);   }]>;
def negativePowerOf2    : TImmLeaf<XLenVT, [{ return isPowerOf2_32(-Imm);    }]>;
def powerOf2            : TImmLeaf<XLenVT, [{ return isPowerOf2_32(Imm);     }]>;
def mask                : TImmLeaf<XLenVT, [{ return isMask_32(Imm);         }]>;
def flippedMask         : TImmLeaf<XLenVT, [{ return isMask_32(~Imm);        }]>;
def shiftedMask         : TImmLeaf<XLenVT, [{ return isShiftedMask_32(Imm);  }]>;
def shiftedFlippedMask  : TImmLeaf<XLenVT, [{ return isShiftedMask_32(~Imm); }]>;

//===----------------------------------------------------------------------===//
// Operand and SDNode transformation definitions.
//===----------------------------------------------------------------------===//

def trailing1sPlus1 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(
                          countTrailingOnes<uint32_t>(N->getSExtValue()) + 1,
                          SDLoc(N), N->getValueType(0));
}]>;

def 31minus : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(31 - N->getSExtValue(),
                                   SDLoc(N), N->getValueType(0));
}]>;

def extractOffset : SDNodeXForm<sra, [{
  return CurDAG->getTargetConstant(N->getConstantOperandVal(1)
                                   - N->getOperand(0)->getConstantOperandVal(1),
                                   SDLoc(N), N->getValueType(0));
}]>;

def trailing1s : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(
                          countTrailingOnes<uint32_t>(N->getSExtValue()),
                          SDLoc(N), N->getValueType(0));
}]>;

def flippedMaskWidthMinus1 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(31
                          - countLeadingOnes<uint32_t>(N->getSExtValue())
                          - countTrailingOnes<uint32_t>(N->getSExtValue()),
                          SDLoc(N), N->getValueType(0));
}]>;

def trailing0s : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(
                          countTrailingZeros<uint32_t>(N->getSExtValue()),
                          SDLoc(N), N->getValueType(0));
}]>;

def maskWidthMinus1 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(31
                          - countLeadingZeros<uint32_t>(N->getSExtValue())
                          - countTrailingZeros<uint32_t>(N->getSExtValue()),
                          SDLoc(N), N->getValueType(0));
}]>;

// // Converts an immediate offset into an immediate mask with
// // only one bit set in the position specified by the offset
// // value itself (aka: at an offset from the lsb)
// def offsetMask : SDNodeXForm<timm, [{
//   return CurDAG->getTargetConstant(0x1u << N->getSExtValue(),
//                                    SDLoc(N), N->getValueType(0));
// }]>;

//===----------------------------------------------------------------------===//
// Opcodes
//===----------------------------------------------------------------------===//

// Post-increment operations
def OPC_PULP_LPI : RISCVOpcode<"PULP_LPI", 0b0001011>;
def OPC_PULP_SPI : RISCVOpcode<"PULP_SPI", 0b0101011>;
def OPC_PULP_LPI_RR : RISCVOpcode<"PULP_LPI_RR", 0b0000011>;
def OPC_PULP_SPI_RR : RISCVOpcode<"PULP_SPI_RR", 0b0100011>;
// General ALU operations, PULP extended
def OPC_PULP_OP : RISCVOpcode<"PULP_OP", 0b1011011>;

//===----------------------------------------------------------------------===//
// Instruction class templates
//===----------------------------------------------------------------------===//

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in {

class Pulp_ALU_r<bits<7> funct7, bits<3> funct3,
                 RISCVOpcode opcode, string opcodestr>
    : RVInstR<funct7, funct3, opcode, (outs GPR:$rd), (ins GPR:$rs1),
              opcodestr, "$rd, $rs1">,
      Sched<[WriteIALU, ReadIALU]> {
  let rs2 = 0;
}

class Pulp_ALU_rr<bits<7> funct7, bits<3> funct3, RISCVOpcode opcode, string opcodestr,
                  RegisterClass ty1 = GPR, RegisterClass ty2 = ty1, RegisterClass resty = ty1>
    : RVInstR<funct7, funct3, opcode, (outs resty:$rd), (ins ty1:$rs1, ty2:$rs2),
              opcodestr, "$rd, $rs1, $rs2">,
      Sched<[WriteIALU, ReadIALU, ReadIALU]>;

class Pulp_ALU_rr_wb<bits<7> funct7, bits<3> funct3, RISCVOpcode opcode, string opcodestr,
                     RegisterClass ty1 = GPR, RegisterClass ty2 = ty1, RegisterClass resty = ty1>
    : RVInstR<funct7, funct3, opcode, (outs resty:$rd_wb), (ins resty:$rd, ty1:$rs1, ty2:$rs2),
              opcodestr, "$rd, $rs1, $rs2">,
      Sched<[WriteIALU, ReadIALU, ReadIALU]> {
  let Constraints = "$rd = $rd_wb";
}

class Pulp_ALU_ri<bits<7> funct7, bits<3> funct3, string opcodestr>
    : RVInstR<funct7, funct3, OPC_OP, (outs GPR:$rd), (ins GPR:$rs1, uimm5:$rs2),
              opcodestr, "$rd, $rs1, $rs2">,
      Sched<[WriteIALU, ReadIALU]>;

class Pulp_ALU_rii<bits<2> funct2, bits<3> funct3, string opcodestr>
    : RVInst<(outs GPR:$rd), (ins GPR:$rs1, uimm5:$Is3, uimm5:$Is2),
              opcodestr, "$rd, $rs1, $Is3, $Is2", [], InstFormatOther>,
      Sched<[WriteIALU, ReadIALU]> {
  bits<5> Is3;
  bits<5> Is2;
  bits<5> rs1;
  bits<5> rd;

  let Inst{31-30} = funct2;
  let Inst{29-25} = Is3;
  let Inst{24-20} = Is2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = funct3;
  let Inst{11-7} = rd;
  let Opcode = 0b0110011;
}

class Pulp_ALU_rii_wb<bits<2> funct2, bits<3> funct3, string opcodestr>
    : RVInst<(outs GPR:$rd_wb), (ins GPR:$rd, GPR:$rs1, uimm5:$Is3, uimm5:$Is2),
              opcodestr, "$rd, $rs1, $Is3, $Is2", [], InstFormatOther>,
      Sched<[WriteIALU, ReadIALU]> {
  bits<5> Is3;
  bits<5> Is2;
  bits<5> rs1;
  bits<5> rd;

  let Inst{31-30} = funct2;
  let Inst{29-25} = Is3;
  let Inst{24-20} = Is2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = funct3;
  let Inst{11-7} = rd;
  let Opcode = 0b0110011;

  let Constraints = "$rd = $rd_wb";
}

class Pulp_ALU_rri<bits<2> funct2, bits<3> funct3, RISCVOpcode opcode, string opcodestr>
    : RVInst<(outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2, uimm5:$Is3),
              opcodestr, "$rd, $rs1, $rs2, $Is3", [], InstFormatOther>,
      Sched<[WriteIALU, ReadIALU, ReadIALU]> {
  bits<5> Is3;
  bits<5> rs2;
  bits<5> rs1;
  bits<5> rd;

  let Inst{31-30} = funct2;
  let Inst{29-25} = Is3;
  let Inst{24-20} = rs2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = funct3;
  let Inst{11-7} = rd;
  let Opcode = opcode.Value;
}

class Pulp_ALU_rri_wb<bits<2> funct2, bits<3> funct3, RISCVOpcode opcode, string opcodestr>
    : RVInst<(outs GPR:$rd_wb), (ins GPR:$rd, GPR:$rs1, GPR:$rs2, uimm5:$Is3),
              opcodestr, "$rd, $rs1, $rs2, $Is3", [], InstFormatOther>,
      Sched<[WriteIALU, ReadIALU, ReadIALU]> {
  bits<5> Is3;
  bits<5> rs2;
  bits<5> rs1;
  bits<5> rd;

  let Inst{31-30} = funct2;
  let Inst{29-25} = Is3;
  let Inst{24-20} = rs2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = funct3;
  let Inst{11-7} = rd;
  let Opcode = opcode.Value;

  let Constraints = "$rd = $rd_wb";
}

} // let hasSideEffects = 0, mayLoad = 0, mayStore = 0

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
class Pulp_ALU_vsci<bits<5> funct5, bit F, bits<3> funct3, string opcodestr,
                    RegisterClass vec, Operand sci, RegisterClass res = vec>
    : RVInst<(outs res:$rd), (ins vec:$rs1, sci:$Imm6), opcodestr,
             "$rd, $rs1, $Imm6", [], InstFormatOther>,
      Sched<[WriteIALU, ReadIALU]> {
  bits<6> Imm6;
  bits<5> rs1;
  bits<5> rd;

  let Inst{31-27} = funct5;
  let Inst{26} = F;
  let Inst{25} = Imm6{0};
  let Inst{24-20} = Imm6{5-1};
  let Inst{19-15} = rs1;
  let Inst{14-12} = funct3;
  let Inst{11-7} = rd;
  let Opcode = 0b1010111;
}

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
class Pulp_ALU_vsci_wb<bits<5> funct5, bit F, bits<3> funct3, string opcodestr,
                    RegisterClass vec, Operand sci, RegisterClass res = vec>
    : RVInst<(outs res:$rd_wb), (ins res:$rd, vec:$rs1, sci:$Imm6), opcodestr,
             "$rd, $rs1, $Imm6", [], InstFormatOther>,
      Sched<[WriteIALU, ReadIALU]> {
  bits<6> Imm6;
  bits<5> rs1;
  bits<5> rd;

  let Constraints = "$rd = $rd_wb";
  let Inst{31-27} = funct5;
  let Inst{26} = F;
  let Inst{25} = Imm6{0};
  let Inst{24-20} = Imm6{5-1};
  let Inst{19-15} = rs1;
  let Inst{14-12} = funct3;
  let Inst{11-7} = rd;
  let Opcode = 0b1010111;
}

let hasSideEffects = 0, mayLoad = 0, mayStore = 0, isBranch = 1, isTerminator = 1 in
class Pulp_Immediate_Branch<bits<3> funct3, string opcodestr>
      : RVInstB<funct3, OPC_BRANCH, (outs),
                (ins GPR:$rs1, simm5:$rs2, simm13_lsb0:$imm12),
                opcodestr, "$rs1, $rs2, $imm12">,
        Sched<[WriteJmp, ReadJmp, ReadJmp]>;

multiclass SC_SCI_H_B<bits<5> funct5, bit F, Operand sci, string opcodestr> {
  def _H     : Pulp_ALU_rr<{funct5, F, 0}, 0b000, OPC_OP_V, "pv." # opcodestr # ".h", PulpV2>;
  def _SC_H  : Pulp_ALU_rr<{funct5, F, 0}, 0b100, OPC_OP_V, "pv." # opcodestr # ".sc.h", PulpV2, GPR>;
  def _SCI_H : Pulp_ALU_vsci<funct5, F,    0b110,                         "pv." # opcodestr # ".sci.h", PulpV2, sci>;
  def _B     : Pulp_ALU_rr<{funct5, F, 0}, 0b001, OPC_OP_V, "pv." # opcodestr # ".b", PulpV4>;
  def _SC_B  : Pulp_ALU_rr<{funct5, F, 0}, 0b101, OPC_OP_V, "pv." # opcodestr # ".sc.b", PulpV4, GPR>;
  def _SCI_B : Pulp_ALU_vsci<funct5, F,    0b111,                         "pv." # opcodestr # ".sci.b", PulpV4, sci>;
}

multiclass DOTP<bits<5> funct5, bit F, Operand sci, string opcodestr> {
  def _H     : Pulp_ALU_rr<{funct5, F, 0}, 0b000, OPC_OP_V, "pv." # opcodestr # ".h", PulpV2, PulpV2, GPR>;
  def _SC_H  : Pulp_ALU_rr<{funct5, F, 0}, 0b100, OPC_OP_V, "pv." # opcodestr # ".sc.h", PulpV2, GPR, GPR>;
  def _SCI_H : Pulp_ALU_vsci<funct5, F,    0b110,                         "pv." # opcodestr # ".sci.h", PulpV2, sci, GPR>;
  def _B     : Pulp_ALU_rr<{funct5, F, 0}, 0b001, OPC_OP_V, "pv." # opcodestr # ".b", PulpV4, PulpV4, GPR>;
  def _SC_B  : Pulp_ALU_rr<{funct5, F, 0}, 0b101, OPC_OP_V, "pv." # opcodestr # ".sc.b", PulpV4, GPR, GPR>;
  def _SCI_B : Pulp_ALU_vsci<funct5, F,    0b111,                         "pv." # opcodestr # ".sci.b", PulpV4, sci, GPR>;
}

multiclass SDOTP<bits<5> funct5, bit F, Operand sci, string opcodestr> {
  def _H     : Pulp_ALU_rr_wb<{funct5, F, 0}, 0b000, OPC_OP_V, "pv." # opcodestr # ".h", PulpV2, PulpV2, GPR>;
  def _SC_H  : Pulp_ALU_rr_wb<{funct5, F, 0}, 0b100, OPC_OP_V, "pv." # opcodestr # ".sc.h", PulpV2, GPR, GPR>;
  def _SCI_H : Pulp_ALU_vsci_wb<funct5, F,    0b110,                         "pv." # opcodestr # ".sci.h", PulpV2, sci, GPR>;
  def _B     : Pulp_ALU_rr_wb<{funct5, F, 0}, 0b001, OPC_OP_V, "pv." # opcodestr # ".b", PulpV4, PulpV4, GPR>;
  def _SC_B  : Pulp_ALU_rr_wb<{funct5, F, 0}, 0b101, OPC_OP_V, "pv." # opcodestr # ".sc.b", PulpV4, GPR, GPR>;
  def _SCI_B : Pulp_ALU_vsci_wb<funct5, F,    0b111,                         "pv." # opcodestr # ".sci.b", PulpV4, sci, GPR>;
}

let hasSideEffects = 0, mayLoad = 0, mayStore = 1 in
multiclass Pulp_Store<bits<2> funct2, string opcodestr> {

    def _ri_PostIncrement
      : RVInstS<{0, funct2}, OPC_PULP_SPI, (outs GPR:$rs1_wb),
      (ins GPR:$rs2, GPR:$rs1, simm12:$imm12), opcodestr, "$rs2, ${imm12}(${rs1}!)">{
        let Constraints = "$rs1 = $rs1_wb";
      }

    def _rr_PostIncrement
      : RVInstR<0b0000000, {1, funct2}, OPC_PULP_SPI, (outs GPR:$rs1_wb),
      (ins GPR:$rs2, GPR:$rs1, GPR:$rd), opcodestr, "$rs2, ${rd}(${rs1}!)">{
        let Constraints = "$rs1 = $rs1_wb";
      }

    def _rr
      : RVInstR<0b0000000, {1, funct2}, OPC_PULP_SPI_RR, (outs),
      (ins GPR:$rs2, GPR:$rs1, GPR:$rd), opcodestr, "$rs2, ${rd}(${rs1})">;
}

let hasSideEffects = 0, mayLoad = 1, mayStore = 0 in
multiclass Pulp_Load<bits<7> funct7, bits<3> funct3, string opcodestr> {

  def _ri_PostIncrement
    : RVInstI<funct3, OPC_PULP_LPI, (outs GPR:$rd, GPR:$rs1_wb),
    (ins GPR:$rs1, simm12:$imm12), opcodestr, "$rd, ${imm12}(${rs1}!)">{
      let Constraints = "$rs1 = $rs1_wb";
    }

  def _rr_PostIncrement
    : RVInstR<funct7, 0b111, OPC_PULP_LPI, (outs GPR:$rd, GPR:$rs1_wb),
    (ins GPR:$rs1, GPR:$rs2), opcodestr, "$rd, ${rs2}(${rs1}!)">{
      let Constraints = "$rs1 = $rs1_wb";
    }

  def _rr
    : RVInstR<funct7, 0b111, OPC_PULP_LPI_RR, (outs GPR:$rd),
    (ins GPR:$rs1, GPR:$rs2), opcodestr, "$rd, ${rs2}(${rs1})">;
}

//===----------------------------------------------------------------------===//
// Instructions
//===----------------------------------------------------------------------===//

let Predicates = [IsRV32, HasPULPExtElw], DecoderNamespace = "RV32Xpulpelw" in {
let hasSideEffects = 1, mayStore = 1 in
  def PULP_ELW : Load_ri<0b110, "p.elw">, Sched<[WriteLDW, ReadMemBase]>;
} // Predicates = [IsRV32, HasPULPExtElw], DecoderNamespace = "RV32Xpulpelw"

// Hardware loops
let Predicates = [IsRV32, HasPULPExtHwloop], DecoderNamespace = "RV32Xpulphwloop" in {
def LOOP0setup : Instruction, Sched<[ReadIALU, WriteCSR]> {

    bits<32> Inst;
    bits<32> SoftFail = 0;
    bits<12> uimmL;
    bits<5> rs1;

    let Namespace = "RISCV";
    let hasSideEffects = 1;
    let mayLoad = 0;
    let mayStore = 0;
    let Size = 4;
    let isTerminator = 1;

    let Inst{31-20} = uimmL;
    let Inst{19-15} = rs1;
    let Inst{14-12} = 0b100;
    let Inst{11-8} = 0b0000;
    let Inst{7} = 0b0;
    let Inst{6-0} = 0b1111011;

    dag InOperandList = (ins uimm12pcrel:$uimmL, GPR:$rs1);
    dag OutOperandList = (outs);

    let AsmString = "lp.setup\tx0, $rs1, $uimmL";
}

def LOOP1setup : Instruction, Sched<[ReadIALU, WriteCSR]> {

    bits<32> Inst;
    bits<32> SoftFail = 0;
    bits<12> uimmL;
    bits<5> rs1;

    let Namespace = "RISCV";
    let hasSideEffects = 1;
    let mayLoad = 0;
    let mayStore = 0;
    let Size = 4;
    let isTerminator = 1;

    let Inst{31-20} = uimmL;
    let Inst{19-15} = rs1;
    let Inst{14-12} = 0b100;
    let Inst{11-8} = 0b0000;
    let Inst{7} = 0b1;
    let Inst{6-0} = 0b1111011;

    dag InOperandList = (ins uimm12pcrel:$uimmL, GPR:$rs1);
    dag OutOperandList = (outs);

    let AsmString = "lp.setup\tx1, $rs1, $uimmL";
}

def LOOP0setupi : Instruction, Sched<[WriteCSR]> {

    bits<32> Inst;
    bits<32> SoftFail = 0;
    bits<12> uimmL;
    bits<5> uimmS;

    let Namespace = "RISCV";
    let hasSideEffects = 1;
    let mayLoad = 0;
    let mayStore = 0;
    let Size = 4;
    let isTerminator = 1;

    let Inst{31-20} = uimmL;
    let Inst{19-15} = uimmS;
    let Inst{14-12} = 0b101;
    let Inst{11-8} = 0b0000;
    let Inst{7} = 0b0;
    let Inst{6-0} = 0b1111011;

    dag InOperandList = (ins uimm5:$uimmS, uimm12pcrel:$uimmL);
    dag OutOperandList = (outs);

    let AsmString = "lp.setupi\tx0, $uimmL, $uimmS";

}

def LOOP1setupi : Instruction, Sched<[WriteCSR]> {

    bits<32> Inst;
    bits<32> SoftFail = 0;
    bits<12> uimmL;
    bits<5> uimmS;

    let Namespace = "RISCV";
    let hasSideEffects = 1;
    let mayLoad = 0;
    let mayStore = 0;
    let Size = 4;
    let isTerminator = 1;

    let Inst{31-20} = uimmL;
    let Inst{19-15} = uimmS;
    let Inst{14-12} = 0b101;
    let Inst{11-8} = 0b0000;
    let Inst{7} = 0b1;
    let Inst{6-0} = 0b1111011;

    dag InOperandList = (ins uimm5:$uimmS, uimm12pcrel:$uimmL);
    dag OutOperandList = (outs);

    let AsmString = "lp.setupi\tx1, $uimmL, $uimmS";

}

def LOOP0starti : Instruction, Sched<[WriteCSR]> {

    bits<32> Inst;
    bits<32> SoftFail = 0;
    bits<12> uimmL;

    let Namespace = "RISCV";
    let hasSideEffects = 1;
    let mayLoad = 0;
    let mayStore = 0;
    let Size = 4;
    let isTerminator = 1;

    let Inst{31-20} = uimmL;
    let Inst{19-15} = 0b00000;
    let Inst{14-12} = 0b000;
    let Inst{11-8} = 0b0000;
    let Inst{7} = 0b0;
    let Inst{6-0} = 0b1111011;

    dag InOperandList = (ins uimm12pcrel:$uimmL);
    dag OutOperandList = (outs);

    let AsmString = "lp.starti\tx0, $uimmL";

}

def LOOP1starti : Instruction, Sched<[WriteCSR]> {

    bits<32> Inst;
    bits<32> SoftFail = 0;
    bits<12> uimmL;

    let Namespace = "RISCV";
    let hasSideEffects = 1;
    let mayLoad = 0;
    let mayStore = 0;
    let Size = 4;
    let isTerminator = 1;

    let Inst{31-20} = uimmL;
    let Inst{19-15} = 0b00000;
    let Inst{14-12} = 0b000;
    let Inst{11-8} = 0b0000;
    let Inst{7} = 0b1;
    let Inst{6-0} = 0b1111011;

    dag InOperandList = (ins uimm12pcrel:$uimmL);
    dag OutOperandList = (outs);

    let AsmString = "lp.starti\tx1, $uimmL";

}

def LOOP0endi : Instruction, Sched<[WriteCSR]> {

    bits<32> Inst;
    bits<32> SoftFail = 0;
    bits<12> uimmL;

    let Namespace = "RISCV";
    let hasSideEffects = 1;
    let mayLoad = 0;
    let mayStore = 0;
    let Size = 4;
    let isTerminator = 1;

    let Inst{31-20} = uimmL;
    let Inst{19-15} = 0b00000;
    let Inst{14-12} = 0b001;
    let Inst{11-8} = 0b0000;
    let Inst{7} = 0b0;
    let Inst{6-0} = 0b1111011;

    dag InOperandList = (ins uimm12pcrel:$uimmL);
    dag OutOperandList = (outs);

    let AsmString = "lp.endi\tx0, $uimmL";

}

def LOOP1endi : Instruction, Sched<[WriteCSR]> {

    bits<32> Inst;
    bits<32> SoftFail = 0;
    bits<12> uimmL;

    let Namespace = "RISCV";
    let hasSideEffects = 1;
    let mayLoad = 0;
    let mayStore = 0;
    let Size = 4;
    let isTerminator = 1;

    let Inst{31-20} = uimmL;
    let Inst{19-15} = 0b00000;
    let Inst{14-12} = 0b001;
    let Inst{11-8} = 0b0000;
    let Inst{7} = 0b1;
    let Inst{6-0} = 0b1111011;

    dag InOperandList = (ins uimm12pcrel:$uimmL);
    dag OutOperandList = (outs);

    let AsmString = "lp.endi\tx1, $uimmL";

}

def LOOP0counti : Instruction, Sched<[WriteCSR]> {

    bits<32> Inst;
    bits<32> SoftFail = 0;
    bits<12> uimmL;

    let Namespace = "RISCV";
    let hasSideEffects = 1;
    let mayLoad = 0;
    let mayStore = 0;
    let Size = 4;
    let isTerminator = 1;

    let Inst{31-20} = uimmL;
    let Inst{19-15} = 0b00000;
    let Inst{14-12} = 0b011;
    let Inst{11-8} = 0b0000;
    let Inst{7} = 0b0;
    let Inst{6-0} = 0b1111011;

    dag InOperandList = (ins uimm12pcrel:$uimmL);
    dag OutOperandList = (outs);

    let AsmString = "lp.counti\tx0, $uimmL";

}

def LOOP1counti : Instruction, Sched<[WriteCSR]> {

    bits<32> Inst;
    bits<32> SoftFail = 0;
    bits<12> uimmL;

    let Namespace = "RISCV";
    let hasSideEffects = 1;
    let mayLoad = 0;
    let mayStore = 0;
    let Size = 4;
    let isTerminator = 1;

    let Inst{31-20} = uimmL;
    let Inst{19-15} = 0b00000;
    let Inst{14-12} = 0b011;
    let Inst{11-8} = 0b0000;
    let Inst{7} = 0b1;
    let Inst{6-0} = 0b1111011;

    dag InOperandList = (ins uimm12pcrel:$uimmL);
    dag OutOperandList = (outs);

    let AsmString = "lp.counti\tx1, $uimmL";

}

def LOOP0count : Instruction, Sched<[ReadIALU, WriteCSR]> {

    bits<32> Inst;
    bits<32> SoftFail = 0;
    bits<5> uimmS;

    let Namespace = "RISCV";
    let hasSideEffects = 1;
    let mayLoad = 0;
    let mayStore = 0;
    let Size = 4;
    let isTerminator = 1;

    let Inst{31-20} = 0b000000000000;
    let Inst{19-15} = uimmS;
    let Inst{14-12} = 0b010;
    let Inst{11-8} = 0b0000;
    let Inst{7} = 0b0;
    let Inst{6-0} = 0b1111011;

    dag InOperandList = (ins uimm5:$uimmS);
    dag OutOperandList = (outs);

    let AsmString = "lp.count\tx0, $uimmS";

}

def LOOP1count : Instruction, Sched<[ReadIALU, WriteCSR]> {

    bits<32> Inst;
    bits<32> SoftFail = 0;
    bits<5> uimmS;

    let Namespace = "RISCV";
    let hasSideEffects = 1;
    let mayLoad = 0;
    let mayStore = 0;
    let Size = 4;
    let isTerminator = 1;

    let Inst{31-20} = 0b000000000000;
    let Inst{19-15} = uimmS;
    let Inst{14-12} = 0b010;
    let Inst{11-8} = 0b0000;
    let Inst{7} = 0b1;
    let Inst{6-0} = 0b1111011;

    dag InOperandList = (ins uimm5:$uimmS);
    dag OutOperandList = (outs);

    let AsmString = "lp.count\tx1, $uimmS";
}
} // Predicates = [IsRV32, HasPULPExtHwloop], DecoderNamespace = "RV32Xpulphwloop"

let Predicates = [IsRV32, HasPULPExtBitop], DecoderNamespace = "RV32Xpulpbitop" in {
// Bit manipulation operations
def P_EXTRACT :   Pulp_ALU_rii   <0b11, 0b000, "p.extract">;
def P_EXTRACTU :  Pulp_ALU_rii   <0b11, 0b001, "p.extractu">;
def P_INSERT :    Pulp_ALU_rii_wb<0b11, 0b010, "p.insert">;
def P_BCLR :      Pulp_ALU_rii   <0b11, 0b011, "p.bclr">;
def P_BSET :      Pulp_ALU_rii   <0b11, 0b100, "p.bset">;

def P_EXTRACTR :  Pulp_ALU_rr   <0b1000000, 0b000, OPC_OP, "p.extractr">;
def P_EXTRACTUR : Pulp_ALU_rr   <0b1000000, 0b001, OPC_OP, "p.extractur">;
def P_INSERTR :   Pulp_ALU_rr_wb<0b1000000, 0b010, OPC_OP, "p.insertr">;
def P_BCLRR :     Pulp_ALU_rr   <0b1000000, 0b011, OPC_OP, "p.bclrr">;
def P_BSETR :     Pulp_ALU_rr   <0b1000000, 0b100, OPC_OP, "p.bsetr">;

def P_ROR :       Pulp_ALU_rr<0b0000100, 0b101, OPC_OP, "p.ror">;
def P_FF1 :       Pulp_ALU_r <0b0001000, 0b000, OPC_OP, "p.ff1">;
def P_FL1 :       Pulp_ALU_r <0b0001000, 0b001, OPC_OP, "p.fl1">;
def P_CLB :       Pulp_ALU_r <0b0001000, 0b010, OPC_OP, "p.clb">;
def P_CNT :       Pulp_ALU_r <0b0001000, 0b011, OPC_OP, "p.cnt">;

def P_EXTHS :  Pulp_ALU_r <0b0001000, 0b100, OPC_OP, "p.exths">;
def P_EXTHZ :  Pulp_ALU_r <0b0001000, 0b101, OPC_OP, "p.exthz">;
def P_EXTBS :  Pulp_ALU_r <0b0001000, 0b110, OPC_OP, "p.extbs">;
def P_EXTBZ :  Pulp_ALU_r <0b0001000, 0b111, OPC_OP, "p.extbz">;
} // Predicates = [IsRV32, HasPULPExtBitop], DecoderNamespace = "RV32Xpulpbitop"


// General ALU operations
let Predicates = [IsRV32, HasPULPExtAbs], DecoderNamespace = "RV32Xpulpabs" in {
def P_ABS :    Pulp_ALU_r <0b0000010, 0b000, OPC_OP, "p.abs">;
} // Predicates = [IsRV32, HasPULPExtAbs], DecoderNamespace = "RV32Xpulpabs"

let Predicates = [IsRV32, HasPULPExtSlet], DecoderNamespace = "RV32Xpulpslet" in {
def P_SLET :   Pulp_ALU_rr<0b0000010, 0b010, OPC_OP, "p.slet">;
def P_SLETU :  Pulp_ALU_rr<0b0000010, 0b011, OPC_OP, "p.sletu">;
} // Predicates = [IsRV32, HasPULPExtSlet], DecoderNamespace = "RV32Xpulpslet"

let Predicates = [IsRV32, HasPULPExtMinmax], DecoderNamespace = "RV32Xpulpminmax" in {
def P_MIN :    Pulp_ALU_rr<0b0000010, 0b100, OPC_OP, "p.min">;
def P_MINU :   Pulp_ALU_rr<0b0000010, 0b101, OPC_OP, "p.minu">;
def P_MAX :    Pulp_ALU_rr<0b0000010, 0b110, OPC_OP, "p.max">;
def P_MAXU :   Pulp_ALU_rr<0b0000010, 0b111, OPC_OP, "p.maxu">;
} // Predicates = [IsRV32, HasPULPExtMinmax], DecoderNamespace = "RV32Xpulpminmax"

let Predicates = [IsRV32, HasPULPExtClip], DecoderNamespace = "RV32Xpulpclip" in {
def P_CLIP :   Pulp_ALU_ri<0b0001010, 0b001, "p.clip">;
def P_CLIPU :  Pulp_ALU_ri<0b0001010, 0b010, "p.clipu">;
def P_CLIPR :  Pulp_ALU_rr<0b0001010, 0b101, OPC_OP, "p.clipr">;
def P_CLIPUR : Pulp_ALU_rr<0b0001010, 0b110, OPC_OP, "p.clipur">;
} // Predicates = [IsRV32, HasPULPExtClip], DecoderNamespace = "RV32Xpulpclip"

let Predicates = [IsRV32, HasPULPExtAddsubrn], DecoderNamespace = "RV32Xpulpaddsubrn" in {
def P_ADDN :    Pulp_ALU_rri<0b00, 0b010, OPC_PULP_OP, "p.addn">;
def P_ADDUN :   Pulp_ALU_rri<0b10, 0b010, OPC_PULP_OP, "p.addun">;
def P_ADDRN :   Pulp_ALU_rri<0b00, 0b110, OPC_PULP_OP, "p.addrn">;
def P_ADDURN :  Pulp_ALU_rri<0b10, 0b110, OPC_PULP_OP, "p.addurn">;
def P_SUBN :    Pulp_ALU_rri<0b00, 0b011, OPC_PULP_OP, "p.subn">;
def P_SUBUN :   Pulp_ALU_rri<0b10, 0b011, OPC_PULP_OP, "p.subun">;
def P_SUBRN :   Pulp_ALU_rri<0b00, 0b111, OPC_PULP_OP, "p.subrn">;
def P_SUBURN :  Pulp_ALU_rri<0b10, 0b111, OPC_PULP_OP, "p.suburn">;
def P_ADDNR :   Pulp_ALU_rr_wb<0b0100000, 0b010, OPC_PULP_OP, "p.addnr">;
def P_ADDUNR :  Pulp_ALU_rr_wb<0b1100000, 0b010, OPC_PULP_OP, "p.addunr">;
def P_ADDRNR :  Pulp_ALU_rr_wb<0b0100000, 0b110, OPC_PULP_OP, "p.addrnr">;
def P_ADDURNR : Pulp_ALU_rr_wb<0b1100000, 0b110, OPC_PULP_OP, "p.addurnr">;
def P_SUBNR :   Pulp_ALU_rr_wb<0b0100000, 0b011, OPC_PULP_OP, "p.subnr">;
def P_SUBUNR :  Pulp_ALU_rr_wb<0b1100000, 0b011, OPC_PULP_OP, "p.subunr">;
def P_SUBRNR :  Pulp_ALU_rr_wb<0b0100000, 0b111, OPC_PULP_OP, "p.subrnr">;
def P_SUBURNR : Pulp_ALU_rr_wb<0b1100000, 0b111, OPC_PULP_OP, "p.suburnr">;
} // Predicates = [IsRV32, HasPULPExtAddsubrn], DecoderNamespace = "RV32Xpulpaddsubrn"

let Predicates = [IsRV32, HasPULPExtBr], DecoderNamespace = "RV32Xpulpbr" in {
// Instructions: immediate branches
def P_BEQIMM : Pulp_Immediate_Branch<0b010, "p.beqimm">;
def P_BNEIMM : Pulp_Immediate_Branch<0b011, "p.bneimm">;
} // Predicates = [IsRV32, HasPULPExtBr], DecoderNamespace = "RV32Xpulpbr"

let Predicates = [IsRV32, HasPULPExtMacsi], DecoderNamespace = "RV32Xpulpmacsi" in {
// Instructions: MAC operations
def P_MAC :      Pulp_ALU_rr_wb<0b0100001, 0b000, OPC_OP, "p.mac">;
def P_MSU :      Pulp_ALU_rr_wb<0b0100001, 0b001, OPC_OP, "p.msu">;
} // Predicates = [IsRV32, HasPULPExtMacsi], DecoderNamespace = "RV32Xpulpmacsi"

let Predicates = [IsRV32, HasPULPExtMulrnhi], DecoderNamespace = "RV32Xpulpmulrnhi" in {
def P_MULS :     Pulp_ALU_rr   <0b1000000, 0b000, OPC_PULP_OP, "p.muls">;
def P_MULHHS :   Pulp_ALU_rr   <0b1100000, 0b000, OPC_PULP_OP, "p.mulhhs">;
def P_MULSN :    Pulp_ALU_rri       <0b10, 0b000, OPC_PULP_OP, "p.mulsn">;
def P_MULHHSN :  Pulp_ALU_rri       <0b11, 0b000, OPC_PULP_OP, "p.mulhhsn">;
def P_MULSRN :   Pulp_ALU_rri       <0b10, 0b100, OPC_PULP_OP, "p.mulsrn">;
def P_MULHHSRN : Pulp_ALU_rri       <0b11, 0b100, OPC_PULP_OP, "p.mulhhsrn">;
def P_MULU :     Pulp_ALU_rr   <0b0000000, 0b000, OPC_PULP_OP, "p.mulu">;
def P_MULHHU :   Pulp_ALU_rr   <0b0100000, 0b000, OPC_PULP_OP, "p.mulhhu">;
def P_MULUN :    Pulp_ALU_rri       <0b00, 0b000, OPC_PULP_OP, "p.mulun">;
def P_MULHHUN :  Pulp_ALU_rri       <0b01, 0b000, OPC_PULP_OP, "p.mulhhun">;
def P_MULURN :   Pulp_ALU_rri       <0b00, 0b100, OPC_PULP_OP, "p.mulurn">;
def P_MULHHURN : Pulp_ALU_rri       <0b01, 0b100, OPC_PULP_OP, "p.mulhhurn">;
} // Predicates = [IsRV32, HasPULPExtMulrnhi], DecoderNamespace = "RV32Xpulpmulrnhi"

let Predicates = [IsRV32, HasPULPExtMacrnhi], DecoderNamespace = "RV32Xpulpmacrnhi" in {
def P_MACSN :    Pulp_ALU_rri_wb    <0b10, 0b001, OPC_PULP_OP, "p.macsn">;
def P_MACHHSN :  Pulp_ALU_rri_wb    <0b11, 0b001, OPC_PULP_OP, "p.machhsn">;
def P_MACSRN :   Pulp_ALU_rri_wb    <0b10, 0b101, OPC_PULP_OP, "p.macsrn">;
def P_MACHHSRN : Pulp_ALU_rri_wb    <0b11, 0b101, OPC_PULP_OP, "p.machhsrn">;
def P_MACUN :    Pulp_ALU_rri_wb    <0b00, 0b001, OPC_PULP_OP, "p.macun">;
def P_MACHHUN :  Pulp_ALU_rri_wb    <0b01, 0b001, OPC_PULP_OP, "p.machhun">;
def P_MACURN :   Pulp_ALU_rri_wb    <0b00, 0b101, OPC_PULP_OP, "p.macurn">;
def P_MACHHURN : Pulp_ALU_rri_wb    <0b01, 0b101, OPC_PULP_OP, "p.machhurn">;
} // Predicates = [IsRV32, HasPULPExtMacrnhi], DecoderNamespace = "RV32Xpulpmacrnhi"

let Predicates = [IsRV32, HasPULPExtPartmac], DecoderNamespace = "RV32Xpulppartmac" in {
def P_MACS :     Pulp_ALU_rr_wb<0b1000000, 0b001, OPC_PULP_OP, "p.macs">;
def P_MACHHS :   Pulp_ALU_rr_wb<0b1100000, 0b001, OPC_PULP_OP, "p.machhs">;
def P_MACU :     Pulp_ALU_rr_wb<0b0000000, 0b001, OPC_PULP_OP, "p.macu">;
def P_MACHHU :   Pulp_ALU_rr_wb<0b0100000, 0b001, OPC_PULP_OP, "p.machhu">;
} // Predicates = [IsRV32, HasPULPExtPartmac], DecoderNamespace = "RV32Xpulppartmac"

let Predicates = [IsRV32, HasPULPExtVect], DecoderNamespace = "RV32Xpulpvect" in {
// Instructions: packed vector ALU
defm PV_ADD  : SC_SCI_H_B<0b00000, 0, simm6, "add">;
defm PV_SUB  : SC_SCI_H_B<0b00001, 0, simm6, "sub">;
defm PV_AVG  : SC_SCI_H_B<0b00010, 0, simm6, "avg">;
defm PV_AVGU : SC_SCI_H_B<0b00011, 0, uimm6, "avgu">;
defm PV_MIN  : SC_SCI_H_B<0b00100, 0, simm6, "min">;
defm PV_MINU : SC_SCI_H_B<0b00101, 0, uimm6, "minu">;
defm PV_MAX  : SC_SCI_H_B<0b00110, 0, simm6, "max">;
defm PV_MAXU : SC_SCI_H_B<0b00111, 0, uimm6, "maxu">;
defm PV_SRL  : SC_SCI_H_B<0b01000, 0, uimm6, "srl">;
defm PV_SRA  : SC_SCI_H_B<0b01001, 0, uimm6, "sra">;
defm PV_SLL  : SC_SCI_H_B<0b01010, 0, uimm6, "sll">;
defm PV_OR   : SC_SCI_H_B<0b01011, 0, simm6, "or">;
defm PV_XOR  : SC_SCI_H_B<0b01100, 0, simm6, "xor">;
defm PV_AND  : SC_SCI_H_B<0b01101, 0, simm6, "and">;

let hasSideEffects = 0, mayStore = 0, mayLoad = 0, rs2 = 0 in {
  def PV_ABS_H : RVInstR<0b0111000, 0b000, OPC_OP_V,
                         (outs PulpV2:$rd), (ins PulpV2:$rs1),
                         "pv.abs.h", "$rd, $rs1">, Sched<[WriteIALU, ReadIALU]>;

  def PV_ABS_B : RVInstR<0b0111000, 0b001, OPC_OP_V,
                         (outs PulpV4:$rd), (ins PulpV4:$rs1),
                         "pv.abs.b", "$rd, $rs1">, Sched<[WriteIALU, ReadIALU]>;
}

// Pseudos used to lower vector splat operations on packed SIMD data types
let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in {
  def PseudoPV_ADD_SC_H_VL  : Pseudo<(outs PulpV2:$dst), (ins GPR:$src1, GPR:$src2, AVL:$vl),[]>;
  def PseudoPV_ADD_SC_B_VL  : Pseudo<(outs PulpV4:$dst), (ins GPR:$src1, GPR:$src2, AVL:$vl),[]>;
  def PseudoPV_ADD_SCI_H_VL : Pseudo<(outs PulpV2:$dst), (ins GPR:$src1, simm6:$imm, AVL:$vl),[]>;
  def PseudoPV_ADD_SCI_B_VL : Pseudo<(outs PulpV4:$dst), (ins GPR:$src1, simm6:$imm, AVL:$vl),[]>;
}

def PV_EXTRACT_H : Pulp_ALU_vsci<0b01111, 0, 0b110, "pv.extract.h", PulpV2, uimm6, GPR>;
def PV_EXTRACT_B : Pulp_ALU_vsci<0b01111, 0, 0b111, "pv.extract.b", PulpV4, uimm6, GPR>;
def PV_EXTRACTU_H : Pulp_ALU_vsci<0b10010, 0, 0b110, "pv.extractu.h", PulpV2, uimm6, GPR>;
def PV_EXTRACTU_B : Pulp_ALU_vsci<0b10010, 0, 0b111, "pv.extractu.b", PulpV4, uimm6, GPR>;
def PV_INSERT_H   : Pulp_ALU_vsci_wb<0b10110, 0, 0b110, "pv.insert.h", GPR, uimm6, PulpV2>;
def PV_INSERT_B   : Pulp_ALU_vsci_wb<0b10110, 0, 0b111, "pv.insert.b", GPR, uimm6, PulpV4>;

defm PV_DOTUP   : DOTP<0b10000, 0, uimm6, "dotup">;
defm PV_DOTUSP  : DOTP<0b10001, 0, simm6, "dotusp">;
defm PV_DOTSP   : DOTP<0b10011, 0, simm6, "dotsp">;
defm PV_SDOTUP  : SDOTP<0b10100, 0, uimm6, "sdotup">;
defm PV_SDOTUSP : SDOTP<0b10101, 0, simm6, "sdotusp">;
defm PV_SDOTSP  : SDOTP<0b10111, 0, simm6, "sdotsp">;

// Vectorial comparison operations
defm PV_CMPEQ  : SC_SCI_H_B<0b00000, 1, simm6, "cmpeq">;
defm PV_CMPNE  : SC_SCI_H_B<0b00001, 1, simm6, "cmpne">;
defm PV_CMPGT  : SC_SCI_H_B<0b00010, 1, simm6, "cmpgt">;
defm PV_CMPGE  : SC_SCI_H_B<0b00011, 1, simm6, "cmpge">;
defm PV_CMPLT  : SC_SCI_H_B<0b00100, 1, simm6, "cmplt">;
defm PV_CMPLE  : SC_SCI_H_B<0b00101, 1, simm6, "cmple">;
defm PV_CMPGTU : SC_SCI_H_B<0b00110, 1, uimm6, "cmpgtu">;
defm PV_CMPGEU : SC_SCI_H_B<0b00111, 1, uimm6, "cmpgeu">;
defm PV_CMPLTU : SC_SCI_H_B<0b01000, 1, uimm6, "cmpltu">;
defm PV_CMPLEU : SC_SCI_H_B<0b01001, 1, uimm6, "cmpleu">;

let isCodeGenOnly = 1 in { // Helper for Patterns
  def P_INSERTR_v2 : Pulp_ALU_rr_wb<0b1000000, 0b010, OPC_OP, "p.insertr", GPR, GPR, PulpV2>;
  def P_INSERTR_v4 : Pulp_ALU_rr_wb<0b1000000, 0b010, OPC_OP, "p.insertr", GPR, GPR, PulpV4>;
  def PV_SHUFFLE_H_GPR : Pulp_ALU_rr<0b1100000, 0b000, OPC_OP_V, "pv.shuffle.h", PulpV2, GPR, GPR>;
  def PV_SHUFFLE_B_GPR : Pulp_ALU_rr<0b1100000, 0b001, OPC_OP_V, "pv.shuffle.b", PulpV4, GPR, GPR>;
}
} // Predicates = [IsRV32, HasPULPExtVect], DecoderNamespace = "RV32Xpulpvect"

let Predicates = [IsRV32, HasPULPExtVectshufflepack], DecoderNamespace = "RV32Xpulpvectshufflepack" in {
def PV_SHUFFLE_H       : Pulp_ALU_rr<0b1100000, 0b000, OPC_OP_V, "pv.shuffle.h", PulpV2>;
def PV_SHUFFLE_SCI_H   : Pulp_ALU_vsci<0b11000, 0, 0b110, "pv.shuffle.sci.h", PulpV2, uimm6>;
def PV_SHUFFLE_B       : Pulp_ALU_rr<0b1100000, 0b001, OPC_OP_V, "pv.shuffle.b", PulpV4>;
def PV_SHUFFLEI0_SCI_B : Pulp_ALU_vsci<0b11000, 0, 0b111, "pv.shufflei0.sci.b", PulpV4, uimm6>;
def PV_SHUFFLEI1_SCI_B : Pulp_ALU_vsci<0b11101, 0, 0b111, "pv.shufflei1.sci.b", PulpV4, uimm6>;
def PV_SHUFFLEI2_SCI_B : Pulp_ALU_vsci<0b11110, 0, 0b111, "pv.shufflei2.sci.b", PulpV4, uimm6>;
def PV_SHUFFLEI3_SCI_B : Pulp_ALU_vsci<0b11111, 0, 0b111, "pv.shufflei3.sci.b", PulpV4, uimm6>;

def PV_SHUFFLE2_H : Pulp_ALU_rr_wb<0b1100100, 0b000, OPC_OP_V, "pv.shuffle2.h", PulpV2>;
def PV_SHUFFLE2_B : Pulp_ALU_rr_wb<0b1100100, 0b001, OPC_OP_V, "pv.shuffle2.b", PulpV4>;
def PV_PACK_H : Pulp_ALU_rr<0b1101000, 0b000, OPC_OP_V, "pv.pack.h", GPR, GPR, PulpV2>;
def PV_PACKHI_B : Pulp_ALU_rr_wb<0b1101100, 0b001, OPC_OP_V, "pv.packhi.b", GPR, GPR, PulpV4>;
def PV_PACKLO_B : Pulp_ALU_rr_wb<0b1110000, 0b001, OPC_OP_V, "pv.packlo.b", GPR, GPR, PulpV4>;

let isCodeGenOnly = 1 in
def PV_PACKHI_B_nowb : Pulp_ALU_rr<0b1101100, 0b001, OPC_OP_V, "pv.packhi.b", GPR, GPR, PulpV4>;
} // Predicates = [IsRV32, HasPULPExtVectshufflepack], DecoderNamespace = "RV32Xpulpvectshufflepack"

let Predicates = [IsRV32, HasPULPExtPostmod], DecoderNamespace = "RV32Xpulppostmod" in {
// Instructions: Postmod load and store instructions
defm P_LB  : Pulp_Load<0b0000000, 0b000, "p.lb">,  Sched<[WriteLDB, ReadMemBase]>;
defm P_LBU : Pulp_Load<0b0100000, 0b100, "p.lbu">, Sched<[WriteLDB, ReadMemBase]>;
defm P_LH  : Pulp_Load<0b0001000, 0b001, "p.lh">,  Sched<[WriteLDH, ReadMemBase]>;
defm P_LHU : Pulp_Load<0b0101000, 0b101, "p.lhu">, Sched<[WriteLDH, ReadMemBase]>;
defm P_LW  : Pulp_Load<0b0010000, 0b010, "p.lw">,  Sched<[WriteLDW, ReadMemBase]>;

defm P_SB : Pulp_Store<0b00, "p.sb">, Sched<[WriteSTB, ReadStoreData, ReadMemBase]>;
defm P_SH : Pulp_Store<0b01, "p.sh">, Sched<[WriteSTH, ReadStoreData, ReadMemBase]>;
defm P_SW : Pulp_Store<0b10, "p.sw">, Sched<[WriteSTW, ReadStoreData, ReadMemBase]>;
} // Predicates = [IsRV32, HasPULPExtPostmod], DecoderNamespace = "RV32Xpulppostmod"

//===----------------------------------------------------------------------===//
// Codegen pattern templates
//===----------------------------------------------------------------------===//
def between
    : PatFrags<(ops node:$lowerBound, node:$upperBound, node:$value),
               [(smin (smax node:$value, node:$lowerBound), node:$upperBound),
                (smax (smin node:$value, node:$upperBound), node:$lowerBound)]>;

def betweenu
    : PatFrags<(ops node:$upperBound, node:$value),
               [(umin (umax node:$value, 0), node:$upperBound),
                (umax (umin node:$value, node:$upperBound), 0)]>;


def clip : PatFrag<(ops node:$lowerBound, node:$upperBound, node:$value),
                   (between node:$lowerBound, node:$upperBound, node:$value), [{

  if (auto bound1 = dyn_cast<ConstantSDNode>(N->getOperand(0)->getOperand(1)))
    if (auto bound2 = dyn_cast<ConstantSDNode>(N->getOperand(1)))
      return (bound1->getZExtValue() == ~bound2->getZExtValue());
  return false;
}]>;

def shiftRound : PatFrag<(ops node:$value, node:$shiftAmount),
                         (sra (add node:$value, powerOf2),
                              node:$shiftAmount), [{
  if (auto powerOf2 = dyn_cast<ConstantSDNode>(N->getOperand(0)->getOperand(1)))
    return (powerOf2->getZExtValue() << 1)
           == (1U << N->getConstantOperandVal(1));
  return false;
}]>;

def ushiftRound : PatFrag<(ops node:$value, node:$shiftAmount),
                          (srl (add node:$value, powerOf2),
                               node:$shiftAmount), [{
  if (auto powerOf2 = dyn_cast<ConstantSDNode>(N->getOperand(0)->getOperand(1)))
    return (powerOf2->getZExtValue() << 1)
           == (1U << N->getConstantOperandVal(1));
  return false;
}]>;

def roundBit : PatFrag<(ops node:$shiftAmount),
                       (srl (shl 1, node:$shiftAmount), (i32 1))>;

def extract : PatFrag<(ops node:$value, node:$leftShift, node:$rightShift),
                      (sra (shl node:$value, node:$leftShift),
                           node:$rightShift), [{
  return N->getOperand(0)->getConstantOperandVal(1)
         <= N->getConstantOperandVal(1);
}]>;

def insert : PatFrag<(ops node:$dest, node:$value, node:$mask, node:$shift),
                     (or (and node:$dest, shiftedFlippedMask),
                         (and (shl node:$value, node:$shift), node:$mask)), [{
  SDValue maskedDest = N->getOperand(0);
  SDValue maskedVal = N->getOperand(1);

  if(maskedDest->getOperand(0)->getOpcode() == ISD::SHL){
    maskedDest = N->getOperand(1);
    maskedVal = N->getOperand(0);
  }

  uint32_t destMask = (uint32_t) maskedDest->getConstantOperandVal(1),
           mask     = (uint32_t) maskedVal->getConstantOperandVal(1),
           shift    = (uint32_t) maskedVal->getOperand(0)->getConstantOperandVal(1);
  return (mask == ~destMask) && (countTrailingZeros(mask) == shift);
}]>;

def maskFromRegs : PatFrag<(ops node:$widthMinus1, node:$shift),
                           (shl (add (shl 2, node:$widthMinus1), -1),
                                node:$shift)>;

def shiftedFlippedMask_shiftImmediate : PatFrag<(ops node:$widthMinus1, node:$mask),
                                  (or (shl flippedMask, node:$widthMinus1),
                                           node:$mask), [{
  uint32_t flippedMask = (uint32_t) N->getOperand(0)->getConstantOperandVal(0);
  uint32_t mask = (uint32_t) N->getConstantOperandVal(1);
  return countTrailingZeros(flippedMask) == (countTrailingOnes(mask) + 1);
}]>;

def shiftedMask_shiftImmediate : PatFrag<(ops node:$widthMinus1, node:$flippedMask),
                                         (add (shl imm, node:$widthMinus1),
                                              node:$flippedMask), [{
  uint32_t shiftedBit = (uint32_t) N->getOperand(0)->getConstantOperandVal(0);
  uint32_t flippedMask = (uint32_t) N->getConstantOperandVal(1);
  return (2U << countTrailingZeros(flippedMask)) == shiftedBit;
}]>;

// Pattern templates for multiply operations
def muls : PatFrag<(ops node:$rs1, node:$rs2),
                   (mul (sext_inreg node:$rs1, i16),
                        (sext_inreg node:$rs2, i16))>;
def mulhhs : PatFrag<(ops node:$rs1, node:$rs2),
                     (mul (sra node:$rs1, (i32 16)),
                          (sra node:$rs2, (i32 16)))>;
def mulu : PatFrag<(ops node:$rs1, node:$rs2),
                   (mul (and node:$rs1, 65535),
                        (and node:$rs2, 65535))>;
def mulhhu : PatFrag<(ops node:$rs1, node:$rs2),
                     (mul (srl node:$rs1, (i32 16)),
                          (srl node:$rs2, (i32 16)))>;

def macs : PatFrag<(ops node:$rd, node:$rs1, node:$rs2),
                   (add node:$rd, (muls node:$rs1, node:$rs2))>;
def machhs : PatFrag<(ops node:$rd, node:$rs1, node:$rs2),
                     (add node:$rd, (mulhhs node:$rs1, node:$rs2))>;
def macu : PatFrag<(ops node:$rd, node:$rs1, node:$rs2),
                   (add node:$rd, (mulu node:$rs1, node:$rs2))>;
def machhu : PatFrag<(ops node:$rd, node:$rs1, node:$rs2),
                     (add node:$rd, (mulhhu node:$rs1, node:$rs2))>;

class vec_avg<ValueType vectype, SDNode shiftOp>
    : PatFrag<(ops node:$rs1, node:$rs2),
              (shiftOp (add node:$rs1, node:$rs2),
                       (vectype (splat_vector (i32 1))))>;


def sbextract : PatFrag<(ops node:$vector, node:$index),
                        (sext_inreg (vector_extract (v4i8 node:$vector), node:$index), i8)>;
def ubextract : PatFrag<(ops node:$vector, node:$index),
                        (and (vector_extract (v4i8 node:$vector), node:$index), 255)>;
def shextract : PatFrag<(ops node:$vector, node:$index),
                        (sext_inreg (vector_extract (v2i16 node:$vector), node:$index), i16)>;
def uhextract : PatFrag<(ops node:$vector, node:$index),
                        (and (vector_extract (v2i16 node:$vector), node:$index), 65535)>;

class dotp_h<PatFrag extractOp1, PatFrag extractOp2>
    : PatFrag<(ops node:$rs1, node:$rs2),
              (add (mul (extractOp1 node:$rs1, 0), (extractOp2 node:$rs2, 0)),
                   (mul (extractOp1 node:$rs1, 1), (extractOp2 node:$rs2, 1)))>;

def dotup_h  : dotp_h<uhextract, uhextract>;
def dotusp_h : dotp_h<uhextract, shextract>;
def dotsp_h  : dotp_h<shextract, shextract>;

class dotp_sc_h<PatFrag extractOp>
    : PatFrag<(ops node:$rs1, node:$sc),
              (mul (add (extractOp node:$rs1, 0), (extractOp node:$rs1, 1)), node:$sc)>;

def dotup_sc_h : dotp_sc_h<uhextract>;
def dotsp_sc_h : dotp_sc_h<shextract>;

// Tablegen only permutes 3 operands, so we have to permute the 4th operand manually
def sum4 : PatFrags<(ops node:$a, node:$b, node:$c, node:$d),
                    [(add (add (add node:$a, node:$b), node:$c), node:$d),
                     (add (add (add node:$a, node:$b), node:$d), node:$c),
                     (add (add (add node:$a, node:$d), node:$c), node:$b),
                     (add (add (add node:$d, node:$b), node:$c), node:$a),
                     (add (add node:$a, node:$b), (add node:$c, node:$d))]>;

class dotp_b<PatFrag extractOp1, PatFrag extractOp2>
    : PatFrag<(ops node:$rs1, node:$rs2),
              (sum4 (mul (extractOp1 node:$rs1, 0), (extractOp2 node:$rs2, 0)),
                    (mul (extractOp1 node:$rs1, 1), (extractOp2 node:$rs2, 1)),
                    (mul (extractOp1 node:$rs1, 2), (extractOp2 node:$rs2, 2)),
                    (mul (extractOp1 node:$rs1, 3), (extractOp2 node:$rs2, 3)))>;

def dotup_b  : dotp_b<ubextract, ubextract>;
def dotusp_b : dotp_b<ubextract, sbextract>;
def dotsp_b  : dotp_b<sbextract, sbextract>;

class dotp_sc_b<PatFrag extractOp>
    : PatFrag<(ops node:$rs1, node:$sc),
              (mul (sum4 (extractOp node:$rs1, 0),
                         (extractOp node:$rs1, 1),
                         (extractOp node:$rs1, 2),
                         (extractOp node:$rs1, 3)), node:$sc)>;

def dotup_sc_b : dotp_sc_b<ubextract>;
def dotsp_sc_b : dotp_sc_b<sbextract>;

//===----------------------------------------------------------------------===//
// Pseudo-instructions and codegen patterns
//===----------------------------------------------------------------------===//

let Predicates = [IsRV32, HasPULPExtMulrnhi] in {
multiclass int_mul_N_RN<string intrin, string instr> {
  // mul<op>N: mul op with normalization factor as immediate
  def : Pat<(!cast<Intrinsic>("int_riscv_pulp_mul" # intrin # "N")
              GPR:$rs1, GPR:$rs2, tuimm5:$shift),
            (!cast<RVInst>("P_MUL" # instr # "N")
              GPR:$rs1, GPR:$rs2, tuimm5:$shift)>;
  // mul<op>RN: mul op with normalization and rounding factors as immediates
  def : Pat<(!cast<Intrinsic>("int_riscv_pulp_mul" # intrin # "RN")
              GPR:$rs1, GPR:$rs2, tuimm5:$shift, timm),
            (!cast<RVInst>("P_MUL" # instr # "RN")
              GPR:$rs1, GPR:$rs2, tuimm5:$shift)>;
}

defm : int_mul_N_RN<"s",   "S">;
defm : int_mul_N_RN<"u",   "U">;
defm : int_mul_N_RN<"hhs", "HHS">;
defm : int_mul_N_RN<"hhu", "HHU">;

def : Pat<(muls GPR:$rs1, GPR:$rs2),
          (P_MULS GPR:$rs1, GPR:$rs2)>;
def : Pat<(mulhhs GPR:$rs1, GPR:$rs2),
          (P_MULHHS GPR:$rs1, GPR:$rs2)>;
def : Pat<(sra (muls GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_MULSN GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
def : Pat<(sra (mulhhs GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_MULHHSN GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
def : Pat<(shiftRound (muls GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_MULSRN GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
def : Pat<(shiftRound (mulhhs GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_MULHHSRN GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;

def : Pat<(mulu GPR:$rs1, GPR:$rs2),
          (P_MULU GPR:$rs1, GPR:$rs2)>;
def : Pat<(mulhhu GPR:$rs1, GPR:$rs2),
          (P_MULHHU GPR:$rs1, GPR:$rs2)>;
def : Pat<(srl (mulu GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_MULUN GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
def : Pat<(srl (mulhhu GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_MULHHUN GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
def : Pat<(ushiftRound (mulu GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_MULURN GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
def : Pat<(ushiftRound (mulhhu GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_MULHHURN GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
} // Predicates = [IsRV32, HasPULPExtMulrnhi]

let Predicates = [IsRV32, HasPULPExtMacrnhi] in {
multiclass int_mac_N_RN<string intrin, string instr> {
  // mac<op>N: mac op with normalization factor as immediate
  def : Pat<(!cast<Intrinsic>("int_riscv_pulp_mac" # intrin # "N")
              GPR:$rs1, GPR:$rs2, GPR:$rd, tuimm5:$shift),
            (!cast<RVInst>("P_MAC" # instr # "N")
              GPR:$rd, GPR:$rs1, GPR:$rs2, tuimm5:$shift)>;
  // mac<op>RN: mac op with normalization and rounding factors as immediates
  def : Pat<(!cast<Intrinsic>("int_riscv_pulp_mac" # intrin # "RN")
              GPR:$rs1, GPR:$rs2, GPR:$rd, tuimm5:$shift, timm),
            (!cast<RVInst>("P_MAC" # instr # "RN")
              GPR:$rd, GPR:$rs1, GPR:$rs2, tuimm5:$shift)>;
}

defm : int_mac_N_RN<"s",   "S">;
defm : int_mac_N_RN<"u",   "U">;
defm : int_mac_N_RN<"hhs", "HHS">;
defm : int_mac_N_RN<"hhu", "HHU">;

def : Pat<(sra (macs GPR:$rd, GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_MACSN GPR:$rd, GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
def : Pat<(sra (machhs GPR:$rd, GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_MACHHSN GPR:$rd, GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
def : Pat<(shiftRound (macs GPR:$rd, GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_MACSRN GPR:$rd, GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
def : Pat<(shiftRound (machhs GPR:$rd, GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_MACHHSRN GPR:$rd, GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;

def : Pat<(srl (macu GPR:$rd, GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_MACUN GPR:$rd, GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
def : Pat<(srl (machhu GPR:$rd, GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_MACHHUN GPR:$rd, GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
def : Pat<(ushiftRound (macu GPR:$rd, GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_MACURN GPR:$rd, GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
def : Pat<(ushiftRound (machhu GPR:$rd, GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_MACHHURN GPR:$rd, GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
} // Predicates = [IsRV32, HasPULPExtMacrnhi]

let Predicates = [IsRV32, HasPULPExtPartmac] in {
def : Pat<(macs GPR:$rd, GPR:$rs1, GPR:$rs2),
          (P_MACS GPR:$rd, GPR:$rs1, GPR:$rs2)>;
def : Pat<(machhs GPR:$rd, GPR:$rs1, GPR:$rs2),
          (P_MACHHS GPR:$rd, GPR:$rs1, GPR:$rs2)>;

def : Pat<(macu GPR:$rd, GPR:$rs1, GPR:$rs2),
          (P_MACU GPR:$rd, GPR:$rs1, GPR:$rs2)>;
def : Pat<(machhu GPR:$rd, GPR:$rs1, GPR:$rs2),
          (P_MACHHU GPR:$rd, GPR:$rs1, GPR:$rs2)>;
} // Predicates = [IsRV32, HasPULPExtPartmac]

// Patterns for bit manipulation operations
let Predicates = [IsRV32, HasPULPExtBitop] in {
// extract
// widthMinus1 and shift immediates
def : Pat<(extract:$extract GPR:$rs1, uimm5, uimm5:$shiftRight),
          (P_EXTRACT GPR:$rs1, (31minus imm:$shiftRight), (extractOffset $extract))>;

// shift = 0
def : Pat<(sra (shl GPR:$rs1, (sub 31, GPR:$widthMinus1)),
               (sub 31, GPR:$widthMinus1)),
          (P_EXTRACTR GPR:$rs1, (SLLI GPR:$widthMinus1, 5))>;

// shift immediate
def : Pat<(sra (shl GPR:$rs1, (sub uimm5:$_31MinusShift, GPR:$widthMinus1)),
               (sub 31, GPR:$widthMinus1)),
          (P_EXTRACTR GPR:$rs1, (P_INSERT (ADDI X0, (31minus uimm5:$_31MinusShift)), GPR:$widthMinus1, 4, 5))>;

// widthMinus1 immediate
def : Pat<(sra (shl GPR:$rs1, (sub uimm5:$_32MinusWidth, GPR:$shift)),
               uimm5:$_32MinusWidth),
          (P_EXTRACTR GPR:$rs1, (P_INSERT GPR:$shift, (ADDI X0, (31minus uimm5:$_32MinusWidth)), 4, 5))>;

// widthMinus1 = 0
def : Pat<(sra (shl GPR:$rs1, (sub 31, GPR:$shift)), (i32 31)),
          (P_EXTRACTR GPR:$rs1, (ANDI GPR:$shift, 31))>;

// no immediates
def : Pat<(sra (shl GPR:$rs1, (sub (sub 31, GPR:$widthMinus1), GPR:$shift)),
               (sub 31, GPR:$widthMinus1)),
          (P_EXTRACTR GPR:$rs1, (P_INSERT GPR:$shift, GPR:$widthMinus1, 4, 5))>;

// extractu
// widthMinus1 and shift immediates
def : Pat<(and (srl GPR:$rs1, uimm5:$shift), mask:$mask),
          (P_EXTRACTU GPR:$rs1, (maskWidthMinus1 mask:$mask), uimm5:$shift)>;

// shift = 0
def : Pat<(and GPR:$rs1, (add (shl 2, GPR:$widthMinus1), -1)),
          (P_EXTRACTUR GPR:$rs1, (SLLI GPR:$widthMinus1, 5))>;

// no immediates
def : Pat<(and (srl GPR:$rs1, GPR:$shift), (add (shl 2, GPR:$widthMinus1), -1)),
          (P_EXTRACTUR GPR:$rs1, (P_INSERT GPR:$shift, GPR:$widthMinus1, 4, 5))>;

// insert
// widthMinus1 and shift immediates
def : Pat<(insert GPR:$rd, GPR:$rs1, shiftedMask:$mask, uimm5:$shift),
          (P_INSERT GPR:$rd, GPR:$rs1, (maskWidthMinus1 imm:$mask), uimm5:$shift)>;

// widthMinus1 immediate
def : Pat<(or (and GPR:$rd, (not (shl mask:$mask, GPR:$shift))),
              (shl (and GPR:$rs1, mask:$mask), GPR:$shift)),
          (P_INSERTR GPR:$rd, GPR:$rs1,
                     (P_INSERT GPR:$shift,
                               (ADDI X0, (maskWidthMinus1 mask:$mask)), 4, 5))>;

// widthMinus1 = 0
def : Pat<(or (and GPR:$rd, (not (shl 1, GPR:$shift))),
              (shl (and GPR:$rs1, 1), GPR:$shift)),
          (P_INSERTR GPR:$rd, GPR:$rs1, (ANDI GPR:$shift, 31))>;

// shift = 0
def : Pat<(or (and GPR:$rs1, (add (shl 2, GPR:$widthMinus1), -1)),
              (and GPR:$rd, (sub 0, (shl 2, GPR:$widthMinus1)))),
          (P_INSERTR GPR:$rd, GPR:$rs1, (SLLI GPR:$widthMinus1, 5))>;

// no immediates
def : Pat<(or (and GPR:$dest, (not (maskFromRegs GPR:$widthMinus1, GPR:$shift))),
              (shl (and (add (shl 2, GPR:$widthMinus1), -1), GPR:$rs1), GPR:$shift)),
          (P_INSERTR GPR:$dest, GPR:$rs1, (P_INSERT GPR:$shift, GPR:$widthMinus1, 4, 5))>;

// bclr
// widthMinus1 and shift immediates
def : Pat<(and GPR:$rs1, shiftedFlippedMask:$mask),
          (P_BCLR GPR:$rs1, (flippedMaskWidthMinus1 imm:$mask), (trailing1s imm:$mask))>;

// widthMinus1 immediate
def : Pat<(and GPR:$rs1, (not (shl mask:$mask, GPR:$shift))),
          (P_BCLRR GPR:$rs1, (P_INSERT GPR:$shift, (ADDI X0, (maskWidthMinus1 mask:$mask)), 4, 5))>;

// widthMinus1 = 0
def : Pat<(and GPR:$rs1, (not (shl 1, GPR:$shift))),
          (P_BCLRR GPR:$rs1, (ANDI GPR:$shift, 31))>;

// shift immediate
def : Pat<(and GPR:$rs1, (shiftedFlippedMask_shiftImmediate GPR:$widthMinus1, mask:$mask)),
          (P_BCLRR GPR:$rs1, (P_INSERT (ADDI X0, (trailing1s mask:$mask)),
                                       GPR:$widthMinus1, 4, 5))>;

// shift = 0
def : Pat<(and GPR:$rs1, (shl -2, GPR:$widthMinus1)),
          (P_BCLRR GPR:$rs1, (SLLI GPR:$widthMinus1, 5))>;

// no immediates
def : Pat<(and (not (maskFromRegs GPR:$widthMinus1, GPR:$shift)), GPR:$rs1),
          (P_BCLRR GPR:$rs1, (P_INSERT GPR:$shift, GPR:$widthMinus1, 4, 5))>;

// bset
// widthMinus1 and shift immediates
def : Pat<(or GPR:$rs1, shiftedMask:$mask),
          (P_BSET GPR:$rs1, (maskWidthMinus1 imm:$mask), (trailing0s imm:$mask))>;

// widthMinus1 immediate
def : Pat<(or GPR:$rs1, (shl mask:$mask, GPR:$shift)),
          (P_BSETR GPR:$rs1, (P_INSERT GPR:$shift, (ADDI X0, (maskWidthMinus1 mask:$mask)), 4, 5))>;

// widthMinus1 = 0
def : Pat<(or GPR:$rs1, (shl 1, GPR:$shift)),
          (P_BSETR GPR:$rs1, (ANDI GPR:$shift, 31))>;

// shift immediate
def : Pat<(or GPR:$rs1, (shiftedMask_shiftImmediate GPR:$widthMinus1, flippedMask:$flippedMask)),
          (P_BSETR GPR:$rs1, (P_INSERT (ADDI X0, (trailing0s flippedMask:$flippedMask)),
                                       GPR:$widthMinus1, 4, 5))>;

// shift = 0
def : Pat<(or GPR:$rs1, (add (shl 2, GPR:$widthMinus1), -1)),
          (P_BSETR GPR:$rs1, (SLLI GPR:$widthMinus1, 5))>;

// no immediates
def : Pat<(or (maskFromRegs GPR:$widthMinus1, GPR:$shift), GPR:$rs1),
          (P_BSETR GPR:$rs1, (P_INSERT GPR:$shift, GPR:$widthMinus1, 4, 5))>;

def : Pat<(cttz GPR:$rs1), (P_FF1 GPR:$rs1)>;
def : Pat<(ctlz_zero_undef GPR:$rs1), (XORI (P_FL1 GPR:$rs1), 31)>;
def : Pat<(xor (ctlz_zero_undef GPR:$rs1), 31), (P_FL1 GPR:$rs1)>;
def : Pat<(ctlz_zero_undef (xor GPR:$rs1, (sra GPR:$rs1, (i32 31)))), (P_CLB GPR:$rs1)>;
def : Pat<(ctpop GPR:$rs1), (P_CNT GPR:$rs1)>;
def : PatGprGpr<rotr, P_ROR>;

def : Pat<(sext_inreg GPR:$rs1, i16), (P_EXTHS GPR:$rs1)>;
def : Pat<(sext_inreg GPR:$rs1, i8 ), (P_EXTBS GPR:$rs1)>;
def : Pat<(and GPR:$rs1, 0xffff), (P_EXTHZ GPR:$rs1)>;
def : Pat<(and GPR:$rs1, 0xff  ), (P_EXTBZ GPR:$rs1)>;
} // Predicates = [IsRV32, HasPULPExtBitop]

// Patterns for general ALU operations

let Predicates = [IsRV32, HasPULPExtAbs] in {
def : Pat<(abs GPR:$rs1), (P_ABS GPR:$rs1)>;
} // Predicates = [IsRV32, HasPULPExtAbs]

let Predicates = [IsRV32, HasPULPExtSlet] in {
def : PatGprGpr<setle, P_SLET>;
def : PatGprGpr<setule, P_SLETU>;
} // Predicates = [IsRV32, HasPULPExtSlet]

let Predicates = [IsRV32, HasPULPExtMinmax] in {
def : PatGprGpr<smin, P_MIN>;
def : PatGprGpr<umin, P_MINU>;
def : PatGprGpr<smax, P_MAX>;
def : PatGprGpr<umax, P_MAXU>;
} // Predicates = [IsRV32, HasPULPExtMinmax]

let Predicates = [IsRV32, HasPULPExtClip] in {
def : Pat<(clip negativePowerOf2, powerOf2Minus1:$upperBound, GPR:$rs1),
          (P_CLIP GPR:$rs1, (trailing1sPlus1 imm:$upperBound))>;
def : Pat<(between (not GPR:$rs2), GPR:$rs2, GPR:$rs1),
          (P_CLIPR GPR:$rs1, GPR:$rs2)>;
def : Pat<(betweenu powerOf2Minus1:$upperBound, GPR:$rs1),
          (P_CLIPU GPR:$rs1, (trailing1sPlus1 imm:$upperBound))>;
def : Pat<(betweenu GPR:$rs2, GPR:$rs1),
          (P_CLIPUR GPR:$rs1, GPR:$rs2)>;
} // Predicates = [IsRV32, HasPULPExtClip]

let Predicates = [IsRV32, HasPULPExtAddsubrn] in {
def : Pat<(sra (add GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_ADDN GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
def : Pat<(srl (add GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_ADDUN GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
def : Pat<(shiftRound (add GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_ADDRN GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
def : Pat<(ushiftRound (add GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_ADDURN GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;

def : Pat<(sra (sub GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_SUBN GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
def : Pat<(srl (sub GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_SUBUN GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
def : Pat<(shiftRound (sub GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_SUBRN GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;
def : Pat<(ushiftRound (sub GPR:$rs1, GPR:$rs2), uimm5:$Is3),
          (P_SUBURN GPR:$rs1, GPR:$rs2, uimm5:$Is3)>;

def : Pat<(sra (add GPR:$rd, GPR:$rs1), GPR:$rs2),
          (P_ADDNR GPR:$rd, GPR:$rs1, GPR:$rs2)>;
def : Pat<(srl (add GPR:$rd, GPR:$rs1), GPR:$rs2),
          (P_ADDUNR GPR:$rd, GPR:$rs1, GPR:$rs2)>;
def : Pat<(sra (add (add GPR:$rd, GPR:$rs1), (roundBit GPR:$rs2)), GPR:$rs2),
          (P_ADDRNR  GPR:$rd, GPR:$rs1, GPR:$rs2)>;
def : Pat<(srl (add (add GPR:$rd, GPR:$rs1), (roundBit GPR:$rs2)), GPR:$rs2),
          (P_ADDURNR GPR:$rd, GPR:$rs1, GPR:$rs2)>;

def : Pat<(sra (sub GPR:$rd, GPR:$rs1), GPR:$rs2),
          (P_SUBNR GPR:$rd, GPR:$rs1, GPR:$rs2)>;
def : Pat<(srl (sub GPR:$rd, GPR:$rs1), GPR:$rs2),
          (P_SUBUNR GPR:$rd, GPR:$rs1, GPR:$rs2)>;
def : Pat<(sra (add (sub GPR:$rd, GPR:$rs1), (roundBit GPR:$rs2)), GPR:$rs2),
          (P_SUBRNR  GPR:$rd, GPR:$rs1, GPR:$rs2)>;
def : Pat<(srl (add (sub GPR:$rd, GPR:$rs1), (roundBit GPR:$rs2)), GPR:$rs2),
          (P_SUBURNR GPR:$rd, GPR:$rs1, GPR:$rs2)>;
} // Predicates = [IsRV32, HasPULPExtAddsubrn]

// Patterns for immediate branching Operations
let Predicates = [IsRV32, HasPULPExtBr] in {
def : Pat<(brcond (XLenVT (seteq GPR:$rs1, simm5:$imm5)), bb:$imm12),
          (P_BEQIMM GPR:$rs1, simm5:$imm5, simm13_lsb0:$imm12)>;
def : Pat<(brcond (XLenVT (setne GPR:$rs1, simm5:$imm5)), bb:$imm12),
          (P_BNEIMM GPR:$rs1, simm5:$imm5, simm13_lsb0:$imm12)>;
} // Predicates = [IsRV32, HasPULPExtBr]

let Predicates = [IsRV32, HasPULPExtMacsi] in {
def : Pat<(add GPR:$rd, (mul GPR:$rs1, GPR:$rs2)),
          (P_MAC GPR:$rd, GPR:$rs1, GPR:$rs2)>;
def : Pat<(sub GPR:$rd, (mul GPR:$rs1, GPR:$rs2)),
          (P_MSU GPR:$rd, GPR:$rs1, GPR:$rs2)>;
} // Predicates = [IsRV32, HasPULPExtMacsi]

// Patterns for vectorial ALU operations
let Predicates = [IsRV32, HasPULPExtVect] in {
class PatV2V2<SDPatternOperator OpNode, RVInst Inst>
    : Pat<(OpNode PulpV2:$rs1, PulpV2:$rs2), (Inst PulpV2:$rs1, PulpV2:$rs2)>;

class PatV4V4<SDPatternOperator OpNode, RVInst Inst>
    : Pat<(OpNode PulpV4:$rs1, PulpV4:$rs2), (Inst PulpV4:$rs1, PulpV4:$rs2)>;

class PatV2GPR<SDPatternOperator OpNode, RVInst Inst>
    : Pat<(OpNode PulpV2:$rs1, (v2i16 (splat_vector GPR:$rs2))), (Inst PulpV2:$rs1, GPR:$rs2)>;

class PatV4GPR<SDPatternOperator OpNode, RVInst Inst>
    : Pat<(OpNode PulpV4:$rs1, (v4i8 (splat_vector GPR:$rs2))), (Inst PulpV4:$rs1, GPR:$rs2)>;

class PatV2Simm6<SDPatternOperator OpNode, RVInst Inst>
    : Pat<(OpNode PulpV2:$rs1, (v2i16 (splat_vector simm6:$imm))), (Inst PulpV2:$rs1, simm6:$imm)>;

class PatV4Simm6<SDPatternOperator OpNode, RVInst Inst>
    : Pat<(OpNode PulpV4:$rs1, (v4i8 (splat_vector simm6:$imm))), (Inst PulpV4:$rs1, simm6:$imm)>;

class PatV2Uimm6<SDPatternOperator OpNode, RVInst Inst>
    : Pat<(OpNode PulpV2:$rs1, (v2i16 (splat_vector uimm6:$imm))), (Inst PulpV2:$rs1, uimm6:$imm)>;

class PatV4Uimm6<SDPatternOperator OpNode, RVInst Inst>
    : Pat<(OpNode PulpV4:$rs1, (v4i8 (splat_vector uimm6:$imm))), (Inst PulpV4:$rs1, uimm6:$imm)>;

multiclass GeneralSVectorPattern<SDPatternOperator OpNode, string Inst> {
  def : PatV2V2   <OpNode, !cast<RVInst>("PV_" # Inst # "_H")>;
  def : PatV2GPR  <OpNode, !cast<RVInst>("PV_" # Inst # "_SC_H")>;
  def : PatV2Simm6<OpNode, !cast<RVInst>("PV_" # Inst # "_SCI_H")>;
  def : PatV4V4   <OpNode, !cast<RVInst>("PV_" # Inst # "_B")>;
  def : PatV4GPR  <OpNode, !cast<RVInst>("PV_" # Inst # "_SC_B")>;
  def : PatV4Simm6<OpNode, !cast<RVInst>("PV_" # Inst # "_SCI_B")>;
}

multiclass GeneralUVectorPattern<SDPatternOperator OpNode, string Inst> {
  def : PatV2V2   <OpNode, !cast<RVInst>("PV_" # Inst # "_H")>;
  def : PatV2GPR  <OpNode, !cast<RVInst>("PV_" # Inst # "_SC_H")>;
  def : PatV2Uimm6<OpNode, !cast<RVInst>("PV_" # Inst # "_SCI_H")>;
  def : PatV4V4   <OpNode, !cast<RVInst>("PV_" # Inst # "_B")>;
  def : PatV4GPR  <OpNode, !cast<RVInst>("PV_" # Inst # "_SC_B")>;
  def : PatV4Uimm6<OpNode, !cast<RVInst>("PV_" # Inst # "_SCI_B")>;
}

defm : GeneralSVectorPattern<add, "ADD">;
defm : GeneralSVectorPattern<sub, "SUB">;
defm : GeneralSVectorPattern<smin, "MIN">;
defm : GeneralUVectorPattern<umin, "MINU">;
defm : GeneralSVectorPattern<smax, "MAX">;
defm : GeneralUVectorPattern<umax, "MAXU">;
defm : GeneralUVectorPattern<srl, "SRL">;
defm : GeneralUVectorPattern<sra, "SRA">;
defm : GeneralUVectorPattern<shl, "SLL">;
defm : GeneralSVectorPattern<or, "OR">;
defm : GeneralSVectorPattern<xor, "XOR">;
defm : GeneralSVectorPattern<and, "AND">;

def : PatV2V2<vec_avg<v2i16, sra>, PV_AVG_H>;
def : PatV2GPR<vec_avg<v2i16, sra>, PV_AVG_SC_H>;
def : PatV2Simm6<vec_avg<v2i16, sra>, PV_AVG_SCI_H>;
def : PatV4V4<vec_avg<v4i8, sra>, PV_AVG_B>;
def : PatV4GPR<vec_avg<v4i8, sra>, PV_AVG_SC_B>;
def : PatV4Simm6<vec_avg<v4i8, sra>, PV_AVG_SCI_B>;

def : PatV2V2<vec_avg<v2i16, srl>, PV_AVGU_H>;
def : PatV2GPR<vec_avg<v2i16, srl>, PV_AVGU_SC_H>;
def : PatV2Simm6<vec_avg<v2i16, srl>, PV_AVGU_SCI_H>;
def : PatV4V4<vec_avg<v4i8, srl>, PV_AVGU_B>;
def : PatV4GPR<vec_avg<v4i8, srl>, PV_AVGU_SC_B>;
def : PatV4Simm6<vec_avg<v4i8, srl>, PV_AVGU_SCI_B>;

def : Pat<(abs PulpV2:$rs1), (PV_ABS_H PulpV2:$rs1)>;
def : Pat<(abs PulpV4:$rs1), (PV_ABS_B PulpV4:$rs1)>;

def : Pat<(i32 (vector_extract (v2i16 PulpV2:$rs1), uimm6:$index)),
          (PV_EXTRACT_H PulpV2:$rs1, uimm6:$index)>;
def : Pat<(i32 (vector_extract (v4i8 PulpV4:$rs1), uimm6:$index)),
          (PV_EXTRACT_B PulpV4:$rs1, uimm6:$index)>;
def : Pat<(i32 (sext_inreg (vector_extract PulpV2:$rs1, uimm6:$index), i16)),
          (PV_EXTRACT_H PulpV2:$rs1, uimm6:$index)>;
def : Pat<(i32 (sext_inreg (vector_extract PulpV4:$rs1, uimm6:$index), i8)),
          (PV_EXTRACT_B PulpV4:$rs1, uimm6:$index)>;
def : Pat<(i32 (and (vector_extract (v2i16 PulpV2:$rs1), uimm6:$index), 65535)),
          (PV_EXTRACT_H PulpV2:$rs1, uimm6:$index)>;
def : Pat<(i32 (and (vector_extract (v4i8 PulpV4:$rs1), uimm6:$index), 255)),
          (PV_EXTRACT_B PulpV4:$rs1, uimm6:$index)>;
def : Pat<(vector_insert PulpV2:$rd, GPR:$rs1, uimm6:$index),
          (PV_INSERT_H PulpV2:$rd, GPR:$rs1, uimm6:$index)>;
def : Pat<(vector_insert PulpV4:$rd, GPR:$rs1, uimm6:$index),
          (PV_INSERT_B PulpV4:$rd, GPR:$rs1, uimm6:$index)>;

// insert/extract without immediate index
def : Pat<(vector_insert PulpV2:$rd, GPR:$rs1, GPR:$index),
          (P_INSERTR_v2 PulpV2:$rd, GPR:$rs1,
                     (P_INSERT (ADDI X0, 0b111100000), GPR:$index, 0, 4))>;
def : Pat<(vector_insert PulpV4:$rd, GPR:$rs1, GPR:$index),
          (P_INSERTR_v4 PulpV4:$rd, GPR:$rs1,
                     (P_INSERT (ADDI X0, 0b11100000), GPR:$index, 1, 3))>;

def : Pat<(i32 (vector_extract PulpV2:$rs1, GPR:$rs2)),
          (PV_SHUFFLE_H_GPR PulpV2:$rs1, GPR:$rs2)>;
def : Pat<(i32 (vector_extract PulpV4:$rs1, GPR:$rs2)),
          (PV_SHUFFLE_B_GPR PulpV4:$rs1, GPR:$rs2)>;

def : PatV2V2<dotup_h, PV_DOTUP_H>;

def : Pat<(dotup_sc_h PulpV2:$rs1, (and GPR:$rs2, 65535)),
          (PV_DOTUP_SC_H PulpV2:$rs1, GPR:$rs2)>;

def : Pat<(dotup_sc_h PulpV2:$rs1, uimm6:$sci),
          (PV_DOTUP_SCI_H PulpV2:$rs1, uimm6:$sci)>;

def : PatV4V4<dotup_b, PV_DOTUP_B>;

def : Pat<(dotup_sc_b PulpV4:$rs1, (and GPR:$rs2, 255)),
          (PV_DOTUP_SC_B PulpV4:$rs1, GPR:$rs2)>;

def : Pat<(dotup_sc_b PulpV4:$rs1, uimm6:$sci),
          (PV_DOTUP_SCI_B PulpV4:$rs1, uimm6:$sci)>;


def : PatV2V2<dotusp_h , PV_DOTUSP_H>;

def : Pat<(dotup_sc_h PulpV2:$rs1, (sext_inreg GPR:$rs2, i16)),
          (PV_DOTUSP_SC_H PulpV2:$rs1, GPR:$rs2)>;

def : Pat<(dotup_sc_h PulpV2:$rs1, simm6:$sci),
          (PV_DOTUSP_SCI_H PulpV2:$rs1, simm6:$sci)>;

def : PatV4V4<dotusp_b, PV_DOTUSP_B>;

def : Pat<(dotup_sc_b PulpV4:$rs1, (sext_inreg GPR:$rs2, i8)),
          (PV_DOTUSP_SC_B PulpV4:$rs1, GPR:$rs2)>;

def : Pat<(dotup_sc_b PulpV4:$rs1, simm6:$sci),
          (PV_DOTUSP_SCI_B PulpV4:$rs1, simm6:$sci)>;


def : PatV2V2<dotsp_h , PV_DOTSP_H>;

def : Pat<(dotsp_sc_h PulpV2:$rs1, (sext_inreg GPR:$rs2, i16)),
          (PV_DOTSP_SC_H PulpV2:$rs1, GPR:$rs2)>;

def : Pat<(dotsp_sc_h PulpV2:$rs1, simm6:$sci),
          (PV_DOTSP_SCI_H PulpV2:$rs1, simm6:$sci)>;

def : PatV4V4<dotsp_b, PV_DOTSP_B>;

def : Pat<(dotsp_sc_b PulpV4:$rs1, (sext_inreg GPR:$rs2, i8)),
          (PV_DOTSP_SC_B PulpV4:$rs1, GPR:$rs2)>;

def : Pat<(dotsp_sc_b PulpV4:$rs1, simm6:$sci),
          (PV_DOTSP_SCI_B PulpV4:$rs1, simm6:$sci)>;

def : Pat<(add GPR:$rd, (dotup_h PulpV2:$rs1, PulpV2:$rs2)),
          (PV_SDOTUP_H GPR:$rd, PulpV2:$rs1, PulpV2:$rs2)>;

def : Pat<(add GPR:$rd, (dotup_sc_h PulpV2:$rs1, (and GPR:$rs2, 65535))),
          (PV_SDOTUP_SC_H GPR:$rd, PulpV2:$rs1, GPR:$rs2)>;

def : Pat<(add GPR:$rd, (dotup_sc_h PulpV2:$rs1, uimm6:$sci)),
          (PV_SDOTUP_SCI_H GPR:$rd, PulpV2:$rs1, uimm6:$sci)>;

def : Pat<(add GPR:$rd, (dotup_b PulpV4:$rs1, PulpV4:$rs2)),
          (PV_SDOTUP_B GPR:$rd, PulpV4:$rs1, PulpV4:$rs2)>;

def : Pat<(add GPR:$rd, (dotup_sc_b PulpV4:$rs1, (and GPR:$rs2, 255))),
          (PV_SDOTUP_SC_B GPR:$rd, PulpV4:$rs1, GPR:$rs2)>;

def : Pat<(add GPR:$rd, (dotup_sc_b PulpV4:$rs1, uimm6:$sci)),
          (PV_SDOTUP_SCI_B GPR:$rd, PulpV4:$rs1, uimm6:$sci)>;

def : Pat<(add GPR:$rd, (dotusp_h PulpV2:$rs1, PulpV2:$rs2)),
          (PV_SDOTUSP_H GPR:$rd, PulpV2:$rs1, PulpV2:$rs2)>;

def : Pat<(add GPR:$rd, (dotup_sc_h PulpV2:$rs1, (sext_inreg GPR:$rs2, i16))),
          (PV_SDOTUSP_SC_H GPR:$rd, PulpV2:$rs1, GPR:$rs2)>;

def : Pat<(add GPR:$rd, (dotup_sc_h PulpV2:$rs1, simm6:$sci)),
          (PV_SDOTUSP_SCI_H GPR:$rd, PulpV2:$rs1, simm6:$sci)>;

def : Pat<(add GPR:$rd, (dotusp_b PulpV4:$rs1, PulpV4:$rs2)),
          (PV_SDOTUSP_B GPR:$rd, PulpV4:$rs1, PulpV4:$rs2)>;

def : Pat<(add GPR:$rd, (dotup_sc_b PulpV4:$rs1, (sext_inreg GPR:$rs2, i8))),
          (PV_SDOTUSP_SC_B GPR:$rd, PulpV4:$rs1, GPR:$rs2)>;

def : Pat<(add GPR:$rd, (dotup_sc_b PulpV4:$rs1, simm6:$sci)),
          (PV_SDOTUSP_SCI_B GPR:$rd, PulpV4:$rs1, simm6:$sci)>;

def : Pat<(add GPR:$rd, (dotsp_h PulpV2:$rs1, PulpV2:$rs2)),
          (PV_SDOTSP_H GPR:$rd, PulpV2:$rs1, PulpV2:$rs2)>;

def : Pat<(add GPR:$rd, (dotsp_sc_h PulpV2:$rs1, (sext_inreg GPR:$rs2, i16))),
          (PV_SDOTSP_SC_H GPR:$rd, PulpV2:$rs1, GPR:$rs2)>;

def : Pat<(add GPR:$rd, (dotsp_sc_h PulpV2:$rs1, simm6:$sci)),
          (PV_SDOTSP_SCI_H GPR:$rd, PulpV2:$rs1, simm6:$sci)>;

def : Pat<(add GPR:$rd, (dotsp_b PulpV4:$rs1, PulpV4:$rs2)),
          (PV_SDOTSP_B GPR:$rd, PulpV4:$rs1, PulpV4:$rs2)>;

def : Pat<(add GPR:$rd, (dotsp_sc_b PulpV4:$rs1, (sext_inreg GPR:$rs2, i8))),
          (PV_SDOTSP_SC_B GPR:$rd, PulpV4:$rs1, GPR:$rs2)>;

def : Pat<(add GPR:$rd, (dotsp_sc_b PulpV4:$rs1, simm6:$sci)),
          (PV_SDOTSP_SCI_B GPR:$rd, PulpV4:$rs1, simm6:$sci)>;

def : Pat<(v4i8 (splat_vector GPR:$rs1)), (PV_ADD_SC_B X0, GPR:$rs1)>;


// Pattern to map vector splat operations on pseudos
def : Pat<(v2i16 (riscv_vmv_v_x_vl (v2i16 undef), GPR:$imm, VLOpFrag)),
          (PseudoPV_ADD_SC_H_VL X0, GPR:$imm, $vl)>;
def : Pat<(v2i16 (riscv_vmv_v_x_vl (v2i16 undef), simm6:$imm, VLOpFrag)),
          (PseudoPV_ADD_SCI_H_VL X0, simm6:$imm, $vl)>;
def : Pat<(v4i8 (riscv_vmv_v_x_vl (v4i8 undef), GPR:$imm, VLOpFrag)),
          (PseudoPV_ADD_SC_B_VL X0, GPR:$imm, $vl)>;
def : Pat<(v4i8 (riscv_vmv_v_x_vl (v4i8 undef), simm6:$imm, VLOpFrag)),
          (PseudoPV_ADD_SCI_B_VL X0, simm6:$imm, $vl)>;


defm : GeneralSVectorPattern<seteq, "CMPEQ">;
defm : GeneralSVectorPattern<setne, "CMPNE">;
defm : GeneralSVectorPattern<setgt, "CMPGT">;
defm : GeneralSVectorPattern<setge, "CMPGE">;
defm : GeneralSVectorPattern<setlt, "CMPLT">;
defm : GeneralSVectorPattern<setle, "CMPLE">;
defm : GeneralUVectorPattern<setugt, "CMPGTU">;
defm : GeneralUVectorPattern<setuge, "CMPGEU">;
defm : GeneralUVectorPattern<setult, "CMPLTU">;
defm : GeneralUVectorPattern<setule, "CMPLEU">;

def : Pat<(v2i16 (bitconvert GPR:$rs1)), (v2i16 PulpV2:$rs1)>;
def : Pat<(v4i8 (bitconvert GPR:$rs1)), (v4i8 PulpV4:$rs1)>;
def : Pat<(i32 (bitconvert PulpV2:$rs1)), (i32 GPR:$rs1)>;
def : Pat<(i32 (bitconvert PulpV4:$rs1)), (i32 GPR:$rs1)>;
} // Predicates = [IsRV32, HasPULPExtVect]

let Predicates = [IsRV32, HasPULPExtVectshufflepack] in {
def : Pat<(v2i16 (build_vector (i32 (vector_extract PulpV2:$rs1, GPR:$index0)),
                               (i32 (vector_extract PulpV2:$rs1, GPR:$index1)))),
          (PV_SHUFFLE_H PulpV2:$rs1, (PV_PACK_H GPR:$index1, GPR:$index0))>;

def : Pat<(v4i8 (build_vector (i32 (vector_extract PulpV4:$rs1, GPR:$index0)),
                              (i32 (vector_extract PulpV4:$rs1, GPR:$index1)),
                              (i32 (vector_extract PulpV4:$rs1, GPR:$index2)),
                              (i32 (vector_extract PulpV4:$rs1, GPR:$index3)))),
          (PV_SHUFFLE_B PulpV4:$rs1, (PV_PACKLO_B (PV_PACKHI_B_nowb GPR:$index3,
                                     GPR:$index2), GPR:$index1, GPR:$index0))>;


def : Pat<(v2i16 (build_vector GPR:$rs1, GPR:$rs2)),
          (PV_PACK_H GPR:$rs2, GPR:$rs1)>;
def : Pat<(v4i8 (build_vector GPR:$rs1, GPR:$rs2, GPR:$rs3, GPR:$rs4)),
          (PV_PACKLO_B (PV_PACKHI_B_nowb GPR:$rs4, GPR:$rs3), GPR:$rs2, GPR:$rs1)>;

def : Pat<(v2i16 (splat_vector GPR:$rs1)), (PV_PACK_H GPR:$rs1, GPR:$rs1)>;
} // Predicates = [IsRV32, HasPULPExtVectshufflepack]

let Predicates = [IsRV32, HasPULPExtPostmod] in {
// Patterns for load/store instructions

// post increment loads need custom selection, because tablegen can't deal with
// multiple result values

def : Pat<(sextloadi8 (add GPR:$base, GPR:$offset)),
    (P_LB_rr GPR:$base, GPR:$offset)>;
def : Pat<(zextloadi8 (add GPR:$base, GPR:$offset)),
    (P_LBU_rr GPR:$base, GPR:$offset)>;
def : Pat<(sextloadi16 (add GPR:$base, GPR:$offset)),
    (P_LH_rr GPR:$base, GPR:$offset)>;
def : Pat<(zextloadi16 (add GPR:$base, GPR:$offset)),
    (P_LHU_rr GPR:$base, GPR:$offset)>;
def : Pat<(load (add GPR:$base, GPR:$offset)),
    (P_LW_rr GPR:$base, GPR:$offset)>;

def : Pat<(post_truncsti8 GPR:$val, GPR:$base, simm12:$offset),
    (P_SB_ri_PostIncrement GPR:$val, GPR:$base, simm12:$offset)>;
def : Pat<(post_truncsti16 GPR:$val, GPR:$base, simm12:$offset),
    (P_SH_ri_PostIncrement GPR:$val, GPR:$base, simm12:$offset)>;
def : Pat<(post_store GPR:$val, GPR:$base, simm12:$offset),
    (P_SW_ri_PostIncrement GPR:$val, GPR:$base, simm12:$offset)>;

def : Pat<(post_truncsti8 GPR:$val, GPR:$base, GPR:$offset),
    (P_SB_rr_PostIncrement GPR:$val, GPR:$base, GPR:$offset)>;
def : Pat<(post_truncsti16 GPR:$val, GPR:$base, GPR:$offset),
    (P_SH_rr_PostIncrement GPR:$val, GPR:$base, GPR:$offset)>;
def : Pat<(post_store GPR:$val, GPR:$base, GPR:$offset),
    (P_SW_rr_PostIncrement GPR:$val, GPR:$base, GPR:$offset)>;

def : Pat<(truncstorei8 GPR:$val, (add GPR:$base, GPR:$offset)),
    (P_SB_rr GPR:$val, GPR:$base, GPR:$offset)>;
def : Pat<(truncstorei16 GPR:$val, (add GPR:$base, GPR:$offset)),
    (P_SH_rr GPR:$val, GPR:$base, GPR:$offset)>;
def : Pat<(store GPR:$val, (add GPR:$base, GPR:$offset)),
    (P_SW_rr GPR:$val, GPR:$base, GPR:$offset)>;
} // Predicates = [IsRV32, HasPULPExtPostmod]

//===----------------------------------------------------------------------===//
// Pseudo-instructions and codegen patterns
//===----------------------------------------------------------------------===//

let Predicates = [IsRV32, HasPULPExtElw] in {
def : Pat<(int_riscv_pulp_event_unit_read GPR:$rs, simm12:$simm12),
          (PULP_ELW GPR:$rs, simm12:$simm12)>;
def : Pat<(int_riscv_pulp_event_unit_read GPR:$rs, GPR:$off),
          (PULP_ELW (ADD GPR:$rs, GPR:$off), 0)>;
} // Predicates = [IsRV32, HasPULPExtElw]

class UnaryBuiltin<Intrinsic intrinsic, Instruction instruction>
      : Pat<(intrinsic GPR:$rs1), (instruction GPR:$rs1)>;

let Predicates = [IsRV32, HasPULPExtBitop] in {
def : Pat<(int_riscv_pulp_bitinsert GPR:$rd, GPR:$rs1, uimm5:$ls2, uimm5:$ls3),
          (P_INSERT GPR:$rd, GPR:$rs1, uimm5:$ls2, uimm5:$ls3)>;

def : UnaryBuiltin<int_riscv_pulp_fl1, P_FL1>;
def : UnaryBuiltin<int_riscv_pulp_ff1, P_FF1>;
def : UnaryBuiltin<int_riscv_pulp_clb, P_CLB>;
def : UnaryBuiltin<int_riscv_pulp_cnt, P_CNT>;
def : Pat<(int_riscv_pulp_parity GPR:$rs1), (P_BCLR (P_CNT GPR:$rs1), 30, 1)>;
def : PatGprGpr<int_riscv_pulp_rotr, P_ROR>;

def : Pat<(int_riscv_pulp_bclr GPR:$rs1, shiftedFlippedMask:$mask),
          (P_BCLR GPR:$rs1, (flippedMaskWidthMinus1 imm:$mask), (trailing1s imm:$mask))>;
def : PatGprGpr<int_riscv_pulp_bclr_r, P_BCLRR>;

def : Pat<(int_riscv_pulp_bset GPR:$rs1, shiftedMask:$mask),
          (P_BSET GPR:$rs1, (maskWidthMinus1 imm:$mask), (trailing0s imm:$mask))>;
def : PatGprGpr<int_riscv_pulp_bset_r, P_BSETR>;

def : Pat<(int_riscv_pulp_bextract GPR:$rs1, tuimm5:$size, tuimm5:$shift),
          (P_EXTRACT GPR:$rs1, tuimm5:$size, tuimm5:$shift)>;
def : PatGprGpr<int_riscv_pulp_bextract_r, P_EXTRACTR>;

def : Pat<(int_riscv_pulp_bextractu GPR:$rs1, tuimm5:$size, tuimm5:$shift),
          (P_EXTRACTU GPR:$rs1, tuimm5:$size, tuimm5:$shift)>;
def : PatGprGpr<int_riscv_pulp_bextractu_r, P_EXTRACTUR>;

def : Pat<(int_riscv_pulp_binsert GPR:$rd, shiftedFlippedMask,
                                  GPR:$rs1, shiftedMask:$srcMask, tuimm5:$shift),
          (P_INSERT GPR:$rd, GPR:$rs1, (maskWidthMinus1 imm:$srcMask), tuimm5:$shift)>;
def : Pat<(int_riscv_pulp_binsert_r GPR:$rd, GPR:$rs1, GPR:$rs2),
          (P_INSERTR GPR:$rd, GPR:$rs1, GPR:$rs2)>;
} // Predicates = [IsRV32, HasPULPExtBitop]

let Predicates = [IsRV32, HasPULPExtAbs] in {
def : UnaryBuiltin<int_riscv_pulp_abs, P_ABS>;
} // Predicates = [IsRV32, HasPULPExtAbs]

let Predicates = [IsRV32, HasPULPExtMacsi] in {
def : Pat<(int_riscv_pulp_mac GPR:$rs1, GPR:$rs2, GPR:$rd), (P_MAC GPR:$rd, GPR:$rs1, GPR:$rs2)>;
def : Pat<(int_riscv_pulp_msu GPR:$rs1, GPR:$rs2, GPR:$rd), (P_MSU GPR:$rd, GPR:$rs1, GPR:$rs2)>;
} // Predicates = [IsRV32, HasPULPExtMacsi]

let Predicates = [IsRV32, HasPULPExtPartmac] in {
def : Pat<(int_riscv_pulp_macs GPR:$rs1, GPR:$rs2, GPR:$rd), (P_MACS GPR:$rd, GPR:$rs1, GPR:$rs2)>;
def : Pat<(int_riscv_pulp_macu GPR:$rs1, GPR:$rs2, GPR:$rd), (P_MACU GPR:$rd, GPR:$rs1, GPR:$rs2)>;

def : Pat<(int_riscv_pulp_machhs GPR:$rs1, GPR:$rs2, GPR:$rd), (P_MACHHS GPR:$rd, GPR:$rs1, GPR:$rs2)>;
def : Pat<(int_riscv_pulp_machhu GPR:$rs1, GPR:$rs2, GPR:$rd), (P_MACHHU GPR:$rd, GPR:$rs1, GPR:$rs2)>;
} // Predicates = [IsRV32, HasPULPExtPartmac]

let Predicates = [IsRV32, HasPULPExtMinmax] in {
def : PatGprGpr<int_riscv_pulp_maxsi, P_MAX>;
def : PatGprGpr<int_riscv_pulp_minsi, P_MIN>;
def : PatGprGpr<int_riscv_pulp_maxusi, P_MAXU>;
def : PatGprGpr<int_riscv_pulp_minusi, P_MINU>;
} // Predicates = [IsRV32, HasPULPExtMinmax]

let Predicates = [IsRV32, HasPULPExtVect] in {
multiclass BinaryVectorBuiltin<string intrin, string instr> {
  def : PatV2V2<!cast<Intrinsic>("int_riscv_pulp_" # intrin # "2"),
                !cast<RVInst>("PV_" # instr # "_H")>;

  def : PatV4V4<!cast<Intrinsic>("int_riscv_pulp_" # intrin # "4"),
                !cast<RVInst>("PV_" # instr # "_B")>;
}

defm : BinaryVectorBuiltin<"add",  "ADD">;
defm : BinaryVectorBuiltin<"sub",  "SUB">;
defm : BinaryVectorBuiltin<"avg",  "AVG">;
defm : BinaryVectorBuiltin<"avgu", "AVGU">;
defm : BinaryVectorBuiltin<"min",  "MIN">;
defm : BinaryVectorBuiltin<"minu", "MINU">;
defm : BinaryVectorBuiltin<"max",  "MAX">;
defm : BinaryVectorBuiltin<"maxu", "MAXU">;
defm : BinaryVectorBuiltin<"and",  "AND">;
defm : BinaryVectorBuiltin<"or",   "OR">;
defm : BinaryVectorBuiltin<"exor", "XOR">;
defm : BinaryVectorBuiltin<"srl",  "SRL">;
defm : BinaryVectorBuiltin<"sra",  "SRA">;
defm : BinaryVectorBuiltin<"sll",  "SLL">;
def : Pat<(int_riscv_pulp_abs2 PulpV2:$rs1), (PV_ABS_H PulpV2:$rs1)>;
def : Pat<(int_riscv_pulp_abs4 PulpV4:$rs1), (PV_ABS_B PulpV4:$rs1)>;
def : Pat<(int_riscv_pulp_neg2 PulpV2:$rs1), (PV_SUB_H X0, PulpV2:$rs1)>;
def : Pat<(int_riscv_pulp_neg4 PulpV4:$rs1), (PV_SUB_B X0, PulpV4:$rs1)>;

class PatV2V2GPR<SDPatternOperator op, Instruction instr>
    : Pat<(op PulpV2:$rs1, PulpV2:$rs2, GPR:$rd),
          (instr GPR:$rd, PulpV2:$rs1, PulpV2:$rs2)>;

class PatV2GPRGPR<SDPatternOperator op, Instruction instr>
    : Pat<(op PulpV2:$rs1, GPR:$rs2, GPR:$rd),
          (instr GPR:$rd, PulpV2:$rs1, GPR:$rs2)>;

class PatV4V4GPR<SDPatternOperator op, Instruction instr>
    : Pat<(op PulpV4:$rs1, PulpV4:$rs2, GPR:$rd),
          (instr GPR:$rd, PulpV4:$rs1, PulpV4:$rs2)>;

class PatV4GPRGPR<SDPatternOperator op, Instruction instr>
    : Pat<(op PulpV4:$rs1, GPR:$rs2, GPR:$rd),
          (instr GPR:$rd, PulpV4:$rs1, GPR:$rs2)>;

multiclass DotproductBuiltin<string intrin, string instr> {
  def : PatV2V2<!cast<Intrinsic>("int_riscv_pulp_dot" # intrin # "p2"),
                !cast<RVInst>("PV_DOT" # instr # "P_H")>;

  def : Pat<(!cast<Intrinsic>("int_riscv_pulp_dot" # intrin # "psc2") PulpV2:$rs1, GPR:$rs2),
            (!cast<RVInst>("PV_DOT" # instr # "P_SC_H") PulpV2:$rs1, GPR:$rs2)>;

  def : PatV4V4<!cast<Intrinsic>("int_riscv_pulp_dot" # intrin # "p4"),
                !cast<RVInst>("PV_DOT" # instr # "P_B")>;

  def : Pat<(!cast<Intrinsic>("int_riscv_pulp_dot" # intrin # "psc4") PulpV4:$rs1, GPR:$rs2),
            (!cast<RVInst>("PV_DOT" # instr # "P_SC_B") PulpV4:$rs1, GPR:$rs2)>;

  def : Pat<(!cast<Intrinsic>("int_riscv_pulp_sdot" # intrin # "p2") PulpV2:$rs1, PulpV2:$rs2, GPR:$rd),
            (!cast<RVInst>("PV_SDOT" # instr # "P_H") GPR:$rd, PulpV2:$rs1, PulpV2:$rs2)>;

  def : Pat<(!cast<Intrinsic>("int_riscv_pulp_sdot" # intrin # "psc2") PulpV2:$rs1, GPR:$rs2, GPR:$rd),
            (!cast<RVInst>("PV_SDOT" # instr # "P_SC_H") GPR:$rd, PulpV2:$rs1, GPR:$rs2)>;

  def : Pat<(!cast<Intrinsic>("int_riscv_pulp_sdot" # intrin # "p4") PulpV4:$rs1, PulpV4:$rs2, GPR:$rd),
            (!cast<RVInst>("PV_SDOT" # instr # "P_B") GPR:$rd, PulpV4:$rs1, PulpV4:$rs2)>;

  def : Pat<(!cast<Intrinsic>("int_riscv_pulp_sdot" # intrin # "psc4") PulpV4:$rs1, GPR:$rs2, GPR:$rd),
            (!cast<RVInst>("PV_SDOT" # instr # "P_SC_B") GPR:$rd, PulpV4:$rs1, GPR:$rs2)>;

}

defm : DotproductBuiltin<"s",  "S">;
defm : DotproductBuiltin<"u",  "U">;
defm : DotproductBuiltin<"us", "US">;
} // Predicates = [IsRV32, HasPULPExtVect]

let Predicates = [IsRV32, HasPULPExtMulrnhi] in {
def : PatGprGpr<int_riscv_pulp_muls, P_MULS>;
def : PatGprGpr<int_riscv_pulp_mulu, P_MULU>;
def : PatGprGpr<int_riscv_pulp_mulhhs, P_MULHHS>;
def : PatGprGpr<int_riscv_pulp_mulhhu, P_MULHHU>;
} // Predicates = [IsRV32, HasPULPExtMulrnhi]

let Predicates = [IsRV32, HasPULPExtAddsubrn] in {
multiclass int_N_RN_r<string intrin, string instr> {
  // <op>N: op with normalization factor as immediate
  def : Pat<(!cast<Intrinsic>("int_riscv_pulp_" # intrin # "N")
              GPR:$rs1, GPR:$rs2, tuimm5:$shift),
            (!cast<RVInst>("P_" # instr # "N")
              GPR:$rs1, GPR:$rs2, tuimm5:$shift)>;
  // <op>N_r: op with normalization factor
  def : Pat<(!cast<Intrinsic>("int_riscv_pulp_" # intrin # "N_r")
              GPR:$rd, GPR:$rs1, GPR:$rs2),
            (!cast<RVInst>("P_" # instr # "NR")
              GPR:$rd, GPR:$rs1, GPR:$rs2)>;
  // <op>RN: op with normalization and rounding factors as immediates
  def : Pat<(!cast<Intrinsic>("int_riscv_pulp_" # intrin # "RN")
              GPR:$rs1, GPR:$rs2, tuimm5:$shift, timm),
            (!cast<RVInst>("P_" # instr # "RN")
              GPR:$rs1, GPR:$rs2, tuimm5:$shift)>;
  // <op>RN_r: op with normalization and rounding factors
  def : Pat<(!cast<Intrinsic>("int_riscv_pulp_" # intrin # "RN_r")
              GPR:$rd, GPR:$rs1, GPR:$rs2),
            (!cast<RVInst>("P_" # instr # "RNR")
              GPR:$rd, GPR:$rs1, GPR:$rs2)>;
}

defm : int_N_RN_r<"add",  "ADD">;
defm : int_N_RN_r<"addu", "ADDU">;
defm : int_N_RN_r<"sub",  "SUB">;
defm : int_N_RN_r<"subu", "SUBU">;
} // Predicates = [IsRV32, HasPULPExtAddsubrn]

let Predicates = [IsRV32, HasPULPExtVectshufflepack] in {
def : Pat<(int_riscv_pulp_pack2 GPR:$rs1, GPR:$rs2),
          (PV_PACK_H GPR:$rs2, GPR:$rs1)>;
def : Pat<(int_riscv_pulp_pack4 GPR:$rs1, GPR:$rs2, GPR:$rs3, GPR:$rs4),
          (PV_PACKLO_B (PV_PACKHI_B_nowb GPR:$rs4, GPR:$rs3), GPR:$rs2, GPR:$rs1)>;
def : PatV2V2<int_riscv_pulp_shuffleh, PV_SHUFFLE_H>;
def : PatV4V4<int_riscv_pulp_shuffleb, PV_SHUFFLE_B>;
def : Pat<(int_riscv_pulp_pack4_lo GPR:$rs2, GPR:$rs1, PulpV4:$rd),
          (PV_PACKLO_B PulpV4:$rd, GPR:$rs2, GPR:$rs1)>;
def : Pat<(int_riscv_pulp_pack4_hi GPR:$rs2, GPR:$rs1, PulpV4:$rd),
          (PV_PACKHI_B PulpV4:$rd, GPR:$rs2, GPR:$rs1)>;
def : Pat<(int_riscv_pulp_shuffle2h PulpV2:$rd, PulpV2:$rs1, PulpV2:$rs2),
          (PV_SHUFFLE2_H PulpV2:$rd, PulpV2:$rs1, PulpV2:$rs2)>;
def : Pat<(int_riscv_pulp_shuffle4b PulpV4:$rd, PulpV4:$rs1, PulpV4:$rs2),
          (PV_SHUFFLE2_B PulpV4:$rd, PulpV4:$rs1, PulpV4:$rs2)>;
} // Predicates = [IsRV32, HasPULPExtVectshufflepack]

let Predicates = [IsRV32, HasPULPExtPostmod] in {
def : Pat<(int_riscv_pulp_OffsetedRead GPR:$rs1, GPR:$rs2), (P_LW_rr GPR:$rs1, GPR:$rs2)>;
def : Pat<(int_riscv_pulp_OffsetedReadHalf GPR:$rs1, GPR:$rs2), (P_LH_rr GPR:$rs1, GPR:$rs2)>;
def : Pat<(int_riscv_pulp_OffsetedReadByte GPR:$rs1, GPR:$rs2), (P_LB_rr GPR:$rs1, GPR:$rs2)>;

def : Pat<(int_riscv_pulp_OffsetedWrite GPR:$rs2, GPR:$rs1, GPR:$rs3), (P_SW_rr GPR:$rs2, GPR:$rs1, GPR:$rs3)>;
def : Pat<(int_riscv_pulp_OffsetedWriteHalf GPR:$rs2, GPR:$rs1, GPR:$rs3), (P_SH_rr GPR:$rs2, GPR:$rs1, GPR:$rs3)>;
def : Pat<(int_riscv_pulp_OffsetedWriteByte GPR:$rs2, GPR:$rs1, GPR:$rs3), (P_SB_rr GPR:$rs2, GPR:$rs1, GPR:$rs3)>;

def : Pat<(int_riscv_pulp_read_base_off GPR:$rs1, GPR:$rs2), (P_LW_rr GPR:$rs1, GPR:$rs2)>;
def : Pat<(int_riscv_pulp_write_base_off GPR:$rs2, GPR:$rs1, GPR:$rs3), (P_SW_rr GPR:$rs2, GPR:$rs1, GPR:$rs3)>;
} // Predicates = [IsRV32, HasPULPExtPostmod]

let Predicates = [IsRV32, HasPULPExtClip] in {
def : Pat<(int_riscv_pulp_clip GPR:$rs1, negativePowerOf2:$lowerBound,
                               powerOf2Minus1),
          (P_CLIP GPR:$rs1, (trailing0s imm:$lowerBound))>;
def : PatGprGpr<int_riscv_pulp_clip_r, P_CLIPR>;

def : Pat<(int_riscv_pulp_clipu GPR:$rs1, 0, powerOf2Minus1:$upperBound),
          (P_CLIPU GPR:$rs1, (trailing1sPlus1 imm:$upperBound))>;
def : PatGprGpr<int_riscv_pulp_clipu_r, P_CLIPUR>;
} // Predicates = [IsRV32, HasPULPExtClip]

let Predicates = [IsRV32, HasPULPExtV2] in {
def : Pat<(int_riscv_pulp_spr_read tuimm12:$csr),
          (CSRRS csr_sysreg:$csr, X0)>;
def : Pat<(int_riscv_pulp_spr_read_vol tuimm12:$csr),
          (CSRRS csr_sysreg:$csr, X0)>;
def : Pat<(int_riscv_pulp_spr_write tuimm12:$csr, GPR:$rd),
          (CSRRW csr_sysreg:$csr, GPR:$rd)>;
def : Pat<(int_riscv_pulp_read_then_spr_write tuimm12:$csr, GPR:$rs1),
          (CSRRW csr_sysreg:$csr, GPR:$rs1)>;
def : Pat<(int_riscv_pulp_spr_bit_set tuimm12:$csr, tuimm5:$offset),
          (CSRRSI csr_sysreg:$csr, tuimm5:$offset)>;
def : Pat<(int_riscv_pulp_spr_bit_clr tuimm12:$csr, tuimm5:$offset),
          (CSRRCI csr_sysreg:$csr, tuimm5:$offset)>;
def : Pat<(int_riscv_pulp_read_then_spr_bit_set tuimm12:$csr, tuimm5:$offset),
          (CSRRSI csr_sysreg:$csr, tuimm5:$offset)>;
def : Pat<(int_riscv_pulp_read_then_spr_bit_clr tuimm12:$csr, tuimm5:$offset),
          (CSRRCI csr_sysreg:$csr, tuimm5:$offset)>;

// TODO the *_v versions should have side effects
def : Pat<(int_riscv_pulp_read_base_off_v GPR:$rs1, GPR:$rs2), (P_LW_rr GPR:$rs1, GPR:$rs2)>;
def : Pat<(int_riscv_pulp_write_base_off_v GPR:$rs2, GPR:$rs1, GPR:$rs3), (P_SW_rr GPR:$rs2, GPR:$rs1, GPR:$rs3)>;

def : Pat<(int_riscv_pulp_CoreId), (ANDI (CSRRS MHARTID.Encoding, X0), 0b1111)>;
def : Pat<(int_riscv_pulp_CoreCount), (ANDI (LW (LUI 0x1A103), 0), 0x12)>;
def : Pat<(int_riscv_pulp_ClusterId), (SRLI (ANDI (CSRRS MHARTID.Encoding, X0), 0b11111100000), 5)>;
def : Pat<(int_riscv_pulp_IsFc), (SRLI (ANDI (CSRRS MHARTID.Encoding, X0), 0b10000000000), 10)>;
// Symbols below must be provided by the platform, no CSR involved
// Note: GCC lowers HasFc to zero immediate
def : Pat<(int_riscv_pulp_HasFc), (ANDI X0, 0)>;
} // Predicates = [IsRV32, HasPULPExtV2]
