# Step 14 — vendor_boot / DTB / DTBO / module strategy

Step 14 closes the hardware-input architecture without copying stock kernel
payloads into the public device tree.

Added:

```text
prebuilt/
├── README.md
└── generated/
    └── .gitignore

tools/
├── klee_vendor_boot.py
├── prepare-klee-stock-inputs.py
└── repack-klee-vendor-boot.py

HARDWARE-INPUT-STRATEGY.md
```

`BoardConfig.mk` now contains the Build60-validated vendor_boot address geometry
and locally generated DTB/DTBO paths.

## Important cleanup

Not carried forward:
- `TW_LOAD_VENDOR_BOOT_MODULES`
- `TW_LOAD_VENDOR_MODULES`
- duplicate recovery-root touch `.ko` files
- 244 stock PLATFORM modules as public-tree prebuilts

The final source build will reuse stock PLATFORM hardware state and replace only
the project-owned first-stage fstab.

## Self-test status

The Step14 vendor_boot packer is required to rebuild Build60 exactly when fed
Build60's own three component payloads. This proves the v4 section offsets,
alignment, table layout, image padding and address/header handling.

## Next

Step 15 is the final BoardConfig/device configuration cleanup:
- dynamic partition group metadata;
- shipping API;
- display/brightness/pixel format;
- USB/package flags;
- removal of remaining placeholder values/TODOs.
