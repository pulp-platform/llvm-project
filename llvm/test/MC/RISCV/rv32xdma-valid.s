# RUN: llvm-mc %s -triple=riscv32 --mattr=xdma -riscv-no-aliases -show-encoding \
# RUN:     | FileCheck -check-prefixes=CHECK-ASM,CHECK-ASM-AND-OBJ %s
# RUN: llvm-mc %s -filetype=obj -triple=riscv32  --mattr=xdma \
# RUN:     | llvm-objdump -M no-aliases -d -r --mattr=xdma - \
# RUN:     | FileCheck -check-prefixes=CHECK-DISASM %s

# CHECK-ASM-AND-OBJ: dmsrc t0, t1
# CHECK-ASM: encoding: [0x2b,0x80,0x62,0x00]
# CHECK-DISASM: 2b 80 62 00   dmsrc  t0, t1
dmsrc t0, t1
# CHECK-ASM-AND-OBJ: dmdst t2, t3
# CHECK-ASM: encoding: [0x2b,0x80,0xc3,0x03]
# CHECK-DISASM: 2b 80 c3 03   dmdst  t2, t3
dmdst t2, t3
# CHECK-ASM-AND-OBJ: dmstr t0, t1
# CHECK-ASM: encoding: [0x2b,0x80,0x62,0x0c]
# CHECK-DISASM: 2b 80 62 0c   dmstr  t0, t1
dmstr t0, t1
# CHECK-ASM-AND-OBJ: dmcpyi t0, t1, 11
# CHECK-ASM: encoding: [0xab,0x02,0xb3,0x04]
# CHECK-DISASM: ab 02 b3 04   dmcpyi t0, t1, 11
dmcpyi t0, t1, 0b1011
# CHECK-ASM-AND-OBJ: dmcpy t0, t1, t2
# CHECK-ASM: encoding: [0xab,0x02,0x73,0x06]
# CHECK-DISASM: ab 02 73 06   dmcpy t0, t1, t2
dmcpy t0, t1, t2
# CHECK-ASM-AND-OBJ: dmstati t0, 5
# CHECK-ASM: encoding: [0xab,0x02,0x50,0x08]
# CHECK-DISASM: ab 02 50 08   dmstati t0, 5
dmstati t0, 0b0101
# CHECK-ASM-AND-OBJ: dmstat t0, t1
# CHECK-ASM: encoding: [0xab,0x02,0x60,0x0a]
# CHECK-DISASM: ab 02 60 0a   dmstat t0, t1
dmstat t0, t1
# CHECK-ASM-AND-OBJ: dmrep t0
# CHECK-ASM: encoding: [0x2b,0x80,0x02,0x0e]
# CHECK-DISASM: 2b 80 02 0e   dmrep t0
dmrep t0
# CHECK-ASM-AND-OBJ: dmuser t0, t1
# CHECK-ASM: encoding: [0x2b,0x80,0x62,0x10]
# CHECK-DISASM: 2b 80 62 10   dmuser t0, t1
dmuser t0, t1
