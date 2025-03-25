add_llvm_component_library(LLVMSSR
  SSRInference.cpp
  SSRGeneration.cpp

  DEPENDS
  intrinsics_gen

  LINK_COMPONENTS
  Core
  Support
  )
