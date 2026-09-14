#
# Copyright (c) 2026, MediaTek Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

ifeq ($(TA_ENC),1)
BL31_SOURCES		+=	$(APSOC_COMMON)/img_dec/ta/ta_key.c

BL31_CPPFLAGS		+=	-I$(APSOC_COMMON)/img_dec/ta/ \
				-DMTK_TA_ENC

endif
