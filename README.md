# OrangeFox Recovery for POCO X8 Pro (`klee`)

Unofficial **OrangeFox R12.0** recovery project for the **POCO X8 Pro (`klee`)**, independently maintained by **RakaRizaldy**.

> [!NOTE]
> This repository is the independent `klee` release and development channel maintained by RakaRizaldy. It is not presented as, affiliated with, or maintained on behalf of any previous unofficial maintainer or previous unofficial release channel. Upstream OrangeFox/source attribution and licensing remain separate and will be preserved where applicable.

## Source tree status

```text
Build status: PASS by reconstruction/preflight
Clean-source rebuild: verification deferred
```

This repository now contains the independently reconstructed `klee` device
tree and build tooling derived from the validated Build60 recovery baseline.
The Build60 binary/runtime validation and the clean-source rebuild status are
tracked separately; see **[SOURCE-STATUS.md](SOURCE-STATUS.md)**.

> [!WARNING]
> This is an unofficial recovery project for an unlocked device. Flashing recovery, boot-chain partitions, dynamic partitions, or running Format Data can cause data loss or an unbootable device if used incorrectly. Make a backup and verify that your device is `klee` before flashing.

## Current release

**Build60 FINAL — 19 August 2026**

- Recovery image target: `vendor_boot`
- Image size: **64 MiB** (`67,108,864` bytes)
- SHA256: `aa7fdc2ebc9f30ecbeaf18a6d982fd86de782600bdd30adf676a17c22e4d0251`
- Device: **POCO X8 Pro (`klee`)**
- Platform: MediaTek MT6899 family
- Virtual A/B + dynamic partitions
- Android 16 FBE support on the validated HyperOS bases

Build60 supersedes Build59 for public use. Its direct fix closes the post-Format-Data touch lifecycle issue: `touch_report` is quiesced before native Format Data so ODM can be released, then automatically resumed afterward. Runtime validation confirmed that touch remains usable without rebooting recovery.

## Highlights

- Android 16 FBE decryption with region-aware Weaver backend selection.
- Validated IDXM NXP Weaver + Xiaomi MIAuthSecret path.
- Validated Pure CN Xiaomi Weaver/CPace path.
- Stable Novatek touch initialization and post-Format-Data touch recovery.
- AW86927 stock-backed haptic initialization and strong constant-duration feedback.
- OrangeFox settings/profile persistence across pre-decrypt and post-decrypt states.
- Fastbootd fixes including Windows userspace-fastboot recognition.
- Dynamic-partition / SUPER handling for `klee`.
- Klee Tools: Recovery Self-Test, Storage / Partition Health, and Clear OrangeFox Logs.
- Fenrir Install / Repair with FBE fail-closed behavior and upgrade-safe `vendor_boot` cache handling.
- Advanced Wipe Data Android 16 FBE parent-directory repair.
- Format Data dynamic-unmap preparation and Build60 post-format touch auto-resume.

## Installation

Recovery lives in `vendor_boot`.

```text
fastboot flash vendor_boot <Build60-image.img>
fastboot reboot recovery
```

Always confirm the target device and active slot before flashing. See **[INSTALLATION.md](INSTALLATION.md)** for the full operational procedure.

### Fenrir first-conversion rule

For a currently installed **non-Fenrir HOS** state, this project requires:

```text
Fenrir Install / Repair -> Format Data -> Reboot System
```

**Format Data is mandatory** for that first non-Fenrir -> Fenrir conversion.

## Validation status

Build60 has directly passed:

- OrangeFox boot.
- Format Data.
- automatic `touch_report` resume after Format Data.
- repeated Format Data in one recovery session.
- Dalvik/Cache wipe between repeated Format Data cycles.
- post-System Format Data regression.
- physical touch usability without recovery reboot.

The companion HyperDot recovery ZIP also passed its sparse SUPER installation path, post-recovery-reboot SUPER/mapping checks, and clean boot to Android Setup Wizard.

See **[TEST_MATRIX.md](TEST_MATRIX.md)** for the detailed validation matrix.

## Documentation

- **[CHANGELOG.md](CHANGELOG.md)** — concise public changelog.
- **[BUILD-HISTORY.md](BUILD-HISTORY.md)** — build-by-build project history.
- **[TECHNICAL-HISTORY.md](TECHNICAL-HISTORY.md)** — subsystem root causes and architecture.
- **[INSTALLATION.md](INSTALLATION.md)** — flashing and Fenrir/Format Data procedure.
- **[KNOWN_NOTES.md](KNOWN_NOTES.md)** — boundaries, caveats, and non-claims.
- **[TEST_MATRIX.md](TEST_MATRIX.md)** — runtime validation status.
- **[CHANGELOG-FULL-CHAT1-TO-CHAT9.md](CHANGELOG-FULL-CHAT1-TO-CHAT9.md)** — full preserved project chronology.
- **[SOURCE-PROVENANCE.md](SOURCE-PROVENANCE.md)** — history reconstruction notes.
- **[SOURCE-STATUS.md](SOURCE-STATUS.md)** — reconstruction/preflight status and clean-build boundary.
- **[BUILDING.md](BUILDING.md)** — source preparation and build workflow.
- **[docs/reconstruction/](docs/reconstruction/)** — Step3–Step17 reconstruction proofs and audit records.

## Project identity

This repository documents and publishes the current independent `klee` recovery line developed and validated through this project's own build/test history. Historical technical evidence is retained for reproducibility, but no previous unofficial maintainer is used as the identity, branding, authority, or release channel of this repository.

## Development approach

The project follows a minimal-delta workflow: once a subsystem reaches runtime closure, later builds preserve it unless new runtime evidence justifies reopening it. Static proof, runtime proof, and inference are documented separately, and destructive operations are designed to fail closed.

## Releases

Large binary artifacts such as the final `.img` and FINAL MASTER release ZIP belong in **GitHub Releases**, not in normal Git history. Release assets should carry SHA256 checksums for verification.

## Disclaimer

This repository is an unofficial community project and is not affiliated with Xiaomi, POCO, or the OrangeFox official support team. Use at your own risk.
