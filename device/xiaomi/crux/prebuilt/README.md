# Prebuilt DT

## Live DT derived for the PE Crux kernel

`live-dt/twrp-live.dtb` derives from the ABL DT captured from the verified
legacy TWRP 3.3.1 boot. Its original SHA-256 was
`9744b16db18c12e8b084c5a30c3c70e94263c7ddbd20613736b9a299c442f03d`.
The current DT SHA-256 is `1d2e75468c5bc38ee2fef426566b6cfde07a604086a47909f9d15ebbc98db843`.

Three property changes adapt it to the PE Cepheus 4.14.305 Crux kernel, and
one removes the captured phone's identity:

- `/soc/ufshc@1d84000/reg` adds the ICE range `0x1d90000/0x8000`.
- The same node gets `reg-names = "ufs_mem", "ufs_ice"`, matching PE's own DTS.
- `/vendor/extcon_usb1/status` becomes `"disabled"`; its sole consumer USB1
  is already disabled. This releases PM8150 GPIO10 for the SMB5 charger.
- `/chosen/bootargs` drops the ten ABL identity keys listed in
  `scripts/crux_identity.py` (serial number, CPU ID, panel, board and storage
  IDs). `make-fit.sh` refuses a DT that carries any of them.

CPU descriptions, primary USB OTG/PD, crypto phandle, memory reservations and
all other property values are unchanged. The remaining `/chosen` values are
static capture inputs. The Recovery-container U-Boot (`fastboot boot`) appends
the receiving phone's ABL identity at prep; the Boot U-Boot cache entry passes
the DT bootargs unchanged, so an identity-free FIT is not a cache-slot payload.
Do not persist debug probe arguments from a later runtime capture.

The corrected working DT has been device-verified with the unchanged PE Image
on 2026-10-04: eight CPUs, TWRP UI, ADB and normal watchdog takeover. The
packaged FIT/cache deployment status is recorded in
[`BUILD-RESULTS-2026-10-04-DT.md`](../../../../docs/BUILD-RESULTS-2026-10-04-DT.md).

## Kernel

No prebuilt kernel is committed here. The manifest pins the kernel commit; see
`docs/KERNEL.md` for source and toolchain inputs.
