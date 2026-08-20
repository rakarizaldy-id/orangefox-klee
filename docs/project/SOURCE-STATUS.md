# Source Status

```text
Runtime release:              VALIDATED
Published source tree:        PASS by reconstruction/preflight
Clean-source current release: NOT YET VERIFIED
```

## Current runtime release

The current runtime-validated public image is:

`OrangeFox-R12.0-Unofficial-klee-Fenrir-20260820.img`

SHA256:

`5740bd9c17e92d32e4dc24b02792a5c8aa54df94ad5233c1370af995269bcaf2`

Its runtime validation includes Android 16 FBE, encrypted/decrypted settings convergence, Recovery Password, theme/navigation persistence, touch/haptic, Klee Tools and Fenrir A/B verification/repair.

## What `PASS by reconstruction/preflight` means

The published device tree completed the reconstruction and static/preflight gates derived from the historical Build60 recovery baseline.

It includes:

- reconstructed recovery fstab roles and init/service wiring;
- source reconstructions of project-specific compiled helpers;
- OrangeFox/TWRP patch and callback layer;
- proprietary extraction map rather than committed Xiaomi blobs;
- stock-derived `vendor_boot` PLATFORM / DTB / DTBO preparation tooling;
- device configuration cleanup;
- build preflight checks designed to fail closed on known regressions.

## Important boundary

The current 2026-08-20 release contains later runtime stabilization beyond the historical Build60 reconstruction anchor.

A completely fresh OrangeFox source checkout has **not** yet been independently compiled, forward-ported through the later stabilization delta, and runtime-validated as an exact reproduction of the current public image.

Therefore this repository does **not** currently claim:

- byte-for-byte reproducibility of the 2026-08-20 release from the public tree;
- that every current runtime delta is already represented in clean source;
- that the public source tree itself has passed the same current-release runtime matrix.

This distinction preserves both records accurately:

- current release runtime behavior is validated;
- clean-source reproducibility of that current release remains a future verification milestone.
