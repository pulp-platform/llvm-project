/*
 * Copyright (C) 2018 ETH Zurich and University of Bologna
 *
 * Author: Alessandro Capotondi, UNIBO, (alessandro.capotondi@unibo.it)
 *
 * Copyright (C) 2005-2014 Free Software Foundation, Inc.
 *
 * This file is part of the GNU OpenMP Library (libgomp).
 *
 * Libgomp is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
 * any later version.
 *
 * Libgomp is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * Under Section 7 of GPL version 3, you are granted additional
 * permissions described in the GCC Runtime Library Exception, version
 * 3.1, as published by the Free Software Foundation.
 *
 * You should have received a copy of the GNU General Public License and
 * a copy of the GCC Runtime Library Exception along with this program;
 * see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see
 * <http://www.gnu.org/licenses/>.
 */

#ifndef PLUGIN_HERO_DEV_H__
#define PLUGIN_HERO_DEV_H__

#define PRINT_CYCLES_PLUGIN_HERO_DEV 1
#define DEBUG_LEVEL_PLUGIN_HERO_DEV 0

#define TRACE_FUNCTION()                                                       \
  do {                                                                         \
    if (DEBUG_LEVEL_PLUGIN_HERO_DEV > 2) {                                    \
      printf("%s:%d:%s\n", __FILE__, __LINE__, __func__);                      \
    } else if (DEBUG_LEVEL_PLUGIN_HERO_DEV > 0) {                             \
      printf("%s\n", __func__);                                                \
    }                                                                          \
  } while (0)

#define TRACE(...)                                                             \
  do {                                                                         \
    if (DEBUG_LEVEL_PLUGIN_HERO_DEV > 3) {                                    \
      printf("%s:%d:%s - ", __FILE__, __LINE__, __func__);                     \
      printf(__VA_ARGS__);                                                     \
      printf("\n");                                                            \
    } else if (DEBUG_LEVEL_PLUGIN_HERO_DEV > 1) {                             \
      printf(__VA_ARGS__);                                                     \
      printf("\n");                                                            \
    }                                                                          \
  } while (0)

extern "C" {

#include "libhero/host/hero_api.h"

#define HERO_DEV_DEFAULT_CLUSTER_ID (0x1U)
#define HERO_DEV_DEFAULT_FREQ (HERO_DEV_DEFAULT_FREQ_MHZ)
#define HERO_DEV_DEFAULT_MEM_MODE (copy)
#define HERO_DEV_DEFAULT_RAB_LEVEL (0x2U)
#define HERO_DEV_DEFAULT_RAB_LOG_EN (0x0U)
#define HERO_DEV_DEFAULT_INTR_RAB_MISS_DIS (0x1U)
#define HERO_DEV_DEFAULT_ACP_EN (0x0U)
#define HERO_DEV_DEFAULT_TIMEOUT (20U)

}

/* Start/end addresses of functions and global variables on a device.  */
typedef std::vector<addr_pair> AddrVect;

/* Addresses of functions variables map on a device.  */
typedef std::map<uintptr_t, DataDesc> AddrVectMap;

/* Addresses for all images and a device.  */
typedef std::map<const void *, AddrVect> ImgDevAddrMap;

/* Total number of available devices.  */
static int num_devices;

/* Total number of shared libraries with offloading to HERO Device.  */
static int num_images;

/* Two dimensional array: one key is a pointer to image,
   second key is number of device.  Contains a vector of pointer pairs.  */
static ImgDevAddrMap *address_table;
static AddrVectMap *address_map;

/* Thread-safe registration  */
static pthread_once_t is_init_hero_device = PTHREAD_ONCE_INIT;

/* HERO device handlers.  */
static HeroDev hero_dev;
static HeroDev *hd;

#define GOMP(X) GOMP_PLUGIN_##X
#define SELF "hero: "

extern "C" int GOMP_OFFLOAD_hero_get_nb_rab_miss_handlers(void);

extern "C" int GOMP_OFFLOAD_get_type(void) {
  TRACE_FUNCTION();

  return OFFLOAD_TARGET_TYPE_HERO;
}

extern "C" int GOMP_OFFLOAD_get_num_devices(void) {
  TRACE_FUNCTION();

  return 1;
}

static int init_hero_device() {
  TRACE_FUNCTION();

  int ret;
  int currFreq = 0x0;

  hero_add_timestamp("device_init",__func__,0);

  hd = &hero_dev;
  //hd->cluster_sel = HERO_DEV_DEFAULT_CLUSTER_ID;

  // reserve virtual addresses overlapping with HERO Device's internal physical address
  // space
  ret = hero_dev_mmap(hd);
  if (ret < 0) {
    TRACE("ERROR: cannot load device!");
    return ret;
  }

  //currFreq = hero_dev_clking_set_freq(hd, HERO_DEV_DEFAULT_FREQ);
  //if (currFreq > 0)
  //  TRACE("HERO Device running @ %d MHz.", currFreq);

  hero_dev_reset(hd, 0x1);

  // initialization of HERO Device, static RAB rules (mbox, L2, ...)
  hero_dev_init(hd);

  // set up accelerator for RAB miss-handling
  // FIXME: reenable after fixing
  // hero_dev_rab_soc_mh_enable(hd, 0);

  address_table = new ImgDevAddrMap;
  address_map = new AddrVectMap;
  num_devices = 1;
  num_images = 0;
  return 0;
}

static int deinit_hero_device() {
  //hero_dev_munmap(NULL);
}

extern "C" bool GOMP_OFFLOAD_init_device(int n __attribute__((unused))) {
  TRACE_FUNCTION();

  pthread_once(&is_init_hero_device, init_hero_device);

  return 1;
}

extern "C" bool GOMP_OFFLOAD_fini_device(int n __attribute__((unused))) {
  TRACE_FUNCTION();

  hero_dev_mbox_write(hd, MBOX_DEVICE_STOP);

  TRACE("Waiting for EOC...");
  hero_dev_exe_wait(hd, HERO_DEV_DEFAULT_TIMEOUT);
  hero_dev_exe_stop(hd);
  hero_dev_munmap(hd);

  return 1;
}

/* Return the libgomp version number we're compatible with.  There is
   no requirement for cross-version compatibility.  */

extern "C" unsigned GOMP_OFFLOAD_version(void) { return GOMP_VERSION; }

static void get_target_table(int &num_funcs, int &num_vars, void **&table) {
  TRACE_FUNCTION();

  unsigned int nums[2];
  hero_dev_mbox_read(hd, nums, 2);

  num_funcs = nums[0];
  num_vars = nums[1];

  int table_size = num_funcs + 2 * num_vars;
  table = new void *[table_size];

  if (num_funcs) {
    hero_dev_mbox_read(hd, (unsigned int *)&table[0], num_funcs);
    for (int i = 0; i < num_funcs; i++) {
      TRACE("Function %d @ %p", i, table[i]);
    }
  }

  if (num_vars) {
    hero_dev_mbox_read(hd, (unsigned int *)&table[num_funcs], num_vars);
    for (int i = 0; i < num_vars; i++) {
      TRACE("Variable %d @ %p, size = %#x", i, table[num_funcs + i * 2],
            table[num_funcs + i * 2 + 1]);
    }
  }
}

/* Offload TARGET_IMAGE to all available devices and fill address_table with
   corresponding target addresses.  */
static void offload_image(const void *target_image) {
  TRACE_FUNCTION();

  struct TargetImage {
    int64_t size;
    /* 10 characters is enough for max int value.  */
    char name[sizeof("lib0000000000.so")];
    char data[];
  } __attribute__((packed));

  void *image_start = ((void **)target_image)[0];
  void *image_end = ((void **)target_image)[1];
  int64_t image_size = (uintptr_t)image_end - (uintptr_t)image_start;

  TRACE("HERO Device target_image @ %p: start @ %p, end @ %p, size = %#x",
        target_image, image_start, image_end, image_size);

  TargetImage *image = (TargetImage *)malloc(
      sizeof(int64_t) + sizeof("lib0000000000.so") + image_size);

  if (!image) {
    fprintf(stderr, "%s: Can't allocate memory\n", __FILE__);
    exit(1);
  }

  image->size = image_size;
  sprintf(image->name, "lib%010d.so", num_images++);
  hero_dev_load_bin_from_mem(hd, image_start, image->size);
  TRACE("HERO Device target_image %s @ %p loaded, size = %#x", image->name,
        (void *)image_start, image->size);

  hero_dev_exe_start(hd);

  int num_funcs = 0;
  int num_vars = 0;
  void **table = NULL;

  get_target_table(num_funcs, num_vars, table);

  AddrVect curr_dev_table;
  for (int i = 0; i < num_funcs; i++) {
    addr_pair tgt_addr;
    tgt_addr.start = (uintptr_t)table[i];
    tgt_addr.end = tgt_addr.start + sizeof(uintptr_t);
    TRACE("Function %d @ %p ... %p", i, (void *)tgt_addr.start,
          (void *)tgt_addr.end);
    curr_dev_table.push_back(tgt_addr);
  }

  for (int i = 0; i < num_vars; i++) {
    addr_pair tgt_addr;
    tgt_addr.start = (uintptr_t)table[num_funcs + i * 2];
    tgt_addr.end = tgt_addr.start +
                   (uintptr_t)table[num_funcs + i * 2 + 1]; // start + size
    TRACE("Variable %d @ %p ... %p", i, (void *)tgt_addr.start,
          (void *)tgt_addr.end);
    curr_dev_table.push_back(tgt_addr);
  }
  address_table->insert(std::make_pair(target_image, curr_dev_table));
  free(image);
}

extern "C" int
GOMP_OFFLOAD_load_image(int device __attribute__((unused)),
                        unsigned int version __attribute__((unused)),
                        const void *target_image __attribute__((unused)),
                        struct addr_pair **result __attribute__((unused))) {
  TRACE_FUNCTION();

  TRACE("Device %d, Version %d, target_image @ %p, result @ %p", device,
        version, target_image, result);

  if (GOMP_VERSION_DEV(version) > GOMP_VERSION) {
    //    GOMP_PLUGIN_error ("Offload data incompatible with HERO plugin"
    //      " (expected %u, received %u)",
    //      GOMP_VERSION, GOMP_VERSION_DEV (version));
    return -1;
  }

  /* If target_image is already present in address_table, then there is no need
     to offload it.  */
  if (address_table->count(target_image) == 0)
    offload_image(target_image);

  AddrVect *curr_dev_table = &(*address_table)[target_image];
  int table_size = curr_dev_table->size();
  addr_pair *table = (addr_pair *)malloc(table_size * sizeof(addr_pair));
  if (table == NULL) {
    fprintf(stderr, "%s: Can't allocate memory\n", __FILE__);
    exit(1);
  }

  std::copy(curr_dev_table->begin(), curr_dev_table->end(), table);
  *result = table;
  return table_size;
}

extern "C" bool GOMP_OFFLOAD_unload_image(int n __attribute__((unused)),
                                          unsigned int version
                                          __attribute__((unused)),
                                          const void *i
                                          __attribute__((unused))) {
  TRACE_FUNCTION();

  return 1;
}

extern "C" void *GOMP_OFFLOAD_alloc(int n __attribute__((unused)),
                                    size_t size) {
  TRACE_FUNCTION();

  uintptr_t phy_ptr = (uintptr_t)NULL;
  uintptr_t virt_ptr = (uintptr_t)NULL;
  DataDesc data_desc;

  virt_ptr = (uintptr_t)hero_dev_l2_malloc(hd, size, (uintptr_t *)&phy_ptr);

  data_desc.sh_mem_ctrl = HERO_DEV_DEFAULT_MEM_MODE;
  data_desc.cache_ctrl = HERO_DEV_DEFAULT_ACP_EN;
  data_desc.rab_lvl = HERO_DEV_DEFAULT_RAB_LEVEL;
  data_desc.ptr_l3_v = (void *)virt_ptr;
  data_desc.ptr_l3_p = (void *)phy_ptr;
  data_desc.size = size;

  TRACE("data_desc.sh_mem_ctrl = %#x", data_desc.sh_mem_ctrl);
  TRACE("data_desc.cache_ctrl  = %#x", data_desc.cache_ctrl);
  TRACE("data_desc.rab_lvl     = %#x", data_desc.rab_lvl);
  TRACE("data_desc.ptr_l3_v    = %#p", data_desc.ptr_l3_v);
  TRACE("data_desc.ptr_l3_p    = %#p", data_desc.ptr_l3_p);
  TRACE("data_desc.size        = %#x", data_desc.size);

  address_map->insert(std::make_pair(phy_ptr, data_desc));
  return (void *)phy_ptr;
}

extern "C" bool GOMP_OFFLOAD_free(int n __attribute__((unused)),
                                  void *tgt_ptr) {
  TRACE_FUNCTION();

  TRACE("tgt_ptr = %p", tgt_ptr);
  uintptr_t vir_ptr =
      (uintptr_t)(address_map->find((uintptr_t)tgt_ptr)->second).ptr_l3_v;
  uintptr_t phy_ptr = (uintptr_t)tgt_ptr;
  address_map->erase(phy_ptr);

  hero_dev_l2_free(hd, vir_ptr, phy_ptr);

  return 1;
}

extern "C" bool GOMP_OFFLOAD_host2dev(int n __attribute__((unused)),
                                      void *tgt_ptr, const void *host_ptr,
                                      size_t size) {
  TRACE_FUNCTION();

  DataDesc &data_desc = address_map->find((uintptr_t)tgt_ptr)->second;
  uintptr_t vir_ptr = (uintptr_t)data_desc.ptr_l3_v;

  TRACE("       tgt_ptr = %p, host_ptr = %p, size = %#x", (void *)tgt_ptr,
        (void *)host_ptr, size);
  TRACE("memcpy(vir_ptr = %p, host_ptr = %p, size = %#x)", (void *)vir_ptr,
        (void *)host_ptr, size);

  // FIXME: This is a workaround to solve issue hero#59, in which the aarch64
  //        memcpy caused a segfault under certain cases. The gitlab issue has
  //        coded we used to produce the behaviour. The workaround is to use a
  //        byte-copy-loop.
  char *src = (char *)host_ptr;
  char *dst = (char *)vir_ptr;
  for (int i = 0; i < size; i++) {
    dst[i] = src[i];
  }
  //memcpy((void *)vir_ptr, host_ptr, size);

  return 1;
}

extern "C" bool GOMP_OFFLOAD_dev2host(int n __attribute__((unused)),
                                      void *host_ptr, const void *tgt_ptr,
                                      size_t size) {
  TRACE_FUNCTION();

  DataDesc &data_desc = address_map->find((uintptr_t)tgt_ptr)->second;
  uintptr_t vir_ptr = (uintptr_t)data_desc.ptr_l3_v;

  TRACE("       host_ptr = %p, tgt_ptr = %p, size = %#x", (void *)host_ptr,
        (void *)tgt_ptr, size);
  TRACE("memcpy(host_ptr = %p, vir_ptr = %p, size = %#x)", (void *)host_ptr,
        (void *)vir_ptr, size);

  // FIXME: This is a workaround to solve issue hero#59, in which the aarch64
  //        memcpy caused a segfault under certain cases. The gitlab issue has
  //        coded we used to produce the behaviour. The workaround is to use a
  //        byte-copy-loop.
  char *dst = (char *)host_ptr;
  char *src = (char *)vir_ptr;
  for (int i = 0; i < size; i++) {
    dst[i] = src[i];
  }
  //memcpy(host_ptr, (void *)vir_ptr, size);

  return 1;
}

extern "C" bool GOMP_OFFLOAD_dev2dev(int n __attribute__((unused)),
                                     void *host_ptr, const void *tgt_ptr,
                                     size_t size) {
  TRACE_FUNCTION();

  // GOMP_PLUGIN_fatal("Not supported!");

  return 0;
}

extern "C" void GOMP_OFFLOAD_run(int n __attribute__((unused)), void *tgt_fn,
                                 void *tgt_vars,
                                 void **args __attribute__((unused))) {
  TRACE_FUNCTION();

  uint32_t ret[2];

  TRACE("tgt_fn @ %p, tgt_vars @ %p, nb_rab_miss_handlers %d", tgt_fn, tgt_vars,
        GOMP_OFFLOAD_hero_get_nb_rab_miss_handlers());
  hero_dev_mbox_write(hd, MBOX_DEVICE_START);
  hero_dev_mbox_write(hd, (uint32_t)tgt_fn);
  hero_dev_mbox_write(hd, (uint32_t)tgt_vars);
  hero_dev_mbox_write(hd, (uint32_t)GOMP_OFFLOAD_hero_get_nb_rab_miss_handlers());

  hero_dev_mbox_read(hd, (unsigned int *)&ret, 2);
  if (MBOX_DEVICE_DONE == ret[0])
    TRACE("Execution done");
  else
    TRACE("Returned %#x", ret[0]);

  if (PRINT_CYCLES_PLUGIN_HERO_DEV == 1)
    printf("Execution time, kernel only [HERO Device cycles] = %d\n", (int)ret[1]);
}

void GOMP_OFFLOAD_async_run(int ord, void *tgt_fn, void *tgt_vars, void **args,
                            void *async_data) {
  TRACE_FUNCTION();

  // GOMP_PLUGIN_fatal("Not supported!");
}

#endif // PLUGIN_HERO_DEV_H__
