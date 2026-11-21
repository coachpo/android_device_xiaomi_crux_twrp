#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Build only the Crux RAM UI kernel in a fresh Linux OUT; do not use it for PE.
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 TWRP_TREE NEW_KERNEL_OUT" >&2
    exit 2
fi

here=$(cd "$(dirname "$0")" && pwd)
tree=$(realpath "$1")
out=$(realpath -m "$2")
src="$tree/kernel/xiaomi/crux"
baseline="$tree/out/target/product/crux/obj/KERNEL_OBJ/.config"
llvm="$tree/prebuilts/clang/host/linux-x86/clang-prelude/bin"
gcc="$tree/prebuilts/gcc/linux-x86"
cross64="$gcc/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-"
cross32="$gcc/arm/arm-linux-androideabi-4.9/bin/arm-linux-androideabi-"

test "$(git -C "$src" rev-parse HEAD)" = "$(python3 "$here/kernel-pin.py")"
test -z "$(git -C "$src" status --porcelain --untracked-files=no)"
test -f "$baseline"
test -x "$llvm/clang"
mkdir "$out"
cp "$baseline" "$out/.config"

# The UI needs the USB gadget, not a storage host or loadable storage drivers.
# UFS has no alternative block access path once its host stack is absent.
"$src/scripts/config" --file "$out/.config" \
    --disable SCSI_UFSHCD --disable MMC --disable USB_STORAGE --disable USB_UAS \
    --disable MODULES

export PATH="$llvm:${cross64%/*}:${cross32%/*}:$PATH"
export KBUILD_BUILD_USER=crux KBUILD_BUILD_HOST=build KBUILD_BUILD_VERSION=1
KBUILD_BUILD_TIMESTAMP=$(git -C "$src" show -s --format=%cD HEAD)
export KBUILD_BUILD_TIMESTAMP

args=(-C "$src" O="$out" ARCH=arm64 CC=clang LLVM=1 LLVM_IAS=1
    "CROSS_COMPILE=$cross64" "CROSS_COMPILE_ARM32=$cross32" CLANG_TRIPLE=aarch64-linux-gnu-
    "LD=$llvm/ld.lld" "LD_COMPAT=$llvm/ld.lld" "AR=$llvm/llvm-ar" "NM=$llvm/llvm-nm"
    "OBJCOPY=$llvm/llvm-objcopy" "OBJDUMP=$llvm/llvm-objdump" "STRIP=$llvm/llvm-strip"
    "KAFLAGS=-fmacro-prefix-map=$src/=")
make "${args[@]}" olddefconfig
for flag in SCSI_UFSHCD SCSI_UFSHCD_PLATFORM SCSI_UFS_QCOM MMC USB_STORAGE USB_UAS MODULES; do
    if grep -q "^CONFIG_$flag=" "$out/.config"; then
        echo "RAM UI kernel still enables CONFIG_$flag" >&2
        exit 1
    fi
done
for flag in BLK_DEV_INITRD RD_GZIP IKCONFIG USB_GADGET USB_CONFIGFS_F_FS INPUT_EVDEV; do
    grep -qx "CONFIG_$flag=y" "$out/.config"
done

make "${args[@]}" -j"$(nproc)" Image
"$src/scripts/extract-ikconfig" "$out/arch/arm64/boot/Image" | cmp - "$out/.config"
