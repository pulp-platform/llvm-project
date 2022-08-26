//===--- HeroPULP.h - Hero PULP ToolChain Implementations -------*- C++ -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_CLANG_LIB_DRIVER_TOOLCHAINS_HERO_PULP_H
#define LLVM_CLANG_LIB_DRIVER_TOOLCHAINS_HERO_PULP_H

#include <string>

#include "Gnu.h"
#include "clang/Driver/ToolChain.h"

namespace clang {
namespace driver {
namespace toolchains {

class LLVM_LIBRARY_VISIBILITY HeroPULPToolChain : public Generic_ELF {
public:
  HeroPULPToolChain(const Driver &D, const llvm::Triple &Triple,
                   const llvm::opt::ArgList &Args);

  bool IsIntegratedAssemblerDefault() const override { return true; }
  void addClangTargetOptions(const llvm::opt::ArgList &DriverArgs,
                             llvm::opt::ArgStringList &CC1Args,
                             Action::OffloadKind) const override;
  void
  AddClangSystemIncludeArgs(const llvm::opt::ArgList &DriverArgs,
                            llvm::opt::ArgStringList &CC1Args) const override;
  void
  addLibStdCxxIncludePaths(const llvm::opt::ArgList &DriverArgs,
                           llvm::opt::ArgStringList &CC1Args) const override {};

  virtual llvm::opt::DerivedArgList *
   TranslateArgs(const llvm::opt::DerivedArgList &Args, StringRef BoundArch,
                 Action::OffloadKind DeviceOffloadKind) const override;

protected:
  Tool *buildLinker() const override;

private:
  std::string computeSysRoot() const override;
};

} // end namespace toolchains

namespace tools {
namespace HeroPULP {
class LLVM_LIBRARY_VISIBILITY Linker : public Tool {
public:
  Linker(const ToolChain &TC);
  bool hasIntegratedCPP() const override { return false; }
  bool isLinkJob() const override { return true; }
  void ConstructJob(Compilation &C, const JobAction &JA,
                    const InputInfo &Output, const InputInfoList &Inputs,
                    const llvm::opt::ArgList &TCArgs,
                    const char *LinkingOutput) const override;

private:
  std::string PulpSdkInstallDir;
};
} // end namespace HeroPULP
} // end namespace tools

} // end namespace driver
} // end namespace clang

#endif // LLVM_CLANG_LIB_DRIVER_TOOLCHAINS_BIGPULP_H
