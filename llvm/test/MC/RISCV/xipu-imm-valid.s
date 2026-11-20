# Xipu - integer immediate instructions
# RUN: llvm-mc %s -triple=riscv32 -mattr=+xipu -M no-aliases -show-encoding \
# RUN:     | FileCheck -check-prefixes=CHECK-ENC,CHECK-INST %s
# RUN: llvm-mc -filetype=obj -triple riscv32 -mattr=+xipu < %s \
# RUN:     | llvm-objdump --mattr=+xipu --no-print-imm-hex -M no-aliases -d - \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: iaddi a0, a1, 4
# CHECK-ENC: encoding: [0x7b,0x85,0x45,0x00]
iaddi a0, a1, 4

# CHECK-INST: iaddi t0, t1, -2048
# CHECK-ENC: encoding: [0xfb,0x02,0x03,0x80]
iaddi t0, t1, -2048

# CHECK-INST: islti a0, a1, 2047
# CHECK-ENC: encoding: [0x7b,0xa5,0xf5,0x7f]
islti a0, a1, 2047

# CHECK-INST: isltiu a0, a1, -1
# CHECK-ENC: encoding: [0x7b,0xb5,0xf5,0xff]
isltiu a0, a1, -1

# CHECK-INST: ixori a0, a1, 255
# CHECK-ENC: encoding: [0x7b,0xc5,0xf5,0x0f]
ixori a0, a1, 255

# CHECK-INST: iori t6, zero, 1
# CHECK-ENC: encoding: [0xfb,0x6f,0x10,0x00]
iori t6, zero, 1

# CHECK-INST: iandi a0, a1, -256
# CHECK-ENC: encoding: [0x7b,0xf5,0x05,0xf0]
iandi a0, a1, -256
