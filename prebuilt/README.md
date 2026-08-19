# Generated device hardware inputs

This directory intentionally does **not** contain Xiaomi/MediaTek binary payloads.

Run:

```bash
python3 device/xiaomi/klee/tools/prepare-klee-stock-inputs.py \
    --vendor-boot /path/to/vendor_boot.img \
    --dtbo /path/to/dtbo.img \
    --device-dir device/xiaomi/klee
```

The tool creates local, ignored files under `prebuilt/generated/`:

```text
platform-vendor-ramdisk.cpio.lz4
mt6899-klee.dtb
dtbo.img
stock-input-report.txt
```

The PLATFORM ramdisk is taken from the supplied stock `vendor_boot`, then only
`first_stage_ramdisk/fstab.mt6899` is replaced with the source-owned recovery
fstab before recompression.

This keeps the public tree free of hundreds of stock kernel modules while
making the project-specific first-stage fstab change reproducible.
