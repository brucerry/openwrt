# Emplus EWS276-FIT

OpenWrt 25.12 support for the Emplus EWS276-FIT. The supplied `.config`
builds the **unsigned development profile** without signing keys or eFuse
provisioning. Signed images are a separate, opt-in profile.

---

## Hardware

| Component | Description |
| --- | --- |
| SoC | MediaTek MT7986A |
| Memory | 512 MiB DDR4 |
| Flash | Winbond W25N02LV, 256 MiB SPI-NAND with existing NMBM mapping |
| Ethernet | One GPY211C 2.5GbE port on `eth0` |
| Wi-Fi | Integrated MT7986 dual-band 2.4/5 GHz radio |
| Console | UART0, 115200 8N1 |

---

## Build the Default Profile

Use a GNU/Linux host with a case-sensitive filesystem and the standard
[OpenWrt build dependencies](https://openwrt.org/docs/guide-developer/build-system/install-buildsystem).

```sh
make defconfig
make -j1 V=s
```

The repository includes its feed sources and default configuration. Keep
the supplied snapshot for reproducibility; `feeds update -a` fetches newer
feed revisions and is not needed for this build.

The default target is `MediaTek ARM` / `Filogic` / `Emplus EWS276-FIT`
(`CONFIG_TARGET_PROFILE="DEVICE_emplus_ews276-fit"`). No key-generation
step is needed for unsigned builds.

---

## Separate Security Profiles

| Profile | Status and purpose |
| --- | --- |
| `emplus_ews276-fit` | Default unsigned development images |
| `emplus_ews276-fit-signed` | Opt-in signed BL2, authenticated FIP and RSA-signed FIT |

To build the `signed` profile instead:

```sh
./scripts/gen-mtk-secureboot-keys.sh
make menuconfig
# Select only Emplus EWS276-FIT (signed) under Target Profile.
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
Automatic eFuse counter updates are disabled. Building or flashing signed
images does not enable BootROM secure boot or burn anti-rollback eFuses.

---

## Artifacts

Images are written to `bin/targets/mediatek/filogic/` with these prefixes:

- Unsigned: `openwrt-mediatek-filogic-emplus_ews276-fit`
- Signed: `openwrt-mediatek-filogic-emplus_ews276-fit-signed`

| Filename suffix | Purpose |
| --- | --- |
| `-initramfs-recovery.itb` | RAM recovery |
| `-squashfs-sysupgrade.itb` | Persistent firmware upgrade |
| `-spim-nand-bl31-uboot.fip` | BL31/U-Boot bootloader package |
| `-spim-nand-preloader.bin` | BL2 bootloader |
| `-bl2.img.signkeyhash` | Signed profile only: 32-byte BootROM key-hash reference |

Build one profile at a time and archive its artifacts before switching.
Do not mix keys or bootloader/FIT sets from different builds.

---

## Installation and Updates

Initial vendor migration and bootloader replacement require a board-specific
UART recovery procedure, a verified NAND/OOB backup and external recovery
access. Preserve `Factory`, the secondary `ubi_1` slot and existing NMBM
metadata. Do not erase the whole NAND or force bootloader writes from Linux.

For routine updates on an installed system from this tree, transfer the
matching sysupgrade FIT to `/tmp`, verify its approved SHA-256 checksum, then:

```sh
IMAGE=/tmp/openwrt-mediatek-filogic-emplus_ews276-fit-squashfs-sysupgrade.itb
sysupgrade -T "$IMAGE" && sysupgrade "$IMAGE"
```

Use the `-signed-` filename on signed systems. RAM recovery requires
`sysupgrade -T "$IMAGE" && sysupgrade -n "$IMAGE"`; it cannot preserve the
installed configuration. Signed U-Boot requires signed recovery as well.
Sysupgrade updates firmware/overlay, not BL2 or FIP.

For the validated unsigned-to-signed transition, install the signed FIT,
then write and read back the matching FIP, and BL2 last through U-Boot.
Verify transfer hashes, page alignment and complete partition readbacks;
do not reset after a failed check. No eFuse write is part of this procedure.

---

## MT7986 eFuse Command Reference

The **signed** profile includes U-Boot `efuse`, Linux `mtk-efuse-tool-mt7986`
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
iw dev
```

Validated on the development board: unsigned and signed cold boot,
configuration-preserving installed upgrades, overlay persistence, Ethernet
ping and both AP interfaces starting. Signed boots verify
`sha256,rsa2048:fit_key` and firmware rollback version `0`.

---

## License

Based on OpenWrt, licensed under GPL-2.0; individual components retain their
respective licenses.
