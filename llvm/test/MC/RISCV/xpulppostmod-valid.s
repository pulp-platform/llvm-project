# Xpulppostmod - PULP post-incrementing and register-register loads/stores
# RUN: llvm-mc %s -triple=riscv32 -mattr=+xpulppostmod -M no-aliases -show-encoding \
# RUN:     | FileCheck -check-prefixes=CHECK-ENC,CHECK-INST %s
# RUN: llvm-mc -filetype=obj -triple riscv32 -mattr=+xpulppostmod < %s \
# RUN:     | llvm-objdump --mattr=+xpulppostmod --no-print-imm-hex -M no-aliases -d - \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: p.lb.irpost a0, (a1), 4
# CHECK-ENC: encoding: [0x0b,0x85,0x45,0x00]
p.lb.irpost a0, (a1), 4

# CHECK-INST: p.lb.irpost t0, (t1), -2048
# CHECK-ENC: encoding: [0x8b,0x02,0x03,0x80]
p.lb.irpost t0, (t1), -2048

# CHECK-INST: p.lb.rrpost a0, (a1), a2
# CHECK-ENC: encoding: [0x0b,0xf5,0xc5,0x00]
p.lb.rrpost a0, (a1), a2

# CHECK-INST: p.lb.rr a0, a2(a1)
# CHECK-ENC: encoding: [0x03,0xf5,0xc5,0x00]
p.lb.rr a0, a2(a1)

# CHECK-INST: p.lbu.irpost a0, (a1), 4
# CHECK-ENC: encoding: [0x0b,0xc5,0x45,0x00]
p.lbu.irpost a0, (a1), 4

# CHECK-INST: p.lbu.irpost t0, (t1), -2048
# CHECK-ENC: encoding: [0x8b,0x42,0x03,0x80]
p.lbu.irpost t0, (t1), -2048

# CHECK-INST: p.lbu.rrpost a0, (a1), a2
# CHECK-ENC: encoding: [0x0b,0xf5,0xc5,0x40]
p.lbu.rrpost a0, (a1), a2

# CHECK-INST: p.lbu.rr a0, a2(a1)
# CHECK-ENC: encoding: [0x03,0xf5,0xc5,0x40]
p.lbu.rr a0, a2(a1)

# CHECK-INST: p.lh.irpost a0, (a1), 4
# CHECK-ENC: encoding: [0x0b,0x95,0x45,0x00]
p.lh.irpost a0, (a1), 4

# CHECK-INST: p.lh.irpost t0, (t1), -2048
# CHECK-ENC: encoding: [0x8b,0x12,0x03,0x80]
p.lh.irpost t0, (t1), -2048

# CHECK-INST: p.lh.rrpost a0, (a1), a2
# CHECK-ENC: encoding: [0x0b,0xf5,0xc5,0x10]
p.lh.rrpost a0, (a1), a2

# CHECK-INST: p.lh.rr a0, a2(a1)
# CHECK-ENC: encoding: [0x03,0xf5,0xc5,0x10]
p.lh.rr a0, a2(a1)

# CHECK-INST: p.lhu.irpost a0, (a1), 4
# CHECK-ENC: encoding: [0x0b,0xd5,0x45,0x00]
p.lhu.irpost a0, (a1), 4

# CHECK-INST: p.lhu.irpost t0, (t1), -2048
# CHECK-ENC: encoding: [0x8b,0x52,0x03,0x80]
p.lhu.irpost t0, (t1), -2048

# CHECK-INST: p.lhu.rrpost a0, (a1), a2
# CHECK-ENC: encoding: [0x0b,0xf5,0xc5,0x50]
p.lhu.rrpost a0, (a1), a2

# CHECK-INST: p.lhu.rr a0, a2(a1)
# CHECK-ENC: encoding: [0x03,0xf5,0xc5,0x50]
p.lhu.rr a0, a2(a1)

# CHECK-INST: p.lw.irpost a0, (a1), 4
# CHECK-ENC: encoding: [0x0b,0xa5,0x45,0x00]
p.lw.irpost a0, (a1), 4

# CHECK-INST: p.lw.irpost t0, (t1), -2048
# CHECK-ENC: encoding: [0x8b,0x22,0x03,0x80]
p.lw.irpost t0, (t1), -2048

# CHECK-INST: p.lw.rrpost a0, (a1), a2
# CHECK-ENC: encoding: [0x0b,0xf5,0xc5,0x20]
p.lw.rrpost a0, (a1), a2

# CHECK-INST: p.lw.rr a0, a2(a1)
# CHECK-ENC: encoding: [0x03,0xf5,0xc5,0x20]
p.lw.rr a0, a2(a1)

# CHECK-INST: p.sb.irpost a0, (a1), 4
# CHECK-ENC: encoding: [0x2b,0x82,0xa5,0x00]
p.sb.irpost a0, (a1), 4

# CHECK-INST: p.sb.irpost t0, (t1), 2047
# CHECK-ENC: encoding: [0xab,0x0f,0x53,0x7e]
p.sb.irpost t0, (t1), 2047

# CHECK-INST: p.sb.rrpost a0, (a1), a2
# CHECK-ENC: encoding: [0x2b,0xc6,0xa5,0x00]
p.sb.rrpost a0, (a1), a2

# CHECK-INST: p.sb.rr a0, a2(a1)
# CHECK-ENC: encoding: [0x23,0xc6,0xa5,0x00]
p.sb.rr a0, a2(a1)

# CHECK-INST: p.sh.irpost a0, (a1), 4
# CHECK-ENC: encoding: [0x2b,0x92,0xa5,0x00]
p.sh.irpost a0, (a1), 4

# CHECK-INST: p.sh.irpost t0, (t1), 2047
# CHECK-ENC: encoding: [0xab,0x1f,0x53,0x7e]
p.sh.irpost t0, (t1), 2047

# CHECK-INST: p.sh.rrpost a0, (a1), a2
# CHECK-ENC: encoding: [0x2b,0xd6,0xa5,0x00]
p.sh.rrpost a0, (a1), a2

# CHECK-INST: p.sh.rr a0, a2(a1)
# CHECK-ENC: encoding: [0x23,0xd6,0xa5,0x00]
p.sh.rr a0, a2(a1)

# CHECK-INST: p.sw.irpost a0, (a1), 4
# CHECK-ENC: encoding: [0x2b,0xa2,0xa5,0x00]
p.sw.irpost a0, (a1), 4

# CHECK-INST: p.sw.irpost t0, (t1), 2047
# CHECK-ENC: encoding: [0xab,0x2f,0x53,0x7e]
p.sw.irpost t0, (t1), 2047

# CHECK-INST: p.sw.rrpost a0, (a1), a2
# CHECK-ENC: encoding: [0x2b,0xe6,0xa5,0x00]
p.sw.rrpost a0, (a1), a2

# CHECK-INST: p.sw.rr a0, a2(a1)
# CHECK-ENC: encoding: [0x23,0xe6,0xa5,0x00]
p.sw.rr a0, a2(a1)
