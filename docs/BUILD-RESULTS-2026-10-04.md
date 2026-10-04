# Build results — 2026-10-04 (Cepheus 4.14.305 baseline)

Historical first-build/integration record. The failure and open items below
are observations from that run, not current status. The later e45a24 Image
boots TWRP with two DT compatibility repairs; current inputs, successful
RAM boot and pending persistent deployment are recorded in
[`BUILD-RESULTS-2026-10-04-DT.md`](BUILD-RESULTS-2026-10-04-DT.md).

Rebuild of the Crux TWRP 3.7.1 recovery with the migrated PE Cepheus kernel
baseline (`crux-pe13-cepheus` @ `b38f5a5c8cac`, Linux 4.14.305), the Prelude
clang 16 toolchain, and the device integration of the resulting FIT.

## Build inputs

| Item | Value |
|---|---|
| TWRP tree | `~/twrp-12.1` in the `cruxbuild` VM |
| Kernel | `kernel/xiaomi/crux` @ `b38f5a5c8cacddaa2e547c466876d22528e1c7e5` (branch tip: PE official Cepheus `f4048f154b51`, 15 migration commits, UFS first-Hibern8 trace) |
| Kernel source in the VM | `~/crux-kernel-cepheus`, fetched into the TWRP kernel checkout over `file://` (the branch is not yet published on GitHub) |
| Command | `USE_CCACHE=1 CCACHE_EXEC=/usr/bin/ccache scripts/build-twrp.sh ~/twrp-12.1` |
| Toolchain | Prelude clang 16.0.2 (LLVM 16), `LLVM=1 LLVM_IAS=1`; `LD`/`LD_COMPAT`/`AR`/`NM`/`OBJCOPY`/`OBJDUMP`/`STRIP` from the same prelude; TWRP's `kernel.mk` still passes `CROSS_COMPILE_ARM32` and hardcodes `HOSTCC`/`HOSTCXX` to the tree's clang 12 for host utilities |
| Toolchain setup | `prebuilts/clang/host/linux-x86/clang-prelude` in the TWRP tree is a symlink to `~/crux-pe13-offline-2026-09-25/pe13/prebuilts/clang/host/linux-x86/clang-prelude` (2.4 GB, not vendored) |
| Fixes needed | `LD_COMPAT` must be passed explicitly: the Cepheus `arch/arm64/kernel/vdso32/Makefile` only falls back to `$(LD)` when the make variable `LLVM` is set, otherwise it runs a host `ld` that does not exist (`VDSOL32 ... /bin/sh: 1: ld: not found`) |

Build completed in 10:48 (mm:ss).

## Build outputs

| Artifact | Size (bytes) | SHA-256 |
|---|---|---|
| `recovery.img` | 134,217,728 | `c5aaae6e1cd2d4697b7d1c508b11c67d3bb4f9fe77afe4d87a7289851b3e8608` |
| `ramdisk-recovery.img` | 24,518,712 | `d1a0e7cb24ffece28bc31f3698a4f395f7ce2a9544f55ecec53c141421f7a615` (unchanged) |
| `kernel` (`Image-dtb`) | 45,773,752 | `19a704bbcec0cbd18cd3c53a699af3fcd8740f80bec19e3112a0e423514b4a02` |
| `Image` (raw arm64) | 43,776,016 | `bdf84b081de7fcf5a317d9e5c48d6e3f6fe5da6dea67d24cc7273b3d5600b371` |
| `twrp-crux.itb` | 43,204,672 (`0x2934040`) | `2a0a2c7f1974e0db24d08cf3eaf2ccf9bcc51bd277984c0f69052a6d3c7e5817` |

- Kernel banner (`uname -r`): `4.14.305-Crux-PE-gb38f5a5c8cac`.
- ARM64 header `image_size`: `0x3287000` (kernel ends at `0x83307000`).
- Built `.config`: `CONFIG_PSTORE{,_CONSOLE,_PMSG,_RAM}=y`, `CONFIG_COMPAT_VDSO=y`,
  `CONFIG_DRM_MSM=y`, `CONFIG_TOUCHSCREEN_ST_FTS_V521=y`; `CONFIG_EROFS_FS` and
  `CONFIG_RD_LZMA` are not set in this baseline.
- The TWRP ramdisk is byte-identical to the 2026-10-03 builds.

## U-Boot FIT

`scripts/make-fit.sh --out-dir .../out/target/product/crux --mkimage /usr/bin/mkimage`:

| Item | Value |
|---|---|
| FIT size | 43,204,672 B |
| UFS blocks (4096 B) | `0x2935` |
| Free space in the 64 MiB TWRP cache slot | ~23,343 KiB |
| Kernel component | gzip 18,024,057 B, sha256 `1fc39301…` |
| FDT component | live ABL DT, 659,861 B, sha256 `9744b16db18c12e8b084c5a30c3c70e94263c7ddbd20613736b9a299c442f03d` |
| Ramdisk component | 24,518,712 B, sha256 `d1a0e7cb…` |

The menu command now lives in `board/qualcomm/xiaomi-crux.env` and must leave
`fdt_high`/`initrd_high` unset: the Cepheus kernel reserves `image_size`
`0x3287000` and the 24.5 MiB ramdisk does not fit below the old low
`initrd_high=0x84200000` (`ramdisk - allocation error`).

```text
boot_twrp=scsi dev 0; scsi read 0xC0000000 0x34000 0x2935; setenv fdt_high; setenv initrd_high; bootm start 0xC0000000; bootm loados; bootm ramdisk; bootm prep; bootm go
```

## Device integration (2026-10-04)

| Item | Value |
|---|---|
| U-Boot boot image | `ub-crux-twrp-cepheus.img`, 688,128 B, SHA-256 `55478566438a12786c6376cffa2736de660dd00270998f6aa4917ba83101c64d` |
| U-Boot version after flash | `U-Boot 2026.10-rc5-00613-g61f62025d6ca-dirty (Oct 04 2026 - 08:48:44 +0800)` |
| Flash method | U-Boot shell XMODEM (`flash-boot-via-loadx.py`) → UFS LUN4 LBA `0x14000`, 168 blocks; CRC32 `0x7528c8d0` verified after write and after read-back (U-Boot fastboot cannot flash UFS: `Writing 'boot' FAILED (remote: 'invalid partition or device')`) |
| Cache slot | TWRP FIT written at LBA `0x34000` (64 MiB into `cache`, `/dev/block/sda29`), full read-back SHA-256 verified |
| PE recovery slot | FIT re-written at LBA `0x38000` after an accidental overwrite, read-back SHA-256 `0c5ae76d…` matches the deployed candidate; MIUI slot (`0x30000`) and PE ROM slot (`0x3c000`) untouched |
| Manual load check | `bootm start/loados/ramdisk/prep` (no `go`): kernel → `0x80080000`, ramdisk → `0x2611c3000`, FDT → `0xbba5b000`, component hashes OK |
| Boot result | **`run boot_twrp` / menu entry 3 reaches `Starting kernel ...` and does not come up: the USB port never re-enumerates and no ADB after 180 s** |

The boot result is identical to the new-baseline PE recovery candidate
(`recovery-cepheus.itb`, C01/C02) and to the same test with the old recovery
DT. The new kernel therefore hangs in early boot before USB/userspace in every
tested configuration; TWRP cannot work on device until that kernel issue is
fixed. The old 13-plus TWRP builds were not the blocker: this FIT differs from
the last 2026-10-03 build only in the kernel baseline and toolchain.

## Rollback material

- The proven TWRP 3.3.1 slot content was backed up before being overwritten:
  `legacy-twrp-3.3.1-slot.bin` (first 55,074,316 bytes match
  `out/crux-bootmenu-2026-10-02/twrp-menu.itb`, SHA-256 `5a300a03…`).
- The pre-existing MIUI + TWRP 3.3.1 payload remains at
  `out/crux-bootmenu-2026-10-02/cache-payload.img` and can be re-flashed to
  `cache` from ABL fastboot (`fastboot flash cache …`).
- To restore the old kernel for TWRP, check out `thirteen-plus`
  (`50443f853589`) in `kernel/xiaomi/crux` and rebuild; the previous build
  record is `BUILD-RESULTS-2026-10-03B.md`.

## Open items

1. The Cepheus-baseline kernel does not reach userspace on this device; the
   early-boot bisection belongs to the device session's records
   (`out/crux-kernel-cepheus-earlyboot-2026-10-03/`, `HANDOFF-PE13-2026-10-03E.md`).
2. Once the kernel boots, re-run the device plan in `DEVICE-TEST.md`
   (display/touch, `/data` decryption, USB, haptics).
3. The `crux-pe13-cepheus` branch is still local to the VM/migration bundle; it
   is not published on `coachpo/kernel_xiaomi_crux`.
