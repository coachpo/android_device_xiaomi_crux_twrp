# Build results — 2026-10-03

Rebuild of the Crux TWRP 3.7.1 recovery on the OrbStack `cruxbuild` VM after
the kernel was synced to the `thirteen-plus` branch tip (pstore enabled).

## Build inputs

| Item | Value |
|---|---|
| TWRP tree | `~/twrp-12.1` in the VM |
| Kernel | `kernel/xiaomi/crux` @ `c5afe30f211bec03f1a9d10f90eac4a57e792818` (branch tip; pstore config `debb0e0c4e50` on top of `b5ef1109`) |
| Command | `USE_CCACHE=1 CCACHE_EXEC=/usr/bin/ccache scripts/build-twrp.sh ~/twrp-12.1` (`lunch twrp_crux-eng && mka recoveryimage`) |
| Toolchain | same as 2026-10-02: `clang-r416183b1`, kernel linked with `ld.lld` + LLVM binutils |
| `EXPECTED_KERNEL_SHA` at build time | `b5ef11095c53…` — build-twrp.sh printed the expected mismatch warning and continued |

The expected revision is updated to `c5afe30f211b` together with this record.

## Build outputs

| Artifact | Size (bytes) | SHA-256 |
|---|---|---|
| `recovery.img` | 134,217,728 | `9c197727436e4a3af513520e86f2cc58332d4ec7caa88cf0a19b38e378d4835e` |
| `ramdisk-recovery.img` | 24,518,712 | `d1a0e7cb24ffece28bc31f3698a4f395f7ce2a9544f55ecec53c141421f7a615` |
| `kernel` (`Image-dtb`) | 50,441,476 | `6f7cbd4648fa78e026f8bb58b99afb411a50784a3fe3128b9b41c95618d49910` |
| `Image` (raw arm64) | 48,443,408 | `de97d56a8336cc390f78d6a9dada2fc3c9109c2d6b36d4f460659f18dcbb0df2` |
| `twrp-crux.itb` | 44,413,240 | `5a731a989b804180e24de7baef66abefe6f55fc887bb2269fd51d40761eda450` |

- Kernel banner build time: `#2 SMP PREEMPT Sat Oct 3 05:15:20 CST 2026`.
- The built kernel `.config` (`obj/KERNEL_OBJ/.config`) enables
  `CONFIG_PSTORE{,_CONSOLE,_PMSG,_RAM}=y` and `CONFIG_PSTORE_ZLIB_COMPRESS=y`;
  the hung-task/softlockup diagnostics are not part of the branch.

## U-Boot FIT

`scripts/make-fit.sh --out-dir .../out/target/product/crux --mkimage /usr/bin/mkimage`:

| Item | Value |
|---|---|
| FIT size | 44,413,240 B (`0x2a5b138`) |
| UFS blocks (4096 B) | `0x2a5c` |
| Slot | 64 MiB TWRP cache slot; 22,163 KiB free |

Updated menu command for `board/qualcomm/xiaomi-crux.env` (the U-Boot session
owns that file; the block count changed from `0x2a58`):

```text
boot_twrp=scsi dev 0; scsi read 0xC0000000 0x34000 0x2a5c; setenv fdt_high 0x84900000; setenv initrd_high 0x84200000; bootm start 0xC0000000; bootm loados; bootm ramdisk; bootm prep; bootm go
```

## Not yet verified

- Nothing has been flashed or booted on hardware; the `DEVICE-TEST.md` plan is
  still pending.
- The U-Boot menu environment and cache payload still contain the legacy TWRP
  3.3.1 FIT until the integration session updates them.
