# Crux TWRP — Xiaomi Mi 9 Pro 5G (TWRP 3.7.1 / twrp-12.1)

Self-maintained TWRP device tree and build tooling for the Xiaomi Mi 9 Pro 5G
(codename **crux**, SM8150 / msmnile).

| Item | Value |
|---|---|
| TWRP baseline | **3.7.1** on the **`twrp-12.1`** branch (version string `3.7.1_12`) |
| Device tree path | `device/xiaomi/crux` |
| Kernel | `kernel/xiaomi/crux` from branch `crux-pe13-cepheus`; expected revision `e45a24f31ee0d48edba0cc164063c3a631589e31` — Linux **4.14.305** on the PE official Cepheus baseline (`PixelExperience-Devices/kernel_xiaomi_cepheus` `f4048f154b51`) plus the Crux migration commits. The manifest follows the branch; the build script only warns if the revision differs. |
| Boot path | **All entries go through U-Boot**; TWRP is packed as a FIT and loaded from the cache partition by the U-Boot boot menu |
| Status | **GitHub Release deployed on 2026-10-05:** signed build and downloaded assets verified, RAM test passed, cache full readback passed, ordinary U-Boot menu item 3 boot passed, eight CPUs and timed vibration verified. See [deployment record](docs/RELEASE-DEPLOYMENT-2026-10-05.md). |

The new PE-baseline TWRP has booted on the device with the DT compatibility
corrections described in the current result record. The corrected cache slot is deployed and verified by an ordinary menu boot;
the phone currently remains in TWRP.
U-Boot source and payload ownership is in `u-boot-port/`. This repository
produces the FIT and its exact `boot_twrp` command for integration; it does not
change the U-Boot checkout, flash cache or operate the device. See
`docs/UBOOT.md` and the [latest recorded device handoff](../u-boot-port/notes/HANDOFF-NEXT-2026-10-02.md).

## Repository layout

```text
device/xiaomi/crux/          TWRP device tree (BoardConfig, product, recovery root)
  prebuilt/live-dt/          ABL live device tree used by the proven TWRP FIT
  recovery/root/             init scripts, fstab, twrp.flags, stock crypto blobs
manifests/crux-twrp.xml      repo local manifest (device + kernel + pinned Prelude)
scripts/setup-twrp.sh        repo init/sync a TWRP 12.1 tree
scripts/build-twrp.sh        lunch twrp_crux-eng && mka recoveryimage
scripts/make-fit.sh          package recovery.img pieces into twrp-crux.itb
scripts/insert-cache-payload.py   write the FIT into a cache payload copy
docs/UBOOT.md                boot chain, FIT contract, cache layout
docs/KERNEL.md               kernel source integration and toolchain
docs/DEVICE-TEST.md          on-device validation plan (read-only first)
docs/STATUS.md               what is done, what is open
docs/BUILD-RESULTS-2026-10-02.md   first successful build: sizes, hashes, fixes
```

## Requirements

- x86_64 Linux userspace (the workspace's build VM is `cruxbuild`). About
  150 GB free is a planning estimate for the TWRP 12.1 tree plus `out/`; the
  first full sync used ~34 GB on top of the previously built tree.
- `repo` (Android repo launcher).
- U-Boot `mkimage` for packaging the FIT (the crux U-Boot tree's
  `tools/mkimage`, or any U-Boot `mkimage` on `PATH`).
- For later device work: `adb`, `fastboot`, and the EDL recovery path.

## Quick start

```sh
# 1. Sync a TWRP 12.1 tree (downloads the minimal TWRP manifest + crux tree + kernel)
scripts/setup-twrp.sh "$HOME/twrp-12.1"

# 2. Build TWRP (builds the kernel from source through vendor/twrp/build/tasks/kernel.mk)
scripts/build-twrp.sh "$HOME/twrp-12.1"
#    output: $HOME/twrp-12.1/out/target/product/crux/recovery.img
#            $HOME/twrp-12.1/out/target/product/crux/ramdisk-recovery.img

# 3. Package the U-Boot FIT (kernel compressed, live DT, recovery ramdisk)
scripts/make-fit.sh --out-dir "$HOME/twrp-12.1/out/target/product/crux"
#    output: out/fit-twrp/twrp-crux.itb + a new boot_twrp command line

# 4. Prepare a cache payload copy for review; this does not write the device
scripts/insert-cache-payload.py --fit out/fit-twrp/twrp-crux.itb \
    --base ../out/crux-bootmenu-2026-10-02/cache-payload.img
```

For quick kernel iterations TWRP can reuse an already-built kernel instead of
rebuilding the source:

```sh
TARGET_PREBUILT_KERNEL="$PWD/../out/crux-kernel-2026-10-01/Image" \
TARGET_FORCE_PREBUILT_KERNEL=1 scripts/build-twrp.sh "$HOME/twrp-12.1"
```

## GitHub Actions builds and releases

Run **Actions → TWRP Recovery for crux → Run workflow** on `main` to build
and publish a GitHub Release. Leave `release_tag` empty for a unique tag, or
supply a new tag. Pushing a `twrp-crux-*` tag also triggers the workflow.

The workflow builds the PE Cepheus Crux kernel and recovery from source on
Ubuntu 22.04, using the same pinned Prelude Clang 16.0.2 revision as the
verified local build. It includes the corrected live DT and the optional
80px top display inset. Release assets contain the Android recovery image,
U-Boot FIT, gzip ramdisk, resolved source manifest, build metadata, SHA-256
checksums and exact watchdog-protected menu command. Build logs are retained
as workflow artifacts, and release assets receive signed GitHub build provenance.
The TWRP version credits `coachpo`; full GitHub/source URLs are embedded in
`/system/etc/crux-release.txt` and included in `CREDITS.txt`. See
[`docs/CI-RELEASE.md`](docs/CI-RELEASE.md) and
[`official practice comparison`](docs/OFFICIAL-PRACTICES.md).

The workflow packages TWRP; device cache integration and hardware flashing
remain separate operations. A newly compiled release is not automatically
hardware-tested.

## Verified build (2026-10-02)

`lunch twrp_crux-eng && mka recoveryimage` completed on the `cruxbuild` VM
with the kernel built from source. Artifacts are archived in the workspace at
`out/twrp-crux-2026-10-02/`:

| Artifact | Size | SHA-256 |
|---|---|---|
| `recovery.img` | 128 MiB | `a715b1fb…b17217` |
| `ramdisk-recovery.img` | 24,518,969 B | `59c006aa…c71e3f3` |
| `kernel` (`Image-dtb`) | 50,441,476 B | `8cb961b1…4f38d1` |
| `Image` (raw) | 48,443,408 B | `af1063fa…e86889` |
| `twrp-crux.itb` | 44,398,928 B | `3170852a…335b23` |

- Kernel banner: `Linux version 4.14.357-openela-Marisa-20260104-ksunext`
  (clang 12.0.7, LLD 12.0.7).
- TWRP identity: `3.7.1_12-crux-twrp-12.1`.
- U-Boot FIT: `0x2a58` blocks (was `0x3486` for the proven 3.3.1 FIT), 22,177
  KiB free in the 64 MiB TWRP cache slot.
- Full report and the build fixes: `docs/BUILD-RESULTS-2026-10-02.md`.

## Rebuilds (2026-10-03)

Rebuilt twice after the kernel history cleanup. The first rebuild (pstore
kernel) produced a 44,413,240 B / `0x2a5c` FIT (`5a731a98…`, see
`docs/BUILD-RESULTS-2026-10-03.md`); the final rebuild used the branch tip
`50443f853589` with the PE13 fixes and produced a 44,462,716 B / `0x2a68` FIT
(SHA-256 `12c7c985…`, see `docs/BUILD-RESULTS-2026-10-03B.md`). Not
device-tested.

## Cepheus baseline rebuild (2026-10-04)

The kernel baseline moved from the self-maintained 4.14.357-openela
`thirteen-plus` line to the PE official Cepheus 4.14.305 baseline that PE13 now
uses (`kernel/xiaomi/crux` checked out at `crux-pe13-cepheus`,
`b38f5a5c8cac`) and the kernel is now built with the PE13 Prelude clang 16
toolchain in LLVM mode. The recovery image and FIT were rebuilt against it
(43,204,672 B / `0x2935` blocks, SHA-256 `2a0a2c7f…`; sizes and hashes in
`docs/BUILD-RESULTS-2026-10-04.md`).

On 2026-10-04 the FIT was written to the TWRP cache slot and the U-Boot
`boot_twrp` command updated (new block count, `fdt_high`/`initrd_high` unset);
the menu entry boots the FIT, but the Cepheus kernel stops after
`Starting kernel` without re-enumerating USB/ADB — the same early-boot hang as
the new-baseline PE recovery candidate. That initial failure is superseded by the DT correction and successful
2026-10-04 device boot in [`BUILD-RESULTS-2026-10-04-DT.md`](docs/BUILD-RESULTS-2026-10-04-DT.md).

## Why twrp-12.1 and not a newer branch

As of 2026-10-02, the official TeamWin release page lists TWRP 3.7.1
([released 2024-02-21](https://twrp.me/site/update/2024/02/21/3.7.1-released.html)). This checkout uses its `twrp-12.1` build branch:

- TWRP 3.7.1's Android 12.1 release line is version `3.7.1_12` and targets
  Android 12.1 and up, covering the PE13 (Android 13) userdata layout.
- `android-13`, `android-14` and `android-14.1` exist in the TWRP repository
  but have **no official release** (`android-14.1` still identifies as
  `3.7.1_14`). They are a later, separate evaluation.
- Linux 4.14 is **not** a documented TWRP ceiling. The crux kernel already has
  `ANDROID_BINDERFS`, `DM_DEFAULT_KEY`, `DM_CRYPT`, `DM_VERITY`,
  `FS_ENCRYPTION` (+ inline crypt), `EROFS_FS`, `SCSI_UFS_QCOM`, `DRM_MSM`,
  `USB_CONFIGFS_F_FS/F_MTP`, `INPUT_EVDEV` and the `ST_FTS_V521` touch driver.
  The one deliberate difference is that TWRP 12.1's vold still falls back to
  the session keyring for v1 fscrypt policies, while 14.1 removed that
  fallback — relevant only if `twrp-14.1` is evaluated later.

## Provenance of the included blobs

`recovery/root/` contains the stock crux TEE/recovery userspace needed for
decryption and haptics (`qseecomd`, keymaster 4.0, gatekeeper 1.0, vibrator,
their `lib64` dependencies and firmware). They come from the device's stock
firmware via the community crux TWRP device tree (TWRP A12.1). See `NOTICE`.

The kernel is **not** committed; it is built from
`coachpo/kernel_xiaomi_crux` (the PE13 Cepheus baseline line).

## Licence

Original content: Apache-2.0. Bundled stock binaries: see `NOTICE`.
