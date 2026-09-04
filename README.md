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
make menuconfig
make defconfig
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