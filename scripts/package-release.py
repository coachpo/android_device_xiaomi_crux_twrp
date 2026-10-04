#!/usr/bin/env python3
"""Package and verify the Crux recovery build for GitHub Releases."""
import argparse
from datetime import datetime, timezone
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
VERSION = "3.7.1_12"


def run(args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True, **kwargs).stdout.strip()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def revision(path):
    return run(["git", "-c", f"safe.directory={path}", "-C", str(path), "rev-parse", "HEAD"])


def cpio_file(archive, wanted):
    cursor = 0
    while cursor + 110 <= len(archive):
        header = archive[cursor:cursor + 110]
        assert header[:6] == b"070701", "Expected a newc recovery archive"
        size = int(header[54:62], 16)
        name_size = int(header[94:102], 16)
        name = archive[cursor + 110:cursor + 110 + name_size].rstrip(b"\0")
        cursor = (cursor + 110 + name_size + 3) & ~3
        data = archive[cursor:cursor + size]
        cursor = (cursor + size + 3) & ~3
        if name == wanted:
            return data
        if name == b"TRAILER!!!":
            break
    raise ValueError(f"Missing embedded recovery file: {wanted!r}")


def package(args):
    tree = args.tree.resolve()
    product = tree / "out/target/product/crux"
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    image = product / "obj/KERNEL_OBJ/arch/arm64/boot/Image"
    config = product / "obj/KERNEL_OBJ/.config"
    ramdisk = product / "ramdisk-recovery.img"
    dt = ROOT / "device/xiaomi/crux/prebuilt/live-dt/twrp-live.dtb"
    version_header = (tree / "bootable/recovery/variables.h").read_text()
    assert re.search(r'#define\s+TW_MAIN_VERSION_STR\s+"' + re.escape(VERSION) + '"', version_header), "Release version differs from the TWRP source"
    assert image.read_bytes()[56:60] == b"ARMd", "Expected a raw arm64 Image"
    assert (product / "recovery.img").read_bytes()[:8] == b"ANDROID!", "Invalid recovery image"
    assert "CONFIG_RD_GZIP=y" in config.read_text()
    assert ramdisk.read_bytes()[:2] == b"\x1f\x8b", "Recovery initramfs must be gzip"
    credits = ROOT / "device/xiaomi/crux/recovery/root/system/etc/crux-release.txt"
    archive = gzip.decompress(ramdisk.read_bytes())
    assert cpio_file(archive, b"system/etc/crux-release.txt") == credits.read_bytes(), "Maintainer attribution missing from built recovery"
    assert b"3.7.1_12-crux-twrp-12.1-coachpo" in cpio_file(archive, b"system/bin/recovery"), "Maintainer version suffix missing from built recovery"
    bootargs = run(["fdtget", "-t", "s", str(dt), "/chosen", "bootargs"])
    assert not any(value in bootargs for value in ["maxcpus=", "initcall_blacklist=", "watchdog_v2.enable=0"]), "Diagnostic bootargs in release DT"
    assert run(["fdtget", "-t", "x", str(dt), "/soc/ufshc@1d84000", "reg"]) == "1d84000 2500 1d90000 8000"
    assert run(["fdtget", "-t", "s", str(dt), "/soc/ufshc@1d84000", "reg-names"]) == "ufs_mem ufs_ice"
    assert run(["fdtget", "-t", "s", str(dt), "/vendor/extcon_usb1", "status"]) == "disabled"

    fit_name = f"twrp-crux-{VERSION}.itb"
    with tempfile.TemporaryDirectory(prefix="crux-release-") as temporary:
        stage = Path(temporary)
        fit = stage / fit_name
        output = run([str(ROOT / "scripts/make-fit.sh"), "--out-dir", str(product),
                      "--kernel", str(image), "--dt", str(dt), "--out", str(fit)])
        print(output)
        assert fit.stat().st_size <= 64 * 1024 * 1024, "FIT exceeds the TWRP cache slot"
        for index, source, compressed in [(0, image, True), (1, dt, False), (2, ramdisk, False)]:
            extracted = stage / f"component-{index}"
            run(["dumpimage", "-T", "flat_dt", "-p", str(index), "-o", str(extracted), str(fit)])
            data = extracted.read_bytes()
            assert (gzip.decompress(data) if compressed else data) == source.read_bytes(), "FIT component differs from its build input"
        shutil.copy2(fit, out / fit_name)

    shutil.copy2(product / "recovery.img", out / f"twrp-crux-{VERSION}-recovery.img")
    shutil.copy2(ramdisk, out / "ramdisk-recovery.img")
    shutil.copy2(credits, out / "CREDITS.txt")
    manifest = run(["repo", "manifest", "-r"], cwd=tree)
    (out / "source-manifest.xml").write_text(manifest + "\n")
    clang = tree / "prebuilts/clang/host/linux-x86/clang-prelude"
    compiler = run([str(clang / "bin/clang"), "--version"])
    assert "16.0.2" in compiler, "Expected the verified Prelude Clang 16.0.2"
    patches = {p.name: sha(p) for p in sorted((ROOT / "patches/kernel").glob("*.patch"))}
    for patch in sorted((ROOT / "patches/kernel").glob("*.patch")):
        run(["git", "-C", str(tree / "kernel/xiaomi/crux"), "apply", "--reverse", "--check", str(patch)])
    soong = json.loads((tree / "out/soong/soong.variables").read_text())
    offsets = soong["VendorVars"]["twrpGlobalVars"]
    assert (offsets["tw_y_offset"], offsets["tw_h_offset"]) == ("80", "-80")
    blocks = ((out / fit_name).stat().st_size + 4095) // 4096
    boot_command = (f"boot_twrp=scsi dev 0; scsi read 0xC0000000 0x34000 0x{blocks:x}; "
                    "setenv fdt_high; setenv initrd_high; bootm start 0xC0000000; "
                    "bootm loados; bootm ramdisk; bootm prep; run boot_go")
    (out / "BOOT-TWRP.txt").write_text(boot_command + "\n")
    metadata = {
        "device": "crux", "twrp_version": VERSION, "release_tag": args.release_tag,
        "built_at_utc": datetime.now(timezone.utc).isoformat(),
        "device_source_commit": revision(ROOT),
        "kernel_source_commit": revision(tree / "kernel/xiaomi/crux"),
        "kernel_patches_sha256": patches,
        "kernel_config_sha256": sha(config), "raw_image_sha256": sha(image),
        "live_dtb_sha256": sha(dt), "toolchain_commit": revision(clang),
        "compiler": compiler, "top_inset_px": 80, "fit_blocks": f"0x{blocks:x}",
        "maintainer": "coachpo", "maintainer_github": "https://github.com/coachpo",
        "repository": "https://github.com/coachpo/android_device_xiaomi_crux_twrp",
        "embedded_credits_sha256": sha(credits),
        "workflow_run": os.environ.get("GITHUB_RUN_ID"),
        "workflow_commit": os.environ.get("GITHUB_SHA"),
        "fit_component_readbacks_verified": True,
    }
    (out / "BUILD-INFO.json").write_text(json.dumps(metadata, indent=2) + "\n")
    notes = f"""TWRP {VERSION} for Xiaomi Mi 9 Pro 5G (crux), built from source on the PE Cepheus 4.14.305 migration baseline.

Crux port maintained by [coachpo](https://github.com/coachpo). [Source repository](https://github.com/coachpo/android_device_xiaomi_crux_twrp).
The recovery version suffix includes `coachpo`; full credits and source URLs are embedded at `/system/etc/crux-release.txt` and attached as `CREDITS.txt`. TWRP upstream credit remains with TeamWin.

- `twrp-crux-{VERSION}.itb`: U-Boot FIT for the TWRP slot, with the UFS ICE/USB1 DT compatibility corrections and 80px top display inset.
- `twrp-crux-{VERSION}-recovery.img`: Android recovery-image build output. This project's verified boot route uses the FIT through U-Boot.
- `ramdisk-recovery.img`: gzip recovery initramfs.
- `BOOT-TWRP.txt`: exact menu command and read length ({blocks:#x} 4096-byte blocks), requiring the watchdog-protected `boot_go` wrapper.
- `source-manifest.xml`, `BUILD-INFO.json`, `SHA256SUMS`: resolved source revisions, applied board patch, compiler and artifact checksums.
- `CREDITS.txt`: maintainer GitHub, source repository and upstream credits.

Device source: `{metadata['device_source_commit']}`. Kernel: `{metadata['kernel_source_commit']}`. Prelude: `{metadata['toolchain_commit']}`.

The FIT contents and slot size are verified by the workflow. The source baseline has passed device startup with eight CPUs, ADB and TWRP UI; this newly built release has not itself been flashed or function-tested. Touch/MTP/decryption coverage is recorded in the repository's device-test documentation. This release is a TWRP build, not a full multi-entry cache payload.

For workflow-produced releases, verify GitHub's signed build provenance with `gh attestation verify twrp-crux-{VERSION}.itb --repo coachpo/android_device_xiaomi_crux_twrp`. This self-maintained release does not carry TeamWin's official OpenPGP signature.
"""
    (out / "RELEASE-NOTES.md").write_text(notes)
    files = sorted(p for p in out.iterdir() if p.is_file() and p.name != "SHA256SUMS")
    (out / "SHA256SUMS").write_text("".join(f"{sha(p)}  {p.name}\n" for p in files))
    print(f"Verified {len(files)} release assets in {out}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tree", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--release-tag", required=True)
    package(parser.parse_args())
