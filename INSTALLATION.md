# Installation / Operational Guide — Build60 FINAL

## Flash or update OrangeFox
`klee` recovery lives in `vendor_boot`.

Typical active-slot fastboot flow:

```text
fastboot flash vendor_boot <Build60 image>
fastboot reboot recovery
```

Always confirm the device is `klee` and that the intended active slot is the one being operated on.

## Existing Fenrir-compatible HOS
1. Boot Build60.
2. Decrypt user 0 if requested.
3. `Advanced -> Klee Tools -> Fenrir Install / Repair`.
4. Confirm completion/ready.
5. Continue normal ROM/recovery workflow.

## Non-Fenrir HOS -> first Fenrir conversion
This project requires:

1. Boot Build60.
2. Decrypt user 0.
3. Run `Fenrir Install / Repair`.
4. Confirm Fenrir completes.
5. **Format Data.**
6. Reboot System.

Official sequence:
`non-Fenrir HOS -> Fenrir Install / Repair -> Format Data -> Reboot System`

Do not skip Format Data in this transition.

## Format Data in Build60
Expected internal sequence:
`PRE -> native DATAMEDIA -> POSTDATAMEDIA`

- PRE quiesces `touch_report` so ODM can be released.
- native Format Data performs the destructive wipe/unmap.
- POSTDATAMEDIA resumes `touch_report` only if PRE stopped it.
- touch should work immediately afterward without a recovery reboot.

## Advanced Wipe Data
Build60 inherits the validated Build58 same-worker sequence:
`PRE -> native WIPE -> POSTLIST -> queue_done`

This preserves `/data/media` while repairing only the missing Android 16 FBE parent skeleton required
for the next decrypt cycle.

## Large HyperDot ZIP transfer during testing
The project observed corruption when very large ROM ZIPs were copied through OrangeFox MTP.
For multi-gigabyte ROM ZIP testing, ADB push was the validated transfer path.

## Separate Windows BAT
The HyperDot Windows BAT flasher is not part of this OrangeFox release artifact and had not yet completed
the separate Build60 BAT runtime test when this package was created.
