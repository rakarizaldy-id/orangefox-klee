# Changelog — OrangeFox R12.0 Unofficial for POCO X8 Pro (`klee`)

This is the public/user-facing changelog. For the complete experimental chronology, including rejected
builds and root-cause work, see `CHANGELOG-FULL-CHAT1-TO-CHAT9.md` and `TECHNICAL-HISTORY.md`.

## 2026-08-20 — OrangeFox R12.0

- Android 16 FBE decryption support for `klee`.
- KeyMint, Weaver and AuthSecret integration.
- Stable encrypted/decrypted recovery settings lifecycle.
- Recovery Password lifecycle fixes.
- Persistent theme/accent/navigation settings.
- Home/Back decrypt-page navigation fixes.
- NVT touch and AW86927 haptic support.
- Fastbootd support.
- Fenrir Install / Repair with A/B verification and hash-verified writes.
- Recovery Diagnostics and Storage / Partition Status tools.
- Safe saved-log cleanup without truncating `/tmp/recovery.log`.
- Recovery UI race and soft-restart fixes.


## Build60 — 19 August 2026 — FINAL

### Format Data touch lifecycle
- Fixed touch becoming unusable after a successful Format Data in the same recovery session.
- Retains Build59 automatic `touch_report` quiesce before dynamic SUPER unmap.
- Added guarded `POSTDATAMEDIA` resume after native Format Data.
- Touch now returns automatically without recovery reboot and without remounting ODM.
- Repeated Format Data and post-System regression tests passed.

### Retained wipe/FBE safety
- Advanced Wipe Data keeps the Build58 single-worker `PRE -> WIPE -> POSTLIST` architecture.
- Android 16 FBE parent-directory repair after preserve-media Data wipe retained.
- `.foxs` profile recovery/persistence architecture retained.
- Format Data dynamic-unmap preparation from Build59 retained.

### Fenrir
- Fenrir Install / Repair retained byte-identically from the validated architecture.
- Upgrade-safe vendor_boot cache handling prevents old valid cache from downgrading a newly flashed recovery.
- FBE-locked state remains fail-closed.
- Final project rule: non-Fenrir HOS -> Fenrir Install / Repair -> **Format Data required** -> Reboot System.

## Major milestones inherited by Build60

### Universal Android 16 FBE
- IDXM `OS3.0.303.0.WPJIDXM`: NXP Weaver + Xiaomi MIAuthSecret path, directly validated.
- Pure CN `OS3.0.304.0.WPJCNXM`: Xiaomi Weaver/CPace path, directly validated.
- Region-aware backend selection; no global hardcoded Weaver key size.

### Settings / themes / status
- Pre-decrypt settings bootstrap through metadata/persist architecture.
- Direct-PIN and encrypted-main profile reconciliation.
- Fresh-install `.foxs` bootstrap and post-wipe fallback self-heal.
- Theme/status preload and persistent UI preferences.

### Touch / display / haptic
- Novatek `touch_report` stabilization with ODM-aware startup logic.
- Display/panel and screenshot fixes retained.
- AW86927 stock-backed haptic initialization.
- Strong `FF_CONSTANT` duration path with real slider duration and no boot vibration.

### Fastbootd / dynamic partitions
- fastbootd AIDL/service/SELinux and USB configfs fixes retained.
- Windows fastbootd enumeration verified with Google Android Bootloader Interface.
- Dynamic SUPER mappings, ADB root and recovery flashing workflows retained.

### Klee Tools
- Recovery Self-Test.
- Storage / Partition Health.
- Clear OrangeFox Logs.
- True in-memory GUI “Clear Console” remains parked/not implemented.

### Release identity
- Native `[Branch] : klee`.
- Friendly device identity `POCO X8 Pro (klee)`.
- Independent `klee` release line maintained and packaged by RakaRizaldy.
