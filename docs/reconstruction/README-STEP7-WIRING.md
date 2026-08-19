# Step 7 — Build60 Runtime Wiring Map

Step 7 verifies **who launches every runtime script** imported in Step 6.

It also adds one required Build60 init file that was discovered during the wiring audit:

`recovery/root/init.recovery.keymint.rc`

Golden SHA256:
`4cfe45b4bcbaf83f159b2445e12b3fd12c727f3c986dfc06ebcff35cd2a1c16c`

Golden CPIO mode:
`0750`

---

# 1. Boot init chain

Build60 boot wiring starts with:

```text
init.recovery.mt6899.rc
        |
        +--> import /init.recovery.bootctl.rc
        |
        +--> import /init.recovery.keymint.rc
```

Therefore `init.recovery.keymint.rc` is not optional. It is part of the Build60 boot-time orchestration.

---

# 2. Direct MT6899 boot helpers

`init.recovery.mt6899.rc` launches:

```text
load-touch-module
    -> /system/bin/load-touch-modules.sh

create-bootdevice-link
    -> /system/bin/create-bootdevice-link.sh
```

Both scripts already entered the reconstructed tree in Step 6.

---

# 3. Touch late-fix

`vendor/etc/init/klee_touch_odm_latefix.rc`:

```text
on init
    start klee_touch_odm_latefix

service klee_touch_odm_latefix
    -> /system/bin/klee_touch_odm_latefix.sh
```

So the touch late-fix is automatically started during init.

The Xiaomi `touch_report` service itself remains a later proprietary/vendor extraction item.

---

# 4. Haptic initialization

`vendor/etc/init/klee_haptic_stock_init.rc`:

```text
on init
    start klee.haptic_stock_init

service klee.haptic_stock_init
    -> /system/bin/klee_haptic_stock_init.sh
```

The shell logic is already source-friendly in Step 6.

Its compiled AW86927 helper remains deferred.

---

# 5. FBE / KeyMint / Weaver orchestration

`init.recovery.keymint.rc` defines the recovery-side security stack:

```text
tee-supplicant
vendor.keymint-mitee
vendor.gatekeeper_mitee
vendor.secure_element_hal_service
klee.omapi_bridge
miweaver_hal_service
vendor.weaver_nxp
vendor.weaver_xiaomi
klee.fbe_prep
```

The important trigger chain is:

```text
on fs
    -> prepare persist / metadata
    -> preload OrangeFox profile/theme state
    -> start tee-supplicant

tee-supplicant = running
    -> start vendor.keymint-mitee
    -> start vendor.secure_element_hal_service
    -> start klee.fbe_prep

secure element HAL = running
    -> start klee.omapi_bridge
```

`klee_fbe_prep.sh` then selects the validated regional backend:

```text
non-CN
    -> vendor.weaver_nxp
    -> MIAuthSecret path

Pure CN
    -> vendor.weaver_xiaomi
    -> Xiaomi Weaver/CPace path
```

The actual HAL binaries remain vendor/proprietary dependencies.

---

# 6. OrangeFox settings / profile / theme / status wiring

During `on fs`:

```text
metadata mounted early
    |
    +--> metadata-backed `.foxs` bind
    |
    +--> exec_start klee.status_vars_preload
    |
    +--> start klee.fox_profile_sync
```

Services:

```text
klee.status_vars_preload
    -> fox-status-preload.sh

klee.status_vars_cleanup
    -> fox-status-preload.sh cleanup-delayed

klee.fox_profile_sync
    -> fox-profile-sync.sh

klee.fox_settings_sync
    -> fox-settings-sync.sh

klee.fox_theme_sync
    -> fox-theme-sync.sh
```

After successful decrypt:

```text
on property:twrp.decrypt.done=true
    -> stop klee.fox_profile_sync
    -> start klee.status_vars_cleanup
    -> start klee.fox_settings_sync
    -> start klee.fox_theme_sync
```

This reconstructs the final Build60 pre-decrypt/post-decrypt settings lifecycle.

---

# 7. Klee Tools / Fenrir GUI wiring

Build60 `twres/pages/advanced.xml` contains a **Klee Tools** entry.

The Klee Tools page launches:

```text
Recovery Self-Test
    -> /system/bin/klee-recovery-selftest

Storage / Partition Health
    -> /system/bin/klee-storage-health

Clear OrangeFox Logs
    -> /system/bin/klee-clear-logs

Fenrir Install / Repair
    -> /system/bin/klee-fenrir-install
```

These are GUI `terminalcommand` actions.

The Build60 golden `advanced.xml` SHA256 is:

`1ca86e8cef05687b8d890e2c030739f949861785b61c4fdd47e07f9e0a0f2173`

We are **not copying the entire upstream XML into the device root yet**.
The final tree should represent these changes as a reproducible OrangeFox UI patch/overlay.

---

# 8. Advanced Wipe / Format Data wiring

Build60 `twres/pages/wipe.xml` connects the GUI wipe engine to `klee-wipe-prep`.

Advanced Wipe Data:

```text
PRE
    /system/bin/klee-wipe-prep LIST <wipe-list>
        ->
native WIPE LIST
        ->
POSTLIST
    /system/bin/klee-wipe-prep POSTLIST <wipe-list>
        ->
queue_done
```

Format Data:

```text
PRE
    /system/bin/klee-wipe-prep DATAMEDIA ""
        ->
native DATAMEDIA
        ->
POSTDATAMEDIA
    /system/bin/klee-wipe-prep POSTDATAMEDIA ""
        ->
queue_done
```

The second path is the Build60 fix that resumes `touch_report` after successful Format Data.

Golden `wipe.xml` SHA256:

`1f735b9d2e7d3fab7abe18b35a52b065396c81f4b02b163b79fc862c8376c6cf`

This XML must later become a source patch/overlay rather than an unexplained full upstream-file copy.

---

# 9. CLI wipe compatibility

Build60 has:

```text
/system/bin/twrp       -> shell wrapper
/system/bin/twrp.real  -> original compiled TWRP CLI
```

The wrapper intercepts only:

```text
twrp format data
    -> klee-wipe-prep DATAMEDIA

twrp wipe metadata
    -> klee-wipe-prep LIST "/metadata;"
```

and then `exec`s `twrp.real`.

Golden hashes:

```text
/system/bin/twrp
6cd9a93485238bbe93d0f234bee7587866fa4ccbd025ad3888f67b4e0f5cfc24

/system/bin/twrp.real
0b88764cf7358bf834a315b3f6aaaed46faf031dde21d77a4e6bd935e79f46ae
```

This must be reconstructed through build rules/source patching. We should **not** simply commit the
compiled `twrp.real` binary.

---

# 10. Splash wiring

Build60 `twres/pages/customization.xml` calls:

```text
/system/bin/klee_splash_apply.sh
```

from the `apply_splash` page.

Golden `customization.xml` SHA256:

`72522f88fe72cfe51cfd3e7035d8aff95e995450c3cb50ec99037dd40832351a`

Again, this should become a reproducible UI patch/overlay.

---

# Runtime reachability result

All 16 plain-text scripts imported in Step 6 are accounted for:

| Script | Runtime entry |
|---|---|
| `create-bootdevice-link.sh` | `init.recovery.mt6899.rc` |
| `load-touch-modules.sh` | `init.recovery.mt6899.rc` |
| `klee_touch_odm_latefix.sh` | `klee_touch_odm_latefix.rc` |
| `klee_fbe_prep.sh` | `init.recovery.keymint.rc` |
| `klee_miweaver_wait.sh` | `init.recovery.keymint.rc` |
| `klee_haptic_stock_init.sh` | `klee_haptic_stock_init.rc` |
| `klee_splash_apply.sh` | `customization.xml` |
| `fox-settings-sync.sh` | `init.recovery.keymint.rc` |
| `fox-profile-sync.sh` | `init.recovery.keymint.rc` |
| `fox-status-preload.sh` | `init.recovery.keymint.rc` |
| `fox-theme-sync.sh` | `init.recovery.keymint.rc` |
| `klee-wipe-prep` | `wipe.xml` + TWRP CLI wrapper |
| `klee-fenrir-install` | `advanced.xml` |
| `klee-recovery-selftest` | `advanced.xml` |
| `klee-storage-health` | `advanced.xml` |
| `klee-clear-logs` | `advanced.xml` |

**No Step 6 script is currently an unexplained dead file.**

---

# Step 7 tree addition

The actual source-tree addition in this step is:

```text
recovery/root/
└── init.recovery.keymint.rc
```

UI XML and TWRP wrapper behavior are documented but deliberately deferred to the next source-patch step.

# Next step

**Step 8: reconstruct the project-authored UI / TWRP patch layer.**

Targets:

1. `advanced.xml` — Klee Tools + Fenrir
2. `wipe.xml` — Build58/59/60 wipe sequencing
3. `customization.xml` — vendor_boot-v4 splash backend
4. TWRP CLI wrapper/build rule

The goal is to represent only our deltas against OrangeFox source, rather than committing complete
upstream-generated files without explanation.
