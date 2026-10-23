#!/bin/sh
# Assemble logical DAM-AP410 NAND data; the bounded stream is for programming.
set -eu

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/.." && pwd)}"
export TOPDIR

BIN_DIR="$TOPDIR/bin/targets/mediatek/filogic"
PREFIX="openwrt-mediatek-filogic-emplus_dam-ap410-signed"
HOST_BIN="$TOPDIR/staging_dir/host/bin"
NAND_SIZE=$((128 * 1024 * 1024))
NMBM_START=$((0x07800000))
ERASE_SIZE=$((0x20000))
# Current NMBM needs two one-block tables, a two-block gap, a signature,
# its top-boundary guard and at least one unused replacement block.
NMBM_GOOD_BLOCK_RESERVE=7

# Offsets and sizes must match the "partitions" node of the board DTS.
BL2_OFFSET=$((0x0));         BL2_SIZE=$((0x100000))
ENV_OFFSET=$((0x100000));    ENV_SIZE=$((0x80000))
FACTORY_OFFSET=$((0x180000)); FACTORY_SIZE=$((0x200000))
FIP_OFFSET=$((0x380000));    FIP_SIZE=$((0x200000))
UBI_OFFSET=$((0x580000));    UBI_SIZE=$((0x6000000))
USERFS_OFFSET=$((0x6580000)); USERFS_SIZE=$((0x940000))
STORAGE_OFFSET=$((0x6ec0000)); STORAGE_SIZE=$((0x940000))

factory=""
userfs=""
storage=""
env_img=""
outfile=""
blank_factory=""
bad_block_budget=0

die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
	cat <<EOF
Usage: $0 [options]

  -o <file>          output image (default: <bin-dir>/<prefix>-full-nand.bin)
  -b <dir>           directory holding build artifacts (default: $BIN_DIR)
  -p <prefix>        artifact name prefix (default: $PREFIX)
  -f <file>          Factory partition image from this device's own backup
  --blank-factory    leave Factory erased instead of restoring a backup
  --userfs <file>    userfs partition image (default: erased)
  --storage <file>   Storage partition image (default: erased)
  --env <file>       u-boot-env partition image (default: erased)
  --bad-block-budget <N>
                    require room for N initial bad blocks on the chip (default: 0)
  -h, --help         show this help

Factory holds per-device calibration and MAC addresses. It cannot be generated
from build output, so restore it from the backup taken from the same unit.

Outputs: a 128 MiB logical image, .program.bin bounded programming stream,
.layout.json programming requirements, and .sha256sum for both binaries.
Existing output files are never overwritten. Rebuild BL2 and FIP with NMBM
enabled; no device-specific NMBM map is embedded in either output.

Program .program.bin as one global good-block stream: skip bad physical
blocks without consuming source blocks, including across partition boundaries.
Erased source blocks still consume logical addresses. Erase good blocks first,
preserve bad-block markers, and leave physical 0x07800000..0x07ffffff for NMBM.
The full-size logical image is NOT a whole-chip skip-bad programming stream.

The default stream ends at Storage's start (0x06ec0000), leaving 74 data-block
slots of physical headroom. The current NMBM also needs seven good management
blocks plus one replacement per bad data block: at most 57 initial bad blocks
in total. --storage extends the stream to the payload's eraseblock boundary;
a full Storage payload requires all data blocks below NMBM to be good.
The sidecar records both limits. --bad-block-budget rejects inputs that cannot
meet the requested whole-chip margin, but does not scan or qualify a chip.
Enough good management blocks and BootROM-compatible BL2/ECC/OOB programming
are also required. Never use this fresh-chip flow to overwrite an existing map.
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
	-o|-b|-p|-f|--userfs|--storage|--env|--bad-block-budget)
		[ "$#" -ge 2 ] && [ -n "$2" ] || die "$1 requires a value"
		case "$2" in -*) die "$1 requires a value (use ./ for names starting with -)";; esac
		case "$1" in
		-o) outfile="$2";;
		-b) BIN_DIR="$2";;
		-p) PREFIX="$2";;
		-f) factory="$2";;
		--userfs) userfs="$2";;
		--storage) storage="$2";;
		--env) env_img="$2";;
		--bad-block-budget) bad_block_budget="$2";;
		esac
		shift 2;;
	--blank-factory) blank_factory=1; shift ;;
	-h|--help) usage; exit 0 ;;
	*) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
	esac
done

case "$bad_block_budget" in ''|*[!0-9]*) die "bad-block budget must be a non-negative decimal integer";; esac

bl2="$BIN_DIR/$PREFIX-spim-nand-preloader.bin"
fip="$BIN_DIR/$PREFIX-spim-nand-bl31-uboot.fip"
fit="$BIN_DIR/$PREFIX-squashfs-sysupgrade.itb"
[ -n "$outfile" ] || outfile="$BIN_DIR/$PREFIX-full-nand.bin"

for f in "$bl2" "$fip" "$fit"; do
	[ -f "$f" ] && [ -r "$f" ] && [ -s "$f" ] || die "missing or empty artifact: $f"
done

if [ -n "$factory" ]; then
	[ -f "$factory" ] && [ -r "$factory" ] && [ -s "$factory" ] || die "missing or empty Factory image: $factory"
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
command -v python3 >/dev/null || die "python3 not found"
[ -x "$HOST_BIN/fwtool" ] || die "fwtool not found in $HOST_BIN"

mkdir -p -- "$(dirname -- "$outfile")"
outdir=$(CDPATH= cd -- "$(dirname -- "$outfile")" && pwd)
outfile=$outdir/$(basename -- "$outfile")
programfile=$outfile.program.bin
layoutfile=$outfile.layout.json
for path in "$outfile" "$programfile" "$layoutfile" "$outfile.sha256sum"; do
	[ ! -e "$path" ] && [ ! -L "$path" ] || die "refusing to overwrite: $path"
done
workdir=$(mktemp -d "$outdir/.dam-ap410-nand.XXXXXX")
published_complete=
rollback_link() {
	if [ "$1" -ef "$2" ]; then
		rm -f -- "$2"
	fi
}
cleanup() {
	if [ -z "$published_complete" ]; then
		rollback_link "$workdir/image.bin" "$outfile"
		rollback_link "$workdir/program.bin" "$programfile"
		rollback_link "$workdir/layout.json" "$layoutfile"
		rollback_link "$workdir/checksums" "$outfile.sha256sum"
	fi
	rm -rf -- "$workdir"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# sysupgrade strips the appended metadata and signature before writing the FIT,
# so the UBI volume must hold the bare image.
cp "$fit" "$workdir/kernel.itb"
"$HOST_BIN/fwtool" -q -s /dev/null -t "$workdir/kernel.itb" || :
"$HOST_BIN/fwtool" -q -i /dev/null -t "$workdir/kernel.itb" || die "missing or damaged sysupgrade metadata"

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
	[ -f "$2" ] && [ -r "$2" ] && [ -s "$2" ] || die "missing or empty $1 image: $2"
	size="$(stat -c%s "$2")"
	if [ "$size" -gt "$4" ]; then
		echo "$1 image is $size bytes, exceeds partition size $4" >&2
		exit 1
	fi
	dd if="$2" of="$workdir/image.bin" bs=65536 seek=$(( $3 / 65536 )) \
		conv=notrunc 2>/dev/null
	printf '  %-11s 0x%08x  %9s / %-9s bytes\n' "$1" "$3" "$size" "$4"
}

fill_ff "$workdir/image.bin" "$NAND_SIZE"

echo "Assembling $outfile"
place BL2 "$bl2" "$BL2_OFFSET" "$BL2_SIZE"
[ -n "$env_img" ] && place u-boot-env "$env_img" "$ENV_OFFSET" "$ENV_SIZE"
[ -n "$factory" ] && place Factory "$factory" "$FACTORY_OFFSET" "$FACTORY_SIZE"
place FIP "$fip" "$FIP_OFFSET" "$FIP_SIZE"
place ubi "$workdir/ubi.img" "$UBI_OFFSET" "$UBI_SIZE"
[ -n "$userfs" ] && place userfs "$userfs" "$USERFS_OFFSET" "$USERFS_SIZE"
[ -n "$storage" ] && place Storage "$storage" "$STORAGE_OFFSET" "$STORAGE_SIZE"

python3 - "$workdir" "$outfile" "$PREFIX" "$NAND_SIZE" "$NMBM_START" \
	"$STORAGE_OFFSET" "$ERASE_SIZE" "$bad_block_budget" "$storage" "$NMBM_GOOD_BLOCK_RESERVE" \
	BL2 "$BL2_OFFSET" "$BL2_SIZE" u-boot-env "$ENV_OFFSET" "$ENV_SIZE" \
	Factory "$FACTORY_OFFSET" "$FACTORY_SIZE" FIP "$FIP_OFFSET" "$FIP_SIZE" \
	ubi "$UBI_OFFSET" "$UBI_SIZE" userfs "$USERFS_OFFSET" "$USERFS_SIZE" \
	Storage "$STORAGE_OFFSET" "$STORAGE_SIZE" <<'PY'
import json
from pathlib import Path
import sys

work, output, prefix, size, management, storage_offset, erase, budget, storage, reserve = sys.argv[1:11]
work, output = Path(work), Path(output)
size, management, storage_offset, erase, budget, reserve = map(int, (size, management, storage_offset, erase, budget, reserve))
end = storage_offset + (Path(storage).stat().st_size if storage else 0)
end = (end + erase - 1) // erase * erase
data_blocks, required_blocks = management // erase, end // erase
headroom = data_blocks - required_blocks
maximum_initial_bad = (size - management) // erase - reserve
supported_budget = min(headroom, maximum_initial_bad)
if supported_budget < budget:
    sys.exit(f"ERROR: payload needs {required_blocks} good data blocks; "
             f"requested bad-block budget {budget} cannot fit "
             f"(data headroom: {headroom}, NMBM total initial-bad limit: {maximum_initial_bad})")
if (work / "image.bin").stat().st_size != size:
    sys.exit("ERROR: unexpected combined image size")
with (work / "image.bin").open("rb") as source, (work / "program.bin").open("wb") as stream:
    remaining = end
    while remaining:
        data = source.read(min(remaining, 1024 * 1024))
        if not data:
            sys.exit("ERROR: incomplete logical image")
        stream.write(data)
        remaining -= len(data)
    while True:
        data = source.read(1024 * 1024)
        if not data:
            break
        if data != b"\xff" * len(data):
            sys.exit("ERROR: non-erased data outside the programming span")
partitions = []
for index in range(11, len(sys.argv), 3):
    name, offset, length = sys.argv[index:index + 3]
    partition = {"name": name, "offset": int(offset), "size": int(length)}
    if name == "Storage":
        partition.update(size=None, size_policy="remaining logical NMBM capacity")
    partitions.append(partition)
layout = {
    "format": "dam-ap410-nmbm-logical-v1",
    "artifact_prefix": prefix,
    "image_file": output.name,
    "image_bytes": size,
    "program_file": output.name + ".program.bin",
    "program_logical_bytes": end,
    "page_bytes": 2048,
    "eraseblock_bytes": erase,
    "oob_included": False,
    "physical_data_limit_exclusive": management,
    "minimum_good_data_blocks": required_blocks,
    "data_area_headroom_blocks": headroom,
    "maximum_bad_data_blocks": supported_budget,
    "maximum_initial_bad_blocks_total": maximum_initial_bad,
    "minimum_good_management_blocks_without_remappings": reserve,
    "maximum_initial_bad_block_budget": supported_budget,
    "requested_initial_bad_block_budget": budget,
    "bad_block_budget_scope": "initial bad blocks across both physical data and management regions",
    "bad_block_policy": "global-skip-without-consuming-source",
    "nmbm_metadata": "erased; initialized on target",
    "nmbm_max_ratio": 1,
    "nmbm_max_reserved_blocks": 64,
    "partitions": partitions,
    "requires": [
        "fresh-chip programming only; preserve valid maps during routine upgrades",
        "erase good blocks across the chip first; preserve bad-block markers",
        "program only program_file; abort if its good blocks do not fit below the physical data limit",
        "reject chips if bad data blocks exceed data_area_headroom_blocks",
        "reject chips if bad data plus bad management blocks exceed maximum_initial_bad_blocks_total",
        "skip bad physical blocks without consuming source blocks or restarting at partition boundaries",
        "erased source blocks still consume logical addresses",
        "leave the physical management area erased for NMBM initialization",
        "rebuilt BL2 CREATE|READ_ONLY and U-Boot CREATE, both with ratio 1 and limit 64",
        "at least seven good management blocks plus one replacement per bad data block",
        "MT7981 BootROM-compatible BL2 placement and chip-correct ECC/OOB programming",
    ],
    "validation": "construction only; signatures, programmer behavior and hardware boot are not verified",
}
with (work / "layout.json").open("w", encoding="ascii") as destination:
    json.dump(layout, destination, indent=2)
    destination.write("\n")
print(f"Programming span: 0x{end:08x}; {required_blocks} good data blocks required; "
      f"initial bad-block budget up to {supported_budget} "
      f"(physical data headroom: {headroom})")
if not headroom:
    print("WARNING: this payload requires all data blocks below NMBM to be good", file=sys.stderr)
PY

# Publish on the output filesystem without replacing any existing file.
ln -- "$workdir/image.bin" "$outfile"
ln -- "$workdir/program.bin" "$programfile"
ln -- "$workdir/layout.json" "$layoutfile"
(cd -- "$outdir" && sha256sum -- "$(basename -- "$outfile")" \
	"$(basename -- "$programfile")") > "$workdir/checksums"
ln -- "$workdir/checksums" "$outfile.sha256sum"
published_complete=1
cat "$outfile.sha256sum"

cat >&2 <<EOF

Program $programfile, following $layoutfile.
The 128 MiB $outfile is a logical template, NOT a whole-chip skip-bad stream.
Use one global good-block stream and stop before physical 0x07800000. Erased
source blocks still consume logical addresses. Abort if insufficient good data
blocks remain or NMBM's total initial-bad-block limit is exceeded. The recorded
budget does not scan the target or predict future failures. Keep the physical
management area erased for target initialization.
Do not overwrite a populated device's NMBM map; lost historical remappings cannot
be reconstructed. No OOB/ECC is included. W25N01GV/chip-correct ECC, BootROM BL2
placement, programmer readback and hardware boot still require qualification.
This script does not verify boot-chain signatures or write any keys/eFuses.
EOF
