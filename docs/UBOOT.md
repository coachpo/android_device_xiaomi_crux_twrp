# U-Boot integration for the crux TWRP build

The Xiaomi Mi 9 Pro 5G is chain-loaded:

```text
PBL -> XBL -> ABL -> U-Boot (crux port) -> boot menu -> FIT (cache partition)
```

Every Android/recovery entry is started by the U-Boot boot menu. There is no
direct ABL -> recovery path in use, and the `recovery` partition is not the
normal boot source for TWRP on this setup.

The current artifact is the [2026-10-05 GitHub Release](RELEASE-DEPLOYMENT-2026-10-05.md),
with PE Cepheus 4.14.305, TWRP 3.7.1, corrected live DT, top inset and haptics.
The new workspace U-Boot menu reads its exact `0x2924` blocks; the ordinary
menu item 3 recheck reached ADB in 9.69 seconds with eight CPUs. See the
[current workspace baseline](../../docs/pe13-development-baseline-2026-10-05.md)
and [`boot_twrp` source](../../u-boot-port/src/u-boot-next/board/qualcomm/xiaomi-crux.env).
The [2026-10-04 DT result](BUILD-RESULTS-2026-10-04-DT.md) retains the first
startup evidence. Physical touch/haptics acceptance and untested functions
are distinguished in [STATUS.md](STATUS.md).
Current debug boots follow the [watchdog recovery guide](../../u-boot-port/notes/KERNEL-DEBUG-WATCHDOG.md).

Use a checked `run boot_go` handoff or explicitly arm and check the timer
immediately before a direct debug `bootm go`. Unattended diagnosis also needs
the two kernel parameters set before prep; a menu entry alone does not stop
Linux from taking over and feeding the watchdog. Generated FIT commands are
handoff material for the U-Boot integration owner, who applies that gate.

## Historical menu and layout evidence

Source: `u-boot-port/src/u-boot-next/board/qualcomm/xiaomi-crux.env`.

The legacy commands and source-state descriptions below preserve the earlier
integration evidence. They are not current watchdog-protected debug recipes;
use the guide above and the block count of the FIT actually deployed.

The earlier MIUI/TWRP-only checkpoint used the hardware-verified
`ub-crux-bootmenu.img` and cache payload below. Its historical source-state
description also recorded uncommitted PE
menu entries and an uncommitted `boot/bootm.c` change to reserve the arm64
kernel's full BSS footprint. Those changes and their candidate image had
not yet been rebuilt together, flashed or device-verified in that earlier record.

```text
cache partition: UFS LUN0, 4096-byte blocks, starts at LBA 0x30000
  0x00000000  miui-menu.itb      MIUI            (stock kernel + official DT)
  0x04000000  twrp-menu.itb      TWRP            (proven TWRP 3.3.1 + live DT)

# Legacy, hardware-tested 3.3.1 entry; a newly built FIT needs a new block count:
boot_twrp=scsi dev 0; scsi read 0xC0000000 0x34000 0x3486; setenv fdt_high 0x84900000; setenv initrd_high 0x84200000; bootm start 0xC0000000; bootm loados; bootm ramdisk; bootm prep; bootm go
```

Address contract used by the FIT:

| Component | Load / entry |
|---|---|
| kernel | `0x80080000` (load and entry) |
| ramdisk | `0x83000000` |
| fdt | `0x84800000` |
| `fdt_high` | `0x84900000` |
| `initrd_high` | `0x84200000` |

`scsi read 0xC0000000 0x34000 <blocks>` reads a TWRP FIT from cache LBA
`0x34000` (64 MiB into the payload); `<blocks>` is the FIT size in 4096-byte
blocks. The proven 3.3.1 FIT was `0x3486` blocks (55,074,356 bytes). The
first TWRP 3.7.1 build (2026-10-02) was `0x2a58` blocks (44,398,928 bytes,
see `BUILD-RESULTS-2026-10-02.md`); the 2026-10-03 pstore rebuild was
`0x2a5c` blocks (44,413,240 bytes, see `BUILD-RESULTS-2026-10-03.md`), the
final 2026-10-03 rebuild with the PE13 kernel fixes is `0x2a68` blocks
(44,462,716 bytes, see `BUILD-RESULTS-2026-10-03B.md`), and the 2026-10-04
Cepheus-baseline build is `0x2935` blocks (43,204,672 bytes, see
`BUILD-RESULTS-2026-10-04.md`). Integration must verify that the menu's read
count covers the deployed FIT.
Those descriptions refer to dated payloads and are superseded by the current
four-slot cache layout. The 2026-10-04 fixed2 FIT used `0x293c` blocks, and its
corrected DT replacement kept that count. The 2026-10-05 Release uses `0x2924`;
the then-existing `0x293c` menu read was sufficient, so that deployment needed
no environment change. The current workspace menu now reads `0x2924`.
Use the current baseline above for the menu and cache layout; preserve each
MIUI, TWRP, PE Recovery and PE ROM payload region during an authorized update.

## What this repository produces

`scripts/make-fit.sh` packages the TWRP build into `out/fit-twrp/twrp-crux.itb`:

- kernel: the raw `Image` built from `kernel/xiaomi/crux` (no appended DTBs),
  **gzip-compressed in the FIT** and decompressed by U-Boot (`CONFIG_GZIP=y`)
  so the image stays inside the 64 MiB TWRP cache slot;
- ramdisk: `ramdisk-recovery.img` (gzip) with `compression = "none"` — the
  kernel unpacks the initramfs itself (`CONFIG_RD_GZIP=y`);
- fdt: `device/xiaomi/crux/prebuilt/live-dt/twrp-live.dtb`, the captured ABL live DT with the
  UFS ICE resource and unused USB1 extcon compatibility corrections.

The script prints the exact replacement for `boot_twrp`, recomputed for the
new FIT size, plus SHA-256 and block count. Since 2026-10-04 the replacement
command must leave `fdt_high`/`initrd_high` unset (`setenv fdt_high; setenv
initrd_high;`): the Cepheus kernel reserves its full `image_size` and the
24.5 MiB ramdisk does not fit below the old low `initrd_high=0x84200000`. If
the FIT exceeds 64 MiB it warns
and the cache-payload layout has to be renegotiated. The 2026-10-02 build
packaged the raw `Image` (48,443,408 B, `af1063fa…`) with the separate live DT;
`BoardConfig.mk` still names `Image-dtb` for the recovery image. Re-check the
selected kernel artifact after any build-config change.

## Ownership boundary

U-Boot source and cache-payload integration belong to `u-boot-port/`. This
repository produces a FIT and handoff material only; it must **not** edit:

- `u-boot-port/src/u-boot-next/**` (including `board/qualcomm/xiaomi-crux.env`),
- `out/crux-bootmenu-2026-10-02/cache-payload.img` or the device.

When the image is ready for hardware, hand over:

1. `out/fit-twrp/twrp-crux.itb` (with SHA-256),
2. the generated `boot_twrp=...` line (the block count changes),
3. optionally a payload copy produced by `scripts/insert-cache-payload.py`.

The U-Boot integration work then updates the environment and, when explicitly
authorized, writes the payload.

## Live device tree

`prebuilt/live-dt/twrp-live.dtb` was captured from the ABL/U-Boot live DT used
by the proven TWRP 3.3.1 boot (original SHA-256
`9744b16db18c12e8b084c5a30c3c70e94263c7ddbd20613736b9a299c442f03d`).
The corrected prebuilt is `1442852931cbf49829ffcbe8f1b51661ebbf9321828bf0d58b6abd66fc2b6633`;
see [prebuilt provenance](../device/xiaomi/crux/prebuilt/README.md). It
contains the stock `/chosen/bootargs` (including
`androidboot.selinux=permissive`, `buildvariant=eng`,
`androidboot.boot_devices=soc/1d84000.ufshc`, the panel command
`msm_drm.dsi_display0=dsi_samsung_fhd_ea8076_f1s_cmd_display:` and the
`ramoops_memreserve` reservation).

It preserves the panel/touch/keymaster hardware descriptions from ABL's overlay.
Node presence does not establish complete touch or decryption support; use
[STATUS.md](STATUS.md) for the observed validation scope. If it must be regenerated, boot a
working recovery and read `/sys/firmware/fdt`, or build a DT from the kernel
sources (`sm8150-v2.dtb` + `crux-sm8150-overlay.dtbo`) and patch
`/chosen/bootargs` before packaging.

## Ramoops note (historical)

The old U-Boot injected a duplicate `ramoops@b0000000` node, which crashed the
TWRP 3.3.1 kernel. The fixed U-Boot no longer does this; the TWRP FIT no longer
needs the `fdt rm /reserved-memory/ramoops@b0000000` workaround. If an older
U-Boot is used, that removal must happen after `bootm prep`.
