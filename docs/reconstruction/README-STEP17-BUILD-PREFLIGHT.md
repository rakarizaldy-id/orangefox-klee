# Step 17 — First-build preflight and build harness

Step17 does **not** claim that a full OrangeFox source build has already run in
this artifact runtime. The complete OrangeFox checkout and extracted stock
vendor repository are intentionally external to the public device tree.

Instead Step17 makes the first real build deterministic and fail-closed.

Added:

```text
tools/
├── preflight-klee-build.py
├── prepare-klee-build-inputs.sh
└── build-klee.sh

BUILDING.md
```

## What the full preflight validates

- device tree files and source helpers;
- no known stale/legacy flags;
- project first-stage no-AVB fs_mgr policy;
- stock-derived PLATFORM/DTB/DTBO input report;
- OrangeFox source structure;
- Step16 native branch + ODM source patches;
- all proprietary inputs;
- private OMAPI NDK module generation.

## Build command

The harness uses:

```text
lunch twrp_klee-eng
mka adbd vendorbootimage
```

and stores the compile log under the product output directory.

## Why final repack is still Step18

The source build's job is to prove that the RECOVERY fragment compiles from this
clean tree. Build60's hardware PLATFORM fragment is deliberately not recreated
as hundreds of source-tree blob entries. Step18 will extract the newly compiled
RECOVERY fragment and combine it with the validated stock-derived PLATFORM/DTB.

## Current status

- committed/device-tree preflight: PASS
- fake complete-environment full-preflight regression: PASS
- actual OrangeFox compile: pending an external synced source checkout + stock extraction inputs

This distinction is intentional: no false "build PASS" claim is made before a
real build command executes in the actual Android source environment.
