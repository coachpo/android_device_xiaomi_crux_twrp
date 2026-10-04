# TeamWin build and release practices

The current build follows TeamWin's recommended Android 12.1 minimal manifest,
`repo` synchronization, `lunch twrp_crux-eng` and `mka recoveryimage` target.
These are documented in the [official compiling FAQ](https://twrp.me/faq/howtocompiletwrp.html)
and its [linked minimal-manifest instructions](https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp/tree/twrp-12.1).
Crux has a separate recovery partition; the source build therefore produces
an Android recovery image. This project also packages a FIT for its verified
U-Boot chainload route.

Practices used in this repository:

- Standard upstream source/build targets, with the PE Crux kernel/compiler
  inputs recorded rather than substituting another kernel baseline.
- Original upstream attribution preserved; the Crux maintainer is identified
  by the native `TW_DEVICE_VERSION` suffix and embedded project credits.
- Checksums and source/compiler records accompany each build. New binaries
  are distinguished from earlier hardware evidence.
- GitHub signs build provenance for published assets using the repository's
  workflow identity; users can verify it with `gh attestation verify`.

TeamWin's download service offers checksum verification and official
[OpenPGP signatures](https://twrp.me/faq/pgpkeys.html) using TeamWin's private
key. This repository uses SHA-256 plus [GitHub artifact attestations](https://github.com/actions/attest)
for its own releases. It does not label these as TeamWin-signed official images.

## Official inclusion

The [maintainer guide](https://twrp.me/faq/OfficialMaintainer.html) asks for a
GitHub device tree, working-device validation and coordination with TeamWin.
Their team can fork accepted trees and add them to Gerrit/Jenkins and the
`twrp.me` distribution path. Creating this GitHub workflow does not enroll a
device in that service.

Before applying, the blocking validation still needs actual touch/display,
backup/restore and reboot-to-system coverage; ADB and recovery startup already
have evidence. Decryption, MTP and other functions need their own results.
No storage-changing tests or TeamWin contact are performed by this CI task.

The current repository contains scripts/docs above the device leaf. For an
official tree handoff, prepare the flat `device/xiaomi/crux` tree plus matching
kernel/compiler dependencies and the board DT correction; confirm the U-Boot
boot route and supported installation path with TeamWin. That is a separate
submission step after functional validation, not an automatic Release hook.
