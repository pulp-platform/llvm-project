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
// RUN: %clang --target=riscv32 -march=rv32imafcxpulppostmod -c -S -emit-llvm %s -o - \
// RUN:     | FileCheck %s
// 4. clang with a platform triple that is expected to provide PULP extensions
// RUN: %clang --target=riscv32-hero-unknown-elf -c -S -emit-llvm %s -o - \
// RUN:     | FileCheck %s

#include <stdint.h>

// CHECK-LABEL: @test_builtin_pulp_OffsetedRead(
// CHECK:         [[PTR:%.*]] = load i32*, i32** %data.addr, align 4
// CHECK:         [[RES:%.*]] = call i32 @llvm.riscv.pulp.OffsetedRead(i32* [[PTR]], i32 4)
//
int32_t test_builtin_pulp_OffsetedRead(int32_t *data) {
  return __builtin_pulp_OffsetedRead(data, 4);
}

// CHECK-LABEL: @test_builtin_pulp_OffsetedWrite(
// CHECK:         [[PTR:%.*]] = load i32*, i32** %data.addr, align 4
// CHECK:         call void @llvm.riscv.pulp.OffsetedWrite(i32 1, i32* [[PTR]], i32 4)
//
void test_builtin_pulp_OffsetedWrite(int32_t *data) {
  __builtin_pulp_OffsetedWrite(1, data, 4);
}

// CHECK-LABEL: @test_builtin_pulp_OffsetedReadHalf(
// CHECK:         [[PTR:%.*]] = load i16*, i16** %data.addr, align 4
// CHECK:         [[RES:%.*]] = call i32 @llvm.riscv.pulp.OffsetedReadHalf(i16* [[PTR]], i32 4)
//
int16_t test_builtin_pulp_OffsetedReadHalf(int16_t *data) {
  return __builtin_pulp_OffsetedReadHalf(data, 4);
}

// CHECK-LABEL: @test_builtin_pulp_OffsetedWriteHalf(
// CHECK:         [[PTR:%.*]] = load i16*, i16** %data.addr, align 4
// CHECK:         call void @llvm.riscv.pulp.OffsetedWriteHalf(i32 1, i16* [[PTR]], i32 4)
//
void test_builtin_pulp_OffsetedWriteHalf(int16_t *data) {
  __builtin_pulp_OffsetedWriteHalf(1, data, 4);
}

// CHECK-LABEL: @test_builtin_pulp_OffsetedReadByte(
// CHECK:         [[PTR:%.*]] = load i8*, i8** %data.addr, align 4
// CHECK:         [[RES:%.*]] = call i32 @llvm.riscv.pulp.OffsetedReadByte(i8* [[PTR]], i32 4)
//
char test_builtin_pulp_OffsetedReadByte(char *data) {
  return __builtin_pulp_OffsetedReadByte(data, 4);
}

// CHECK-LABEL: @test_builtin_pulp_OffsetedWriteByte(
// CHECK:         [[PTR:%.*]] = load i8*, i8** %data.addr, align 4
// CHECK:         call void @llvm.riscv.pulp.OffsetedWriteByte(i32 1, i8* [[PTR]], i32 4)
//
void test_builtin_pulp_OffsetedWriteByte(char *data) {
  __builtin_pulp_OffsetedWriteByte(1, data, 4);
}

// CHECK-LABEL: @test_builtin_pulp_read_base_off(
// CHECK:         [[PTR:%.*]] = load i32*, i32** %data.addr, align 4
// CHECK:         call i32 @llvm.riscv.pulp.read.base.off(i32* [[PTR]], i32 15)
//
int32_t test_builtin_pulp_read_base_off(int32_t* data) {
  return __builtin_pulp_read_base_off(data, 0xF);
}

// CHECK-LABEL: @test_builtin_pulp_write_base_off(
// CHECK:         [[PTR:%.*]] = load i32*, i32** %data.addr, align 4
// CHECK:         call void @llvm.riscv.pulp.write.base.off(i32 1, i32* [[PTR]], i32 15)
//
void test_builtin_pulp_write_base_off(int32_t* data) {
  __builtin_pulp_write_base_off(0x1, data, 0xF);
}
