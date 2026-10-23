#!/bin/sh
# Build RFBB health-test NAND images without embedding a device-specific map.
set -eu

TOPDIR=${TOPDIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
BIN_DIR=$TOPDIR/bin/targets/mediatek/filogic
PREFIX=openwrt-mediatek-filogic-mediatek_mt7986b-rfbb
PATH=$TOPDIR/staging_dir/host/bin:$PATH
export PATH
NAND_MIB=128
BLOCK_SIZE=$((0x20000))
UBI_OFFSET=$((0x580000))
UBI_SIZE=$((0x7280000))
factory=
outfile=
budget=0

die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
	cat <<EOF
Usage: $0 [options]

Combine this workspace's RFBB preloader, FIP and installed FIT artifacts.
No original NAND dump is required. Factory stays erased unless supplied;
this is a health-test image, not production calibration or provisioning.

  -b DIR                 artifact directory (default: $BIN_DIR)
  -p PREFIX              artifact prefix (default: $PREFIX)
  -o FILE                output (default: <prefix>-<size>MiB-full-nand.bin)
  -f FILE                optional same-device Factory partition backup
  --nand-size-mib N      128, 256 or 512 (default: 128)
  --bad-block-budget N   require room for N initial bad blocks (default: 0)
  -h, --help             show this help

Output is a full-size logical template, a bounded .program.bin stream,
.layout.json programming requirements, and checksums for both binaries.
Only program .program.bin as one global good-block stream. Skip bad physical
blocks without consuming source blocks or restarting at partition boundaries.
Erased source blocks still consume logical addresses. Erase good blocks first,
preserve bad-block markers and leave the physical NMBM management area erased.

BL2/U-Boot must be rebuilt with NMBM ratio 1 and reservation limit 256.
The layout sidecar records the physical boundary and both data/management
capacity checks. The budget does not scan a chip or predict future failures.
Select the actual target capacity; these images require 2 KiB pages and
128 KiB eraseblocks. Do not reuse another capacity's programming limits.
Existing outputs are never overwritten. Do not use this fresh-chip workflow
to overwrite existing NMBM metadata. No OOB/ECC is included; NAND geometry,
BootROM BL2 placement and the programmer still require hardware qualification.
EOF
}

while [ "$#" -gt 0 ]; do
	case "$1" in
	-b|-p|-o|-f|--nand-size-mib|--bad-block-budget)
		[ "$#" -ge 2 ] && [ -n "$2" ] || die "$1 requires a value"
		case "$2" in -*) die "$1 requires a value (use ./ for names starting with -)";; esac
		case "$1" in
		-b) BIN_DIR=$2;;
		-p) PREFIX=$2;;
		-o) outfile=$2;;
		-f) factory=$2;;
		--nand-size-mib) NAND_MIB=$2;;
		--bad-block-budget) budget=$2;;
		esac
		shift 2;;
	-h|--help) usage; exit 0;;
	*) die "unknown option: $1";;
	esac
done
case "$NAND_MIB" in 128|256|512) ;; *) die "NAND size must be 128, 256 or 512 MiB";; esac
case "$budget" in ''|*[!0-9]*) die "bad-block budget must be a non-negative decimal integer";; esac
for tool in python3 fwtool ubinize fdtget stat dd tr sha256sum mktemp; do
	command -v "$tool" >/dev/null 2>&1 || die "$tool not found; build/install host tools first"
done

check_file() {
	[ -f "$1" ] && [ -r "$1" ] && [ -s "$1" ] || die "missing or empty input: $1"
	[ "$(stat -Lc%s -- "$1")" -le "$2" ] || die "input exceeds $2 bytes: $1"
}
bl2=$BIN_DIR/$PREFIX-preloader.bin
fip=$BIN_DIR/$PREFIX-bl31-uboot.fip
fit=$BIN_DIR/$PREFIX-squashfs-sysupgrade.itb
check_file "$bl2" $((0x100000))
check_file "$fip" $((0x200000))
check_file "$fit" "$UBI_SIZE"
[ -z "$factory" ] || check_file "$factory" $((0x200000))

[ -n "$outfile" ] || outfile=$BIN_DIR/$PREFIX-${NAND_MIB}MiB-full-nand.bin
mkdir -p -- "$(dirname -- "$outfile")"
outdir=$(CDPATH= cd -- "$(dirname -- "$outfile")" && pwd)
outfile=$outdir/$(basename -- "$outfile")
for path in "$outfile" "$outfile.program.bin" "$outfile.layout.json" "$outfile.sha256sum"; do
	[ ! -e "$path" ] && [ ! -L "$path" ] || die "refusing to overwrite: $path"
done
workdir=$(mktemp -d "$outdir/.rfbb-nand.XXXXXX")
complete=
rollback_link() {
	if [ "$1" -ef "$2" ]; then rm -f -- "$2"; fi
}
cleanup() {
	if [ -z "$complete" ]; then
		rollback_link "$workdir/image.bin" "$outfile"
		rollback_link "$workdir/program.bin" "$outfile.program.bin"
		rollback_link "$workdir/layout.json" "$outfile.layout.json"
		rollback_link "$workdir/checksums" "$outfile.sha256sum"
	fi
	rm -rf -- "$workdir"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

cp -- "$fit" "$workdir/fit.itb"
fwtool -q -s /dev/null -t "$workdir/fit.itb" || :
fwtool -q -i "$workdir/metadata.json" -t "$workdir/fit.itb" || die "missing or damaged sysupgrade metadata"
python3 - "$workdir/metadata.json" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as source:
    metadata = json.load(source)
if "mediatek,mt7986b-rfbb" not in metadata.get("supported_devices", []):
    sys.exit("ERROR: sysupgrade is not for MT7986B-RFBB")
PY
config=$(fdtget -t s "$workdir/fit.itb" /configurations default)
fdtget -t s "$workdir/fit.itb" "/configurations/$config" kernel >/dev/null
rootfs=$(fdtget -t s "$workdir/fit.itb" "/configurations/$config" loadables)
[ "$(fdtget -t s "$workdir/fit.itb" "/images/$rootfs" type)" = filesystem ] || die "expected installed FIT rootfs"

# Match stock sysupgrade: two environments, dynamic 'fit', writable overlay.
cat > "$workdir/ubinize.cfg" <<EOF
[ubootenv]
mode=ubi
vol_id=0
vol_type=dynamic
vol_name=ubootenv
vol_size=1MiB

[ubootenv2]
mode=ubi
vol_id=1
vol_type=dynamic
vol_name=ubootenv2
vol_size=1MiB

[fit]
mode=ubi
vol_id=2
vol_type=dynamic
vol_name=fit
image=$workdir/fit.itb

[rootfs_data]
mode=ubi
vol_id=3
vol_type=dynamic
vol_name=rootfs_data
vol_size=1MiB
vol_flags=autoresize
EOF
ubinize -o "$workdir/ubi.img" -p 128KiB -m 2048 -E 5 -Q "${SOURCE_DATE_EPOCH:-0}" "$workdir/ubinize.cfg"
check_file "$workdir/ubi.img" "$UBI_SIZE"

nand_size=$((NAND_MIB * 1024 * 1024))
tr '\000' '\377' < /dev/zero | dd of="$workdir/image.bin" bs=65536 \
	count=$((nand_size / 65536)) iflag=fullblock 2>/dev/null
place() {
	dd if="$1" of="$workdir/image.bin" bs=65536 seek=$(( $2 / 65536 )) conv=notrunc 2>/dev/null
}
place "$bl2" 0
[ -z "$factory" ] || place "$factory" $((0x180000))
place "$fip" $((0x380000))
place "$workdir/ubi.img" "$UBI_OFFSET"

python3 - "$workdir" "$outfile" "$PREFIX" "$nand_size" "$BLOCK_SIZE" "$UBI_OFFSET" "$UBI_SIZE" "$budget" "$factory" <<'PY'
import json
from pathlib import Path
import sys

work, output, prefix, size, erase, ubi_offset, ubi_size, requested, factory = sys.argv[1:]
work, output = Path(work), Path(output)
size, erase, ubi_offset, ubi_size, requested = map(int, (size, erase, ubi_offset, ubi_size, requested))
blocks = size // erase
reserved = min(blocks // 16, 256)
management = (blocks - reserved) * erase
end = ubi_offset + (work / "ubi.img").stat().st_size
end = (end + erase - 1) // erase * erase
headroom = (management - end) // erase
# These geometries fit each NMBM info table into one eraseblock.
maximum_bad = reserved - 7
supported = min(headroom, maximum_bad)
if requested > supported:
    sys.exit(f"ERROR: bad-block budget {requested} cannot fit; supported {supported} "
             f"(data headroom {headroom}, management limit {maximum_bad})")
if (work / "image.bin").stat().st_size != size:
    sys.exit("ERROR: unexpected combined image size")
with (work / "image.bin").open("rb") as source, (work / "program.bin").open("wb") as stream:
    remaining = end
    while remaining:
        chunk = source.read(min(remaining, 1024 * 1024))
        if not chunk:
            sys.exit("ERROR: incomplete combined image")
        stream.write(chunk)
        remaining -= len(chunk)
    while True:
        chunk = source.read(1024 * 1024)
        if not chunk:
            break
        if chunk != b"\xff" * len(chunk):
            sys.exit("ERROR: non-erased data outside the programming span")
layout = {
    "format": "mt7986b-rfbb-nmbm-logical-v1",
    "artifact_prefix": prefix,
    "image_file": output.name, "image_bytes": size,
    "program_file": output.name + ".program.bin", "program_logical_bytes": end,
    "page_bytes": 2048, "eraseblock_bytes": erase, "oob_included": False,
    "physical_data_limit_exclusive": management,
    "minimum_good_data_blocks": end // erase,
    "data_area_headroom_blocks": headroom,
    "maximum_initial_bad_blocks_total": maximum_bad,
    "minimum_good_management_blocks_without_remappings": 7,
    "maximum_initial_bad_block_budget": supported,
    "requested_initial_bad_block_budget": requested,
    "bad_block_policy": "global-skip-without-consuming-source",
    "nmbm_metadata": "erased; initialized on target",
    "nmbm_max_ratio": 1, "nmbm_max_reserved_blocks": 256,
    "factory_data": "provided" if factory else "blank; health-test image only",
    "partitions": [
        {"name": "bl2", "offset": 0, "size": 0x100000},
        {"name": "orig-env", "offset": 0x100000, "size": 0x80000},
        {"name": "factory", "offset": 0x180000, "size": 0x200000},
        {"name": "fip", "offset": 0x380000, "size": 0x200000},
        {"name": "ubi", "offset": ubi_offset, "size": ubi_size},
    ],
    "requires": [
        "target capacity, page size and eraseblock size must match image_bytes, page_bytes and eraseblock_bytes",
        "fresh-chip programming only; preserve valid maps during routine upgrades",
        "erase good blocks first and preserve all bad-block markers",
        "program only program_file and stop below physical_data_limit_exclusive",
        "reject chips if bad data blocks exceed data_area_headroom_blocks",
        "reject chips if bad data plus bad management blocks exceed maximum_initial_bad_blocks_total",
        "skip bad physical blocks without consuming source blocks or restarting at partition boundaries",
        "erased source blocks still consume logical addresses",
        "leave the physical management region erased for target initialization",
        "rebuilt BL2 CREATE|READ_ONLY and U-Boot CREATE with ratio 1 and reservation limit 256",
        "at least seven good management blocks plus one replacement per bad data block",
        "MT7986 BootROM-compatible BL2 placement and chip-correct ECC/OOB programming",
    ],
    "validation": "construction only; signatures, programmer behavior and hardware boot are not verified",
}
with (work / "layout.json").open("w", encoding="ascii") as destination:
    json.dump(layout, destination, indent=2)
    destination.write("\n")
print(f"Programming {end} logical bytes; NMBM starts at 0x{management:08x}; "
      f"initial bad-block budget up to {supported}")
PY
ln -- "$workdir/image.bin" "$outfile"
ln -- "$workdir/program.bin" "$outfile.program.bin"
ln -- "$workdir/layout.json" "$outfile.layout.json"
(cd -- "$outdir" && sha256sum -- "$(basename -- "$outfile")" \
	"$(basename -- "$outfile").program.bin") > "$workdir/checksums"
ln -- "$workdir/checksums" "$outfile.sha256sum"
complete=1
cat -- "$outfile.sha256sum"
cat >&2 <<EOF

Program $outfile.program.bin, not the full-size logical template.
Follow $outfile.layout.json; both data and management limits apply.
Factory is blank unless supplied. Do not overwrite a populated unit's factory
data or NMBM map. Missing historical remappings cannot be reconstructed.
No OOB/ECC or keys/eFuses are programmed. Hardware boot and programmer
readback remain unqualified by this script.
EOF
