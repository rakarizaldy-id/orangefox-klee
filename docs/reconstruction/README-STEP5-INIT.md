# Step 5 — Init / Service Reconstruction

All files in this step were extracted directly from the Build60 golden recovery ramdisk.

## Included in the source-tree overlay

- `recovery/root/init.recovery.mt6899.rc` — MediaTek recovery init layer.
- `recovery/root/init.recovery.project.rc` — project/device properties and mount-point skeleton.
- `recovery/root/init.recovery.usb.rc` — Build60 configfs implementation for ADB, sideload, MTP and fastbootd.
- `recovery/root/vendor/etc/init/klee_touch_odm_latefix.rc` — project touch late-fix wrapper.
- `recovery/root/vendor/etc/init/klee_haptic_stock_init.rc` — project haptic init wrapper.

## init.recovery.mt6899.rc

This file:

- imports recovery boot-control and KeyMint init fragments;
- enforces SELinux in early-init;
- configures USB controller `11201000.usb0`;
- starts the recovery boot HAL when servicemanager is ready;
- defines `load-touch-module`;
- defines `create-bootdevice-link`;
- starts boot HAL, health HAL, touch-module loader and bootdevice-link helper on boot.

This means later reconstruction must also provide:

- `/system/bin/load-touch-modules.sh`
- `/system/bin/create-bootdevice-link.sh`

## init.recovery.project.rc

Creates the Build60 mount-point skeleton for metadata/persist/nvdata/nvcfg/protect/mi_ext and sets:

- `ro.hardware=mt6899`
- `ro.board.platform=mt6899`
- dynamic partitions = true
- A/B = true
- Virtual A/B = true
- userspace snapshots = true

Recovery USB identity:

- ADB VID `18D1`
- ADB PID `D001`
- fastbootd PID `4EE0`

## init.recovery.usb.rc

Preserves the validated Build60 configfs paths for:

- ADB
- sideload
- MTP
- MTP + ADB
- fastbootd

Important IDs include Google/Android `18D1` for ADB/fastbootd and Xiaomi `2717` for the MTP gadget paths.

## Project service RCs

`klee_touch_odm_latefix.rc` launches `/system/bin/klee_touch_odm_latefix.sh` during init.

`klee_haptic_stock_init.rc` launches `/system/bin/klee_haptic_stock_init.sh` during init.

The corresponding scripts are reconstructed in a later step.

## Vendor RC deliberately not added yet

Build60 also contains `vendor/etc/init/touch_report.rc`, which launches the Xiaomi vendor binary `/vendor/bin/touch_report`.

It is deliberately kept out of the public project overlay for now. The service definition and binary belong together in the later vendor/proprietary extraction flow. Build60 remains the behavioral reference.

## Permission note

Golden CPIO modes:

- the three root `init.recovery.*.rc` files: `0750`
- the two `vendor/etc/init/klee_*` files: `0644`

Git only records the executable bit, so exact final ramdisk permissions must be enforced by the build configuration where necessary.

## Step 5 tree

```text
recovery/root/
├── first_stage_ramdisk/
│   └── fstab.mt6899
├── fstab.mt6899
├── init.recovery.mt6899.rc
├── init.recovery.project.rc
├── init.recovery.usb.rc
├── system/
│   └── etc/
│       └── recovery.fstab
└── vendor/
    └── etc/
        └── init/
            ├── klee_haptic_stock_init.rc
            └── klee_touch_odm_latefix.rc
```

## Next step

Step 6 will reconstruct the plain-text runtime scripts referenced by these RCs and by the validated Build60 project. Compiled helpers and Xiaomi vendor binaries remain separate for now.
