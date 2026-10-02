#!/usr/bin/env bash
#
# Package a TWRP recovery build into a U-Boot FIT for the crux boot menu.
#
# Copyright (C) 2026 The Crux TWRP port
# SPDX-License-Identifier: Apache-2.0
#
# The FIT layout matches the currently-working U-Boot boot_twrp command:
#   kernel  load/entry 0x80080000
#   ramdisk load        0x83000000
#   fdt     load        0x84800000
#   fdt_high 0x84900000, initrd_high 0x84200000
#
# The TWRP ramdisk is passed with compression="none": the kernel unpacks the
# gzip/lzma initramfs itself (CONFIG_RD_GZIP / CONFIG_RD_LZMA are enabled in
# the crux kernel). The kernel Image is optionally gzip-compressed and
# declared as such, so U-Boot decompresses it (CONFIG_GZIP=y in the crux
# U-Boot). That keeps the FIT inside the 64 MiB TWRP cache slot.
#
# Usage:
#   scripts/make-fit.sh [--out-dir DIR] [--kernel FILE] [--ramdisk FILE]
#                       [--dt FILE] [--kernel-comp gzip|none] [--out FILE]
#                       [--mkimage FILE] [--no-verify]
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR=""
KERNEL=""
RAMDISK=""
DT=""
KERNEL_COMP="gzip"
OUT=""
MKIMAGE=""

usage() {
    cat <<'EOF'
Usage: scripts/make-fit.sh [--out-dir DIR] [--kernel FILE] [--ramdisk FILE]
                           [--dt FILE] [--kernel-comp gzip|none] [--out FILE]
                           [--mkimage FILE]
EOF
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --out-dir)   OUT_DIR="$2"; shift 2 ;;
        --kernel)    KERNEL="$2"; shift 2 ;;
        --ramdisk)   RAMDISK="$2"; shift 2 ;;
        --dt)        DT="$2"; shift 2 ;;
        --kernel-comp) KERNEL_COMP="$2"; shift 2 ;;
        --out)       OUT="$2"; shift 2 ;;
        --mkimage)   MKIMAGE="$2"; shift 2 ;;
        -h|--help)   usage 0 ;;
        *) echo "unknown option: $1" >&2; usage 1 ;;
    esac
done

if [ -z "$OUT_DIR" ]; then
    for cand in "$PWD/out/target/product/crux" "$REPO_ROOT/twrp-12.1/out/target/product/crux"; do
        if [ -f "$cand/ramdisk-recovery.img" ]; then OUT_DIR="$cand"; break; fi
    done
fi
if [ -z "$OUT_DIR" ] || [ ! -f "$OUT_DIR/ramdisk-recovery.img" ]; then
    echo "error: cannot find ramdisk-recovery.img; pass --out-dir" >&2
    exit 1
fi

if [ -z "$KERNEL" ]; then
    if [ -f "$OUT_DIR/obj/KERNEL_OBJ/arch/arm64/boot/Image" ]; then
        KERNEL="$OUT_DIR/obj/KERNEL_OBJ/arch/arm64/boot/Image"
    else
        KERNEL="$OUT_DIR/kernel"
    fi
fi
[ -f "$KERNEL" ] || { echo "error: kernel image not found: $KERNEL" >&2; exit 1; }

if [ -z "$RAMDISK" ]; then RAMDISK="$OUT_DIR/ramdisk-recovery.img"; fi
[ -f "$RAMDISK" ] || { echo "error: ramdisk not found: $RAMDISK" >&2; exit 1; }

if [ -z "$DT" ]; then
    DT="$REPO_ROOT/device/xiaomi/crux/prebuilt/live-dt/twrp-live.dtb"
fi
[ -f "$DT" ] || { echo "error: device tree not found: $DT" >&2; exit 1; }

if [ -z "$OUT" ]; then OUT="$REPO_ROOT/out/fit-twrp/twrp-crux.itb"; fi
mkdir -p "$(dirname "$OUT")"

BUILD_DIR="$(dirname "$OUT")"
ITS="$BUILD_DIR/twrp-crux.its"

echo "==> staging FIT inputs in $BUILD_DIR"
cp "$DT" "$BUILD_DIR/fdt.dtb"
cp "$RAMDISK" "$BUILD_DIR/ramdisk.gz"
if ! head -c2 "$RAMDISK" | od -An -tx1 | grep -q '1f 8b'; then
    echo "warning: $RAMDISK does not look like gzip; the FIT declares it as an" >&2
    echo "         unmodified initramfs (compression=none). Check the kernel's" >&2
    echo "         CONFIG_RD_* support and adjust make-fit.sh if needed." >&2
fi

case "$KERNEL_COMP" in
    gzip)
        gzip -9 -c "$KERNEL" > "$BUILD_DIR/kernel.bin"
        ITS_COMP="gzip"
        ;;
    none)
        cp "$KERNEL" "$BUILD_DIR/kernel.bin"
        ITS_COMP="none"
        ;;
    *)
        echo "error: --kernel-comp must be gzip or none" >&2
        exit 1
        ;;
esac

cat > "$ITS" <<EOF
/dts-v1/;

/ {
	description = "Crux boot menu: TWRP 3.7.1 (twrp-12.1) recovery";
	#address-cells = <1>;
	#size-cells = <1>;
	images {
		kernel {
			description = "Crux Marisa 4.14 Image (TWRP build)";
			data = /incbin/("kernel.bin");
			type = "kernel";
			arch = "arm64";
			os = "linux";
			compression = "$ITS_COMP";
			load = <0x80080000>;
			entry = <0x80080000>;
			hash-1 { algo = "sha256"; };
		};
		fdt {
			description = "ABL live recovery DTB";
			data = /incbin/("fdt.dtb");
			type = "flat_dt";
			arch = "arm64";
			compression = "none";
			load = <0x84800000>;
			hash-1 { algo = "sha256"; };
		};
		ramdisk {
			description = "TWRP recovery ramdisk (gzip)";
			data = /incbin/("ramdisk.gz");
			type = "ramdisk";
			arch = "arm64";
			os = "linux";
			compression = "none";
			load = <0x83000000>;
			hash-1 { algo = "sha256"; };
		};
	};
	configurations {
		default = "conf";
		conf { kernel = "kernel"; fdt = "fdt"; ramdisk = "ramdisk"; };
	};
};
EOF

if [ -z "$MKIMAGE" ]; then
    for cand in "$REPO_ROOT/../u-boot-port/src/u-boot-next/tools/mkimage" "$PWD/tools/mkimage"; do
        if [ -x "$cand" ]; then MKIMAGE="$cand"; break; fi
    done
fi
if [ -z "$MKIMAGE" ]; then
    if command -v mkimage >/dev/null 2>&1; then
        MKIMAGE="$(command -v mkimage)"
    else
        echo "error: mkimage not found; pass --mkimage or build the crux U-Boot tools" >&2
        exit 1
    fi
fi

echo "==> mkimage ($MKIMAGE)"
"$MKIMAGE" -f "$ITS" "$OUT"

SIZE=$(wc -c < "$OUT" | tr -d ' ')
BLOCKS=$(( (SIZE + 4095) / 4096 ))
if command -v sha256sum >/dev/null 2>&1; then
    SHA=$(sha256sum "$OUT" | awk '{print $1}')
else
    SHA=$(shasum -a 256 "$OUT" | awk '{print $1}')
fi
SLOT=$(( 64 * 1024 * 1024 ))

echo
echo "FIT:      $OUT"
echo "size:     $SIZE bytes ($(printf '0x%x' "$SIZE"))"
echo "blocks:   $(printf '0x%x' "$BLOCKS") (4096-byte UFS blocks)"
echo "sha256:   $SHA"
if [ "$SIZE" -gt "$SLOT" ]; then
    echo "WARNING:  FIT is larger than the current 64 MiB TWRP cache slot!" >&2
    echo "          coordinate a cache-payload layout change with the U-Boot menu session" >&2
else
    LEFT=$(( (SLOT - SIZE) / 1024 ))
    echo "slot fit: OK ($LEFT KiB left in the 64 MiB slot)"
fi

echo
echo "Updated U-Boot command (board/qualcomm/xiaomi-crux.env):"
echo "boot_twrp=scsi dev 0; scsi read 0xC0000000 0x34000 $(printf '0x%x' "$BLOCKS"); setenv fdt_high 0x84900000; setenv initrd_high 0x84200000; bootm start 0xC0000000; bootm loados; bootm ramdisk; bootm prep; bootm go"
