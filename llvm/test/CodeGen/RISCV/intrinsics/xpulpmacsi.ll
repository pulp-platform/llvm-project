; RUN: llc -march=riscv32 -mattr=+xpulpv -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -march=riscv32 -mattr=+xpulpmacsi -verify-machineinstrs < %s | FileCheck %s

declare i32 @llvm.riscv.pulp.mac(i32, i32, i32)
define i32 @test_llvm_riscv_pulp_mac() {
; CHECK-LABEL: test_llvm_riscv_pulp_mac:
; CHECK:       # %bb.0:
; CHECK-DAG:     li [[REG0:a[0-9]+]], 1
; CHECK-DAG:     li [[REG1:a[0-9]+]], 2
; CHECK-DAG:     li [[REG2:a[0-9]+]], 3
; CHECK-NEXT:    p.mac [[REG2]], [[REG0]], [[REG1]]
;
  %1 = tail call i32 @llvm.riscv.pulp.mac(i32 1, i32 2, i32 3)
  ret i32 %1
}

declare i32 @llvm.riscv.pulp.msu(i32, i32, i32)
define i32 @test_llvm_riscv_pulp_msu() {
; CHECK-LABEL: @test_llvm_riscv_pulp_msu
; CHECK:       # %bb.0:
; CHECK-DAG:     li [[REG0:a[0-9]+]],  1
; CHECK-DAG:     li [[REG1:a[0-9]+]],  2
; CHECK-DAG:     li [[REG2:a[0-9]+]], 10
; CHECK-NEXT:    p.msu [[REG2]], [[REG0]], [[REG1]]
;
  %1 = call i32 @llvm.riscv.pulp.msu(i32 1, i32 2, i32 10)
  ret i32 %1
}
