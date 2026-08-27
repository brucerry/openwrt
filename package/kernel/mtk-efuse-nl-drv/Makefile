#
# Copyright (C) 2008-2012 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=mtk-efuse-nl-drv
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define KernelPackage/mtk-efuse-nl-drv
  SECTION:=MTK Properties
  CATEGORY:=MTK Properties
  TITLE:=MTK eFuse driver
  SUBMENU:=Drivers
  FILES:=$(PKG_BUILD_DIR)/mtk_efuse.ko
  AUTOLOAD:=$(call AutoLoad,81,mtk_efuse)
endef

define KernelPackage/mtk-efuse-nl-drv/description
  MTK eFuse driver
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
