#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0

from pathlib import Path
import argparse

from klee_vendor_boot import (
    BUILD60_VENDOR_BOOT_SHA256,
    build_vendor_boot_v4,
    sha256_bytes,
)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--template", required=True, type=Path,
                    help="validated stock vendor_boot v4 used for header geometry")
    ap.add_argument("--platform", required=True, type=Path)
    ap.add_argument("--recovery", required=True, type=Path,
                    help="source-built compressed recovery vendor ramdisk fragment")
    ap.add_argument("--dtb", required=True, type=Path)
    ap.add_argument("--output", required=True, type=Path)
    ap.add_argument("--partition-size", type=int, default=67108864)
    ap.add_argument("--expect-build60", action="store_true",
                    help="self-test mode: require exact Build60 full-image hash")
    args = ap.parse_args()

    image = build_vendor_boot_v4(
        args.template.read_bytes(),
        args.platform.read_bytes(),
        args.recovery.read_bytes(),
        args.dtb.read_bytes(),
        args.partition_size,
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(image)
    digest = sha256_bytes(image)
    print(f"output={args.output}")
    print(f"size={len(image)}")
    print(f"sha256={digest}")

    if args.expect_build60 and digest != BUILD60_VENDOR_BOOT_SHA256:
        print(f"FAIL: expected Build60 {BUILD60_VENDOR_BOOT_SHA256}")
        return 2

    if args.expect_build60:
        print("KLEE VENDOR_BOOT REPACK EXACT-GOLDEN: PASS")
    else:
        print("KLEE VENDOR_BOOT REPACK: PASS")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
