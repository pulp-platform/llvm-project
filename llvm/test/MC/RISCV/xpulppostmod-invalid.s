# Xpulppostmod - PULP post-incrementing and register-register loads/stores
# RUN: not llvm-mc -triple riscv32 -mattr=+xpulppostmod < %s 2>&1 \
# RUN:     | FileCheck -check-prefixes=CHECK %s
# RUN: not llvm-mc -triple riscv32 -mattr=-xpulppostmod < %s 2>&1 \
# RUN:     | FileCheck -check-prefixes=CHECK-EXT %s

# CHECK: :[[@LINE+1]]:23: error: operand must be a symbol with %lo/%pcrel_lo/%tprel_lo specifier or an integer in the range [-2048, 2047]
p.lw.irpost a0, (a1), 2048

# CHECK: :[[@LINE+1]]:23: error: operand must be a symbol with %lo/%pcrel_lo/%tprel_lo specifier or an integer in the range [-2048, 2047]
p.sw.irpost a0, (a1), -2049

# CHECK: :[[@LINE+1]]:17: error: invalid operand for instruction
p.lw.irpost a0, 4(a1)

# CHECK: :[[@LINE+1]]:13: error: invalid operand for instruction
p.lw.rr a0, (a1), a2

# CHECK-EXT: :[[@LINE+1]]:1: error: instruction requires the following: 'Xpulppostmod' (Xpulp extension subset: post-incrementing load & store operations and register-register loads & store operations)
p.lw.irpost a0, (a1), 4
