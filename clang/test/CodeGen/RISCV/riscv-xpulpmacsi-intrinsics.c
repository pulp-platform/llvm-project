// REQUIRES: riscv-registered-target
// Performing the same checks for each possible way to invoke clang
// for PULP extensions:
// 1. cc1 with unversioned group extension (+xpulpv instead of +xpulpv2)
// RUN: %clang_cc1 -triple riscv32 -target-feature +xpulpv -emit-llvm %s -o - \
// RUN:     | FileCheck %s
// 2. clang with versioned group extension
// RUN: %clang --target=riscv32 -march=rv32imafcxpulpv2 -c -S -emit-llvm %s -o - \
// RUN:     | FileCheck %s
// 3. clang with specific extension
// RUN: %clang --target=riscv32 -march=rv32imafcxpulpmacsi -c -S -emit-llvm %s -o - \
// RUN:     | FileCheck %s
// 4. clang with a platform triple that is expected to provide PULP extensions
// RUN: %clang --target=riscv32-hero-unknown-elf -c -S -emit-llvm %s -o - \
// RUN:     | FileCheck %s

#include <stdint.h>

typedef int16_t  v2s __attribute__((vector_size(4)));
typedef uint16_t v2u __attribute__((vector_size(4)));
typedef int8_t   v4s __attribute__((vector_size(4)));
typedef uint8_t  v4u __attribute__((vector_size(4)));

// CHECK-LABEL: @test_builtin_pulp_mac(
// CHECK-NEXT:  entry:
// CHECK-NEXT:    [[RES:%.*]] = call i32 @llvm.riscv.pulp.mac(i32 1, i32 2, i32 3)
// CHECK-NEXT:    ret i32 [[RES]]
int32_t test_builtin_pulp_mac(void) {
  return __builtin_pulp_mac(1, 2, 3);
}

// CHECK-LABEL: @test_builtin_pulp_msu(
// CHECK-NEXT:  entry:
// CHECK-NEXT:    [[RES:%.*]] = call i32 @llvm.riscv.pulp.msu(i32 1, i32 2, i32 10)
// CHECK-NEXT:    ret i32 [[RES]]
//
int32_t test_builtin_pulp_msu(void) {
  return __builtin_pulp_msu(1, 2, 10);
}
