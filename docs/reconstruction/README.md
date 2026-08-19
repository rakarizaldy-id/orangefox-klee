# Reconstruction archive

This directory preserves the source reconstruction and cleanup record that led
to the current public device tree.

The operational source files remain at repository root (`BoardConfig.mk`,
`device.mk`, `recovery/`, `helpers/`, `patches/`, `tools/`, etc.).

## Milestones

- Step 3 — build skeleton
- Step 4 — fstab roles
- Step 5 — init/service mapping
- Step 6 — runtime scripts
- Step 7 — runtime wiring
- Step 8 — OrangeFox/TWRP callback patch layer
- Step 9 — compiled-helper audit
- Step 10 — AW86927 helper source
- Step 11 — `foxs-merge` source
- Step 12 — OMAPI bridge source
- Step 13 — proprietary extraction map
- Step 14 — vendor_boot / DTB / DTBO / module strategy
- Step 15 — final configuration cleanup
- Step 16 — recovery-core/source patch layer
- Step 17 — build/preflight harness

Build60 remains the runtime golden baseline. The clean-source rebuild is
tracked in `../../SOURCE-STATUS.md`.
