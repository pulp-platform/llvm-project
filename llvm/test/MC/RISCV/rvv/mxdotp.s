# RUN: llvm-mc -triple=riscv64 -show-encoding --mattr=+v %s \
# RUN:         --mattr=+f \
# RUN:        | FileCheck %s --check-prefixes=CHECK-ENCODING,CHECK-INST

vmxdotp.wf v8, ft9, v9, ft10, v10
# CHECK-INST: vmxdotp.wf v8, ft9, v9, ft10, v10
# CHECK-ENCODING: [0x5f,0xa4,0x9e,0xf2]

vmxdotp.ww v8, v9, v10, v11, v12
# CHECK-INST: vmxdotp.ww v8, v9, v10, v11, v12
# CHECK-ENCODING: [0x7f,0xc4,0xa4,0x5a]
