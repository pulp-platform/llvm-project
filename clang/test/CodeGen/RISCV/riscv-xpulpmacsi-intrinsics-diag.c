// REQUIRES: riscv-registered-target
// RUN: %clang_cc1 %s -triple=riscv32 -verify -S -o -

#include <stdint.h>

void test_builtin_pulp_diag(int32_t *data) {
  // clang-format off
  (void) __builtin_pulp_mac(1, 2, 3); // expected-error {{builtin requires at least one of the following extensions support to be enabled : 'Xpulpv', 'Xpulpmacsi'}}
  (void) __builtin_pulp_msu(1, 2, 10); // expected-error {{builtin requires at least one of the following extensions support to be enabled : 'Xpulpv', 'Xpulpmacsi'}}
  // clang-format on
}
