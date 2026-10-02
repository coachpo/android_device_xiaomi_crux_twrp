# U-Boot integration for the crux TWRP build

The Xiaomi Mi 9 Pro 5G is chain-loaded:

```text
PBL -> XBL -> ABL -> U-Boot (crux port) -> boot menu -> FIT (cache partition)
```

Every Android/recovery entry is started by the U-Boot boot menu. There is no
direct ABL -> recovery path in use, and the `recovery` partition is not the
normal boot source for TWRP on this setup.

## Current boot menu contract

Source: `u-boot-port/src/u-boot-next/board/qualcomm/xiaomi-crux.env`.

```text
cache partition: UFS LUN0, 4096-byte blocks, starts at LBA 0x30000
  0x00000000  miui-menu.itb      MIUI            (stock kernel + official DT)
  0x04000000  twrp-menu.itb      TWRP            (proven TWRP 3.3.1 + live DT)
  0x08000000  pe-recovery.itb    PE recovery
  0x0c000000  pe-rom.itb         PE system

boot_twrp=scsi dev 0; scsi read 0xC0000000 0x34000 0x3486; \
          setenv fdt_high 0x84900000; setenv initrd_high 0x84200000; \
          bootm start 0xC0000000; bootm loados; bootm ramdisk; bootm prep; bootm go
```

Address contract used by the FIT:

| Component | Load / entry |
|---|---|
| kernel | `0x80080000` (load and entry) |
| ramdisk | `0x83000000` |
| fdt | `0x84800000` |
| `fdt_high` | `0x84900000` |
| `initrd_high` | `0x84200000` |

`scsi read 0xC0000000 0x34000 <blocks>` reads the TWRP FIT from cache
LBA `0x34000` (64 MiB into the cache payload); `<blocks>` is the FIT size in
4096-byte blocks. The proven 3.3.1 FIT was `0x3486` blocks (55,074,356 bytes).

## What this repository produces

`scripts/make-fit.sh` packages the TWRP build into `out/fit-twrp/twrp-crux.itb`:

- kernel: the raw `Image` built from `kernel/xiaomi/crux` (no appended DTBs),
  **gzip-compressed in the FIT** and decompressed by U-Boot (`CONFIG_GZIP=y`)
  so the image stays inside the 64 MiB TWRP cache slot;
- ramdisk: `ramdisk-recovery.img` (gzip) with `compression = "none"` — the
  kernel unpacks the initramfs itself (`CONFIG_RD_GZIP=y`);
- fdt: `device/xiaomi/crux/prebuilt/live-dt/twrp-live.dtb`, the ABL live DT that
  the currently-working TWRP FIT uses.

The script prints the exact replacement for `boot_twrp`, recomputed for the
new FIT size, plus SHA-256 and block count. If the FIT exceeds 64 MiB it warns
and the cache-payload layout has to be renegotiated.

## Ownership boundary

The U-Boot boot menu and the cache payload image are maintained by another
session. This repository must **not** edit:

- `u-boot-port/src/u-boot-next/**` (including `board/qualcomm/xiaomi-crux.env`),
- `out/crux-bootmenu-2026-10-02/cache-payload.img` or the device.

When the image is ready for hardware, hand over:

1. `out/fit-twrp/twrp-crux.itb` (with SHA-256),
2. the generated `boot_twrp=...` line (the block count changes),
3. optionally a payload copy produced by `scripts/insert-cache-payload.py`.

The boot-menu session then updates the environment and writes the payload.

## Live device tree

`prebuilt/live-dt/twrp-live.dtb` was captured from the ABL/U-Boot live DT used
by the proven TWRP 3.3.1 boot (SHA-256
`9744b16db18c12e8b084c5a30c3c70e94263c7ddbd20613736b9a299c442f03d`). It
contains the stock `/chosen/bootargs` (including
`androidboot.selinux=permissive`, `buildvariant=eng`,
`androidboot.boot_devices=soc/1d84000.ufshc`, the panel command
`msm_drm.dsi_display0=dsi_samsung_fhd_ea8076_f1s_cmd_display:` and the
`ramoops_memreserve` reservation).

It is kept because the panel/touch/keymaster nodes come from ABL's overlay and
are known to drive the hardware in recovery. If it must be regenerated, boot a
working recovery and read `/sys/firmware/fdt`, or build a DT from the kernel
sources (`sm8150-v2.dtb` + `crux-sm8150-overlay.dtbo`) and patch
`/chosen/bootargs` before packaging.

## Ramoops note (historical)

The old U-Boot injected a duplicate `ramoops@b0000000` node, which crashed the
TWRP 3.3.1 kernel. The fixed U-Boot no longer does this; the TWRP FIT no longer
needs the `fdt rm /reserved-memory/ramoops@b0000000` workaround. If an older
U-Boot is used, that removal must happen after `bootm prep`.
