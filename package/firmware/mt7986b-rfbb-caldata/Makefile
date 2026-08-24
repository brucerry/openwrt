include $(TOPDIR)/rules.mk

PKG_NAME:=mt7986b-rfbb-caldata
PKG_RELEASE:=1
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Build/Compile
endef

define Package/mt7986b-rfbb-caldata
  SECTION:=firmware
  CATEGORY:=Firmware
  TITLE:=MT7986B RFBB MT7975 calibration data
  DEPENDS:=+kmod-mt7915e
endef

define Package/mt7986b-rfbb-caldata/install
	$(INSTALL_DIR) $(1)/lib/firmware/mediatek
	$(INSTALL_DATA) ./files/mt7986_eeprom_mt7975_dual.bin \
		$(1)/lib/firmware/mediatek/
endef

$(eval $(call BuildPackage,mt7986b-rfbb-caldata))
