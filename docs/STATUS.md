# Status

As of 2026-10-02 this repository contains a complete **code-level** TWRP
adaptation for crux on the TWRP 12.1 baseline. The device tree **builds
successfully** on the OrbStack `cruxbuild` VM (128 MiB `recovery.img`,
24.5 MB ramdisk, 44.4 MB U-Boot FIT); see
[`BUILD-RESULTS-2026-10-02.md`](BUILD-RESULTS-2026-10-02.md). No artifact from
this adaptation has been flashed or tested on device yet. The phone has
separately booted the older TWRP 3.3.1 FIT from the verified U-Boot menu; see
`../../u-boot-port/notes/HANDOFF-NEXT-2026-10-02.md`.

## Component state

| Component | State | Notes |
|---|---|---|
| TWRP baseline | configured | `twrp-12.1` (3.7.1_12); `lunch twrp_crux-eng` |
| Kernel source integration | configured | inline build of `kernel/xiaomi/crux` (`crux_defconfig`), branch `crux-pe13-cepheus`; expected revision `b38f5a5c8cac` (the build script warns on mismatch but does not fail); PE13 Cepheus 4.14.305 + Crux migration |
| Device kernel capabilities | verified (config) | binderfs, dm-default-key, dm-crypt/verity, FBE v2+ICE, UFS, DRM, touch; EROFS is not enabled in the Cepheus baseline (ext4 system) — see `KERNEL.md` |
| Partition / fstab layout | configured | static non-A/B; exact PE13 userdata flags (`fileencryption=ice`, metadata keydirectory, reservedsize) |
| `twrp.flags` | configured | full crux partition list converted from the proven 3.3.1 image to TWRP 12.1 syntax |
| Display / touch / keys | configured, unverified | RGBX_8888 DRM path, `hbtp_vm` input blacklist, panel0 backlight, ST FTS firmware from `firmware_mnt` |
| USB (adb / MTP) | configured, unverified | custom configfs `init.recovery.usb.rc` + `a600000.dwc3` |
| Crypto / decryption | configured, unverified | twrp-common `qcom_decrypt` + `qcom_decrypt_fbe`, stock keymaster 4.0 / gatekeeper 1.0 / qseecomd blobs, FBE v2 props |
| Haptics | configured, unverified | AW8697 firmware in ramdisk + vibrator HAL binaries |
| U-Boot FIT packaging | configured | `scripts/make-fit.sh`, gzip kernel + live DT, recomputes `boot_twrp` blocks |
| Build | **verified 2026-10-02; rebuilt 2026-10-03; Cepheus-baseline build 2026-10-04** | `lunch twrp_crux-eng` + `mka recoveryimage` on the `cruxbuild` VM; kernel 4.14.305 from source with Prelude clang 16; see `BUILD-RESULTS-2026-10-02.md`, `BUILD-RESULTS-2026-10-03.md`, `BUILD-RESULTS-2026-10-03B.md` and `BUILD-RESULTS-2026-10-04.md` |
| Recovery on device | **not run for this adaptation** | 2026-10-04: menu entry 3 boots the Cepheus-baseline FIT but the kernel stops after `Starting kernel` (no USB/ADB), the same early-boot hang as the new PE recovery candidate; the U-Boot menu/env and cache slot are integrated |
| Decryption on PE13 data | **not verified** | main functional risk |

## Open risks / questions

1. **FIT size vs cache slot.** Resolved for the 2026-10-02 build: the
   gzip-kernel FIT was 44,398,928 B (`0x2a58` blocks). The 2026-10-03 pstore
   rebuild is 44,413,240 B (`0x2a5c`); the final 2026-10-03 rebuild with the
   PE13 kernel fixes is 44,462,716 B (`0x2a68`), and the 2026-10-04
   Cepheus-baseline build is 43,204,672 B (`0x2935`), leaving ~23,343 KiB free
   in the 64 MiB TWRP cache slot. Re-check after any further ramdisk or kernel
   change.
2. **Cepheus-baseline kernel early boot.** The 2026-10-04 FIT reaches
   `Starting kernel` and never re-enumerates USB/ADB, exactly like the
   new-baseline PE recovery candidate (with its own DT and with the old
   recovery DT). Blocked on the PE13 kernel early-boot investigation; see
   `BUILD-RESULTS-2026-10-04.md`, `../../out/crux-kernel-cepheus-earlyboot-2026-10-03/`
   and `../../u-boot-port/notes/HANDOFF-PE13-2026-10-03E.md`. The menu command
   must keep `fdt_high`/`initrd_high` unset for the Cepheus `image_size` and the
   24.5 MiB ramdisk.
2. **Decryption of PE13 `/data`.** PE13 uses `fileencryption=ice` +
   metadata encryption (`dm-default-key`, options v2) with the nabu Android 12
   keymaster line. The ramdisk ships the stock crux keymaster 4.0/gatekeeper 1.0
   blobs; the metadata/v2 combination is the same class that the community
   crux A12.1 tree reported as broken ("Data 解密" in its README). Expect this
   to need on-device iteration.
3. **Pixel format.** The community crux TWRP trees use `RGBX_8888`, while the
   PE13 recovery uses `BGRA_8888`. `RGBX_8888` is configured here; if the
   colours are wrong, switch to `BGRA_8888` and rebuild.
4. **Touch firmware.** `FW_UPDATE_ON_PROBE` makes the ST FTS driver use
   `request_firmware()`; the ramdisk relies on the modem partition being
   mounted at `/vendor/firmware_mnt/image`. If touch does not work, check that
   mount and the `ueventd.qcom.rc` `firmware_directories` line.
5. **Vibrator / haptics HAL** binaries are stock MIUI; the service is
   optional and harmless if it cannot start.
6. **AVB.** The recovery image is built with an AVB test key. The device is
   unlocked and boots through U-Boot, so AVB only matters if the image is
   flashed to the recovery partition and booted by ABL — a use case that is
   explicitly not the primary path.
7. **`CONFIG_DM_INIT` absent.** The PE13 kernel cannot parse MIUI's
   `dm=`/`root=/dev/dm-0` boot args. That affects booting MIUI with this
   kernel, not TWRP (TWRP sets up its own mounts).

## Next steps

1. ~~Compile on the build host and fix any device-tree build errors.~~ Done
   2026-10-02; see `BUILD-RESULTS-2026-10-02.md`.
2. Hand the current `boot_twrp` block count (`0x2935`; was `0x2a68`/`0x2a5c`/`0x2a58`
   for the earlier builds and `0x3486` for the legacy 3.3.1 FIT) and the FIT
   to the U-Boot boot-menu session and prepare a cache payload copy. Done on
   2026-10-04: the FIT is in the TWRP cache slot and the corrected `boot_twrp`
   is in the U-Boot env; the menu entry boots it (kernel early-boot hang
   pending).
3. After the FIT handoff, obtain explicit authorization for the needed device operations and follow `docs/DEVICE-TEST.md` by phase.
4. Iterate on decryption and display/touch if needed.
5. Only later: evaluate `twrp-14.1` (`3.7.1_14`).
