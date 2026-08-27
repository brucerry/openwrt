/* SPDX-License-Identifier: BSD-2-Clause */
/*
 * Copyright (C) 2021 MediaTek Incorporation. All Rights Reserved.
 *
 * Author: Alvin Kuo <Alvin.Kuo@mediatek.com>
 */
#ifndef __MTK_EFUSE_H__
#define __MTK_EFUSE_H__

#include <stdint.h>

#define MTK_EFUSE_TOOL_VERSION		0x2

/*********************************************************************************
 *
 *  efuse data in user space
 *
 ********************************************************************************/
struct mtk_efuse_field_t {
	uint32_t field;
	uint32_t len;
};

struct mtk_efuse_group_t;

struct mtk_efuse_group_oper_t {
	int (*prepare_write)(int argc, char *argv[], const struct mtk_efuse_group_t *group,
			     uint8_t *data, uint32_t len);
	int (*read)(struct mtk_efuse_field_t *fields, const uint32_t fields_num,
		    uint8_t *data, uint32_t len);
	int (*write)(struct mtk_efuse_field_t *fields, const uint32_t fields_num,
		     uint8_t *data, uint32_t len);
	int (*post_read)(const struct mtk_efuse_group_t *group, uint8_t *data, uint32_t len);
};

struct mtk_efuse_group_t {
	uint32_t id;
	struct mtk_efuse_group_oper_t oper;
	uint32_t fields_num;
	struct mtk_efuse_field_t *fields;
};

struct mtk_efuse_cmd_t;

struct mtk_efuse_cmd_oper_t {
	int (*find_group)(int argc, char *argv[], const struct mtk_efuse_cmd_t *cmd,
			  const struct mtk_efuse_group_t **group);
};

struct mtk_efuse_cmd_t {
	char name[4];
	struct mtk_efuse_cmd_oper_t oper;
	uint32_t groups_num;
	const struct mtk_efuse_group_t *groups;
};

#define EFUSE_FIELD(_field)					\
	{ .field = _EFUSE_##_field }

#define EFUSE_GROUP_FIELDS(_id, ...)				\
	static struct mtk_efuse_field_t (_id##_fields)[] = { __VA_ARGS__ }

#define EFUSE_GROUP_BOOL(_id)					\
	{							\
		.id = (_EFUSE_GROUP_##_id),			\
		.oper = {					\
			.prepare_write = prepare_blow_write,	\
			.read = mtk_efuse_read,			\
			.write = mtk_efuse_write,		\
			.post_read = post_blown_read,		\
		},						\
		.fields_num = ARRAY_SIZE((_id##_fields)),	\
		.fields = (_id##_fields)			\
	}

#define EFUSE_GROUP(_id, ...)					\
	{							\
		.id = (_EFUSE_GROUP_##_id),			\
		.oper = { __VA_ARGS__ },			\
		.fields_num = ARRAY_SIZE((_id##_fields)),	\
		.fields = (_id##_fields)			\
	}

#define EFUSE_CMD_GROUPS(_name, ...)				\
	static const struct mtk_efuse_group_t (_name##_groups)[] = { __VA_ARGS__ }

#define EFUSE_CMD(_name, _find_group)				\
	{							\
		.name = (#_name),				\
		.oper = {					\
			.find_group = _find_group,		\
		},						\
		.groups_num = ARRAY_SIZE((_name##_groups)),	\
		.groups = (_name##_groups)			\
	}

int find_efuse_cmd(int argc, char *argv[], const struct mtk_efuse_cmd_t **cmd);
int find_group(int argc, char *argv[], const struct mtk_efuse_cmd_t *cmd,
	       const struct mtk_efuse_group_t **group);
int mtk_efuse_read(struct mtk_efuse_field_t *fields, const uint32_t fields_num,
		   uint8_t *data, uint32_t len);
int mtk_efuse_write(struct mtk_efuse_field_t *fields, const uint32_t fields_num,
		    uint8_t *data, uint32_t len);
int prepare_blow_write(int argc, char *argv[], const struct mtk_efuse_group_t *group,
		       uint8_t *data, uint32_t len);
int post_blown_read(const struct mtk_efuse_group_t *group, uint8_t *data, uint32_t len);
int post_value_read(const struct mtk_efuse_group_t *group, uint8_t *data, uint32_t len);

#endif /* __MTK_EFUSE_H__ */
