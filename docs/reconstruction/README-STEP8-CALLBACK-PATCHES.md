# Step 8 — Reproducible OrangeFox ramdisk patch layer

Step 8 converts the Build60 GUI/CLI modifications into a build-time, fail-closed callback layer.

## Why callback instead of copying full upstream binaries

OrangeFox `fox_12.1` supports `FOX_LOCAL_CALLBACK_SCRIPT`. On its first invocation, OrangeFox passes
the recovery ramdisk path immediately before building the recovery image. This lets the device tree
apply small Klee-specific deltas to the generated ramdisk while leaving upstream binaries and most
upstream UI resources source-built.

## Added

```text
patches/
├── orangefox/
│   ├── apply-klee-ramdisk.py
│   └── fragments/
│       ├── advanced-klee-entry.xml
│       ├── advanced-klee-page.xml
│       ├── wipe-list-slider.xml
│       ├── wipe-formatdata-confirm.xml
│       ├── wipe-action-page.xml
│       └── customization-apply-splash.xml
└── twrp/
    └── twrp-wrapper.sh

tools/
└── fox-callback.sh
```

`vendorsetup.sh` now exports:

```text
FOX_LOCAL_CALLBACK_SCRIPT=device/xiaomi/klee/tools/fox-callback.sh
```

## Callback first-call behavior

1. Patch `twres/pages/advanced.xml`
   - Add Klee Tools entry.
   - Add Self-Test.
   - Add Storage / Partition Health.
   - Add Clear OrangeFox Logs.
   - Add Fenrir Install / Repair.

2. Patch `twres/pages/wipe.xml`
   - Advanced Wipe: PRE -> WIPE -> POSTLIST in one worker.
   - Format Data: PRE -> DATAMEDIA -> POSTDATAMEDIA in one worker.
   - Preserve queue-done/tw_busy completion gates.
   - Reset queue latch before every wipe action page entry.

3. Patch `twres/pages/customization.xml`
   - Replace only the `apply_splash` page with the validated `klee_splash_apply.sh` backend for
     vendor_boot header v4.

4. Patch TWRP CLI layout
   - Preserve the source-built `/system/bin/twrp` ELF as `/system/bin/twrp.real`.
   - Install the Build60 transparent shell wrapper at `/system/bin/twrp`.
   - The wrapper only intercepts destructive CLI forms that need `klee-wipe-prep`.

## Fail-closed behavior

The patcher aborts when:
- expected XML pages/anchors are missing or duplicated;
- final markers appear with wrong counts;
- XML becomes invalid;
- generated `/system/bin/twrp` is not an ELF;
- `twrp.real` state is inconsistent.

This is intentional. An upstream OrangeFox UI change should break the build loudly instead of silently
producing a recovery with incomplete wipe/Fenrir behavior.

## What Step 8 does NOT solve yet

- native `[Branch] : klee` source patch — **resolved in Step16**;
- compiled `foxs-merge`;
- OMAPI bridge source;
- AW86927 compiled helper source;
- Xiaomi/NXP proprietary HALs/blobs;
- touch_report and touch modules extraction;
- DTB/platform vendor ramdisk provenance;
- Fenrir boot-chain asset redistribution/extraction.

Those remain separate reconstruction steps.
