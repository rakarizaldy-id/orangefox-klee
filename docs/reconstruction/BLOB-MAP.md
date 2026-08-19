# Step 13 — Proprietary extraction map

## Goal

Keep only **device/vendor-specific runtime inputs** as proprietary files.

Everything that can reasonably be source-built or represented as text
configuration stays in the device tree.

## Proprietary categories retained

### FBE / MiTEE
- MiTEE supplicant
- KeyMint service
- Gatekeeper service
- Secure Element service
- NXP Weaver backend
- Xiaomi Weaver/CPace backend
- Xiaomi AuthSecret service
- vendor/interface support libraries
- four MiTEE TA files present in Build60

### Touch userspace
- `touch_report`
- the four `libtouchreport*` plugins
- `libmisight.so`

## Source-owned configuration

These are deliberately **not** proprietary blobs anymore:

- `recovery/root/vendor/etc/init/touch_report.rc`
- `recovery/root/vendor/etc/vintf/manifest/klee-security.xml`

The VINTF file is a minimal recovery-only declaration instead of carrying a
large stock vendor manifest with unrelated radio/audio/camera HAL declarations.

## Cleanup / anomaly removals

### Removed: `system/lib64/klee-touch/*`

Build60 contains:

- `android.frameworks.sensorservice-V1-ndk.so`
- `android.hardware.common-V2-ndk.so`
- `android.hardware.common.fmq-V1-ndk.so`
- `android.hardware.sensors-V2-ndk.so`
- a private `libc++.so`
- `vendor.xiaomi.hw.touchfeature-V1-ndk.so`

But final Build60 text/config has no runtime reference to this directory and
`touch_report` does not include it in `LD_LIBRARY_PATH`.

**Step 13 classification: historical/dead residue; excluded.**

If the first clean source build later proves a hidden runtime dependency, this
decision can be revisited from evidence rather than carrying the entire folder
pre-emptively.

### Removed: duplicate touch modules from recovery `/lib/modules`

Build60 also contains copies of:

- `nt38771_touch_klee.ko`
- `xiaomi_touch_klee.ko`

The final `load-touch-modules.sh` does not load those copies. It mounts
`/vendor_dlkm` and loads:

```text
/vendor_dlkm/lib/modules/nt38771_touch_klee.ko
/vendor_dlkm/lib/modules/xiaomi_touch_klee.ko
```

Therefore the recovery-root duplicates are not added to this proprietary map.
The vendor_dlkm/kernel strategy is handled in Step 14.

### Removed: proprietary `libmemunreachable` carry-over

The old tree copied a vendor `libmemunreachable.so` into recovery system.
Build60 already contains the source-built AOSP system library, so this
proprietary duplicate is excluded.

### OMAPI NDK duplicate cleanup

Build60 has vendor copies:

- `vendor/lib64/android.hardware.secure_element-V1-ndk.so`
- `vendor/lib64/android.se.omapi-V1-ndk.so`

and stripped copies under `system/lib64/klee_*`.

The pairs have:
- identical ELF Build IDs;
- identical exported symbol sets;
- identical SONAME/NEEDED contracts.

The system copies are therefore treated as stripped packaging variants, not
independent blobs. Step 13 keeps one vendor source copy and uses extract-utils
`lib_fixups` to expose private module names for linking the source-built bridge.

## Provenance boundary

Build60 GOLDEN determines:
- which files must exist in recovery;
- target path;
- runtime behavior;
- exact golden hashes.

Stock HyperOS remains the preferred redistribution/extraction origin.
Where a stock partition source path is still uncertain, the first extraction
run will validate it. A path mismatch is a provenance/path issue, not permission
to pull files from the old broken tree.

## Current source baseline

Validated runtime baselines used by the project:
- Global/IDXM: OS3.0.303.0.WPJIDXM
- Pure CN: OS3.0.304.0.WPJCNXM

The universal FBE stack intentionally carries both:
- NXP + MIAuthSecret path for non-CN;
- Xiaomi Weaver/CPace path for CN.

## MTK Boot Control

Step15 restored the Build60 boot-control import and maps:

```text
vendor/bin/hw/android.hardware.boot-service.mtk
```

`libmtk_bsg.so`, required by that service, is already supplied by the stock-derived PLATFORM vendor ramdisk and is not duplicated in the proprietary extraction set. The AIDL boot VINTF declaration is source-owned as `klee-boot.xml`.
