##===----------------------------------------------------------------------===##
#
#                   Not the LLVM Compiler Infrastructure
#
# This file is dual licensed under the MIT and the University of Illinois Open
# Source Licenses. See LICENSE.txt for details.
#
##===----------------------------------------------------------------------===##
#
# Build a plugin for a HERO accelerator.
#
##===----------------------------------------------------------------------===##
set(LIBOMPTARGET_HERO_BUILD OFF CACHE BOOL
  "Should the HERO offloading plugin be built")
if(NOT LIBOMPTARGET_HERO_BUILD)
  libomptarget_say("Not building HERO offloading plugin: build disabled.")
  return()
endif()

if(NOT EXISTS $ENV{HERO_DEV_INC_DIR}/libhero/host/hero_api.h)
  libomptarget_say("Not building HERO offloading plugin: HERO device SDK not found (HERO_DEV_INC_DIR to the correct path)")
  return()
endif()
libomptarget_say("Building HERO offloading plugin.")

# Define the suffix for the runtime messaging dumps.
add_definitions(-DTARGET_NAME=HERO)
set(CMAKE_CXX_FLAGS "-fpermissive")
#set(CMAKE_CXX_FLAGS "-fms-extensions -Wno-error=reserved-user-defined-literal")

# set flags (FIXME: include with idirafter to prevent problems with using accelerator definitions of herodev.h)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} $ENV{LIBGOMP_PLUGIN_HERO_DEV_CPPFLAGS} -lpthread -idirafter $ENV{HERO_DEV_INC_DIR}")
set(CMAKE_LD_FLAGS "${CMAKE_LD_FLAGS} $ENV{LIBGOMP_PLUGIN_HERO_DEV_LDFLAGS} -lpthread")

if(EXISTS $ENV{HERO_LIBHERODEV_DIR}/inc/herodev.h)
  include_directories($ENV{HERO_LIBHERODEV_DIR}/inc)
endif()

include_directories(${LIBOMPTARGET_DEP_LIBFFI_INCLUDE_DIR})
include_directories(${LIBOMPTARGET_DEP_LIBELF_INCLUDE_DIR})

if(LIBOMPTARGET_ENABLE_PREM)
  add_definitions(-DPREM_MODE)
endif()


if(LIBOMPTARGET_HERO_DEV_TYPE STREQUAL "")
  message(FATAL_ERROR "No device chosen for Hero (LIBOMPTARGET_HERO_DEV_TYPE)")
endif()

foreach(HERO_DEV_TYPE ${LIBOMPTARGET_HERO_DEV_TYPE})

  string(TOLOWER ${HERO_DEV_TYPE} HERO_DEV_TYPE_LOWER)

  add_library(omptarget.rtl.herodev_${HERO_DEV_TYPE_LOWER} SHARED
    rtl.cpp
  )

  # Install plugin under the lib destination folder.
  install(TARGETS omptarget.rtl.herodev_${HERO_DEV_TYPE_LOWER} LIBRARY DESTINATION "${OPENMP_INSTALL_LIBDIR}")

  if(LIBOMPTARGET_ENABLE_PREM)
    target_link_libraries(omptarget.rtl.herodev_${HERO_DEV_TYPE_LOWER}
      ${LIBOMPTARGET_DEP_LIBFFI_LIBRARIES}
      ${LIBOMPTARGET_DEP_LIBELF_LIBRARIES}
      "cmux-vote"
      "premnotify"
    )
  else()
    target_link_libraries(omptarget.rtl.herodev_${HERO_DEV_TYPE_LOWER}
      ${LIBOMPTARGET_DEP_LIBFFI_LIBRARIES}
      ${LIBOMPTARGET_DEP_LIBELF_LIBRARIES}
    )
  endif()

  add_definitions(-DLIBOMPTARGET_HERO)
  add_definitions(-DLIBOMPTARGET_HERO_DEV_TYPE_${HERO_DEV_TYPE})
  if(EXISTS $ENV{HERO_LIBHERO_DIR}/lib/libhero_${HERO_DEV_TYPE_LOWER}.so)
    target_link_libraries(omptarget.rtl.herodev_${HERO_DEV_TYPE_LOWER}
        $ENV{HERO_LIBHERO_DIR}/lib/libhero_${HERO_DEV_TYPE_LOWER}.so)
  else()
    message( FATAL_ERROR $ENV{HERO_LIBHERO_DIR} "/lib/libhero_" ${HERO_DEV_TYPE_LOWER} ".so not found" )
  endif()
endforeach()

# Report to the parent scope that we are building a plugin for HERO.
set(LIBOMPTARGET_SYSTEM_TARGETS "${LIBOMPTARGET_SYSTEM_TARGETS} hero" PARENT_SCOPE)
