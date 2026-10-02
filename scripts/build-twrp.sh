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
#
set -euo pipefail

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

export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C
export TW_DEFAULT_LANGUAGE=zh_CN

# shellcheck disable=SC1091
source build/envsetup.sh

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
