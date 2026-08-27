#!/bin/sh
# Generate MT798x/MT7981 secure boot key material per MTK official Secure Boot
# Application Note (RSA-2048, sha256+rsa-pss). Idempotent: skips existing keys.
set -e

KEYDIR="${1:-keys/mtk-secure-boot}"
mkdir -p "$KEYDIR"
cd "$KEYDIR"

gen_rsa_pair() {
	# $1=private file $2=public file
	if [ ! -f "$1" ]; then
		openssl genrsa -out "$1" 2048
		chmod 600 "$1"
	fi
	if [ ! -f "$2" ]; then
		openssl rsa -in "$1" -pubout -outform PEM -out "$2"
	fi
}

# BL2 key: root of trust verified by Boot ROM via OTP-stored public key hash.
# -> TFA_BROM_SIGN_KEY (signs BL2 image header via bromimage, outside TF-A CoT)
gen_rsa_pair bl2_private_key.pem bl2_public_key.pem

# FIP key: root of trust for the FIP/TBBR certificate chain.
# -> TFA_ROT_KEY (TF-A embeds its hash as rotpk_sha256.bin into BL2)
gen_rsa_pair fip_private_key.pem fip_public_key.pem

# Trusted key: intermediate cert key (trusted world).
# -> TFA_TRUSTED_WORLD_KEY
gen_rsa_pair trusted_private_key.pem trusted_public_key.pem

# Non-trusted key: intermediate cert key (non-trusted world).
# -> TFA_NON_TRUSTED_WORLD_KEY
gen_rsa_pair non_trusted_private_key.pem non_trusted_public_key.pem

# SoC FW key (BL31).
# -> TFA_BL31_KEY
gen_rsa_pair soc_fw_private_key.pem soc_fw_public_key.pem

# Non-trusted FW key (BL33 / U-Boot).
# -> TFA_BL33_KEY
gen_rsa_pair nt_fw_private_key.pem nt_fw_public_key.pem

# FIT key: signs U-Boot FIT (kernel+DTB, transitively rootfs dm-verity root
# hash). Self-signed X.509 cert per MTK note, RSA-2048 exponent 65537 (-F4).
if [ ! -f fit_key.key ]; then
	openssl genrsa -F4 -out fit_key.key 2048
	chmod 600 fit_key.key
fi
if [ ! -f fit_key.crt ]; then
	openssl req -batch -new -x509 -key fit_key.key -out fit_key.crt
fi

echo "Keys ready in $KEYDIR:"
ls -1 "$PWD"
