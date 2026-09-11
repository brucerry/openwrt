# Emplus EHR330

This tree adds OpenWrt 25.12 support for the Emplus EHR330, based on the MediaTek MT7987A.

---

## Hardware

| Component | Description |
| --- | --- |
| SoC | MediaTek MT7987A |
| Flash | 256 MiB SPI-NAND managed through NMBM |
| Memory | 1 GiB DDR4 |
| Ethernet | RTL8221B WAN on `eth0`; internal 2.5GbE PHY LAN on `eth1` |
| Wi-Fi | MT7996 2+3+3 PCIe radio (`14c3:7990`), intended 2.4/5/6 GHz operation |
| Console | UART0, 115200 8N1 |

---

## Build

> [!TIP]
> The `signed` profile produces this trust chain:
>
> ```text
> BootROM → signed BL2 → authenticated TBB FIP/BL31/U-Boot → RSA-signed FIT
> ```
> 
> `emplus_ehr330` is the signed production profile.\
> `emplus_ehr330_unsigned` is for development only on devices that do not enforce > BootROM secure boot.\
> The profiles are mutually exclusive.

Keep signing keys outside source control. To build the `signed` profile:

```sh
./scripts/gen-mtk-secureboot-keys.sh
make V=s -j1
```

Images are written under `bin/targets/mediatek/filogic/` with the prefix `openwrt-mediatek-filogic-emplus_ehr330-signed-`.\
Inspect the exact build before flashing:

```sh
OUT=bin/targets/mediatek/filogic
PREFIX=openwrt-mediatek-filogic-emplus_ehr330-signed
sha256sum "$OUT/$PREFIX"-*
staging_dir/host/bin/fiptool info "$OUT/$PREFIX-spim-nand-bl31-uboot.fip"
mkimage -l "$OUT/$PREFIX-squashfs-sysupgrade.itb"
```

The `signed` FIP must include BL31, BL33, and the five TBB certificates.\
The FIT must show `sha256,rsa2048:fit_key`.\
The 32-byte `*.bl2.img.signkeyhash` is for eFuse hash comparison only and must never be written to NAND.

---

## Verify the running trust chain

Before provisioning eFuses, install the exact signed BL2, FIP, and sysupgrade
set being approved. At the U-Boot prompt, compare installed bootloader partitions
with the matching build files. These commands are read-only:

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

Both comparisons must succeed. Capture repeated cold boots over UART and require:

```text
BL2: ... OpenWrt ...
Verifying BL Anti-Rollback Version ... OK
BL2: Booting BL31
BL31: ... OpenWrt ...
U-Boot ... OpenWrt ...
Verifying Hash Integrity ... sha256,rsa2048:fit_key+ OK
```

Reaching BL31/U-Boot without an authentication error verifies the signed
BL2-to-FIP chain; the RSA message verifies U-Boot-to-FIT. Before provisioning,
only BootROM verification of the signed BL2 remains unenforced.

---

## Enable BootROM secure boot

This EHR330 procedure is specific to MT7987. Use the bundled
`/usr/sbin/mtk-efuse-tool-mt7987` with tool and driver version 2.0. Unlike
MT7981/MT7986, MT7987 `ph` and `lh` commands require a hash-algorithm argument.

Warning: eFuse writes are irreversible. A wrong hash, algorithm, slot, or power
loss can permanently brick the board. Use stable power, retain an UART log and a
raw NAND/OOB backup, keep an external programmer available, and do not provision
until repeated cold boots pass. Do not provision while U-Boot SPI-NAND reads are
intermittent.

The official MT7987 procedure requires `AVDD18_VQPS` tied to 1.8 V for eFuse
writes. Confirm this EHR330 hardware requirement before any write.

The signed EHR330 profile uses the default MT7987 algorithm: RSA-2048 with
SHA-256. Do not program a different algorithm unless BL2 and FIP were rebuilt
for it first. MT7987 SHA-256 slot 1 is used only after slot 0 is explicitly
disabled; it is not an automatic fallback.

On the build host, record the exact hash for the approved build:

```sh
OUT=bin/targets/mediatek/filogic
PREFIX=openwrt-mediatek-filogic-emplus_ehr330-signed
HASH="$OUT/$PREFIX-bl2.img.signkeyhash"
test "$(stat -c %s "$HASH")" -eq 32
sha256sum "$HASH"
hexdump -Cv "$HASH"
```

Fetch the same file on the EHR330 and compare its size, SHA-256, and bytes with
the host record:

```sh
cd /tmp
tftp -g -r openwrt-mediatek-filogic-emplus_ehr330-signed-bl2.img.signkeyhash \
	-l bl2.img.signkeyhash 192.168.1.10
test "$(stat -c %s /tmp/bl2.img.signkeyhash)" -eq 32
sha256sum /tmp/bl2.img.signkeyhash
hexdump -Cv /tmp/bl2.img.signkeyhash
```

Read state first. Algorithm value `0` is SHA-256. Stop unless secure boot and
slot-0 lock are unblown, slot 0 is all zeroes, and all commands succeed:

```sh
mtk-efuse-tool-mt7987 sa r
mtk-efuse-tool-mt7987 es r
mtk-efuse-tool-mt7987 ph r 0 0
mtk-efuse-tool-mt7987 lh r 0 0
mtk-efuse-tool-mt7987 dh r 0
mtk-efuse-tool-mt7987 ph r 1 0
mtk-efuse-tool-mt7987 lh r 1 0
```

For this build, `sa r` must report the default algorithm. Do not run `sa w`.
Program and read back only SHA-256 slot 0; every displayed byte must equal the
approved hash:

```sh
mtk-efuse-tool-mt7987 ph w 0 /tmp/bl2.img.signkeyhash
mtk-efuse-tool-mt7987 ph r 0 0
```

Cold-boot and repeat trust-chain verification. Then lock slot 0 and verify it:

```sh
mtk-efuse-tool-mt7987 lh w 0 0
mtk-efuse-tool-mt7987 lh r 0 0
mtk-efuse-tool-mt7987 ph r 0 0
```

Cold-boot and verify again. Only then enable BootROM secure boot:

```sh
mtk-efuse-tool-mt7987 es w
mtk-efuse-tool-mt7987 es r
```

Require `es` to report `blown`, then fully remove power and capture a cold boot.
It must reach signed BL2, authenticated FIP, signed FIT, and Linux. Do not
program `dh`, `ea`, `db`, `dj`, or slot 1 as part of this procedure.

Normal BootROM:
> V0: 0000\
> 00: 0000
```text
F0: 102B 0000
FA: 1040 0000
FA: 1040 0000 [0200]
F9: 0000 0000
V0: 0000 0000 [0001]
00: 0000 0000
BP: 2400 0041 [0000]
G0: 1190 0000
EC: 0000 0000 [1000]
T0: 0000 028A [010F]
Jump to BL
```

Fused BootROM with unsigned BL2:
> V0: 100C, INVALID_SIG_TYPE\
> 00: 1017, BL_VERIFY_FAILED
```text
F0: 102B 0000
FA: 1040 0000
FA: 1040 0000 [0200]
F9: 0000 0000
V0: 100C 0000 [0001]
00: 1017 0000
F9: 0000 0000
V0: 100C 0000 [0001]
01: 102A 0001
02: 1017 0000
BP: 2000 02C0 [0001]
EC: 0000 0000 [1000]
T0: 0000 023C [000F]
System halt!
```

Fused BootROM with signed BL2 but wrong key:
> V0: 706D, KEY_MISMATCH\
> 00: 1017, BL_VERIFY_FAILED

---

## Complete signing-key rotation

The fused BootROM SHA-256 hash pins the BL2 signing key after secure boot is
enabled. Do not rotate that key in the field. Changing the FIP root or payload
keys requires a matching BL2 and FIP. Changing `fit_key.key` requires matching
U-Boot/FIP plus all recovery and sysupgrade FITs.

Build and stage a complete signed set. Before writing, compare its BL2
`*.signkeyhash` byte-for-byte with `ph r 0 0`; a mismatch means the new BL2
cannot boot on a fused board. Write and verify matching FIP first, then BL2 in
the same U-Boot session. Do not reset between those writes. RAM-boot the matching
signed recovery FIT, install the matching sysupgrade FIT, and verify repeated
cold and software-reset boots.

---

## Flash future builds

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
IMAGE=openwrt-mediatek-filogic-emplus_ehr330-signed-squashfs-sysupgrade.itb
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
