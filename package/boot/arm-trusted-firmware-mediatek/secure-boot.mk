# Keep TF-A's source-only crypto dependency separate from target libmbedtls.
include $(INCLUDE_DIR)/mtk-anti-rollback.mk

MBEDTLS_TFA_RELEASE:=3.6.7
MBEDTLS_TFA_SOURCE:=mbedtls-tfa-$(MBEDTLS_TFA_RELEASE).tar.zst
MTK_TBB_KEY_DIR?=$(TOPDIR)/keys/mtk-secure-boot
MTK_TBB_KEYS:=bl2 fip trusted non_trusted soc_fw nt_fw

define MTK_TBB_CHECK_KEYS
	$(foreach key,$(MTK_TBB_KEYS),test -s "$(MTK_TBB_KEY_DIR)/$(key)_private_key.pem" || { echo "Missing $(key) signing key in $(MTK_TBB_KEY_DIR)" >&2; exit 1; };)
endef

MTK_TBB_FLAGS = \
	TRUSTED_BOARD_BOOT=1 GENERATE_COT=1 CREATE_KEYS=0 E=0 KEY_ALG=rsa KEY_SIZE=2048 HASH_ALG=sha256 \
	ANTI_ROLLBACK=1 BL2_UPDATE_AR_VER=0 \
	ANTI_ROLLBACK_TABLE=$(MTK_TBB_BUILD_DIR)/ews276-fit-bl-ar-table.xml \
	ROT_KEY=$(MTK_TBB_KEY_DIR)/fip_private_key.pem \
	BROM_SIGN_KEY=$(MTK_TBB_KEY_DIR)/bl2_private_key.pem \
	TRUSTED_WORLD_KEY=$(MTK_TBB_KEY_DIR)/trusted_private_key.pem \
	NON_TRUSTED_WORLD_KEY=$(MTK_TBB_KEY_DIR)/non_trusted_private_key.pem \
	BL31_KEY=$(MTK_TBB_KEY_DIR)/soc_fw_private_key.pem \
	BL33_KEY=$(MTK_TBB_KEY_DIR)/nt_fw_private_key.pem \
	MBEDTLS_DIR=$(MTK_TBB_BUILD_DIR)/mbedtls-tfa-$(MBEDTLS_TFA_RELEASE)
