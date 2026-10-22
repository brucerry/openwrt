# Emplus EWS276-FIT

OpenWrt 25.12 support for the Emplus EWS276-FIT. The supplied `.config`
builds the **unsigned development profile** without signing keys or eFuse
provisioning. Signed and encrypted images are separate, opt-in profiles.

---

## Hardware

| Component | Description |
| --- | --- |
| SoC | MediaTek MT7986A |
| Memory | 512 MiB DDR4 |
| Flash | Winbond W25N02LV, 256 MiB SPI-NAND with NMBM bad-block management |
| Ethernet | One GPY211C 2.5GbE port on `eth0` |
| Wi-Fi | Integrated MT7986 dual-band 2.4/5 GHz radio |
| Console | UART0, 115200 8N1 |

---

## Build

| Profile | Status and purpose |
| --- | --- |
| `emplus_ews276-fit` | Default unsigned development images |
| `emplus_ews276-fit-signed` | Opt-in signed BL2, authenticated FIP and RSA-signed FIT |
| `emplus_ews276-fit-encrypted` | Signed chain plus encrypted FIP and FIT payloads |

### Unsigned Profile

```sh
make defconfig
make -j1 V=s
```

The default target is `MediaTek ARM` / `Filogic` / `Emplus EWS276-FIT`
(`CONFIG_TARGET_PROFILE="DEVICE_emplus_ews276-fit"`). No key-generation
step is needed for unsigned builds.

### Signed Profile

```sh
./scripts/gen-mtk-secureboot-keys.sh
make menuconfig
# Select only Emplus EWS276-FIT (signed) under Target Profile.
# Enable mtk-efuse-nl-tool-mt7986 for the Linux eFuse commands.
make defconfig
make -j1 V=s
```

Reuse approved keys for existing devices; do not replace them with newly
generated keys. Keep `keys/mtk-secure-boot/` outside source control and back
it up securely. To return to unsigned builds, restore the supplied unsigned
`.config` and run `make defconfig`.

The `signed` chain is:

```text
BootROM -> signed BL2 -> authenticated FIP (BL31/U-Boot) -> RSA-signed FIT
```

BL/FW rollback versions start at `0` in `include/mtk-anti-rollback.mk`.
Automatic eFuse counter updates are disabled.

### Encrypted Profile

```sh
./scripts/gen-mtk-secureboot-keys.sh
./scripts/gen-mtk-secureboot-keys.sh --encryption
make menuconfig
# Select only Emplus EWS276-FIT (signed and encrypted) under Target Profile.
# Enable mtk-efuse-nl-tool-mt7986 for the Linux eFuse commands.
make defconfig
make -j1 V=s
```

Host OpenSSL 3 with `openssl kdf` is required.
Existing approved keys and salts must be retained.
When switching an existing unsigned configuration, also enable
`mtk-efuse-nl-tool-mt7986` if its previous package exclusion remains.

The `encrypted` profile uses AES-GCM for BL31/U-Boot and `tee_aes256`
AES-256-CBC for FIT kernel/rootfs or recovery initrd payloads, authenticated
by the FIT signature. FIP nonces and FIT IVs are generated per payload.
The installed SquashFS root is decrypted into RAM (`/dev/ram0`); the UBIFS
writable overlay, BL2 and authenticated DTB are not encrypted.

Encrypted boot requires the matching device platform key through MediaTek's
key service.

---

## Artifacts

Images are written to `bin/targets/mediatek/filogic/` with these prefixes:

- Unsigned: `openwrt-mediatek-filogic-emplus_ews276-fit`
- Signed: `openwrt-mediatek-filogic-emplus_ews276-fit-signed`
- Encrypted: `openwrt-mediatek-filogic-emplus_ews276-fit-encrypted`

| Filename suffix | Purpose |
| --- | --- |
| `-initramfs-recovery.itb` | RAM recovery |
| `-squashfs-sysupgrade.itb` | Persistent firmware upgrade |
| `-spim-nand-bl31-uboot.fip` | BL31/U-Boot bootloader package |
| `-spim-nand-preloader.bin` | BL2 bootloader |
| `-bl2.img.signkeyhash` | Signed/encrypted profiles: 32-byte BootROM key-hash reference |

Build one profile at a time and archive its artifacts before switching.
Do not mix keys or bootloader/FIT sets from different builds.

---

## Full NAND Programming Image

After building profile, run directly:

```sh
./scripts/gen-ews276-fit-nand-image.sh
```

Run with `-h` for more info.

---

## Installation and Updates

Initial vendor migration and bootloader replacement require a board-specific
UART recovery procedure, a verified NAND/OOB backup and external recovery
access. Preserve `Factory`, the secondary `ubi_1` slot and existing NMBM
metadata. Do not erase the whole NAND or force bootloader writes from Linux.

For routine updates on an installed system from this tree, transfer the
matching sysupgrade FIT to `/tmp`, then:

```sh
IMAGE=/tmp/openwrt-mediatek-filogic-emplus_ews276-fit-squashfs-sysupgrade.itb
sysupgrade -T "$IMAGE" && sysupgrade "$IMAGE"
```

### Flash FIP and BL2 Through U-Boot

Use this procedure only on an installed EWS276-FIT with the NMBM partition
layout below, stable power, an off-device NAND/OOB backup and external
recovery access. Use one matching FIT/FIP/BL2 set from the selected profile.
Install its FIT first as above. Signed images must use approved keys and
compatible rollback versions; do not flash unsigned images on a board with
BootROM secure boot enabled.
Do not substitute encrypted images on a board without its platform key.
Encrypted hardware boot and migration are not qualified by this procedure.
This procedure does not provision keys or write eFuses.

Reboot and interrupt autoboot. Repeat this setup each time you enter U-Boot;
point the TFTP server at the directory containing the selected files.
The example uses the default unsigned prefix. For signed or encrypted
builds, replace `prefix` with the corresponding prefix listed under Artifacts:

```text
setenv ipaddr 192.168.1.1
setenv serverip 192.168.1.10
setenv loadaddr 0x46000000
setenv prefix openwrt-mediatek-filogic-emplus_ews276-fit
mtd list
mtd bad spi-nand0
```

Confirm these partitions are under `nmbm0`; stop if the layout differs:

| Partition | Start | Size |
| --- | --- | --- |
| `bl2` | `0x00000000` | `0x00100000` |
| `fip` | `0x00380000` | `0x00200000` |

For this BL2 update procedure, stop if any bad block is listed in the first
1 MiB. Stop on any failed command; after erasing starts, keep power on and
do not reset until readback succeeds or recovery is complete.

**FIP first.** Paste this chain as one U-Boot command. It downloads the FIP,
checks its size, aligns the write length to 2 KiB, backs up the old partition
at `0x49000000`, then writes and compares the complete 2 MiB partition:

```text
mw.b ${loadaddr} 0xff 0x200000 && tftpboot ${loadaddr} ${prefix}-spim-nand-bl31-uboot.fip && test 0x${filesize} -gt 0 && test 0x${filesize} -le 0x200000 && setexpr wrlen ${filesize} + 0x7ff && setexpr wrlen ${wrlen} / 0x800 && setexpr wrlen ${wrlen} \* 0x800 && mtd read fip 0x49000000 0 0x200000 && mtd erase fip && mtd write fip ${loadaddr} 0 ${wrlen} && mtd read fip 0x47000000 0 0x200000 && cmp.b ${loadaddr} 0x47000000 0x200000
```

Expect `Total of 2097152 byte(s) were the same`. Only then run `reset`
and verify the new BL31/U-Boot boots the installed FIT into Linux.

**BL2 last.** Return to U-Boot and repeat the setup/layout checks above.
Paste this chain as one command. It backs up the old BL2 at `0x49000000`
and compares logical/raw reads before erasing. After writing, both complete
1 MiB readbacks must match:

```text
mw.b ${loadaddr} 0xff 0x100000 && tftpboot ${loadaddr} ${prefix}-spim-nand-preloader.bin && test 0x${filesize} -gt 0 && test 0x${filesize} -le 0x100000 && setexpr wrlen ${filesize} + 0x7ff && setexpr wrlen ${wrlen} / 0x800 && setexpr wrlen ${wrlen} \* 0x800 && mtd read bl2 0x49000000 0 0x100000 && mtd read spi-nand0 0x48000000 0 0x100000 && cmp.b 0x49000000 0x48000000 0x100000 && mtd erase bl2 && mtd write bl2 ${loadaddr} 0 ${wrlen} && mtd read bl2 0x48000000 0 0x100000 && cmp.b ${loadaddr} 0x48000000 0x100000 && mtd read spi-nand0 0x48000000 0 0x100000 && cmp.b ${loadaddr} 0x48000000 0x100000
```

Expect three successful 1 MiB comparisons: one before writing and two after.
RAM backups are lost on reset or power loss; they do not replace the
off-device backup. After all checks pass, test `reset` and, when possible,
a cold boot. Check the BL2/BL31/U-Boot banners, overlay and Ethernet; signed
and encrypted boots must also pass FIT signature checks. On those profiles,
use the read-only eFuse checks below to confirm enable flags remain unchanged.
The unsigned profile does not include the Linux eFuse module/tool.

---

## MT7986 eFuse Command Reference

The **signed and encrypted** profiles include U-Boot `efuse`, Linux `mtk-efuse-tool-mt7986`
and `kmod-mtk-efuse-nl-drv`.
Both interfaces require a compatible BL31 eFuse service and access the same
physical OTP fields. The Linux module is loaded manually.

Writes permanently
program OTP bits, even before a write lock is set. The tables below describe
syntax, not a provisioning sequence. Actual provisioning requires the official
MT7986 hardware/voltage procedure, approved keys and separate authorization.

### Linux Commands

Prefix each argument sequence below with `mtk-efuse-tool-mt7986`.
`r` reads a value; `w` programs it irreversibly.

| Command | Read arguments | Write arguments | Function |
| --- | --- | --- | --- |
| `ph` | `ph r <IDX>` | `ph w <IDX> <HASH_FILE>` | BL2 public-key hash |
| `lh` | `lh r <IDX>` | `lh w <IDX>` | Lock public-key hash writes |
| `dh` | `dh r <IDX>` | `dh w <IDX>` | Disable a public-key hash slot |
| `dj` | `dj r` | `dj w` | Disable JTAG |
| `es` | `es r` | `es w` | Enable BootROM secure boot |
| `ea` | `ea r` | `ea w` | Enable BootROM anti-rollback |
| `db` | `db r` | `db w` | Disable the BootROM command interface |
| `ak` | `ak r` | `ak w <KEY_FILE>` | 16-byte platform key |
| `al` | `al r` | `al w` | Lock platform-key writes |

`IDX` is `0` or `1`; `HASH_FILE` is the 32-byte binary `*-bl2.img.signkeyhash`
artifact, not its hexadecimal text or SHA-256 checksum. MT7986 BL2 uses
RSA-2048/SHA-256: unlike MT7987/MT7988, do not append a `HASH_ALGO` argument
to `ph`/`lh`, and do not use `sa` to select another algorithm.

Read-only inspection on signed Linux or signed RAM recovery:

```sh
modprobe mtk_efuse
mtk-efuse-tool-mt7986 ph r 0
mtk-efuse-tool-mt7986 lh r 0
mtk-efuse-tool-mt7986 dh r 0
mtk-efuse-tool-mt7986 es r
mtk-efuse-tool-mt7986 ea r
```

The supplied tool also exposes `ak`/`al`, but platform-key operations are not
needed for signed-only firmware and have not been hardware-qualified here.
`KEY_FILE` is a 16-byte binary secret; `ak r` can expose it before read
protection is active.

### U-Boot Raw Fields

Use `efuse read <index>` or, only during authorized provisioning,
`efuse write <index> <hex-data>`. Indexes are decimal; data is hexadecimal
in byte order, not a filename.

| Index | Field | Write data | Linux equivalent |
| --- | --- | --- | --- |
| `8`, `9` | BL2 public-key hash slots 0, 1 | 32 bytes / 64 hex digits | `ph` |
| `16`, `17` | Hash write locks for slots 0, 1 | `1` | `lh` |
| `21`, `22` | Disable hash slots 0, 1 | `1` | `dh` |
| `25` | Disable JTAG | `1` | `dj` |
| `26` | Enable BootROM secure boot | `1` | `es` |
| `27` | Enable BootROM anti-rollback | `1` | `ea` |
| `28`-`31` | Two 64-bit BL rollback-counter copies | Read only in this guide | No short-form counter command |
| `33` | Disable the BootROM command interface | `1` | `db` |
| `34`, `35` | One 64-bit FW rollback counter | Read only in this guide | No short-form counter command |
| `37` | Platform-key value | 16 bytes / 32 hex digits | `ak` |
| `38` | Platform-key write lock | `1` | `al` |

Raw rollback words are bitmaps, not plain integer versions;
do not hand-compose or program them as part of routine firmware updates.

Read-only U-Boot inspection of enable flags and both BL counter copies:

```text
efuse read 26
efuse read 27
efuse read 28
efuse read 29
efuse read 30
efuse read 31
```

Stop on unsupported-field, permission or SMC errors; a failed read does not
mean zero or unblown. Choose one interface per write operation;
the Linux and U-Boot write commands are alternatives, not successive steps.
The reference above is checked against this tree's MT7986 tool object and
signed BL31 libraries, including the separately backported FW counter fields.

---

## Verification and Limits

```sh
ubus call system board
df -h / /overlay
cat /sys/class/net/eth0/address
ip a
iw dev
```

Validated on the development board: configuration-preserving installed
upgrades, overlay persistence, Ethernet ping and both AP interfaces starting.
Earlier unsigned and signed builds passed cold boot.
Signed boots verify `sha256,rsa2048:fit_key` and firmware
rollback version `0`.

---

## License

Based on OpenWrt, licensed under GPL-2.0; individual components retain their
respective licenses.
