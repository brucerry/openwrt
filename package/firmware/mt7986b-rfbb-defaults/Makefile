include $(TOPDIR)/rules.mk

PKG_NAME:=mt7986b-rfbb-defaults
PKG_RELEASE:=1
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Build/Compile
endef

define Package/mt7986b-rfbb-defaults
  SECTION:=base
  CATEGORY:=Base system
  TITLE:=MT7986B RFBB first-boot defaults
  DEPENDS:=+wpad-basic-mbedtls
endef

define Package/mt7986b-rfbb-defaults/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/99-mt7986b-rfbb-wireless $(1)/etc/uci-defaults/
endef

$(eval $(call BuildPackage,mt7986b-rfbb-defaults))
