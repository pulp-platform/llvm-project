# Xpulpvect - PULP SIMD instructions with a 6-bit immediate
# RUN: llvm-mc %s -triple=riscv32 -mattr=+xpulpvect,+xpulpvectshufflepack -M no-aliases -show-encoding \
# RUN:     | FileCheck -check-prefixes=CHECK-ENC,CHECK-INST %s
# RUN: llvm-mc -filetype=obj -triple riscv32 -mattr=+xpulpvect,+xpulpvectshufflepack < %s \
# RUN:     | llvm-objdump --mattr=+xpulpvect,+xpulpvectshufflepack --no-print-imm-hex -M no-aliases -d - \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: pv.shuffle.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0xc2]
pv.shuffle.sci.h a0, a1, 11

# CHECK-INST: pv.shufflei0.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0xc2]
pv.shufflei0.sci.b a0, a1, 11

# CHECK-INST: pv.shufflei1.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0xea]
pv.shufflei1.sci.b a0, a1, 11

# CHECK-INST: pv.shufflei2.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0xf2]
pv.shufflei2.sci.b a0, a1, 11

# CHECK-INST: pv.shufflei3.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0xfa]
pv.shufflei3.sci.b a0, a1, 11

# CHECK-INST: pv.add.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x02]
pv.add.sci.h a0, a1, 11

# CHECK-INST: pv.add.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x02]
pv.add.sci.b a0, a1, 11

# CHECK-INST: pv.sub.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x0a]
pv.sub.sci.h a0, a1, 11

# CHECK-INST: pv.sub.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x0a]
pv.sub.sci.b a0, a1, 11

# CHECK-INST: pv.avg.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x12]
pv.avg.sci.h a0, a1, 11

# CHECK-INST: pv.avg.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x12]
pv.avg.sci.b a0, a1, 11

# CHECK-INST: pv.avgu.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x1a]
pv.avgu.sci.h a0, a1, 11

# CHECK-INST: pv.avgu.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x1a]
pv.avgu.sci.b a0, a1, 11

# CHECK-INST: pv.min.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x22]
pv.min.sci.h a0, a1, 11

# CHECK-INST: pv.min.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x22]
pv.min.sci.b a0, a1, 11

# CHECK-INST: pv.minu.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x2a]
pv.minu.sci.h a0, a1, 11

# CHECK-INST: pv.minu.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x2a]
pv.minu.sci.b a0, a1, 11

# CHECK-INST: pv.max.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x32]
pv.max.sci.h a0, a1, 11

# CHECK-INST: pv.max.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x32]
pv.max.sci.b a0, a1, 11

# CHECK-INST: pv.maxu.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x3a]
pv.maxu.sci.h a0, a1, 11

# CHECK-INST: pv.maxu.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x3a]
pv.maxu.sci.b a0, a1, 11

# CHECK-INST: pv.srl.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x42]
pv.srl.sci.h a0, a1, 11

# CHECK-INST: pv.srl.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x42]
pv.srl.sci.b a0, a1, 11

# CHECK-INST: pv.sra.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x4a]
pv.sra.sci.h a0, a1, 11

# CHECK-INST: pv.sra.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x4a]
pv.sra.sci.b a0, a1, 11

# CHECK-INST: pv.sll.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x52]
pv.sll.sci.h a0, a1, 11

# CHECK-INST: pv.sll.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x52]
pv.sll.sci.b a0, a1, 11

# CHECK-INST: pv.or.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x5a]
pv.or.sci.h a0, a1, 11

# CHECK-INST: pv.or.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x5a]
pv.or.sci.b a0, a1, 11

# CHECK-INST: pv.xor.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x62]
pv.xor.sci.h a0, a1, 11

# CHECK-INST: pv.xor.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x62]
pv.xor.sci.b a0, a1, 11

# CHECK-INST: pv.and.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x6a]
pv.and.sci.h a0, a1, 11

# CHECK-INST: pv.and.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x6a]
pv.and.sci.b a0, a1, 11

# CHECK-INST: pv.extract.h a0, a1, 1
# CHECK-ENC: encoding: [0x57,0xe5,0x05,0x7a]
pv.extract.h a0, a1, 1

# CHECK-INST: pv.extract.b a0, a1, 1
# CHECK-ENC: encoding: [0x57,0xf5,0x05,0x7a]
pv.extract.b a0, a1, 1

# CHECK-INST: pv.extractu.h a0, a1, 1
# CHECK-ENC: encoding: [0x57,0xe5,0x05,0x92]
pv.extractu.h a0, a1, 1

# CHECK-INST: pv.extractu.b a0, a1, 1
# CHECK-ENC: encoding: [0x57,0xf5,0x05,0x92]
pv.extractu.b a0, a1, 1

# CHECK-INST: pv.insert.h a0, a1, 1
# CHECK-ENC: encoding: [0x57,0xe5,0x05,0xb2]
pv.insert.h a0, a1, 1

# CHECK-INST: pv.insert.b a0, a1, 1
# CHECK-ENC: encoding: [0x57,0xf5,0x05,0xb2]
pv.insert.b a0, a1, 1

# CHECK-INST: pv.dotsp.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x9a]
pv.dotsp.sci.h a0, a1, 11

# CHECK-INST: pv.dotsp.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x9a]
pv.dotsp.sci.b a0, a1, 11

# CHECK-INST: pv.dotup.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x82]
pv.dotup.sci.h a0, a1, 11

# CHECK-INST: pv.dotup.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x82]
pv.dotup.sci.b a0, a1, 11

# CHECK-INST: pv.dotusp.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x8a]
pv.dotusp.sci.h a0, a1, 11

# CHECK-INST: pv.dotusp.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x8a]
pv.dotusp.sci.b a0, a1, 11

# CHECK-INST: pv.sdotsp.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0xba]
pv.sdotsp.sci.h a0, a1, 11

# CHECK-INST: pv.sdotsp.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0xba]
pv.sdotsp.sci.b a0, a1, 11

# CHECK-INST: pv.sdotup.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0xa2]
pv.sdotup.sci.h a0, a1, 11

# CHECK-INST: pv.sdotup.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0xa2]
pv.sdotup.sci.b a0, a1, 11

# CHECK-INST: pv.sdotusp.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0xaa]
pv.sdotusp.sci.h a0, a1, 11

# CHECK-INST: pv.sdotusp.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0xaa]
pv.sdotusp.sci.b a0, a1, 11

# CHECK-INST: pv.cmpeq.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x06]
pv.cmpeq.sci.h a0, a1, 11

# CHECK-INST: pv.cmpeq.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x06]
pv.cmpeq.sci.b a0, a1, 11

# CHECK-INST: pv.cmpne.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x0e]
pv.cmpne.sci.h a0, a1, 11

# CHECK-INST: pv.cmpne.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x0e]
pv.cmpne.sci.b a0, a1, 11

# CHECK-INST: pv.cmpgt.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x16]
pv.cmpgt.sci.h a0, a1, 11

# CHECK-INST: pv.cmpgt.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x16]
pv.cmpgt.sci.b a0, a1, 11

# CHECK-INST: pv.cmpge.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x1e]
pv.cmpge.sci.h a0, a1, 11

# CHECK-INST: pv.cmpge.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x1e]
pv.cmpge.sci.b a0, a1, 11

# CHECK-INST: pv.cmplt.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x26]
pv.cmplt.sci.h a0, a1, 11

# CHECK-INST: pv.cmplt.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x26]
pv.cmplt.sci.b a0, a1, 11

# CHECK-INST: pv.cmple.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x2e]
pv.cmple.sci.h a0, a1, 11

# CHECK-INST: pv.cmple.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x2e]
pv.cmple.sci.b a0, a1, 11

# CHECK-INST: pv.cmpgtu.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x36]
pv.cmpgtu.sci.h a0, a1, 11

# CHECK-INST: pv.cmpgtu.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x36]
pv.cmpgtu.sci.b a0, a1, 11

# CHECK-INST: pv.cmpgeu.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x3e]
pv.cmpgeu.sci.h a0, a1, 11

# CHECK-INST: pv.cmpgeu.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x3e]
pv.cmpgeu.sci.b a0, a1, 11

# CHECK-INST: pv.cmpltu.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x46]
pv.cmpltu.sci.h a0, a1, 11

# CHECK-INST: pv.cmpltu.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x46]
pv.cmpltu.sci.b a0, a1, 11

# CHECK-INST: pv.cmpleu.sci.h a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xe5,0x55,0x4e]
pv.cmpleu.sci.h a0, a1, 11

# CHECK-INST: pv.cmpleu.sci.b a0, a1, 11
# CHECK-ENC: encoding: [0x57,0xf5,0x55,0x4e]
pv.cmpleu.sci.b a0, a1, 11
