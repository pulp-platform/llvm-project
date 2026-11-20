# Xpulpbitop - PULP bit-manipulation operations with two immediates
# RUN: llvm-mc %s -triple=riscv32 -mattr=+xpulpbitop -M no-aliases -show-encoding \
# RUN:     | FileCheck -check-prefixes=CHECK-ENC,CHECK-INST %s
# RUN: llvm-mc -filetype=obj -triple riscv32 -mattr=+xpulpbitop < %s \
# RUN:     | llvm-objdump --mattr=+xpulpbitop --no-print-imm-hex -M no-aliases -d - \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: p.extract a0, a1, 3, 4
# CHECK-ENC: encoding: [0x33,0x85,0x45,0xc6]
p.extract a0, a1, 3, 4

# CHECK-INST: p.extract t0, t1, 31, 0
# CHECK-ENC: encoding: [0xb3,0x02,0x03,0xfe]
p.extract t0, t1, 31, 0

# CHECK-INST: p.extractu a0, a1, 7, 8
# CHECK-ENC: encoding: [0x33,0x95,0x85,0xce]
p.extractu a0, a1, 7, 8

# CHECK-INST: p.insert a0, a1, 3, 4
# CHECK-ENC: encoding: [0x33,0xa5,0x45,0xc6]
p.insert a0, a1, 3, 4

# CHECK-INST: p.bset a0, a1, 2, 5
# CHECK-ENC: encoding: [0x33,0xc5,0x55,0xc4]
p.bset a0, a1, 2, 5

# CHECK-INST: p.bclr a0, a1, 2, 5
# CHECK-ENC: encoding: [0x33,0xb5,0x55,0xc4]
p.bclr a0, a1, 2, 5

# CHECK-INST: p.bclr t0, t1, 0, 31
# CHECK-ENC: encoding: [0xb3,0x32,0xf3,0xc1]
p.bclr t0, t1, 0, 31
