# Building the reconstructed klee OrangeFox tree

## Verification boundary

The repository currently contains a **clean-source reconstruction anchored to the historical Build60 behavior baseline**.

The current public runtime release dated 2026-08-20 includes later settings/password/theme/Fenrir stabilization work. A completely fresh source build that reproduces that current runtime image byte-for-byte has **not** yet been completed from this published tree.

Do not interpret the current release tag as proof that the public tree already reproduces the release image.

## Required source base

This reconstruction targets the OrangeFox `fox_12.1` source family used for the historical Build60 behavior baseline.

Place this device tree at:

```text
device/xiaomi/klee
```

## One-time non-source inputs

The public device tree intentionally does not contain Xiaomi/MediaTek hardware payloads. Before the first build, prepare:

1. stock-derived PLATFORM vendor ramdisk + DTB/DTBO;
2. generated `vendor/xiaomi/klee` proprietary repository.

Helper:

```bash
bash device/xiaomi/klee/tools/prepare-klee-build-inputs.sh \
    /path/to/vendor_boot.img \
    /path/to/dtbo.img \
    /path/to/unpacked-stock-root
```

If the proprietary extraction source is not ready yet, omit the third argument. The helper will prepare only the hardware inputs and the full preflight will later report what is still missing.

## Preflight only

Committed/source-owned tree checks can be run without Android source or stock blobs:

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
- the reconstructed core source patches already applied;
- generated stock PLATFORM/DTB/DTBO inputs matching the historical reconstruction gates;
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

The built `vendor_boot.img` is a **compile/test carrier**, not automatically the current public release image.

The reconstruction workflow compares the source-built RECOVERY fragment against the historical validated reference and combines it with known-good stock-derived non-recovery inputs using the deterministic repacker.

## Temporary bring-up concession

`ALLOW_MISSING_DEPENDENCIES=true` remains a temporary first-compile concession in the reconstruction flow.

After the build graph is proven, remove it and rebuild. A final source-reproducible release should not depend on undeclared missing dependencies.

## Current source goal

The next source milestone is not another runtime recovery patch. It is:

1. reproduce the historical reconstruction cleanly from a fresh source checkout;
2. forward-port the post-Build60 stabilization delta into the source tree;
3. rebuild and runtime-test that source-produced image;
4. only then claim the current release line as clean-source reproducible.
