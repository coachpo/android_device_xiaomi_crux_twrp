# prebuilt

## `live-dt/twrp-live.dtb`

ABL live device tree used by the currently-working U-Boot TWRP FIT.

- Source: `out/crux-bootmenu-2026-10-02/twrp-live.dtb` (workspace), captured
  from the proven TWRP 3.3.1 boot.
- SHA-256: `9744b16db18c12e8b084c5a30c3c70e94263c7ddbd20613736b9a299c442f03d`
- Contains the stock ABL `/chosen/bootargs` (permissive SELinux, `buildvariant=eng`,
  `androidboot.boot_devices=soc/1d84000.ufshc`, panel command
  `dsi_samsung_fhd_ea8076_f1s_cmd_display:`, ramoops reservation) and the
  overlay nodes that drive the panel, touch and TEE in recovery.

`scripts/make-fit.sh` uses this file by default. Regenerate it only from a
working recovery (`/sys/firmware/fdt`) or build a replacement from
`sm8150-v2.dtb` + `crux-sm8150-overlay.dtbo` and patch `/chosen/bootargs`.

## No prebuilt kernel

The kernel is not committed here. TWRP builds it from the pinned
`coachpo/kernel_xiaomi_crux` source through
`vendor/twrp/build/tasks/kernel.mk` (see `docs/KERNEL.md`). For quick
iteration, pass `TARGET_PREBUILT_KERNEL` to `scripts/build-twrp.sh`.
