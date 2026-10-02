# Build results — 2026-10-02

First successful host build of this device tree on the OrbStack `cruxbuild`
VM (`ubuntu:jammy`, amd64, 17 vCPU, 48 GiB RAM).

## Build inputs

| Item | Value |
|---|---|
| TWRP tree | `~/twrp-12.1` in the VM, manifest `twrp-12.1` (AOSP `android-12.1.0_r4` + TeamWin forks) |
| Device tree | this repository, copied in via `LOCAL_DEVICE` |
| Kernel | `kernel/xiaomi/crux` @ `b5ef11095c5389f937514d59da39c35cd244d971` (verified by `build-twrp.sh`) |
| Command | `lunch twrp_crux-eng && mka recoveryimage -j17` |
| Toolchain | AOSP 12.1 `clang-r416183b1`, kernel linked with `ld.lld` + LLVM binutils |

## Build outputs

| Artifact | Size (bytes) | SHA-256 |
|---|---|---|
| `recovery.img` | 134,217,728 (128 MiB) | `a715b1fbde3d6e03bb37aea8c9d4a0c878f8997963cc801aebc186ee34b17217` |
| `ramdisk-recovery.img` | 24,518,969 | `59c006aa8c46c06b79285a3e95b6f9ce9004ee77bc6c07d6b92adbcf1c71e3f3` |
| `kernel` (`Image-dtb`) | 50,441,476 | `8cb961b13d035933dbf9e76178b8dd8a0bf292b505c2331ac1c8502edb4f38d1` |
| `Image` (raw) | 48,443,408 | `af1063fa80a5850e87f6d11ac78a69d352704950d03296730d45179350e86889` |
| `twrp-crux.itb` | 44,398,928 | `3170852ae65de269f62903e4e49343056be47ad5e4d9c4cda79d17201e335b23` |

Archived in the workspace at `out/twrp-crux-2026-10-02/` (with `SHA256SUMS`
and the generated `twrp-crux.its`).

## Verified properties

- `recovery.img`: `ANDROID!` magic, **header version 1**, page size 4096,
  kernel address `0x8000`, ramdisk address `0x01000000`, tags `0x00000100`;
  kernel 50,441,476 B + ramdisk 24,518,969 B.
- Kernel banner:
  `Linux version 4.14.357-openela-Marisa-20260104-ksunext ...` built with
  `clang version 12.0.7` and `LLD 12.0.7`.
- TWRP identity string in the recovery ramdisk:
  `3.7.1_12-crux-twrp-12.1` (`TW_DEVICE_VERSION := crux-twrp-12.1`).
- Recovery root contains `recovery.fstab`, `twrp.flags`,
  `init.recovery.qcom.rc`, `init.recovery.qcom_decrypt.rc`,
  `init.recovery.qcom_decrypt.fbe.rc` (from `device/qcom/twrp-common`) and
  the stock `qseecomd` / keymaster 4.0 / gatekeeper 1.0 blobs.
- `init.recovery.qcom.rc` includes the
  `import /init.recovery.qcom_decrypt.rc` line exactly once.

## U-Boot FIT

`scripts/make-fit.sh --out-dir .../out/target/product/crux --mkimage /usr/bin/mkimage`:

| Item | Value |
|---|---|
| FIT size | 44,398,928 B (`0x2a57950`) |
| UFS blocks (4096 B) | `0x2a58` |
| Slot | 64 MiB TWRP cache slot; 22,177 KiB free |
| Kernel | raw `Image`, gzip-compressed in the FIT (U-Boot decompresses, `CONFIG_GZIP=y`) |
| Ramdisk | original gzip, `compression = "none"` (kernel unpacks, `CONFIG_RD_GZIP=y`) |
| FDT | `prebuilt/live-dt/twrp-live.dtb` (ABL live DT) |

Updated menu command for `board/qualcomm/xiaomi-crux.env` (the boot-menu
session owns this file; the block count changed from `0x3486` to `0x2a58`):

```text
boot_twrp=scsi dev 0; scsi read 0xC0000000 0x34000 0x2a58; setenv fdt_high 0x84900000; setenv initrd_high 0x84200000; bootm start 0xC0000000; bootm loados; bootm ramdisk; bootm prep; bootm go
```

## Issues found and fixed during the build

| Issue | Fix |
|---|---|
| `build/envsetup.sh` aborts under `set -u` (`TOP: unbound variable`) | `build-twrp.sh` drops `-u` and re-enables `-e` after sourcing |
| A symlinked `device/xiaomi/crux` is not found by the AOSP product scan (`lunch` cannot locate `twrp_crux`) | `setup-twrp.sh` copies the tree; `build-twrp.sh` rsyncs it when `LOCAL_DEVICE` is set |
| `TARGET_COPY_OUT_VENDOR must be set to 'vendor'` | added `TARGET_COPY_OUT_VENDOR := vendor` |
| `TARGET_SYSTEM_PROP` expanded to `/system.prop` (missing `build/make/core/system.prop`) | use literal `device/xiaomi/crux/...` paths instead of `$(LOCAL_PATH)` for late-expanded variables |
| vmlinux link: `aarch64-linux-android-ld: Cannot change output format whilst linking AArch64 binaries` | build the kernel with `LD=ld.lld AR=llvm-ar NM/OBJCOPY/OBJDUMP/STRIP=llvm-*` from the tree's `clang-r416183b1` |

## Not yet verified

- Nothing has been flashed or booted on hardware.
- Display (RGBX_8888 DRM path), touch (ST FTS firmware), USB (adb/MTP/OTG),
  vibrator and especially PE13 data decryption (FBE v2 + metadata
  encryption) still need on-device validation — see `DEVICE-TEST.md`.
