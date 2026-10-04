# Kernel integration

## Source

The kernel is **not** stored in this repository. TWRP's inline kernel build
(`vendor/twrp/build/tasks/kernel.mk`) builds it from:

| Variable | Value |
|---|---|
| `TARGET_KERNEL_SOURCE` | `kernel/xiaomi/crux` |
| `TARGET_KERNEL_CONFIG` | `crux_defconfig` |
| `TARGET_KERNEL_CLANG_COMPILE` | `true` |
| `TARGET_KERNEL_CLANG_VERSION` | `prelude` (PE13 Prelude clang 16.0.2) |
| `BOARD_KERNEL_IMAGE_NAME` | `Image-dtb` |
| `BOARD_KERNEL_SEPARATED_DTBO` | `true` |

The manifest follows branch `crux-pe13-cepheus` and the build script warns when
the checkout differs from the expected revision; it does not pin the commit:

```xml
<project name="coachpo/kernel_xiaomi_crux" path="kernel/xiaomi/crux"
         remote="github"
         revision="crux-pe13-cepheus" clone-depth="1" />
```

The expected revision is `e45a24f31ee0d48edba0cc164063c3a631589e31` (see
`scripts/build-twrp.sh`). The branch is the PE13 Cepheus baseline migration:

```text
Linux version 4.14.305-Crux-PE-ge45a24f31ee0
```

It is the official PE Cepheus source
(`PixelExperience-Devices/kernel_xiaomi_cepheus` `f4048f154b51`, branch
`thirteen`, Linux 4.14.305) plus the Crux migration and early-boot memory-limit fixes. The verified
Image is unchanged by the current DT-only repair; see
[`BUILD-RESULTS-2026-10-04-DT.md`](BUILD-RESULTS-2026-10-04-DT.md). The migration record, patch set and Git bundle
are in [`../../out/crux-kernel-cepheus-2026-10-03/`](../../out/crux-kernel-cepheus-2026-10-03/README.md);
the legacy archive of the old tree is in
[`../../out/crux-kernel-legacy-archive-2026-10-03/`](../../out/crux-kernel-legacy-archive-2026-10-03/README.md).
For an offline build or a recorded revision unavailable from the moving remote
branch, fetch the matching migration bundle locally. Verify its contents and
selected commit; a previous branch publication does not prove the current tip:

```sh
git -C kernel/xiaomi/crux fetch /path/to/crux-pe13-cepheus.bundle \
    crux-pe13-cepheus:refs/remotes/local/crux-pe13-cepheus
git -C kernel/xiaomi/crux checkout -B crux-pe13-cepheus local/crux-pe13-cepheus
```

The previous `thirteen-plus` line (`50443f853589`, 4.14.357-openela "Marisa")
is superseded by this baseline and is no longer built by TWRP.

## Toolchain

The kernel is built with the PE13 "Prelude" clang 16.0.2 toolchain in LLVM
mode, matching the PE13 build of the same baseline. `device/xiaomi/crux/BoardConfig.mk`
sets:

```make
TARGET_KERNEL_CLANG_VERSION := prelude
TARGET_KERNEL_CLANG_PATH := $(shell pwd)/prebuilts/clang/host/linux-x86/clang-prelude
TARGET_KERNEL_CLANG_BIN := $(TARGET_KERNEL_CLANG_PATH)/bin
TARGET_KERNEL_ADDITIONAL_FLAGS += \
    LLVM=1 LLVM_IAS=1 \
    LD=$(TARGET_KERNEL_CLANG_BIN)/ld.lld \
    LD_COMPAT=$(TARGET_KERNEL_CLANG_BIN)/ld.lld \
    AR=$(TARGET_KERNEL_CLANG_BIN)/llvm-ar \
    NM=$(TARGET_KERNEL_CLANG_BIN)/llvm-nm \
    OBJCOPY=$(TARGET_KERNEL_CLANG_BIN)/llvm-objcopy \
    OBJDUMP=$(TARGET_KERNEL_CLANG_BIN)/llvm-objdump \
    STRIP=$(TARGET_KERNEL_CLANG_BIN)/llvm-strip
```

The twrp-12.1 default `clang-r416183b1` (12.0.7) predates the Cepheus
baseline and is not used for the kernel. The kernel toolchain is not vendored
in this repository: the build tree needs
`prebuilts/clang/host/linux-x86/clang-prelude`, either a copy or a symlink to
the PE13 tree
(`~/crux-pe13-offline-2026-09-25/pe13/prebuilts/clang/host/linux-x86/clang-prelude`).
The setup manifest now fetches this toolchain from
`https://gitlab.com/jjpprrrr/prelude-clang.git` at
`ac8fce34dc0f6918672100d7a6e867a66b8afa8f`, the actual local compiler revision.
`scripts/build-twrp.sh` also applies the repository's board DT patch before
building: it disables the unused USB1 extcon that conflicts with SMB5. The
patch is idempotent on the local corrected tree. Its SHA-256 is included in
release metadata; the kernel branch remains the PE migration branch.

TWRP's `kernel.mk` still passes `CROSS_COMPILE_ARM32` (AOSP arm binutils) and
hardcodes `HOSTCC`/`HOSTCXX` to the tree's clang 12 for host utilities; target
compilation and the LLVM binutils come from Prelude. `LD_COMPAT` is set
explicitly because the Cepheus `vdso32/Makefile` only falls back to `$(LD)`
when the make variable `LLVM` is set, and otherwise expects a host `ld` that
the build environment does not have.

Alternatively, reuse an already-built kernel image (PE13 build):

```sh
TARGET_PREBUILT_KERNEL=/path/to/out/crux-kernel-cepheus-2026-10-03/Image \
TARGET_FORCE_PREBUILT_KERNEL=1 scripts/build-twrp.sh "$HOME/twrp-12.1"
```

## Optional TWRP kernel fragment

The committed PE13 `crux_defconfig` contains everything recovery needs. Two
options are absent and are **optional** for the first bring-up:

| Option | Effect | Why it may be wanted |
|---|---|---|
| `CONFIG_SERIAL_MSM_GENI_CONSOLE=y` | kernel console on `ttyMSM0` | kernel UART console logs (CDC-ACM is a separate U-Boot console) |
| `CONFIG_DRM_FBDEV_EMULATION=y` | `/dev/fb0` | fallback if the TWRP DRM path misbehaves |

(`CONFIG_PSTORE*` is already enabled in the Cepheus `crux_defconfig`.)

To add them, place a fragment in the kernel repository at
`arch/arm64/configs/crux_twrp_defconfig` and set
`TARGET_KERNEL_ADDITIONAL_CONFIG := crux_twrp_defconfig`. This is deliberately
not enabled yet: it modifies the shared PE13 kernel repository and the missing
options do not block recovery. The verified Image was built at `e45a24f31ee0`; the Crux source DT now
has an uncommitted board correction disabling the unused USB1 GPIO extcon; the Crux hung-task/softlockup diagnostics that used to
be uncommitted on the old tree are part of the migration commits here.

## Verified kernel capabilities for TWRP

From the built Cepheus-baseline `kernel.config`
(`out/crux-kernel-cepheus-2026-10-03/kernel.config`, `crux_defconfig`):

- `CONFIG_ANDROID_BINDERFS=y`, `CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"`
- `CONFIG_DM_DEFAULT_KEY=y` (metadata encryption), `CONFIG_DM_CRYPT=y`, `CONFIG_DM_VERITY=y`, `CONFIG_DM_SNAPSHOT=y`
- `CONFIG_FS_ENCRYPTION=y`, `CONFIG_FS_ENCRYPTION_INLINE_CRYPT=y`, `CONFIG_BLK_INLINE_ENCRYPTION=y` (FBE v2 / ICE)
- `CONFIG_EXT4_FS=y`; `CONFIG_EROFS_FS` is **not** set in the Cepheus baseline (the PE13 crux `twrp.flags` mounts `system` as ext4, so recovery does not need EROFS)
- `CONFIG_SCSI_UFS_QCOM=y`, `CONFIG_PHY_QCOM_UFS=y`
- `CONFIG_USB_DWC3=y`, `CONFIG_USB_CONFIGFS_F_FS=y`, `CONFIG_USB_CONFIGFS_F_MTP=y`, `CONFIG_USB_STORAGE=y`
- `CONFIG_DRM_MSM=y`, `CONFIG_DRM_KMS_HELPER=y`, `CONFIG_DRM_MSM_DSI_STAGING=y`, `CONFIG_QCOM_KGSL=y`
- `CONFIG_INPUT_EVDEV=y`, `CONFIG_TOUCHSCREEN_ST_FTS_V521=y`, `CONFIG_TOUCHSCREEN_XIAOMI_TOUCHFEATURE=y`
- `CONFIG_FW_LOADER=y`, `CONFIG_RD_GZIP=y` (the FIT ramdisk is gzip; `RD_LZMA`/`RD_ZSTD` are not set in this baseline)
- Security: `CONFIG_SECURITY_SELINUX=y`
- `CONFIG_PSTORE=y`, `CONFIG_PSTORE_CONSOLE=y`, `CONFIG_PSTORE_PMSG=y`, `CONFIG_PSTORE_RAM=y` (crash logs; already in the official Cepheus config `c872241570f6`)

Also absent from the baseline config, and listed in the fragment table below:
`SERIAL_MSM_GENI_CONSOLE`, `DRM_FBDEV_EMULATION`.

## Modules

The Cepheus `crux_defconfig` builds **0** `.ko` modules; `kernel.mk` installs
none into the vendor staging area. TWRP recovery does not depend on modules
(`TW_LOAD_VENDOR_MODULES` is not used). Use the prebuilt-kernel path above to
skip the kernel build during iteration.

## Updating the kernel

1. Choose the kernel branch and expected revision deliberately. Update
   `manifests/crux-twrp.xml`, `scripts/build-twrp.sh`'s expected SHA and the
   README table together; the manifest tracks a branch and the warning is not
   an enforcement check.
2. If the PE13 device tree also consumes the same kernel, keep both in sync
   (PE13 selects `kernel/xiaomi/crux-pe-cepheus`).
3. Re-run `scripts/setup-twrp.sh` (or `repo sync` in the tree) and rebuild from
   a clean kernel checkout; uncommitted defconfig or driver experiments change
   the kernel even when HEAD matches. Because the tree is not yet published to
   GitHub, fetch the branch locally from the migration bundle first (see
   `Source`).
