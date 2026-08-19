# Step 14 — Hardware build-input strategy

## Build60 vendor_boot v4 golden geometry

Directly parsed from `60.img`:

| Field | Build60 |
|---|---:|
| header version | 4 |
| page size | 4096 |
| header size | 2128 |
| partition/image size | 67,108,864 |
| vendor ramdisk combined size | 63,509,218 |
| DTB section size | 447,276 |
| ramdisk table entries | 2 |
| table entry size | 108 |
| bootconfig | 0 |
| kernel address | `0x40000000` |
| ramdisk address | `0x66f00000` |
| tags address | `0x47c80000` |
| DTB address | `0x47c80000` |
| vendor cmdline | `bootopt=64S3,32N2,64N2 erofs.reserved_pages=64` |

The validated base/offset representation is:

```text
base           = 0x3fff8000
kernel_offset  = 0x00008000
ramdisk_offset = 0x26f08000
tags_offset    = 0x07c88000
dtb_offset     = 0x07c88000
```

## Golden component hashes

```text
full vendor_boot
aa7fdc2ebc9f30ecbeaf18a6d982fd86de782600bdd30adf676a17c22e4d0251

PLATFORM fragment (legacy LZ4)
7851f553ccfc14564ffb9c969100ef1c26d8c0684e0b7d9fb26b6000a168801c

RECOVERY fragment (Build60)
ef47aa03b3e46f64299a8bcf76ad1c2f9b62080dbe570118596f6448db666017

DTB wrapper section
0e9e85739150973efff32d8ee9a1727e2442cf8a8ca5c97ebff585268cdb8bc4

inner FDT payload
244ec61c5d16ef1318a3244b00d251468261d8f0e098a02e3737a91a37ef483a

validated live DTBO A/B
aa1091f40a1b3c970e304b39180f8ad38ff4ed675b85b1b9963d9c1e610846e3
```

The DTB section has a 64-byte MediaTek/device wrapper followed by one FDT
whose total size consumes the rest of the section.

## PLATFORM strategy

Build60's PLATFORM fragment contains **244 kernel modules** plus first-stage
fstab, SELinux contexts, properties, and other vendor-ramdisk state.

Those files are stock/device hardware payload, not OrangeFox source.

The clean strategy is therefore:

```text
validated stock vendor_boot
        |
        +--> extract PLATFORM compressed fragment
        |        |
        |        +--> decompress legacy LZ4
        |        +--> replace only:
        |             first_stage_ramdisk/fstab.mt6899
        |             with source-owned Step4 fstab
        |        +--> recompress legacy LZ4 HC12
        |
        +--> extract DTB section
```

The transform is fail-closed: with the intended stock baseline, the resulting
PLATFORM and DTB must match the Build60 golden hashes before a release build.

No PLATFORM `.ko` is committed to the public device tree.

## Why not `BOARD_VENDOR_RAMDISK_FRAGMENTS := platform`

Build60's table entry 0 is the **default PLATFORM ramdisk**:
- type `PLATFORM`;
- empty ramdisk name;
- offset 0.

A named AOSP vendor-ramdisk fragment would introduce a different table identity.
Rather than carry hundreds of stock files into the public tree or create a
gratuitous table-layout difference, Step14 keeps the stock PLATFORM fragment
outside source and performs one deterministic final vendor_boot repack.

## RECOVERY strategy

OrangeFox source builds the RECOVERY ramdisk fragment.

The final image is assembled as:

```text
vendor_boot header v4
├── PLATFORM  ← validated stock-derived, first-stage fstab patched
├── RECOVERY  ← current source build
├── DTB       ← validated stock-derived
└── table     ← exactly two entries
```

`tools/repack-klee-vendor-boot.py` implements this final composition.

When fed the Build60 PLATFORM, RECOVERY and DTB components, the packer produces
the **exact 64 MiB Build60 image byte-for-byte**. This is used as a structural
self-test; future source builds are expected to differ in the RECOVERY payload.

## Kernel strategy

`klee` recovery does not replace the `boot` partition kernel.

Therefore:

```make
TARGET_NO_KERNEL := true
BOARD_USES_GENERIC_KERNEL_IMAGE := true
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
```

The Android boot partition remains untouched by recovery construction.

## vendor_dlkm / touch modules

The final Build60 `load-touch-modules.sh` explicitly mounts `/vendor_dlkm` and
loads:

```text
/vendor_dlkm/lib/modules/nt38771_touch_klee.ko
/vendor_dlkm/lib/modules/xiaomi_touch_klee.ko
```

Then it unmounts `/vendor_dlkm`.

Therefore the two recovery-root `.ko` copies found in Build60 are not required
for the clean tree and remain excluded.

The old tree's `TW_LOAD_VENDOR_BOOT_MODULES` / `TW_LOAD_VENDOR_MODULES` path is
also excluded because it would reintroduce duplicate module staging/loading and
does not represent the validated final script path.

## DTBO strategy

`dtbo` is a separate 8 MiB A/B partition. Recovery does not need to rebuild it.

For build metadata and tooling, a local ignored `dtbo.img` is prepared from
validated stock. The known live A/B hash is recorded as a comparison point, but
stock provenance is still verified when the official image is supplied.

## Public-tree boundary

Committed:
- parsers/repack tools;
- source-owned first-stage fstab;
- BoardConfig geometry;
- hashes/provenance documentation.

Not committed:
- PLATFORM ramdisk;
- DTB;
- DTBO;
- stock kernel modules.

This is intentional.
