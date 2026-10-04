# Crux recovery haptics (2026-10-05)

The repaired recovery passed a temporary U-Boot RAM boot. The user confirmed
vibration and smooth touch interaction. This record describes the local RAM
validation; Release builds and persistent deployment require their own checks.

## Cause and change

`minuitwrp/events.cpp` selects HIDL before AIDL when both input haptics options
are enabled. The bundled QTI service and its VINTF manifest implement AIDL.
`BoardConfig.mk` now enables only `TW_SUPPORT_INPUT_AIDL_HAPTICS`.

The recovery linker defaults to `/system/lib64`, while the QTI implementation
and effect libraries are in `/vendor/lib64`. The original service repeatedly
exited with `vendor.qti.hardware.vibrator.impl.so not found`. Its init definition
now supplies `LD_LIBRARY_PATH=/vendor/lib64:/vendor/lib64/hw`. The second,
unused vibrator definition in `init.recovery.hardware.rc` was removed.

If the AIDL service is absent, the current TWRP implementation waits about
five seconds per request. This was observed during a temporary UI restart;
restoring the init-managed service removed the apparent touch lag. The full
repaired ramdisk starts that service automatically.

No kernel or DT change is required. The QTI AIDL implementation sends timed
FF_CONSTANT effects to the AW8697 input device. The existing driver selects
RAM loop mode and stops playback using its duration timer. Firmware loaded
successfully from the existing ramdisk via firmware fallback.

## Verification

- `scripts/build-twrp.sh` / `recoveryimage` passed using the verified fixed2
  PE Cepheus 4.14.305 kernel (`e45a24f31ee0`), with the recovery rebuilt.
- Final gzip/cpio inspection confirmed the AIDL library and init definitions,
  vendor libraries, firmware and maintainer credits.
- FIT component readbacks matched the input Image, live DT and ramdisk.
- Watchdog-protected U-Boot RAM boot reached ADB in 9.43 seconds; all eight
  CPUs were online. `qti.vibrator` started automatically, AW8697 firmware
  checksum passed and three 150ms requests stopped on time. Actual UI
  requests were also observed. Service remained running beyond 89 seconds.
- User accepted vibration and smooth touch. Full cache SHA-256 remained
  `9005ad062a3b81abb4a949bec86c43f5811e49e4eb019e2e82b812112bae9e47`.

FIT SHA-256: `afa8e764b67c6d3c63586ad89d3fd73b108eadaccf77ef76728fc425b25bb8a7`;
43,235,500 bytes, `0x293c` 4096-byte blocks. The 80px top inset remains enabled.

## Incremental build note

The TWRP 12.1 `relink_libraries` phony package can retain old recovery-root
library copies after rebuilding a library. For this iteration, removing the
generated `out/target/product/crux/obj/FAKE/relink_libraries_intermediates/relink_libraries-timestamp`
and rebuilding `recoveryimage` refreshed them. Inspect the final ramdisk:
its `system/lib64/libminuitwrp.so` must match the new system build and reference
`AServiceManager_getService`, with no HIDL `IVibrator::getService` reference.
This does not affect a fresh CI build.
