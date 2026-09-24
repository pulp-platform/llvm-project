# Xdma - PULP Asynchronous Data Movement Extension
# RUN: not llvm-mc -triple riscv32 -mattr=+xdma < %s 2>&1 \
# RUN:     | FileCheck -check-prefixes=CHECK %s
# RUN: not llvm-mc -triple riscv32 -mattr=-xdma < %s 2>&1 \
# RUN:     | FileCheck -check-prefixes=CHECK-EXT %s

# CHECK: :[[@LINE+1]]:1: error: too few operands for instruction
dmopc a0

# CHECK: :[[@LINE+1]]:11: error: invalid operand for instruction
dmopc a0, 1

# CHECK: :[[@LINE+1]]:15: error: invalid operand for instruction
dmopc a0, a1, a2

# CHECK-EXT: :[[@LINE+1]]:1: error: instruction requires the following: 'Xdma' (Asynchronous Data Movement extension)
dmopc a0, a1
