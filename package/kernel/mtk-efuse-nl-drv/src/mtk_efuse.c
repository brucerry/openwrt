/* SPDX-License-Identifier:	GPL-2.0+ */
/*
 * Copyright (C) 2021 MediaTek Incorporation. All Rights Reserved.
 *
 * Author: Alvin Kuo <Alvin.Kuo@mediatek.com>
 */

#include <linux/init.h>
#include <linux/types.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/arm-smccc.h>
#include <net/genetlink.h>

#include "mtk_efuse.h"

/*
 *  define private netlink command type
 */
struct mtk_efuse_nl_cmd_t {
	enum MTK_EFUSE_NL_CMD cmd;
	int (*process)(struct genl_info *info);
	const enum MTK_EFUSE_NL_ATTR_TYPE *req_attrs;
	u32 req_attrs_num;
};

#define MTK_EFUSE_NL_CMD_REQ_ATTRS(attr) \
	.req_attrs = attr, \
	.req_attrs_num = ARRAY_SIZE(attr),

static const enum MTK_EFUSE_NL_ATTR_TYPE
mtk_efuse_nl_cmd_read_attrs[] = {
	MTK_EFUSE_NL_ATTR_TYPE_EFUSE_FIELD,
};

static const enum MTK_EFUSE_NL_ATTR_TYPE
mtk_efuse_nl_cmd_write_attrs[] = {
	MTK_EFUSE_NL_ATTR_TYPE_EFUSE_FIELD,
	MTK_EFUSE_NL_ATTR_TYPE_DATA
};

static const enum MTK_EFUSE_NL_ATTR_TYPE
mtk_efuse_nl_cmd_get_len_attrs[] = {
	MTK_EFUSE_NL_ATTR_TYPE_EFUSE_FIELD,
};

/* 
 *  define process function and required attributes
 *  for each supported netlink command
 */
static const struct mtk_efuse_nl_cmd_t
mtk_efuse_nl_cmds[] = {
	{
		.cmd = MTK_EFUSE_NL_CMD_READ,
		.process = mtk_efuse_nl_reply_read,
		MTK_EFUSE_NL_CMD_REQ_ATTRS(mtk_efuse_nl_cmd_read_attrs)
	}, {
		.cmd = MTK_EFUSE_NL_CMD_WRITE,
		.process = mtk_efuse_nl_reply_write,
		MTK_EFUSE_NL_CMD_REQ_ATTRS(mtk_efuse_nl_cmd_write_attrs)
	}, {
		.cmd = MTK_EFUSE_NL_CMD_GET_LEN,
		.process = mtk_efuse_nl_reply_get_len,
		MTK_EFUSE_NL_CMD_REQ_ATTRS(mtk_efuse_nl_cmd_get_len_attrs)
	}, {
		.cmd = MTK_EFUSE_NL_CMD_UPDATE_AR_VER,
		.process = mtk_efuse_nl_reply_update_ar_ver,
		.req_attrs = NULL,
		.req_attrs_num = 0,
	},
};

/*  
 *  define netlink attribute type
 */
static const struct nla_policy
mtk_efuse_nl_cmd_policy[] = {
	[MTK_EFUSE_NL_ATTR_TYPE_EFUSE_FIELD] = { .type = NLA_U32 },
	[MTK_EFUSE_NL_ATTR_TYPE_DATA] = { .type = NLA_BINARY },
};

/*  
 *  define supported netlink command
 */
static const struct genl_ops
mtk_efuse_nl_ops[] = {
	{
		.cmd = MTK_EFUSE_NL_CMD_READ,
		.doit = mtk_efuse_nl_response,
		.flags = GENL_ADMIN_PERM,
	}, {
		.cmd = MTK_EFUSE_NL_CMD_WRITE,
		.doit = mtk_efuse_nl_response,
		.flags = GENL_ADMIN_PERM,
	}, {
		.cmd = MTK_EFUSE_NL_CMD_GET_LEN,
		.doit = mtk_efuse_nl_response,
		.flags = GENL_ADMIN_PERM,
	}, {
		.cmd = MTK_EFUSE_NL_CMD_UPDATE_AR_VER,
		.doit = mtk_efuse_nl_response,
		.flags = GENL_ADMIN_PERM,
	},
};

static struct genl_family
mtk_efuse_nl_family = {
	.name = MTK_EFUSE_NL_GENL_NAME,
	.version = MTK_EFUSE_NL_GENL_VERSION,
	.maxattr = MTK_EFUSE_NL_ATTR_TYPE_MAX,
	.ops = mtk_efuse_nl_ops,
	.n_ops = ARRAY_SIZE(mtk_efuse_nl_ops),
	.policy = mtk_efuse_nl_cmd_policy,
};

static int mtk_efuse_smc(unsigned long smc_fid,
			 unsigned long x1,
			 unsigned long x2,
			 unsigned long x3,
			 unsigned long x4,
			 struct arm_smccc_res *res)
{
	/* SMC64 calling convention is used if in 64bits Linux */
	if (sizeof(void *) == 8)
		smc_fid |= (0x1 << 30);

	arm_smccc_smc(smc_fid, x1, x2, x3, x4, 0x0, 0x0, 0x0, res);

	return 0;
}

static int mtk_efuse_read(u32 efuse_field,
			  u8 *read_buffer,
			  u32 read_buffer_len)
{
	int ret;
	u32 offset;
	u32 efuse_len;
	u32 val;
	static struct arm_smccc_res res;

	/* get efuse length */
	ret = mtk_efuse_smc(MTK_SIP_EFUSE_GET_LEN,
			    efuse_field, 0x0, 0x0, 0x0,
			    &res);
	if (ret < 0)
		return ret;
	else if (res.a0 != MTK_EFUSE_SUCCESS) {
		pr_err("%s : get efuse length fail (%lu)\n",
		       __func__, res.a0);
		return -1;
	}
	efuse_len = res.a1;

	/* verify efuse_buffer */
	if (!read_buffer)
		return -EINVAL;
	if (read_buffer_len < efuse_len)
		return -ENOMEM;

	/* clean read buffer */
	memset(read_buffer, 0x0, read_buffer_len);

	/* issue efuse read */
	for (offset = 0; offset < efuse_len; offset += 4) {
		ret = mtk_efuse_smc(MTK_SIP_EFUSE_READ,
				    efuse_field, offset, 0x0, 0x0,
				    &res);
		if (ret < 0)
			return ret;
		else if (res.a0 != MTK_EFUSE_SUCCESS) {
			pr_err("%s : read efuse fail (%lu)\n",
			       __func__, res.a0);
			return -1;
		}
		val = res.a1;

		if (offset + sizeof(val) <= efuse_len)
			memcpy(read_buffer + offset, &val, sizeof(val));
		else
			memcpy(read_buffer + offset, &val, efuse_len - offset);
	}

	return 0;
}

static int mtk_efuse_write(u32 efuse_field,
			   u8 *write_buffer,
			   u32 write_buffer_len)
{
	int ret;
	u32 efuse_len;
	uintptr_t data;
	static struct arm_smccc_res res;

	/* get efuse length */
	ret = mtk_efuse_smc(MTK_SIP_EFUSE_GET_LEN,
			    efuse_field, 0x0, 0x0, 0x0,
			    &res);
	if (ret < 0)
		return ret;
	else if (res.a0 != MTK_EFUSE_SUCCESS) {
		pr_err("%s : get efuse length fail (%lu)\n",
		       __func__, res.a0);
		return -1;
	}
	efuse_len = res.a1;

	/* verify buffer */
	if (!write_buffer)
		return -EINVAL;
	if (write_buffer_len < efuse_len)
		return -ENOMEM;

	data = __get_free_page(GFP_KERNEL);
	if (!data)
		return -ENOMEM;

	memcpy((void *)data, write_buffer, efuse_len);

	/* issue efuse write */
	ret = mtk_efuse_smc(MTK_SIP_EFUSE_WRITE,
			    efuse_field, virt_to_phys((void *)data), efuse_len,
			    0x0, &res);
	if (!ret && res.a0 != MTK_EFUSE_SUCCESS) {
		pr_err("%s : write efuse fail (%lu)\n", __func__, res.a0);
		ret = -1;
	}

	free_page(data);

	return ret;
}

static int mtk_efuse_get_len(u32 efuse_field, u32 *efuse_len)
{
	int ret;
	struct arm_smccc_res res = { 0 };

	/* get efuse length */
	ret = mtk_efuse_smc(MTK_SIP_EFUSE_GET_LEN,
			    efuse_field, 0x0, 0x0, 0x0,
			    &res);
	if (ret < 0)
		return ret;
	else if (res.a0 != MTK_EFUSE_SUCCESS) {
		pr_err("%s : get efuse length fail (%lu)\n",
		       __func__, res.a0);
		return -1;
	}

	*efuse_len = res.a1;

	return 0;
}

static int mtk_efuse_nl_prepare_reply(struct genl_info *info,
				      u8 cmd,
				      struct sk_buff **skbp)
{
	void *reply;
        struct sk_buff *skb;

        if (!info)
		return -EINVAL;

        skb = genlmsg_new(NLMSG_GOODSIZE, GFP_KERNEL);
        if (!skb)
		return -ENOMEM;

	/* construct send-back message header */
	reply = genlmsg_put(skb, info->snd_portid, info->snd_seq,
			    &mtk_efuse_nl_family, 0, cmd);
	if (!reply) {
		nlmsg_free(skb);
		return -EINVAL;
	}

	*skbp = skb;
        return 0;
}

static int mtk_efuse_nl_send_reply(struct sk_buff *skb,
				   struct genl_info *info)
{
        struct genlmsghdr *genlhdr = nlmsg_data(nlmsg_hdr(skb));
        void *reply = genlmsg_data(genlhdr);

        /* finalize a generic netlink message */
        genlmsg_end(skb, reply);

        /* reply to a request */
        return genlmsg_reply(skb, info);
}

static int mtk_efuse_nl_reply_read(struct genl_info *info)
{
	int ret;
	u32 efuse_field;
	u32 len;
	u8 *read_buffer = NULL;
	struct sk_buff *reply_skb = NULL;

	efuse_field =
		nla_get_u32(info->attrs[MTK_EFUSE_NL_ATTR_TYPE_EFUSE_FIELD]);

	ret = mtk_efuse_nl_prepare_reply(info, MTK_EFUSE_NL_CMD_READ,
					 &reply_skb);
	if (ret < 0)
		goto error;

	ret = mtk_efuse_get_len(efuse_field, &len);
	if (ret < 0)
		goto error;

	read_buffer = kmalloc(len, GFP_KERNEL);
	if (!read_buffer) {
		ret = -ENOMEM;
		goto error;
	}

	ret = mtk_efuse_read(efuse_field, read_buffer, len);
	if (ret < 0)
		goto error;

	ret = nla_put(reply_skb, MTK_EFUSE_NL_ATTR_TYPE_DATA, len, read_buffer);
	if (ret < 0)
		goto error;

	kfree(read_buffer);

        return mtk_efuse_nl_send_reply(reply_skb, info);

error:
        if (reply_skb)
		nlmsg_free(reply_skb);
	kfree(read_buffer);

        return ret;
}

static int mtk_efuse_nl_reply_write(struct genl_info *info)
{
	u32 len;
	u32 efuse_field;
	u8 *data;

	efuse_field =
		nla_get_u32(info->attrs[MTK_EFUSE_NL_ATTR_TYPE_EFUSE_FIELD]);

	data = nla_data(info->attrs[MTK_EFUSE_NL_ATTR_TYPE_DATA]);
	len = nla_len(info->attrs[MTK_EFUSE_NL_ATTR_TYPE_DATA]);

	if (!data || !len)
		return -EINVAL;

	return mtk_efuse_write(efuse_field, data, len);
}

static int mtk_efuse_nl_reply_get_len(struct genl_info *info)
{
	int ret;
	u32 efuse_field;
	u32 len;
	struct sk_buff *reply_skb = NULL;

	efuse_field =
		nla_get_u32(info->attrs[MTK_EFUSE_NL_ATTR_TYPE_EFUSE_FIELD]);

	ret = mtk_efuse_nl_prepare_reply(info, MTK_EFUSE_NL_CMD_GET_LEN,
					 &reply_skb);
	if (ret < 0)
		goto error;

	ret = mtk_efuse_get_len(efuse_field, &len);
	if (ret < 0)
		goto error;

	ret = nla_put(reply_skb, MTK_EFUSE_NL_ATTR_TYPE_DATA, sizeof(len), (u8 *)&len);
	if (ret < 0)
		goto error;

	return mtk_efuse_nl_send_reply(reply_skb, info);

error:
	if (reply_skb)
		nlmsg_free(reply_skb);

	return ret;
}

static int mtk_efuse_nl_reply_update_ar_ver(struct genl_info *info)
{
	int ret;
	struct arm_smccc_res res;

	/* issue update anti-rollback version*/
	ret = mtk_efuse_smc(MTK_SIP_EFUSE_UPDATE_AR_VER,
			    0x0, 0x0, 0x0, 0x0,
			    &res);
	if (ret < 0)
		return ret;
	else if (res.a0 != MTK_EFUSE_SUCCESS) {
		pr_err("%s : update anti-rollback version fail (%lu)\n"
		       , __func__, res.a0);
		return -1;
	}

	return 0;
}

static int mtk_efuse_nl_response(struct sk_buff *skb, struct genl_info *info)
{
	int idx;
        u32 nl_cmd_attrs_num = 0;
        const struct mtk_efuse_nl_cmd_t *cmditem = NULL;
        struct genlmsghdr *hdr = nlmsg_data(info->nlhdr);

	for (idx = 0; idx < ARRAY_SIZE(mtk_efuse_nl_cmds); idx++) {
		if (hdr->cmd == mtk_efuse_nl_cmds[idx].cmd) {
			cmditem = &mtk_efuse_nl_cmds[idx];
			break;
		}
	}

	if (!cmditem) {
		pr_err("%s : unknown cmd %u\n", __func__, hdr->cmd);
		return -EINVAL;
	}

	for (idx = 0; idx < cmditem->req_attrs_num; idx++) {
		if (info->attrs[cmditem->req_attrs[idx]])
			nl_cmd_attrs_num++;
	}

	if (nl_cmd_attrs_num != cmditem->req_attrs_num) {
		pr_err("%s : missing required attr(s) for cmd %u\n",
		       __func__, hdr->cmd);
		return -EINVAL;
	}

	return cmditem->process(info);
}

static int __init mtk_efuse_nl_init(void)
{
	int ret;

	ret = genl_register_family(&mtk_efuse_nl_family);
	if (ret) {
		pr_err("%s : genl_register_family fail (%d)\n",
		       __func__, ret);
		return ret;
	}

	pr_info("%s : netlink family \"mtk-efuse\" register success\n",
		__func__);
        return 0;
}

static void __exit mtk_efuse_nl_exit(void)
{
	genl_unregister_family(&mtk_efuse_nl_family);

	pr_info("%s : netlink family \"mtk-efuse\" unregister success\n",
		__func__);
}

module_init(mtk_efuse_nl_init);
module_exit(mtk_efuse_nl_exit);

MODULE_DESCRIPTION("Mediatek eFuse driver");
MODULE_LICENSE("GPL");
