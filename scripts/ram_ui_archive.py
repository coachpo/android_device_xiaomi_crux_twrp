"""In-memory newc edits for the Crux RAM UI; never extract host device nodes."""

from dataclasses import dataclass
import stat


def require(condition, message):
    if not condition:
        raise ValueError(message)


def align4(n):
    return (n + 3) & ~3


@dataclass(frozen=True)
class Entry:
    name: str
    fields: tuple
    data: bytes

    def replace_data(self, data):
        return Entry(self.name, self.fields[:6] + (len(data),) + self.fields[7:], data)

    def encode(self):
        path = self.name.encode() + b"\0"
        record = b"070701" + b"".join(f"{x:08x}".encode() for x in self.fields) + path
        return record.ljust(align4(len(record)), b"\0") + self.data.ljust(align4(len(self.data)), b"\0")


def new_entry(name, inode, mode, data=b""):
    return Entry(name, (inode, mode, 0, 0, 1, 0, len(data), 0, 0, 0, 0, len(name.encode()) + 1, 0), data)


def read_newc(raw):
    entries = {}
    pos = 0
    while pos + 110 <= len(raw):
        require(raw[pos:pos + 6] == b"070701", "Expected newc recovery ramdisk")
        fields = tuple(int(raw[i:i + 8], 16) for i in range(pos + 6, pos + 110, 8))
        n = pos + 110
        path = raw[n:n + fields[11]]
        require(path.endswith(b"\0") and path.count(b"\0") == 1, "Invalid newc path")
        name = path[:-1].decode()
        start = align4(n + len(path))
        end = start + fields[6]
        pos = align4(end)
        require(pos <= len(raw) and name not in entries, "Truncated or duplicate newc entry")
        entries[name] = Entry(name, fields, raw[start:end])
        if name == "TRAILER!!!":
            require(not any(raw[pos:]), "Unexpected second ramdisk archive or trailing data")
            return entries
    raise ValueError("Missing newc trailer")


def write_newc(entries):
    raw = b"".join(entry.encode() for entry in entries.values())
    return raw.ljust((len(raw) + 511) & ~511, b"\0")


FSTAB = "system/etc/recovery.fstab"
FLAGS = "system/etc/twrp.flags"
QCOM_RC = "init.recovery.qcom.rc"
SINK = "crux/bcb-sink.img"
TWRP_FOLDER = "TWRP"
TWRP_MARKER = TWRP_FOLDER + "/.twrpcf"
RAM_FSTAB = b"# Recovery BCB emulation in the initramfs; no persistent mount routes.\n/crux/bcb-sink.img /misc emmc defaults defaults\n"
RAM_FLAGS = b"# RAM UI profile: no physical storage volumes.\n"
DROP_RC = b"""    wait /dev/block/platform/soc/${ro.boot.bootdevice}
    symlink /dev/block/platform/soc/${ro.boot.bootdevice} /dev/block/bootdevice
    chmod 0660 /dev/qseecom
    chown system drmrpc /dev/qseecom
"""
DROP_CRYPTO = b"import /init.recovery.qcom_decrypt.rc\n"


def ram_ui_entries(original):
    entries = original.copy()
    require(not {"crux", SINK, TWRP_FOLDER, TWRP_MARKER} & entries.keys(), "Already a derived ramdisk")
    trailer = entries.pop("TRAILER!!!")
    rc = entries[QCOM_RC].data
    require(rc.count(DROP_RC) == 1 and rc.count(DROP_CRYPTO) == 1, "Unexpected Crux init storage paths")
    entries[QCOM_RC] = entries[QCOM_RC].replace_data(rc.replace(DROP_RC, b"").replace(DROP_CRYPTO, b""))
    entries[FSTAB] = entries[FSTAB].replace_data(RAM_FSTAB)
    entries[FLAGS] = entries[FLAGS].replace_data(RAM_FLAGS)
    for name in tuple(entries):
        if name.startswith(("init.recovery.qcom_decrypt", "init.recovery.services.qcom_decrypt")) and name.endswith(".rc"):
            del entries[name]
    inode = max(e.fields[0] for e in original.values()) + 1
    entries["crux"] = new_entry("crux", inode, stat.S_IFDIR | 0o755)
    entries[SINK] = new_entry(SINK, inode + 1, stat.S_IFREG | 0o600, bytes(16384))
    # Without a storage volume, Check_For_TwrpFolder starts at / and must find
    # the marker before it attempts to mount the nonexistent default volume.
    entries[TWRP_FOLDER] = new_entry(TWRP_FOLDER, inode + 2, stat.S_IFDIR | 0o755)
    entries[TWRP_MARKER] = new_entry(TWRP_MARKER, inode + 3, stat.S_IFREG | 0o644)
    entries[trailer.name] = trailer
    return entries
