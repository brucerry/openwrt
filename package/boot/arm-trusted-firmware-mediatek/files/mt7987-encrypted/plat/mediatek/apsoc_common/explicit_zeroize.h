/**
 * \file explicit_zeroize.h
 *
 * \brief Secure memory clearing helper.
 */
/*
 *  Copyright The Mbed TLS Contributors
 *  SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later
 */
#ifndef EXPLICIT_ZEROIZE_H
#define EXPLICIT_ZEROIZE_H

#include <stddef.h>

void explicit_zeroize(void *buf, size_t len);

#endif /* EXPLICIT_ZEROIZE_H */