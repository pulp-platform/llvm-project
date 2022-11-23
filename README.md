# LLVM for PULP Platform Projects

LLVM 12 with extensions for processors and computer systems of the [PULP platform](https://pulp-platform.org).  These include:
- MemPool: Instruction scheduling model for the MemPool architecture; `Xmempool` extension to allow dynamic instruction tracing;
- [PULPv2 RISC-V ISA extension (`Xpulpv2`)][hero]: automatic insertion of hardware loops, post-increment memory accesses, and multiply-accumulates; intrinsics, `clang` builtins , and assembly support for all instructions of the extension;
- [Snitch RISC-V ISA extensions (`Xssr`, `Xfrep`, and `Xdma`)][snitch]: automatic insertion of `frep` hardware loops; intrinsics and `clang` builtins for `Xssr` and `Xdma` extensions; assembly support for all instructions of the extension. NEW: automatic SSR inference.

# Snitch RISC-V ISA Extension Support

## Build instructions
Refer to [snitch-toolchain-cd](https://github.com/pulp-platform/snitch-toolchain-cd) for build scripts and continuous deployment of pre-built toolchains.

## Command-line options
Note that flags that are passed to LLVM through `clang` need to be prefaced with `-mllvm` (use `"SHELL:-mllvm <flag>"` in CMake to prevent removal of repeated `-mllvm`s).

| Flag | Description |
|---|---|
| `--mcpu=snitch` | Enables all extensions for Snitch `rv32imafd,xfrep,xssr,xdma` and the Snitch machine model, which is not adapted for Snitch yet |
| `--debug-only=riscv-sdma` | Enable the debug output of the DMA pseudo instruction expansion pass |
| `--debug-only=riscv-ssr` | Enable the debug output of the SSR pseudo instruction expansion pass |
| `--debug-only=snitch-freploops` | Enable the debug output of the FREP loop inference pass |
| `--snitch-frep-inference` | Globally enable the FREP inference on all loops in the compiled module. |
| `-infer-ssr` | Enable automatic inference of SSR streams. |
| `-ssr-no-intersect-check` | Do not generate intersection checks (unsafe). Use `restrict` key-word instead if possible. |
| `-ssr-no-tcdm-check` | Assume all data of inferred streams is inside TCDM. |
| `-ssr-no-bound-check` | Do not generate checks that make sure the inferred stream's access is executed at least once. |
| `-ssr-conflict-free-only` | Only infer streams if they have no conflicts with other memory accesses. |
| `-ssr-no-inline` | Prevent functions that contain SSR streams from being inlined |
| `-ssr-barrier` | Enable the insertion of a spinning loop that waits for the stream to be done before it is disabled. |
| `-ssr-verbose` | Write information about inferred streams to `stderr`. |

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
 * @brief Start an SSR read transfer. `DM` and `dim` must be constant. This method 
 * lowers to a single `scfgwi` instruction as opposed to the non-immediate version which
 * does address calculation first.
 * @details Bound and stride can be configured using the respective methods
 * 
 * @param DM data mover ID
 * @param dim Number of dimensions minus one
 * @param data pointer to data
 */
void __builtin_ssr_read_imm(uint32_t DM, uint32_t dim, void* data);

/**
 * @brief Start an SSR write transfer. `DM` and `dim` must be constant. This method 
 * lowers to a single `scfgwi` instruction as opposed to the non-immediate version which
 * does address calculation first.
 * @details Bound and stride can be configured using the respective methods
 * 
 * @param DM data mover ID
 * @param dim Number of dimensions minus one
 * @param data pointer to data
 */
void __builtin_ssr_write_imm(uint32_t DM, uint32_t dim, void* data);

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

/**
 * @brief Wait for the done bit to be set on data mover `DM`
 * @details Creates a polling loop and might not exit if SSR not configured correctly
 * 
 * @param DM data mover ID
 */
void __builtin_ssr_barrier(uint32_t DM);
```

#### SSR Inference Interoperability
Automatic SSR infernce will not infer any streams in an `ssr_enable` to `ssr_disable` region. 
Note that SSR inference currently treats any inline asm block as if it would contain an SSR instruction. Thus it will not infer streams in any loop nests that contain inline asm somewhere.


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

__For `frep` inference to work, `clang` must be invoked with at least `-O1`__

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
files needed to process intermediate representations and convert them into
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

     * ``cmake -S llvm -B build -G <generator> [options]``

        Some common build system generators are:

        * ``Ninja`` --- for generating [Ninja](https://ninja-build.org)
          build files. Most llvm developers use Ninja.
        * ``Unix Makefiles`` --- for generating make-compatible parallel makefiles.
        * ``Visual Studio`` --- for generating Visual Studio projects and
          solutions.
        * ``Xcode`` --- for generating Xcode projects.

        Some common options:

        * ``-DLLVM_ENABLE_PROJECTS='...'`` and ``-DLLVM_ENABLE_RUNTIMES='...'`` ---
          semicolon-separated list of the LLVM sub-projects and runtimes you'd like to
          additionally build. ``LLVM_ENABLE_PROJECTS`` can include any of: clang,
          clang-tools-extra, cross-project-tests, flang, libc, libclc, lld, lldb,
          mlir, openmp, polly, or pstl. ``LLVM_ENABLE_RUNTIMES`` can include any of
          libcxx, libcxxabi, libunwind, compiler-rt, libc or openmp. Some runtime
          projects can be specified either in ``LLVM_ENABLE_PROJECTS`` or in
          ``LLVM_ENABLE_RUNTIMES``.

          For example, to build LLVM, Clang, libcxx, and libcxxabi, use
          ``-DLLVM_ENABLE_PROJECTS="clang" -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi"``.

        * ``-DCMAKE_INSTALL_PREFIX=directory`` --- Specify for *directory* the full
          path name of where you want the LLVM tools and libraries to be installed
          (default ``/usr/local``). Be careful if you install runtime libraries: if
          your system uses those provided by LLVM (like libc++ or libc++abi), you
          must not overwrite your system's copy of those libraries, since that
          could render your system unusable. In general, using something like
          ``/usr`` is not advised, but ``/usr/local`` is fine.

        * ``-DCMAKE_BUILD_TYPE=type`` --- Valid options for *type* are Debug,
          Release, RelWithDebInfo, and MinSizeRel. Default is Debug.

        * ``-DLLVM_ENABLE_ASSERTIONS=On`` --- Compile with assertion checks enabled
          (default is Yes for Debug builds, No for all other build types).

      * ``cmake --build build [-- [options] <target>]`` or your build system specified above
        directly.

        * The default target (i.e. ``ninja`` or ``make``) will build all of LLVM.

        * The ``check-all`` target (i.e. ``ninja check-all``) will run the
          regression tests to ensure everything is in working order.

        * CMake will generate targets for each tool and library, and most
          LLVM sub-projects generate their own ``check-<project>`` target.

        * Running a serial build will be **slow**.  To improve speed, try running a
          parallel build.  That's done by default in Ninja; for ``make``, use the option
          ``-j NNN``, where ``NNN`` is the number of parallel jobs to run.
          In most cases, you get the best performance if you specify the number of CPU threads you have.
          On some Unix systems, you can specify this with ``-j$(nproc)``.

      * For more information see [CMake](https://llvm.org/docs/CMake.html)

Consult the
[Getting Started with LLVM](https://llvm.org/docs/GettingStarted.html#getting-started-with-llvm)
page for detailed information on configuring and compiling LLVM. You can visit
[Directory Layout](https://llvm.org/docs/GettingStarted.html#directory-layout)
to learn about the layout of the source code tree.

## Getting in touch

Join [LLVM Discourse forums](https://discourse.llvm.org/), [discord chat](https://discord.gg/xS7Z362) or #llvm IRC channel on [OFTC](https://oftc.net/).

The LLVM project has adopted a [code of conduct](https://llvm.org/docs/CodeOfConduct.html) for
participants to all modes of communication within the project.
