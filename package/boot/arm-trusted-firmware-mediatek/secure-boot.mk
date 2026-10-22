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
	MBEDTLS_DIR=$(MTK_TBB_BUILD_DIR)/mbedtls-tfa-$(MBEDTLS_TFA_RELEASE) \
	$(if $(MTK_TBB_ENCRYPT),$(MTK_TBB_ENCRYPT_FLAGS))

define MTK_TBB_CHECK_ENCRYPTION_KEYS
	$(foreach file,platform_key.bin:16 roe_salt.bin:32 fip_salt.bin:32 kernel_salt.bin:32 rootfs_salt.bin:32 fip_nonce.bin:12,\
		test "$(shell wc -c < '$(MTK_TBB_KEY_DIR)/$(word 1,$(subst :, ,$(file)))' 2>/dev/null)" = $(word 2,$(subst :, ,$(file))) || { echo "Invalid encryption material: $(word 1,$(subst :, ,$(file)))" >&2; exit 1; };)
endef

MTK_TBB_ENCRYPT_FLAGS = \
	FIP_ENC=1 FW_ENC=1 FW_ENC_VIA_BL31=1 ENCRYPT_BL31=1 ENCRYPT_BL33=1 \
	TRNG_SUPPORT=1 DECRYPTION_SUPPORT=aes_gcm \
	ENC_KEY_PATH=$(MTK_TBB_KEY_DIR)/platform_key.bin \
	ENC_NONCE_PATH=$(MTK_TBB_KEY_DIR)/fip_nonce.bin \
	ROE_KEY_SALT=$(MTK_TBB_KEY_DIR)/roe_salt.bin \
	FIP_KEY_SALT=$(MTK_TBB_KEY_DIR)/fip_salt.bin \
	KERNEL_KEY_SALT=$(MTK_TBB_KEY_DIR)/kernel_salt.bin \
	ROOTFS_KEY_SALT=$(MTK_TBB_KEY_DIR)/rootfs_salt.bin
