## Emplus DAM-AP410

This tree includes OpenWrt 25.12 support for the Emplus DAM-AP410, an indoor
Wi-Fi 6 access point based on the MediaTek MT7981B.

### Hardware

| Component | Description |
|---|---|
| SoC | MediaTek MT7981B, dual-core Arm Cortex-A53 |
| Memory | 512 MiB DDR4 |
| Wi-Fi | MT7981B with MT7976C, dual-band 2x2 + 2x2 |
| Ethernet | MT7531AE switch, three bridged 1 GbE LAN ports |
| Flash | Winbond W25N01GV 128 MiB SPI-NAND |
| Console | UART0, 115200 8N1 |

The signed profile builds this trust chain:

```text
BootROM -> signed BL2 -> authenticated FIP/BL31/U-Boot -> RSA-signed FIT
```

`emplus_dam-ap410` is the signed production profile.
`emplus_dam-ap410_unsigned` is for development on devices that do not enforce
secure boot.

### Build

Generate keys once per checkout, select the required profile, and build:

```sh
./scripts/gen-mtk-secureboot-keys.sh
make V=s -j1
```

Production artifacts are under `bin/targets/mediatek/filogic/` with the prefix
`openwrt-mediatek-filogic-emplus_dam-ap410-signed-`. Inspect every new build
rather than relying on recorded sizes or hashes:

```sh
OUT=bin/targets/mediatek/filogic
PREFIX=openwrt-mediatek-filogic-emplus_dam-ap410-signed
ls -lh "$OUT/$PREFIX"-*
sha256sum "$OUT/$PREFIX"-*
staging_dir/host/bin/fiptool info \
  "$OUT/$PREFIX-spim-nand-bl31-uboot.fip"
```

The FIP must include BL31, BL33, and the trusted, SoC-firmware, and non-trusted
firmware key/content certificates. Never publish the private keys. The
`*.signkeyhash` output is a comparison/provisioning artifact, not a NAND image.

### Verify the running trust chain

Before enabling BootROM secure boot, verify that every signed stage is already
installed and enforced above BL2. First inspect the build artifacts:

```sh
OUT=bin/targets/mediatek/filogic
PREFIX=openwrt-mediatek-filogic-emplus_dam-ap410-signed

test "$(stat -c %s "$OUT/$PREFIX-bl2.img.signkeyhash")" -eq 32
staging_dir/host/bin/fiptool info \
  "$OUT/$PREFIX-spim-nand-bl31-uboot.fip"
```

The FIP inspection must list BL31, BL33, and all five trusted, SoC-firmware, and
non-trusted-firmware key/content certificates.

At U-Boot, compare the installed bootloader partitions with the exact current
build files served by TFTP. These are read-only flash checks:

```text
run load_fip
run calc_write_size
mtd read FIP ${verifyaddr} 0 ${write_size}
cmp.b ${loadaddr} ${verifyaddr} ${write_size}

run load_bl2
run calc_write_size
mtd read BL2 ${verifyaddr} 0 ${write_size}
cmp.b ${loadaddr} ${verifyaddr} ${write_size}
```

Both comparisons must report no differences. Cold-boot with a serial log and
require all of the following:

```text
BL2: ... OpenWrt ...
Verifying BL Anti-Rollback Version ... OK
BL2: Booting BL31
BL31: ... OpenWrt ...
U-Boot ... OpenWrt ...
Verifying Hash Integrity ... sha256,rsa2048:fit_key+ OK
```

With `TRUSTED_BOARD_BOOT=1`, BL2 stops before BL31 if FIP certificate or payload
authentication fails. Reaching the matching BL31/U-Boot with no authentication
error therefore proves the BL2-to-FIP link. The RSA message proves the
U-Boot-to-FIT link. Before eFuse provisioning, the signed BL2 is present but its
signature is not yet enforced by BootROM; that is the only open link.

### Enable BootROM secure boot

**Warning:** The commands in this section irreversibly program one-time eFuses.
A wrong hash, wrong slot, interrupted write, or unbootable BL2 can permanently
brick the device. Keep a verified raw NAND/OOB backup and external programmer,
use stable power, and perform this only after the checks above and repeated cold
boots pass. Never use a hash from another build or key set.

On the build host, identify the exact 32-byte BootROM hash payload and record its
checksum and bytes:

```sh
OUT=bin/targets/mediatek/filogic
HASH="$OUT/openwrt-mediatek-filogic-emplus_dam-ap410-signed-bl2.img.signkeyhash"
test "$(stat -c %s "$HASH")" -eq 32
sha256sum "$HASH"
hexdump -Cv "$HASH"
```

Place that exact file in the TFTP root. Fetch it on the running device and
verify its size and SHA-256 against the host output:

```sh
cd /tmp
tftp -g \
  -r openwrt-mediatek-filogic-emplus_dam-ap410-signed-bl2.img.signkeyhash \
  -l bl2.img.signkeyhash 192.168.1.10
test "$(stat -c %s /tmp/bl2.img.signkeyhash)" -eq 32
sha256sum /tmp/bl2.img.signkeyhash
hexdump -Cv /tmp/bl2.img.signkeyhash
```

Read all relevant fields before writing. This example provisions slot 0; stop
unless secure boot and lock 0 are `unblown`, and public-hash slot 0 contains 32
zero bytes. Do not continue on an inconsistent status or command error.

```sh
mtk-efuse-tool-mt7981 es r
mtk-efuse-tool-mt7981 ph r 0
mtk-efuse-tool-mt7981 lh r 0
mtk-efuse-tool-mt7981 ph r 1
mtk-efuse-tool-mt7981 lh r 1
```

Program only the public-key hash, then read it back:

```sh
mtk-efuse-tool-mt7981 ph w 0 /tmp/bl2.img.signkeyhash
mtk-efuse-tool-mt7981 ph r 0
```

The 32 displayed bytes must exactly match `hexdump -Cv` above. Stop if any byte
differs. Because secure boot is still disabled, cold-boot once now and repeat
the complete trust-chain verification before locking the slot.

After that cold boot passes, permanently lock hash slot 0 and verify it:

```sh
mtk-efuse-tool-mt7981 lh w 0
mtk-efuse-tool-mt7981 lh r 0
mtk-efuse-tool-mt7981 ph r 0
```

Require `lh: blown` and the same 32 hash bytes. Cold-boot and verify the complete
chain again. Only then perform the final irreversible step that makes BootROM
enforce the BL2 signature:

```sh
mtk-efuse-tool-mt7981 es w
mtk-efuse-tool-mt7981 es r
```

Require `es: blown`, then power the device fully off and cold-boot while
capturing serial output. The complete chain above must still pass. Do not
program `db`, `dj`, `ea`, `ed`, or the unused public-hash slot as part of this
procedure.

### Complete signing-key rotation

The keys protect different links and do not all have the same rotation rules:

- `bl2_private_key.pem` signs BL2 for BootROM. Once secure boot is enabled and
  its public-key hash is fused, every replacement BL2 must be signed by that
  key. Treat it as non-rotatable unless a separately validated SoC procedure
  provisions another supported hash slot before the old trust path is lost.
- `fip_private_key.pem` is the TF-A root key trusted by BL2. Rotating it requires
  a matching BL2 and authenticated FIP to be installed in one U-Boot session.
- The trusted-world, non-trusted-world, BL31, and BL33 keys authenticate payloads
  within the FIP certificate chain. Rebuild the matched BL2/FIP set when rotating
  the complete key set.
- `fit_key.key` signs recovery and sysupgrade FITs. Its public key is embedded in
  U-Boot, so rotate U-Boot/FIP and all FIT images together.

Install or generate the intended keys, make a complete signed build, and stage
the resulting images on TFTP:

```sh
make clean
make V=s -j1

OUT=bin/targets/mediatek/filogic
PREFIX=openwrt-mediatek-filogic-emplus_dam-ap410-signed
stat -c '%s %n' "$OUT/$PREFIX"-*
sha256sum "$OUT/$PREFIX"-*
staging_dir/host/bin/fiptool info \
  "$OUT/$PREFIX-spim-nand-bl31-uboot.fip"
```

If BootROM secure boot is enabled, compare the new `*.signkeyhash` byte-for-byte
with the fused public-hash slot before writing anything. A mismatch means the
new BL2 cannot boot and the rotation must stop.

At the currently working U-Boot prompt, set the network parameters explicitly;
the installed U-Boot may predate the helper variables. Load the new FIP without
erasing flash:

```text
setenv ipaddr 192.168.1.1
setenv serverip 192.168.1.10
setenv netmask 255.255.255.0
setenv loadaddr 0x46000000
setenv verifyaddr 0x47000000
mw.b ${loadaddr} 0xff 0x200000
tftpboot ${loadaddr} openwrt-mediatek-filogic-emplus_dam-ap410-signed-spim-nand-bl31-uboot.fip
echo ${filesize}
crc32 ${loadaddr} ${filesize}
setexpr write_size ${filesize} + 0x7ff
setexpr write_size ${write_size} / 0x800
setexpr write_size ${write_size} * 0x800
```

Match the transfer size to the host file, confirm `${write_size} <= 0x200000`,
and record the CRC. Then write and compare the FIP:

```text
mtd erase FIP
mtd write FIP ${loadaddr} 0 ${write_size}
mtd read FIP ${verifyaddr} 0 ${write_size}
cmp.b ${loadaddr} ${verifyaddr} ${write_size}
```

Do not reset. While the old U-Boot is still running, load the matching BL2:

```text
mw.b ${loadaddr} 0xff 0x100000
tftpboot ${loadaddr} openwrt-mediatek-filogic-emplus_dam-ap410-signed-spim-nand-preloader.bin
echo ${filesize}
crc32 ${loadaddr} ${filesize}
setexpr write_size ${filesize} + 0x7ff
setexpr write_size ${write_size} / 0x800
setexpr write_size ${write_size} * 0x800
```

Match the host size, confirm `${write_size} <= 0x100000`, and write BL2 only
after the FIP readback passed:

```text
mtd erase BL2
mtd write BL2 ${loadaddr} 0 ${write_size}
mtd read BL2 ${verifyaddr} 0 ${write_size}
cmp.b ${loadaddr} ${verifyaddr} ${write_size}
reset
```

The reset must reach the new BL2, authenticated FIP, and U-Boot. From the new
U-Boot, boot the recovery FIT signed by the new FIT key:

```text
run boot_recovery
```

Then install the matching Linux image from initramfs recovery:

```sh
cd /tmp
IMAGE=openwrt-mediatek-filogic-emplus_dam-ap410-signed-squashfs-sysupgrade.itb
tftp -g -r "$IMAGE" -l "$IMAGE" 192.168.1.10
sha256sum "$IMAGE"
sysupgrade -T "/tmp/$IMAGE"
sysupgrade -n "/tmp/$IMAGE"
```

Verify the RSA FIT message and complete cold and software-reset boots. Never
reset between writing the new-key FIP and its matching BL2: neither the old
BL2/new FIP nor the new BL2/old FIP combination is a valid rotation endpoint.

### Flash future builds

Back up the device first. Preserve `Factory`, update FIP before BL2, verify each
readback before reset, and update BL2 last. These commands assume the OpenWrt
U-Boot defaults from this tree and a TFTP server at `192.168.1.10`.

Load, inspect, write, and verify FIP as separate actions:

```text
run load_fip
echo ${filesize}
crc32 ${loadaddr} ${filesize}
run write_fip
run verify_fip
```

Confirm the reported transfer size against the current host file and record the
CRC before `run write_fip`. Do not reset if `run verify_fip` fails.

Update the kernel/root filesystem from signed initramfs recovery:

```text
run boot_recovery
```

Then on the recovery system:

```sh
cd /tmp
IMAGE=openwrt-mediatek-filogic-emplus_dam-ap410-signed-squashfs-sysupgrade.itb
tftp -g -r "$IMAGE" -l "$IMAGE" 192.168.1.10
sha256sum "$IMAGE"
sysupgrade -T "/tmp/$IMAGE"
sysupgrade -n "/tmp/$IMAGE"
```

Do not run this upgrade from persistent OpenWrt because its UBI `kernel` volume
backs the mounted `/dev/fit0`.

Only after the new FIP and persistent image boot repeatedly, inspect eFuses with
read commands (`es r`, `ph r 0`, and `ph r 1`). Never use eFuse write commands
as part of a routine firmware update. If secure boot is enabled, stop unless a
fused public-key hash exactly matches the current build's `*.signkeyhash`.

Load and verify BL2 last:

```text
run load_bl2
echo ${filesize}
crc32 ${loadaddr} ${filesize}
run write_bl2
run verify_bl2
```

Confirm the current host size and record the CRC before `run write_bl2`. Reset
only after a clean readback comparison. An external programmer and a verified
raw NAND/OOB backup remain the final recovery path.
