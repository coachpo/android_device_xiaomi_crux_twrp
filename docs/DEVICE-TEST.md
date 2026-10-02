# Device test plan (read-only first)

Do not run any of this until the U-Boot boot-menu session is free and the
device owner has approved device access. Until then this repository only
produces host-side artifacts.

## Preconditions

- The U-Boot boot menu is updated with the new `boot_twrp` line from
  `scripts/make-fit.sh` and the cache payload (or a copy) contains the new
  `twrp-crux.itb`.
- The device is backed up as far as possible; EDL recovery is available
  (`crux_images_V13.0.1.0.RFXCNXM_...` + the verified EDL path).
- Serial console access through the U-Boot USB CDC-ACM console is useful for
  early failures (the PE kernel has no GENI console and no pstore, so the
  screen and ADB are the primary signals).

## Phase 1 — boot and identity (read-only)

1. Reboot into the U-Boot menu, select TWRP.
2. Expect:
   - the TWRP splash/UI;
   - host `adb devices` shows `recovery`;
   - `adb shell getprop ro.twrp.version` -> `3.7.1_12-...`;
   - `adb shell getprop ro.product.device` -> `crux`.
3. If it does not boot: capture the U-Boot console output, note the last
   `bootm`/kernel message, and return to the menu (power/volume keys) or EDL.

## Phase 2 — collect logs before changing anything

```sh
adb shell dmesg > dmesg.txt
adb pull /tmp/recovery.log
adb shell logcat -b all -d > logcat.txt
adb shell cat /proc/cmdline
adb shell cat /proc/version
```

Check for: UFS enumeration, `panel0-backlight`, `fts` touch probe/firmware,
`/dev/qseecom`, `keymaster`/`gatekeeper` service start, DRM card probe.

## Phase 3 — hardware smoke tests

| Area | Check |
|---|---|
| Display | UI orientation, colours, brightness slider path (`/sys/class/backlight/panel0-backlight/brightness`) |
| Touch | multi-touch, no phantom input (the `hbtp_vm` device must be ignored) |
| Keys | volume / power |
| USB | ADB on/off, MTP visible to the host, OTG mass storage |
| Storage | mount `/system_root`, `/vendor`, `/cache`, `/metadata`; read a file from each |
| Haptics | optional; check `vendor.qti.hardware.vibrator` service |
| RTC | `date` is sane (QCOM RTC fix) |

## Phase 4 — decryption (the main risk)

Test in this order and record everything:

1. `/data` with no lock screen credential.
2. `/data` with a PIN/password.
3. Reboot after decryption and access internal storage.
4. Backup and restore of a small `/data` subset.

Useful checks:

```sh
adb shell getprop ro.crypto.state
adb shell getprop ro.crypto.type
adb shell getprop ro.crypto.volume.metadata.method
adb shell twrp decrypt <credential>   # if needed
```

If decryption fails, capture `/tmp/recovery.log` and the output of the
prepdecrypt/keymaster services (`setprop prepdecrypt.loglevel 2` first, as
documented by `device/qcom/twrp-common`) and compare against the PE13 fstab
flags and `vendor.prop` in this tree.

## Phase 5 — recovery operations

- Wipe cache / metadata, format `/data` with the correct FBE v2 scheme.
- Flash a small image (boot/dtbo) to a partition and verify it.
- Verify reboot to system / recovery / bootloader / EDL.

## Failure handling

- The device is unlocked; a failed recovery boot does not brick the system.
- If the TWRP FIT fails before userspace, the U-Boot console shows why; the
  menu can still boot MIUI or PE.
- Keep EDL as the final fallback and confirm the target device before any
  flash.
