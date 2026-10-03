# Build results — 2026-10-03 (second rebuild, PE13 kernel fixes)

Rebuild of the Crux TWRP 3.7.1 recovery with the kernel at the rewritten
`thirteen-plus` tip, which now includes the PE13 bring-up fixes (KGSL GMU
lookup, IPA probe defer, BPF 18-argument support, ftrace/BPF config, real
uname, PCIe MSI cells).

## Build inputs

| Item | Value |
|---|---|
| TWRP tree | `~/twrp-12.1` in the VM |
| Kernel | `kernel/xiaomi/crux` @ `50443f853589625100431e994f675f1b7087edec` (branch tip after the 2026-10-03 history cleanup) |
| Command | `USE_CCACHE=1 CCACHE_EXEC=/usr/bin/ccache scripts/build-twrp.sh ~/twrp-12.1` |
| Toolchain | same as before: `clang-r416183b1`, kernel linked with `ld.lld` + LLVM binutils |

`build-twrp.sh` printed the expected mismatch warning (`expected c5afe30…`,
actual `50443f85…`) and continued; the expected revision is updated together
with this record.

## Build outputs

| Artifact | Size (bytes) | SHA-256 |
|---|---|---|
| `recovery.img` | 134,217,728 | `0de8554b4540ed23e07d6fa8869ca56d195706f51b8e86923e1bd855c642fe2d` |
| `ramdisk-recovery.img` | 24,518,712 | `d1a0e7cb24ffece28bc31f3698a4f395f7ce2a9544f55ecec53c141421f7a615` |
| `kernel` (`Image-dtb`) | 50,482,608 | `baa72089798c22bbe83dc28166c1311c5cd9924fb67ee317e0d2684751e8b864` |
| `Image` (raw arm64) | 48,484,368 | `5788925a6c7c365233b9b7f54e0b112cda358fe774c78539be51780521994e2e` |
| `twrp-crux.itb` | 44,462,716 | `12c7c9857e506c3f5b0426a3b00b1ccf45b8bee8986a35cbf732d72fa6db4112` |

- Kernel banner build time: `#3 SMP PREEMPT Sat Oct 3 11:26:48 CST 2026`.
- The ramdisk is byte-identical to the first 2026-10-03 rebuild.

## U-Boot FIT

`scripts/make-fit.sh --out-dir .../out/target/product/crux --mkimage /usr/bin/mkimage`:

| Item | Value |
|---|---|
| FIT size | 44,462,716 B (`0x2a6727c`) |
| UFS blocks (4096 B) | `0x2a68` |
| Slot | 64 MiB TWRP cache slot; 22,115 KiB free |

Updated menu command for `board/qualcomm/xiaomi-crux.env` (the U-Boot session
owns that file; the block count changed from `0x2a5c`):

```text
boot_twrp=scsi dev 0; scsi read 0xC0000000 0x34000 0x2a68; setenv fdt_high 0x84900000; setenv initrd_high 0x84200000; bootm start 0xC0000000; bootm loados; bootm ramdisk; bootm prep; bootm go
```

## Not yet verified

- Nothing has been flashed or booted on hardware; the `DEVICE-TEST.md` plan is
  still pending.
- The U-Boot menu environment and cache payload still contain the legacy TWRP
  3.3.1 FIT until the integration session updates them.
