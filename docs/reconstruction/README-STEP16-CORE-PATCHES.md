# Step 16 — Final OrangeFox recovery-core patches

Step16 removes the last brittle Build60 binary-core workaround and makes native
branch identity source-reproducible.

Added:

```text
patches/orangefox/core/
├── README.md
└── klee-core-delta.patch

tools/
├── apply-klee-source-patches.py
└── apply-klee-source-patches.sh

CORE-PATCH-PROOF.md
STEP16-SELFTEST.txt
```

The existing ramdisk callback is also updated so no
`libodm_ebusy_suppress.so` or matching `LD_PRELOAD` survives a clean build.

After syncing OrangeFox fox_12.1:

```bash
python3 device/xiaomi/klee/tools/apply-klee-source-patches.py "$ANDROID_BUILD_TOP"
```

The source patcher is idempotent and fail-closed on upstream drift.

Next: Step17 first real source-build/preflight.
