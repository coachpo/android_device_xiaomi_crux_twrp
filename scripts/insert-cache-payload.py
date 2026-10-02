#!/usr/bin/env python3
"""Insert a TWRP FIT into the crux cache payload at the TWRP slot.

The crux U-Boot boot menu reads its payloads from the cache partition
(UFS LUN0, starting at LBA 0x30000, 4096-byte blocks):

    0x00000000  miui-menu.itb       MIUI
    0x04000000  twrp-menu.itb       TWRP          <-- this script writes here
    0x08000000  pe-recovery.itb     PE recovery
    0x0c000000  pe-rom.itb          PE system

This script never touches the device. It produces a new payload image that can
be flashed to the cache partition later, by the session that owns the boot
menu.

Usage:
    scripts/insert-cache-payload.py --fit out/fit-twrp/twrp-crux.itb \
        [--base cache-payload.img] [--out out/cache-payload-twrp.img] \
        [--offset 0x4000000]

Without --base an empty payload of --size bytes (default 0x8000000, i.e. up
to the next slot) is created.
"""

import argparse
import hashlib
import os
import sys

TWRP_SLOT = 0x04000000
NEXT_SLOT = 0x08000000


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--fit", required=True, help="TWRP FIT (twrp-crux.itb)")
    ap.add_argument("--base", help="existing cache payload image to start from")
    ap.add_argument("--out", help="output payload image")
    ap.add_argument("--offset", default=hex(TWRP_SLOT),
                    help="TWRP slot offset (default 0x4000000)")
    ap.add_argument("--size", default=hex(NEXT_SLOT),
                    help="payload size when --base is not given (default 0x8000000)")
    args = ap.parse_args()

    offset = int(args.offset, 0)
    size = int(args.size, 0)
    fit = open(args.fit, "rb").read()

    if args.base:
        if not os.path.exists(args.base):
            sys.exit(f"error: base payload not found: {args.base}")
        buf = bytearray(open(args.base, "rb").read())
    else:
        buf = bytearray()

    # The TWRP slot must not overlap the next slot.
    if offset + len(fit) > NEXT_SLOT and not args.base:
        sys.exit(f"error: FIT ({len(fit)} bytes) does not fit below 0x{NEXT_SLOT:x}")

    if offset < len(buf):
        # check the old TWRP slot content is not larger than the new slot
        pass
    if len(buf) < offset:
        buf.extend(b"\0" * (offset - len(buf)))
    buf[offset:offset + len(fit)] = fit
    if len(buf) < size:
        buf.extend(b"\0" * (size - len(buf)))

    out = args.out
    if not out:
        out = os.path.join(os.path.dirname(os.path.abspath(args.fit)),
                           "cache-payload-twrp.img")
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    open(out, "wb").write(buf)

    blocks = (len(buf) + 4095) // 4096
    print(f"fit:      {args.fit} ({len(fit)} bytes) -> {out}")
    print(f"offset:   0x{offset:x}")
    print(f"payload:  {len(buf)} bytes, blocks 0x{blocks:x}")
    print(f"sha256:   {hashlib.sha256(buf).hexdigest()}")
    print()
    print("Flash later (device writes are owned by the boot-menu session):")
    print(f"  fastboot flash cache {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
