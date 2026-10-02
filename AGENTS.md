# Crux TWRP source tree

## Scope and current status

- This checkout owns the Crux TWRP 12.1 device-tree adaptation and its build/FIT scripts. Start with [`README.md`](README.md), then use [`docs/STATUS.md`](docs/STATUS.md), [`docs/KERNEL.md`](docs/KERNEL.md), [`docs/UBOOT.md`](docs/UBOOT.md) and [`docs/DEVICE-TEST.md`](docs/DEVICE-TEST.md) for their separate topics.
- The new TWRP 3.7.1 adaptation was host-built on 2026-10-02 (`docs/BUILD-RESULTS-2026-10-02.md`) but has not been booted on device. The last device-verified TWRP is the older 3.3.1 image loaded from cache; current device and U-Boot state belongs to [`../u-boot-port/notes/HANDOFF-NEXT-2026-10-02.md`](../u-boot-port/notes/HANDOFF-NEXT-2026-10-02.md). Do not describe the new source tree as device-verified.
- `manifests/crux-twrp.xml` follows the moving `thirteen-plus` kernel branch and records an expected commit. `scripts/build-twrp.sh` warns on a different kernel commit but continues; do not call the manifest SHA-pinned or assume the warning enforces it.
- Check this checkout's Git status before editing or syncing. Preserve existing local changes and record source revision changes in the manifest and the related README/kernel status notes.

## Build and integration boundary

- Use `scripts/setup-twrp.sh`, `scripts/build-twrp.sh` and `scripts/make-fit.sh` for the documented host workflow. The build needs an x86_64 Linux userspace; the 2026-10-02 host build and its outputs are recorded in `docs/BUILD-RESULTS-2026-10-02.md`.
- This checkout produces a recovery image/FIT and the corresponding `boot_twrp` command line. U-Boot code and cache-payload ownership stays in `u-boot-port/`; do not edit its environment, write a cache image or operate the phone from this checkout. Hand off the FIT path, SHA-256, block count and generated single-line command for integration.
- Keep each U-Boot environment value on one physical line. The macOS build path does not reliably join backslash continuations; see the current U-Boot handoff for the verified constraint.

## Device tests

- `docs/DEVICE-TEST.md` contains both read-only checks and storage-changing operations. Separate them. Obtaining a new FIT on device may require an explicitly authorized cache write; wiping/formating `/data` or flashing partitions requires explicit authorization for that operation and a verified target/image.
- Record the artifact, source revision, boot arguments and observed result. A successful build or FIT packaging step is not evidence of a successful device boot.
