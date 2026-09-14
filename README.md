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

## Build profiles

The production trust chain is:

```text
BootROM -> signed BL2 -> authenticated TBB FIP/BL31/U-Boot -> RSA-signed FIT
```

| Profile | Purpose |
| --- | --- |
| `emplus_ehr330_unsigned` | Development on devices where BootROM secure boot is not enabled |
| `emplus_ehr330` | Signed production image set |
| `emplus_ehr330_encrypted` | Signed production set plus encrypted BL31, U-Boot, kernel, initramfs, and rootfs |

The encrypted profile has all signing properties of the signed profile and adds encryption.\
MT7987 BL2 remains signed but unencrypted; it derives the root-of-encryption keys and decrypts BL31.\
The FIT DTB remains authenticated by the signed configuration but does not have a cipher node.\
Select exactly one profile and keep BL2, FIP, recovery, and sysupgrade images from the same build.

Keep all signing and encryption material outside source control. Build the signed profile with:

```sh
./scripts/gen-mtk-secureboot-keys.sh
make menuconfig
make V=s -j1
```

Build the encrypted profile with:

```sh
./scripts/gen-mtk-secureboot-keys.sh --encryption
make menuconfig
make V=s -j1
```

The encrypted build uses a 16-byte platform key, per-purpose salts, and a FIP nonce.\
Back up the complete generated key directory in a production secrets system; losing or changing its platform key makes future encrypted images unusable on locked devices.

Artifacts are written to `bin/targets/mediatek/filogic/`. Inspect an encrypted build without printing secrets:

```sh
OUT=bin/targets/mediatek/filogic
PREFIX=openwrt-mediatek-filogic-emplus_ehr330-encrypted
RECOVERY="$OUT/$PREFIX-initramfs-recovery.itb"
SYSUPGRADE="$OUT/$PREFIX-squashfs-sysupgrade.itb"

sha256sum "$OUT/$PREFIX"-*
staging_dir/host/bin/fiptool info "$OUT/$PREFIX-spim-nand-bl31-uboot.fip"
dumpimage -l "$RECOVERY"
dumpimage -l "$SYSUPGRADE"

fdtget -t s "$RECOVERY" /images/kernel-1/cipher algo
fdtget -t bx "$RECOVERY" /images/kernel-1/cipher iv | wc -w
fdtget -t s "$RECOVERY" /images/initrd-1/cipher algo
fdtget -t bx "$RECOVERY" /images/initrd-1/cipher iv | wc -w
fdtget -t s "$SYSUPGRADE" /images/kernel-1/cipher algo
fdtget -t bx "$SYSUPGRADE" /images/kernel-1/cipher iv | wc -w
fdtget -t s "$SYSUPGRADE" /images/rootfs-1/cipher algo
fdtget -t bx "$SYSUPGRADE" /images/rootfs-1/cipher iv | wc -w
```

The FIP must contain BL31, BL33, and all five TBB certificates.\
Encrypted FIT payloads must use `tee_aes256` with 16-byte IVs, while their configurations remain signed with `sha256,rsa2048:fit_key`.\
The 32-byte `*.bl2.img.signkeyhash` is only for eFuse comparison and must never be written to NAND.

Host inspection validates image construction, not device-specific eFuse compatibility.\
Hardware cold-boot validation is mandatory before locking the platform key or enabling BootROM secure boot.

---

## Can an encrypted image be flashed?

Writing bytes and successfully booting them are different questions.\
An encrypted FIT cannot boot through the unsigned or signed U-Boot builds because only the encrypted U-Boot requests BL31 decryption.\
Likewise, an encrypted FIP requires the matching encryption-aware BL2 and the exact platform key used by the build.

| Current firmware/eFuse state | Direct encrypted transition | Conditions |
| --- | --- | --- |
| Unsigned vendor firmware | **No supported direct path** | Its NMBM partition geometry matches this tree, but its update format, BL31 eFuse service, and FIT decryption support are not established. First RAM-boot this tree's unsigned recovery and validate the migration path below. |
| This tree's unsigned firmware | **Yes, staged** | `ak r` must work, the exact platform key must be programmed first, and the complete encrypted FIT/FIP/BL2 set must be installed before booting it. |
| This tree's signed firmware | **Yes, staged** | Same requirements as unsigned; the encrypted BL2/FIP/FIT must also use the approved signing keys. |
| Signed firmware with BL2 public-key hash fused | **Yes, conditionally** | The encrypted BL2 signing-key hash must match the active eFuse slot. If `es` is blown, BootROM rejects any mismatch. A fused hash alone does not enforce verification until secure boot is enabled. |
| Signed firmware with matching BL2 hash and platform key fused | **Yes; intended final state** | The platform key must match the build byte-for-byte. If its write lock is blown, a mismatch cannot be repaired and the encrypted chain cannot boot. |

### Vendor migration probe

The captured vendor firmware uses the same BL2, environment, Factory, FIP, `ubi`, and `ubi_1` offsets and sizes as this tree.\
It also provides TFTP, `iminfo`, and `bootm`, but its captured FIT boot verifies only CRC32/SHA1 and shows no RSA or decryption step.

Before writing NAND, use vendor U-Boot to test this tree's unsigned recovery entirely from RAM:

```text
tftpboot ${loadaddr} openwrt-mediatek-filogic-emplus_ehr330_unsigned-initramfs-recovery.itb
iminfo ${loadaddr}
bootm ${loadaddr}
```

If recovery reaches Linux, use only read commands to confirm that the vendor BL31 accepts the eFuse SMC interface:

```sh
mtk-efuse-tool-mt7987 sa r
mtk-efuse-tool-mt7987 es r
mtk-efuse-tool-mt7987 ph r 0 0
mtk-efuse-tool-mt7987 lh r 0 0
mtk-efuse-tool-mt7987 al r
```

Stop if any read fails. A successful RAM boot and eFuse readback support migration to this tree's plain firmware;\
they do not make vendor U-Boot capable of booting encrypted FITs or prove that vendor `mtkupgrade` accepts OpenWrt images.

Do not mix profiles or builds. In particular, do not flash only an encrypted sysupgrade FIT under a plain U-Boot,\
or only an encrypted FIP under a plain BL2. Preserve `Factory`, retain UART access, and keep a raw NAND/OOB backup and an external recovery method available.

---

## Provision the platform key

Platform-key programming is irreversible because eFuse bits only move in one direction.\
Use stable power and confirm the EHR330 hardware requirement that `AVDD18_VQPS` is tied to 1.8 V before any write.

The target must be running this tree's MediaTek eFuse tool and a compatible BL31 eFuse service.\
Stop if either read command fails, if the platform-key field is not all zero, or if its write lock is already blown:

```sh
mtk-efuse-tool-mt7987 ak r
mtk-efuse-tool-mt7987 al r
```

On the build host, verify the key file length and transfer that exact file to the target over a controlled network:

```sh
KEY=keys/mtk-secure-boot/platform_key.bin
test "$(stat -c %s "$KEY")" -eq 16
sha256sum "$KEY"
```

On the target, compare the transferred file's size and SHA-256 with the host record, then program and read it back:

```sh
test "$(stat -c %s /tmp/platform_key.bin)" -eq 16
sha256sum /tmp/platform_key.bin
mtk-efuse-tool-mt7987 ak w /tmp/platform_key.bin
mtk-efuse-tool-mt7987 ak r
```

The readback contains secret material before lock. Compare it locally and do not capture, publish, or paste it into build logs.\
Do **not** run `al w` yet. First install and cold-boot the complete encrypted image set repeatedly.

After repeated encrypted cold boots pass, permanently lock platform-key writes and verify the lock:

```sh
mtk-efuse-tool-mt7987 al w
mtk-efuse-tool-mt7987 al r
```

Fully remove power, boot again, and confirm `ak r` no longer exposes the platform key to the normal world.\
The derived ROE/FIP/FIT keys are intentionally not readable at runtime; successful decryption and boot are their functional verification.

---

## First encrypted installation

This procedure starts from this tree's working unsigned or signed firmware.\
Do not use it directly from vendor firmware, and do not continue unless platform-key provisioning above has succeeded.

1. On the host, inspect and hash the complete encrypted artifact set.\
   If the device already has a BL2 key hash fused, compare the encrypted `*.bl2.img.signkeyhash` byte-for-byte with the active eFuse slot.
2. At the current plain U-Boot prompt, RAM-boot the matching **plain** recovery image.\
   A plain U-Boot cannot decrypt the encrypted recovery FIT.
3. From recovery, install the encrypted sysupgrade image and watch UART for the reboot.\
   Interrupt U-Boot before it attempts to boot the newly installed encrypted FIT.
4. In that same U-Boot session, load, write, and verify encrypted FIP first, then encrypted BL2 last.\
   Do not reset between these writes, and do not reset after any failed readback.
5. Fully remove power and validate repeated cold boots through Linux before locking any remaining eFuses.

At the current plain U-Boot prompt, select the plain recovery filename explicitly:

```text
setenv recoveryfile openwrt-mediatek-filogic-emplus_ehr330-signed-initramfs-recovery.itb
run boot_recovery
```

Use the `_unsigned` recovery instead if the source build is unsigned.\
On the recovery system, install the encrypted persistent image:

```sh
cd /tmp
IMAGE=openwrt-mediatek-filogic-emplus_ehr330-encrypted-squashfs-sysupgrade.itb
tftp -g -r "$IMAGE" -l "$IMAGE" 192.168.1.10
sha256sum "$IMAGE"
sysupgrade -T "/tmp/$IMAGE"
sysupgrade -n "/tmp/$IMAGE"
```

Do not run this from persistent OpenWrt because its UBI `kernel` volume backs the mounted `/dev/fit0`.\
Interrupt the automatic reboot, then install the encrypted bootloader pair:

```text
setenv fipfile openwrt-mediatek-filogic-emplus_ehr330-encrypted-spim-nand-bl31-uboot.fip
run load_fip
echo ${filesize}
crc32 ${loadaddr} ${filesize}
run write_fip
run verify_fip

setenv bl2file openwrt-mediatek-filogic-emplus_ehr330-encrypted-spim-nand-preloader.bin
run load_bl2
echo ${filesize}
crc32 ${loadaddr} ${filesize}
run write_bl2
run verify_bl2
```

Confirm each transfer size and CRC against the host artifact before its write.\
Both verification commands must report a successful byte comparison before `reset` or power removal.

---

## Runtime verification

Capture repeated cold boots over UART. An encrypted boot must reach each stage without authentication or decryption errors:

```text
BL2: ... OpenWrt ...
Verifying BL Anti-Rollback Version ... OK
BL2: Booting BL31
BL31: ... OpenWrt ...
U-Boot ... OpenWrt ...
Verifying Hash Integrity ... sha256,rsa2048:fit_key+ OK
Decrypting Data ... OK
```

Reaching BL31 verifies that BL2 authenticated and decrypted the FIP firmware.\
Reaching U-Boot verifies BL33 authentication and decryption, while the FIT messages verify payload signature and decryption.\
A successful Linux boot and readable root filesystem complete the functional chain check.

Read the permanent security state at runtime:

```sh
mtk-efuse-tool-mt7987 sa r
mtk-efuse-tool-mt7987 es r
mtk-efuse-tool-mt7987 ph r 0 0
mtk-efuse-tool-mt7987 lh r 0 0
mtk-efuse-tool-mt7987 al r
mtk-efuse-tool-mt7987 ak r
```

For the final production state, require RSA-2048/SHA-256, the approved BL2 hash in the active locked slot,\
secure boot reported as blown, the platform-key write lock reported as blown, and no platform-key exposure after a cold reset.

---

## Enable BootROM secure boot

Do this only after the exact signed or encrypted BL2/FIP/FIT set has passed repeated cold boots.\
The commands below are specific to MT7987 tool and driver version 2.0; algorithm value `0` is SHA-256.

Record the approved 32-byte BL2 signing-key hash on the host, then transfer that file to `/tmp/bl2.img.signkeyhash` on the EHR330.\
Read the current state and stop unless secure boot and slot-0 lock are unblown and slot 0 is all zeroes:

```sh
mtk-efuse-tool-mt7987 sa r
mtk-efuse-tool-mt7987 es r
mtk-efuse-tool-mt7987 ph r 0 0
mtk-efuse-tool-mt7987 lh r 0 0
mtk-efuse-tool-mt7987 dh r 0
```

Program SHA-256 slot 0, verify every byte, cold-boot the full chain, then lock and verify the slot:

```sh
mtk-efuse-tool-mt7987 ph w 0 /tmp/bl2.img.signkeyhash
mtk-efuse-tool-mt7987 ph r 0 0

mtk-efuse-tool-mt7987 lh w 0 0
mtk-efuse-tool-mt7987 lh r 0 0
mtk-efuse-tool-mt7987 ph r 0 0
```

Only after another successful cold boot, enable BootROM enforcement and verify it:

```sh
mtk-efuse-tool-mt7987 es w
mtk-efuse-tool-mt7987 es r
```

Fully remove power and require a clean boot through encrypted Linux.\
`V0: 100C` with `BL_VERIFY_FAILED` indicates an unsigned BL2; `V0: 706D` with `BL_VERIFY_FAILED` indicates a signing-key mismatch.\
Do not program `dh`, `ea`, `db`, `dj`, or slot 1 as part of this procedure.

---

## Future updates and key rotation

For routine updates within the encrypted profile, RAM-boot the encrypted recovery FIT, install the encrypted sysupgrade FIT,\
and update FIP before BL2 only when bootloader changes are required. Verify every NAND write before reset.

The BootROM hash pins the BL2 signing key after secure boot is enabled.\
Changing FIP signing or encryption material requires a matching BL2 and FIP; changing `fit_key.key` requires matching U-Boot/FIP and every FIT.\
Changing the platform key is impossible after `al` is blown, so retain the approved production key and salts for the device lifetime.

Before any bootloader update on a secure-boot device, compare the new `*.bl2.img.signkeyhash` byte-for-byte with the active eFuse hash.\
A mismatch means the new BL2 cannot boot. Never use eFuse write commands as part of a routine firmware update.
