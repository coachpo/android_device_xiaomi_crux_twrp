#
# Copyright (C) 2026 The Crux TWRP port
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),crux)
include $(call all-subdir-makefiles,$(LOCAL_PATH))
endif
