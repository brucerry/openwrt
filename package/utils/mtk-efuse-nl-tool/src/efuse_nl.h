/* SPDX-License-Identifier: BSD-2-Clause */
/*
 * Copyright (C) 2024 MediaTek Incorporation. All Rights Reserved.
 *
 */
#ifndef __EFUSE_NL_H__
#define __EFUSE_NL_H__

#include <stdint.h>

/*********************************************************************************
 *
 *  netlink info
 *
 ********************************************************************************/
#define MTK_EFUSE_NL_GENL_NAME			"mtk-efuse"
#define MTK_EFUSE_NL_GENL_VERSION		0x2

void mtk_efuse_nl_free(void);
int mtk_efuse_nl_init(void);
int mtk_efuse_nl_read(uint32_t field, uint8_t *data, uint32_t len);
int mtk_efuse_nl_write(uint32_t field, uint8_t *data, uint32_t len);
int mtk_efuse_nl_get_len(uint32_t field, uint32_t *len);
int mtk_efuse_nl_update_ar_ver(void);

#endif /* __EFUSE_NL_H__ */
