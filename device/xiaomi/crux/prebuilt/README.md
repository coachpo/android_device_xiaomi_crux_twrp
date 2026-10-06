# Prebuilt DT

## Live DT derived for the PE Crux kernel

`live-dt/twrp-live.dtb` derives from the ABL DT captured from the verified
legacy TWRP 3.3.1 boot. Its original SHA-256 was
`9744b16db18c12e8b084c5a30c3c70e94263c7ddbd20613736b9a299c442f03d`.
The current compatible DT SHA-256 is `1442852931cbf49829ffcbe8f1b51661ebbf9321828bf0d58b6abd66fc2b6633`.

Exactly three property changes adapt it to the PE Cepheus 4.14.305 Crux kernel:

- `/soc/ufshc@1d84000/reg` adds the ICE range `0x1d90000/0x8000`.
- The same node gets `reg-names = "ufs_mem", "ufs_ice"`, matching PE's own DTS.
- `/vendor/extcon_usb1/status` becomes `"disabled"`; its sole consumer USB1
  is already disabled. This releases PM8150 GPIO10 for the SMB5 charger.

CPU descriptions, primary USB OTG/PD, crypto phandle, memory reservations and
all other property values are unchanged. The supplied `/chosen` values are
static capture inputs; U-Boot replaces the initrd and final boot arguments
at prep. Do not persist debug probe arguments from a later runtime capture.

The corrected working DT has been device-verified with the unchanged PE Image
on 2026-10-04: eight CPUs, TWRP UI, ADB and normal watchdog takeover. The
packaged FIT/cache deployment status is recorded in
[`BUILD-RESULTS-2026-10-04-DT.md`](../../../../docs/BUILD-RESULTS-2026-10-04-DT.md).

## Kernel

No prebuilt kernel is committed here. The manifest tracks `thirteen`;
its expected source revision is `d035d3881e3732bb8e56b5c251ca21f85cf4e404`. The expected SHA is a warning,
not a pin. See `docs/KERNEL.md` for source and toolchain inputs.
