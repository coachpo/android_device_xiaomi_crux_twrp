import gzip
import importlib.util
from pathlib import Path
import stat
import unittest

from ram_ui_archive import DROP_CRYPTO, DROP_RC, FLAGS, FSTAB, QCOM_RC, SINK, TWRP_FOLDER, TWRP_MARKER, new_entry


spec = importlib.util.spec_from_file_location("ram_ui_packer", Path(__file__).with_name("package-ram-ui.py"))
packer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packer)
PIN = "0123456789ab" + "0" * 28


def kernel_with(extra=b""):
    mandatory = b"".join(f"CONFIG_{flag}=y\n".encode() for flag in packer.KERNEL_ON)
    banner = b"Linux version 4.14.305-Crux-PE-g0123456789ab (crux@build)"
    return bytes(56) + b"ARMd" + banner + b"IKCFG_ST" + gzip.compress(mandatory + extra) + b"IKCFG_ED"


def recovery_archive(extra=None):
    contents = {p: b"component" for p in packer.PRESERVED}
    contents.update({FSTAB: b"/dev/block/physical /misc emmc defaults defaults\n", FLAGS: b"/data ext4 old-flags\n",
                     "etc": b"/system/etc", QCOM_RC: DROP_RC + DROP_CRYPTO +
                     b"on boot\n    start qti.vibrator\n    setprop sys.usb.controller ${ro.boot.usbcontroller}\n",
                     "init.recovery.qcom_decrypt.rc": b"on fs\n    mount_all /fstab.physical\n"})
    contents.update(extra or {})
    contents["TRAILER!!!"] = b""
    return {p: new_entry(p, i, (stat.S_IFLNK | 0o777) if p == "etc" else (stat.S_IFREG | 0o644), data)
            for i, (p, data) in enumerate(contents.items(), 1)}


class RamUiContract(unittest.TestCase):
    def test_kernel_must_not_provide_physical_storage_or_modules(self):
        self.assertIn(b"CONFIG_INPUT_EVDEV=y", packer.validate_kernel(kernel_with(), PIN)[0])
        for setting in (b"CONFIG_SCSI_UFSHCD=y", b"CONFIG_USB_STORAGE=m", b"CONFIG_MODULES=y"):
            with self.subTest(setting=setting), self.assertRaisesRegex(ValueError, "Unexpected CONFIG_"):
                packer.validate_kernel(kernel_with(setting + b"\n"), PIN)

    def test_bcb_is_ram_file_and_optional_decryption_is_not_imported(self):
        source = recovery_archive()
        result = packer.read_newc(packer.write_newc(packer.ram_ui_entries(source)))
        packer.validate_ramdisk(result, source)
        self.assertNotIn(b"/dev/block/", result[FSTAB].data)
        self.assertTrue(stat.S_ISREG(result[SINK].fields[1]))
        self.assertEqual(bytes(16384), result[SINK].data)

    def test_unexpected_storage_mount_fails_profile_validation(self):
        source = recovery_archive({"unexpected.rc": b"on fs\n    mount ext4 /dev/block/custom /data\n"})
        with self.assertRaisesRegex(ValueError, "Persistent storage init action"):
            packer.validate_ramdisk(packer.ram_ui_entries(source), source)

    def test_no_storage_profile_requires_ram_folder_marker(self):
        source = recovery_archive()
        entries = packer.read_newc(packer.write_newc(packer.ram_ui_entries(source)))
        self.assertTrue(stat.S_ISDIR(entries[TWRP_FOLDER].fields[1]))
        self.assertTrue(stat.S_ISREG(entries[TWRP_MARKER].fields[1]))
        self.assertEqual(b"", entries[TWRP_MARKER].data)
        del entries[TWRP_MARKER]
        with self.assertRaisesRegex(ValueError, r"\.twrpcf marker required"):
            packer.validate_ramdisk(entries, source)

    def test_only_hardware_identity_and_storage_bootargs_are_removed(self):
        args = (b"androidboot.serialno=test-device androidboot.ufsid=test-storage-id androidboot.hwc=region "
                b"androidboot.bootdevice=ufs androidboot.usbcontroller=a600000.dwc3 androidboot.usbconfigfs=true\0")
        clean, private = packer.sanitize_bootargs(args)
        self.assertEqual("androidboot.usbcontroller=a600000.dwc3 androidboot.usbconfigfs=true", clean)
        counts = packer.privacy_check({"initramfs": b"log test-storage-id /Users/example/source"}, private)
        self.assertEqual(1, counts["initramfs"]["androidboot.ufsid"])
        self.assertEqual(1, counts["initramfs"]["macOS home"])


if __name__ == "__main__":
    unittest.main()
