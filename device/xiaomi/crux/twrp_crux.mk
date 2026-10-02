#
# Copyright (C) 2026 The Crux TWRP port
#
# SPDX-License-Identifier: Apache-2.0
#
# Xiaomi Mi 9 Pro 5G (crux) - TWRP 3.7.1 (twrp-12.1 baseline, 3.7.1_12)
#

# Inherit the AOSP recovery product base and the TWRP common configuration.
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base.mk)
$(call inherit-product, vendor/twrp/config/common.mk)

# Inherit the crux device configuration.
$(call inherit-product, device/xiaomi/crux/device.mk)

# Device identifier (must come after all inclusions).
PRODUCT_DEVICE := crux
PRODUCT_NAME := twrp_crux
PRODUCT_BRAND := Xiaomi
PRODUCT_MODEL := Mi 9 Pro 5G
PRODUCT_MANUFACTURER := Xiaomi
