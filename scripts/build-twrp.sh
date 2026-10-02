#!/usr/bin/env bash
#
# Build TWRP 3.7.1 (twrp-12.1 / 3.7.1_12) for crux.
#
# Copyright (C) 2026 The Crux TWRP port
# SPDX-License-Identifier: Apache-2.0
#
# Usage:
#   scripts/build-twrp.sh [TREE_DIR] [extra mka arguments...]
#
# Environment:
#   TARGET_PREBUILT_KERNEL   Use this kernel image instead of building
#                            kernel/xiaomi/crux from source (quick iteration).
#   TARGET_FORCE_PREBUILT_KERNEL=1   Required together with
#                            TARGET_PREBUILT_KERNEL when the kernel source is
#                            present (see vendor/twrp/build/tasks/kernel.mk).
#   ALLOW_KERNEL_REVISION_MISMATCH=1  Build even when kernel/xiaomi/crux is
#                            not at the pinned revision (unreproducible).
#
set -eo pipefail

TREE="${1:-$PWD/twrp-12.1}"
shift || true

if [ ! -d "$TREE" ]; then
    echo "error: build tree '$TREE' does not exist; run scripts/setup-twrp.sh first" >&2
    exit 1
fi

cd "$TREE"

if [ ! -f build/envsetup.sh ]; then
    echo "error: '$TREE' does not look like an Android build tree" >&2
    exit 1
fi

# Keep the device tree in sync when developing against a local checkout.
# A symlink is not enough: the AOSP product scan does not follow symlinked
# device directories.
if [ -n "${LOCAL_DEVICE:-}" ]; then
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "$LOCAL_DEVICE/" "$TREE/device/xiaomi/crux/"
    else
        rm -rf "$TREE/device/xiaomi/crux"
        cp -a "$LOCAL_DEVICE" "$TREE/device/xiaomi/crux"
    fi
fi

# Pinned PE13 kernel revision; keep in sync with manifests/crux-twrp.xml and
# scripts/setup-twrp.sh.
EXPECTED_KERNEL_SHA="b5ef11095c5389f937514d59da39c35cd244d971"
if [ -d kernel/xiaomi/crux/.git ]; then
    ACTUAL_KERNEL_SHA="$(git -C kernel/xiaomi/crux rev-parse HEAD 2>/dev/null || true)"
    if [ "$ACTUAL_KERNEL_SHA" != "$EXPECTED_KERNEL_SHA" ]; then
        echo "kernel/xiaomi/crux is at ${ACTUAL_KERNEL_SHA:-unknown}" >&2
        echo "expected $EXPECTED_KERNEL_SHA (Linux 4.14.357 PE13 kernel)" >&2
        if [ -n "${TARGET_PREBUILT_KERNEL:-}" ] && [ -n "${TARGET_FORCE_PREBUILT_KERNEL:-}" ]; then
            echo "warning: continuing because a prebuilt kernel was forced" >&2
        elif [ -n "${ALLOW_KERNEL_REVISION_MISMATCH:-}" ]; then
            echo "warning: ALLOW_KERNEL_REVISION_MISMATCH is set; continuing" >&2
        else
            echo "error: refusing to build with a mismatched kernel" >&2
            echo "       set ALLOW_KERNEL_REVISION_MISMATCH=1 to build with it anyway" >&2
            exit 1
        fi
    fi
fi

export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C
export TW_DEFAULT_LANGUAGE=zh_CN

# shellcheck disable=SC1091
set +u
source build/envsetup.sh
set -e

echo "==> lunch twrp_crux-eng"
lunch twrp_crux-eng

if [ -n "${TARGET_PREBUILT_KERNEL:-}" ]; then
    echo "==> using prebuilt kernel: $TARGET_PREBUILT_KERNEL"
    echo "    (set TARGET_FORCE_PREBUILT_KERNEL=1 to silence the build warning)"
fi

if command -v nproc >/dev/null 2>&1; then
    JOBS="$(nproc)"
else
    JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
fi

echo "==> mka recoveryimage -j$JOBS $*"
mka recoveryimage -j"$JOBS" "$@"

OUT="out/target/product/crux"
echo
echo "==> build outputs"
ls -l "$OUT/recovery.img" "$OUT/ramdisk-recovery.img" 2>/dev/null || true
ls -l "$OUT/kernel" 2>/dev/null || true
echo
echo "Next: scripts/make-fit.sh --out-dir $TREE/$OUT"
