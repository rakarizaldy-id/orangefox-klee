# Installation / Operational Guide

This guide applies to the current **OrangeFox R12.0 — 2026-08-20** runtime release for POCO X8 Pro (`klee`).

## Recovery image

`OrangeFox-R12.0-Unofficial-klee-Fenrir-20260820.img`

SHA256:

```text
5740bd9c17e92d32e4dc24b02792a5c8aa54df94ad5233c1370af995269bcaf2
```

## Flash or update OrangeFox

`klee` recovery lives in `vendor_boot`.

```bash
fastboot flash vendor_boot OrangeFox-R12.0-Unofficial-klee-Fenrir-20260820.img
fastboot reboot recovery
```

Always confirm that the connected device is `klee` before flashing.

## Existing Fenrir device

If the currently installed HOS is already Fenrir-compatible:

1. Boot OrangeFox.
2. Decrypt user 0 if requested.
3. Open `Advanced -> Klee Tools -> Fenrir Install / Repair`.
4. Allow the tool to verify the bootchain and both `vendor_boot` slots.
5. If all components already match, the operation is status-only.
6. If only the inactive `vendor_boot` slot requires repair, another Format Data is not automatically required.

## First true non-Fenrir -> Fenrir conversion

The required project sequence is:

```text
Fenrir Install / Repair
        ↓
Format Data
        ↓
Reboot System
```

Detailed sequence:

1. Boot OrangeFox.
2. Decrypt user 0.
3. Run `Fenrir Install / Repair`.
4. Confirm that Fenrir reaches the ready state.
5. **Format Data.**
6. Reboot System.

**Do not boot System between the first Fenrir conversion and Format Data.**

## Format Data behavior

The validated recovery architecture uses:

```text
PRE -> native DATAMEDIA -> POSTDATAMEDIA
```

- PRE quiesces `touch_report` when needed so ODM can be released safely.
- native Format Data performs the destructive wipe/unmap.
- POSTDATAMEDIA resumes `touch_report` only when PRE stopped it.
- physical touch is expected to return without requiring a recovery reboot.

If post-Format Data touch loss reappears, capture `/tmp/recovery.log` and treat it as regression evidence rather than documenting a reboot as the normal workaround.

## Advanced Wipe Data

The validated preserve-media Data wipe architecture uses one worker:

```text
PRE -> native WIPE -> POSTLIST -> queue_done
```

This preserves `/data/media` while repairing only the Android 16 FBE parent-directory skeleton required for the next decrypt cycle.

## Large ROM ZIP transfers

During project testing, very large ROM ZIP files were observed to be vulnerable to corruption when transferred through OrangeFox MTP.

For multi-gigabyte ROM testing, the validated transfer path is:

```bash
adb push <rom.zip> /sdcard/
```

This is a testing/transport note, not a claim that normal MTP operation is universally broken.

## OTA / survival

OrangeFox OTA/survival functionality is intentionally unsupported for this unofficial release.
