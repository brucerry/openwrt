/* SPDX-License-Identifier:	GPL-2.0+ */
/*
 * Copyright (C) 2021 MediaTek Incorporation. All Rights Reserved.
 *
 * Author: Alvin Kuo <Alvin.Kuo@mediatek.com>
 */
#ifndef __MTK_EFUSE_H__
#define __MTK_EFUSE_H__

/*********************************************************************************
 *
 *  Returned status of eFuse SMC
 *
 ********************************************************************************/
#define MTK_EFUSE_SUCCESS                                       0x00000000
#define MTK_EFUSE_ERROR_INVALIDE_PARAMTER                       0x00000001
#define MTK_EFUSE_ERROR_INVALIDE_EFUSE_FIELD                    0x00000002
#define MTK_EFUSE_ERROR_EFUSE_FIELD_DISABLED                    0x00000003
#define MTK_EFUSE_ERROR_EFUSE_LEN_EXCEED_BUFFER_LEN             0x00000004
#define MTK_EFUSE_ERROR_READ_EFUSE_FIELD_FAIL                   0x00000005
#define MTK_EFUSE_ERROR_WRITE_EFUSE_FIELD_FAIL                  0x00000006

/*********************************************************************************
 *
 *  Function ID of eFuse SMC
 *
 ********************************************************************************/
/*
 *  MTK_SIP_EFUSE_GET_LEN - get data length of efuse field
 *
 *  parameters
 *  @x1:        efuse field
 *
 *  return
 *  @r0:        status
 *  @r1:        data length
 */
#define MTK_SIP_EFUSE_GET_LEN           0x82000501

/*
 *  MTK_SIP_EFUSE_WRITE - write efuse field
 *
 *  parameters
 *  @x1:        efuse field
 *  @x2:        addr
 *  @x3:        size
 *
 *  return
 *  @r0:        status
 */
#define MTK_SIP_EFUSE_WRITE             0x82000502

/*
 *  MTK_SIP_EFUSE_READ - read efuse field
 *
 *  parameters
 *  @x1:        efuse field
 *  @x2:        offset
 *
 *  return
 *  @r0:        status
 */
#define MTK_SIP_EFUSE_READ              0x82000503

/*
 *  MTK_SIP_EFUSE_DISABLE - disable efuse field
 *
 *  parameters
 *  @x1:        efuse field
 *
 *  return
 *  @r0:        status
 */
#define MTK_SIP_EFUSE_DISABLE		0x82000504

/*
 *  MTK_SIP_EFUSE_UPDATE_AR_VER - update anti-rollback version
 *
 *  return
 *  @r0:        status
 */
#define MTK_SIP_EFUSE_UPDATE_AR_VER	0x82000510

/*********************************************************************************
 *
 *  netlink info
 *
 ********************************************************************************/
#define MTK_EFUSE_NL_GENL_NAME			"mtk-efuse"
#define MTK_EFUSE_NL_GENL_VERSION		0x2

enum MTK_EFUSE_NL_CMD {
	MTK_EFUSE_NL_CMD_UNSPEC = 0,
	MTK_EFUSE_NL_CMD_READ,
	MTK_EFUSE_NL_CMD_WRITE,
	MTK_EFUSE_NL_CMD_GET_LEN,
	MTK_EFUSE_NL_CMD_UPDATE_AR_VER,
	__MTK_EFUSE_NL_CMD_MAX
};
#define MTK_EFUSE_NL_CMD_MAX (__MTK_EFUSE_NL_CMD_MAX - 1)

enum MTK_EFUSE_NL_ATTR_TYPE {
	MTK_EFUSE_NL_ATTR_TYPE_UNSPEC = 0,
	MTK_EFUSE_NL_ATTR_TYPE_EFUSE_FIELD,
	MTK_EFUSE_NL_ATTR_TYPE_DATA,
	__MTK_EFUSE_NL_ATTR_TYPE_MAX,
};
#define MTK_EFUSE_NL_ATTR_TYPE_MAX (__MTK_EFUSE_NL_ATTR_TYPE_MAX - 1)

static int mtk_efuse_nl_reply_read(struct genl_info *info);
static int mtk_efuse_nl_reply_write(struct genl_info *info);
static int mtk_efuse_nl_reply_get_len(struct genl_info *info);
static int mtk_efuse_nl_reply_update_ar_ver(struct genl_info *info);
static int mtk_efuse_nl_response(struct sk_buff *skb, struct genl_info *info);

#endif /* __MTK_EFUSE_H__ */
