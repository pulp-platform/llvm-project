; RUN: llc -march=riscv32 -mattr=+xpulpv -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -march=riscv32 -mattr=+xpulppostmod -verify-machineinstrs < %s | FileCheck %s

declare i32 @llvm.riscv.pulp.OffsetedRead(i32*, i32)
define i32 @test_llvm_riscv_pulp_OffsetedRead(i32* %data) {
; CHECK-LABEL: @test_llvm_riscv_pulp_OffsetedRead
; CHECK:       # %bb.0:
; CHECK:         li [[OFFSET:a[0-9]+]], 4
; CHECK:         p.lw [[PTR:a[0-9]+]], [[OFFSET]]([[PTR]])
;
  %1 = call i32 @llvm.riscv.pulp.OffsetedRead(i32* %data, i32 4)
  ret i32 %1
}

declare void @llvm.riscv.pulp.OffsetedWrite(i32, i32*, i32)
define void @test_llvm_riscv_pulp_OffsetedWrite(i32* %data) {
; CHECK-LABEL: @test_llvm_riscv_pulp_OffsetedWrite
; CHECK:       # %bb.0:
; CHECK-DAG:     li [[OFFSET:a[0-9]+]],  4
; CHECK-DAG:     li [[VALUE:a[0-9]+]],  1
; CHECK:         p.sw [[VALUE]], [[OFFSET]]({{a[0-9]+}})
;
  call void @llvm.riscv.pulp.OffsetedWrite(i32 1, i32* %data, i32 4)
  ret void
}

declare i32 @llvm.riscv.pulp.OffsetedReadHalf(i16*, i32)
define i32 @test_llvm_riscv_pulp_OffsetedReadHalf(i16* %data) {
; CHECK-LABEL: @test_llvm_riscv_pulp_OffsetedReadHalf
; CHECK:       # %bb.0:
; CHECK:         li [[OFFSET:a[0-9]+]], 4
; CHECK:         p.lh [[PTR:a[0-9]+]], [[OFFSET]]([[PTR]])
;
  %1 = call i32 @llvm.riscv.pulp.OffsetedReadHalf(i16* %data, i32 4)
  ret i32 %1
}

declare void @llvm.riscv.pulp.OffsetedWriteHalf(i32, i16*, i32)
define void @test_llvm_riscv_pulp_OffsetedWriteHalf(i16* %data) {
; CHECK-LABEL: @test_llvm_riscv_pulp_OffsetedWriteHalf
; CHECK:       # %bb.0:
; CHECK-DAG:     li [[OFFSET:a[0-9]+]],  4
; CHECK-DAG:     li [[VALUE:a[0-9]+]],  1
; CHECK:         p.sh [[VALUE]], [[OFFSET]]({{a[0-9]+}})
;
  call void @llvm.riscv.pulp.OffsetedWriteHalf(i32 1, i16* %data, i32 4)
  ret void
}

declare i32 @llvm.riscv.pulp.OffsetedReadByte(i8*, i32)
define i32 @test_llvm_riscv_pulp_OffsetedReadByte(i8* %data) {
; CHECK-LABEL: @test_llvm_riscv_pulp_OffsetedReadByte
; CHECK:       # %bb.0:
; CHECK:         li [[OFFSET:a[0-9]+]], 4
; CHECK:         p.lb [[PTR:a[0-9]+]], [[OFFSET]]([[PTR]])
;
  %1 = call i32 @llvm.riscv.pulp.OffsetedReadByte(i8* %data, i32 4)
  ret i32 %1
}

declare void @llvm.riscv.pulp.OffsetedWriteByte(i32, i8*, i32)
define void @test_llvm_riscv_pulp_OffsetedWriteByte(i8* %data) {
; CHECK-LABEL: @test_llvm_riscv_pulp_OffsetedWriteByte
; CHECK:       # %bb.0:
; CHECK-DAG:     li [[OFFSET:a[0-9]+]],  4
; CHECK-DAG:     li [[VALUE:a[0-9]+]],  1
; CHECK:         p.sb [[VALUE]], [[OFFSET]]({{a[0-9]+}})
;
  call void @llvm.riscv.pulp.OffsetedWriteByte(i32 1, i8* %data, i32 4)
  ret void
}

declare i32 @llvm.riscv.pulp.read.base.off(i32* %data, i32)
define i32 @test_llvm_riscv_pulp_read_base_off(i32* %data) {
; CHECK-LABEL: @test_llvm_riscv_pulp_read_base_off
; CHECK:       # %bb.0:
; CHECK:         li [[OFFSET:a[0-9]+]], 15
; CHECK:         p.lw [[PTR:a[0-9]+]], [[OFFSET]]([[PTR]])
;
  %1 = call i32 @llvm.riscv.pulp.read.base.off(i32* %data, i32 15)
  ret i32 %1
}

declare void @llvm.riscv.pulp.write.base.off(i32, i32*, i32)
define void @test_llvm_riscv_pulp_write_base_off(i32* %data) {
; CHECK-LABEL: @test_llvm_riscv_pulp_write_base_off
; CHECK:       # %bb.0:
; CHECK-DAG:     li [[OFFSET:a[0-9]+]], 15
; CHECK-DAG:     li [[VALUE:a[0-9]+]],  1
; CHECK:         p.sw [[VALUE]], [[OFFSET]]({{a[0-9]+}})
;
  call void @llvm.riscv.pulp.write.base.off(i32 1, i32* %data, i32 15)
  ret void
}
