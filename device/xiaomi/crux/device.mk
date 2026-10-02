#
# Copyright (C) 2026 The Crux TWRP port
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/xiaomi/crux

# ---------------------------------------------------------------------------
# API level (device shipped Android 9; PE13 target is Android 13)
# ---------------------------------------------------------------------------
PRODUCT_TARGET_VNDK_VERSION := 30
PRODUCT_SHIPPING_API_LEVEL := 29

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------
TARGET_SYSTEM_PROP += $(LOCAL_PATH)/system.prop
TARGET_VENDOR_PROP += $(LOCAL_PATH)/vendor.prop

# ---------------------------------------------------------------------------
# Crypto / decryption
#
# The prebuilt qseecomd / keymaster@4.0 / gatekeeper@1.0 blobs live in
# recovery/root/system/bin and recovery/root/vendor/lib64 (stock crux MIUI,
# same set that allows TWRP recovery decryption on this device).
# device/qcom/twrp-common provides the decryption init scripts through the
# qcom_decrypt / qcom_decrypt_fbe packages.
# ---------------------------------------------------------------------------
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
BOARD_USES_QCOM_FBE_DECRYPTION := true
PRODUCT_PACKAGES += \
    qcom_decrypt \
    qcom_decrypt_fbe

# ---------------------------------------------------------------------------
# Recovery build inputs
# ---------------------------------------------------------------------------
TARGET_RECOVERY_DEVICE_MODULES += \
    libion \
    vendor.display.config@1.0 \
    vendor.display.config@2.0 \
    libdisplayconfig.qti

RECOVERY_LIBRARY_SOURCE_FILES += \
    $(TARGET_OUT_SHARED_LIBRARIES)/libion.so \
    $(TARGET_OUT_SYSTEM_EXT_SHARED_LIBRARIES)/vendor.display.config@1.0.so \
    $(TARGET_OUT_SYSTEM_EXT_SHARED_LIBRARIES)/vendor.display.config@2.0.so

# TWRP-specific mount/flash layout (merged with recovery.fstab by TWRP)
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/system/etc/twrp.flags:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/twrp.flags

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH) \
    vendor/qcom/opensource/commonsys-intf/display
