#!/usr/bin/env bash
# Build the locked Crux TWRP recovery from source.
# Usage: scripts/build-twrp.sh [TREE_DIR]
set -eo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "${1:-/mnt/twrp}"
python3 "$ROOT/scripts/check-source-lock.py" .

export LC_ALL=C TZ=UTC
export SOURCE_DATE_EPOCH="$(git -C "$ROOT" log -1 --format=%ct)"
export BUILD_DATETIME="$SOURCE_DATE_EPOCH" BUILD_NUMBER="eng.crux.$SOURCE_DATE_EPOCH"
export BUILD_USERNAME=crux BUILD_HOSTNAME=build
export OUT_DIR=out USE_CCACHE=false CCACHE_DISABLE=1
export ALLOW_MISSING_DEPENDENCIES=true
unset TARGET_PREBUILT_KERNEL TARGET_FORCE_PREBUILT_KERNEL

stamp="$OUT_DIR/crux-build-number"
mkdir -p "$OUT_DIR"
if [[ ! -f $stamp || $(<"$stamp") != "$BUILD_NUMBER" ]]; then
    printf '%s\n' "$BUILD_NUMBER" > "$stamp"
fi

# shellcheck disable=SC1091
source build/envsetup.sh
set -e
lunch twrp_crux-eng
mka recoveryimage -j"${TWRP_BUILD_JOBS:-$(nproc)}"

ls -l out/target/product/crux/{recovery.img,ramdisk-recovery.img}
