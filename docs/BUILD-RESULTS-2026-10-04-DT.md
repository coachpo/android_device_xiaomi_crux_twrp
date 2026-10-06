# Device boot result with corrected Crux DT

This is the first corrected-DT startup record from 2026-10-04. The current
TWRP artifact and its deployment checks are in the
[2026-10-05 Release record](RELEASE-DEPLOYMENT-2026-10-05.md).

The unchanged PE official Cepheus 4.14.305 Crux Image booted TWRP 3.7.1
through U-Boot. The repair is in the DT used by the FIT, not a kernel rollback.

## Failure and repair

The captured ABL live DT omitted the named `ufs_ice` memory resource required
by the enabled QTI UFS crypto driver. The driver failed with `-22`, preventing
UFS host initialization. The corrected host resource list matches the PE
kernel's own `sm8150.dtsi`: `<0x1d84000 0x2500 0x1d90000 0x8000>` and
`reg-names = "ufs_mem", "ufs_ice"`. The ICE provider and crypto support remain.

A separate unused USB1 GPIO extcon claimed PM8150 GPIO10. SMB5's default
pinctrl then failed, preventing the charger/PMIC PD dependency chain from
binding. USB1 was already disabled; disabling only its extcon provider removes
the conflict while retaining primary USB OTG, PD and EUD references.

The earlier bus-hang conclusion was an observation error: bus QoS disabled
U-Boot's USB console clock. A returning probe could reach its target yet lose
its console. Timed watchdog checkpoints and a USB-clock retention control
proved progress beyond that alleged hang. Device-level deferred probing was
then traced using same-boot logs and RAM list/device identity reads.

## Fixed inputs and hardware evidence

- Official PE Cepheus base: `f4048f154b51`, branch `thirteen`.
- Crux migration Image commit: `e45a24f31ee0d48edba0cc164063c3a631589e31`.
- Image SHA-256: `f3f5a8c003d118204a904ca316a8d072f49e2bee01b67b8e06037c9b6cb4354b`.
- Prelude clang 16.0.2, same existing gzip recovery ramdisk.
- U-Boot: `2026.10-rc5-00614-g35579e6f8c14-dirty`, built 2026-10-04 16:24:49.
- Native U-Boot handoff used full SMP and normal USB drivers, with no Image
  RAM patches or initcall blacklist.
- Diagnostic boot: ADB recovery appeared at 8.52 seconds; version
  `3.7.1_12-crux-twrp-12.1`, CPU online `0-7`, recovery process present.
- Normal watchdog takeover: ADB appeared at 10.59 seconds and remained usable
  beyond 65 seconds; `MSM Watchdog Initialized` is logged.
- Recovery log records DRM graphics and successful Atomic Commit; the user
  confirmed the physical TWRP interface.
- UFS enumerated six LUNs; primary UDC `a600000.dwc3` and USB/charging power
  supplies are present.

The first two native ADB observation attempts had host sandbox/server errors;
empty stdout from those attempts is not absence evidence. Successful checks
ran with USB access and verified command return status.

## Artifact and deployment status

The corrected prebuilt live DT has exactly three changed properties. The
Crux source DTS disables the same unused extcon for future built overlays;
host CPP/DTBO compilation confirms that one added property and unchanged
primary USB. The kernel Image and config are unchanged.

FIT/cache artifacts and complete hardware logs are in the workspace's
`out/twrp-crux-pe-fixed-dt-2026-10-04/` record and the originating Codex task's
`outputs/`. The FIT fits the same `0x293c` blocks. The updated cache payload
preserves every byte outside the TWRP FIT region, including MIUI, PE recovery
and PE ROM. The user subsequently explicitly authorized this cache write.

The 384 MiB corrected cache was written through ABL fastboot after rechecking
the target and original cache SHA-256. Entire-cache U-Boot CRC32 before boot
and SHA-256 after boot matched the host image. The ordinary menu entry 3
booted without RAM patches or diagnostic bootargs; ADB appeared at 11.3076
seconds, all eight CPUs were online, normal watchdog ownership was confirmed
and the user again confirmed TWRP UI. Recovery remained healthy at uptime
123.91 seconds. Evidence is in `evidence/persistent-menu-boot/` under the
artifact record. Boot was not changed; no commit or push was performed.

Touch interaction, MTP, haptics and userdata decryption remain separate
functional checks. Default-password decryption failed; no data wipe/format
was performed. Cache is the raw boot-payload container, so its mount error
must not be addressed by formatting it.
