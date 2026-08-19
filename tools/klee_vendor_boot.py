#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
#
# Shared helpers for klee vendor_boot v4 reconstruction.

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import hashlib
import struct

VENDOR_BOOT_MAGIC = b"VNDRBOOT"
LEGACY_LZ4_MAGIC = bytes.fromhex("02214c18")
PAGE_SIZE = 4096

# Build60 golden constants.
BUILD60_VENDOR_BOOT_SHA256 = "aa7fdc2ebc9f30ecbeaf18a6d982fd86de782600bdd30adf676a17c22e4d0251"
BUILD60_PLATFORM_SHA256 = "7851f553ccfc14564ffb9c969100ef1c26d8c0684e0b7d9fb26b6000a168801c"
BUILD60_RECOVERY_SHA256 = "ef47aa03b3e46f64299a8bcf76ad1c2f9b62080dbe570118596f6448db666017"
BUILD60_DTB_SHA256 = "0e9e85739150973efff32d8ee9a1727e2442cf8a8ca5c97ebff585268cdb8bc4"
BUILD60_INNER_FDT_SHA256 = "244ec61c5d16ef1318a3244b00d251468261d8f0e098a02e3737a91a37ef483a"
LIVE_DTBO_SHA256 = "aa1091f40a1b3c970e304b39180f8ad38ff4ed675b85b1b9963d9c1e610846e3"

@dataclass
class VendorBootHeader:
    header_version: int
    page_size: int
    kernel_addr: int
    ramdisk_addr: int
    vendor_ramdisk_size: int
    cmdline: str
    tags_addr: int
    name: str
    header_size: int
    dtb_size: int
    dtb_addr: int
    table_size: int
    table_entries: int
    table_entry_size: int
    bootconfig_size: int

@dataclass
class RamdiskEntry:
    size: int
    offset: int
    ramdisk_type: int
    name: str
    board_id: tuple[int, ...]

def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def align(value: int, page: int = PAGE_SIZE) -> int:
    return (value + page - 1) // page * page

def parse_header(image: bytes) -> VendorBootHeader:
    if image[:8] != VENDOR_BOOT_MAGIC:
        raise ValueError("not a vendor_boot image")
    header_version = struct.unpack_from("<I", image, 8)[0]
    if header_version != 4:
        raise ValueError(f"klee reconstruction requires vendor_boot header v4, got {header_version}")
    page_size = struct.unpack_from("<I", image, 12)[0]
    if page_size != PAGE_SIZE:
        raise ValueError(f"unexpected page size {page_size}")

    off = 16
    kernel_addr, ramdisk_addr, vendor_ramdisk_size = struct.unpack_from("<III", image, off)
    off += 12
    cmdline = image[off:off + 2048].split(b"\0", 1)[0].decode(errors="replace")
    off += 2048
    tags_addr = struct.unpack_from("<I", image, off)[0]
    off += 4
    name = image[off:off + 16].split(b"\0", 1)[0].decode(errors="replace")
    off += 16
    header_size = struct.unpack_from("<I", image, off)[0]
    off += 4
    dtb_size = struct.unpack_from("<I", image, off)[0]
    off += 4
    dtb_addr = struct.unpack_from("<Q", image, off)[0]
    off += 8
    table_size, table_entries, table_entry_size, bootconfig_size = struct.unpack_from(
        "<IIII", image, off
    )
    return VendorBootHeader(
        header_version, page_size, kernel_addr, ramdisk_addr,
        vendor_ramdisk_size, cmdline, tags_addr, name, header_size,
        dtb_size, dtb_addr, table_size, table_entries,
        table_entry_size, bootconfig_size
    )

def section_offsets(header: VendorBootHeader):
    header_page_end = align(header.header_size, header.page_size)
    ramdisk_off = header_page_end
    ramdisk_end = ramdisk_off + header.vendor_ramdisk_size
    dtb_off = align(ramdisk_end, header.page_size)
    dtb_end = dtb_off + header.dtb_size
    table_off = align(dtb_end, header.page_size)
    table_end = table_off + header.table_size
    bootconfig_off = align(table_end, header.page_size)
    return ramdisk_off, ramdisk_end, dtb_off, dtb_end, table_off, table_end, bootconfig_off

def parse_entries(image: bytes, header: VendorBootHeader):
    *_, table_off, table_end, _ = section_offsets(header)
    if header.table_entry_size != 108:
        raise ValueError(f"unexpected ramdisk table entry size {header.table_entry_size}")
    if header.table_size != header.table_entries * header.table_entry_size:
        raise ValueError("ramdisk table size/entry count mismatch")
    entries = []
    for i in range(header.table_entries):
        off = table_off + i * header.table_entry_size
        size, roff, rtype = struct.unpack_from("<III", image, off)
        name = image[off + 12:off + 44].split(b"\0", 1)[0].decode(errors="replace")
        board_id = struct.unpack_from("<16I", image, off + 44)
        entries.append(RamdiskEntry(size, roff, rtype, name, board_id))
    return entries

def extract_fragments(image: bytes):
    header = parse_header(image)
    entries = parse_entries(image, header)
    ramdisk_off, _, dtb_off, dtb_end, *_ = section_offsets(header)
    fragments = []
    for e in entries:
        start = ramdisk_off + e.offset
        fragments.append((e, image[start:start + e.size]))
    dtb = image[dtb_off:dtb_end]
    return header, fragments, dtb

def legacy_lz4_decompress(blob: bytes) -> bytes:
    if not blob.startswith(LEGACY_LZ4_MAGIC):
        raise ValueError("not an Android legacy-LZ4 ramdisk")
    try:
        import lz4.block
    except ImportError as exc:
        raise RuntimeError("python lz4 module is required: install python3-lz4") from exc

    pos = 4
    out = bytearray()
    while pos < len(blob):
        if pos + 4 > len(blob):
            raise ValueError("truncated legacy-LZ4 block header")
        size = struct.unpack_from("<I", blob, pos)[0]
        pos += 4
        if size == 0:
            if pos != len(blob):
                raise ValueError("unexpected data after legacy-LZ4 terminator")
            break
        if pos + size > len(blob):
            raise ValueError("truncated legacy-LZ4 block")
        block = blob[pos:pos + size]
        pos += size
        # Android legacy frames use 8 MiB uncompressed blocks.
        out += lz4.block.decompress(block, uncompressed_size=8 * 1024 * 1024)
    return bytes(out)

def legacy_lz4_compress(raw: bytes) -> bytes:
    try:
        import lz4.block
    except ImportError as exc:
        raise RuntimeError("python lz4 module is required: install python3-lz4") from exc

    out = bytearray(LEGACY_LZ4_MAGIC)
    block_size = 8 * 1024 * 1024
    for off in range(0, len(raw), block_size):
        block = raw[off:off + block_size]
        # HC level 12 reproduces Build60's legacy-LZ4 stream byte-for-byte
        # when the input CPIO is unchanged.
        compressed = lz4.block.compress(
            block,
            mode="high_compression",
            compression=12,
            store_size=False,
        )
        out += struct.pack("<I", len(compressed))
        out += compressed
    return bytes(out)

def cpio_replace_newc(cpio: bytes, target_name: str, replacement: bytes) -> bytes:
    pos = 0
    out = bytearray()
    found = 0

    while True:
        if pos + 110 > len(cpio):
            raise ValueError("truncated newc header")
        header = bytearray(cpio[pos:pos + 110])
        magic = header[:6]
        if magic not in (b"070701", b"070702"):
            raise ValueError(f"unexpected CPIO magic at {pos}: {magic!r}")

        fields = [int(header[6 + i*8:14 + i*8], 16) for i in range(13)]
        filesize = fields[6]
        namesize = fields[11]

        name_start = pos + 110
        name_end = name_start + namesize
        if name_end > len(cpio):
            raise ValueError("truncated CPIO name")
        name_raw = cpio[name_start:name_end]
        name = name_raw[:-1].decode(errors="surrogateescape") if name_raw.endswith(b"\0") else ""
        name_padded_end = align(name_end, 4)
        data_start = name_padded_end
        data_end = data_start + filesize
        if data_end > len(cpio):
            raise ValueError("truncated CPIO data")
        data = cpio[data_start:data_end]
        next_pos = align(data_end, 4)

        if name == target_name:
            found += 1
            data = replacement
            header[54:62] = f"{len(data):08x}".encode()

        out += header
        out += name_raw
        out += b"\0" * (align(len(out), 4) - len(out))
        out += data
        out += b"\0" * (align(len(out), 4) - len(out))

        pos = next_pos
        if name == "TRAILER!!!":
            # Preserve any trailing bytes after the archive exactly.
            out += cpio[pos:]
            break

    if found != 1:
        raise ValueError(f"expected exactly one {target_name!r}, found {found}")
    return bytes(out)

def build_vendor_boot_v4(
    template: bytes,
    platform_fragment: bytes,
    recovery_fragment: bytes,
    dtb: bytes,
    partition_size: int = 67108864,
) -> bytes:
    h = parse_header(template)

    # Fail closed on the Build60-relevant geometry.
    expected = {
        "header_size": 2128,
        "page_size": 4096,
        "kernel_addr": 0x40000000,
        "ramdisk_addr": 0x66F00000,
        "tags_addr": 0x47C80000,
        "dtb_addr": 0x47C80000,
        "bootconfig_size": 0,
    }
    for key, value in expected.items():
        actual = getattr(h, key)
        if actual != value:
            raise ValueError(f"template {key} mismatch: got {actual:#x}, expected {value:#x}")

    header_page = bytearray(template[:h.page_size])
    struct.pack_into("<I", header_page, 24, len(platform_fragment) + len(recovery_fragment))
    struct.pack_into("<I", header_page, 2100, len(dtb))
    struct.pack_into("<I", header_page, 2112, 216)
    struct.pack_into("<I", header_page, 2116, 2)
    struct.pack_into("<I", header_page, 2120, 108)
    struct.pack_into("<I", header_page, 2124, 0)

    image = bytearray(header_page)
    image += platform_fragment
    image += recovery_fragment
    image += b"\0" * (align(len(image), h.page_size) - len(image))
    image += dtb
    image += b"\0" * (align(len(image), h.page_size) - len(image))

    zero_board_id = [0] * 16
    image += struct.pack(
        "<III32s16I",
        len(platform_fragment), 0, 1, b"", *zero_board_id
    )
    image += struct.pack(
        "<III32s16I",
        len(recovery_fragment), len(platform_fragment), 2, b"recovery", *zero_board_id
    )
    image += b"\0" * (align(len(image), h.page_size) - len(image))

    if len(image) > partition_size:
        raise ValueError(
            f"reconstructed vendor_boot is {len(image)} bytes, larger than partition {partition_size}"
        )
    image += b"\0" * (partition_size - len(image))
    return bytes(image)
