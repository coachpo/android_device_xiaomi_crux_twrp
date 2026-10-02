# Kernel integration

## Source

The kernel is **not** stored in this repository. TWRP's inline kernel build
(`vendor/twrp/build/tasks/kernel.mk`) builds it from:

| Variable | Value |
|---|---|
| `TARGET_KERNEL_SOURCE` | `kernel/xiaomi/crux` |
| `TARGET_KERNEL_CONFIG` | `crux_defconfig` |
| `TARGET_KERNEL_CLANG_COMPILE` | `true` |
| `BOARD_KERNEL_IMAGE_NAME` | `Image-dtb` |
| `BOARD_KERNEL_SEPARATED_DTBO` | `true` |

The source is provided by `manifests/crux-twrp.xml`:

```xml
<project name="coachpo/kernel_xiaomi_crux" path="kernel/xiaomi/crux"
         remote="github"
         revision="b5ef11095c5389f937514d59da39c35cd244d971" />
```

That commit is the PE13 kernel used by the current workspace:

```text
Linux version 4.14.357-openela-Marisa-20260104-ksunext
```

It chains CAF `msm-4.14` `LA.UM.9.1.r1-16400` + Android 4.14-stable
(4.14.336) + OpenELA `v4.14.357` + crux DTS/touch/FOD/haptics adaptation
(`crux: align boot, touch and FOD interfaces with Android 13`, etc.). The
matching PE13 artifacts are archived at `out/crux-kernel-2026-10-01/`.

## Toolchain

TWRP 12.1's kernel build defaults to the tree's clang prebuilt (AOSP
`clang-r416183b1` through `LLVM_PREBUILTS_VERSION`). The PE13 build used the
"Prelude" clang 16 from the PE13 tree
(`prebuilts/clang/host/linux-x86/clang-prelude`). If the default clang cannot
build the kernel, point TWRP at a prelude copy that exists inside the TWRP
tree:

```make
# BoardConfig.mk or an env override
TARGET_KERNEL_CLANG_PATH := $(shell pwd)/prebuilts/clang/host/linux-x86/clang-prelude
```

or fall back to a kernel built in the PE13 tree:

```sh
TARGET_PREBUILT_KERNEL=/path/to/out/crux-kernel-2026-10-01/Image \
TARGET_FORCE_PREBUILT_KERNEL=1 scripts/build-twrp.sh "$HOME/twrp-12.1"
```

## Optional TWRP kernel fragment

The PE13 `crux_defconfig` already contains everything recovery needs. Three
options are absent and are **optional** for the first bring-up:

| Option | Effect | Why it may be wanted |
|---|---|---|
| `CONFIG_SERIAL_MSM_GENI_CONSOLE=y` | kernel console on `ttyMSM0` | kernel logs over the U-Boot CDC-ACM console |
| `CONFIG_DRM_FBDEV_EMULATION=y` | `/dev/fb0` | fallback if the TWRP DRM path misbehaves |
| `CONFIG_PSTORE=y` + `CONFIG_PSTORE_RAM=y` | pstore/ramoops | crash logs survive reboot |

To add them, place a fragment in the kernel repository at
`arch/arm64/configs/crux_twrp_defconfig` and set
`TARGET_KERNEL_ADDITIONAL_CONFIG := crux_twrp_defconfig`. This is deliberately
not enabled yet: it modifies the shared PE13 kernel repository and the missing
options do not block recovery.

## Verified kernel capabilities for TWRP

From the built PE13 `kernel.config`:

- `CONFIG_ANDROID_BINDERFS=y`, `CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"`
- `CONFIG_DM_DEFAULT_KEY=y` (metadata encryption), `CONFIG_DM_CRYPT=y`, `CONFIG_DM_VERITY=y`, `CONFIG_DM_SNAPSHOT=y`
- `CONFIG_FS_ENCRYPTION=y`, `CONFIG_FS_ENCRYPTION_INLINE_CRYPT=y`, `CONFIG_BLK_INLINE_ENCRYPTION=y` (FBE v2 / ICE)
- `CONFIG_EROFS_FS=y`, `CONFIG_EXT4_FS=y`
- `CONFIG_SCSI_UFS_QCOM=y`, `CONFIG_PHY_QCOM_UFS=y`
- `CONFIG_USB_DWC3=y`, `CONFIG_USB_CONFIGFS_F_FS=y`, `CONFIG_USB_CONFIGFS_F_MTP=y`, `CONFIG_USB_STORAGE=y`
- `CONFIG_DRM_MSM=y`, `CONFIG_DRM_KMS_HELPER=y`, `CONFIG_DRM_MSM_DSI_STAGING=y`, `CONFIG_QCOM_KGSL=y`
- `CONFIG_INPUT_EVDEV=y`, `CONFIG_TOUCHSCREEN_ST_FTS_V521=y`, `CONFIG_TOUCHSCREEN_XIAOMI_TOUCHFEATURE=y`
- `CONFIG_FW_LOADER=y`, `CONFIG_RD_GZIP=y`, `CONFIG_RD_LZMA=y`, `CONFIG_RD_ZSTD=y`
- Security: `CONFIG_SECURITY_SELINUX=y`

Absent (see fragment table): `SERIAL_MSM_GENI_CONSOLE`, `DRM_FBDEV_EMULATION`,
`PSTORE`, `PSTORE_RAM`.

## Modules

The kernel may build `=m` modules; `kernel.mk` installs them into the vendor
image staging area. TWRP recovery does not depend on them (`TW_LOAD_VENDOR_MODULES`
is not used). If the module build slows iteration, use the prebuilt-kernel path
above.

## Updating the kernel

1. Update the pinned revision in `manifests/crux-twrp.xml` (and the README
   table) to the new `coachpo/kernel_xiaomi_crux` commit or branch.
2. If the PE13 device tree also consumes the same kernel commit, keep both in
   sync (the PE13 manifest pins `b5ef1109` as well).
3. Re-run `scripts/setup-twrp.sh` (or `repo sync` in the tree) and rebuild.
