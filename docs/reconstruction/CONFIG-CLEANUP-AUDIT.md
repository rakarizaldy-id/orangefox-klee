# Step 15 — Final configuration cleanup audit

Step15 replaces remaining placeholders/stale carry-over with Build60/runtime evidence and current source semantics.

## Locked from Build60/runtime

- API/first API: 34
- product ABI: arm64-v8a only
- Bionic runtime CPU variant: cortex-a55
- panel: 1268x2756
- pixel format: RGBX_8888
- brightness path: `/sys/class/leds/lcd-backlight/brightness`
- hardware brightness max: 16383
- Virtual A/B + compression/userspace snapshots
- exact 35-entry A/B partition list
- custom configfs USB init (ADB 18D1:D001, fastbootd 18D1:4EE0)
- vendor_boot v4 geometry from Step14

## Important correction: cmdline variable

An early Step15 draft considered renaming `BOARD_KERNEL_CMDLINE` to a hypothetical `BOARD_VENDOR_CMDLINE`. That was rejected after checking the AOSP make path: classic Android build derives `INTERNAL_KERNEL_CMDLINE` from `BOARD_KERNEL_CMDLINE`, and uses it as `--vendor_cmdline` when constructing vendor_boot. The clean tree therefore keeps `BOARD_KERNEL_CMDLINE` even though the final field lives in vendor_boot.

## Brightness cleanup

Historical tree value `TW_MAX_BRIGHTNESS := 2047` conflicts with direct runtime hardware max 16383 and is removed. Default 4915 is ~30% of max; persisted OrangeFox settings remain authoritative after load.

## Dynamic partition cleanup

No old 9.1 GiB super/group values are retained. Physical `BOARD_SUPER_PARTITION_SIZE` remains 12 GiB because it is directly measured. No `BOARD_SUPER_PARTITION_GROUPS` is invented because this recovery-only tree does not build super.img.

## AVB cleanup

`BOARD_AVB_ENABLE` remains unset. This does not claim Android's vbmeta chain is gone; it avoids making this recovery-only tree build/sign AVB images while preserving the validated project-specific first-stage fstab behavior.

## Old flags intentionally removed

- `PRODUCT_TARGET_VNDK_VERSION := 36`
- old super group/size values
- `TW_LOAD_VENDOR_BOOT_MODULES`
- `TW_LOAD_VENDOR_MODULES`
- `TW_INCLUDE_LPDUMP`
- `TW_INPUT_BLACKLIST="hbtp_vm"`
- `TW_NO_SCREEN_BLANK`
- manual update_engine/update_verifier/checkpoint_gc requests

## Current OrangeFox variables used

- `FOX_AB_DEVICE=1`
- `FOX_VIRTUAL_AB_DEVICE=1`
- `FOX_VENDOR_BOOT_RECOVERY=1`
- `FOX_LOCAL_CALLBACK_SCRIPT=...`
- `FOX_ALLOW_EARLY_SETTINGS_LOAD=1`
- `OF_ENABLE_LPTOOLS=1`
- `OF_USE_DMCTL=1`
- `OF_MAINTAINER=RakaRizaldy`

`FOX_VERSION` remains intentionally unset because current OrangeFox marks it obsolete/automatic.

## Boot Control anomaly fixed

`init.recovery.mt6899.rc` imports `/init.recovery.bootctl.rc`; the reconstruction had not yet carried that file. Step15 restores the exact Build60 RC and maps the proprietary MTK AIDL boot service. Its MTK support library `libmtk_bsg.so` comes from the stock-derived PLATFORM fragment and is not duplicated.

## Newly discovered Step16 item

Build60 recovery process preloads `libodm_ebusy_suppress.so`. It is a project-specific fixed-offset recovery ELF hook, so Step15 does not falsely classify it as a vendor blob. It is explicitly queued for Step16 recovery-core/source-patch reconstruction.

## Temporary bring-up concession

`ALLOW_MISSING_DEPENDENCIES := true` remains for the first clean build only. Step17 should remove it if dependency declarations are complete.
