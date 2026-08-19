#!/usr/bin/env python3
"""
Compare an extracted/vendor source tree or unpacked recovery against the
Build60 golden SHA256 manifest.

This is a diagnostic tool, not a license/provenance substitute.
"""
from pathlib import Path
import argparse
import hashlib
import sys

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", type=Path, help="root containing vendor/, system/, etc.")
    ap.add_argument(
        "--manifest",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "BUILD60-BLOB-SHA256SUMS.txt",
    )
    args = ap.parse_args()

    failures = 0
    checked = 0
    for raw in args.manifest.read_text().splitlines():
        raw = raw.strip()
        if not raw or raw.startswith("#"):
            continue
        expected, rel = raw.split(maxsplit=1)
        path = args.root / rel
        if not path.is_file():
            print(f"MISSING  {rel}")
            failures += 1
            continue
        actual = sha256(path)
        checked += 1
        if actual == expected:
            print(f"PASS     {rel}")
        else:
            print(f"MISMATCH {rel}")
            print(f"         expected {expected}")
            print(f"         actual   {actual}")
            failures += 1

    print(f"\nchecked={checked} failures={failures}")
    return 1 if failures else 0

if __name__ == "__main__":
    raise SystemExit(main())
