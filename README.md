# Crux TWRP — Xiaomi Mi 9 Pro 5G (TWRP 3.7.1 / twrp-12.1)

Self-maintained TWRP device tree and build tooling for the Xiaomi Mi 9 Pro 5G
(codename **crux**, SM8150 / msmnile).

The retained TWRP is the GitHub Release
`twrp-crux-3.7.1_12-37242105687-1` (source `8c10afbc879d`, FIT SHA-256
`df812eef…`). It is the U-Boot cache-menu entry 3 and the CRC witness that the
crux-install/1 installer checks; it is not an installer. Its identity, symbols
and readbacks are in the workspace
component record (Obsidian 《Crux 组件身份与保留件》)
and its deployment in [RELEASE-DEPLOYMENT-2026-10-05.md](docs/RELEASE-DEPLOYMENT-2026-10-05.md).
PE installation uses the separate RAM-only install TWRP (see the
workspace notes, Obsidian 《Crux 00 总览》).

| Item | Value |
|---|---|
| TWRP baseline | **3.7.1** on the **`twrp-12.1`** branch (version string `3.7.1_12`) |
| Device tree path | `device/xiaomi/crux` |
| Kernel | `coachpo/kernel_xiaomi_crux` branch `thirteen` (PE official Cepheus `f4048f154b51`, Linux **4.14.305**, plus the Crux migration). The retained Release was built at `e45a24f31ee0`. The manifest pins one commit (`scripts/kernel-pin.py` prints it) and `scripts/build-twrp.sh` refuses another checkout or tracked changes; see [KERNEL.md](docs/KERNEL.md) |
| Boot path | All entries go through U-Boot; TWRP is a FIT loaded from the cache partition by the U-Boot boot menu |
| Verification scope | [STATUS.md](docs/STATUS.md) |

The current build inputs differ from the retained Release's (kernel branch
and expected revision, `crux-release.txt`). A build from this checkout is a new
artifact that needs its own hardware test; it does not replace the retained
FIT. U-Boot source and cache-payload ownership is in the workspace `crux-uboot/`. This
repository produces the FIT and its exact `boot_twrp` command for integration;
it does not change the U-Boot checkout, write cache or operate the device. See
[UBOOT.md](docs/UBOOT.md).

## Repository layout

```text
device/xiaomi/crux/          TWRP device tree (BoardConfig, product, recovery root)
  prebuilt/live-dt/          ABL live device tree packaged into the FIT
  recovery/root/             init scripts, fstab, twrp.flags, stock crypto/haptics blobs
manifests/crux-twrp.xml      exact lock for every TWRP 12.1, kernel and toolchain project
scripts/setup-twrp.sh        sync the lock and export the device leaf from this commit
scripts/check-source-lock.py verify pinned checkouts and the device leaf without writes
scripts/build-twrp.sh        verify source, lunch twrp_crux-eng && mka recoveryimage
scripts/kernel-pin.py        print the kernel commit the manifest pins
scripts/make-fit.sh          package recovery.img pieces into twrp-crux.itb
scripts/package-release.py   verify FIT components and write release metadata
.github/workflows/twrp-release.yml  CI build and GitHub Release
docs/UBOOT.md                FIT contract and U-Boot handoff
docs/KERNEL.md               kernel source integration and toolchain
docs/CI-RELEASE.md           CI release contents
docs/OFFICIAL-PRACTICES.md   comparison with official TWRP practice
docs/HAPTICS.md              AW8697 haptics in recovery
docs/DISPLAY-INSET.md        top display inset
docs/DEVICE-TEST.md          on-device validation plan (read-only first)
docs/STATUS.md               verified and open scope
docs/BUILD-RESULTS-2026-10-04-DT.md   live-DT correction and first startup evidence
docs/RELEASE-DEPLOYMENT-2026-10-05.md retained Release deployment record
```

## Requirements

- Ubuntu 22.04 x86_64 (the workspace's build VM is `cruxbuild`). About
  150 GB free is a planning estimate for the TWRP 12.1 tree plus `out/`.
- `repo` (Android repo launcher).
- Ubuntu build/packaging dependencies from the
  [workflow](.github/workflows/twrp-release.yml), including `u-boot-tools` and DTC.

## Quick start

```sh
sudo install -d -o "$(id -u)" -g "$(id -g)" /mnt/twrp
# If reusing this VM's existing tree, bind it to the same short path as CI:
# sudo mount --bind "$HOME/twrp-12.1" /mnt/twrp
# For an existing separately managed kernel and Prelude checkout only:
# export TWRP_USE_EXISTING_CHECKOUTS=1
scripts/setup-twrp.sh /mnt/twrp
python3 scripts/check-source-lock.py /mnt/twrp
scripts/build-twrp.sh /mnt/twrp
scripts/package-release.py --tree /mnt/twrp --out /path/to/new/dist
(cd /path/to/new/dist && sha256sum --check SHA256SUMS)
```

Use the same Git commit in CI and locally. The 249 upstream pins are from
the previously verified source export, plus the locked kernel and Prelude.
Keep the kernel pin aligned with PE. The build takes time and build number
from the Git commit, uses `crux@build`, and disables ccache.

### RAM-only UI candidate (host packaging)

For display, input, vibration and recovery ADB tests without physical storage,
use the separate local RAM UI profile. It is neither the cache TWRP nor the
signed ZIP installer, and it has no backup, decryption or flash volumes.

1. On Linux, run `scripts/build-ram-ui-kernel.sh TWRP_TREE NEW_KERNEL_OUT`.
   It uses the existing TWRP build's `.config` as a baseline and builds a
   separate `NEW_KERNEL_OUT/arch/arm64/boot/Image` from the pinned kernel.
2. Run `python3 scripts/package-ram-ui.py --source-fit ORIGINAL_FIT
   --source-fit-sha256 ORIGINAL_SHA256 --kernel RAW_IMAGE --mkimage MKIMAGE
   --dumpimage DUMPIMAGE --out NEW_DIR` with `fdtget` and `fdtput` on `PATH`.
   The output contains the FIT, embedded kernel config, verification metadata
   and checksums. The recipe does not create `recovery.img` or a cache command.

The profile omits the UFS, MMC, USB-storage and loadable-module paths, disables
the internal storage controllers in its DT and removes the DT mount table.
It uses a private RAM file for `/misc` instead of the physical BCB and removes
decryption init routes. A RAM `/TWRP/.twrpcf` marker lets TeamWin discover its
default settings folder without trying to mount a nonexistent storage volume.
The original TWRP UI, USB gadget and haptics userspace
are retained; the USB controller stays `dr_mode = "otg"` as in the source DT
(the MSM DWC3 gadget ignores VBUS in `peripheral` mode and never enumerates). Packaging checks the selected FIT components and scans the
expanded kernel and ramdisk for the original device identity and host paths.
Physical UI, touch, haptics and ADB still require a separately authorized,
watchdog-protected RAM boot from the Recovery container; never flash this FIT.

### Build notes

These tree-integration choices are why the scripts look the way they do:

| Issue | Handling |
|---|---|
| `build/envsetup.sh` aborts under `set -u` (`TOP: unbound variable`) | `build-twrp.sh` runs with `set -eo pipefail` |
| A symlinked `device/xiaomi/crux` is not found by the AOSP product scan | `setup-twrp.sh` exports the committed leaf instead |
| `TARGET_COPY_OUT_VENDOR must be set to 'vendor'` | `BoardConfig.mk` sets `TARGET_COPY_OUT_VENDOR := vendor` |
| `$(LOCAL_PATH)` in late-expanded variables resolves to `/` | use literal `device/xiaomi/crux/...` paths |
| AOSP binutils cannot link the AArch64 kernel | the kernel uses Prelude's LLVM tools (`LLVM=1`, `ld.lld`, `llvm-*`); see [KERNEL.md](docs/KERNEL.md#toolchain) |

## GitHub Actions builds and releases

Run **Actions → TWRP Recovery for crux → Run workflow** on `main`. With an
empty `release_tag`, it uploads only the checked workflow artifact. A supplied
tag or a `twrp-crux-*` tag push also publishes a GitHub Release. Dispatch and
push require owner authorization.

The workflow builds the PE Cepheus Crux kernel and recovery from source on
Ubuntu 22.04, using the same pinned Prelude Clang 16.0.2 revision as the
verified local build. It includes the corrected live DT and the optional
80px top display inset. Release assets contain the Android recovery image,
U-Boot FIT, gzip ramdisk, resolved source manifest, build metadata, SHA-256
checksums and a watchdog-protected command for the historical cache layout
(not the current boot or install path). Only releases receive signed GitHub
build provenance. Raw build logs are not uploaded as artifacts.
The TWRP version credits `coachpo`; full GitHub/source URLs are embedded in
`/system/etc/crux-release.txt` and included in `CREDITS.txt`. See
[`docs/CI-RELEASE.md`](docs/CI-RELEASE.md) and
[`official practice comparison`](docs/OFFICIAL-PRACTICES.md).

The workflow packages TWRP; device cache integration and hardware flashing
remain separate operations. A newly compiled release is not automatically
hardware-tested.

## Why twrp-12.1 and not a newer branch

As of 2026-10-02, the official TeamWin release page lists TWRP 3.7.1
([released 2024-02-21](https://twrp.me/site/update/2024/02/21/3.7.1-released.html)). This checkout uses its `twrp-12.1` build branch:

- TWRP 3.7.1's Android 12.1 release line is version `3.7.1_12` and targets
  Android 12.1 and up, covering the PE13 (Android 13) userdata layout.
- `android-13`, `android-14` and `android-14.1` exist in the TWRP repository
  but have **no official release** (`android-14.1` still identifies as
  `3.7.1_14`). They are a later, separate evaluation.
- Linux 4.14 is **not** a documented TWRP ceiling. The Cepheus
  baseline's [kernel capabilities](docs/KERNEL.md#verified-kernel-capabilities-for-twrp)
  include Binder, encryption/ICE, UFS, DRM, USB and touch support; EROFS is
  disabled, and the device mounts system as ext4.
  The one deliberate difference is that TWRP 12.1's vold still falls back to
  the session keyring for v1 fscrypt policies, while 14.1 removed that
  fallback — relevant only if `twrp-14.1` is evaluated later.

## Provenance of the included blobs

`recovery/root/` contains the stock crux TEE/recovery userspace needed for
decryption and haptics (`qseecomd`, keymaster 4.0, gatekeeper 1.0, vibrator,
their `lib64` dependencies and firmware). They come from the device's stock
firmware via the community crux TWRP device tree (TWRP A12.1). See `NOTICE`.
They stay in this repository rather than being taken from `vendor_xiaomi_crux`:
that repository's blobs come from another firmware line (PixelExperience-Blobs
and V10.4.6.0), and `qseecomd` and the gatekeeper service differ from these; TWRP
decryption is only known to work with this set.

The kernel is **not** committed; it is built from
`coachpo/kernel_xiaomi_crux` (the PE13 Cepheus baseline line).

## Licence

Original content: Apache-2.0. Bundled stock binaries: see `NOTICE`.
