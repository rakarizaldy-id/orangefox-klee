# OrangeFox Recovery for POCO X8 Pro (`klee`)

Unofficial **OrangeFox R12.0** recovery device tree for **POCO X8 Pro (`klee`)**.

Maintained by **RakaRizaldy**.

## Device

| Item | Value |
|---|---|
| Device | POCO X8 Pro |
| Codename | `klee` |
| Platform | MediaTek MT6899 |
| Architecture | arm64 |
| Recovery target | `vendor_boot` |
| Partition scheme | Virtual A/B + Dynamic Partitions |
| Android baseline | Android 16 / HyperOS |

## Current Release

**OrangeFox R12.0 — 2026-08-20**

This is the current runtime-validated OrangeFox R12.0 release for `klee`.

### Recovery image

`OrangeFox-R12.0-Unofficial-klee-Fenrir-20260820.img`

SHA256:

```text
5740bd9c17e92d32e4dc24b02792a5c8aa54df94ad5233c1370af995269bcaf2
```

[Download OrangeFox R12.0 for klee](https://github.com/rakarizaldy-id/orangefox-klee/releases/tag/OrangeFox-R12.0-klee-20260820)

## Features

- Android 16 FBE decryption
- KeyMint / Weaver / AuthSecret integration
- Global ID, China, and HyperOS Mod decryption support
- Stable encrypted ↔ decrypted recovery settings lifecycle
- Recovery Password support
- Persistent theme, accent and navigation settings
- Stable Novatek touch support
- Post-Format Data touch recovery
- AW86927 haptic support
- ADB
- MTP
- USB-OTG
- Fastbootd
- Virtual A/B and dynamic partition support
- ZIP / image flashing
- Backup / Restore
- Fenrir Install / Repair
- Recovery Diagnostics
- Storage / Partition Status
- Clear Saved OrangeFox Logs

## Validated Firmware

Runtime validation includes:

- HyperOS `OS3.0.303.0.WPJIDXM`
- HyperOS `OS3.0.304.0.WPJCNXM`

## Installation

Recovery is installed to `vendor_boot`.

```bash
fastboot flash vendor_boot OrangeFox-R12.0-Unofficial-klee-Fenrir-20260820.img
fastboot reboot recovery
```

## Fenrir

For the **first true non-Fenrir → Fenrir conversion**:

```text
Fenrir Install / Repair
        ↓
Format Data
        ↓
Reboot System
```

**Format Data is mandatory before booting System after the first Fenrir conversion.**

If the device is already Fenrir and Fenrir Install / Repair is only verifying or repairing the inactive `vendor_boot` slot, another Format Data is not automatically required.

## Notes

- This is an unofficial OrangeFox build.
- OrangeFox OTA / survival functionality is intentionally unsupported for this release.
- Fenrir is device-specific to `klee`; do not use its assets or procedures on another codename.

## Documentation

- [Installation / Operational Guide](docs/project/INSTALLATION.md)
- [Changelog](docs/project/CHANGELOG.md)
- [Runtime Test Matrix](docs/project/TEST_MATRIX.md)
- [Known Notes / Boundaries](docs/project/KNOWN_NOTES.md)
- [Build History](docs/project/BUILD-HISTORY.md)
- [Technical History](docs/project/TECHNICAL-HISTORY.md)
- [Source Status](docs/project/SOURCE-STATUS.md)
- [Building](docs/project/BUILDING.md)
