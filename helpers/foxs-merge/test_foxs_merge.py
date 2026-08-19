#!/usr/bin/env python3
import os
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

BIN = sys.argv[1]

def serialize(entries, prefix=b"\x10\x00\x01\x00"):
    out = bytearray(prefix)
    for key, value in entries:
        kb = key.encode() + b"\0"
        vb = value.encode() + b"\0"
        out += struct.pack("<H", len(kb)) + kb
        out += struct.pack("<H", len(vb)) + vb
    return bytes(out)

def run(*args):
    p = subprocess.run([BIN, *map(str, args)], capture_output=True, text=True)
    return p.returncode, p.stdout.strip(), p.stderr.strip()

def parse_entries(data, prefix_len=4):
    pos = prefix_len
    result = []
    while pos < len(data):
        kl = struct.unpack_from("<H", data, pos)[0]
        pos += 2
        key = data[pos:pos + kl - 1].decode()
        pos += kl
        vl = struct.unpack_from("<H", data, pos)[0]
        pos += 2
        value = data[pos:pos + vl - 1].decode()
        pos += vl
        result.append((key, value))
    return result

with tempfile.TemporaryDirectory() as td:
    d = Path(td)

    versioned = d / "versioned.foxs"
    headerless = d / "headerless.foxs"
    unknown = d / "unknown.foxs"
    legacy = d / "legacy.foxs"

    versioned.write_bytes(serialize([("b", "2"), ("a", "1")]))
    headerless.write_bytes(serialize([("a", "1")], b""))
    unknown.write_bytes(serialize([("a", "1")], b"\x99\x88\x77\x66"))

    # Legacy-corrupt marker followed by valid native records.
    legacy.write_bytes(
        serialize([("a", "1")], b"\x02\x00\x01\x00\x02\x00X\x00")
    )

    probes = [
        (versioned, 0, "versioned"),
        (headerless, 12, "headerless"),
        (unknown, 13, "unknown-versioned"),
        (legacy, 11, "legacy-corrupt"),
    ]

    for path, expected_rc, expected_text in probes:
        rc, text, _ = run("--probe", path)
        assert (rc, text) == (expected_rc, expected_text), (path, rc, text)

    src = d / "src.foxs"
    dst = d / "dst.foxs"
    allow = d / "allow.list"

    src.write_bytes(serialize([
        ("tw_brightness", "30"),
        ("tw_storage_path", "/SRC"),
        ("center_clock", "1"),
    ]))
    dst.write_bytes(serialize([
        ("tw_storage_path", "/KEEP"),
        ("tw_brightness", "80"),
        ("z", "z"),
    ]))
    allow.write_text("# test\n tw_brightness \ncenter_clock\n")

    inode_before = os.stat(dst).st_ino
    rc, text, _ = run(src, dst, allow)
    assert (rc, text) == (0, "changed")
    assert os.stat(dst).st_ino == inode_before
    assert dst.read_bytes()[:4] == b"\x10\x00\x01\x00"

    entries = parse_entries(dst.read_bytes())
    assert entries == [
        ("center_clock", "1"),
        ("tw_brightness", "30"),
        ("tw_storage_path", "/KEEP"),
        ("z", "z"),
    ]

    rc, text, _ = run(src, dst, allow)
    assert (rc, text) == (10, "unchanged")

    # Headerless self-heal.
    src2 = d / "src2.foxs"
    dst2 = d / "dst2.foxs"
    allow2 = d / "allow2.list"
    src2.write_bytes(serialize([("a", "same")]))
    dst2.write_bytes(serialize([("a", "same")], b""))
    allow2.write_text("a\n")

    rc, text, _ = run(src2, dst2, allow2)
    assert (rc, text) == (0, "changed")
    assert dst2.read_bytes()[:4] == b"\x10\x00\x01\x00"

    # Legacy-corrupt self-heal.
    dst3 = d / "dst3.foxs"
    dst3.write_bytes(
        serialize([("a", "old")], b"\x02\x00\x01\x00\x02\x00X\x00")
    )

    rc, text, _ = run(src2, dst3, allow2)
    assert (rc, text) == (0, "repaired")
    assert run("--probe", dst3)[:2] == (0, "versioned")

print("FOXS-MERGE TEST CORPUS: PASS")
