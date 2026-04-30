#!/bin/bash -xe

# Copyright 2022 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

echo ${BUGURL}
echo ${PKGVERS}

# Build settings
if [ "x${CCACHE_BUILD}" != "x" ]; then
  CCACHE_BUILD=False # does currently not work in docker
fi

# Pointers to install, build and source directories
INSTALLPREFIX=${PWD}/install
BUILDPREFIX=${PWD}/build
LLVMSRC=${PWD}/llvm-project
NEWLIBSRC=${PWD}/newlib

# If a BUGURL and PKGVERS has been provided, set variables
NEWLIB_EXTRA_OPTS=""
LLVM_EXTRA_OPTS=""
if [ "x${BUGURL}" != "x" ]; then
  NEWLIB_EXTRA_OPTS="${NEWLIB_EXTRA_OPTS} --with-bugurl='${BUGURL}'"
  LLVM_EXTRA_OPTS="${LLVM_EXTRA_OPTS} -DPACKAGE_BUGREPORT='${BUGURL}'"
fi
if [ "x${PKGVERS}" != "x" ]; then
  NEWLIB_EXTRA_OPTS="${NEWLIB_EXTRA_OPTS} --with-pkgversion='${PKGVERS}'"
fi
if [ "x${BUILDNO}" != "x" ]; then
  LLVM_EXTRA_OPTS="${LLVM_EXTRA_OPTS} -DLLVM_VERSION_SUFFIX='-${BUILDNO}'"
fi

# cxx from variable or system
if [ "x${CC}" == "x" ]; then CC=`which gcc`; fi
if [ "x${CXX}" == "x" ]; then CXX=`which g++`; fi
echo $CC
echo $CXX

# Allow environment to control parallelism
if [ "x${PARALLEL_JOBS}" == "x" ]; then
  PARALLEL_JOBS=$(nproc)
fi

# Clone newlib
rm -rf ${NEWLIBSRC}
git clone --depth 1 -b newlib-4.4.0 https://sourceware.org/git/newlib-cygwin.git ${NEWLIBSRC}
ls -al

##############################
# Clang/LLVM
##############################
mkdir -p ${BUILDPREFIX}/llvm
cd ${BUILDPREFIX}/llvm
cmake \
    -DCMAKE_BUILD_TYPE="Release" \
    -DCMAKE_INSTALL_PREFIX=${INSTALLPREFIX} \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DLLVM_CCACHE_BUILD=${CCACHE_BUILD} \
    -DLLVM_TARGETS_TO_BUILD="RISCV" \
    -DLLVM_DEFAULT_TARGET_TRIPLE="riscv32-unknown-elf" \
    -DLLVM_OPTIMIZED_TABLEGEN=True \
    -DCMAKE_C_COMPILER=$CC \
    -DCMAKE_CXX_COMPILER=$CXX \
    ${LLVM_EXTRA_OPTS} \
    -G Ninja ${LLVMSRC}/llvm
ninja -j ${PARALLEL_JOBS}
ninja install

##############################
# from here on, use the new built toolchain
##############################

PATH=${INSTALLPREFIX}/bin:${PATH}

##############################
# newlib
##############################

# Build newlib for rv32
mkdir -p ${BUILDPREFIX}/newlib32
cd ${BUILDPREFIX}/newlib32
# CFLAGS_FOR_TARGET="-DPREFER_SIZE_OVER_SPEED=1 -Os" \
${NEWLIBSRC}/configure                                 \
    --target=riscv32-unknown-elf                       \
    --prefix=${INSTALLPREFIX}                          \
    AR_FOR_TARGET=${INSTALLPREFIX}/bin/llvm-ar         \
    AS_FOR_TARGET=${INSTALLPREFIX}/bin/llvm-as         \
    LD_FOR_TARGET=${INSTALLPREFIX}/bin/llvm-ld         \
    RANLIB_FOR_TARGET=${INSTALLPREFIX}/bin/llvm-ranlib \
    CC_FOR_TARGET="${INSTALLPREFIX}/bin/clang --target=riscv32 -march=rv32imafd \
    #  -mno-fdiv" \
    ${NEWLIB_EXTRA_OPTS}                             
    # --enable-multilib                              \
    # --disable-newlib-fvwrite-in-streamio           \
    # --disable-newlib-fseek-optimization            \
    # --enable-newlib-nano-malloc                    \
    # --disable-newlib-unbuf-stream-opt              \
    # --enable-target-optspace                       \
    # --enable-newlib-reent-small                    \
    # --disable-newlib-wide-orient                   \
    # --disable-newlib-io-float                      \
    # --enable-newlib-nano-formatted-io              \
make -j${PARALLEL_JOBS}
make install

##############################
# compiler-rt
##############################
mkdir -p ${BUILDPREFIX}/compiler-rt32
cd ${BUILDPREFIX}/compiler-rt32
# NOTE: CMAKE_SYSTEM_NAME is set to linux to allow the configure step to
#       correctly validate that clang works for cross compiling
cmake -G"Unix Makefiles"                                                     \
    -DCMAKE_SYSTEM_NAME=Linux                                                \
    -DCMAKE_INSTALL_PREFIX=$(${INSTALLPREFIX}/bin/clang -print-resource-dir) \
    -DCMAKE_C_COMPILER=${INSTALLPREFIX}/bin/clang                            \
    -DCMAKE_CXX_COMPILER=${INSTALLPREFIX}/bin/clang                          \
    -DCMAKE_AR=${INSTALLPREFIX}/bin/llvm-ar                                  \
    -DCMAKE_NM=${INSTALLPREFIX}/bin/llvm-nm                                  \
    -DCMAKE_RANLIB=${INSTALLPREFIX}/bin/llvm-ranlib                          \
    -DCMAKE_C_COMPILER_TARGET="riscv32-unknown-elf"                          \
    -DCMAKE_CXX_COMPILER_TARGET="riscv32-unknown-elf"                        \
    -DCMAKE_ASM_COMPILER_TARGET="riscv32-unknown-elf"                        \
    -DCMAKE_C_FLAGS="-march=rv32imafd -mabi=ilp32d"                          \
    -DCMAKE_CXX_FLAGS="-march=rv32imafd -mabi=ilp32d"                        \
    -DCMAKE_ASM_FLAGS="-march=rv32imafd -mabi=ilp32d"                        \
    -DCMAKE_EXE_LINKER_FLAGS="-nostartfiles -nostdlib -fuse-ld=lld"          \
    -DCOMPILER_RT_BAREMETAL_BUILD=ON                                         \
    -DCOMPILER_RT_BUILD_BUILTINS=ON                                          \
    -DCOMPILER_RT_BUILD_MEMPROF=OFF                                          \
    -DCOMPILER_RT_BUILD_LIBFUZZER=OFF                                        \
    -DCOMPILER_RT_BUILD_PROFILE=OFF                                          \
    -DCOMPILER_RT_BUILD_SANITIZERS=OFF                                       \
    -DCOMPILER_RT_BUILD_XRAY=OFF                                             \
    -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON                                     \
    -DCOMPILER_RT_OS_DIR="riscv32-unknown-unknown-elf"                       \
    -DLLVM_CONFIG_PATH=${BUILDPREFIX}/llvm/bin/llvm-config                   \
    ../../llvm-project/compiler-rt
make -j${PARALLEL_JOBS}
make install

# LLVM 22.x expects libclang_rt.builtins.a (no arch suffix) inside the
# per-triple directory, but cmake installs it as libclang_rt.builtins-riscv32.a.
RT_DIR="$(${INSTALLPREFIX}/bin/clang --target=riscv32-unknown-elf -print-runtime-dir)"
ln -sf libclang_rt.builtins-riscv32.a "${RT_DIR}/libclang_rt.builtins.a"
