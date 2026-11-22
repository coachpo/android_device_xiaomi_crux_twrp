# GitHub Actions: build and release

The `TWRP Recovery for crux` workflow builds TWRP 3.7.1_12 for the Xiaomi Mi 9
Pro 5G from source. It uploads verified workflow artifacts and publishes a
GitHub Release only when requested by a tag.

## Trigger a build

In this repository, open **Actions → TWRP Recovery for crux → Run workflow**.
Choose `main`. An empty `release_tag` uploads only the artifact; a supplied tag must be a valid
Git tag. An existing tag without a Release is accepted only if it points to
the exact triggering commit. Existing releases are rejected before the expensive build starts.
Pushing a tag matching `twrp-crux-*` also runs the workflow against that tag.
No regular branch push automatically starts this full build.

The workflow uses the repository's automatic `GITHUB_TOKEN` with
`contents: write` for Releases and `id-token`/`attestations: write` for signed
build provenance; no personal token or long-lived signing-key secret is required. It creates a draft,
uploads assets and publishes it only after source build and package checks
pass. If an upload fails, the draft remains unpublished for inspection; retry with a
fresh tag, or remove that failed draft before explicitly reusing its tag.

## Build inputs

- Ubuntu 22.04 x86_64 hosted runner, matching the verified local build OS.
- Short source path `/mnt/twrp` on both hosts: the legacy QCACLD compiler command repeats
  absolute include paths, so the default long GitHub workspace path can
  exceed Linux's single-command argument limit.
- The 251 exact project pins in `manifests/crux-twrp.xml` from the same
  commit as the scripts. Both build paths check the tree before compiling.
- Device files from the exact triggering checkout, copied from this
  repository's `device/xiaomi/crux` leaf directory.
- `coachpo/kernel_xiaomi_crux` at the manifest pin (the PE13 source lock's
  kernel commit); the build refuses another checkout.
- Prelude Clang 16.0.2 from `jjpprrrr/prelude-clang` on GitLab, pinned to
  `ac8fce34dc0f6918672100d7a6e867a66b8afa8f`.
- The board USB1 extcon correction is part of the pinned kernel; the captured
  live DT already carries the UFS ICE resource and USB1 extcon corrections.
- Built-in portrait theme with the 80px top content inset. The optional inset
  changes recovery UI; it does not change kernel display timing.

The local tree uses about 26 GiB of source, 10 GiB of repo metadata and 13 GiB
of output, plus the external compiler. The workflow frees unused preinstalled
Android/.NET stacks on its fresh hosted runner, prints available space and
uses its existing CPU count for compilation. Both build paths disable
ccache, use `crux@build` and derive Android and kernel timestamps from the
commit in UTC. The FIT uses Ubuntu's `mkimage` and `gzip -n`; the standalone
image uses a fixed salt with the Android AVB test key. The source tree and
outputs are not cached across CI runs. Logs are not uploaded as artifacts.

## Release assets

| Asset | Purpose |
|---|---|
| `twrp-crux-3.7.1_12.itb` | Kernel, corrected live DT and recovery ramdisk for a RAM boot via the Recovery container |
| `twrp-crux-3.7.1_12-recovery.img` | Android recovery-image build output |
| `ramdisk-recovery.img` | gzip recovery initramfs |
| `BOOT-TWRP.txt` | Exact legacy cache read length and guarded command (not a current menu entry) |
| `source-manifest.xml` | The exact TWRP/kernel/compiler source lock |
| `BUILD-INFO.json` | Source/patch/compiler/config/component hashes and layout settings |
| `SHA256SUMS` | Checksums for all release assets |
| `RELEASE-NOTES.md` | Artifact roles and validation scope |
| `CREDITS.txt` | Maintainer GitHub, repository URLs and upstream credits (also embedded in recovery) |

`package-release.py` checks the arm64/Android image headers, gzip support,
required live DT properties and absence of diagnostic bootargs. It extracts
all three FIT components using `dumpimage`, compares them with their build
inputs and rejects a FIT larger than the 64 MiB TWRP slot. It verifies the
applied board configuration, records the selected compiler and Soong inset
values, and scans the expanded FIT inputs and packaged files before upload.

The published files are TWRP artifacts, not a complete multi-entry cache
payload. Use the FIT through the documented U-Boot integration path; the
Android recovery image is not the verified direct-ABL boot route. Device
writes remain separate and require the operation's explicit authorization.
The workflow does not flash a phone. Earlier hardware evidence establishes
the baseline startup scope; each new CI binary remains a new build until
separately tested on hardware.

## Local verification

```sh
bash -n scripts/*.sh
# actionlint checks GitHub expression contexts and workflow syntax:
actionlint .github/workflows/twrp-release.yml
# Package a completed source build with the actual inputs and metadata:
python3 scripts/check-source-lock.py /mnt/twrp
scripts/package-release.py --tree /mnt/twrp --out out/release-check
(cd out/release-check && sha256sum --check SHA256SUMS)
```

The packaging check needs `mkimage`, `dumpimage`, `fdtget`, Python 3,
and the recorded build/compiler trees. It runs on the build Linux host.

## Attribution and verification

The homepage version suffix includes `coachpo`. Full project credits are
embedded at `/system/etc/crux-release.txt`; view them from TWRP's Advanced →
Terminal with `cat /system/etc/crux-release.txt`, or read the Release's
`CREDITS.txt`. The package check requires the exact credits file and maintainer
version string in the built initramfs.

After downloading the FIT, check `SHA256SUMS` and verify the workflow's signed
provenance:

```sh
gh attestation verify twrp-crux-3.7.1_12.itb \
  --repo coachpo/android_device_xiaomi_crux_twrp
```

This identifies this repository's GitHub build. It is separate from TeamWin's
OpenPGP signatures. See [OFFICIAL-PRACTICES.md](OFFICIAL-PRACTICES.md) for the
upstream build and official inclusion process.
