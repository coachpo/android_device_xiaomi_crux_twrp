#
# Copyright (C) 2026 The Crux TWRP port
#
# SPDX-License-Identifier: Apache-2.0
#
# Xiaomi Mi 9 Pro 5G (crux) - TWRP 3.7.1 / twrp-12.1 device configuration.
#
# Hardware/software baseline:
#   - SM8150 (msmnile), UFS 1d84000.ufshc, USB dwc3 a600000.dwc3
#   - non-A/B, static system/vendor partitions, separate recovery partition
#   - boot header v1, 4096-byte pages, separate DTBO partition
#   - kernel built from source: kernel/xiaomi/crux (coachpo/kernel_xiaomi_crux
#     crux-pe13-cepheus, Linux 4.14.305 on the PE official Cepheus baseline)
#   - all boot entries go through U-Boot; the TWRP FIT is loaded from the cache
#     partition by the U-Boot boot menu (see docs/UBOOT.md)
#

DEVICE_PATH := device/xiaomi/crux

# ---------------------------------------------------------------------------
# Minimal manifest build allowances
# ---------------------------------------------------------------------------
ALLOW_MISSING_DEPENDENCIES := true
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_MISSING_REQUIRED_MODULES := true
BUILD_BROKEN_PREBUILT_ELF_FILES := true

# ---------------------------------------------------------------------------
# Architecture
# ---------------------------------------------------------------------------
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := kryo

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a73

TARGET_SUPPORTS_64_BIT_APPS := true
TARGET_USES_64_BIT_BINDER := true

# ---------------------------------------------------------------------------
# Bootloader / platform
# ---------------------------------------------------------------------------
TARGET_OTA_ASSERT_DEVICE := crux
TARGET_BOOTLOADER_BOARD_NAME := msmnile
TARGET_NO_BOOTLOADER := true
TARGET_USES_UEFI := true
TARGET_BOARD_PLATFORM := msmnile
TARGET_BOARD_PLATFORM_GPU := qcom-adreno640
QCOM_BOARD_PLATFORMS += msmnile

# ---------------------------------------------------------------------------
# Kernel - built from source through vendor/twrp/build/tasks/kernel.mk
# ---------------------------------------------------------------------------
# The kernel source is provided by the local manifest
# (manifests/crux-twrp.xml -> coachpo/kernel_xiaomi_crux @ crux-pe13-cepheus).
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_SOURCE := kernel/xiaomi/crux
TARGET_KERNEL_CONFIG := crux_defconfig
TARGET_KERNEL_CLANG_COMPILE := true
# The Cepheus 4.14.305 baseline is built with the PE13 "Prelude" clang 16.0.2
# in LLVM mode (LLVM=1 + LLVM_IAS=1), matching the PE13 build. The twrp-12.1
# default clang-r416183b1 (12.0.7) predates the baseline, so point the kernel
# build at a Prelude copy inside the tree
# (prebuilts/clang/host/linux-x86/clang-prelude, symlinked to the PE13 tree).
TARGET_KERNEL_CLANG_VERSION := prelude
TARGET_KERNEL_CLANG_PATH := $(shell pwd)/prebuilts/clang/host/linux-x86/clang-prelude
TARGET_KERNEL_CLANG_BIN := $(TARGET_KERNEL_CLANG_PATH)/bin
# With LLVM=1 the vdso32 Makefile uses $(LD) as LD_COMPAT; pass both anyway so
# the 32-bit ARM vDSO link never depends on a host `ld` that does not exist.
TARGET_KERNEL_ADDITIONAL_FLAGS += \
    LLVM=1 LLVM_IAS=1 \
    LD=$(TARGET_KERNEL_CLANG_BIN)/ld.lld \
    LD_COMPAT=$(TARGET_KERNEL_CLANG_BIN)/ld.lld \
    AR=$(TARGET_KERNEL_CLANG_BIN)/llvm-ar \
    NM=$(TARGET_KERNEL_CLANG_BIN)/llvm-nm \
    OBJCOPY=$(TARGET_KERNEL_CLANG_BIN)/llvm-objcopy \
    OBJDUMP=$(TARGET_KERNEL_CLANG_BIN)/llvm-objdump \
    STRIP=$(TARGET_KERNEL_CLANG_BIN)/llvm-strip
# TWRP-specific kernel options (console/pstore/...) can be added with a fragment
# placed in kernel/xiaomi/crux/arch/arm64/configs/ and selected here:
# TARGET_KERNEL_ADDITIONAL_CONFIG := crux_twrp_defconfig

BOARD_KERNEL_IMAGE_NAME := Image-dtb
BOARD_KERNEL_SEPARATED_DTBO := true
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_BASE := 0x00000000
BOARD_RAMDISK_OFFSET := 0x01000000
BOARD_KERNEL_TAGS_OFFSET := 0x00000100
BOARD_BOOT_HEADER_VERSION := 1
BOARD_MKBOOTIMG_ARGS := \
    --header_version $(BOARD_BOOT_HEADER_VERSION) \
    --ramdisk_offset $(BOARD_RAMDISK_OFFSET) \
    --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)

BOARD_KERNEL_CMDLINE := console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0xa90000
BOARD_KERNEL_CMDLINE += androidboot.hardware=qcom androidboot.console=ttyMSM0
BOARD_KERNEL_CMDLINE += androidboot.memcg=1 lpm_levels.sleep_disabled=1
BOARD_KERNEL_CMDLINE += video=vfb:640x400,bpp:32,memsize=3072000 msm_rtb.filter=0x237
BOARD_KERNEL_CMDLINE += androidboot.usbcontroller=a600000.dwc3 androidboot.usbconfigfs=true
BOARD_KERNEL_CMDLINE += service_locator.enable=1 swiotlb=2048 loop.max_part=7
BOARD_KERNEL_CMDLINE += firmware_class.path=/vendor/firmware_mnt/image
BOARD_KERNEL_CMDLINE += androidboot.boot_devices=soc/1d84000.ufshc
BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive buildvariant=eng

# ---------------------------------------------------------------------------
# Partitions (static, non-A/B; sizes are image build limits, not GPT facts)
# ---------------------------------------------------------------------------
BOARD_FLASH_BLOCK_SIZE := 262144
BOARD_BOOTIMAGE_PARTITION_SIZE := 134217728
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 134217728
BOARD_DTBOIMG_PARTITION_SIZE := 33554432
BOARD_VBMETAIMAGE_PARTITION_SIZE := 131072
BOARD_CACHEIMAGE_PARTITION_SIZE := 268435456
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 3758096384
BOARD_VENDORIMAGE_PARTITION_SIZE := 1610612736
BOARD_SYSTEMIMAGE_PARTITION_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USES_METADATA_PARTITION := true
TARGET_COPY_OUT_VENDOR := vendor
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_BUILD_SYSTEM_ROOT_IMAGE := true
BOARD_ROOT_EXTRA_FOLDERS := bluetooth dsp firmware persist
BOARD_SUPPRESS_SECURE_ERASE := true

# ---------------------------------------------------------------------------
# Recovery
# ---------------------------------------------------------------------------
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab
TARGET_RECOVERY_PIXEL_FORMAT := "RGBX_8888"
TARGET_RECOVERY_QCOM_RTC_FIX := true
TARGET_USES_MKE2FS := true
TW_QCOM_ATS_OFFSET := 1617714502203

# ---------------------------------------------------------------------------
# Spoofed platform properties used by TWRP and the AVB rollback index
# ---------------------------------------------------------------------------
PLATFORM_VERSION := 99.87.36
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)

# ---------------------------------------------------------------------------
# AVB (build-time only: the device is unlocked and boots through U-Boot)
# ---------------------------------------------------------------------------
BOARD_AVB_ENABLE := true
BOARD_AVB_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA2048
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3

# ---------------------------------------------------------------------------
# Crypto / decryption
# ---------------------------------------------------------------------------
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
BOARD_USES_QCOM_FBE_DECRYPTION := true
TW_USE_FSCRYPT_POLICY := 2

# ---------------------------------------------------------------------------
# TWRP configuration
# ---------------------------------------------------------------------------
TW_THEME := portrait_hdpi
# Crux cutout bounds reach 77px; keep the status bar below that top strip.
TW_Y_OFFSET := 80
TW_H_OFFSET := -80
TW_EXTRA_LANGUAGES := true
TW_DEFAULT_LANGUAGE := zh_CN
TW_USE_TOOLBOX := true
TW_INCLUDE_NTFS_3G := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true
TW_EXCLUDE_APEX := true
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_INPUT_BLACKLIST := "hbtp_vm"
TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
TW_MAX_BRIGHTNESS := 4095
TW_DEFAULT_BRIGHTNESS := 1640
TW_CUSTOM_CPU_TEMP_PATH := "/sys/class/thermal/thermal_zone1/temp"
TW_BATTERY_SYSFS_WAIT_SECONDS := 5
TW_FRAMERATE := 60
# The bundled QTI vibrator service implements AIDL. Enabling HIDL as well
# makes minuitwrp select its HIDL branch and skip the available AIDL service.
TW_SUPPORT_INPUT_AIDL_HAPTICS := true
TW_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true
TW_HAS_EDL_MODE := true
TW_IGNORE_MISC_WIPE_DATA := true
RECOVERY_SDCARD_ON_DATA := true
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true
TW_DEVICE_VERSION := crux-twrp-12.1-coachpo

