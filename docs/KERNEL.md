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

The manifest pins the kernel at the commit the PE13 source lock pins
(`coachpo/crux-pe13-distributed` `config/cloud-source-manifest.json`), so TWRP
and PE build the same kernel source. `scripts/kernel-pin.py` prints it, and
`scripts/build-twrp.sh` refuses another checkout or tracked changes:

```xml
<project name="coachpo/kernel_xiaomi_crux" path="kernel/xiaomi/crux"
         remote="crux-github"
         revision="2900b2cc1af5517a25c71cc8851c5f893754fea3" upstream="refs/heads/thirteen"
         groups="notdefault,crux-extra" />
```

Bump it together with the PE lock. `TWRP_USE_EXISTING_CHECKOUTS=1` leaves
an independent kernel checkout and a separate Prelude checkout untouched
and still checks their pins. Fetch the kernel with `--no-tags`: a reachable
tag can change the kernel version, and a linked worktree shares the main
checkout's tags. The retained Release's
TWRP Image was built at `e45a24f31ee0`
(`Linux version 4.14.305-Crux-PE-ge45a24f31ee0`).

It is the official PE Cepheus source
(`PixelExperience-Devices/kernel_xiaomi_cepheus` `f4048f154b51`, branch
`thirteen`, Linux 4.14.305) plus the Crux migration and early-boot memory-limit fixes. The USB1 extcon
board correction is now committed in the maintained kernel source. The
previously verified Image and DT-only repair are recorded in
[`BUILD-RESULTS-2026-10-04-DT.md`](BUILD-RESULTS-2026-10-04-DT.md). No offline bundle is kept;
the published `thirteen` branch is the source.

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
The board DT correction that disables the unused USB1 extcon (it conflicts
with SMB5) is committed in the kernel source; `scripts/build-twrp.sh` applies
no kernel patch.

TWRP's `kernel.mk` still passes `CROSS_COMPILE_ARM32` (AOSP arm binutils) and
hardcodes `HOSTCC`/`HOSTCXX` to the tree's clang 12 for host utilities; target
compilation and the LLVM binutils come from Prelude. `LD_COMPAT` is set
explicitly because the Cepheus `vdso32/Makefile` only falls back to `$(LD)`
when the make variable `LLVM` is set, and otherwise expects a host `ld` that
the build environment does not have.

The comparable local and CI builds both build the kernel from source. Use
the separate RAM UI recipe for kernel-only diagnostics.

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
has the committed board correction disabling the unused USB1 GPIO extcon; the Crux hung-task/softlockup diagnostics that used to
be uncommitted on the old tree are part of the migration commits here.

## Verified kernel capabilities for TWRP

From the built Cepheus-baseline kernel configuration (`crux_defconfig`):

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

Also absent from the baseline config, and listed in the fragment table above:
`SERIAL_MSM_GENI_CONSOLE`, `DRM_FBDEV_EMULATION`.

## Modules

The Cepheus `crux_defconfig` builds **0** `.ko` modules; `kernel.mk` installs
none into the vendor staging area. TWRP recovery does not depend on modules
(`TW_LOAD_VENDOR_MODULES` is not used).

## Updating the kernel

1. Choose the kernel commit deliberately and update the pin in
   `manifests/crux-twrp.xml` and the snippet above together;
   `scripts/build-twrp.sh` refuses any other commit or a kernel tree with
   tracked changes.
2. If the PE13 device tree also consumes the same kernel, keep both in sync
   (PE13 selects `kernel/xiaomi/crux-pe-cepheus`).
3. Re-run `scripts/setup-twrp.sh` and rebuild from
   a clean kernel checkout; uncommitted defconfig or driver experiments change
   the kernel even when HEAD matches.
