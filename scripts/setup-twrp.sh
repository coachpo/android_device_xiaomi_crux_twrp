#!/usr/bin/env bash
#
# Initialize and sync a TWRP 12.1 (3.7.1_12) build tree for crux.
#
# Copyright (C) 2026 The Crux TWRP port
# SPDX-License-Identifier: Apache-2.0
#
# Usage:
#   scripts/setup-twrp.sh [TREE_DIR]
#
# Environment:
#   TWRP_BRANCH    TWRP minimal-manifest branch       (default: twrp-12.1)
#   TWRP_JOBS      repo sync parallelism              (default: nproc)
#   LOCAL_DEVICE   Path to a local device tree checkout. When set, the device
#                  project is not fetched from GitHub; a symlink is created at
#                  device/xiaomi/crux instead (useful while developing this
#                  repository in place).
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TREE="${1:-$PWD/twrp-12.1}"
TWRP_BRANCH="${TWRP_BRANCH:-twrp-12.1}"
LOCAL_DEVICE="${LOCAL_DEVICE:-}"

if ! command -v repo >/dev/null 2>&1; then
    echo "error: 'repo' is not in PATH (install the Android repo launcher first)" >&2
    exit 1
fi
if ! command -v nproc >/dev/null 2>&1; then
    JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
else
    JOBS="$(nproc)"
fi
JOBS="${TWRP_JOBS:-$JOBS}"

mkdir -p "$TREE"
cd "$TREE"

echo "==> repo init ($TWRP_BRANCH)"
repo init --depth=1 \
    -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git \
    -b "$TWRP_BRANCH"

MANIFEST_DIR="$TREE/.repo/local_manifests"
mkdir -p "$MANIFEST_DIR"

if [ -n "$LOCAL_DEVICE" ]; then
    echo "==> using local device tree: $LOCAL_DEVICE"
    cat > "$MANIFEST_DIR/crux-twrp.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
    <project name="coachpo/kernel_xiaomi_crux"
             path="kernel/xiaomi/crux"
             remote="github"
             revision="b5ef11095c5389f937514d59da39c35cd244d971" />
</manifest>
EOF
else
    echo "==> using device tree from GitHub (coachpo/android_device_xiaomi_crux_twrp)"
    cp "$REPO_ROOT/manifests/crux-twrp.xml" "$MANIFEST_DIR/crux-twrp.xml"
fi

echo "==> repo sync (-j$JOBS, this downloads the TWRP 12.1 tree)"
repo sync -c --no-clone-bundle --no-tags -j"$JOBS"

if [ -n "$LOCAL_DEVICE" ]; then
    mkdir -p "$TREE/device/xiaomi"
    ln -sfn "$(cd "$LOCAL_DEVICE" && pwd)" "$TREE/device/xiaomi/crux"
    echo "==> linked $TREE/device/xiaomi/crux -> $LOCAL_DEVICE"
fi

echo
echo "Done. Next:"
echo "  cd $TREE"
echo "  scripts/build-twrp.sh ."
