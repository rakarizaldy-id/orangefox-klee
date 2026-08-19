# Klee OrangeFox core deltas

Only two recovery-core changes are retained:

1. `variables.h`: set `FOX_BRANCH` to `"klee"`.
2. `partition.cpp`: if the normal unmount fails with the exact combination
   `/odm` + `EBUSY`, try `MNT_DETACH`, wait 200 ms, and return success only
   after `Is_Mounted()` confirms `/odm` is actually gone.

Apply after syncing OrangeFox fox_12.1 and before compiling:

```bash
python3 device/xiaomi/klee/tools/apply-klee-source-patches.py "$ANDROID_BUILD_TOP"
```

The patcher is idempotent and fail-closed if upstream structure changes.

The old broad device patchset is deliberately not imported wholesale.
