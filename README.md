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
| This tree's unsigned firmware | **Yes, staged** | `ak r` must work, the exact platform key must be programmed first, and the complete encrypted FIT/FIP/BL2 set must be installed before booting it. |
| This tree's signed firmware | **Yes, staged** | Same requirements as unsigned; the encrypted BL2/FIP/FIT must also use the approved signing keys. |
| Signed firmware with BL2 public-key hash fused | **Yes, conditionally** | The encrypted BL2 signing-key hash must match the active eFuse slot. If `es` is blown, BootROM rejects any mismatch. A fused hash alone does not enforce verification until secure boot is enabled. |
| Signed firmware with matching BL2 hash and platform key fused | **Yes; intended final state** | The platform key must match the build byte-for-byte. If its write lock is blown, a mismatch cannot be repaired and the encrypted chain cannot boot. |

Do not mix profiles or builds. In particular, do not flash only an encrypted sysupgrade FIT under a plain U-Boot,\
or only an encrypted FIP under a plain BL2. Preserve `Factory`, retain UART access, and keep a raw NAND/OOB backup and an external recovery method available.

---

## Safe provisioning order

The order matters. Never install encrypted firmware before programming its exact platform key,\
and never lock either key field or enable BootROM secure boot until the preceding cold-boot gate passes.

For an encrypted production device, complete the numbered sections in order:

1. Install the complete signed image set and validate repeated cold boots.
2. Program and read back the platform key, but leave its write lock unblown.
3. Install the complete encrypted FIT/FIP/BL2 set without locking any eFuse field.
4. Validate repeated encrypted cold boots through Linux.
5. Lock the platform key, fully remove power, and validate encrypted boot again.
6. Program and lock the installed BL2 signing-key hash, then enable BootROM secure boot last and validate the final chain.

Stop immediately if any transfer, readback, verification, or cold boot fails. Do not advance to the next irreversible step.\
For a signed-only production device, complete step 1, skip the platform-key and encryption sections, then continue at step 6.

The U-Boot eFuse field indexes in this procedure are the MediaTek MT7987/MT7988 mapping.\
Do not reuse them on MT7981, MT7986, or another SoC without its own official field table.

---

## MT7987/MT7988 eFuse command reference

These tables reproduce the command mappings from the official MediaTek Secure Boot Provision Application Note.\
They apply only to MT7987/MT7988. In every command, `r` means read while `w` permanently writes or blows OTP bits.

The Linux examples use the executable installed by this build, `mtk-efuse-tool-mt7987`.\
The official document abbreviates its name to `mtk-efuse-tool`; the command arguments are the same.

### Linux/kernel-driver `mtk-efuse-tool` short forms

This userspace command sends the semantic operations below to the kernel `mtk-efuse` netlink driver.

| Short form | Read command arguments | Write command arguments | Function |
| --- | --- | --- | --- |
| `ph` | `ph r <PUBK_HASH_IDX> <HASH_ALGO>` | `ph w <PUBK_HASH_IDX> <PUBK_HASH_FILE>` | Read or write a BL2 public-key hash. |
| `lh` | `lh r <PUBK_HASH_IDX> <HASH_ALGO>` | `lh w <PUBK_HASH_IDX> <HASH_ALGO>` | Read or permanently lock a public-key hash. |
| `dh` | `dh r <PUBK_HASH_IDX>` | `dh w <PUBK_HASH_IDX>` | Read or permanently disable a public-key hash slot. |
| `sa` | `sa r` | `sa w <ALGO_IDX>` | Read or permanently select the BootROM signature/hash algorithm. |
| `dj` | `dj r` | `dj w` | Read or permanently disable JTAG. |
| `es` | `es r` | `es w` | Read or permanently enable the BootROM secure-boot chain. |
| `ea` | `ea r` | `ea w` | Read or permanently enable BootROM anti-rollback. |
| `db` | `db r` | `db w` | Read or permanently disable the BootROM command interface. |
| `ak` | `ak r` | `ak w <PLAT_KEY_BIN>` | Read or write the 16-byte platform key. |
| `al` | `al r` | `al w` | Read or permanently lock platform-key writes. |

Prefix each argument sequence with `mtk-efuse-tool-mt7987`, for example `mtk-efuse-tool-mt7987 sa r`.\
The index and algorithm parameters have these meanings:

| Parameter | Value | Meaning |
| --- | --- | --- |
| `PUBK_HASH_IDX` | `0` | First SHA-256 hash slot; the only valid logical slot for SHA-384. |
| `PUBK_HASH_IDX` | `1` | Second SHA-256 hash slot. |
| `HASH_ALGO` | `0` | SHA-256 public-key hash. |
| `HASH_ALGO` | `1` | SHA-384 public-key hash. |
| `ALGO_IDX` | `0` | RSA-2048 with SHA-256. |
| `ALGO_IDX` | `1` | RSA-3072 with SHA-256. |
| `ALGO_IDX` | `2` | RSA-3072 with SHA-384. |

### U-Boot `efuse` raw field indexes

U-Boot accepts `efuse read <index>` and `efuse write <index> <hex-data>`.\
Unlike the Linux tool, this raw interface does not group related fields or accept a key file.

| Index | Field | Write data | Linux short-form equivalent |
| ---: | --- | --- | --- |
| `8` | Public-key hash 0; first 32 bytes of the SHA-384 hash | Hash bytes in hexadecimal | `ph` for slot 0 |
| `9` | Public-key hash 1; last 16 bytes plus padding for SHA-384 | Hash bytes in hexadecimal | `ph` for slot 1, or the remainder of SHA-384 slot 0 |
| `16` | Public-key hash 0 lock; first 32-byte lock for SHA-384 | `1` | `lh` for slot 0 |
| `17` | Public-key hash 1 lock for its first 16 bytes; last 16-byte lock for SHA-384 | `1` | Part of `lh` for slot 1, or SHA-384 slot 0 |
| `18` | Public-key hash 1 lock for its last 16 bytes | `1` | Part of `lh` for SHA-256 slot 1 |
| `21` | Disable public-key hash 0 | `1` | `dh w 0` |
| `24` | BootROM security algorithm | `0`, `1`, or `2` from `ALGO_IDX` above | `sa` |
| `25` | Disable JTAG | `1` | `dj` |
| `26` | Enable the BootROM secure-boot chain | `1` | `es` |
| `27` | Enable BootROM anti-rollback | `1` | `ea` |
| `33` | Disable the BootROM command interface | `1` | `db` |
| `37` | 16-byte platform-key value | 32 hexadecimal digits | `ak` |
| `38` | Lock platform-key writes | `1` | `al` |

For RSA-3072/SHA-384, the 48-byte hash and its locks span fields `8`, `9`, `16`, and `17`.\
For SHA-256 slot 1, both lock fields `17` and `18` must be blown. Do not hand-compose the padded field-9 SHA-384 value without following the official provisioning procedure.

Every field listed above is security-sensitive OTP state, not a configuration setting.\
Use read commands while inspecting a device, and execute each write only at its corresponding cold-boot gate in this procedure.

Both interfaces reach the same BL31 eFuse service and modify the same physical OTP fields.\
Choose one provisioning interface for a device and execute only that interface's write block at each step:

| Interface | Prefer it when | Input behavior |
| --- | --- | --- |
| U-Boot `efuse` | Linux is unavailable, or provisioning is performed from a controlled recovery/UART session. | Uses raw field indexes and hexadecimal values; the operator must handle field grouping and byte order. |
| Linux `mtk-efuse-tool-mt7987` | The validated signed or encrypted Linux system boots and the eFuse tool and driver are available. | Uses semantic commands and key/hash files; it handles the MT7987 field grouping. |

The paired command blocks below are alternatives, not a sequence. Never run both write blocks for the same field.\
Read-only checks may be repeated through either interface, provided the field is still readable.

---

## Step 1: Install signed images

The signed profile provides authentication without firmware encryption and does not require a platform key.\
Do not write U-Boot eFuse fields 37 or 38 when deploying signed-only firmware.

This procedure assumes the device is already running this tree's working unsigned or signed U-Boot.

At U-Boot, RAM-boot a recovery FIT that the **currently running** U-Boot can verify:

```text
# Current signed U-Boot:
setenv recoveryfile openwrt-mediatek-filogic-emplus_ehr330-signed-initramfs-recovery.itb

# Current unsigned U-Boot:
setenv recoveryfile openwrt-mediatek-filogic-emplus_ehr330_unsigned-initramfs-recovery.itb

run boot_recovery
```

Install the signed persistent image from recovery:

```sh
cd /tmp
IMAGE=openwrt-mediatek-filogic-emplus_ehr330-signed-squashfs-sysupgrade.itb
tftp -g -r "$IMAGE" -l "$IMAGE" 192.168.1.10
sha256sum "$IMAGE"
sysupgrade -T "/tmp/$IMAGE"
sysupgrade -n "/tmp/$IMAGE"
```

Do not run this from persistent OpenWrt because its UBI `kernel` volume backs the mounted `/dev/fit0`.\
Interrupt the automatic reboot, then write and verify the signed FIP before writing BL2 last:

```text
setenv fipfile openwrt-mediatek-filogic-emplus_ehr330-signed-spim-nand-bl31-uboot.fip
run load_fip
echo ${filesize}
crc32 ${loadaddr} ${filesize}
run write_fip
run verify_fip

setenv bl2file openwrt-mediatek-filogic-emplus_ehr330-signed-spim-nand-preloader.bin
run load_bl2
echo ${filesize}
crc32 ${loadaddr} ${filesize}
run write_bl2
run verify_bl2
```

Confirm each transfer size and CRC against the host artifact. Do not reset after a failed readback or between the FIP and BL2 writes.\
If BootROM secure boot is enabled, the signed BL2 hash must match the active eFuse slot before writing anything.

After reset, require the signed BL2, authenticated FIP, signed FIT, and Linux to boot without verification errors.\
Platform-key state is irrelevant to signed-only images because no firmware decryption is requested.

---

## Step 2: Write the platform key

Treat the platform-key write itself as irreversible because eFuse bits only move in one direction; an unblown write lock does not make a bad key replaceable.\
Use stable power and confirm the EHR330 hardware requirement that `AVDD18_VQPS` is tied to 1.8 V before any write.

The encrypted build reads `keys/mtk-secure-boot/platform_key.bin` relative to the repository root.\
Generate it with `./scripts/gen-mtk-secureboot-keys.sh --encryption`.\

Do not confuse `platform_key.bin` with the proprietary `mtk_plat_key.a` build library.\
There is no separate platform-key enable bit: writing field 37, or `ak w`, programs the key and makes it available for key derivation.\
The later field-38 or `al w` step permanently locks further writes and enables read protection after reset.

The target must be running a compatible BL31 eFuse service.\
Choose one read block and stop if the platform-key field is not all zero, its write lock is already blown, or any command fails.

**U-Boot pre-write check:**

```text
efuse read 37
efuse read 38
```

**Linux pre-write check:**

```sh
mtk-efuse-tool-mt7987 ak r
mtk-efuse-tool-mt7987 al r
```

From the repository root, verify the source key file:

```sh
KEY=keys/mtk-secure-boot/platform_key.bin
test "$(stat -c %s "$KEY")" -eq 16
sha256sum "$KEY"
```

Choose exactly one of the following write methods.

**U-Boot method:** Convert the key to exactly 32 hexadecimal digits, then program and read back raw field 37:

```sh
xxd -p -c 16 "$KEY"
```

```text
efuse write 37 <PLATFORM_KEY_HEX>
efuse read 37
```

**Linux method:** Transfer the same binary key to a temporary path on the target, verify its size and approved checksum there, then program and read it back:

```sh
KEY=/tmp/platform_key.bin
test "$(stat -c %s "$KEY")" -eq 16
sha256sum "$KEY"
mtk-efuse-tool-mt7987 ak w "$KEY"
mtk-efuse-tool-mt7987 ak r
rm -f "$KEY"
```

The U-Boot command/readback and Linux `ak r` output contain secret material before lock. Disable UART or shell capture, compare locally, clear the terminal buffer, and remove the target copy afterward.\
Do **not** write field 38 or run `al w` yet. Continue directly to step 3 and prove that this exact key decrypts the complete encrypted image set.

---

## Step 3: Install encrypted images

This procedure assumes the device is already running this tree's working unsigned or signed firmware.\
Do not continue unless platform-key provisioning above has succeeded.

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

## Step 4: Verify encrypted runtime

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

Before locking any eFuse, require repeated successful cold boots through Linux with no authentication or decryption errors.\
Keep UART and the external recovery method available for the remaining provisioning steps.

---

## Step 5: Lock the platform key

Only after step 4 passes, permanently lock platform-key writes.\
Choose exactly one method; both write the same OTP lock.

**U-Boot method:**

```text
efuse write 38 1
efuse read 38
```

**Linux method:**

```sh
mtk-efuse-tool-mt7987 al w
mtk-efuse-tool-mt7987 al r
```

Fully remove power and require another successful encrypted boot through Linux.\
Then confirm through either `efuse read 37` in U-Boot or `mtk-efuse-tool-mt7987 ak r` in Linux that the platform key is no longer exposed.\
The derived ROE/FIP/FIT keys are intentionally not readable at runtime; successful decryption and boot are their functional verification.

Stop if the lock state, read protection, or encrypted cold boot is not exactly as expected.\
Do not program the BL2 signing-key hash or enable BootROM secure boot on a device that fails this gate.

---

## Step 6: Enable BootROM secure boot

For an encrypted deployment, do this only after steps 1 through 5 have passed.\
For a signed-only deployment, do this only after the exact signed BL2/FIP/FIT set has passed repeated cold boots.\
The alternatives below use the MT7987/MT7988 mappings and the EHR330 RSA-2048/SHA-256 configuration.

From the repository root, verify the installed profile's 32-byte BL2 signing-key hash:

```sh
HASH=bin/targets/mediatek/filogic/openwrt-mediatek-filogic-emplus_ehr330-encrypted-bl2.img.signkeyhash
test "$(stat -c %s "$HASH")" -eq 32
sha256sum "$HASH"
```

Use the `-signed-` hash instead for a signed-only deployment.\
Choose one pre-write read block and stop unless RSA-2048/SHA-256 is selected, secure boot and the slot-0 lock are unblown, slot 0 is all zeroes, and its disable field is unblown.

**U-Boot pre-write check:**

```text
efuse read 24
efuse read 26
efuse read 8
efuse read 16
efuse read 21
```

**Linux pre-write check:**

```sh
mtk-efuse-tool-mt7987 sa r
mtk-efuse-tool-mt7987 es r
mtk-efuse-tool-mt7987 ph r 0 0
mtk-efuse-tool-mt7987 lh r 0 0
mtk-efuse-tool-mt7987 dh r 0
```

Choose exactly one method to program SHA-256 slot 0.

**U-Boot method:** Convert the source hash without changing its byte order, replace the placeholder with the exact 64-digit result, and verify every byte after the write:

```sh
xxd -p -c 32 "$HASH"
```

```text
efuse write 8 <BL2_SIGNING_KEY_HASH_HEX>
efuse read 8
```

**Linux method:** Transfer the same binary hash file to the target, verify its size and approved checksum there, then write and read back logical SHA-256 slot 0:

```sh
HASH=/tmp/bl2.img.signkeyhash
test "$(stat -c %s "$HASH")" -eq 32
sha256sum "$HASH"
mtk-efuse-tool-mt7987 ph w 0 "$HASH"
mtk-efuse-tool-mt7987 ph r 0 0
rm -f "$HASH"
```

Stop on any mismatch. Cold-boot the installed image set once more before permanently locking slot 0.\
Choose exactly one lock method; both write the same OTP lock.

**U-Boot lock method:**

```text
efuse write 16 1
efuse read 16
efuse read 8
```

**Linux lock method:**

```sh
mtk-efuse-tool-mt7987 lh w 0 0
mtk-efuse-tool-mt7987 lh r 0 0
mtk-efuse-tool-mt7987 ph r 0 0
```

Only after the locked slot and another cold boot are verified, enable BootROM enforcement and verify it.\
Choose exactly one enable method. This is the final irreversible provisioning command.

**U-Boot enable method:**

```text
efuse write 26 1
efuse read 26
```

**Linux enable method:**

```sh
mtk-efuse-tool-mt7987 es w
mtk-efuse-tool-mt7987 es r
```

Fully remove power and require a clean boot through the selected signed or encrypted Linux image.\
For both profiles, require RSA-2048/SHA-256, the approved BL2 hash in locked slot 0, and secure boot reported as blown.\
For the encrypted profile, additionally require the platform-key write lock to be blown and neither `efuse read 37` nor `ak r` to expose the key after the cold reset.\
Do not write U-Boot fields 21, 25, 27, or 33, run their Linux `dh`, `dj`, `ea`, or `db` write equivalents, or provision public-key hash slot 1 as part of this procedure.

### BootROM UART comparison

Use these UART traces to distinguish a normal BootROM handoff from the two expected secure-boot failures.

Normal BootROM:

> `V0: 0000`\
> `00: 0000`

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

> `V0: 100C`, `INVALID_SIG_TYPE`\
> `00: 1017`, `BL_VERIFY_FAILED`

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

Fused BootROM with signed BL2 but the wrong key:

> `V0: 706D`, `KEY_MISMATCH`\
> `00: 1017`, `BL_VERIFY_FAILED`

---

## Future updates and key rotation

For routine updates within the signed profile, RAM-boot the signed recovery FIT, install the signed sysupgrade FIT,\
and update the signed FIP before BL2 only when bootloader changes are required. Verify every NAND write before reset.

For routine updates within the encrypted profile, RAM-boot the encrypted recovery FIT, install the encrypted sysupgrade FIT,\
and update FIP before BL2 only when bootloader changes are required. Verify every NAND write before reset.

The BootROM hash pins the BL2 signing key after secure boot is enabled.\
Changing FIP signing or encryption material requires a matching BL2 and FIP; changing `fit_key.key` requires matching U-Boot/FIP and every FIT.\
Changing the platform key is impossible after `al` is blown, so retain the approved production key and salts for the device lifetime.

Before any bootloader update on a secure-boot device, compare the new `*.bl2.img.signkeyhash` byte-for-byte with the active eFuse hash.\
A mismatch means the new BL2 cannot boot. Never use eFuse write commands as part of a routine firmware update.
