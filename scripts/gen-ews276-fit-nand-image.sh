#!/bin/sh
# Assemble a build-only, main-area EWS276-FIT NAND image; no device input.
set -eu
umask 022

TOPDIR=${TOPDIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
BIN_DIR=$TOPDIR/bin/targets/mediatek/filogic
PREFIX=openwrt-mediatek-filogic-emplus_ews276-fit
PATH=$TOPDIR/staging_dir/host/bin:$PATH
export PATH

NAND_SIZE=$((0x10000000))
NMBM_START=$((0x0f000000))
PARTITIONS_END=$((0x0e360000))
BL2_OFFSET=0; BL2_SIZE=$((0x100000))
FIP_OFFSET=$((0x380000)); FIP_SIZE=$((0x200000))
UBI_OFFSET=$((0x580000)); UBI_SIZE=$((0x6e00000))
outfile=

die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
	cat <<EOF
Usage: $0 [options]

With no arguments, combine unsigned artifacts from this OpenWrt workspace.
No original NAND dump, Factory backup or other device data is required.

  -b DIR       build artifact directory (default: $BIN_DIR)
  -p PREFIX    artifact prefix (default: $PREFIX)
  -o FILE      output (default: <bin-dir>/<prefix>-full-nand.bin)
  -h, --help   show this help

Use the EWS276-FIT -signed or -encrypted prefix for those built profiles.
Rebuild BL2/U-Boot with NMBM initialization enabled before generating images.

Output is 256 MiB main-area data, without OOB/ECC. W25N02LV geometry:
2048-byte pages, 128 KiB eraseblocks, 128-byte physical OOB, ECC 8/512.
EOF
}

while [ "$#" -gt 0 ]; do
	case "$1" in
	-b|-p|-o)
		[ "$#" -ge 2 ] && [ -n "$2" ] || die "$1 requires a value"
		case "$2" in -*) die "$1 requires a value (use ./ for names starting with -)";; esac
		case "$1" in
		-b) BIN_DIR=$2;;
		-p) PREFIX=$2;;
		-o) outfile=$2;;
		esac
		shift 2;;
	-h|--help) usage; exit 0;;
	*) die "unknown option: $1";;
	esac
done

case "$PREFIX" in
openwrt-mediatek-filogic-emplus_ews276-fit)
	profile=unsigned; max_fit=$((100 * 1024 * 1024));;
openwrt-mediatek-filogic-emplus_ews276-fit-signed)
	profile=signed; max_fit=$((100 * 1024 * 1024));;
openwrt-mediatek-filogic-emplus_ews276-fit-encrypted)
	profile=encrypted; max_fit=$((32 * 1024 * 1024));;
*) die "unsupported EWS276-FIT artifact prefix: $PREFIX";;
esac
for tool in python3 ubinize fwtool fdtget stat dd tr sha256sum mktemp; do
	command -v "$tool" >/dev/null 2>&1 || die "$tool not found; see the README host-tool requirements"
done

check_file() {
	[ -f "$1" ] && [ -r "$1" ] && [ -s "$1" ] || die "missing or empty input: $1"
	[ "$(stat -Lc%s -- "$1")" -le "$2" ] || die "input exceeds $2 bytes: $1"
}

bl2=$BIN_DIR/$PREFIX-spim-nand-preloader.bin
fip=$BIN_DIR/$PREFIX-spim-nand-bl31-uboot.fip
fit=$BIN_DIR/$PREFIX-squashfs-sysupgrade.itb
check_file "$bl2" "$BL2_SIZE"
check_file "$fip" "$FIP_SIZE"
check_file "$fit" "$max_fit"

[ -n "$outfile" ] || outfile=$BIN_DIR/$PREFIX-full-nand.bin
mkdir -p -- "$(dirname -- "$outfile")"
outdir=$(CDPATH= cd -- "$(dirname -- "$outfile")" && pwd)
outfile=$outdir/$(basename -- "$outfile")
for path in "$outfile" "$outfile.sha256sum" "$outfile.layout.json"; do
	[ ! -e "$path" ] && [ ! -L "$path" ] || die "refusing to overwrite: $path"
done
workdir=$(mktemp -d "$outdir/.ews276-nand.XXXXXX")
published=
published_layout=
cleanup() {
	[ -z "$published" ] || rm -f -- "$outfile"
	[ -z "$published_layout" ] || rm -f -- "$outfile.layout.json"
	rm -rf -- "$workdir"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# sysupgrade removes its outer signature and JSON trailers before writing FIT.
cp -- "$fit" "$workdir/fit.itb"
fwtool -q -s /dev/null -t "$workdir/fit.itb" || :
fwtool -q -i "$workdir/metadata.json" -t "$workdir/fit.itb" || die "missing or damaged sysupgrade metadata"
python3 - "$workdir/metadata.json" "${PREFIX#openwrt-mediatek-filogic-}" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as source:
    metadata = json.load(source)
if ("emplus,ews276-fit" not in metadata.get("supported_devices", []) or
        metadata.get("version", {}).get("board") != sys.argv[2]):
    sys.exit("ERROR: sysupgrade board/profile does not match artifact prefix")
PY
config=$(fdtget -t s "$workdir/fit.itb" /configurations default)
fdtget -t s "$workdir/fit.itb" "/configurations/$config" kernel >/dev/null
if [ "$profile" = encrypted ]; then
	root=$(fdtget -t s "$workdir/fit.itb" "/configurations/$config" ramdisk)
	[ "$(fdtget -t s "$workdir/fit.itb" "/images/$root" type)" = ramdisk ] || die "expected encrypted installed rootfs"
	[ "$(fdtget -t s "$workdir/fit.itb" "/images/$root/cipher" algo)" = tee_aes256 ] || die "expected encrypted rootfs cipher"
else
	root=$(fdtget -t s "$workdir/fit.itb" "/configurations/$config" loadables)
	[ "$(fdtget -t s "$workdir/fit.itb" "/images/$root" type)" = filesystem ] || die "expected installed FIT rootfs"
fi
if [ "$profile" != unsigned ]; then
	[ "$(fdtget -t s "$workdir/fit.itb" "/configurations/$config/signature-1" algo)" = sha256,rsa2048 ] || die "expected signed FIT configuration"
fi

# EWS276-FIT boot_flash reads volume 'fit', not EHR330's 'kernel'.
cat > "$workdir/ubinize.cfg" <<EOF
[fit]
mode=ubi
vol_id=0
vol_type=dynamic
vol_name=fit
image=$workdir/fit.itb

[rootfs_data]
mode=ubi
vol_id=1
vol_type=dynamic
vol_name=rootfs_data
vol_size=1MiB
vol_flags=autoresize
EOF
ubinize -o "$workdir/ubi.img" -p 128KiB -m 2048 -Q "${SOURCE_DATE_EPOCH:-0}" "$workdir/ubinize.cfg"
check_file "$workdir/ubi.img" "$UBI_SIZE"

place() {
	# name, input, offset, partition size; unwritten bytes stay erased.
	dd if="$2" of="$workdir/image.bin" bs=65536 seek=$(( $3 / 65536 )) conv=notrunc 2>/dev/null
	printf '  %-11s 0x%08x %9s / %-9s bytes\n' "$1" "$3" "$(stat -Lc%s -- "$2")" "$4"
}

echo "Assembling $outfile ($profile)"
tr '\000' '\377' < /dev/zero | dd of="$workdir/image.bin" bs=65536 \
	count=$(( NAND_SIZE / 65536 )) iflag=fullblock 2>/dev/null
place BL2 "$bl2" "$BL2_OFFSET" "$BL2_SIZE"
place FIP "$fip" "$FIP_OFFSET" "$FIP_SIZE"
place ubi "$workdir/ubi.img" "$UBI_OFFSET" "$UBI_SIZE"
[ "$(stat -c%s -- "$workdir/image.bin")" -eq "$NAND_SIZE" ] || die "unexpected output size"
python3 - "$workdir/layout.json" "$PREFIX" "$NAND_SIZE" "$PARTITIONS_END" "$NMBM_START" <<'PY'
import json
import sys
output, prefix, size, end, management = sys.argv[1:]
layout = {
    "format": "ews276-fit-nmbm-logical-v1",
    "artifact_prefix": prefix,
    "image_bytes": int(size),
    "page_bytes": 2048,
    "eraseblock_bytes": 131072,
    "physical_oob_bytes": 128,
    "ecc_strength_bits": 8,
    "ecc_step_bytes": 512,
    "oob_included": False,
    "program_logical_bytes": int(end),
    "bad_block_policy": "global-skip-without-consuming-source",
    "physical_data_limit_exclusive": int(management),
    "nmbm_metadata": "erased; initialized on target",
    "requires": ["freshly erased good blocks; preserve bad-block markers",
                 "erased source blocks still consume logical addresses",
                 "BL2 CREATE|READ_ONLY; U-Boot CREATE",
                 "MT7986 BootROM-compatible BL2 placement and ECC/OOB",
                 "enough good blocks before the physical data limit"],
}
with open(output, "w", encoding="ascii") as destination:
    json.dump(layout, destination, indent=2)
    destination.write("\n")
PY
# Publish on the same filesystem without overwriting existing files.
ln -- "$workdir/image.bin" "$outfile"
published=1
ln -- "$workdir/layout.json" "$outfile.layout.json"
published_layout=1
sha256sum "$outfile" > "$workdir/checksum"
ln -- "$workdir/checksum" "$outfile.sha256sum"
published=
published_layout=
cat -- "$outfile.sha256sum"
cat >&2 <<EOF

WARNING: build-only image with blank Factory, environments and vendor data.
No fixed all-good NMBM map is embedded. The bootloaders initialize it on target.
Use logical global bad-block skipping as specified in $outfile.layout.json.
Do not program the erased tail as a skip-bad stream into NMBM's reserved area.
Do not overwrite a populated unit's calibration/certificates or reuse a stale map.
No OOB/ECC is included; programmer settings and boot require hardware validation.
This does not verify input boot-chain signatures or program any keys/eFuses.
EOF
