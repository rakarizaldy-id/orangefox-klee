#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0

from pathlib import Path
import argparse
import shutil
import sys

from klee_vendor_boot import (
    BUILD60_DTB_SHA256,
    BUILD60_PLATFORM_SHA256,
    LIVE_DTBO_SHA256,
    cpio_replace_newc,
    extract_fragments,
    legacy_lz4_compress,
    legacy_lz4_decompress,
    sha256_bytes,
    sha256_file,
)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--vendor-boot", required=True, type=Path)
    ap.add_argument("--dtbo", type=Path)
    ap.add_argument("--device-dir", required=True, type=Path)
    ap.add_argument(
        "--no-strict-build60",
        action="store_true",
        help="write outputs even if PLATFORM/DTB hashes differ from Build60 golden",
    )
    args = ap.parse_args()

    device_dir = args.device_dir.resolve()
    out_dir = device_dir / "prebuilt/generated"
    out_dir.mkdir(parents=True, exist_ok=True)

    vb = args.vendor_boot.read_bytes()
    header, fragments, dtb = extract_fragments(vb)

    platform_candidates = [(e, blob) for e, blob in fragments if e.ramdisk_type == 1]
    if len(platform_candidates) != 1:
        raise SystemExit(
            f"expected exactly one PLATFORM ramdisk in stock vendor_boot, got {len(platform_candidates)}"
        )

    entry, platform_blob = platform_candidates[0]
    raw_cpio = legacy_lz4_decompress(platform_blob)

    fstab_path = device_dir / "recovery/root/first_stage_ramdisk/fstab.mt6899"
    if not fstab_path.is_file():
        raise SystemExit(f"missing source-owned first-stage fstab: {fstab_path}")

    patched_cpio = cpio_replace_newc(
        raw_cpio,
        "first_stage_ramdisk/fstab.mt6899",
        fstab_path.read_bytes(),
    )
    patched_platform = legacy_lz4_compress(patched_cpio)

    platform_sha = sha256_bytes(patched_platform)
    dtb_sha = sha256_bytes(dtb)

    strict = not args.no_strict_build60
    failures = []
    if platform_sha != BUILD60_PLATFORM_SHA256:
        failures.append(
            f"PLATFORM mismatch: {platform_sha} != {BUILD60_PLATFORM_SHA256}"
        )
    if dtb_sha != BUILD60_DTB_SHA256:
        failures.append(
            f"DTB mismatch: {dtb_sha} != {BUILD60_DTB_SHA256}"
        )

    if failures and strict:
        print("KLEE STOCK INPUT PREP: FAIL-CLOSED", file=sys.stderr)
        for line in failures:
            print(" - " + line, file=sys.stderr)
        print(
            "Use --no-strict-build60 only for diagnosis; do not release such output.",
            file=sys.stderr,
        )
        return 2

    platform_out = out_dir / "platform-vendor-ramdisk.cpio.lz4"
    dtb_out = out_dir / "mt6899-klee.dtb"
    platform_out.write_bytes(patched_platform)
    dtb_out.write_bytes(dtb)

    dtbo_status = "not supplied"
    if args.dtbo:
        dtbo_out = out_dir / "dtbo.img"
        shutil.copyfile(args.dtbo, dtbo_out)
        dtbo_sha = sha256_file(dtbo_out)
        dtbo_status = (
            f"{dtbo_sha} "
            + ("(matches validated live A/B)" if dtbo_sha == LIVE_DTBO_SHA256
               else "(DIFFERS from validated live A/B; investigate before release)")
        )

    report = f"""KLEE STOCK INPUT PREPARATION
vendor_boot={args.vendor_boot}
header_version={header.header_version}
page_size={header.page_size}
vendor_cmdline={header.cmdline}
platform_name={entry.name!r}
platform_type={entry.ramdisk_type}
platform_sha256={platform_sha}
platform_build60_match={platform_sha == BUILD60_PLATFORM_SHA256}
dtb_sha256={dtb_sha}
dtb_build60_match={dtb_sha == BUILD60_DTB_SHA256}
dtbo={dtbo_status}
"""
    (out_dir / "stock-input-report.txt").write_text(report, encoding="utf-8")
    print(report, end="")
    if failures:
        print("WARNING: diagnostic output differs from Build60 golden")
    else:
        print("KLEE STOCK INPUT PREP: PASS")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
