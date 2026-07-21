//===-- RISCVInstrInfoVme.td - RISC-V VME instructions -----------*- tablegen -*-===//


//===----------------------------------------------------------------------===//
// Matrix Configuration Instructions
//===----------------------------------------------------------------------===//

class RVInstVME<dag outs, dag ins, string opcodestr, string argstr>
    : RVInst<outs, ins, opcodestr, argstr, [], InstFormatR> {
  let Predicates = [HasVInstructions, HasStdExtVme];
}

// msetmtype
class RVInstMSetMType<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVME<outs, ins, opcodestr, argstr> {
  bits<5> rs2;
  bits<5> rs1;

  let Inst{31-25} = 0b1000001;
  let Inst{24-20} = rs2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = 0b111;
  let Inst{11-7}  = 0b00000;
  let Opcode = OPC_OP_V.Value;

  let Defs = [VTYPE, VL];
  let Uses = [VTYPE, VL];
}

// msettn / msettm / msettk
class RVInstMSetT<bits<5> subop,
                  dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVME<outs, ins, opcodestr, argstr> {
  bits<5> rs1;
  bits<5> rd;

  let Inst{31}    = 1;
  let Inst{30-25} = 0b000010;
  let Inst{24-20} = subop;
  let Inst{19-15} = rs1;
  let Inst{14-12} = 0b111;
  let Inst{11-7}  = rd;
  let Opcode = OPC_OP_V.Value;

  let Defs = [VTYPE, VL];
  let Uses = [VTYPE, VL];
}

// msetmtypei
class RVInstMSetMTypei<dag outs, dag ins, string opcodestr, string argstr>
    : RVInst<outs, ins, opcodestr, argstr, [], InstFormatI> {
      let Predicates = [HasVInstructions, HasStdExtVme];
  bits<3> uimm3;
  bits<5> uimm5;

  let Inst{31-25} = 0b1000010;
  let Inst{24-22} = uimm3;
  let Inst{21-20} = 0b11;
  let Inst{19-15} = uimm5;
  let Inst{14-12} = 0b111;
  let Inst{11-7}  = 0b00000;
  let Opcode = OPC_OP_V.Value;

  let Defs = [VTYPE, VL];
  let Uses = [VTYPE, VL];
}


//===----------------------------------------------------------------------===//
// Matrix Arithmetic Instructions
//===----------------------------------------------------------------------===//

class RVInstVMETVV<bits<3> funct3, bits<1> variant,
                   dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVME<outs, ins, opcodestr, argstr> {
  bits<5> vs2;
  bits<5> vs1;
  bits<4> rd;

  let Inst{31-26} = 0b111100;
  let Inst{25}    = 1;
  let Inst{24-20} = vs2;
  let Inst{19-15} = vs1;
  let Inst{14-12} = funct3;
  let Inst{11-8}  = rd;
  let Inst{7}     = variant;
  let Opcode = OPC_OP_VE.Value;

  let Uses = [VTYPE, VL];
}

// Convenience classes for the four arithmetic encodings.
class RVInstVTFMM_TVV<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVMETVV<0b001, 0b0, outs, ins, opcodestr, argstr>;

class RVInstVTFMM_ALT_TVV<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVMETVV<0b001, 0b1, outs, ins, opcodestr, argstr>;

class RVInstVTMMU_TVV<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVMETVV<0b000, 0b0, outs, ins, opcodestr, argstr>;

class RVInstVTMMS_TVV<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVMETVV<0b000, 0b1, outs, ins, opcodestr, argstr>;

//===----------------------------------------------------------------------===//
// Load / Store Tile Subset to Memory
//===----------------------------------------------------------------------===//


// vtle*
class RVInstVTLE<bits<3> nf_or_eew,
                 dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVME<outs, ins, opcodestr, argstr> {
  bits<5> rs2;
  bits<5> rs1;

  let Inst{31-29} = nf_or_eew;
  let Inst{28}    = 1;
  let Inst{27-26} = 0b00;
  let Inst{25}    = 1;
  let Inst{24-20} = rs2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = 0b111;
  let Inst{11-7}  = 0b00000;
  let Opcode = OPC_LOAD_FP.Value;

  let Uses = [VTYPE, VL];
}

// vtse*
class RVInstVTSE<bits<3> nf_or_eew,
                 dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVME<outs, ins, opcodestr, argstr> {
  bits<5> rs2;
  bits<5> rs1;

  let Inst{31-29} = nf_or_eew;
  let Inst{28}    = 1;
  let Inst{27-26} = 0b00;
  let Inst{25}    = 1;
  let Inst{24-20} = rs2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = 0b111;
  let Inst{11-7}  = 0b00000;
  let Opcode = OPC_STORE_FP.Value;

  let Uses = [VTYPE, VL];
}

// Convenience classes for EEW-style encodings.
// If your implementation wants different top-bit values, adjust these here.
class RVInstVTLE8<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVTLE<0b000, outs, ins, opcodestr, argstr>;
class RVInstVTLE16<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVTLE<0b001, outs, ins, opcodestr, argstr>;
class RVInstVTLE32<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVTLE<0b010, outs, ins, opcodestr, argstr>;
class RVInstVTLE64<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVTLE<0b011, outs, ins, opcodestr, argstr>;

class RVInstVTSE8<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVTSE<0b000, outs, ins, opcodestr, argstr>;
class RVInstVTSE16<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVTSE<0b001, outs, ins, opcodestr, argstr>;
class RVInstVTSE32<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVTSE<0b010, outs, ins, opcodestr, argstr>;
class RVInstVTSE64<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVTSE<0b011, outs, ins, opcodestr, argstr>;


//===----------------------------------------------------------------------===//
// Move Tile Subset between Tile State and Vector Registers
//===----------------------------------------------------------------------===//

// vtmv.v.t
class RVInstVTMV_V_T<bits<6> funct6, dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVME<outs, ins, opcodestr, argstr> {
  bits<5> rs1;
  bits<5> vd;

  let Inst{31-26} = funct6;
  let Inst{25}    = 1;
  let Inst{24-20} = 0b11111;
  let Inst{19-15} = rs1;
  let Inst{14-12} = 0b110;
  let Inst{11-7}  = vd;
  let Opcode = OPC_OP_V.Value;

  let Uses = [VTYPE, VL];
}

// vtmv.t.v
class RVInstVTMV_T_V<bits<6> funct6, dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVME<outs, ins, opcodestr, argstr> {
  bits<5> vs2;
  bits<5> rs1;

  let Inst{31-26} = funct6;
  let Inst{25}    = 1;
  let Inst{24-20} = vs2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = 0b110;
  let Inst{11-7}  = 0b00000;
  let Opcode = OPC_OP_V.Value;

  let Uses = [VTYPE, VL];
}

//===----------------------------------------------------------------------===//
// Matrix Tile-Zero Instruction
//===----------------------------------------------------------------------===//

// vtzero
class RVInstVTZero<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVME<outs, ins, opcodestr, argstr> {
  bits<4> rd;

  let Inst{31-26} = 0b010000;
  let Inst{25}    = 1;
  let Inst{24-20} = 0b11110;
  let Inst{19-15} = 0b00000;
  let Inst{14-12} = 0b110;
  let Inst{11-8}  = rd;
  let Inst{7}     = 0;
  let Opcode = OPC_OP_V.Value;

  let Uses = [VTYPE, VL];
}

//===----------------------------------------------------------------------===//
// Zvt Context Discard Instruction
//===----------------------------------------------------------------------===//

// vtdiscard
class RVInstVTDiscard<dag outs, dag ins, string opcodestr, string argstr>
    : RVInstVME<outs, ins, opcodestr, argstr> {
  let Inst{31-26} = 0b010000;
  let Inst{25}    = 1;
  let Inst{24-20} = 0b11100;
  let Inst{19-15} = 0b00000;
  let Inst{14-12} = 0b110;
  let Inst{11-7}  = 0b00000;
  let Opcode = OPC_OP_V.Value;

  let Uses = [VTYPE, VL];
}

// Matrix tile register operand.
def MTRegOp : RegisterOperand<MT> {
  let DecoderMethod = "DecodeMTRegisterClass";
}

// --------------------
// Matrix Config
// --------------------
let hasSideEffects = 1, mayLoad = 0, mayStore = 0 in {

def MSETMTYPE : RVInstMSetMType<
  (outs),
  (ins GPR:$rs2, GPR:$rs1),
  "msetmtype", "$rs1, $rs2">;

def MSETTN : RVInstMSetT<0b00000,
  (outs GPR:$rd), (ins GPR:$rs1),
  "msettn", "$rd, $rs1">;

def MSETTM : RVInstMSetT<0b00001,
  (outs GPR:$rd), (ins GPR:$rs1),
  "msettm", "$rd, $rs1">;

def MSETTK : RVInstMSetT<0b00010,
  (outs GPR:$rd), (ins GPR:$rs1),
  "msettk", "$rd, $rs1">;

def MSETMTYPEI : RVInstMSetMTypei<
  (outs),
  (ins uimm3:$uimm3, uimm5:$uimm5),
  "msetmtypei", "$uimm5, $uimm3">;

} // Matrix Config

// --------------------
// VTLE* (memory load) — rs2 = TSS (GPR holding tile subset specifier)
// --------------------
let hasSideEffects = 0, mayLoad = 1, mayStore = 0 in {

def VTLE8  : RVInstVTLE8 <(outs), (ins GPR:$rs2, GPR:$rs1),
  "vtle8",  "$rs2, (${rs1})">;
def VTLE16 : RVInstVTLE16<(outs), (ins GPR:$rs2, GPR:$rs1),
  "vtle16", "$rs2, (${rs1})">;
def VTLE32 : RVInstVTLE32<(outs), (ins GPR:$rs2, GPR:$rs1),
  "vtle32", "$rs2, (${rs1})">;
def VTLE64 : RVInstVTLE64<(outs), (ins GPR:$rs2, GPR:$rs1),
  "vtle64", "$rs2, (${rs1})">;

} // VTLE

// --------------------
// VTSE* (memory store) — rs2 = TSS (GPR holding tile subset specifier)
// --------------------
let hasSideEffects = 0, mayLoad = 0, mayStore = 1 in {

def VTSE8  : RVInstVTSE8 <(outs), (ins GPR:$rs2, GPR:$rs1),
  "vtse8",  "$rs2, (${rs1})">;
def VTSE16 : RVInstVTSE16<(outs), (ins GPR:$rs2, GPR:$rs1),
  "vtse16", "$rs2, (${rs1})">;
def VTSE32 : RVInstVTSE32<(outs), (ins GPR:$rs2, GPR:$rs1),
  "vtse32", "$rs2, (${rs1})">;
def VTSE64 : RVInstVTSE64<(outs), (ins GPR:$rs2, GPR:$rs1),
  "vtse64", "$rs2, (${rs1})">;

} // VTSE

// --------------------
// VTMV — rs1 = TSS (GPR holding tile subset specifier)
// --------------------
let hasSideEffects = 1, mayLoad = 0, mayStore = 0 in {

def VTMV_V_T : RVInstVTMV_V_T<
  0b010000,
  (outs VR:$vd),
  (ins GPR:$rs1),   // rs1 = TSS scalar value
  "vtmv.v.t", "$vd, $rs1">;

def VTMV_T_V : RVInstVTMV_T_V<
  0b010111,
  (outs),
  (ins GPR:$rs1, VR:$vs2),  // rs1 = TSS scalar value
  "vtmv.t.v", "$rs1, $vs2">;

} // VTMV

// --------------------
// Matrix arithmetic — rd = MTRegOp tile destination
// --------------------
let hasSideEffects = 1, mayLoad = 0, mayStore = 0 in {

def VTMMS_TVV : RVInstVTMMS_TVV<
  (outs MTRegOp:$rd),
  (ins VR:$vs2, VR:$vs1),
  "vtmms.tvv", "$rd, $vs2, $vs1">;

def VTMMU_TVV : RVInstVTMMU_TVV<
  (outs MTRegOp:$rd),
  (ins VR:$vs2, VR:$vs1),
  "vtmmu.tvv", "$rd, $vs2, $vs1">;

def VTFMM_TVV : RVInstVTFMM_TVV<
  (outs MTRegOp:$rd),
  (ins VR:$vs2, VR:$vs1),
  "vtfmm.tvv", "$rd, $vs2, $vs1">;

def VTFMM_ALT_TVV : RVInstVTFMM_ALT_TVV<
  (outs MTRegOp:$rd),
  (ins VR:$vs2, VR:$vs1),
  "vtfmm.alt.tvv", "$rd, $vs2, $vs1">;

} // arithmetic

// --------------------
// Tile/context ops — rd = MTRegOp tile specifier (input, not output)
// --------------------
let hasSideEffects = 1, mayLoad = 0, mayStore = 0 in {

// vtzero: rd specifies WHICH tile to zero — it is an INPUT tile register
// The instruction does not write a scalar result, it modifies tile state
def VTZERO : RVInstVTZero<
  (outs),
  (ins MTRegOp:$rd),
  "vtzero", "$rd">;

def VTDISCARD : RVInstVTDiscard<
  (outs),
  (ins),
  "vtdiscard", "">;

} // tile/context ops