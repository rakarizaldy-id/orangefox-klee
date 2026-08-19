# Step 13 — Proprietary extraction layer

Step 13 creates the first clean extraction architecture.

Added:

```text
proprietary-files.txt
extract-files.py
setup-makefiles.py
recovery-proprietary.mk
BUILD60-BLOB-SHA256SUMS.txt
BLOB-MAP.md
tools/verify-build60-blobs.py

recovery/root/vendor/etc/init/touch_report.rc
recovery/root/vendor/etc/vintf/manifest/klee-security.xml
```

## Extraction model

The intended generated vendor repository is:

```text
vendor/xiaomi/klee/
└── proprietary/
```

`recovery-proprietary.mk` maps only validated proprietary inputs into the
recovery ramdisk.

`device.mk` now inherits that map.

## Fail-clean principle

Do not commit copied Xiaomi ELF/TA/kernel blobs into the public device tree.

For development, extract them from a validated stock/golden source into the
separate generated vendor repository.

## Status

- Build60 proprietary target map: PASS
- golden SHA256 manifest: generated
- dead `klee-touch` directory: excluded
- duplicate recovery touch KOs: excluded
- proprietary libmemunreachable carry-over: excluded
- touch init RC: moved to source configuration
- security VINTF: reduced to recovery-only source fragment
- current Lineage-style Python extract-utils entrypoint: added

## Remaining uncertainty

The exact stock-partition origin of a small number of files still needs
validation when the official stock images are used as extraction input.
The **recovery target paths and Build60 hashes are already known**.

That validation is intentionally deferred to the first real extraction/build
instead of blocking reconstruction now.

## Next step

Step 14:
- vendor_boot PLATFORM fragment strategy;
- DTB / DTBO;
- kernel/vendor_dlkm module strategy;
- decide what is extracted from stock versus source-built.
