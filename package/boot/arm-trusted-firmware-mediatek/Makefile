#
# Copyright (C) 2017 Hauke Mehrtens
# Copyright (C) 2021-2023 Daniel Golle
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=arm-trusted-firmware-mediatek
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL=https://github.com/mtk-openwrt/arm-trusted-firmware.git
PKG_SOURCE_DATE:=2025-07-11
PKG_SOURCE_VERSION:=78a0dfd927bb00ce973a1f8eb4079df0f755887a
PKG_MIRROR_HASH:=72a5f3f00f9e368226bb779dc098aac6195a312b48cc22172987d494ccd135d1

PKG_MAINTAINER:=Daniel Golle <daniel@makrotopia.org>

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/trusted-firmware-a.mk
include $(INCLUDE_DIR)/package.mk

# Vendored, isolated MbedTLS source used only for trusted board boot (TF-A
# authentication/crypto). Pinned upstream release, fetched by our own build
# system (no external SDK / manual download step required). Kept separate
# from the target mbedtls package to avoid PSA-crypto config conflicts.
MBEDTLS_TFA_NAME:=mbedtls-tfa
MBEDTLS_TFA_RELEASE:=3.6.7
MBEDTLS_TFA_SOURCE:=$(MBEDTLS_TFA_NAME)-$(MBEDTLS_TFA_RELEASE).tar.zst

define Download/mbedtls-tfa
  FILE:=$(MBEDTLS_TFA_SOURCE)
  PROTO:=git
  URL:=https://github.com/Mbed-TLS/mbedtls.git
  SOURCE_VERSION:=da6a8c7b9b8e0c1e236deef2910642657db1a7ec
  MIRROR_HASH:=a252825a202e11250846cfde926e116efa987e9189b8a6752a644c934abf8267
  SUBDIR:=$(MBEDTLS_TFA_NAME)-$(MBEDTLS_TFA_RELEASE)
endef

define Build/Prepare
	$(eval $(call Download,mbedtls-tfa))
	$(call Build/Prepare/Default,)
ifneq ($(strip $(TFA_TRUSTED_BOARD_BOOT)),)
	$(TAR) -C $(PKG_BUILD_DIR) -xf $(DL_DIR)/$(MBEDTLS_TFA_SOURCE)
endif
endef

define Trusted-Firmware-A/Default
  BUILD_TARGET:=mediatek
  TFA_IMAGE:=bl2.img bl31.bin
  HIDDEN:=y
  BOOT_DEVICE:=
  DDR3_FLYBY:=
  DDR3_FREQ_1866:=
  DDR4_4BG_MODE:=
  DDR_TYPE:=
  NAND_TYPE:=
  BOARD_QFN:=
  DRAM_USE_COMB:=
  RAM_BOOT_UART_DL:=
  USE_UBI:=
  FIP_OFFSET:=
  FIP_SIZE:=
  SPIM_CTRL:=
  TFA_TRUSTED_BOARD_BOOT:=
  TFA_GENERATE_COT:=
  TFA_OFFLINE_SIGN:=
  TFA_ANTI_ROLLBACK:=
  TFA_ROT_KEY:=
  TFA_BROM_SIGN_KEY:=
  TFA_SCP_BL2_KEY:=
  TFA_TRUSTED_WORLD_KEY:=
  TFA_NON_TRUSTED_WORLD_KEY:=
  TFA_BL31_KEY:=
  TFA_BL32_KEY:=
  TFA_BL33_KEY:=
  TFA_ANTI_ROLLBACK_TABLE:=
  TFA_MBEDTLS_DIR:=
  TFA_KEY_ALG:=
  TFA_HASH_ALG:=
  TFA_E:=
endef

define Trusted-Firmware-A/mt7622-nor-1ddr
  NAME:=MediaTek MT7622 (SPI-NOR, 1x DDR3)
  BUILD_SUBTARGET:=mt7622
  PLAT:=mt7622
  BOOT_DEVICE:=nor
endef

define Trusted-Firmware-A/mt7622-nor-2ddr
  NAME:=MediaTek MT7622 (SPI-NOR, 2x DDR3)
  BUILD_SUBTARGET:=mt7622
  PLAT:=mt7622
  BOOT_DEVICE:=nor
  DDR3_FLYBY:=1
endef

define Trusted-Firmware-A/mt7622-ram-1ddr
  NAME:=MediaTek MT7622 (RAM, 1x DDR3)
  BOOT_DEVICE:=ram
  BUILD_SUBTARGET:=mt7622
  PLAT:=mt7622
  RAM_BOOT_UART_DL:=1
  HIDDEN:=
  DEFAULT:=TARGET_mediatek_mt7622
endef

define Trusted-Firmware-A/mt7622-ram-2ddr
  NAME:=MediaTek MT7622 (RAM, 2x DDR3)
  BOOT_DEVICE:=ram
  BUILD_SUBTARGET:=mt7622
  PLAT:=mt7622
  DDR3_FLYBY:=1
  RAM_BOOT_UART_DL:=1
  HIDDEN:=
  DEFAULT:=TARGET_mediatek_mt7622
endef

define Trusted-Firmware-A/mt7622-snand-1ddr
  NAME:=MediaTek MT7622 (SPI-NAND, 1x DDR3)
  BUILD_SUBTARGET:=mt7622
  PLAT:=mt7622
  BOOT_DEVICE:=snand
endef

define Trusted-Firmware-A/mt7622-snand-ubi-1ddr
  NAME:=MediaTek MT7622 (SPI-NAND using UBI, 1x DDR3)
  BUILD_SUBTARGET:=mt7622
  PLAT:=mt7622
  BOOT_DEVICE:=snand
  USE_UBI:=1
endef

define Trusted-Firmware-A/mt7622-snand-2ddr
  NAME:=MediaTek MT7622 (SPI-NAND, 2x DDR3)
  BUILD_SUBTARGET:=mt7622
  PLAT:=mt7622
  BOOT_DEVICE:=snand
  DDR3_FLYBY:=1
endef

define Trusted-Firmware-A/mt7622-snand-ubi-2ddr
  NAME:=MediaTek MT7622 (SPI-NAND using UBI, 2x DDR3)
  BUILD_SUBTARGET:=mt7622
  PLAT:=mt7622
  BOOT_DEVICE:=snand
  DDR3_FLYBY:=1
  USE_UBI:=1
endef

define Trusted-Firmware-A/mt7622-emmc-1ddr
  NAME:=MediaTek MT7622 (eMMC, 1x DDR3)
  BUILD_SUBTARGET:=mt7622
  PLAT:=mt7622
  BOOT_DEVICE:=emmc
endef

define Trusted-Firmware-A/mt7622-emmc-2ddr
  NAME:=MediaTek MT7622 (eMMC, 2x DDR3)
  BUILD_SUBTARGET:=mt7622
  PLAT:=mt7622
  BOOT_DEVICE:=emmc
  DDR3_FLYBY:=1
endef

define Trusted-Firmware-A/mt7622-sdmmc-1ddr
  NAME:=MediaTek MT7622 (SD card, 1x DDR3)
  BUILD_SUBTARGET:=mt7622
  PLAT:=mt7622
  BOOT_DEVICE:=sdmmc
endef

define Trusted-Firmware-A/mt7622-sdmmc-2ddr
  NAME:=MediaTek MT7622 (SD card, 2x DDR3)
  BUILD_SUBTARGET:=mt7622
  PLAT:=mt7622
  BOOT_DEVICE:=sdmmc
  DDR3_FLYBY:=1
endef

define Trusted-Firmware-A/mt7981-nor-ddr4
  NAME:=MediaTek MT7981 (SPI-NOR, DDR4)
  BOOT_DEVICE:=nor
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7981
  DDR_TYPE:=ddr4
endef

define Trusted-Firmware-A/mt7981-ram-ddr4
  NAME:=MediaTek MT7981 (RAM, DDR4)
  BOOT_DEVICE:=ram
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7981
  DDR_TYPE:=ddr4
  RAM_BOOT_UART_DL:=1
  HIDDEN:=
  DEFAULT:=TARGET_mediatek_filogic
endef

define Trusted-Firmware-A/mt7981-emmc-ddr4
  NAME:=MediaTek MT7981 (eMMC, DDR4)
  BOOT_DEVICE:=emmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7981
  DDR_TYPE:=ddr4
endef

define Trusted-Firmware-A/mt7981-sdmmc-ddr4
  NAME:=MediaTek MT7981 (SD card, DDR4)
  BOOT_DEVICE:=sdmmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7981
  DDR_TYPE:=ddr4
endef

define Trusted-Firmware-A/mt7981-spim-nand-ddr4
  NAME:=MediaTek MT7981 (SPI-NAND via SPIM, DDR4)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7981
  DDR_TYPE:=ddr4
endef

# Dedicated secure-boot variant for Emplus DAM-AP410 only; keeps the shared
# mt7981-spim-nand-ddr4 variant (used by other MT7981 boards) unaffected.
define Trusted-Firmware-A/mt7981-dam-ap410-ddr4
  NAME:=MediaTek MT7981 (Emplus DAM-AP410, secure boot)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7981
  DDR_TYPE:=ddr4
  TFA_TRUSTED_BOARD_BOOT:=1
  TFA_GENERATE_COT:=1
  TFA_ROT_KEY:=$(TOPDIR)/keys/mtk-secure-boot/fip_private_key.pem
  TFA_BROM_SIGN_KEY:=$(TOPDIR)/keys/mtk-secure-boot/bl2_private_key.pem
  TFA_TRUSTED_WORLD_KEY:=$(TOPDIR)/keys/mtk-secure-boot/trusted_private_key.pem
  TFA_NON_TRUSTED_WORLD_KEY:=$(TOPDIR)/keys/mtk-secure-boot/non_trusted_private_key.pem
  TFA_BL31_KEY:=$(TOPDIR)/keys/mtk-secure-boot/soc_fw_private_key.pem
  TFA_BL33_KEY:=$(TOPDIR)/keys/mtk-secure-boot/nt_fw_private_key.pem
endef

define Trusted-Firmware-A/mt7981-nor-ddr3
  NAME:=MediaTek MT7981 (SPI-NOR, DDR3)
  BOOT_DEVICE:=nor
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7981
  DDR_TYPE:=ddr3
endef

define Trusted-Firmware-A/mt7981-ram-ddr3
  NAME:=MediaTek MT7981 (RAM, DDR3)
  BOOT_DEVICE:=ram
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7981
  DDR_TYPE:=ddr3
  DDR3_FREQ_1866:=1
  RAM_BOOT_UART_DL:=1
  HIDDEN:=
  DEFAULT:=TARGET_mediatek_filogic
endef

define Trusted-Firmware-A/mt7981-emmc-ddr3
  NAME:=MediaTek MT7981 (eMMC, DDR3)
  BOOT_DEVICE:=emmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7981
  DDR_TYPE:=ddr3
endef

define Trusted-Firmware-A/mt7981-emmc-ddr3-1866
  NAME:=MediaTek MT7981 (eMMC, DDR3 1866 MT/s)
  BOOT_DEVICE:=emmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7981
  DDR_TYPE:=ddr3
  DDR3_FREQ_1866:=1
endef

define Trusted-Firmware-A/mt7981-sdmmc-ddr3
  NAME:=MediaTek MT7981 (SD card, DDR3)
  BOOT_DEVICE:=sdmmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7981
  DDR_TYPE:=ddr3
endef

define Trusted-Firmware-A/mt7981-snand-ddr3
  NAME:=MediaTek MT7981 (SPI-NAND via SNFI, DDR3)
  BOOT_DEVICE:=snand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7981
  DDR_TYPE:=ddr3
endef

define Trusted-Firmware-A/mt7981-spim-nand-ddr3
  NAME:=MediaTek MT7981 (SPI-NAND via SPIM, DDR3)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7981
  DDR_TYPE:=ddr3
endef

define Trusted-Firmware-A/mt7981-spim-nand-ddr3-1866
  NAME:=MediaTek MT7981 (SPI-NAND via SPIM, DDR3 1866 MT/s)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7981
  DDR_TYPE:=ddr3
  DDR3_FREQ_1866:=1
endef

define Trusted-Firmware-A/mt7981-spim-nand-ubi-ddr3-1866
  NAME:=MediaTek MT7981 (SPI-NAND via SPIM, UBI, DDR3 1866 MT/s)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7981
  DDR_TYPE:=ddr3
  DDR3_FREQ_1866:=1
  USE_UBI:=1
endef

define Trusted-Firmware-A/mt7981-spim-nand-ubi-ddr4
  NAME:=MediaTek MT7981 (SPI-NAND via SPIM, DDR4)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7981
  DDR_TYPE:=ddr4
  USE_UBI:=1
endef

define Trusted-Firmware-A/mt7981-cudy-ddr3
  NAME:=Cudy (SPI-NAND via SPIM, DDR3 1866 MT/s)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7981
  DDR_TYPE:=ddr3
  DDR3_FREQ_1866:=1
  FIP_OFFSET:=0x3c0000
  FIP_SIZE:=0x200000
endef

define Trusted-Firmware-A/mt7981-cudy-ddr4
  NAME:=Cudy (SPI-NAND via SPIM, DDR4)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7981
  DDR_TYPE:=ddr4
  FIP_OFFSET:=0x3c0000
  FIP_SIZE:=0x200000
endef

define Trusted-Firmware-A/mt7986-ram-ddr4
  NAME:=MediaTek MT7986 (RAM, DDR4)
  BOOT_DEVICE:=ram
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7986
  DDR_TYPE:=ddr4
  RAM_BOOT_UART_DL:=1
  HIDDEN:=
  DEFAULT:=TARGET_mediatek_filogic
endef

define Trusted-Firmware-A/mt7986-nor-ddr4
  NAME:=MediaTek MT7986 (SPI-NOR, DDR4)
  BOOT_DEVICE:=nor
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7986
  DDR_TYPE:=ddr4
endef

define Trusted-Firmware-A/mt7986-emmc-ddr4
  NAME:=MediaTek MT7986 (eMMC, DDR4)
  BOOT_DEVICE:=emmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7986
  DDR_TYPE:=ddr4
endef

define Trusted-Firmware-A/mt7986-sdmmc-ddr4
  NAME:=MediaTek MT7986 (SD card, DDR4)
  BOOT_DEVICE:=sdmmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7986
  DDR_TYPE:=ddr4
endef

define Trusted-Firmware-A/mt7986-snand-ddr4
  NAME:=MediaTek MT7986 (SPI-NAND via SNFI, DDR4)
  BOOT_DEVICE:=snand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7986
  DDR_TYPE:=ddr4
endef

define Trusted-Firmware-A/mt7986-spim-nand-ddr4
  NAME:=MediaTek MT7986 (SPI-NAND via SPIM, DDR4)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7986
  DDR_TYPE:=ddr4
  NAND_TYPE:=spim:2k+64
endef

define Trusted-Firmware-A/mt7986-spim-nand-ubi-ddr4
  NAME:=MediaTek MT7986 (SPI-NAND via SPIM using UBI, DDR4)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7986
  DDR_TYPE:=ddr4
  NAND_TYPE:=spim:2k+64
  USE_UBI:=1
endef

define Trusted-Firmware-A/mt7986-spim-nand-4k-ddr4
  NAME:=MediaTek MT7986 (SPI-NAND 4k+256 via SPIM, DDR4)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7986
  DDR_TYPE:=ddr4
  NAND_TYPE:=spim:4k+256
endef

define Trusted-Firmware-A/mt7986-ram-ddr3
  NAME:=MediaTek MT7986 (RAM, DDR3)
  BOOT_DEVICE:=ram
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7986
  DDR_TYPE:=ddr3
  RAM_BOOT_UART_DL:=1
  HIDDEN:=
  DEFAULT:=TARGET_mediatek_filogic
endef

define Trusted-Firmware-A/mt7986-nor-ddr3
  NAME:=MediaTek MT7986 (SPI-NOR, DDR3)
  BOOT_DEVICE:=nor
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7986
  DDR_TYPE:=ddr3
endef

define Trusted-Firmware-A/mt7986-emmc-ddr3
  NAME:=MediaTek MT7986 (eMMC, DDR3)
  BOOT_DEVICE:=emmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7986
  DDR_TYPE:=ddr3
endef

define Trusted-Firmware-A/mt7986-sdmmc-ddr3
  NAME:=MediaTek MT7986 (SD card, DDR3)
  BOOT_DEVICE:=sdmmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7986
  DDR_TYPE:=ddr3
endef

define Trusted-Firmware-A/mt7986-snand-ddr3
  NAME:=MediaTek MT7986 (SPI-NAND via SNFI, DDR3)
  BOOT_DEVICE:=snand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7986
  DDR_TYPE:=ddr3
endef

define Trusted-Firmware-A/mt7986-spim-nand-ddr3
  NAME:=MediaTek MT7986 (SPI-NAND via SPIM, DDR3)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7986
  DDR_TYPE:=ddr3
endef

define Trusted-Firmware-A/mt7986-spim-nand-ubi-ddr3
  NAME:=MediaTek MT7986 (SPI-NAND via SPIM using UBI, DDR3)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7986
  DDR_TYPE:=ddr3
  USE_UBI:=1
endef

define Trusted-Firmware-A/mt7986-spim-nand-4k-ddr3
  NAME:=MediaTek MT7986 (SPI-NAND 4k+256 via SPIM, DDR3)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7986
  DDR_TYPE:=ddr3
  NAND_TYPE:=spim:4k+256
endef

define Trusted-Firmware-A/mt7987-emmc-comb
  NAME:=MediaTek MT7987 (eMMC)
  BOOT_DEVICE:=emmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7987
endef

define Trusted-Firmware-A/mt7987-emmc-ddr4-4bg
  NAME:=MediaTek MT7987 (eMMC, DDR4 4GB)
  BOOT_DEVICE:=emmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7987
  DDR4_4BG_MODE:=1
endef

define Trusted-Firmware-A/mt7987-nor-comb
  NAME:=MediaTek MT7987 (NOR)
  BOOT_DEVICE:=nor
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7987
endef

define Trusted-Firmware-A/mt7987-sdmmc-comb
  NAME:=MediaTek MT7987 (SD card)
  BOOT_DEVICE:=sdmmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7987
endef

define Trusted-Firmware-A/mt7987-sdmmc-ddr4-4bg
  NAME:=MediaTek MT7987 (SD card, DDR4 4GB)
  BOOT_DEVICE:=sdmmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7987
  DDR4_4BG_MODE:=1
endef

define Trusted-Firmware-A/mt7987-spim-nand0
  NAME:=MediaTek MT7987 (SPI-NAND via SPIM)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7987
  SPIM_CTRL:=0
endef

define Trusted-Firmware-A/mt7987-spim-nand0-ubi-comb
  NAME:=MediaTek MT7987 (SPI-NAND via SPIM, UBI)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7987
  USE_UBI:=1
  SPIM_CTRL:=0
endef

define Trusted-Firmware-A/mt7987-spim-nand2-ubi-comb
  NAME:=MediaTek MT7987 (SPI-NAND via SPIM, UBI)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7987
  USE_UBI:=1
  SPIM_CTRL:=2
endef

define Trusted-Firmware-A/mt7987-ram-comb
  NAME:=MediaTek MT7987 (RAM)
  BOOT_DEVICE:=ram
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7987
  RAM_BOOT_UART_DL:=1
  HIDDEN:=
  DEFAULT:=TARGET_mediatek_filogic
endef

define Trusted-Firmware-A/mt7988-nor-ddr3
  NAME:=MediaTek MT7988 (SPI-NOR, DDR3)
  BOOT_DEVICE:=nor
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DDR_TYPE:=ddr3
endef

define Trusted-Firmware-A/mt7988-emmc-ddr3
  NAME:=MediaTek MT7988 (eMMC, DDR3)
  BOOT_DEVICE:=emmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DDR_TYPE:=ddr3
endef

define Trusted-Firmware-A/mt7988-sdmmc-ddr3
  NAME:=MediaTek MT7988 (SD card, DDR3)
  BOOT_DEVICE:=sdmmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DDR_TYPE:=ddr3
endef

define Trusted-Firmware-A/mt7988-snand-ddr3
  NAME:=MediaTek MT7988 (SPI-NAND via SNFI, DDR3)
  BOOT_DEVICE:=snand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DDR_TYPE:=ddr3
endef

define Trusted-Firmware-A/mt7988-spim-nand-ddr3
  NAME:=MediaTek MT7988 (SPI-NAND via SPIM, DDR3)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DDR_TYPE:=ddr3
endef

define Trusted-Firmware-A/mt7988-nor-ddr4
  NAME:=MediaTek MT7988 (SPI-NOR, DDR4)
  BOOT_DEVICE:=nor
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DDR_TYPE:=ddr4
endef

define Trusted-Firmware-A/mt7988-emmc-ddr4
  NAME:=MediaTek MT7988 (eMMC, DDR4)
  BOOT_DEVICE:=emmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DDR_TYPE:=ddr4
endef

define Trusted-Firmware-A/mt7988-sdmmc-ddr4
  NAME:=MediaTek MT7988 (SD card, DDR4)
  BOOT_DEVICE:=sdmmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DDR_TYPE:=ddr4
endef

define Trusted-Firmware-A/mt7988-snand-ddr4
  NAME:=MediaTek MT7988 (SPI-NAND via SNFI, DDR4)
  BOOT_DEVICE:=snand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DDR_TYPE:=ddr4
endef

define Trusted-Firmware-A/mt7988-spim-nand-ddr4
  NAME:=MediaTek MT7988 (SPI-NAND via SPIM, DDR4)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DDR_TYPE:=ddr4
endef

define Trusted-Firmware-A/mt7988-ram-comb
  NAME:=MediaTek MT7988 (RAM)
  BOOT_DEVICE:=ram
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DRAM_USE_COMB:=1
  RAM_BOOT_UART_DL:=1
  HIDDEN:=
  DEFAULT:=TARGET_mediatek_filogic
endef

define Trusted-Firmware-A/mt7988-ram-ddr4
  NAME:=MediaTek MT7988 (RAM/ddr4)
  BOOT_DEVICE:=ram
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  RAM_BOOT_UART_DL:=1
  HIDDEN:=
  DEFAULT:=TARGET_mediatek_filogic
  DDR_TYPE:=ddr4
endef

define Trusted-Firmware-A/mt7988-nor-comb
  NAME:=MediaTek MT7988 (SPI-NOR)
  BOOT_DEVICE:=nor
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DRAM_USE_COMB:=1
endef

define Trusted-Firmware-A/mt7988-emmc-comb
  NAME:=MediaTek MT7988 (eMMC)
  BOOT_DEVICE:=emmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DRAM_USE_COMB:=1
endef

define Trusted-Firmware-A/mt7988-sdmmc-comb
  NAME:=MediaTek MT7988 (SD card)
  BOOT_DEVICE:=sdmmc
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DRAM_USE_COMB:=1
endef

define Trusted-Firmware-A/mt7988-snand-comb
  NAME:=MediaTek MT7988 (SPI-NAND via SNFI)
  BOOT_DEVICE:=snand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DRAM_USE_COMB:=1
endef

define Trusted-Firmware-A/mt7988-snand-ubi-comb
  NAME:=MediaTek MT7988 (SPI-NAND via SNFI, UBI)
  BOOT_DEVICE:=snand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DRAM_USE_COMB:=1
  USE_UBI:=1
endef

define Trusted-Firmware-A/mt7988-spim-nand-comb
  NAME:=MediaTek MT7988 (SPI-NAND via SPIM)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DRAM_USE_COMB:=1
endef

define Trusted-Firmware-A/mt7988-spim-nand-ubi-comb
  NAME:=MediaTek MT7988 (SPI-NAND via SPIM, UBI)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DRAM_USE_COMB:=1
  USE_UBI:=1
endef

define Trusted-Firmware-A/mt7988-spim-nand-ubi-ddr4
  NAME:=MediaTek MT7988 (SPI-NAND via SPIM, DDR4)
  BOOT_DEVICE:=spim-nand
  BUILD_SUBTARGET:=filogic
  PLAT:=mt7988
  DDR_TYPE:=ddr4
  USE_UBI:=1
endef

TFA_TARGETS:= \
	mt7622-nor-1ddr \
	mt7622-nor-2ddr \
	mt7622-ram-1ddr \
	mt7622-ram-2ddr \
	mt7622-snand-1ddr \
	mt7622-snand-ubi-1ddr \
	mt7622-snand-2ddr \
	mt7622-snand-ubi-2ddr \
	mt7622-emmc-1ddr \
	mt7622-emmc-2ddr \
	mt7622-sdmmc-1ddr \
	mt7622-sdmmc-2ddr \
	mt7981-ram-ddr3 \
	mt7981-emmc-ddr3 \
	mt7981-emmc-ddr3-1866 \
	mt7981-nor-ddr3 \
	mt7981-nor-ddr4 \
	mt7981-sdmmc-ddr3 \
	mt7981-snand-ddr3 \
	mt7981-spim-nand-ddr3 \
	mt7981-spim-nand-ddr3-1866 \
	mt7981-spim-nand-ubi-ddr3-1866 \
	mt7981-spim-nand-ubi-ddr4 \
	mt7981-ram-ddr4 \
	mt7981-emmc-ddr4 \
	mt7981-sdmmc-ddr4 \
	mt7981-spim-nand-ddr4 \
	mt7981-dam-ap410-ddr4 \
	mt7981-cudy-ddr3 \
	mt7981-cudy-ddr4 \
	mt7986-ram-ddr3 \
	mt7986-emmc-ddr3 \
	mt7986-nor-ddr3 \
	mt7986-sdmmc-ddr3 \
	mt7986-snand-ddr3 \
	mt7986-spim-nand-ddr3 \
	mt7986-spim-nand-ubi-ddr3 \
	mt7986-spim-nand-4k-ddr3 \
	mt7986-ram-ddr4 \
	mt7986-emmc-ddr4 \
	mt7986-nor-ddr4 \
	mt7986-sdmmc-ddr4 \
	mt7986-snand-ddr4 \
	mt7986-spim-nand-ddr4 \
	mt7986-spim-nand-ubi-ddr4 \
	mt7986-spim-nand-4k-ddr4 \
	mt7987-emmc-comb \
	mt7987-emmc-ddr4-4bg \
	mt7987-nor-comb \
	mt7987-sdmmc-comb \
	mt7987-sdmmc-ddr4-4bg \
	mt7987-spim-nand0 \
	mt7987-spim-nand0-ubi-comb \
	mt7987-spim-nand2-ubi-comb \
	mt7987-ram-comb \
	mt7988-emmc-ddr3 \
	mt7988-nor-ddr3 \
	mt7988-sdmmc-ddr3 \
	mt7988-snand-ddr3 \
	mt7988-spim-nand-ddr3 \
	mt7988-emmc-ddr4 \
	mt7988-nor-ddr4 \
	mt7988-sdmmc-ddr4 \
	mt7988-snand-ddr4 \
	mt7988-spim-nand-ddr4 \
	mt7988-ram-comb \
	mt7988-ram-ddr4 \
	mt7988-emmc-comb \
	mt7988-nor-comb \
	mt7988-sdmmc-comb \
	mt7988-snand-comb \
	mt7988-snand-ubi-comb \
	mt7988-spim-nand-comb \
	mt7988-spim-nand-ubi-comb \
	mt7988-spim-nand-ubi-ddr4

# Optional secure boot knobs passed from top-level make invocation, e.g.:
# make ... TFA_TRUSTED_BOARD_BOOT=1 TFA_GENERATE_COT=1 TFA_ROT_KEY=/abs/path/rot_key.pem
TFA_TRUSTED_BOARD_BOOT ?=
TFA_GENERATE_COT ?=
TFA_OFFLINE_SIGN ?=
TFA_ANTI_ROLLBACK ?=
TFA_ROT_KEY ?=
TFA_BROM_SIGN_KEY ?=
TFA_SCP_BL2_KEY ?=
TFA_TRUSTED_WORLD_KEY ?=
TFA_NON_TRUSTED_WORLD_KEY ?=
TFA_BL31_KEY ?=
TFA_BL32_KEY ?=
TFA_BL33_KEY ?=
TFA_ANTI_ROLLBACK_TABLE ?=
TFA_MBEDTLS_DIR ?=
TFA_KEY_ALG ?=
TFA_HASH_ALG ?=
TFA_E ?=

TFA_DAM_AP410_SECURE_FLAGS = \
	TRUSTED_BOARD_BOOT=1 GENERATE_COT=1 E=0 \
	ROT_KEY=$(TOPDIR)/keys/mtk-secure-boot/fip_private_key.pem \
	BROM_SIGN_KEY=$(TOPDIR)/keys/mtk-secure-boot/bl2_private_key.pem \
	TRUSTED_WORLD_KEY=$(TOPDIR)/keys/mtk-secure-boot/trusted_private_key.pem \
	NON_TRUSTED_WORLD_KEY=$(TOPDIR)/keys/mtk-secure-boot/non_trusted_private_key.pem \
	BL31_KEY=$(TOPDIR)/keys/mtk-secure-boot/soc_fw_private_key.pem \
	BL33_KEY=$(TOPDIR)/keys/mtk-secure-boot/nt_fw_private_key.pem \
	MBEDTLS_DIR=$(PKG_BUILD_DIR)/$(MBEDTLS_TFA_NAME)-$(MBEDTLS_TFA_RELEASE)

TFA_MAKE_FLAGS += \
	BOOT_DEVICE=$(BOOT_DEVICE) \
	$(if $(filter mt7981-dam-ap410-ddr4,$(BUILD_VARIANT)),,USE_MKIMAGE=1 MKIMAGE=$(STAGING_DIR_HOST)/bin/mkimage) \
	$(if $(findstring ddr4,$(DDR_TYPE)),DRAM_USE_DDR4=1) \
	$(if $(BOARD_QFN),BOARD_QFN=1,BOARD_BGA=1) \
	$(if $(NAND_TYPE),NAND_TYPE=$(NAND_TYPE)) \
	HAVE_DRAM_OBJ_FILE=yes \
	$(if $(DDR3_FLYBY),DDR3_FLYBY=1) \
	$(if $(DDR3_FREQ_1866),DDR3_FREQ_1866=1) \
	$(if $(DDR4_4BG_MODE),DDR4_4BG_MODE=1) \
	$(if $(DRAM_USE_COMB),DRAM_USE_COMB=1) \
	$(if $(RAM_BOOT_UART_DL),RAM_BOOT_UART_DL=1) \
	$(if $(USE_UBI),UBI=1 $(if $(findstring mt7622,$(PLAT)),OVERRIDE_UBI_START_ADDR=0x80000)) \
	$(if $(USE_UBI),UBI=1 $(if $(findstring mt7981,$(PLAT)),OVERRIDE_UBI_START_ADDR=0x100000)) \
	$(if $(USE_UBI),UBI=1 $(if $(findstring mt7986,$(PLAT)),OVERRIDE_UBI_START_ADDR=0x200000)) \
	$(if $(FIP_OFFSET),OVERRIDE_FIP_BASE=$(FIP_OFFSET)) \
	$(if $(FIP_SIZE),OVERRIDE_FIP_SIZE=$(FIP_SIZE)) \
	$(if $(SPIM_CTRL),SPIM_CTRL=$(SPIM_CTRL)) \
		$(if $(TFA_TRUSTED_BOARD_BOOT),TRUSTED_BOARD_BOOT=$(TFA_TRUSTED_BOARD_BOOT)) \
		$(if $(TFA_GENERATE_COT),GENERATE_COT=$(TFA_GENERATE_COT)) \
		$(if $(TFA_OFFLINE_SIGN),OFFLINE_SIGN=$(TFA_OFFLINE_SIGN)) \
		$(if $(TFA_ANTI_ROLLBACK),ANTI_ROLLBACK=$(TFA_ANTI_ROLLBACK)) \
		$(if $(TFA_ROT_KEY),ROT_KEY=$(TFA_ROT_KEY)) \
		$(if $(TFA_BROM_SIGN_KEY),BROM_SIGN_KEY=$(TFA_BROM_SIGN_KEY)) \
		$(if $(TFA_SCP_BL2_KEY),SCP_BL2_KEY=$(TFA_SCP_BL2_KEY)) \
		$(if $(TFA_TRUSTED_WORLD_KEY),TRUSTED_WORLD_KEY=$(TFA_TRUSTED_WORLD_KEY)) \
		$(if $(TFA_NON_TRUSTED_WORLD_KEY),NON_TRUSTED_WORLD_KEY=$(TFA_NON_TRUSTED_WORLD_KEY)) \
		$(if $(TFA_BL31_KEY),BL31_KEY=$(TFA_BL31_KEY)) \
		$(if $(TFA_BL32_KEY),BL32_KEY=$(TFA_BL32_KEY)) \
		$(if $(TFA_BL33_KEY),BL33_KEY=$(TFA_BL33_KEY)) \
		$(if $(TFA_ANTI_ROLLBACK_TABLE),ANTI_ROLLBACK_TABLE=$(TFA_ANTI_ROLLBACK_TABLE)) \
		$(if $(TFA_TRUSTED_BOARD_BOOT),MBEDTLS_DIR=$(if $(TFA_MBEDTLS_DIR),$(TFA_MBEDTLS_DIR),$(PKG_BUILD_DIR)/$(MBEDTLS_TFA_NAME)-$(MBEDTLS_TFA_RELEASE))) \
		$(if $(TFA_KEY_ALG),KEY_ALG=$(TFA_KEY_ALG)) \
		$(if $(TFA_HASH_ALG),HASH_ALG=$(TFA_HASH_ALG)) \
		$(if $(TFA_E),E=$(TFA_E),$(if $(TFA_TRUSTED_BOARD_BOOT),E=0)) \
		$(if $(filter mt7981-dam-ap410-ddr4,$(BUILD_VARIANT)),$(TFA_DAM_AP410_SECURE_FLAGS)) \
		$(if $(RAM_BOOT_UART_DL),bl2,all)

define Package/trusted-firmware-a-ram/install
	$(INSTALL_DIR) $(STAGING_DIR_IMAGE)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/build/$(PLAT)/release/bl2.bin $(BIN_DIR)/$(BUILD_VARIANT)-bl2.bin
endef
Package/trusted-firmware-a-mt7622-ram-1ddr/install = $(Package/trusted-firmware-a-ram/install)
Package/trusted-firmware-a-mt7622-ram-2ddr/install = $(Package/trusted-firmware-a-ram/install)
Package/trusted-firmware-a-mt7981-ram-ddr3/install = $(Package/trusted-firmware-a-ram/install)
Package/trusted-firmware-a-mt7981-ram-ddr4/install = $(Package/trusted-firmware-a-ram/install)
Package/trusted-firmware-a-mt7986-ram-ddr3/install = $(Package/trusted-firmware-a-ram/install)
Package/trusted-firmware-a-mt7986-ram-ddr4/install = $(Package/trusted-firmware-a-ram/install)
Package/trusted-firmware-a-mt7987-ram-comb/install = $(Package/trusted-firmware-a-ram/install)
Package/trusted-firmware-a-mt7988-ram-comb/install = $(Package/trusted-firmware-a-ram/install)
Package/trusted-firmware-a-mt7988-ram-ddr4/install = $(Package/trusted-firmware-a-ram/install)

define Package/trusted-firmware-a/install
	$(INSTALL_DIR) $(STAGING_DIR_IMAGE)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/build/$(PLAT)/release/bl2.img $(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-bl2.img
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/build/$(PLAT)/release/bl31.bin $(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-bl31.bin
endef

define Package/trusted-firmware-a-mt7981-dam-ap410-ddr4/install
	$(call Package/trusted-firmware-a/install)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/build/$(PLAT)/release/bl2.img.signkeyhash $(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-bl2.img.signkeyhash
endef

$(eval $(call BuildPackage/Trusted-Firmware-A))
