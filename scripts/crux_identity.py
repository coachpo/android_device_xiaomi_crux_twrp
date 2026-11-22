#!/usr/bin/env python3
"""Device identity and build-host text that Crux TWRP artifacts must not carry.

The Recovery-container U-Boot (crux-uboot `cmd/crux_install.c`) removes these
bootargs keys from a booted FIT and appends the receiving phone's ABL values,
so the packaged DT carries none of them. Usage: crux_identity.py check DTB...
"""

import re
import subprocess
import sys

IDENTITY_KEYS = frozenset("""androidboot.serialno androidboot.cpuid androidboot.oled_wp
    androidboot.hwversion androidboot.hwlevel androidboot.hwc androidboot.ufsid androidboot.dp
    androidboot.baseband msm_drm.dsi_display0""".split())
HOST_TEXT = (b"/home/", b"/Users/", b"/mnt/mac/")
BUILD_USER, BUILD_HOST = "crux", "build"
IDENTITY_ASSIGNMENT = re.compile(
    rb"(?:" + b"|".join(re.escape(key.encode()) for key in sorted(IDENTITY_KEYS)) +
    rb")=[^\s\x00]")
LOCAL_EMAIL = re.compile(rb"[\w.+-]+@[\w.-]+\.local\b", re.IGNORECASE)


def verify_public_bytes(name, data):
    if any(prefix in data for prefix in (*HOST_TEXT, b"/__w/", b"/github/workspace")) or LOCAL_EMAIL.search(data):
        raise ValueError(f"Host path or local email in {name}")
    if IDENTITY_ASSIGNMENT.search(data):
        raise ValueError(f"ABL identity assignment in {name}")


def identity_keys(bootargs):
    return sorted({token.split("=", 1)[0] for token in bootargs.split()} & IDENTITY_KEYS)


def dt_bootargs(path):
    return subprocess.run(["fdtget", "-t", "s", str(path), "/chosen", "bootargs"],
                          check=True, capture_output=True, text=True).stdout.strip()


def main(argv):
    if len(argv) < 2 or argv[0] != "check":
        sys.exit(__doc__)
    found = {path: identity_keys(dt_bootargs(path)) for path in argv[1:]}
    for path, keys in found.items():
        if keys:
            print(f"error: {path} carries ABL identity bootargs: {' '.join(keys)}", file=sys.stderr)
    return 1 if any(found.values()) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
