#!/usr/bin/env python3
"""Derive a storage-free Crux TWRP FIT for RAM-only UI/ADB tests."""

import argparse
import getpass
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import struct
import subprocess
import sys
import tempfile

from ram_ui_archive import (
    FLAGS, FSTAB, QCOM_RC, RAM_FLAGS, RAM_FSTAB, SINK, TWRP_FOLDER, TWRP_MARKER,
    ram_ui_entries, read_newc, require, write_newc,
)


IDENTITY_KEYS = frozenset("""androidboot.serialno androidboot.cpuid androidboot.oled_wp
    androidboot.hwversion androidboot.hwlevel androidboot.hwc androidboot.ufsid androidboot.dp
    androidboot.baseband msm_drm.dsi_display0""".split())
UNIQUE_KEYS = ("androidboot.serialno", "androidboot.cpuid", "androidboot.oled_wp", "androidboot.ufsid")
STORAGE_NODES = ("/soc/ufshc@1d84000", "/soc/sdhci@8804000")
USB_NODE = "/soc/ssusb@a600000/dwc3@a600000"
DT_FSTAB = "/firmware/android/fstab"
STALE_CHOSEN = ("kaslr-seed", "rng-seed", "linux,initrd-start", "linux,initrd-end")
KERNEL_OFF = """SCSI_UFSHCD SCSI_UFSHCD_PLATFORM SCSI_UFS_QCOM MMC USB_STORAGE USB_UAS
    MODULES DEVMEM MTD BLK_DEV_NVME ATA KEXEC OF_OVERLAY EFI""".split()
KERNEL_ON = """BLK_DEV_INITRD RD_GZIP IKCONFIG USB_GADGET USB_CONFIGFS_F_FS USB_DWC3_MSM
    INPUT_EVDEV TOUCHSCREEN_ST_FTS_V521 AW8697_XM_HAPTIC DRM_MSM""".split()
PRESERVED = """init system/bin/init system/bin/recovery twres/portrait.xml system/lib64/libminuitwrp.so
    system/bin/adbd system/etc/init/hw/init.rc init.recovery.usb.rc
    system/bin/vendor.qti.hardware.vibrator.service vendor/lib64/vendor.qti.hardware.vibrator.impl.so
    vendor/etc/vintf/manifest/vendor.qti.hardware.vibrator.service.xml
    vendor/firmware/aw8697_haptic.bin vendor/firmware/aw8697_rtp_1.bin""".split()


def sha(data):
    return hashlib.sha256(data).hexdigest()


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, capture_output=True, **kwargs).stdout.strip()


def fdt_properties(data):
    """Read DT nodes as paths and property bytes for an exact semantic diff."""
    magic, total, start, names_off, _, _, _, _, names_size, size = struct.unpack_from(">10I", data)
    require(magic == 0xD00DFEED and total == len(data), "Invalid inline DT")
    end = start + size
    names = data[names_off:names_off + names_size]
    nodes, stack = {}, []
    pos = start
    while pos < end:
        tag, = struct.unpack_from(">I", data, pos)
        pos += 4
        if tag == 1:
            stop = data.index(0, pos, end)
            stack.append(data[pos:stop].decode())
            path = "/".join(stack)
            require(path not in nodes, "Duplicate DT node")
            nodes[path] = {}
            pos = (stop + 4) & ~3
        elif tag == 2:
            stack.pop()
        elif tag == 3:
            length, name = struct.unpack_from(">II", data, pos)
            pos += 8
            prop = names[name:names.index(0, name)].decode()
            obj = nodes["/".join(stack)]
            require(pos + length <= end and prop not in obj, "Invalid or duplicate DT property")
            obj[prop] = data[pos:pos + length]
            pos = (pos + length + 3) & ~3
        elif tag == 4:
            continue
        elif tag == 9:
            require(not stack, "Unclosed DT nodes")
            return nodes
        else:
            raise ValueError("Invalid DT structure")
    raise ValueError("No DT end token")


def sanitize_bootargs(raw):
    tokens = raw.decode().rstrip("\0").split()
    fields = dict(t.split("=", 1) for t in tokens if "=" in t)
    secrets = {key: fields[key].encode() for key in UNIQUE_KEYS if fields.get(key)}
    strip = IDENTITY_KEYS | {"androidboot.bootdevice", "androidboot.boot_devices"}
    clean = " ".join(t for t in tokens if t.split("=", 1)[0] not in strip)
    require(all(fields.get(k) for k in ("androidboot.usbcontroller", "androidboot.usbconfigfs")),
            "Source DT lacks the recovery ADB gadget properties")
    return clean, secrets


def reserved_memory(data):
    pos, = struct.unpack_from(">I", data, 16)
    pairs = []
    while True:
        address, size = struct.unpack_from(">QQ", data, pos)
        if not (address or size):
            return tuple(pairs)
        pairs.append((address, size))
        pos += 16


def derive_dt(path):
    original = path.read_bytes()
    base = fdt_properties(original)
    expected = {name: props.copy() for name, props in base.items()}
    bootargs, private = sanitize_bootargs(base["/chosen"]["bootargs"])
    run("fdtput", "-t", "s", path, "/chosen", "bootargs", bootargs)
    expected["/chosen"]["bootargs"] = bootargs.encode() + b"\0"
    for prop in STALE_CHOSEN:
        if prop in expected["/chosen"]:
            run("fdtput", "-d", path, "/chosen", prop)
            del expected["/chosen"][prop]
    for node in STORAGE_NODES:
        require(node in expected, f"Missing Crux storage node: {node}")
        run("fdtput", "-t", "s", path, node, "status", "disabled")
        expected[node]["status"] = b"disabled\0"
    require(expected[USB_NODE].get("compatible") == b"snps,dwc3\0", "Unexpected Crux USB controller")
    # dwc3_gadget_vbus_session() refuses VBUS unless dr_mode is otg, which leaves ep0
    # disabled and the gadget never enumerates; keep the source DT's otg unchanged.
    require(expected[USB_NODE].get("dr_mode") == b"otg\0", "Crux USB controller must stay dr_mode=otg")
    run("fdtput", "-r", path, DT_FSTAB)
    expected = {p: props for p, props in expected.items() if p != DT_FSTAB and not p.startswith(DT_FSTAB + "/")}
    rebuilt = path.read_bytes()
    require(fdt_properties(rebuilt) == expected and reserved_memory(rebuilt) == reserved_memory(original),
            "DT changed outside the RAM UI allowlist")
    return private


def validate_kernel(kernel, kernel_pin):
    require(kernel[56:60] == b"ARMd", "Expected a raw arm64 Linux Image")
    start = kernel.index(b"IKCFG_ST") + 8
    end = kernel.index(b"IKCFG_ED", start)
    config = gzip.decompress(kernel[start:end])
    settings = dict(x.split("=", 1) for x in config.decode().splitlines() if x.startswith("CONFIG_"))
    for flag in KERNEL_OFF:
        require(settings.get("CONFIG_" + flag) not in {"m", "y"}, f"Unexpected CONFIG_{flag}")
    for flag in KERNEL_ON:
        require(settings.get("CONFIG_" + flag) == "y", f"Missing CONFIG_{flag}")
    banner = re.search(rb"Linux version (\S+) \(crux@build\)", kernel)
    require(banner and ("-g" + kernel_pin[:12]).encode() in banner[1],
            "Expected the pinned kernel and neutral build identity")
    return config, banner[1].decode()


def validate_ramdisk(entries, original):
    for name in PRESERVED:
        require(entries[name].data and entries[name] == original[name], f"Recovery component changed: {name}")
    require(entries[FSTAB].data == RAM_FSTAB and entries[FLAGS].data == RAM_FLAGS, "Unexpected storage routes")
    etc = entries["etc"]
    require(stat.S_ISLNK(etc.fields[1]) and etc.data == b"/system/etc", "Recovery fstab would not resolve through /etc")
    sink = entries[SINK]
    require(stat.S_ISREG(sink.fields[1]) and sink.fields[1] & 0o777 == 0o600
            and sink.data == bytes(16384), "BCB sink is not an empty, private RAM file")
    folder = entries.get(TWRP_FOLDER)
    marker = entries.get(TWRP_MARKER)
    require(folder and stat.S_ISDIR(folder.fields[1]) and marker and stat.S_ISREG(marker.fields[1]) and not marker.data,
            "Missing the real RAM /TWRP directory and .twrpcf marker required without a storage volume")
    for name, entry in entries.items():
        leaf = name.rsplit("/", 1)[-1]
        require(not stat.S_ISBLK(entry.fields[1]) and not name.endswith(".ko"), "Block node or module in ramdisk")
        require("fstab" not in leaf or name == FSTAB, f"Unexpected fstab: {name}")
        require(not name.startswith("crux/install-keys/"), "Install key in the RAM UI profile")
        if name.endswith(".rc"):
            forbidden = rb"(?m)^[ \t]*(?:mount_all[ \t]|swapon[ \t]|mount[ \t]+\S+[ \t]+/dev/block/|import[ \t]+\S*qcom_decrypt)"
            require(not re.search(forbidden, entry.data), f"Persistent storage init action: {name}")
    qcom = entries[QCOM_RC].data
    require(b"start qti.vibrator" in qcom and b"${ro.boot.usbcontroller}" in qcom
            and b"/dev/block" not in qcom, "Crux vibrator/USB init or storage isolation changed")


def privacy_check(payloads, private):
    forbidden = {**private, "Linux home": b"/home/", "macOS home": b"/Users/",
                 "Mac VM share": b"/mnt/mac/", "build user": (getpass.getuser() + "@").encode()}
    return {name: {key: data.count(needle) for key, needle in forbidden.items()}
            for name, data in payloads.items()}


def fit_parts(path, dumpimage, directory):
    require(run("fdtget", "-l", path, "/images").splitlines() == ["kernel", "fdt", "ramdisk"],
            "Unexpected FIT component order")
    require(run("fdtget", path, "/configurations", "default") == "conf", "Unexpected FIT configuration")
    result = {}
    for index, part in enumerate(("kernel", "fdt", "ramdisk")):
        require(run("fdtget", path, "/configurations/conf", part) == part, "Wrong default FIT selection")
        target = directory / part
        run(dumpimage, "-T", "flat_dt", "-p", str(index), "-o", target, path)
        data = target.read_bytes()
        node = "/images/" + part + "/hash-1"
        require(run("fdtget", path, node, "algo") == "sha256", "Unexpected FIT hash algorithm")
        digest = bytes(int(x, 16) for x in run("fdtget", "-t", "bx", path, node, "value").split()).hex()
        require(digest == sha(data), f"FIT {part} hash does not match the readback")
        result[part] = data
    return result


def package(args):
    require(not args.out.exists(), "Output must be a new directory")
    source_sha = sha(args.source_fit.read_bytes())
    require(source_sha == args.source_fit_sha256, "Source FIT SHA-256 mismatch")
    kernel = args.kernel.read_bytes()
    kernel_pin = run(sys.executable, Path(__file__).with_name("kernel-pin.py"))
    config, kernel_release = validate_kernel(kernel, kernel_pin)
    with tempfile.TemporaryDirectory(prefix="crux-ram-ui-") as directory:
        work = Path(directory)
        parts = fit_parts(args.source_fit.resolve(), args.dumpimage, work)
        base = read_newc(gzip.decompress(parts["ramdisk"]))
        entries = ram_ui_entries(base)
        validate_ramdisk(entries, base)
        cpio = write_newc(entries)
        private = derive_dt(work / "fdt")
        payload = {"kernel": gzip.compress(kernel, mtime=0), "fdt": (work / "fdt").read_bytes(),
                   "ramdisk": gzip.compress(cpio, mtime=0)}
        for part, data in payload.items():
            (work / part).write_bytes(data)
        (work / "ram-ui.its").write_text(ITS)
        image = work / "twrp-crux-ram-ui.itb"
        run(args.mkimage, "-f", "ram-ui.its", image.name, cwd=work,
            env={**os.environ, "SOURCE_DATE_EPOCH": "0"})
        readback = work / "readback"
        readback.mkdir()
        selected = fit_parts(image, args.dumpimage, readback)
        require(selected == payload, "Packaged FIT differs from its inputs")
        require(read_newc(gzip.decompress(selected["ramdisk"])) == entries, "Ramdisk content or mode mismatch")
        data = image.read_bytes()
        scan = privacy_check({"FIT": data, "DT": selected["fdt"], "expanded kernel": kernel,
                              "expanded ramdisk": cpio, "kernel config": config}, private)
        require(not any(n for row in scan.values() for n in row.values()), "Device identity or host path in output")

    meta = {"profile": "crux-twrp-ram-ui", "status": "host-verified-not-booted", "source_fit_sha256": source_sha,
            "fit_sha256": sha(data), "fit_bytes": len(data), "fit_blocks_4096": (len(data) + 4095) // 4096,
            "component_sha256": {k: sha(v) for k, v in selected.items()}, "raw_kernel_sha256": sha(kernel),
            "kernel_source_commit": kernel_pin, "kernel_release": kernel_release,
            "kernel_config_sha256": sha(config), "privacy_counts": scan,
            "storage": "physical host drivers absent; no device mounts; BCB sink in RAM"}
    args.out.mkdir()
    (args.out / image.name).write_bytes(data)
    (args.out / "KERNEL-CONFIG").write_bytes(config)
    (args.out / "BUILD-INFO.json").write_text(json.dumps(meta, indent=2) + "\n")
    assets = sorted(args.out.iterdir())
    (args.out / "SHA256SUMS").write_text("".join(f"{sha(p.read_bytes())}  {p.name}\n" for p in assets))
    print(f"{image.name}: {len(data)} bytes, SHA-256 {sha(data)}")


ITS = """/dts-v1/;
/ {
    description = "Crux TWRP RAM UI (no partition access; never flash)";
    #address-cells = <1>;
    images {
        kernel {
            description = "Crux RAM UI arm64 Image";
            data = /incbin/("kernel"); type = "kernel"; arch = "arm64"; os = "linux";
            compression = "gzip"; load = <0x80080000>; entry = <0x80080000>;
            hash-1 { algo = "sha256"; };
        };
        fdt {
            description = "Crux storage-free DT";
            data = /incbin/("fdt"); type = "flat_dt"; arch = "arm64";
            compression = "none"; load = <0x84800000>;
            hash-1 { algo = "sha256"; };
        };
        ramdisk {
            description = "TWRP RAM UI initramfs (gzip)";
            data = /incbin/("ramdisk"); type = "ramdisk"; arch = "arm64"; os = "linux";
            compression = "none"; load = <0x83000000>;
            hash-1 { algo = "sha256"; };
        };
    };
    configurations { default = "conf"; conf { kernel = "kernel"; fdt = "fdt"; ramdisk = "ramdisk"; }; };
};
"""


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-fit", type=Path, required=True)
    parser.add_argument("--source-fit-sha256", required=True)
    parser.add_argument("--kernel", type=Path, required=True, help="Raw Image from build-ram-ui-kernel.sh")
    parser.add_argument("--mkimage", type=lambda p: str(Path(p).resolve()), required=True)
    parser.add_argument("--dumpimage", type=lambda p: str(Path(p).resolve()), required=True)
    parser.add_argument("--out", type=Path, required=True)
    package(parser.parse_args())
