# Crux TWRP source tree

## Scope and current status

- This checkout owns the Crux TWRP 12.1 device-tree adaptation and its build/FIT scripts. Start with [`README.md`](README.md), then use [`docs/STATUS.md`](docs/STATUS.md), [`docs/KERNEL.md`](docs/KERNEL.md), [`docs/UBOOT.md`](docs/UBOOT.md) and [`docs/DEVICE-TEST.md`](docs/DEVICE-TEST.md) for their separate topics.
- The current TWRP artifact is the [2026-10-05 GitHub Release](docs/RELEASE-DEPLOYMENT-2026-10-05.md): PE Cepheus 4.14.305, TWRP 3.7.1, deployed cache readback and timed haptics verified. The workspace's new U-Boot menu reads `0x2924` blocks and its TWRP recheck reached ADB in 9.69 seconds with eight CPUs; see the [development baseline](../docs/pe13-development-baseline-2026-10-05.md). Keep the [2026-10-04 DT result](docs/BUILD-RESULTS-2026-10-04-DT.md) as the first corrected-DT startup evidence. Basic touch and vibration were accepted on the local RAM fix; final physical UI feedback for the installed Release and broader touch/keys, MTP, recovery operations and userdata decryption remain unverified. TWRP results do not establish PE ROM behavior.
- `manifests/crux-twrp.xml` follows the moving `thirteen` kernel branch and records an expected commit. `scripts/build-twrp.sh` warns on a different kernel commit but continues; it does not check for working-tree changes. Record those changes with each build, and do not call the manifest SHA-pinned or assume the warning enforces it.
- Check this checkout's Git status before editing or syncing. Preserve existing local changes and record source revision changes in the manifest and the related README/kernel status notes.

## Build and integration boundary

- Use `scripts/setup-twrp.sh`, `scripts/build-twrp.sh` and `scripts/make-fit.sh` for the documented host workflow. The build needs an x86_64 Linux userspace; the 2026-10-02 host build and its outputs are recorded in `docs/BUILD-RESULTS-2026-10-02.md`.
- This checkout produces a recovery image/FIT and the corresponding `boot_twrp` command line. U-Boot code and cache-payload ownership stays in `u-boot-port/`; do not edit its environment, write a cache image or operate the phone from this checkout. Hand off the FIT path, SHA-256, block count and generated single-line command for integration.
- `.github/workflows/twrp-release.yml` builds and publishes on manual dispatch or `twrp-crux-*` tag pushes. `scripts/setup-twrp.sh` fetches the pinned Prelude compiler and copies this repository's leaf device directory into the AOSP tree; `scripts/build-twrp.sh` applies `patches/kernel/` before building. `scripts/package-release.py` verifies FIT component readbacks, DT compatibility, slot size and source/compiler metadata. Validate workflow syntax and exercise packaging with real build outputs after changing release logic; a published CI build is not a new hardware test.
- Keep each U-Boot environment value on one physical line. The macOS build path does not reliably join backslash continuations; see the current U-Boot handoff for the verified constraint.

## Device tests

- U-Boot is the bootloader for every Recovery and ROM in this development baseline. Hand off the watchdog recovery requirement with every debug FIT: the U-Boot integration owner must follow [`the workspace watchdog guide`](../u-boot-port/notes/KERNEL-DEBUG-WATCHDOG.md) before kernel entry, including diagnostic bootargs where unattended recovery is required. A generated command ending in bare `bootm go` does not establish that protection. This requirement does not authorize phone/cache writes or move device-operation ownership into this checkout.
- `docs/DEVICE-TEST.md` contains both read-only checks and storage-changing operations. Separate them. Obtaining a new FIT on device may require an explicitly authorized cache write; wiping/formating `/data` or flashing partitions requires explicit authorization for that operation and a verified target/image.
- Record the artifact, source revision, boot arguments and observed result. A successful build or FIT packaging step is not evidence of a successful device boot.
