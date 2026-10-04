# On-device validation plan

TWRP 3.7.1 on the PE Cepheus 4.14.305 Crux kernel has passed a device startup
check through U-Boot with corrected RAM DT: UI confirmed by the user, ADB,
all eight CPUs, UFS enumeration and normal watchdog takeover. See
[`BUILD-RESULTS-2026-10-04-DT.md`](BUILD-RESULTS-2026-10-04-DT.md).
The corrected cache is now deployed with explicit authorization; full readback
and ordinary menu boot passed. ADB appeared at 11.3 seconds and the user again
confirmed TWRP UI.

The remaining phases below are a test plan, not completed functional checks.
Touch interaction, MTP, haptics, recovery operations and full userdata decryption
have not been validated. Cache is a raw FIT payload container on this setup;
its mount failure must not be addressed by wiping or formatting it. Device
storage writes remain owned by the U-Boot integration task and need explicit
authorization for the specific operation.

## Host-side gate

1. Build from a recorded TWRP tree and kernel revision; see `scripts/build-twrp.sh` and `docs/STATUS.md`.
2. Package with `scripts/make-fit.sh`. Record its SHA-256 and block count, check that the FIT fits the 64 MiB slot, and verify the generated single-line `boot_twrp` command.
3. Hand the FIT and command to the U-Boot integration owner. Do not alter U-Boot source, the cache payload or the device from this checkout.

## Phase 1 — boot and identity (read-only observation)

Run only after the new FIT has been built and integrated. If integration requires writing the cache or boot partition, obtain explicit authorization for that write first.

- Before a debug kernel boot, the U-Boot integration owner must pass the [watchdog recovery gate](../../u-boot-port/notes/KERNEL-DEBUG-WATCHDOG.md): verify the deployed handoff arms the timer and recovery leaves the menu waiting. Unattended hang diagnosis needs the documented kernel parameters before `bootm prep` or the returning-probe `--watchdog` mode; ordinary kernel takeover can keep feeding despite an initcall stall. If recovery setup fails, repair and verify it before further debug launches.
- Keep bounded diagnostic boots distinct from normal UI/function validation. The diagnostic parameters prevent kernel takeover and impose a timeout even on a healthy kernel; normal validation needs normal watchdog ownership. Record full bootargs, timer setting, firmware/USB recovery timing and whether a checkpoint was captured or the device reset.
- Select TWRP from the U-Boot menu.
- Record the splash/UI, `adb devices`, `ro.twrp.version`, `ro.product.device`, and the U-Boot console output.
- If it fails, capture the last `bootm`/kernel message and return using a verified menu path. Do not assume a failed recovery boot is harmless.

## Phase 2 — collect logs before changing storage

```sh
adb shell dmesg > dmesg.txt
adb pull /tmp/recovery.log
adb shell logcat -b all -d > logcat.txt
adb shell cat /proc/cmdline
adb shell cat /proc/version
```

Check UFS enumeration, backlight, touch firmware, `/dev/qseecom`, keymaster/gatekeeper startup and DRM. Keep logs local and redact identifiers before sharing.

## Phase 3 — non-destructive hardware checks

| Area | Check |
|---|---|
| Display | Orientation, colors and brightness behavior |
| Touch | Multi-touch and phantom input; confirm `hbtp_vm` is ignored |
| Keys | Volume and power input |
| USB | ADB, MTP and OTG enumeration |
| Storage | Inspect mount state first; read only unless a separate write test is authorized |
| Haptics | Check the optional vibrator service |
| RTC | Read the reported time |

## Phase 4 — data decryption

Decryption can expose personal data and may require a screen-lock credential. Obtain explicit approval for this phase and use only a credential supplied for the test. Do not copy or retain user data.

Start with the documented non-mutating property checks:

```sh
adb shell getprop ro.crypto.state
adb shell getprop ro.crypto.type
adb shell getprop ro.crypto.volume.metadata.method
```

If an authorized credential test fails, capture `/tmp/recovery.log` and compare the PE13 fstab flags and `vendor.prop` with the source tree. Avoid formatting or wiping as a diagnostic shortcut.

## Phase 5 — storage-changing recovery tests

Wiping cache/metadata, formatting `/data`, flashing boot/dtbo, or restoring data changes device storage and can cause data loss or an unbootable device. Run a specific operation only with explicit authorization for that operation, a confirmed backup/recovery path, the exact target device and verified image. Record the command and read-back result.

## Failure recovery

Use the verified automatic watchdog path for kernel diagnostic hangs; see the [watchdog guide](../../u-boot-port/notes/KERNEL-DEBUG-WATCHDOG.md). A watchdog reset to U-Boot is recovery evidence, not a successful TWRP boot or a returning-probe hit. Capture same-boot probe logs before another reset; do not infer the prior checkpoint from RAM read after reset. Manual power reset is a way to regain control to repair a failed recovery path, not the routine for each experiment.

The bootloader and EDL recovery route are documented elsewhere, but they do not make an unverified write safe. Confirm the device's current mode and target before any recovery write; use the U-Boot handoff and the dated EDL record for their respective states.
