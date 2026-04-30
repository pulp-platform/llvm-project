//===- RISCVSystemOperands.td ------------------------------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines the symbolic operands permitted for various kinds of
// RISC-V system instruction.
//
//===----------------------------------------------------------------------===//

include "llvm/TableGen/SearchableTable.td"

//===----------------------------------------------------------------------===//
// CSR (control and status register read/write) instruction options.
//===----------------------------------------------------------------------===//

class SysReg<string name, bits<12> op> {
  string Name = name;
  // A maximum of one alias is supported right now.
  string AltName = name;
  // A maximum of one deprecated name is supported right now.  Unlike the
  // `AltName` alias, a `DeprecatedName` generates a diagnostic when the name is
  // used to encourage software to migrate away from the name.
  string DeprecatedName = "";
  bits<12> Encoding = op;
  // FIXME: add these additional fields when needed.
  // Privilege Access: Read and Write = 0, 1, 2; Read-Only = 3.
  // Privilege Mode: User = 0, System = 1 or Machine = 3.
  // bits<2> ReadWrite = op{11 - 10};
  // bits<2> XMode = op{9 - 8};
  // Check Extra field name and what bits 7-6 correspond to.
  // bits<2> Extra = op{7 - 6};
  // Register number without the privilege bits.
  // bits<6> Number = op{5 - 0};
  code FeaturesRequired = [{ {} }];
  bit isRV32Only = 0;
}

def SysRegsList : GenericTable {
  let FilterClass = "SysReg";
  // FIXME: add "ReadWrite", "Mode", "Extra", "Number" fields when needed.
  let Fields = [
    "Name", "AltName", "DeprecatedName", "Encoding", "FeaturesRequired",
    "isRV32Only",
  ];

  let PrimaryKey = [ "Encoding" ];
  let PrimaryKeyName = "lookupSysRegByEncoding";
}

def lookupSysRegByName : SearchIndex {
  let Table = SysRegsList;
  let Key = [ "Name" ];
}

def lookupSysRegByAltName : SearchIndex {
  let Table = SysRegsList;
  let Key = [ "AltName" ];
}

def lookupSysRegByDeprecatedName : SearchIndex {
  let Table = SysRegsList;
  let Key = [ "DeprecatedName" ];
}

// The following CSR encodings match those given in Tables 2.2,
// 2.3, 2.4, 2.5 and 2.6 in the RISC-V Instruction Set Manual
// Volume II: Privileged Architecture.

//===----------------------------------------------------------------------===//
// User Floating-Point CSRs
//===----------------------------------------------------------------------===//

def SysRegFFLAGS : SysReg<"fflags", 0x001>;
def SysRegFRM    : SysReg<"frm", 0x002>;
def SysRegFCSR   : SysReg<"fcsr", 0x003>;

//===----------------------------------------------------------------------===//
// User Counter/Timers
//===----------------------------------------------------------------------===//
def CYCLE   : SysReg<"cycle", 0xC00>;
def TIME    : SysReg<"time", 0xC01>;
def INSTRET : SysReg<"instret", 0xC02>;

// hpmcounter3-hpmcounter31 at 0xC03-0xC1F.
foreach i = 3...31 in
  def : SysReg<"hpmcounter"#i, !add(0xC03, !sub(i, 3))>;

let isRV32Only = 1 in {
def CYCLEH   : SysReg<"cycleh", 0xC80>;
def TIMEH    : SysReg<"timeh", 0xC81>;
def INSTRETH : SysReg<"instreth", 0xC82>;

// hpmcounter3h-hpmcounter31h at 0xC83-0xC9F.
foreach i = 3...31 in
  def : SysReg<"hpmcounter"#i#"h", !add(0xC83, !sub(i, 3))>;
}

//===----------------------------------------------------------------------===//
// Supervisor Trap Setup
//===----------------------------------------------------------------------===//
def : SysReg<"sstatus", 0x100>;
def : SysReg<"sie", 0x104>;
def : SysReg<"stvec", 0x105>;
def : SysReg<"scounteren", 0x106>;
def : SysReg<"stimecmp", 0x14D>;
let isRV32Only = 1 in
def : SysReg<"stimecmph", 0x15D>;

//===----------------------------------------------------------------------===//
// Supervisor Configuration
//===----------------------------------------------------------------------===//

def : SysReg<"senvcfg", 0x10A>;

//===----------------------------------------------------------------------===//
// Supervisor Trap Handling
//===----------------------------------------------------------------------===//
def : SysReg<"sscratch", 0x140>;
def : SysReg<"sepc", 0x141>;
def : SysReg<"scause", 0x142>;
let DeprecatedName = "sbadaddr" in
def : SysReg<"stval", 0x143>;
def : SysReg<"sip", 0x144>;

//===----------------------------------------------------------------------===//
// Supervisor Protection and Translation
//===----------------------------------------------------------------------===//
let DeprecatedName = "sptbr" in
def : SysReg<"satp", 0x180>;

//===----------------------------------------------------------------------===//
// Debug/Trace Registers
//===----------------------------------------------------------------------===//

def : SysReg<"scontext", 0x5A8>;

//===----------------------------------------------------------------------===//
// Supervisor Count Overflow (defined in Sscofpmf)
//===----------------------------------------------------------------------===//

def : SysReg<"scountovf", 0xDA0>;

//===----------------------------------------------------------------------===//
// Hypervisor Trap Setup
//===----------------------------------------------------------------------===//

def : SysReg<"hstatus", 0x600>;
def : SysReg<"hedeleg", 0x602>;
def : SysReg<"hideleg", 0x603>;
def : SysReg<"hie", 0x604>;
def : SysReg<"hcounteren", 0x606>;
def : SysReg<"hgeie", 0x607>;

//===----------------------------------------------------------------------===//
// Hypervisor Trap Handling
//===----------------------------------------------------------------------===//

def : SysReg<"htval", 0x643>;
def : SysReg<"hip", 0x644>;
def : SysReg<"hvip", 0x645>;
def : SysReg<"htinst", 0x64A>;
def : SysReg<"hgeip", 0xE12>;

//===----------------------------------------------------------------------===//
// Hypervisor Configuration
//===----------------------------------------------------------------------===//

def : SysReg<"henvcfg", 0x60A>;
let isRV32Only = 1 in
def : SysReg<"henvcfgh", 0x61A>;

//===----------------------------------------------------------------------===//
// Hypervisor Protection and Translation
//===----------------------------------------------------------------------===//

def : SysReg<"hgatp", 0x680>;

//===----------------------------------------------------------------------===//
// Debug/Trace Registers
//===----------------------------------------------------------------------===//

def : SysReg<"hcontext", 0x6A8>;

//===----------------------------------------------------------------------===//
// Hypervisor Counter/Timer Virtualization Registers
//===----------------------------------------------------------------------===//

def : SysReg<"htimedelta", 0x605>;
let isRV32Only = 1 in
def : SysReg<"htimedeltah", 0x615>;

//===----------------------------------------------------------------------===//
// Virtual Supervisor Registers
//===----------------------------------------------------------------------===//

def : SysReg<"vsstatus", 0x200>;
def : SysReg<"vsie", 0x204>;
def : SysReg<"vstvec", 0x205>;
def : SysReg<"vsscratch", 0x240>;
def : SysReg<"vsepc", 0x241>;
def : SysReg<"vscause", 0x242>;
def : SysReg<"vstval", 0x243>;
def : SysReg<"vsip", 0x244>;
def : SysReg<"vstimecmp", 0x24D>;
let isRV32Only = 1 in
def : SysReg<"vstimecmph", 0x25D>;
def : SysReg<"vsatp", 0x280>;

//===----------------------------------------------------------------------===//
// Machine Information Registers
//===----------------------------------------------------------------------===//

def : SysReg<"mvendorid", 0xF11>;
def : SysReg<"marchid", 0xF12>;
def : SysReg<"mimpid", 0xF13>;
def : SysReg<"mhartid", 0xF14>;
def : SysReg<"mconfigptr", 0xF15>;

//===----------------------------------------------------------------------===//
// Machine Trap Setup
//===----------------------------------------------------------------------===//
def : SysReg<"mstatus", 0x300>;
def : SysReg<"misa", 0x301>;
def : SysReg<"medeleg", 0x302>;
def : SysReg<"mideleg", 0x303>;
def : SysReg<"mie", 0x304>;
def : SysReg<"mtvec", 0x305>;
def : SysReg<"mcounteren", 0x306>;
let isRV32Only = 1 in
def : SysReg<"mstatush", 0x310>;

//===----------------------------------------------------------------------===//
// Machine Trap Handling
//===----------------------------------------------------------------------===//
def : SysReg<"mscratch", 0x340>;
def : SysReg<"mepc", 0x341>;
def : SysReg<"mcause", 0x342>;
let DeprecatedName = "mbadaddr" in
def : SysReg<"mtval", 0x343>;
def : SysReg<"mip", 0x344>;
def : SysReg<"mtinst", 0x34A>;
def : SysReg<"mtval2", 0x34B>;

//===----------------------------------------------------------------------===//
// Machine Configuration
//===----------------------------------------------------------------------===//

def : SysReg<"menvcfg", 0x30A>;
let isRV32Only = 1 in
def : SysReg<"menvcfgh", 0x31A>;
def : SysReg<"mseccfg", 0x747>;
let isRV32Only = 1 in
def : SysReg<"mseccfgh", 0x757>;

//===----------------------------------------------------------------------===//
// Machine Protection and Translation
//===----------------------------------------------------------------------===//

// pmpcfg0-pmpcfg15 at 0x3A0-0x3AF. Odd-numbered registers are RV32-only.
foreach i = 0...15 in {
  let isRV32Only = !and(i, 1) in
  def : SysReg<"pmpcfg"#i, !add(0x3A0, i)>;
}

// pmpaddr0-pmpaddr63 at 0x3B0-0x3EF.
foreach i = 0...63 in
  def : SysReg<"pmpaddr"#i, !add(0x3B0, i)>;

//===----------------------------------------------------------------------===//
// Machine Counter and Timers
//===----------------------------------------------------------------------===//
def : SysReg<"mcycle", 0xB00>;
def : SysReg<"minstret", 0xB02>;

// mhpmcounter3-mhpmcounter31 at 0xB03-0xB1F.
foreach i = 3...31 in
  def : SysReg<"mhpmcounter"#i, !add(0xB03, !sub(i, 3))>;

let isRV32Only = 1 in {
def: SysReg<"mcycleh", 0xB80>;
def: SysReg<"minstreth", 0xB82>;

// mhpmcounter3h-mhpmcounter31h at 0xB83-0xB9F.
foreach i = 3...31 in
  def : SysReg<"mhpmcounter"#i#"h", !add(0xB83, !sub(i, 3))>;
}

//===----------------------------------------------------------------------===//
// Machine Counter Setup
//===----------------------------------------------------------------------===//
let AltName = "mucounteren" in // Privileged spec v1.9.1 Name
def : SysReg<"mcountinhibit", 0x320>;

// mhpmevent3-mhpmevent31 at 0x323-0x33F.
foreach i = 3...31 in
  def : SysReg<"mhpmevent"#i, !add(0x323, !sub(i, 3))>;

// mhpmevent3h-mhpmevent31h at 0x723-0x73F
foreach i = 3...31 in {
  let isRV32Only = 1 in
  def : SysReg<"mhpmevent"#i#"h", !add(0x723, !sub(i, 3))>;
}

//===----------------------------------------------------------------------===//
// Debug/ Trace Registers (shared with Debug Mode)
//===----------------------------------------------------------------------===//
def : SysReg<"tselect", 0x7A0>;
def : SysReg<"tdata1", 0x7A1>;
def : SysReg<"tdata2", 0x7A2>;
def : SysReg<"tdata3", 0x7A3>;
def : SysReg<"mcontext", 0x7A8>;

//===----------------------------------------------------------------------===//
// Debug Mode Registers
//===----------------------------------------------------------------------===//
def : SysReg<"dcsr", 0x7B0>;
def : SysReg<"dpc", 0x7B1>;

// "dscratch" is an alternative name for "dscratch0" which appeared in earlier
// drafts of the RISC-V debug spec
let AltName = "dscratch" in
def : SysReg<"dscratch0", 0x7B2>;
def : SysReg<"dscratch1", 0x7B3>;

//===----------------------------------------------------------------------===//
// User Vector CSRs
//===----------------------------------------------------------------------===//
def : SysReg<"vstart", 0x008>;
def : SysReg<"vxsat", 0x009>;
def SysRegVXRM : SysReg<"vxrm", 0x00A>;
def : SysReg<"vcsr", 0x00F>;
def SysRegVL : SysReg<"vl", 0xC20>;
def : SysReg<"vtype", 0xC21>;
def SysRegVLENB: SysReg<"vlenb", 0xC22>;

//===----------------------------------------------------------------------===//
// State Enable Extension (Smstateen)
//===----------------------------------------------------------------------===//

// sstateen0-sstateen3 at 0x10C-0x10F, mstateen0-mstateen3 at 0x30C-0x30F,
// mstateen0h-mstateen3h at 0x31C-0x31F, hstateen0-hstateen3 at 0x60C-0x60F,
// and hstateen0h-hstateen3h at 0x61C-0x61F.
foreach i = 0...3 in {
  def : SysReg<"sstateen"#i, !add(0x10C, i)>;
  def : SysReg<"mstateen"#i, !add(0x30C, i)>;
  let isRV32Only = 1 in
  def : SysReg<"mstateen"#i#"h", !add(0x31C, i)>;
  def : SysReg<"hstateen"#i, !add(0x60C, i)>;
  let isRV32Only = 1 in
  def : SysReg<"hstateen"#i#"h", !add(0x61C, i)>;
}

//===-----------------------------------------------
// Entropy Source CSR
//===-----------------------------------------------

def SEED : SysReg<"seed", 0x015>;

//===-----------------------------------------------
// Advanced Interrupt Architecture
//===-----------------------------------------------

// Machine-level CSRs
def : SysReg<"miselect", 0x350>;
def : SysReg<"mireg", 0x351>;
def : SysReg<"mtopei", 0x35C>;
def : SysReg<"mtopi", 0xFB0>;
def : SysReg<"mvien", 0x308>;
def : SysReg<"mvip", 0x309>;
let isRV32Only = 1 in {
def : SysReg<"midelegh", 0x313>;
def : SysReg<"mieh", 0x314>;
def : SysReg<"mvienh", 0x318>;
def : SysReg<"mviph", 0x319>;
def : SysReg<"miph", 0x354>;
} // isRV32Only

// Supervisor-level CSRs
def : SysReg<"siselect", 0x150>;
def : SysReg<"sireg", 0x151>;
def : SysReg<"stopei", 0x15C>;
def : SysReg<"stopi", 0xDB0>;
let isRV32Only = 1 in {
def : SysReg<"sieh", 0x114>;
def : SysReg<"siph", 0x154>;
} // isRV32Only

// Hypervisor and VS CSRs
def : SysReg<"hvien", 0x608>;
def : SysReg<"hvictl", 0x609>;
def : SysReg<"hviprio1", 0x646>;
def : SysReg<"hviprio2", 0x647>;
def : SysReg<"vsiselect", 0x250>;
def : SysReg<"vsireg", 0x251>;
def : SysReg<"vstopei", 0x25C>;
def : SysReg<"vstopi", 0xEB0>;
let isRV32Only = 1 in {
def : SysReg<"hidelegh", 0x613>;
def : SysReg<"hvienh", 0x618>;
def : SysReg<"hviph", 0x655>;
def : SysReg<"hviprio1h", 0x656>;
def : SysReg<"hviprio2h", 0x657>;
def : SysReg<"vsieh", 0x214>;
def : SysReg<"vsiph", 0x254>;
} // isRV32Only

// Jump Vector Table CSR
//===-----------------------------------------------

def : SysReg<"jvt", 0x017>;

//===----------------------------------------------------------------------===//
// Generated custom CSRs from riscv-opcodes
//===----------------------------------------------------------------------===//

def SysReg_UTVT : SysReg<"utvt", 0x007>;
def SysReg_SSP : SysReg<"ssp", 0x011>;
def SysReg_UNXTI : SysReg<"unxti", 0x045>;
def SysReg_UINTSTATUS : SysReg<"uintstatus", 0x046>;
def SysReg_USCRATCHCSW : SysReg<"uscratchcsw", 0x048>;
def SysReg_USCRATCHCSWL : SysReg<"uscratchcswl", 0x049>;
def SysReg_STVT : SysReg<"stvt", 0x107>;
def SysReg_SSTATEEN0 : SysReg<"sstateen0", 0x10C>;
def SysReg_SSTATEEN1 : SysReg<"sstateen1", 0x10D>;
def SysReg_SSTATEEN2 : SysReg<"sstateen2", 0x10E>;
def SysReg_SSTATEEN3 : SysReg<"sstateen3", 0x10F>;
def SysReg_SCOUNTINHIBIT : SysReg<"scountinhibit", 0x120>;
def SysReg_SNXTI : SysReg<"snxti", 0x145>;
def SysReg_SINTSTATUS : SysReg<"sintstatus", 0x146>;
def SysReg_SSCRATCHCSW : SysReg<"sscratchcsw", 0x148>;
def SysReg_SSCRATCHCSWL : SysReg<"sscratchcswl", 0x149>;
def SysReg_SCTRCTL : SysReg<"sctrctl", 0x14E>;
def SysReg_SCTRSTATUS : SysReg<"sctrstatus", 0x14F>;
def SysReg_SIREG2 : SysReg<"sireg2", 0x152>;
def SysReg_SIREG3 : SysReg<"sireg3", 0x153>;
def SysReg_SIREG4 : SysReg<"sireg4", 0x155>;
def SysReg_SIREG5 : SysReg<"sireg5", 0x156>;
def SysReg_SIREG6 : SysReg<"sireg6", 0x157>;
def SysReg_SCTRDEPTH : SysReg<"sctrdepth", 0x15F>;
def SysReg_SRMCFG : SysReg<"srmcfg", 0x181>;
def SysReg_SPMPEN : SysReg<"spmpen", 0x183>;
def SysReg_VSCTRCTL : SysReg<"vsctrctl", 0x24E>;
def SysReg_VSIREG2 : SysReg<"vsireg2", 0x252>;
def SysReg_VSIREG3 : SysReg<"vsireg3", 0x253>;
def SysReg_VSIREG4 : SysReg<"vsireg4", 0x255>;
def SysReg_VSIREG5 : SysReg<"vsireg5", 0x256>;
def SysReg_VSIREG6 : SysReg<"vsireg6", 0x257>;
def SysReg_MTVT : SysReg<"mtvt", 0x307>;
def SysReg_MSTATEEN0 : SysReg<"mstateen0", 0x30C>;
def SysReg_MSTATEEN1 : SysReg<"mstateen1", 0x30D>;
def SysReg_MSTATEEN2 : SysReg<"mstateen2", 0x30E>;
def SysReg_MSTATEEN3 : SysReg<"mstateen3", 0x30F>;
def SysReg_MPMPDELEG : SysReg<"mpmpdeleg", 0x316>;
def SysReg_MCYCLECFG : SysReg<"mcyclecfg", 0x321>;
def SysReg_MINSTRETCFG : SysReg<"minstretcfg", 0x322>;
def SysReg_MHPMEVENT3 : SysReg<"mhpmevent3", 0x323>;
def SysReg_MHPMEVENT4 : SysReg<"mhpmevent4", 0x324>;
def SysReg_MHPMEVENT5 : SysReg<"mhpmevent5", 0x325>;
def SysReg_MHPMEVENT6 : SysReg<"mhpmevent6", 0x326>;
def SysReg_MHPMEVENT7 : SysReg<"mhpmevent7", 0x327>;
def SysReg_MHPMEVENT8 : SysReg<"mhpmevent8", 0x328>;
def SysReg_MHPMEVENT9 : SysReg<"mhpmevent9", 0x329>;
def SysReg_MHPMEVENT10 : SysReg<"mhpmevent10", 0x32A>;
def SysReg_MHPMEVENT11 : SysReg<"mhpmevent11", 0x32B>;
def SysReg_MHPMEVENT12 : SysReg<"mhpmevent12", 0x32C>;
def SysReg_MHPMEVENT13 : SysReg<"mhpmevent13", 0x32D>;
def SysReg_MHPMEVENT14 : SysReg<"mhpmevent14", 0x32E>;
def SysReg_MHPMEVENT15 : SysReg<"mhpmevent15", 0x32F>;
def SysReg_MHPMEVENT16 : SysReg<"mhpmevent16", 0x330>;
def SysReg_MHPMEVENT17 : SysReg<"mhpmevent17", 0x331>;
def SysReg_MHPMEVENT18 : SysReg<"mhpmevent18", 0x332>;
def SysReg_MHPMEVENT19 : SysReg<"mhpmevent19", 0x333>;
def SysReg_MHPMEVENT20 : SysReg<"mhpmevent20", 0x334>;
def SysReg_MHPMEVENT21 : SysReg<"mhpmevent21", 0x335>;
def SysReg_MHPMEVENT22 : SysReg<"mhpmevent22", 0x336>;
def SysReg_MHPMEVENT23 : SysReg<"mhpmevent23", 0x337>;
def SysReg_MHPMEVENT24 : SysReg<"mhpmevent24", 0x338>;
def SysReg_MHPMEVENT25 : SysReg<"mhpmevent25", 0x339>;
def SysReg_MHPMEVENT26 : SysReg<"mhpmevent26", 0x33A>;
def SysReg_MHPMEVENT27 : SysReg<"mhpmevent27", 0x33B>;
def SysReg_MHPMEVENT28 : SysReg<"mhpmevent28", 0x33C>;
def SysReg_MHPMEVENT29 : SysReg<"mhpmevent29", 0x33D>;
def SysReg_MHPMEVENT30 : SysReg<"mhpmevent30", 0x33E>;
def SysReg_MHPMEVENT31 : SysReg<"mhpmevent31", 0x33F>;
def SysReg_MNXTI : SysReg<"mnxti", 0x345>;
def SysReg_MINTSTATUS : SysReg<"mintstatus", 0x346>;
def SysReg_MSCRATCHCSW : SysReg<"mscratchcsw", 0x348>;
def SysReg_MSCRATCHCSWL : SysReg<"mscratchcswl", 0x349>;
def SysReg_MCTRCTL : SysReg<"mctrctl", 0x34E>;
def SysReg_MIREG2 : SysReg<"mireg2", 0x352>;
def SysReg_MIREG3 : SysReg<"mireg3", 0x353>;
def SysReg_MIREG4 : SysReg<"mireg4", 0x355>;
def SysReg_MIREG5 : SysReg<"mireg5", 0x356>;
def SysReg_MIREG6 : SysReg<"mireg6", 0x357>;
def SysReg_PMPCFG0 : SysReg<"pmpcfg0", 0x3A0>;
def SysReg_PMPCFG1 : SysReg<"pmpcfg1", 0x3A1>;
def SysReg_PMPCFG2 : SysReg<"pmpcfg2", 0x3A2>;
def SysReg_PMPCFG3 : SysReg<"pmpcfg3", 0x3A3>;
def SysReg_PMPCFG4 : SysReg<"pmpcfg4", 0x3A4>;
def SysReg_PMPCFG5 : SysReg<"pmpcfg5", 0x3A5>;
def SysReg_PMPCFG6 : SysReg<"pmpcfg6", 0x3A6>;
def SysReg_PMPCFG7 : SysReg<"pmpcfg7", 0x3A7>;
def SysReg_PMPCFG8 : SysReg<"pmpcfg8", 0x3A8>;
def SysReg_PMPCFG9 : SysReg<"pmpcfg9", 0x3A9>;
def SysReg_PMPCFG10 : SysReg<"pmpcfg10", 0x3AA>;
def SysReg_PMPCFG11 : SysReg<"pmpcfg11", 0x3AB>;
def SysReg_PMPCFG12 : SysReg<"pmpcfg12", 0x3AC>;
def SysReg_PMPCFG13 : SysReg<"pmpcfg13", 0x3AD>;
def SysReg_PMPCFG14 : SysReg<"pmpcfg14", 0x3AE>;
def SysReg_PMPCFG15 : SysReg<"pmpcfg15", 0x3AF>;
def SysReg_PMPADDR0 : SysReg<"pmpaddr0", 0x3B0>;
def SysReg_PMPADDR1 : SysReg<"pmpaddr1", 0x3B1>;
def SysReg_PMPADDR2 : SysReg<"pmpaddr2", 0x3B2>;
def SysReg_PMPADDR3 : SysReg<"pmpaddr3", 0x3B3>;
def SysReg_PMPADDR4 : SysReg<"pmpaddr4", 0x3B4>;
def SysReg_PMPADDR5 : SysReg<"pmpaddr5", 0x3B5>;
def SysReg_PMPADDR6 : SysReg<"pmpaddr6", 0x3B6>;
def SysReg_PMPADDR7 : SysReg<"pmpaddr7", 0x3B7>;
def SysReg_PMPADDR8 : SysReg<"pmpaddr8", 0x3B8>;
def SysReg_PMPADDR9 : SysReg<"pmpaddr9", 0x3B9>;
def SysReg_PMPADDR10 : SysReg<"pmpaddr10", 0x3BA>;
def SysReg_PMPADDR11 : SysReg<"pmpaddr11", 0x3BB>;
def SysReg_PMPADDR12 : SysReg<"pmpaddr12", 0x3BC>;
def SysReg_PMPADDR13 : SysReg<"pmpaddr13", 0x3BD>;
def SysReg_PMPADDR14 : SysReg<"pmpaddr14", 0x3BE>;
def SysReg_PMPADDR15 : SysReg<"pmpaddr15", 0x3BF>;
def SysReg_PMPADDR16 : SysReg<"pmpaddr16", 0x3C0>;
def SysReg_PMPADDR17 : SysReg<"pmpaddr17", 0x3C1>;
def SysReg_PMPADDR18 : SysReg<"pmpaddr18", 0x3C2>;
def SysReg_PMPADDR19 : SysReg<"pmpaddr19", 0x3C3>;
def SysReg_PMPADDR20 : SysReg<"pmpaddr20", 0x3C4>;
def SysReg_PMPADDR21 : SysReg<"pmpaddr21", 0x3C5>;
def SysReg_PMPADDR22 : SysReg<"pmpaddr22", 0x3C6>;
def SysReg_PMPADDR23 : SysReg<"pmpaddr23", 0x3C7>;
def SysReg_PMPADDR24 : SysReg<"pmpaddr24", 0x3C8>;
def SysReg_PMPADDR25 : SysReg<"pmpaddr25", 0x3C9>;
def SysReg_PMPADDR26 : SysReg<"pmpaddr26", 0x3CA>;
def SysReg_PMPADDR27 : SysReg<"pmpaddr27", 0x3CB>;
def SysReg_PMPADDR28 : SysReg<"pmpaddr28", 0x3CC>;
def SysReg_PMPADDR29 : SysReg<"pmpaddr29", 0x3CD>;
def SysReg_PMPADDR30 : SysReg<"pmpaddr30", 0x3CE>;
def SysReg_PMPADDR31 : SysReg<"pmpaddr31", 0x3CF>;
def SysReg_PMPADDR32 : SysReg<"pmpaddr32", 0x3D0>;
def SysReg_PMPADDR33 : SysReg<"pmpaddr33", 0x3D1>;
def SysReg_PMPADDR34 : SysReg<"pmpaddr34", 0x3D2>;
def SysReg_PMPADDR35 : SysReg<"pmpaddr35", 0x3D3>;
def SysReg_PMPADDR36 : SysReg<"pmpaddr36", 0x3D4>;
def SysReg_PMPADDR37 : SysReg<"pmpaddr37", 0x3D5>;
def SysReg_PMPADDR38 : SysReg<"pmpaddr38", 0x3D6>;
def SysReg_PMPADDR39 : SysReg<"pmpaddr39", 0x3D7>;
def SysReg_PMPADDR40 : SysReg<"pmpaddr40", 0x3D8>;
def SysReg_PMPADDR41 : SysReg<"pmpaddr41", 0x3D9>;
def SysReg_PMPADDR42 : SysReg<"pmpaddr42", 0x3DA>;
def SysReg_PMPADDR43 : SysReg<"pmpaddr43", 0x3DB>;
def SysReg_PMPADDR44 : SysReg<"pmpaddr44", 0x3DC>;
def SysReg_PMPADDR45 : SysReg<"pmpaddr45", 0x3DD>;
def SysReg_PMPADDR46 : SysReg<"pmpaddr46", 0x3DE>;
def SysReg_PMPADDR47 : SysReg<"pmpaddr47", 0x3DF>;
def SysReg_PMPADDR48 : SysReg<"pmpaddr48", 0x3E0>;
def SysReg_PMPADDR49 : SysReg<"pmpaddr49", 0x3E1>;
def SysReg_PMPADDR50 : SysReg<"pmpaddr50", 0x3E2>;
def SysReg_PMPADDR51 : SysReg<"pmpaddr51", 0x3E3>;
def SysReg_PMPADDR52 : SysReg<"pmpaddr52", 0x3E4>;
def SysReg_PMPADDR53 : SysReg<"pmpaddr53", 0x3E5>;
def SysReg_PMPADDR54 : SysReg<"pmpaddr54", 0x3E6>;
def SysReg_PMPADDR55 : SysReg<"pmpaddr55", 0x3E7>;
def SysReg_PMPADDR56 : SysReg<"pmpaddr56", 0x3E8>;
def SysReg_PMPADDR57 : SysReg<"pmpaddr57", 0x3E9>;
def SysReg_PMPADDR58 : SysReg<"pmpaddr58", 0x3EA>;
def SysReg_PMPADDR59 : SysReg<"pmpaddr59", 0x3EB>;
def SysReg_PMPADDR60 : SysReg<"pmpaddr60", 0x3EC>;
def SysReg_PMPADDR61 : SysReg<"pmpaddr61", 0x3ED>;
def SysReg_PMPADDR62 : SysReg<"pmpaddr62", 0x3EE>;
def SysReg_PMPADDR63 : SysReg<"pmpaddr63", 0x3EF>;
def SysReg_HSTATEEN0 : SysReg<"hstateen0", 0x60C>;
def SysReg_HSTATEEN1 : SysReg<"hstateen1", 0x60D>;
def SysReg_HSTATEEN2 : SysReg<"hstateen2", 0x60E>;
def SysReg_HSTATEEN3 : SysReg<"hstateen3", 0x60F>;
def SysReg_TINFO : SysReg<"tinfo", 0x7A4>;
def SysReg_TCONTROL : SysReg<"tcontrol", 0x7A5>;
def SysReg_MSCONTEXT : SysReg<"mscontext", 0x7AA>;
def SysReg_SSR : SysReg<"ssr", 0x7C0>;
def SysReg_FPMODE : SysReg<"fpmode", 0x7C1>;
def SysReg_BARRIER : SysReg<"barrier", 0x7C2>;
def SysReg_SC : SysReg<"sc", 0x7C3>;
def SysReg_USER_LOW : SysReg<"user_low", 0x7C4>;
def SysReg_USER_HIGH : SysReg<"user_high", 0x7C5>;
def SysReg_COPIFT : SysReg<"copift", 0x7C6>;
def SysReg_DUMP : SysReg<"dump", 0x7C7>;
def SysReg_STACKLIMIT : SysReg<"stacklimit", 0x7D1>;
def SysReg_FMODE : SysReg<"fmode", 0x800>;
def SysReg_MHPMCOUNTER3 : SysReg<"mhpmcounter3", 0xB03>;
def SysReg_MHPMCOUNTER4 : SysReg<"mhpmcounter4", 0xB04>;
def SysReg_MHPMCOUNTER5 : SysReg<"mhpmcounter5", 0xB05>;
def SysReg_MHPMCOUNTER6 : SysReg<"mhpmcounter6", 0xB06>;
def SysReg_MHPMCOUNTER7 : SysReg<"mhpmcounter7", 0xB07>;
def SysReg_MHPMCOUNTER8 : SysReg<"mhpmcounter8", 0xB08>;
def SysReg_MHPMCOUNTER9 : SysReg<"mhpmcounter9", 0xB09>;
def SysReg_MHPMCOUNTER10 : SysReg<"mhpmcounter10", 0xB0A>;
def SysReg_MHPMCOUNTER11 : SysReg<"mhpmcounter11", 0xB0B>;
def SysReg_MHPMCOUNTER12 : SysReg<"mhpmcounter12", 0xB0C>;
def SysReg_MHPMCOUNTER13 : SysReg<"mhpmcounter13", 0xB0D>;
def SysReg_MHPMCOUNTER14 : SysReg<"mhpmcounter14", 0xB0E>;
def SysReg_MHPMCOUNTER15 : SysReg<"mhpmcounter15", 0xB0F>;
def SysReg_MHPMCOUNTER16 : SysReg<"mhpmcounter16", 0xB10>;
def SysReg_MHPMCOUNTER17 : SysReg<"mhpmcounter17", 0xB11>;
def SysReg_MHPMCOUNTER18 : SysReg<"mhpmcounter18", 0xB12>;
def SysReg_MHPMCOUNTER19 : SysReg<"mhpmcounter19", 0xB13>;
def SysReg_MHPMCOUNTER20 : SysReg<"mhpmcounter20", 0xB14>;
def SysReg_MHPMCOUNTER21 : SysReg<"mhpmcounter21", 0xB15>;
def SysReg_MHPMCOUNTER22 : SysReg<"mhpmcounter22", 0xB16>;
def SysReg_MHPMCOUNTER23 : SysReg<"mhpmcounter23", 0xB17>;
def SysReg_MHPMCOUNTER24 : SysReg<"mhpmcounter24", 0xB18>;
def SysReg_MHPMCOUNTER25 : SysReg<"mhpmcounter25", 0xB19>;
def SysReg_MHPMCOUNTER26 : SysReg<"mhpmcounter26", 0xB1A>;
def SysReg_MHPMCOUNTER27 : SysReg<"mhpmcounter27", 0xB1B>;
def SysReg_MHPMCOUNTER28 : SysReg<"mhpmcounter28", 0xB1C>;
def SysReg_MHPMCOUNTER29 : SysReg<"mhpmcounter29", 0xB1D>;
def SysReg_MHPMCOUNTER30 : SysReg<"mhpmcounter30", 0xB1E>;
def SysReg_MHPMCOUNTER31 : SysReg<"mhpmcounter31", 0xB1F>;
def SysReg_HPMCOUNTER3 : SysReg<"hpmcounter3", 0xC03>;
def SysReg_HPMCOUNTER4 : SysReg<"hpmcounter4", 0xC04>;
def SysReg_HPMCOUNTER5 : SysReg<"hpmcounter5", 0xC05>;
def SysReg_HPMCOUNTER6 : SysReg<"hpmcounter6", 0xC06>;
def SysReg_HPMCOUNTER7 : SysReg<"hpmcounter7", 0xC07>;
def SysReg_HPMCOUNTER8 : SysReg<"hpmcounter8", 0xC08>;
def SysReg_HPMCOUNTER9 : SysReg<"hpmcounter9", 0xC09>;
def SysReg_HPMCOUNTER10 : SysReg<"hpmcounter10", 0xC0A>;
def SysReg_HPMCOUNTER11 : SysReg<"hpmcounter11", 0xC0B>;
def SysReg_HPMCOUNTER12 : SysReg<"hpmcounter12", 0xC0C>;
def SysReg_HPMCOUNTER13 : SysReg<"hpmcounter13", 0xC0D>;
def SysReg_HPMCOUNTER14 : SysReg<"hpmcounter14", 0xC0E>;
def SysReg_HPMCOUNTER15 : SysReg<"hpmcounter15", 0xC0F>;
def SysReg_HPMCOUNTER16 : SysReg<"hpmcounter16", 0xC10>;
def SysReg_HPMCOUNTER17 : SysReg<"hpmcounter17", 0xC11>;
def SysReg_HPMCOUNTER18 : SysReg<"hpmcounter18", 0xC12>;
def SysReg_HPMCOUNTER19 : SysReg<"hpmcounter19", 0xC13>;
def SysReg_HPMCOUNTER20 : SysReg<"hpmcounter20", 0xC14>;
def SysReg_HPMCOUNTER21 : SysReg<"hpmcounter21", 0xC15>;
def SysReg_HPMCOUNTER22 : SysReg<"hpmcounter22", 0xC16>;
def SysReg_HPMCOUNTER23 : SysReg<"hpmcounter23", 0xC17>;
def SysReg_HPMCOUNTER24 : SysReg<"hpmcounter24", 0xC18>;
def SysReg_HPMCOUNTER25 : SysReg<"hpmcounter25", 0xC19>;
def SysReg_HPMCOUNTER26 : SysReg<"hpmcounter26", 0xC1A>;
def SysReg_HPMCOUNTER27 : SysReg<"hpmcounter27", 0xC1B>;
def SysReg_HPMCOUNTER28 : SysReg<"hpmcounter28", 0xC1C>;
def SysReg_HPMCOUNTER29 : SysReg<"hpmcounter29", 0xC1D>;
def SysReg_HPMCOUNTER30 : SysReg<"hpmcounter30", 0xC1E>;
def SysReg_HPMCOUNTER31 : SysReg<"hpmcounter31", 0xC1F>;
