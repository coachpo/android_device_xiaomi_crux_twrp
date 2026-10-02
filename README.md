# Crux TWRP — Xiaomi Mi 9 Pro 5G (TWRP 3.7.1 / twrp-12.1)

Self-maintained TWRP device tree and build tooling for the Xiaomi Mi 9 Pro 5G
(codename **crux**, SM8150 / msmnile).

| Item | Value |
|---|---|
| TWRP baseline | **3.7.1** on the **`twrp-12.1`** branch (version string `3.7.1_12`) |
| Device tree path | `device/xiaomi/crux` |
| Kernel | `kernel/xiaomi/crux` @ `b5ef11095c5389f937514d59da39c35cd244d971` — Linux **4.14.357-openela** (`-Marisa-20260104-ksunext`), built **from source** |
| Boot path | **All entries go through U-Boot**; TWRP is packed as a FIT and loaded from the cache partition by the U-Boot boot menu |
| Status | **Code-level adaptation complete; not yet compiled or device-verified** (see `docs/STATUS.md`) |

The U-Boot boot menu is maintained by another session. This repository never
changes U-Boot, the cache payload image or the device; it produces the FIT and
the exact `boot_twrp` environment line to hand over. See `docs/UBOOT.md`.

## Repository layout

```text
device/xiaomi/crux/          TWRP device tree (BoardConfig, product, recovery root)
  prebuilt/live-dt/          ABL live device tree used by the proven TWRP FIT
  recovery/root/             init scripts, fstab, twrp.flags, stock crypto blobs
manifests/crux-twrp.xml      repo local manifest (device tree + kernel source)
scripts/setup-twrp.sh        repo init/sync a TWRP 12.1 tree
scripts/build-twrp.sh        lunch twrp_crux-eng && mka recoveryimage
scripts/make-fit.sh          package recovery.img pieces into twrp-crux.itb
scripts/insert-cache-payload.py   write the FIT into a cache payload copy
docs/UBOOT.md                boot chain, FIT contract, cache layout
docs/KERNEL.md               kernel source integration and toolchain
docs/DEVICE-TEST.md          on-device validation plan (read-only first)
docs/STATUS.md               what is done, what is open
```

## Requirements

- x86_64 Linux build host (the workspace uses the OrbStack `cruxbuild` VM) with
  ~150 GB free for the TWRP 12.1 tree plus `out/`.
- `repo` (Android repo launcher).
- U-Boot `mkimage` for packaging the FIT (the crux U-Boot tree's
  `tools/mkimage`, or any U-Boot `mkimage` on `PATH`).
- For later device work: `adb`, `fastboot`, and the EDL recovery path.

## Quick start

```sh
# 1. Sync a TWRP 12.1 tree (downloads the minimal TWRP manifest + crux tree + kernel)
scripts/setup-twrp.sh "$HOME/twrp-12.1"

# 2. Build TWRP (builds the kernel from source through vendor/twrp/build/tasks/kernel.mk)
scripts/build-twrp.sh "$HOME/twrp-12.1"
#    output: $HOME/twrp-12.1/out/target/product/crux/recovery.img
#            $HOME/twrp-12.1/out/target/product/crux/ramdisk-recovery.img

# 3. Package the U-Boot FIT (kernel compressed, live DT, recovery ramdisk)
scripts/make-fit.sh --out-dir "$HOME/twrp-12.1/out/target/product/crux"
#    output: out/fit-twrp/twrp-crux.itb + a new boot_twrp command line

# 4. (later, owned by the boot-menu session) prepare a cache payload copy
scripts/insert-cache-payload.py --fit out/fit-twrp/twrp-crux.itb \
    --base ../out/crux-bootmenu-2026-10-02/cache-payload.img
```

For quick kernel iterations TWRP can reuse an already-built kernel instead of
rebuilding the source:

```sh
TARGET_PREBUILT_KERNEL="$PWD/../out/crux-kernel-2026-10-01/Image" \
TARGET_FORCE_PREBUILT_KERNEL=1 scripts/build-twrp.sh "$HOME/twrp-12.1"
```

## Why twrp-12.1 and not a newer branch

The previous research in this workspace concluded:

- The latest **released** TWRP is **3.7.1** (2024-02-21), built on the
  `android-12.1` branch (version `3.7.1_12`); it supports Android 12.1 and up,
  which covers the PE13 (Android 13) userdata layout.
- `android-13`, `android-14` and `android-14.1` exist in the TWRP repository
  but have **no official release** (`android-14.1` still identifies as
  `3.7.1_14`). They are a later, separate evaluation.
- Linux 4.14 is **not** a documented TWRP ceiling. The crux kernel already has
  `ANDROID_BINDERFS`, `DM_DEFAULT_KEY`, `DM_CRYPT`, `DM_VERITY`,
  `FS_ENCRYPTION` (+ inline crypt), `EROFS_FS`, `SCSI_UFS_QCOM`, `DRM_MSM`,
  `USB_CONFIGFS_F_FS/F_MTP`, `INPUT_EVDEV` and the `ST_FTS_V521` touch driver.
  The one deliberate difference is that TWRP 12.1's vold still falls back to
  the session keyring for v1 fscrypt policies, while 14.1 removed that
  fallback — relevant only if `twrp-14.1` is evaluated later.

## Provenance of the included blobs

`recovery/root/` contains the stock crux TEE/recovery userspace needed for
decryption and haptics (`qseecomd`, keymaster 4.0, gatekeeper 1.0, vibrator,
their `lib64` dependencies and firmware). They come from the device's stock
firmware via the community crux TWRP device tree (TWRP A12.1). See `NOTICE`.

The kernel is **not** committed; it is built from
`coachpo/kernel_xiaomi_crux` (PE13 kernel line).

## Licence

Original content: Apache-2.0. Bundled stock binaries: see `NOTICE`.
