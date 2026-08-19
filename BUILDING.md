# Building the clean klee OrangeFox tree

## Required source base

This reconstruction targets the OrangeFox `fox_12.1` source family used for the
Build60 behavior baseline.

Place this device tree at:

```text
device/xiaomi/klee
```

## One-time non-source inputs

The public device tree intentionally does not contain Xiaomi/MediaTek hardware
payloads. Before the first build, prepare:

1. stock-derived PLATFORM vendor ramdisk + DTB/DTBO;
2. generated `vendor/xiaomi/klee` proprietary repository.

Helper:

```bash
bash device/xiaomi/klee/tools/prepare-klee-build-inputs.sh \
    /path/to/vendor_boot.img \
    /path/to/dtbo.img \
    /path/to/unpacked-stock-root
```

If the proprietary extraction source is not ready yet, omit the third argument;
the helper will prepare only the hardware inputs and the full preflight will
later tell you exactly what is still missing.

## Preflight only

Committed/source-owned tree checks can be run without Android source or stock
blobs:

```bash
python3 device/xiaomi/klee/tools/preflight-klee-build.py \
    --device-dir device/xiaomi/klee \
    --device-only
```

Full preflight from Android source root:

```bash
python3 device/xiaomi/klee/tools/preflight-klee-build.py \
    --source-root "$PWD"
```

The full check requires:

- OrangeFox source structure;
- Step16 core source patches already applied;
- generated stock PLATFORM/DTB/DTBO report with Build60 release gates;
- every entry in `proprietary-files.txt` under `vendor/xiaomi/klee/proprietary`;
- generated private OMAPI prebuilt modules;
- no known stale configuration reintroduced.

## First source build

From the OrangeFox source root:

```bash
bash device/xiaomi/klee/tools/build-klee.sh
```

The harness performs:

```text
apply/check source patches
        ↓
source build/envsetup.sh + device exports
        ↓
full fail-closed preflight
        ↓
lunch twrp_klee-eng
        ↓
mka adbd vendorbootimage
        ↓
out/target/product/klee/klee-first-source-build.log
```

The built `vendor_boot.img` is a **compile/test carrier**, not yet the release
image. Step18 extracts its source-built RECOVERY fragment, compares it with
Build60, then combines it with the validated stock-derived PLATFORM + DTB using
the deterministic Step14 repacker.

## Temporary bring-up concession

`ALLOW_MISSING_DEPENDENCIES=true` is still enabled for the first clean compile.
After the build graph is proven, remove it and rebuild. A final release must not
depend on undeclared missing dependencies.
