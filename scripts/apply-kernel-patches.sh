#!/usr/bin/env bash
# Apply the board DT correction used by the verified PE Crux recovery.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL="${1:?usage: apply-kernel-patches.sh KERNEL_SOURCE}"
if [ ! -d "$KERNEL" ]; then
    if [ "${TARGET_FORCE_PREBUILT_KERNEL:-}" = 1 ] && [ -f "${TARGET_PREBUILT_KERNEL:-}" ]; then
        exit 0
    fi
    echo "error: kernel source not found: $KERNEL" >&2
    exit 1
fi
for patch in "$REPO_ROOT"/patches/kernel/*.patch; do
    if git -C "$KERNEL" apply --reverse --check "$patch" 2>/dev/null; then
        echo "==> already applied: $(basename "$patch")"
    else
        git -C "$KERNEL" apply --whitespace=error --check "$patch"
        git -C "$KERNEL" apply --whitespace=error "$patch"
        echo "==> applied: $(basename "$patch")"
    fi
done
