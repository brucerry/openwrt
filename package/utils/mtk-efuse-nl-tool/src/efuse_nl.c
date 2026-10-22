// SPDX-License-Identifier: BSD-2-Clause
/*
 * Copyright (C) 2021 MediaTek Incorporation. All Rights Reserved.
 *
 * Author: Alvin Kuo <Alvin.Kuo@mediatek.com>
 */

#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <ctype.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <string.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netlink/netlink.h>
#include <netlink/genl/genl.h>
#include <netlink/genl/ctrl.h>
#include <netlink/genl/family.h>

#include "efuse_nl.h"

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

struct mtk_efuse_nl_attr_t {
	uint32_t field;
	uint32_t len;
	uint8_t *data;
};

static struct nl_sock *sock;
static struct nl_cache *cache;
static struct genl_family *family;

void mtk_efuse_nl_free(void)
{
	if (family)
		nl_object_put((struct nl_object *)family);
	if (cache)
		nl_cache_free(cache);
	if (sock)
		nl_socket_free(sock);

	sock = NULL;
	cache = NULL;
	family = NULL;
}

int mtk_efuse_nl_init(void)
{
	int ret;

	sock = NULL;
	cache = NULL;
	family = NULL;

	/* allocate a new netlink socket */
	sock = nl_socket_alloc();
	if (!sock) {
		fprintf(stderr, "failed to create socket\n");
		goto error;
	}

	/* connect a generic netlink socket */
	ret = genl_connect(sock);
	if (ret < 0) {
		fprintf(stderr, "failed to connect a generic netlink socket\n");
		goto error;
	}

	/* allocate a new controller cache */
	ret = genl_ctrl_alloc_cache(sock, &cache);
	if (ret < 0) {
		fprintf(stderr, "failed to allocate a controller cache\n");
		goto error;
	}

	/* search controller cache for a family name match */
	family = genl_ctrl_search_by_name(cache, MTK_EFUSE_NL_GENL_NAME);
	if (!family) {
		fprintf(stderr, "netlink family (%s) not found\n",
			MTK_EFUSE_NL_GENL_NAME);
		goto error;
	}

	return 0;

error:
	mtk_efuse_nl_free();
	return -EINVAL;
}

static int construct_attrs(struct nl_msg *msg, void *arg)
{
	struct mtk_efuse_nl_attr_t *attr = arg;
	struct genlmsghdr *genlh = nlmsg_data(nlmsg_hdr(msg));

	/* put efuse field into netlink msg */
	nla_put_u32(msg,
		    MTK_EFUSE_NL_ATTR_TYPE_EFUSE_FIELD,
		    attr->field);

	if (genlh->cmd == MTK_EFUSE_NL_CMD_WRITE) {
		/* put write data into netlink msg */
		nla_put(msg, MTK_EFUSE_NL_ATTR_TYPE_DATA, attr->len, attr->data);
	}

	return 0;
}

static int split_attrs(struct nl_msg *msg, void *arg)
{
	int ret;
	uint32_t len;
	uint8_t *data;
	struct mtk_efuse_nl_attr_t *attr = arg;
	struct genlmsghdr *genlh = nlmsg_data(nlmsg_hdr(msg));
	struct nlattr *nl_attrs[MTK_EFUSE_NL_ATTR_TYPE_MAX + 1];

	/* parse netlink msg */
	ret = nla_parse(nl_attrs, MTK_EFUSE_NL_ATTR_TYPE_MAX,
			genlmsg_attrdata(genlh, 0), genlmsg_attrlen(genlh, 0),
			NULL);
	if (ret < 0) {
		fprintf(stderr, "netlink msg parse fail (%d)\n", ret);
		goto done;
	}

	if (genlh->cmd == MTK_EFUSE_NL_CMD_READ ||
	    genlh->cmd == MTK_EFUSE_NL_CMD_GET_LEN) {
		/* get value */
		data = nla_data(nl_attrs[MTK_EFUSE_NL_ATTR_TYPE_DATA]);
		len = nla_len(nl_attrs[MTK_EFUSE_NL_ATTR_TYPE_DATA]);
		if (!data || !len || len != attr->len)
			goto done;

		memcpy(attr->data, data, len);
	}

	return 0;

done:
	return NL_SKIP;
}

static int wait_handler(struct nl_msg *msg, void *arg)
{
	int *finished = arg;

	*finished = 1;
	return NL_STOP;
}

static int mtk_efuse_nl_request(int cmd,
				int (*split)(struct nl_msg *, void *),
				int (*construct)(struct nl_msg *, void *),
				void *arg)
{
	int ret = -1;
	int finished;
	int flags = 0;
	struct nl_msg *msg = NULL;
	struct nl_cb *callback = NULL;

	/* allocate an netllink message buffer */
	msg = nlmsg_alloc();
	if (!msg) {
		fprintf(stderr, "failed to allocate netlink message\n");
		return -ENOMEM;
	}

	/* add generic netlink headers to netlink message */
	genlmsg_put(msg, NL_AUTO_PID, NL_AUTO_SEQ,
		    genl_family_get_id(family), 0, flags, cmd, 0);

	/* fill attaribute of netlink message via construct function */
	if (construct) {
		ret = construct(msg, arg);
		if (ret < 0) {
			fprintf(stderr, "construct attribute fail\n");
			goto error;
		}
	}

	/* allocate a new callback handler */
	callback = nl_cb_alloc(NL_CB_CUSTOM);
	if (!callback) {
		fprintf(stderr, "failed to allocate callback handler\n");
		goto error;
	}

	/* send netlink message */
	ret = nl_send_auto_complete(sock, msg);
	if (ret < 0) {
		fprintf(stderr, "send netlink msg fail (%d)\n", ret);
		goto error;
	}

	finished = 0;
	if (split) {
		nl_cb_set(callback, NL_CB_VALID, NL_CB_CUSTOM,
			  split, arg);
		nl_cb_set(callback, NL_CB_FINISH, NL_CB_CUSTOM,
			  wait_handler, &finished);
	} else {
		nl_cb_set(callback, NL_CB_ACK, NL_CB_CUSTOM,
			  wait_handler, &finished);
	}

	/* receive message from kernel request */
	ret = nl_recvmsgs(sock, callback);
	if (ret < 0) {
		fprintf(stderr, "receive msg fail (%d)\n", ret);
		goto error;
	}

	/* wait until an ACK is received for the latest not yet acknowledge*/
	if (!finished) {
		ret = nl_wait_for_ack(sock);
		if (ret < 0) {
			fprintf(stderr, "wait ack fail (%d)\n", ret);
			goto error;
		}
	}

error:
	if (callback)
		nl_cb_put(callback);

	if (msg)
		nlmsg_free(msg);

	return ret;
}

int mtk_efuse_nl_read(uint32_t field, uint8_t *data, uint32_t len)
{
	struct mtk_efuse_nl_attr_t attr = { 0 };

	attr.field = field;
	attr.data = data;
	attr.len = len;

	return mtk_efuse_nl_request(MTK_EFUSE_NL_CMD_READ, split_attrs,
				    construct_attrs, &attr);
}

int mtk_efuse_nl_write(uint32_t field, uint8_t *data, uint32_t len)
{
	struct mtk_efuse_nl_attr_t attr = { 0 };

	attr.field = field;
	attr.data = data;
	attr.len = len;

	return mtk_efuse_nl_request(MTK_EFUSE_NL_CMD_WRITE, NULL,
				    construct_attrs, &attr);
}

int mtk_efuse_nl_get_len(uint32_t field, uint32_t *len)
{
	struct mtk_efuse_nl_attr_t attr = { 0 };

	attr.field = field;
	attr.data = (uint8_t *)len;
	attr.len = sizeof(*len);

	return mtk_efuse_nl_request(MTK_EFUSE_NL_CMD_GET_LEN, split_attrs,
				    construct_attrs, &attr);
}

int mtk_efuse_nl_update_ar_ver(void)
{
	return mtk_efuse_nl_request(MTK_EFUSE_NL_CMD_UPDATE_AR_VER, NULL,
				    NULL, NULL);
}
