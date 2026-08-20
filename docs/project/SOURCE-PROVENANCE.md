# Source Provenance / Reconstruction Record

The project is maintained from multiple evidence layers. These layers have different purposes and should not be conflated.

## 1. Runtime evidence

The strongest evidence for shipped recovery behavior is direct device testing on POCO X8 Pro (`klee`).

Current runtime validation includes:

- HyperOS `OS3.0.303.0.WPJIDXM`;
- HyperOS `OS3.0.304.0.WPJCNXM`;
- Android 16 FBE / KeyMint / Weaver / AuthSecret;
- encrypted/decrypted OrangeFox settings lifecycle;
- Recovery Password;
- theme/accent/navigation persistence;
- Novatek touch and AW86927 haptic;
- Fastbootd;
- Fenrir A/B verification/repair.

The current public runtime image is identified by SHA256:

`5740bd9c17e92d32e4dc24b02792a5c8aa54df94ad5233c1370af995269bcaf2`

## 2. Historical golden recovery baseline

Build60 remains the historical golden regression/reference baseline for the public source reconstruction.

Its SHA256 is:

`aa7fdc2ebc9f30ecbeaf18a6d982fd86de782600bdd30adf676a17c22e4d0251`

Build60 is not the current public runtime baseline. It is retained because the reconstruction tooling, helper proofs and early source-delta documentation were built around that known-good reference.

## 3. Stock device / ROM truth

Hardware, partition and proprietary behavior is grounded against stock `klee` inputs where appropriate, including:

- `vendor_boot` layout;
- DTB / DTBO;
- dynamic partition topology;
- vendor services and firmware;
- Weaver/AuthSecret implementations;
- touch and haptic components.

The public repository uses extraction maps and preparation tooling rather than pretending Xiaomi/MediaTek proprietary payloads are project-owned source.

## 4. Reconstruction artifacts

The repository contains:

- source-reconstructed helpers;
- fstab/init/service wiring;
- OrangeFox/TWRP patch fragments;
- proprietary extraction lists;
- deterministic repack/preflight tooling;
- reconstruction proofs and reference checksums.

These establish a traceable path toward a clean build, but they do not by themselves prove that the current 2026-08-20 runtime image is already reproducible from a fresh checkout.

## 5. Current stabilization delta

After the historical Build60 reconstruction anchor, later runtime work solved additional settings/password/theme lifecycle issues and verified current Fenrir behavior.

That later stabilization is authoritative for runtime/release behavior, while clean-source forward-port and rebuild verification remain separate future work.

## Documentation rule

When facts conflict, prefer:

1. direct current-device runtime evidence;
2. current release behavior;
3. stock device truth;
4. reconstruction/history documentation.

Do not invent missing historical build facts, and do not present a reconstruction milestone as runtime proof.
