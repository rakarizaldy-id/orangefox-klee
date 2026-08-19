# Step 3 — Minimal klee build skeleton

This is the first independent source-tree skeleton for POCO X8 Pro (`klee`).

## Included
- AndroidProducts.mk
- twrp_klee.mk
- device.mk
- BoardConfig.mk
- vendorsetup.sh

## Already encoded
- arm64 / mt6899
- A/B + native Virtual A/B
- dynamic partitions
- boot 64 MiB
- vendor_boot 64 MiB
- dtbo 8 MiB
- super 12 GiB
- vendor_boot header v4
- 4096 page size
- LZ4 ramdisk
- standalone RECOVERY fragment inside vendor_boot
- Build60 cmdline
- FBE + metadata support
- maintainer identity

## Not guessed yet
- CPU tuning
- super group layout
- DTB source/prebuilt path
- kernel/modules
- display/brightness
- USB details
- proprietary blobs
- fstab/root overlays
- source patches

This is not build-ready yet.
