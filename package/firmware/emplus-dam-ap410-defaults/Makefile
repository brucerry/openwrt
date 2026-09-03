include $(TOPDIR)/rules.mk

PKG_NAME:=emplus-dam-ap410-defaults
PKG_RELEASE:=1
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Build/Compile
endef

define Package/emplus-dam-ap410-defaults
  SECTION:=base
  CATEGORY:=Base system
  TITLE:=Emplus DAM-AP410 first-boot defaults
  DEPENDS:=+wpad-basic-mbedtls
endef

define Package/emplus-dam-ap410-defaults/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/99-emplus-dam-ap410-wireless $(1)/etc/uci-defaults/
endef

$(eval $(call BuildPackage,emplus-dam-ap410-defaults))