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

**OrangeFox R12.0 Build60 FINAL**

Build60 is the current runtime-validated release for `klee`.

SHA256:

```text
aa7fdc2ebc9f30ecbeaf18a6d982fd86de782600bdd30adf676a17c22e4d0251
```

[Download OrangeFox R12.0 Build60 FINAL](https://github.com/rakarizaldy-id/orangefox-klee/releases/tag/R12.0-Build60)

## Features

- Android 16 FBE decryption
- IDXM and Pure CN decryption support
- Stable Novatek touch support
- Post-Format Data touch recovery
- AW86927 haptic support
- OrangeFox settings persistence
- Fastbootd support
- Dynamic partition / SUPER support
- Recovery Self-Test
- Storage / Partition Health
- Clear OrangeFox Logs
- Fenrir Install / Repair support


## Installation

Recovery is installed to `vendor_boot`.

```bash
fastboot flash vendor_boot OrangeFox-R12.0-Unofficial-klee-RakaRizaldy-Fenrir-Build60-20260819-FINAL-MASTER-RELEASE.img
fastboot reboot recovery
```


For first conversion to Fenrir:

Fenrir Install / Repair
        ↓
Format Data
        ↓
Reboot System


Format Data is mandatory for the first Fenrir conversion.

Full instructions are available in [Installation Guide](docs/project/INSTALLATION.md).