// SPDX-License-Identifier: BSD-2-Clause
/*
 * Copyright (C) 2021 MediaTek Incorporation. All Rights Reserved.
 *
 * Author: Alvin Kuo <Alvin.Kuo@mediatek.com>
 */

#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "efuse_nl.h"
#include "mtk_efuse.h"

int find_group(int argc, char *argv[], const struct mtk_efuse_cmd_t *cmd,
	       const struct mtk_efuse_group_t **group)
{
	int ret = 0;

	if (cmd->groups_num && cmd->groups[0].id)
		*group = &cmd->groups[0];
	else
		ret = -EINVAL;

	return ret;
}

int mtk_efuse_read(struct mtk_efuse_field_t *fields,
		   const uint32_t fields_num,
		   uint8_t *data, uint32_t len)
{
	int ret;
	uint32_t i;
	uint32_t l = 0;

	for (i = 0; i < fields_num; i++) {
		ret = mtk_efuse_nl_read(fields[i].field, data + l, fields[i].len);
		if (ret)
			return ret;

		l += fields[i].len;
	}

	return 0;
}

int mtk_efuse_write(struct mtk_efuse_field_t *fields,
		    const uint32_t fields_num,
		    uint8_t *data, uint32_t len)
{
	int ret;
	uint32_t i;
	uint32_t l = 0;

	for (i = 0; i < fields_num; i++) {
		ret = mtk_efuse_nl_write(fields[i].field, data + l, fields[i].len);
		if (ret)
			return ret;

		l += fields[i].len;
	}

	return 0;
}

int prepare_blow_write(int argc, char *argv[],
		       const struct mtk_efuse_group_t *group,
		       uint8_t *data, uint32_t len)
{
	uint32_t i;

	for (i = 0; i < len; i++)
		data[i] = 0x1;

	return 0;
}

int post_value_read(const struct mtk_efuse_group_t *group,
		    uint8_t *data, uint32_t len)
{
	uint32_t i;

	for (i = 0; i < len; i++) {
		if (i % 16 == 0)
			printf("\n%08x ", i);
		if (i % 8 == 0)
			printf(" ");
		printf("%02x ", data[i]);
	}
	printf("\n");

	return 0;
}

int post_blown_read(const struct mtk_efuse_group_t *group,
		    uint8_t *data, uint32_t len)
{
	uint32_t i;
	uint8_t res = 1;
	uint8_t blown = 0;

	for (i = 0; i < len; i++) {
		if (data[i])
			blown = 1;
		res &= data[i];
	}

	if (res) {
		printf("blown\n");
	} else if (!res && !blown) {
		printf("unblown\n");
	} else {
		fprintf(stderr, "field status are inconsistent\n");
		post_value_read(group, data, len);
	}

	return 0;
}

static int find_efuse_group(int argc, char *argv[],
			    const struct mtk_efuse_group_t **group)
{
	int ret;
	const struct mtk_efuse_cmd_t *cmd = NULL;

	ret = find_efuse_cmd(argc, argv, &cmd);
	if (ret) {
		fprintf(stderr, "Unknown command: %s\n", argv[1]);
		return ret;
	}

	if (!cmd->oper.find_group) {
		fprintf(stderr, "Invalid find_group()\n");
		return -EINVAL;
	}

	ret = cmd->oper.find_group(argc, argv, cmd, group);
	if (ret) {
		fprintf(stderr, "Cannot find efuse group(%d) for cmd(%s)\n", ret, cmd->name);
		return ret;
	}

	return 0;
}

static int get_data_len(struct mtk_efuse_field_t *fields,
			const uint32_t fields_num, uint32_t *length)
{
	int ret;
	uint32_t i;
	uint32_t len = 0;

	for (i = 0; i < fields_num; i++) {
		ret = mtk_efuse_nl_get_len(fields[i].field, &fields[i].len);
		if (ret)
			return ret;

		len += fields[i].len;
	}

	*length = len;

	return 0;
}

int main(int argc, char *argv[])
{
	int ret = 0;
	char *cmd;
	const struct mtk_efuse_group_t *group = NULL;
	uint8_t *data = NULL;
	uint32_t len = 0;

#ifdef PLAT
	printf("Platform: %s\n", PLAT);
#endif

	if (argc < 3) {
		fprintf(stderr, "too few arguments\n");
		return -EINVAL;
	}

	cmd = argv[1];
	ret = find_efuse_group(argc, argv, &group);
	if (ret)
		return ret;

	ret = mtk_efuse_nl_init();
	if (ret) {
		fprintf(stderr, "netlink init fail(%d)\n", ret);
		goto exit;
	}

	ret = get_data_len(group->fields, group->fields_num, &len);
	if (ret) {
		fprintf(stderr, "Invalid data length(%d) for group(%u)\n",
			ret, group->id);
		return -EINVAL;
	}

	data = calloc(len, sizeof(uint8_t));
	if (!data)
		return -ENOMEM;

	if (!strncmp(argv[2], "r", 1)) {
		if (!group->oper.read) {
			fprintf(stderr, "Invalid read()\n");
			ret = -EINVAL;
			goto exit;
		}

		ret = group->oper.read(group->fields, group->fields_num, data, len);
		if (ret) {
			fprintf(stderr, "Read command failed(%d) for group(%u)\n",
				ret, group->id);
			goto exit;
		}

		printf("%s: ", cmd);

		if (!group->oper.post_read) {
			fprintf(stderr, "Invalid post_read()\n");
			ret = -EINVAL;
			goto exit;
		}

		ret = group->oper.post_read(group, data, len);
		if (ret) {
			fprintf(stderr, "Post read failed(%d) for group(%u)\n",
				ret, group->id);
			goto exit;
		}
	} else if (!strncmp(argv[2], "w", 1)) {
		if (!group->oper.prepare_write) {
			fprintf(stderr, "Invalid perpare_write()\n");
			ret = -EINVAL;
			goto exit;
		}

		ret = group->oper.prepare_write(argc, argv, group, data, len);
		if (ret) {
			fprintf(stderr, "Prepare write failed(%d) for group(%u)\n",
				ret, group->id);
			goto exit;
		}

		if (!group->oper.write) {
			fprintf(stderr, "Invalid write()\n");
			ret = -EINVAL;
			goto exit;
		}

		ret = group->oper.write(group->fields, group->fields_num, data, len);
		if (ret) {
			fprintf(stderr, "Write command failed(%d) for group(%u)\n",
				ret, group->id);
			goto exit;
		}
	} else {
		fprintf(stderr, "Invalid operation(%s)\n", argv[2]);
		ret = -EINVAL;
		goto exit;
	}

	printf("\nefuse operate (%s) success\n", cmd);

exit:
	if (data)
		free(data);

	mtk_efuse_nl_free();

	return ret;
}
