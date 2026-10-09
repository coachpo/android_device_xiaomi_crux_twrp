# GitHub Release deployment (2026-10-05)

Current sealing index (October 9): this Release remains the fixed historical TWRP input in the workspace baseline. Its original deployment/test scope below is unchanged; see [component sealing status](../../docs/rom-recovery-baseline-seal-status-2026-10-09.md). No new TWRP hardware acceptance or public tier 1 certification follows from PE regression. Public tier 1 recovery is the separately accepted PE Recovery candidate set; this TWRP Release remains the TWRP development input.

[Release](https://github.com/coachpo/android_device_xiaomi_crux_twrp/releases/tag/twrp-crux-3.7.1_12-37242105687-1) was built from the haptics fix commit
`8c10afbc879d6213049657a3e89e660bfd987ab5` by [Actions run 37242105687](https://github.com/coachpo/android_device_xiaomi_crux_twrp/actions/runs/37242105687).
The downloaded Release passed RAM testing, then was deployed to Crux's cache
TWRP slot and booted through ordinary U-Boot menu item **3: Boot TWRP recovery**.

## Artifact and layout

| Item | Verified value |
|---|---|
| FIT SHA-256 | `df812eef1821f519a2864b56d9f192eda22260aad6a24e9851503c72b692e2c1` |
| FIT size | 43,137,656 bytes; `0x2924` 4096-byte blocks |
| Persistent menu read | Existing `0x293c` blocks at LUN0 LBA `0x34000`; sufficient for this FIT |
| Cache size | 402,653,184 bytes (384 MiB) |
| Deployed cache SHA-256 | `89c7abbbf2149ef76209319c2cc81799890b3dc833f8c7d9b08dc49d2284f153` |
| Full cache readback CRC32 | `b7f90e38` |
| Kernel | PE Cepheus 4.14.305 Crux migration `e45a24f31ee0`, built by the workflow |

The downloaded FIT is used directly. The cache candidate starts from a fresh
read-only device snapshot and replaces only that FIT at offset `0x04000000`.
Every byte outside the replacement is identical, preserving MIUI and both PE
slots. The existing persistent menu already reads enough bytes, so no U-Boot
source or boot-partition update was needed.

## Validation

- GitHub signed provenance bound the artifacts to the expected repository,
  workflow run and source commit. All Release checksums and FIT component
  hashes passed, including embedded credits and the AIDL haptics payload.
- Release RAM boot reached ADB in 9.46 seconds. Eight CPUs, matching Release
  binaries, automatic vibrator service startup, waveform firmware load and
  three 150ms effects with automatic stop passed. It stayed healthy at
  uptime 144.10 seconds before flashing.
- ABL fastboot wrote cache after device/product/capacity/base hash checks.
  U-Boot read all 384 MiB back and its CRC32 matched the host image.
- Ordinary menu item 3 loaded the Release's exact component hashes through
  the guarded `boot_go` watchdog handoff. ADB appeared in 11.35 seconds;
  full-cache SHA-256, both recovery/vibration library hashes, eight CPUs and
  normal kernel watchdog initialization matched expectations.
- The installed Release passed a second timed-vibration test and remained
  operational beyond 99 seconds. The local RAM fix had already been accepted
  by the user as having vibration and smooth touch. Final physical UI feedback
  for the installed Release was requested separately.

Machine evidence and local rollback snapshot are kept in the deployment
session workspace, outside this repository. This is a TWRP/haptics validation;
MTP, decryption, backup/restore and broader gesture/keyboard coverage are not
established by it.
