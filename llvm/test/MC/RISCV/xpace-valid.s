# RUN: llvm-mc -triple=riscv32 -show-encoding --mattr=+xpace %s \
# RUN:        | FileCheck %s --check-prefixes=CHECK-ENCODING,CHECK-INST
# RUN: llvm-mc -triple=riscv64 -show-encoding --mattr=+xpace %s \
# RUN:        | FileCheck %s --check-prefixes=CHECK-ENCODING,CHECK-INST
# RUN: not llvm-mc -triple=riscv32 -show-encoding %s 2>&1 \
# RUN:        | FileCheck %s --check-prefix=CHECK-ERROR
# RUN: not llvm-mc -triple=riscv64 -show-encoding %s 2>&1 \
# RUN:        | FileCheck %s --check-prefix=CHECK-ERROR
# RUN: llvm-mc -triple=riscv32 -filetype=obj --mattr=+xpace %s \
# RUN:        | llvm-objdump -d --mattr=+xpace - \
# RUN:        | FileCheck %s --check-prefix=CHECK-INST
# RUN: llvm-mc -triple=riscv64 -filetype=obj --mattr=+xpace %s \
# RUN:        | llvm-objdump -d --mattr=+xpace - \
# RUN:        | FileCheck %s --check-prefix=CHECK-INST
# RUN: llvm-mc -triple=riscv32 -filetype=obj --mattr=+xpace %s \
# RUN:        | llvm-objdump -d - | FileCheck %s --check-prefix=CHECK-UNKNOWN
# RUN: llvm-mc -triple=riscv64 -filetype=obj --mattr=+xpace %s \
# RUN:        | llvm-objdump -d - | FileCheck %s --check-prefix=CHECK-UNKNOWN

# CHECK-INST: pace.pwpa.s fa0, fa1
# CHECK-ENCODING: [0x53,0x85,0x05,0x60]
# CHECK-ERROR: instruction requires the following: 'Xpace' (PACE extension){{$}}
# CHECK-UNKNOWN: 60058553 <unknown>
pace.pwpa.s fa0, fa1

# CHECK-INST: pace.inv.s fa0, fa1
# CHECK-ENCODING: [0x53,0x95,0x05,0x60]
# CHECK-ERROR: instruction requires the following: 'Xpace' (PACE extension){{$}}
# CHECK-UNKNOWN: 60059553 <unknown>
pace.inv.s fa0, fa1

# CHECK-INST: pace.sqrt.s fa0, fa1
# CHECK-ENCODING: [0x53,0xa5,0x05,0x60]
# CHECK-ERROR: instruction requires the following: 'Xpace' (PACE extension){{$}}
# CHECK-UNKNOWN: 6005a553 <unknown>
pace.sqrt.s fa0, fa1

# CHECK-INST: pace.rsqrt.s fa0, fa1
# CHECK-ENCODING: [0x53,0xb5,0x05,0x60]
# CHECK-ERROR: instruction requires the following: 'Xpace' (PACE extension){{$}}
# CHECK-UNKNOWN: 6005b553 <unknown>
pace.rsqrt.s fa0, fa1

# CHECK-INST: pace.pwpa.h fa0, fa1
# CHECK-ENCODING: [0x53,0x85,0x05,0x64]
# CHECK-ERROR: instruction requires the following: 'Xpace' (PACE extension){{$}}
# CHECK-UNKNOWN: 64058553 <unknown>
pace.pwpa.h fa0, fa1

# CHECK-INST: pace.inv.h fa0, fa1
# CHECK-ENCODING: [0x53,0x95,0x05,0x64]
# CHECK-ERROR: instruction requires the following: 'Xpace' (PACE extension){{$}}
# CHECK-UNKNOWN: 64059553 <unknown>
pace.inv.h fa0, fa1

# CHECK-INST: pace.sqrt.h fa0, fa1
# CHECK-ENCODING: [0x53,0xa5,0x05,0x64]
# CHECK-ERROR: instruction requires the following: 'Xpace' (PACE extension){{$}}
# CHECK-UNKNOWN: 6405a553 <unknown>
pace.sqrt.h fa0, fa1

# CHECK-INST: pace.rsqrt.h fa0, fa1
# CHECK-ENCODING: [0x53,0xb5,0x05,0x64]
# CHECK-ERROR: instruction requires the following: 'Xpace' (PACE extension){{$}}
# CHECK-UNKNOWN: 6405b553 <unknown>
pace.rsqrt.h fa0, fa1

# CHECK-INST: vpace.pwpa.s fa0, fa1, fa2
# CHECK-ENCODING: [0x33,0x85,0xc5,0xe0]
# CHECK-ERROR: instruction requires the following: 'Xpace' (PACE extension){{$}}
# CHECK-UNKNOWN: e0c58533 <unknown>
vpace.pwpa.s fa0, fa1, fa2

# CHECK-INST: vpace.inv.s fa0, fa1, fa2
# CHECK-ENCODING: [0x33,0x85,0xc5,0xe2]
# CHECK-ERROR: instruction requires the following: 'Xpace' (PACE extension){{$}}
# CHECK-UNKNOWN: e2c58533 <unknown>
vpace.inv.s fa0, fa1, fa2

# CHECK-INST: vpace.sqrt.s fa0, fa1, fa2
# CHECK-ENCODING: [0x33,0x85,0xc5,0xe4]
# CHECK-ERROR: instruction requires the following: 'Xpace' (PACE extension){{$}}
# CHECK-UNKNOWN: e4c58533 <unknown>
vpace.sqrt.s fa0, fa1, fa2

# CHECK-INST: vpace.rsqrt.s fa0, fa1, fa2
# CHECK-ENCODING: [0x33,0x85,0xc5,0xe6]
# CHECK-ERROR: instruction requires the following: 'Xpace' (PACE extension){{$}}
# CHECK-UNKNOWN: e6c58533 <unknown>
vpace.rsqrt.s fa0, fa1, fa2

# CHECK-INST: vpace.pwpa.h fa0, fa1, fa2
# CHECK-ENCODING: [0x33,0xa5,0xc5,0xe0]
# CHECK-ERROR: instruction requires the following: 'Xpace' (PACE extension){{$}}
# CHECK-UNKNOWN: e0c5a533 <unknown>
vpace.pwpa.h fa0, fa1, fa2

# CHECK-INST: vpace.inv.h fa0, fa1, fa2
# CHECK-ENCODING: [0x33,0xa5,0xc5,0xe2]
# CHECK-ERROR: instruction requires the following: 'Xpace' (PACE extension){{$}}
# CHECK-UNKNOWN: e2c5a533 <unknown>
vpace.inv.h fa0, fa1, fa2

# CHECK-INST: vpace.sqrt.h fa0, fa1, fa2
# CHECK-ENCODING: [0x33,0xa5,0xc5,0xe4]
# CHECK-ERROR: instruction requires the following: 'Xpace' (PACE extension){{$}}
# CHECK-UNKNOWN: e4c5a533 <unknown>
vpace.sqrt.h fa0, fa1, fa2

# CHECK-INST: vpace.rsqrt.h fa0, fa1, fa2
# CHECK-ENCODING: [0x33,0xa5,0xc5,0xe6]
# CHECK-ERROR: instruction requires the following: 'Xpace' (PACE extension){{$}}
# CHECK-UNKNOWN: e6c5a533 <unknown>
vpace.rsqrt.h fa0, fa1, fa2
