# Status

The PE official Cepheus 4.14.305 Crux kernel has booted TWRP 3.7.1 through the
existing U-Boot on 2026-10-04. Native boot with corrected RAM DT reached ADB
in 8.5 seconds; normal kernel watchdog takeover reached ADB in 10.6 seconds
and remained operational beyond 65 seconds (later checked at uptime 2383 seconds).
The corrected cache has now been deployed with explicit authorization and full
readback; its ordinary menu boot reached ADB in 11.3 seconds and stayed healthy
at uptime 123.91 seconds. All eight CPUs were online and
the user confirmed the TWRP interface. See
[`BUILD-RESULTS-2026-10-04-DT.md`](BUILD-RESULTS-2026-10-04-DT.md).

## Current component state

| Component | Verified state |
|---|---|
| Kernel baseline | PE official Cepheus 4.14.305 plus Crux migration, Image built at `e45a24f31ee0`; no archived kernel substitution |
| Device tree | UFS ICE resource added to the captured live DT; unused USB1 GPIO extcon disabled to release SMB5 GPIO10 |
| CPU and recovery | Eight CPUs online, TWRP `3.7.1_12-crux-twrp-12.1`, recovery process and ADB remain available |
| Display | DRM Atomic Commit in recovery log and physical TWRP interface confirmed by user |
| USB | Recovery ADB verified with normal DWC3/PMIC PD path; MTP transfer not tested |
| Storage and ICE | Six UFS LUNs enumerated, block devices available, crypto initialization failure removed without disabling QTI crypto |
| Touch | Basic button interaction accepted by the user on the 2026-10-05 haptics RAM build; broader gesture/keyboard coverage remains untested |
| Haptics | AIDL-only client and service library-path fix RAM-booted on 2026-10-05; service/firmware/timed AW8697 effects verified, user confirmed vibration and smooth touch. See [HAPTICS.md](HAPTICS.md); cache has not been updated with this fix |
| Optional top inset | 80px top strip / 1080×2260 content candidate built and RAM-booted with eight CPUs; current cache unchanged. See [DISPLAY-INSET.md](DISPLAY-INSET.md) for scope and UI verification |
| Persistent menu slot | Corrected cache deployed with explicit authorization; full SHA-256 readback and ordinary menu boot passed; other slots preserved |
| Data decryption | Not validated; default-password attempt failed in recovery log. No formatting or data-wipe test performed |

## Integration and remaining verification

The corrected FIT uses `0x293c` 4096-byte UFS blocks. Keep `fdt_high` and
`initrd_high` unset; the older fixed ceilings do not fit the current Image
and ramdisk. The generated command uses the integration owner's guarded
`run boot_go` handoff.

The cache partition is a raw boot-payload container, not a mountable recovery
cache filesystem. Its mount error is expected in this layout; do not format
it to remove the error. The prepared update starts from a read-only snapshot
of the actual 384 MiB cache and changes only the TWRP FIT region. MIUI, PE
recovery, PE ROM and every byte outside that region are preserved.

Further functionality work includes broader touch/keys coverage, MTP, and decryption
with an appropriate test plan. The current validation is recovery startup;
it does not establish PE ROM startup or full userdata decryption.
