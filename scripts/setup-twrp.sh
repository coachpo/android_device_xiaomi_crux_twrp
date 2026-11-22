#!/usr/bin/env bash
# Sync the committed TWRP lock and the device leaf from the same commit.
# Usage: scripts/setup-twrp.sh [TREE_DIR]
# TWRP_JOBS controls sync parallelism. TWRP_USE_EXISTING_CHECKOUTS=1 leaves
# the separately managed kernel and Prelude checkouts untouched.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TREE="${1:-/mnt/twrp}"
COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
git -C "$ROOT" diff --quiet HEAD -- manifests/crux-twrp.xml device/xiaomi/crux

mkdir -p "$TREE"
cd "$TREE"
if compgen -G '.repo/local_manifests/*.xml' >/dev/null; then
    echo "Remove local manifest overrides from the sync tree before using the lock." >&2
    exit 1
fi
groups="default,crux-extra"
if [[ ${TWRP_USE_EXISTING_CHECKOUTS:-0} == 1 ]]; then
    for path in kernel/xiaomi/crux prebuilts/clang/host/linux-x86/clang-prelude; do
        if [[ ! -e $path/.git || -e .repo/projects/$path.git ]]; then
            echo "Expected a separately managed checkout at $path." >&2
            exit 1
        fi
    done
    groups=default
fi

# Git repo reads the lock from the exact local/CI source commit, not an
# upstream manifest branch. Shallow fetches request the pinned SHA itself.
repo init -u "file://$ROOT" -b "$COMMIT" -m manifests/crux-twrp.xml \
    --groups="$groups" --depth=1 --no-use-superproject --no-clone-bundle

# Older trees may still list a project that was replaced by a separate
# checkout. Remove the stale record so repo does not prune that checkout.
if [[ $groups == default && -f .repo/project.list ]]; then
    python3 - <<'PY'
from pathlib import Path

projects = Path(".repo/project.list")
old = projects.read_text()
external = {"kernel/xiaomi/crux", "prebuilts/clang/host/linux-x86/clang-prelude"}
new = "".join(line for line in old.splitlines(keepends=True) if line.strip() not in external)
if new != old:
    projects.write_text(new)
PY
fi
repo sync -c --detach --no-manifest-update --no-clone-bundle --no-tags -j"${TWRP_JOBS:-$(nproc)}"

# AOSP does not follow a symlinked product tree. Export only tracked files.
git -C "$ROOT" archive "$COMMIT" device/xiaomi/crux | tar -xf -
python3 "$ROOT/scripts/check-source-lock.py" .
