#
# Copyright (C) 2008-2012 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=mtk-efuse-nl-drv
PKG_RELEASE:=2

include $(INCLUDE_DIR)/package.mk

define KernelPackage/mtk-efuse-nl-drv
  SECTION:=MTK Properties
  CATEGORY:=MTK Properties
  TITLE:=MTK eFuse driver
  DEPENDS:=@TARGET_mediatek_filogic
  SUBMENU:=Drivers
  FILES:=$(PKG_BUILD_DIR)/mtk_efuse.ko
endef

define KernelPackage/mtk-efuse-nl-drv/description
  MediaTek eFuse SMC/netlink provisioning driver, version 2.0.
  Load manually for manufacturing diagnostics; do not ship in regular releases.
endef

MAKE_OPTS:= \
	$(KERNEL_MAKE_FLAGS) \
	M="$(PKG_BUILD_DIR)" \
	EXTRA_CFLAGS="$(EXTRA_CFLAGS)" \
	$(EXTRA_KCONFIG)

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" \
		$(MAKE_OPTS) \
		modules
endef

$(eval $(call KernelPackage,mtk-efuse-nl-drv))
