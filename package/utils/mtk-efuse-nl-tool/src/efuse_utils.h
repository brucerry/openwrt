/* SPDX-License-Identifier: BSD-2-Clause */
/*
 * Copyright (C) 2024 MediaTek Incorporation. All Rights Reserved.
 *
 */
#ifndef __EFUSE_UTILS_H__
#define __EFUSE_UTILS_H__

#include <stdint.h>

#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))

int get_file_size(char *file, long *size);
int read_file(char *file, void *buffer, uint32_t length);

#endif /* __EFUSE_UTILS_H__ */
