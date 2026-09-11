#!/bin/sh
# Assemble a raw SPI-NAND image for the Emplus EHR330 from build artifacts.
# The result is written with an external programmer to recover a device whose
# BootROM already enforces secure boot and whose BL2 no longer loads.
set -e

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/.." && pwd)}"
export TOPDIR

BIN_DIR="$TOPDIR/bin/targets/mediatek/filogic"
PREFIX="openwrt-mediatek-filogic-emplus_ehr330-signed"
HOST_BIN="$TOPDIR/staging_dir/host/bin"
NAND_SIZE=$((256 * 1024 * 1024))
NAND_PARTNUMBER="MX35LF2GE4AD-Z4I"

# Offsets and sizes must match the "partitions" node of the board DTS.
BL2_OFFSET=$((0x0));         BL2_SIZE=$((0x100000))
ENV_OFFSET=$((0x100000));    ENV_SIZE=$((0x80000))
FACTORY_OFFSET=$((0x180000)); FACTORY_SIZE=$((0x400000))
FIP_OFFSET=$((0x580000));    FIP_SIZE=$((0x200000))
UBI_OFFSET=$((0x780000));    UBI_SIZE=$((0x6d00000))
UBI1_OFFSET=$((0x7480000));  UBI1_SIZE=$((0x6d00000))
CERT_OFFSET=$((0xe180000));  CERT_SIZE=$((0x60000))
USERCONFIG_OFFSET=$((0xe1e0000)); USERCONFIG_SIZE=$((0xa0000))
CRASHDUMP_OFFSET=$((0xe280000)); CRASHDUMP_SIZE=$((0x60000))

factory=""
ubi1=""
cert=""
userconfig=""
crashdump=""
env_img=""
outfile=""
blank_factory=""

usage() {
	cat <<EOF
Usage: $0 [options]

  -o <file>            output image (default: <bin-dir>/<prefix>-full-nand.bin)
  -b <dir>             directory holding build artifacts (default: $BIN_DIR)
  -p <prefix>          artifact name prefix (default: $PREFIX)
  -f <file>            Factory partition image from this device's own backup
  --blank-factory      leave Factory erased instead of restoring a backup
  --ubi1 <file>        vendor UBI slot image (default: erased)
  --cert <file>        cert partition image (default: erased)
  --userconfig <file>  userconfig partition image (default: erased)
  --crashdump <file>   crashdump partition image (default: erased)
  --env <file>         u-boot-env partition image (default: erased)
  -h                   show this help

Factory holds per-device calibration and MAC addresses. It cannot be generated
from build output, so restore it from the backup taken from the same unit.
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
	-o) outfile="$2"; shift 2 ;;
	-b) BIN_DIR="$2"; shift 2 ;;
	-p) PREFIX="$2"; shift 2 ;;
	-f) factory="$2"; shift 2 ;;
	--blank-factory) blank_factory=1; shift ;;
	--ubi1) ubi1="$2"; shift 2 ;;
	--cert) cert="$2"; shift 2 ;;
	--userconfig) userconfig="$2"; shift 2 ;;
	--crashdump) crashdump="$2"; shift 2 ;;
	--env) env_img="$2"; shift 2 ;;
	-h|--help) usage; exit 0 ;;
	*) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
	esac
done

bl2="$BIN_DIR/$PREFIX-spim-nand-preloader.bin"
fip="$BIN_DIR/$PREFIX-spim-nand-bl31-uboot.fip"
fit="$BIN_DIR/$PREFIX-squashfs-sysupgrade.itb"
[ -n "$outfile" ] || outfile="$BIN_DIR/$PREFIX-full-nand.bin"

for f in "$bl2" "$fip" "$fit"; do
	[ -r "$f" ] || { echo "missing artifact: $f" >&2; exit 1; }
done

if [ -n "$factory" ]; then
	[ -r "$factory" ] || { echo "missing Factory image: $factory" >&2; exit 1; }
elif [ -z "$blank_factory" ]; then
	echo "refusing to build without Factory data" >&2
	echo "pass -f <backup> to restore it, or --blank-factory to erase it" >&2
	exit 1
else
	echo "WARNING: Factory left erased; calibration and MAC data will be lost" >&2
fi

PATH="$HOST_BIN:$PATH"
export PATH
command -v ubinize >/dev/null || { echo "ubinize not found in $HOST_BIN" >&2; exit 1; }

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# sysupgrade strips the appended metadata and signature before writing the FIT,
# so the UBI volume must hold the bare image.
cp "$fit" "$workdir/kernel.itb"
"$HOST_BIN/fwtool" -q -s /dev/null -t "$workdir/kernel.itb" || :
"$HOST_BIN/fwtool" -q -i /dev/null -t "$workdir/kernel.itb" || :

sh "$TOPDIR/scripts/ubinize-image.sh" --uboot-env --kernel "$workdir/kernel.itb" \
	--rootfs-data \
	"$workdir/ubi.img" -p 128KiB -m 2048 -E 5 >/dev/null

fill_ff() {
	# $1=file $2=size
	tr '\000' '\377' < /dev/zero | dd of="$1" bs=65536 \
		count=$(( ($2 + 65535) / 65536 )) iflag=fullblock 2>/dev/null
	truncate -s "$2" "$1"
}

place() {
	# $1=name $2=file $3=offset $4=size
	local size
	size="$(stat -c%s "$2")"
	if [ "$size" -gt "$4" ]; then
		echo "$1 image is $size bytes, exceeds partition size $4" >&2
		exit 1
	fi
	dd if="$2" of="$outfile" bs=65536 seek=$(( $3 / 65536 )) \
		conv=notrunc 2>/dev/null
	printf '  %-11s 0x%08x  %9s / %-9s bytes\n' "$1" "$3" "$size" "$4"
}

mkdir -p "$(dirname "$outfile")"
fill_ff "$outfile" "$NAND_SIZE"

echo "Assembling $outfile"
place BL2 "$bl2" "$BL2_OFFSET" "$BL2_SIZE"
[ -n "$env_img" ] && place u-boot-env "$env_img" "$ENV_OFFSET" "$ENV_SIZE"
[ -n "$factory" ] && place Factory "$factory" "$FACTORY_OFFSET" "$FACTORY_SIZE"
place FIP "$fip" "$FIP_OFFSET" "$FIP_SIZE"
place ubi "$workdir/ubi.img" "$UBI_OFFSET" "$UBI_SIZE"
[ -n "$ubi1" ] && place ubi_1 "$ubi1" "$UBI1_OFFSET" "$UBI1_SIZE"
[ -n "$cert" ] && place cert "$cert" "$CERT_OFFSET" "$CERT_SIZE"
[ -n "$userconfig" ] && place userconfig "$userconfig" "$USERCONFIG_OFFSET" "$USERCONFIG_SIZE"
[ -n "$crashdump" ] && place crashdump "$crashdump" "$CRASHDUMP_OFFSET" "$CRASHDUMP_SIZE"

sha256sum "$outfile" > "$outfile.sha256sum"
cat "$outfile.sha256sum"

cat >&2 <<EOF

The image contains main page data only, without OOB. Program it with the
"$NAND_PARTNUMBER" settings used for the original dump, let the programmer generate ECC,
and enable bad-block handling. This image does not contain NMBM metadata; do not
use it to overwrite a device's existing NMBM mapping table. Partition offsets
assume no bad blocks below $(printf '%#x' $((CRASHDUMP_OFFSET + CRASHDUMP_SIZE))).
EOF
