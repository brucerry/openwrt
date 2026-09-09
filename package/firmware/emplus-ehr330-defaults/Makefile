include $(TOPDIR)/rules.mk

PKG_NAME:=emplus-ehr330-defaults
PKG_RELEASE:=1
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Build/Compile
endef

define Package/emplus-ehr330-defaults
  SECTION:=base
  CATEGORY:=Base system
  TITLE:=Emplus EHR330 first-boot defaults
  DEPENDS:=+wpad-basic-mbedtls
endef

Package/emplus-ehr330-defaults/install = $(INSTALL_DIR) $(1)/etc/uci-defaults; $(INSTALL_BIN) ./files/99-emplus-ehr330-wireless $(1)/etc/uci-defaults/

$(eval $(call BuildPackage,emplus-ehr330-defaults))
