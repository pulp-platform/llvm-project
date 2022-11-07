// REQUIRES: riscv-registered-target
// RUN: %clang_cc1 %s -triple=riscv32 -verify -S -o -

#include <stdint.h>

void test_builtin_pulp_diag(int32_t *data) {
  // clang-format off
  (void) __builtin_pulp_OffsetedRead(data, 4); // expected-error {{builtin requires at least one of the following extensions support to be enabled : 'Xpulpv', 'Xpulppostmod'}}
  (void) __builtin_pulp_OffsetedReadHalf((int16_t *) data, 4); // expected-error {{builtin requires at least one of the following extensions support to be enabled : 'Xpulpv', 'Xpulppostmod'}}
  (void) __builtin_pulp_OffsetedReadByte((char *) data, 4); // expected-error {{builtin requires at least one of the following extensions support to be enabled : 'Xpulpv', 'Xpulppostmod'}}
  __builtin_pulp_OffsetedWrite(1, data, 4); // expected-error {{builtin requires at least one of the following extensions support to be enabled : 'Xpulpv', 'Xpulppostmod'}}
  __builtin_pulp_OffsetedWriteHalf(1, (int16_t *) data, 4); // expected-error {{builtin requires at least one of the following extensions support to be enabled : 'Xpulpv', 'Xpulppostmod'}}
  __builtin_pulp_OffsetedWriteByte(1, (char *) data, 4); // expected-error {{builtin requires at least one of the following extensions support to be enabled : 'Xpulpv', 'Xpulppostmod'}}
  (void) __builtin_pulp_read_base_off(data, 0xF); // expected-error {{builtin requires at least one of the following extensions support to be enabled : 'Xpulpv', 'Xpulppostmod'}}
  __builtin_pulp_write_base_off(0x1, data, 0xF); // expected-error {{builtin requires at least one of the following extensions support to be enabled : 'Xpulpv', 'Xpulppostmod'}}
  // clang-format on
}
