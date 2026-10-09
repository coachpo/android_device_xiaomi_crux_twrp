# Status

## Sealed version retained on October 9

The October 5 deployed Release is retained in the October 9 workspace artifact registry with `new_current_TWRP_build_or_acceptance_claim=false`. It has not been rebuilt or revalidated by the PE installation/regression task. See [the sealing overview](../../docs/rom-recovery-baseline-seal-status-2026-10-09.md).

| Identity | Fixed sealed input |
| --- | --- |
| Runtime version | `3.7.1_12-crux-twrp-12.1-coachpo` |
| Release tag | `twrp-crux-3.7.1_12-37242105687-1` |
| Release source | `8c10afbc879d6213049657a3e89e660bfd987ab5` |
| FIT SHA256 | `df812eef1821f519a2864b56d9f192eda22260aad6a24e9851503c72b692e2c1` |
| Kernel | Original CI `e45a24f31ee0` Cepheus Crux / 4.14.305; not Image858 or the newer maintained source HEAD |
| Symbols | 109 CI userland Build IDs matched; exact CI kernel ELF was not retained. The local kernel is separately paired. |
| Maintained kernel branch | `thirteen` advanced after this Release, through published `07426c…` to the tier 1 baseline commit `5e4950d2619f`; TWRP has not been rebuilt or revalidated against it |

Installed Release final physical UI feedback, broad touch/keyboard, MTP, decryption and backup/restore remain unverified. Historical RAM-fix feedback and PE results retain their own scopes. Public tier 1 uses a separately accepted PE Recovery set (2026100905/2026100906); TWRP is not part of that release product and has no new build or acceptance.

## Historical deployment and verification

Latest update (2026-10-06): the workspace's new menu reads `0x2924` blocks and its TWRP recheck
reached ADB in 9.69 seconds with eight CPUs; see the
[development baseline](../../docs/pe13-development-baseline-2026-10-05.md).

The haptics fix was built and published by GitHub Actions, then the downloaded
Release FIT passed RAM testing and was deployed to cache on 2026-10-05.
Ordinary U-Boot menu item 3 booted it with full readback verification.
See [GitHub Release deployment](RELEASE-DEPLOYMENT-2026-10-05.md).

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
| CPU and recovery | Eight CPUs online, TWRP `3.7.1_12-crux-twrp-12.1-coachpo`, recovery process and ADB remain available |
| Display | DRM Atomic Commit and physical interface confirmation belong to the October 4 corrected-DT result; final physical UI feedback for the installed October 5 Release remains unverified |
| USB | Recovery ADB verified with normal DWC3/PMIC PD path; MTP transfer not tested |
| Storage and ICE | Six UFS LUNs enumerated, block devices available, crypto initialization failure removed without disabling QTI crypto |
| Touch | Basic button interaction accepted by the user on the 2026-10-05 haptics RAM build; broader gesture/keyboard coverage remains untested |
| Haptics | AIDL-only client and service library-path fix RAM-booted on 2026-10-05; service/firmware/timed AW8697 effects verified, user confirmed vibration and smooth touch. See [HAPTICS.md](HAPTICS.md); the GitHub Release with this fix is now deployed and verified via menu item 3 |
| Top inset | The deployed GitHub Release includes the 80px top strip / 1080×2260 content area. See [DISPLAY-INSET.md](DISPLAY-INSET.md) for layout scope |
| Persistent menu slot | GitHub Release `twrp-crux-3.7.1_12-37242105687-1` deployed with authorization; full cache CRC32/SHA-256 and ordinary menu item 3 boot verified; other bytes preserved |
| Data decryption | Not validated; default-password attempt failed in recovery log. No formatting or data-wipe test performed |

## Integration and remaining verification

The deployed Release FIT uses `0x2924` 4096-byte UFS blocks, and the current
workspace menu reads `0x2924`. The 2026-10-05 Release deployment used the older
`0x293c` read, which was sufficient and needed no environment update. Keep `fdt_high` and
`initrd_high` unset; the older fixed ceilings do not fit the current Image
and ramdisk. The generated command uses the integration owner's guarded
`run boot_go` handoff.

The cache partition is a raw boot-payload container, not a mountable recovery
cache filesystem. Its mount error is expected in this layout; do not format
it to remove the error. The 2026-10-05 TWRP Release update started from a read-only snapshot
of the actual 384 MiB cache and changed only the TWRP FIT region. MIUI, PE
recovery, PE ROM and every byte outside that region were preserved by that update.

Further functionality work includes broader touch/keys coverage, MTP, and decryption
with an appropriate test plan. The current validation is recovery startup;
it does not establish PE ROM startup or full userdata decryption.
