# Step 6 — Build60 Runtime Scripts

This step imports only **plain-text / shell runtime helpers** from the Build60 golden recovery.

All listed scripts are copied byte-for-byte from Build60 and installed under:

`recovery/root/system/bin/`

Compiled project helpers and Xiaomi/vendor binaries are deliberately excluded from this step.

## Imported scripts

| Script | Size | SHA256 |
|---|---:|---|
| `create-bootdevice-link.sh` | 221 | `87abeeebfa65dd442e12ee2699c1fabf3816e64ec9f3e5ac7017a24aeb7a3111` |
| `load-touch-modules.sh` | 206 | `163f1439f11fa1fc89e5acfac2a26bf12debb4a0efa8015c1fde08314557d26c` |
| `klee_touch_odm_latefix.sh` | 3100 | `d79c625bb227f114a2d34db640b091408cc60930edc45ce34467278a1973990b` |
| `klee_fbe_prep.sh` | 4045 | `5b2fbc3cd9f6d2b6e5fde878d6dbc645ddaf59b35492a3d3f0bcaaba07c28aac` |
| `klee_miweaver_wait.sh` | 846 | `17d8705cfae5a632d4f7d00def4b485151a1ebce56542e5e4a311bf029a7d896` |
| `klee_haptic_stock_init.sh` | 6509 | `ab58c4977fb10683c854d59ed8768a51bdf95ee9b940530b21f152a38fafbf62` |
| `klee_splash_apply.sh` | 6704 | `b39705e0c25c7b0936ca27ebae87b80af5bd76ac5aeb674b99e274ee3daf4fd6` |
| `fox-settings-sync.sh` | 19415 | `a831f58b159e0e3a04699d5a9bd136272952a2003ccacb3f98eaca3e48e58604` |
| `fox-profile-sync.sh` | 3591 | `c77c51a73ad1dae3ca62b8575e76382fec97119fa24a9093542db96e7c440b5c` |
| `fox-status-preload.sh` | 3462 | `94d6ff721a99a6ccbe17c371a0d2816531bb84f43839bc1f6c2c9bfb8928448c` |
| `fox-theme-sync.sh` | 2200 | `c5863242d3dfb9710ef3980b58c58faf91cd9acb588a89a65f4b3f73a92b5dcb` |
| `klee-wipe-prep` | 6900 | `e79a57ee99859560153c1ad7d98aa06b0e3b0ee104603eca14dff57119195bb8` |
| `klee-fenrir-install` | 8639 | `3dbf3ab84bae81f399bce1f49623003853115704ca65b0b3f4b392e07b090fd6` |
| `klee-recovery-selftest` | 5298 | `5f68316abb1f190cb410a2ac6aa63a22fe5f9b6655c91c43d3d9b096d9205a59` |
| `klee-storage-health` | 3166 | `fbe00784b5bb25d4bb288cf3ff23a68296e1864b84ac0ee7aadb4c23ee02e33d` |
| `klee-clear-logs` | 1197 | `3c4474f4b5077482849b8b76ec94f20ba362c76de15221cdaa460c398697723c` |

## What each group does

### Boot / block-device helpers
- `create-bootdevice-link.sh` — creates `/dev/block/bootdevice/by-name` compatibility links.
- `load-touch-modules.sh` — loads the `klee` touch kernel modules from vendor_dlkm.

### Touch
- `klee_touch_odm_latefix.sh` — Build60 inherited `KleeTouchFixV3`; waits for ODM firmware visibility,
  restarts `touch_report` when needed, and checks that the service remains stable.

### Android 16 FBE
- `klee_fbe_prep.sh` — final region-aware FBE preparation.
- `klee_miweaver_wait.sh` — local Xiaomi Weaver launch/wait helper.

These scripts reference vendor Weaver/AuthSecret components that are **not** added here.

### Haptic
- `klee_haptic_stock_init.sh` — stock-backed AW86927 initialization.

It references a compiled helper:
- `/system/bin/aw86927_ff_constant_prime_noplay`

That executable remains outside Step 6.

### Splash / vendor_boot patching
- `klee_splash_apply.sh` — Build60 splash persistence backend for vendor_boot v4.

It depends on:
- `/system/bin/magiskboot`

`magiskboot` is an upstream/tool dependency, not copied from the golden image in this step.

### OrangeFox settings / profile / theme / status
- `fox-settings-sync.sh`
- `fox-profile-sync.sh`
- `fox-status-preload.sh`
- `fox-theme-sync.sh`

The settings/profile scripts depend on:
- `/system/bin/foxs-merge`

`foxs-merge` is a compiled project helper and is intentionally deferred.

### Wipe lifecycle
- `klee-wipe-prep`

This is the Build60 final wipe helper. It contains the validated lifecycle for:
- Advanced Wipe pre/post work;
- Format Data `touch_report` quiesce;
- Build60 `POSTDATAMEDIA` guarded `touch_report` resume.

### Fenrir
- `klee-fenrir-install`

This is the final shell-side Fenrir installer/repair logic.

It expects the validated Fenrir assets:
- `/system/etc/klee-fenrir-preloader.xz`
- `/system/etc/klee-fenrir-lk.xz`

Those binary boot-chain assets are **not** added to the public source tree yet.

### Klee Tools
- `klee-recovery-selftest`
- `klee-storage-health`
- `klee-clear-logs`

The self-test also probes `/system/bin/foxs-merge`, so the compiled helper must be provided later.

---

## Important source-reconstruction rule

These scripts are source-friendly because they are plain text, but importing them does **not** mean the
tree is build-ready yet.

Some scripts still depend on:

### Project compiled helpers
- `foxs-merge`
- `aw86927_ff_constant_prime_noplay`
- possible other compiled Klee helpers mapped later

### Vendor / proprietary components
- `touch_report`
- Xiaomi/NXP Weaver HAL components
- Xiaomi AuthSecret
- touch kernel modules
- vendor firmware / libraries
- Fenrir LK/preloader assets

### Upstream tools
- `magiskboot`
- toybox / shell / inotifyd and normal recovery utilities

These dependencies will be handled in separate reconstruction steps instead of being silently copied.

## Current tree growth

```text
recovery/root/
├── first_stage_ramdisk/
│   └── fstab.mt6899
├── fstab.mt6899
├── init.recovery.mt6899.rc
├── init.recovery.project.rc
├── init.recovery.usb.rc
├── system/
│   ├── bin/
│   │   ├── create-bootdevice-link.sh
│   │   ├── load-touch-modules.sh
│   │   ├── klee_touch_odm_latefix.sh
│   │   ├── klee_fbe_prep.sh
│   │   ├── klee_miweaver_wait.sh
│   │   ├── klee_haptic_stock_init.sh
│   │   ├── klee_splash_apply.sh
│   │   ├── fox-settings-sync.sh
│   │   ├── fox-profile-sync.sh
│   │   ├── fox-status-preload.sh
│   │   ├── fox-theme-sync.sh
│   │   ├── klee-wipe-prep
│   │   ├── klee-fenrir-install
│   │   ├── klee-recovery-selftest
│   │   ├── klee-storage-health
│   │   └── klee-clear-logs
│   └── etc/
│       └── recovery.fstab
└── vendor/
    └── etc/init/
        ├── klee_haptic_stock_init.rc
        └── klee_touch_odm_latefix.rc
```

## Next step

**Step 7: map the remaining runtime wiring.**

Before adding blobs or compiled helpers, inspect the Build60 init/UI references that actually launch:
- FBE prep;
- settings/profile/theme/status sync;
- Fenrir;
- Klee Tools;
- wipe prep;
- splash logic.

The goal is to know **who starts each script and when** so that copying scripts alone does not leave
dead/unreachable files in the reconstructed tree.
