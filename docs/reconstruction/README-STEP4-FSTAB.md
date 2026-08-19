# Step 4 — Fstab reconstruction from Build60 golden

These three files are copied byte-for-byte from the Build60 recovery ramdisk.

## Roles

### `recovery/root/first_stage_ramdisk/fstab.mt6899`
- Build60 SHA256: `6b27f04a9f51303efb262bf781be6914a7c6a1269b9b0af5f0c431c863258261`
- mode in golden ramdisk: `0644`
- AVB-bearing lines: **0**
- This is the intentional first-stage path where this project removed AVB/verity flags.

### `recovery/root/fstab.mt6899`
- Build60 SHA256: `4560deebd3a841def0871bf9881d41e001467edf88ed27c81880e11389d398c8`
- mode in golden ramdisk: `0640`
- AVB-bearing lines: **19**
- This is a different recovery-root role and is intentionally not normalized to the first-stage copy.

### `recovery/root/system/etc/recovery.fstab`
- Build60 SHA256: `cfdd039916ab1809c9ff0aeaec9c055f3f56cd7d9ee6f519c2b9b71d5408ab64`
- mode in golden ramdisk: `0644`
- TWRP/OrangeFox partition-definition role.
- Contains recovery-specific wipe/formattable/slot metadata and must remain separate.

## Important rule
Do not deduplicate these files just because their partition entries overlap. They have different runtime roles.

## Next step
Step 5 will reconstruct the device-specific init files and identify which services belong in source/device overlays versus vendor extraction.
