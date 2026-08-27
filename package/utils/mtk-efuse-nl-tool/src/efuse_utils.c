// SPDX-License-Identifier: BSD-2-Clause
/*
 * Copyright (C) 2024 MediaTek Incorporation. All Rights Reserved.
 *
 */

#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

int get_file_size(char *file, long *size)
{
	int ret = 0;
	FILE *fp = NULL;
	long sz = 0;

	/* open file */
	fp = fopen(file, "rb");
	if (!fp) {
		fprintf(stderr, "unable to open file\n");
		return -ENOENT;
	}

	/* get file length */
	if (fseek(fp, 0, SEEK_END)) {
		fprintf(stderr, "unable to seek to end of file\n");
		ret = -ferror(fp);
		goto end;
	}

	sz = ftell(fp);
	if (sz < 0) {
		fprintf(stderr, "unable to get the size of file\n");
		ret = -ferror(fp);
		goto end;
	}

	*size = sz;

end:
	fclose(fp);

	return ret;
}

int read_file(char *file, void *buffer, uint32_t length)
{
	int ret = 0;
	FILE *fp = NULL;
	long sz = 0;
	size_t len = 0;

	/* open file */
	fp = fopen(file, "rb");
	if (!fp) {
		fprintf(stderr, "unable to open file\n");
		return -1;
	}

	/* get file length */
	if (fseek(fp, 0, SEEK_END)) {
		fprintf(stderr, "unable to seek to end of file\n");
		ret = -ferror(fp);
		goto end;
	}

	sz = ftell(fp);
	if (sz < 0) {
		fprintf(stderr, "unable to get the size of file\n");
		ret = -ferror(fp);
		goto end;
	}
	rewind(fp);

	/* check file length */
	if (sz != length) {
		fprintf(stderr, "file size is not equal to field length\n");
		ret = -EINVAL;
		goto end;
	}

	memset(buffer, 0x0, length);
	len = fread(buffer, 1, length, fp);
	if (len != length)
		ret = -ferror(fp);

end:
	fclose(fp);

	return ret;
}
