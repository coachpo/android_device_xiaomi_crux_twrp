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
workspace component record (Obsidian 《Crux 组件身份与保留件》)
and [`boot_twrp` source](../../crux-uboot/board/qualcomm/xiaomi-crux.env).
The [2026-10-04 DT result](BUILD-RESULTS-2026-10-04-DT.md) retains the first
startup evidence. Physical touch/haptics acceptance and untested functions
are distinguished in [STATUS.md](STATUS.md).
Current debug boots follow the watchdog recovery guide (Obsidian 《Crux 内核调试 watchdog 流程》).

Use a checked `run boot_go` handoff or explicitly arm and check the timer
immediately before a direct debug `bootm go`. Unattended diagnosis also needs
the two kernel parameters set before prep; a menu entry alone does not stop
Linux from taking over and feeding the watchdog. Generated FIT commands are
handoff material for the U-Boot integration owner, who applies that gate.

## Cache slot and menu entry

The cache partition is UFS LUN0 with 4096-byte blocks. The guarded menu reads
four FIT slots: MIUI `0x30000`, TWRP `0x34000`, PE Recovery `0x38000` and PE ROM
`0x3c000`; the read counts are capacities, not authorized write ranges (see the
workspace component record, Obsidian 《Crux 组件身份与保留件》).
The deployed `boot_twrp` reads the retained Release's `0x2924` blocks:

```text
boot_twrp=scsi dev 0; scsi read 0xC0000000 0x34000 0x2924; setenv fdt_high; setenv initrd_high; bootm start 0xC0000000; bootm loados; bootm ramdisk; bootm prep; run boot_go
```

The FIT loads the kernel at `0x80080000` (load and entry), the ramdisk at
`0x83000000` and the FDT at `0x84800000`. `fdt_high` and `initrd_high` stay
unset so U-Boot can relocate the Cepheus Image and the 24.5 MiB ramdisk.
Integration must verify that the menu's read count covers the deployed FIT and
preserve every MIUI, PE Recovery and PE ROM payload region during an authorized
update.

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
and the cache-payload layout has to be renegotiated. `make-fit.sh` packages the
raw `Image` with the separate live DT, while `BoardConfig.mk` still names
`Image-dtb` for the Android recovery image. Re-check the selected kernel
artifact after any build-config change.

## Ownership boundary

U-Boot source and cache-payload integration belong to the workspace `crux-uboot/` and its integration owner. This
repository produces a FIT and handoff material only; it must **not** edit:

- `crux-uboot/**` (including `board/qualcomm/xiaomi-crux.env`),
- any cache image or the device.

When the image is ready for hardware, hand over:

1. `out/fit-twrp/twrp-crux.itb` (with SHA-256 and block count),
2. the generated `boot_twrp=...` line (the block count changes).

The U-Boot integration work then updates the environment and, when explicitly
authorized, writes the cache slot.

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
