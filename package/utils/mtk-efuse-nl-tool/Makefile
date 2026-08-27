#
# Copyright (C) 2021 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=mtk-efuse-nl-tool
PKG_VERSION:=2.0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)-$(BUILD_VARIANT)
include $(INCLUDE_DIR)/package.mk

define mtk-efuse-nl-tool/Default
  BUILD_TARGET:=mediatek
  BUILD_SUBTARGET:=filogic
  BUILD_DEVICES:=
  NAME:=
  PLAT:=
  VARIANT:=$(1)
endef

define Build/mtk-efuse-nl-tool/Target
  $(eval $(call mtk-efuse-nl-tool/Default,$(1)))
  $(eval $(call mtk-efuse-nl-tool/$(1),$(1)))

  define Package/mtk-efuse-nl-tool-$(1)
    SECTION:=MTK Properties
    CATEGORY:=MTK Properties
    TITLE:=MTK eFuse tool for $(NAME)
    VARIANT:=$(VARIANT)
    SUBMENU:=Applications
    DEPENDS:=+libnl-tiny +kmod-mtk-efuse-nl-drv
  endef

  define Package/mtk-efuse-nl-tool-$(1)/install
	$$(Package/mtk-efuse-nl-tool/install)
  endef
endef

define Build/Configure/mtk-efuse-nl-tool
endef

TARGET_CFLAGS += \
	-D_GNU_SOURCE \
	-I$(STAGING_DIR)/usr/include/libnl-tiny \
	-I$(PKG_BUILD_DIR)

define Build/Compile/mtk-efuse-nl-tool
	$(MAKE) -C $(PKG_BUILD_DIR) \
		PLAT=$(PLAT) \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS) -Wall" \
		LDFLAGS="$(TARGET_LDFLAGS) -lnl-tiny -lm"
endef

define Package/mtk-efuse-nl-tool/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/mtk-efuse-tool $(1)/usr/sbin/mtk-efuse-tool-$(BUILD_VARIANT)
endef

define BuildPackage/mtk-efuse-nl-tool/Defaults
  Build/Configure/Default = $$$$(Build/Configure/mtk-efuse-nl-tool)
  Build/Compile/Default = $$$$(Build/Compile/mtk-efuse-nl-tool)
endef

define BuildPackage/mtk-efuse-nl-tool
  $(eval $(call BuildPackage/mtk-efuse-nl-tool/Defaults))
  $(foreach type,$(if $(DUMP),$(EFUSE_TOOL_TARGETS),$(BUILD_VARIANT)), \
    $(eval $(call Build/mtk-efuse-nl-tool/Target,$(type)))
  )
  $(eval $(call Build/DefaultTargets))
  $(foreach type,$(if $(DUMP),$(EFUSE_TOOL_TARGETS),$(BUILD_VARIANT)), \
    $(call BuildPackage,mtk-efuse-nl-tool-$(type))
  )
endef

define mtk-efuse-nl-tool/mt7981
  BUILD_DEVICES:=mediatek_mt7981-rfb
  NAME:=MediaTek MT7981
  PLAT:=mt7981
endef

define mtk-efuse-nl-tool/mt7986
  BUILD_DEVICES:=mediatek_mt7986a-rfb mediatek_mt7986b-rfb
  NAME:=MediaTek MT7986
  PLAT:=mt7986
endef

define mtk-efuse-nl-tool/mt7987
  BUILD_DEVICES:=mediatek_mt7987a-rfb
  NAME:=MediaTek MT7987
  PLAT:=mt7987
endef

define mtk-efuse-nl-tool/mt7988
  BUILD_DEVICES:=mediatek_mt7988a-rfb mediatek_mt7988d-rfb
  NAME:=MediaTek MT7988
  PLAT:=mt7988
endef

EFUSE_TOOL_TARGETS:= \
	mt7981 \
	mt7986 \
	mt7987 \
	mt7988

$(eval $(call BuildPackage/mtk-efuse-nl-tool))
