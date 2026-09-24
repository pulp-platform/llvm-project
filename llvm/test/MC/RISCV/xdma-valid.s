# Xdma - PULP Asynchronous Data Movement Extension
# RUN: llvm-mc %s -triple=riscv32 -mattr=+xdma -M no-aliases -show-encoding \
# RUN:     | FileCheck -check-prefixes=CHECK-ENC,CHECK-INST %s
# RUN: llvm-mc -filetype=obj -triple riscv32 -mattr=+xdma < %s \
# RUN:     | llvm-objdump --mattr=+xdma -M no-aliases -d - \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: dmopc a0, a1
# CHECK-ENC: encoding: [0x2b,0x00,0xb5,0x14]
dmopc a0, a1

# CHECK-INST: dmopc zero, zero
# CHECK-ENC: encoding: [0x2b,0x00,0x00,0x14]
dmopc x0, x0

# CHECK-INST: dmopc t6, s11
# CHECK-ENC: encoding: [0x2b,0x80,0xbf,0x15]
dmopc x31, x27
