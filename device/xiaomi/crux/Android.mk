#
# Copyright (C) 2026 The Crux TWRP port
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),crux)
include $(call all-subdir-makefiles,$(LOCAL_PATH))

# Android 12.1 treats BUILD_NUMBER_FILE as order-only, so new build numbers
# do not invalidate all the properties that recovery collects across partitions.
crux_build_number_stamp := $(wildcard $(OUT_DIR)/crux-build-number)
ifneq ($(crux_build_number_stamp),)
$(call intermediates-dir-for,PACKAGING,system_build_prop)/buildinfo.prop \
$(TARGET_OUT)/build.prop \
$(TARGET_OUT_VENDOR)/build.prop \
$(TARGET_OUT_PRODUCT)/etc/build.prop \
$(TARGET_OUT_ODM)/etc/build.prop \
$(TARGET_OUT_SYSTEM_EXT)/etc/build.prop \
$(TARGET_RAMDISK_OUT)/system/etc/ramdisk/build.prop: $(crux_build_number_stamp)
endif
endif
