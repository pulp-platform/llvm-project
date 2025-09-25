//===- RISCVSystemOperandsSnitch.td ------------------------------*- tablegen -*-===//
//
// Copyright 2021 ETH Zurich, University of Bologna.
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines the symbolic operands permitted for various kinds of
// RISC-V system instruction in Snitch.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Custom CSRs
//===----------------------------------------------------------------------===//
def : SysReg<"ssr", 0x7C0>;
def : SysReg<"fpmode", 0x7C1>;
def : SysReg<"barrier", 0x7C2>;
def : SysReg<"sc", 0x7C3>;
def : SysReg<"user_low", 0x7C4>;
def : SysReg<"user_high", 0x7C5>;
