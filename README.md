# Snitch-LLVM

LLVM 12 with extensions for [Snitch](https://github.com/pulp-platform/snitch). These include

- Assembly support for SSR, DMA and FREP extensions
- Intrinsics and `clang` builtins for SSR and DMA extensions
- FREP hardware loops

## Build instructions
Refer to [snitch-toolchain-cd](https://github.com/pulp-platform/snitch-toolchain-cd) for build scripts and continuous deployment of pre-built toolchains.

## Command-line options

| Flag | Description |
|---|---|
| `--mcpu=snitch` | Enables all extensions for Snitch `rv32imafd,xfrep,xssr,xdma` and the Snitch machine model, which is not adapted for Snitch yet |
| `--debug-only=riscv-sdma` | Enable the debug output of the DMA pseudo instruction expansion pass |
| `--debug-only=riscv-ssr` | Enable the debug output of the SSR pseudo instruction expansion pass |
| `--debug-only=snitch-freploops` | Enable the debug output of the FREP loop inference pass |
| `--ssr-noregmerge` | Disable the SSR register merging in the SSR pseudo instruction expansion pass. Register merging is enabled by default and can be disabled with this flag. |
| `--snitch-frep-inference` | Globally enable the FREP inference on all loops in the compiled module. |
| `--enable-misched=false` | Disable the machine instruction scheduler. Instructions in a complex loop with multiple SSR push or pop instructions on the same data mover may not be rescheduled because the order in which the SSR are accessed is important. |

## `clang` builtins
The following `clang` builtins can be used to directly make use of the SSR and DMA extensions.

### SSR

```c
/**
 * @brief Setup 1D SSR read transfer
 * @details rep, b, s are raw values written directly to the SSR registers
 * 
 * @param DM data mover ID
 * @param rep repetition count minus one
 * @param b bound minus one
 * @param s relative stride
 * @param data pointer to data
 */
void __builtin_ssr_setup_1d_r(uint32_t DM, uint32_t rep, uint32_t b, uint32_t s, void* data);

/**
 * @brief Setup 1D SSR write transfer
 * @details rep, b, s are raw values written directly to the SSR registers
 * 
 * @param DM data mover ID
 * @param rep repetition count minus one
 * @param b bound minus one
 * @param s relative stride
 * @param data pointer to data
 */
void __builtin_ssr_setup_1d_w(uint32_t DM, uint32_t rep, uint32_t b, uint32_t s, void* data);

/**
 * @brief Write a datum to an SSR streamer
 * @details Must be within an SSR region
 * 
 * @param DM data mover ID
 * @param val value to write
 */
void __builtin_ssr_push(uint32_t DM, double val);

/**
 * @brief Read a datum from an SSR streamer
 * @details Must be within an SSR region
 * 
 * @param DM data mover ID
 * @return datum fetched from DM
 */
double __builtin_ssr_pop(uint32_t DM);

/**
 * @brief Enable an SSR region
 * @details FT registers are reserved and the push/pop methods can be used to access the SSR
 */
void __builtin_ssr_enable();

/**
 * @brief Disable an SSR region
 * @details FT registers are restored and push/pop is not possible
 */
void __builtin_ssr_disable();

/**
 * @brief Start an SSR read transfer
 * @details Bound and stride can be configured using the respective methods
 * 
 * @param DM data mover ID
 * @param dim Number of dimensions minus one
 * @param data pointer to data
 */
void __builtin_ssr_read(uint32_t DM, uint32_t dim, void* data);

/**
 * @brief Start an SSR write transfer
 * @details Bound and stride can be configured using the respective methods
 * 
 * @param DM data mover ID
 * @param dim Number of dimensions minus one
 * @param data pointer to data
 */
void __builtin_ssr_write(uint32_t DM, uint32_t dim, void* data);

/**
 * @brief Configure repetition value
 * @details A value of 0 loads each datum once
 * 
 * @param DM data mover ID
 * @param rep repetition count minus one
 */
void __builtin_ssr_setup_repetition(uint32_t DM, uint32_t rep);

/**
 * @brief Configure bound and stride for dimension 1
 * @details 
 * 
 * @param DM data mover ID
 * @param b bound minus one
 * @param s relative stride
 */
void __builtin_ssr_setup_bound_stride_1d(uint32_t DM, uint32_t b, uint32_t s);

/**
 * @brief Configure bound and stride for dimension 2
 * @details 
 * 
 * @param DM data mover ID
 * @param b bound minus one
 * @param s relative stride
 */
void __builtin_ssr_setup_bound_stride_2d(uint32_t DM, uint32_t b, uint32_t s);

/**
 * @brief Configure bound and stride for dimension 3
 * @details 
 * 
 * @param DM data mover ID
 * @param b bound minus one
 * @param s relative stride
 */
void __builtin_ssr_setup_bound_stride_3d(uint32_t DM, uint32_t b, uint32_t s);

/**
 * @brief Configure bound and stride for dimension 4
 * @details 
 * 
 * @param DM data mover ID
 * @param b bound minus one
 * @param s relative stride
 */
void __builtin_ssr_setup_bound_stride_4d(uint32_t DM, uint32_t b, uint32_t s);
```

### SDMA

```c
/**
 * @brief Start 1D DMA transfer
 * @details non-blocking call, doesn't check if DMA is ready to accept a new transfer
 * 
 * @param src Pointer to source
 * @param dst Pointer to destination
 * @param size Number of bytes to copy
 * @param cfg DMA configuration word
 * @return transfer ID
 */
uint32_t __builtin_sdma_start_oned(uint64_t src, uint64_t dst, uint32_t size, uint32_t cfg);

/**
 * @brief Start 2D DMA transfer
 * @details non-blocking call, doesn't check if DMA is ready to accept a new transfer
 * 
 * @param src Pointer to source
 * @param dst Pointer to destination
 * @param size Number of bytes in the inner transfer
 * @param sstrd Source stride
 * @param dstrd Destination stride
 * @param nreps Number of repetitions in the outer transfer
 * @param cfg DMA configuration word
 * @return transfer ID
 */
uint32_t __builtin_sdma_start_twod(uint64_t src, uint64_t dst, uint32_t size, 
  uint32_t sstrd, uint32_t dstrd, uint32_t nreps, uint32_t cfg);

/**
 * @brief Read DMA status register
 * @details 
 * 
 * @param tid Transfer ID to check
 * @return status register
 */
uint32_t __builtin_sdma_stat(uint32_t tid);

/**
 * @brief Polling wiat for idle
 * @details Block until all transactions have completed
 */
void __builtin_sdma_wait_for_idle(void);
```

## FREP hardware loops

Inference can be enabled globally with `--snitch-frep-inference` or locally with `#pragma frep infer`.

```c
#pragma frep infer
for(unsigned i = 0; i < 128; ++i)
  acc += __builtin_ssr_pop(0)*__builtin_ssr_pop(1);
```

# The LLVM Compiler Infrastructure

This directory and its sub-directories contain source code for LLVM,
a toolkit for the construction of highly optimized compilers,
optimizers, and run-time environments.

The README briefly describes how to get started with building LLVM.
For more information on how to contribute to the LLVM project, please
take a look at the
[Contributing to LLVM](https://llvm.org/docs/Contributing.html) guide.

## Getting Started with the LLVM System

Taken from https://llvm.org/docs/GettingStarted.html.

### Overview

Welcome to the LLVM project!

The LLVM project has multiple components. The core of the project is
itself called "LLVM". This contains all of the tools, libraries, and header
files needed to process intermediate representations and converts it into
object files.  Tools include an assembler, disassembler, bitcode analyzer, and
bitcode optimizer.  It also contains basic regression tests.

C-like languages use the [Clang](http://clang.llvm.org/) front end.  This
component compiles C, C++, Objective-C, and Objective-C++ code into LLVM bitcode
-- and from there into object files, using LLVM.

Other components include:
the [libc++ C++ standard library](https://libcxx.llvm.org),
the [LLD linker](https://lld.llvm.org), and more.

### Getting the Source Code and Building LLVM

The LLVM Getting Started documentation may be out of date.  The [Clang
Getting Started](http://clang.llvm.org/get_started.html) page might have more
accurate information.

This is an example work-flow and configuration to get and build the LLVM source:

1. Checkout LLVM (including related sub-projects like Clang):

     * ``git clone https://github.com/llvm/llvm-project.git``

     * Or, on windows, ``git clone --config core.autocrlf=false
    https://github.com/llvm/llvm-project.git``

2. Configure and build LLVM and Clang:

     * ``cd llvm-project``

     * ``mkdir build``

     * ``cd build``

     * ``cmake -G <generator> [options] ../llvm``

        Some common build system generators are:

        * ``Ninja`` --- for generating [Ninja](https://ninja-build.org)
          build files. Most llvm developers use Ninja.
        * ``Unix Makefiles`` --- for generating make-compatible parallel makefiles.
        * ``Visual Studio`` --- for generating Visual Studio projects and
          solutions.
        * ``Xcode`` --- for generating Xcode projects.

        Some Common options:

        * ``-DLLVM_ENABLE_PROJECTS='...'`` --- semicolon-separated list of the LLVM
          sub-projects you'd like to additionally build. Can include any of: clang,
          clang-tools-extra, libcxx, libcxxabi, libunwind, lldb, compiler-rt, lld,
          polly, or debuginfo-tests.

          For example, to build LLVM, Clang, libcxx, and libcxxabi, use
          ``-DLLVM_ENABLE_PROJECTS="clang;libcxx;libcxxabi"``.

        * ``-DCMAKE_INSTALL_PREFIX=directory`` --- Specify for *directory* the full
          path name of where you want the LLVM tools and libraries to be installed
          (default ``/usr/local``).

        * ``-DCMAKE_BUILD_TYPE=type`` --- Valid options for *type* are Debug,
          Release, RelWithDebInfo, and MinSizeRel. Default is Debug.

        * ``-DLLVM_ENABLE_ASSERTIONS=On`` --- Compile with assertion checks enabled
          (default is Yes for Debug builds, No for all other build types).

      * ``cmake --build . [-- [options] <target>]`` or your build system specified above
        directly.

        * The default target (i.e. ``ninja`` or ``make``) will build all of LLVM.

        * The ``check-all`` target (i.e. ``ninja check-all``) will run the
          regression tests to ensure everything is in working order.

        * CMake will generate targets for each tool and library, and most
          LLVM sub-projects generate their own ``check-<project>`` target.

        * Running a serial build will be **slow**.  To improve speed, try running a
          parallel build.  That's done by default in Ninja; for ``make``, use the option
          ``-j NNN``, where ``NNN`` is the number of parallel jobs, e.g. the number of
          CPUs you have.

      * For more information see [CMake](https://llvm.org/docs/CMake.html)

Consult the
[Getting Started with LLVM](https://llvm.org/docs/GettingStarted.html#getting-started-with-llvm)
page for detailed information on configuring and compiling LLVM. You can visit
[Directory Layout](https://llvm.org/docs/GettingStarted.html#directory-layout)
to learn about the layout of the source code tree.
