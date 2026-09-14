/*
 * Common and shared functions used by multiple modules in the Mbed TLS
 * library.
 *
 *  Copyright The Mbed TLS Contributors
 *  SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
 */

#include <string.h>

static void *(*const volatile memset_func)(void *, int, size_t) = memset;

void explicit_zeroize(void *buf, size_t len)
{
    if (len > 0) {
        memset_func(buf, 0, len);

#if defined(__GNUC__)
#if defined(__clang__) || (__GNUC__ >= 10)
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wvla"
#else
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wvla"
#endif
        asm volatile ("" : : "m" (*(char (*)[len]) buf) :);
#if defined(__clang__)
#pragma clang diagnostic pop
#else
#pragma GCC diagnostic pop
#endif
#endif
#endif
    }
}