# Crux TWRP source tree

## Scope and current status

- This checkout owns the Crux TWRP 12.1 device-tree adaptation and its build/FIT scripts. Start with [`README.md`](README.md), then use [`docs/STATUS.md`](docs/STATUS.md), [`docs/KERNEL.md`](docs/KERNEL.md), [`docs/UBOOT.md`](docs/UBOOT.md) and [`docs/DEVICE-TEST.md`](docs/DEVICE-TEST.md) for their separate topics.
- Use the [retained TWRP record](../docs/pe13-retained-components-2026-11-05.md#twrp-recovery) and [October 5 deployment record](docs/RELEASE-DEPLOYMENT-2026-10-05.md) for the Dev OTA default FIT, its CI source/kernel, symbol limits, menu boot, haptics and cache readback. Do not substitute a new local build or infer the current phone state from those records. Basic touch and vibration were verified on a separate RAM fix; final installed UI feedback, broader touch/keys, MTP, decryption and backup/restore remain unverified. TWRP does not certify PE Recovery or ROM.
- `manifests/crux-twrp.xml` follows the moving `thirteen` kernel branch and records an expected commit. `scripts/build-twrp.sh` warns on a different kernel commit but continues; it does not check for working-tree changes. Record those changes with each build, and do not call the manifest SHA-pinned or assume the warning enforces it.
- Check this checkout's Git status before editing or syncing. Preserve existing local changes and record source revision changes in the manifest and the related README/kernel status notes.

## Build and integration boundary

- Use `scripts/setup-twrp.sh`, `scripts/build-twrp.sh` and `scripts/make-fit.sh` for the documented host workflow. The build needs an x86_64 Linux userspace; the 2026-10-02 host build and its outputs are recorded in `docs/BUILD-RESULTS-2026-10-02.md`.
- This checkout produces a recovery image/FIT and the corresponding `boot_twrp` command line. U-Boot code and cache-payload ownership stays in `u-boot-port/`; do not edit its environment, write a cache image or operate the phone from this checkout. Hand off the FIT path, SHA-256, block count and generated single-line command for integration.
- `.github/workflows/twrp-release.yml` builds and publishes on manual dispatch or `twrp-crux-*` tag pushes; do not trigger either without release authorization. `scripts/setup-twrp.sh` fetches the pinned Prelude compiler and copies this repository's leaf device directory into the AOSP tree; `scripts/build-twrp.sh` applies `patches/kernel/` before building. `scripts/package-release.py` verifies FIT component readbacks, DT compatibility, slot size and source/compiler metadata. Validate workflow syntax and exercise packaging with real build outputs after changing release logic; a published CI build is not a new hardware test.

## Device tests

- `make-fit.sh` and `package-release.py` emit a single-line command ending in `run boot_go`. The U-Boot integration owner must verify the deployed guard and follow the [workspace watchdog procedure](../u-boot-port/notes/KERNEL-DEBUG-WATCHDOG.md), including diagnostic bootargs where unattended recovery is required. Do not reuse historical bare `bootm go` commands as debug launchers.
- [Device tests](docs/DEVICE-TEST.md) include storage-changing operations; separate them from read-only checks. The Dev cache region is raw FIT storage: do not format it to resolve a mount error. Cache writes, wipes, formatting and flashes require separate authorization for the verified target and payload.
- Record the artifact, source revision, boot arguments and observed result. A successful build or FIT packaging step is not evidence of a successful device boot.
