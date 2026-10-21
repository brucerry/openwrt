include $(TOPDIR)/rules.mk

PKG_NAME:=ews276-fit-eeprom
PKG_RELEASE:=1
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/ews276-fit-eeprom
  SECTION:=firmware
  CATEGORY:=Firmware
  TITLE:=EWS276-FIT MT7986 dual-MT7975 EEPROM template
  DEPENDS:=@TARGET_mediatek_filogic +kmod-mt7915e
endef

define Package/ews276-fit-eeprom/description
 EEPROM fallback from the EWS276-FIT vendor firmware for RAM bring-up.
 Production RF calibration and unique MAC provisioning remain unqualified.
endef

define Build/Compile
	$(MKHASH) sha256 ./files/MT7986_iPAiLNA_EEPROM_AX6000.bin | \
		grep -qx aaf433cd1bd91f04f33ad7fdb667fdf0a2f14e61262ce407361b62724bb04ef9
endef

define Package/ews276-fit-eeprom/install
	$(INSTALL_DIR) $(1)/lib/firmware/mediatek
	$(INSTALL_DATA) ./files/MT7986_iPAiLNA_EEPROM_AX6000.bin \
		$(1)/lib/firmware/mediatek/mt7986_eeprom_mt7975_dual.bin
endef

$(eval $(call BuildPackage,ews276-fit-eeprom))
