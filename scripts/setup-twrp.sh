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
#   LOCAL_DEVICE   Absolute path to the device/xiaomi/crux leaf directory.
#                  When set, the device
#                  project is not fetched from GitHub; files are copied to
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
TREE="$PWD"

echo "==> repo init ($TWRP_BRANCH)"
repo init --depth=1 \
    -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git \
    -b "$TWRP_BRANCH"

MANIFEST_DIR="$TREE/.repo/local_manifests"
mkdir -p "$MANIFEST_DIR"

cp "$REPO_ROOT/manifests/crux-twrp.xml" "$MANIFEST_DIR/crux-twrp.xml"
if [ -n "$LOCAL_DEVICE" ]; then
    echo "==> using local device tree: $LOCAL_DEVICE"
    python3 - "$MANIFEST_DIR/crux-twrp.xml" <<'PY_MANIFEST'
import sys
import xml.etree.ElementTree as ET
path = sys.argv[1]
tree = ET.parse(path)
for project in list(tree.getroot().findall("project")):
    if project.get("name") == "coachpo/android_device_xiaomi_crux_twrp":
        tree.getroot().remove(project)
tree.write(path, encoding="utf-8", xml_declaration=True)
PY_MANIFEST
else
    echo "==> using device tree from GitHub (coachpo/android_device_xiaomi_crux_twrp)"
fi

echo "==> repo sync (-j$JOBS, this downloads the TWRP 12.1 tree)"
repo sync -c --no-clone-bundle --no-tags -j"$JOBS"

# The repository includes scripts/docs above device/xiaomi/crux. AOSP needs
# the leaf device directory, not the repository root or a symlink to it.
DEVICE_SOURCE="${LOCAL_DEVICE:-$TREE/crux-device-source/device/xiaomi/crux}"
[ -f "$DEVICE_SOURCE/BoardConfig.mk" ] || {
    echo "error: device source has no BoardConfig.mk: $DEVICE_SOURCE" >&2
    exit 1
}
mkdir -p "$TREE/device/xiaomi/crux"
rsync -a --delete "$DEVICE_SOURCE/" "$TREE/device/xiaomi/crux/"
echo "==> copied $DEVICE_SOURCE -> $TREE/device/xiaomi/crux"

echo
echo "Done. Next:"
echo "  \"$REPO_ROOT/scripts/build-twrp.sh\" \"$TREE\""
