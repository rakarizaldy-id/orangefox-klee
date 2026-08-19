#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Fail-closed preflight for the clean klee OrangeFox source build."""

from __future__ import annotations

from pathlib import Path
import argparse
import os
import re
import subprocess
import sys

FORBIDDEN_ACTIVE_TOKENS = (
    'BOARD_AVB_ENABLE := true',
    'TW_LOAD_VENDOR_BOOT_MODULES :=',
    'TW_LOAD_VENDOR_MODULES :=',
    'TW_INCLUDE_LPDUMP := true',
    'PRODUCT_TARGET_VNDK_VERSION := 36',
)

REQUIRED_HELPERS = (
    'helpers/aw86927/Android.bp',
    'helpers/aw86927/aw86927_ff_constant_prime_noplay.c',
    'helpers/foxs-merge/Android.bp',
    'helpers/foxs-merge/foxs_merge_v2.c',
    'helpers/omapi-bridge/Android.bp',
    'helpers/omapi-bridge/omapi_bridge.cpp',
    'helpers/omapi-bridge/libcxx_compat.cpp',
)

REQUIRED_DEVICE_FILES = (
    'AndroidProducts.mk',
    'BoardConfig.mk',
    'device.mk',
    'twrp_klee.mk',
    'vendorsetup.sh',
    'proprietary-files.txt',
    'recovery-proprietary.mk',
    'recovery/root/init.recovery.mt6899.rc',
    'recovery/root/init.recovery.project.rc',
    'recovery/root/init.recovery.usb.rc',
    'recovery/root/init.recovery.keymint.rc',
    'recovery/root/init.recovery.bootctl.rc',
    'recovery/root/first_stage_ramdisk/fstab.mt6899',
    'recovery/root/system/etc/recovery.fstab',
    'patches/orangefox/apply-klee-ramdisk.py',
    'patches/twrp/twrp-wrapper.sh',
    'tools/fox-callback.sh',
    'tools/apply-klee-source-patches.py',
    'tools/prepare-klee-stock-inputs.py',
    'tools/repack-klee-vendor-boot.py',
)

REQUIRED_GENERATED_INPUTS = (
    'prebuilt/generated/platform-vendor-ramdisk.cpio.lz4',
    'prebuilt/generated/mt6899-klee.dtb',
    'prebuilt/generated/dtbo.img',
    'prebuilt/generated/stock-input-report.txt',
)

REQUIRED_PRIVATE_MODULES = (
    'klee_android.hardware.secure_element-V1-ndk',
    'klee_android.se.omapi-V1-ndk',
)


def green(msg: str):
    print(f'PASS  {msg}')


def warn(msg: str):
    print(f'WARN  {msg}')


def error(errors: list[str], msg: str):
    errors.append(msg)
    print(f'FAIL  {msg}')


def read_text(path: Path) -> str:
    return path.read_text(encoding='utf-8', errors='replace')


def active_lines(text: str):
    for raw in text.splitlines():
        stripped = raw.strip()
        if not stripped or stripped.startswith('#'):
            continue
        yield stripped


def proprietary_paths(device_dir: Path) -> list[str]:
    result = []
    for raw in read_text(device_dir / 'proprietary-files.txt').splitlines():
        line = raw.strip()
        if not line or line.startswith('#'):
            continue
        # ExtractUtils syntax can grow annotations; keep the source path only.
        line = line.lstrip('-')
        source = line.split('|', 1)[0].split(':', 1)[0].strip()
        if source:
            result.append(source)
    return result


def find_module_names(vendor_root: Path) -> set[str]:
    names: set[str] = set()
    for p in vendor_root.rglob('Android.bp'):
        text = read_text(p)
        names.update(re.findall(r'\bname\s*:\s*"([^"]+)"', text))
    for p in vendor_root.rglob('Android.mk'):
        text = read_text(p)
        names.update(re.findall(r'(?m)^LOCAL_MODULE\s*:?=\s*([^\s#]+)', text))
    return names


def check_device(device_dir: Path, errors: list[str], require_generated: bool):
    if not device_dir.is_dir():
        error(errors, f'device tree missing: {device_dir}')
        return

    for rel in REQUIRED_DEVICE_FILES + REQUIRED_HELPERS:
        p = device_dir / rel
        if p.is_file():
            green(rel)
        else:
            error(errors, f'missing device-tree file: {rel}')

    combined = ''
    for name in ('BoardConfig.mk', 'device.mk', 'twrp_klee.mk', 'vendorsetup.sh'):
        p = device_dir / name
        if p.is_file():
            combined += '\n' + read_text(p)

    active = '\n'.join(active_lines(combined))
    for token in FORBIDDEN_ACTIVE_TOKENS:
        if token in active:
            error(errors, f'stale/forbidden active config: {token}')
        else:
            green(f'forbidden config absent: {token}')

    # Project invariants from Steps 14-16.
    invariants = {
        'PRODUCT_SHIPPING_API_LEVEL := 34': device_dir / 'device.mk',
        'core_64_bit_only.mk': device_dir / 'twrp_klee.mk',
        'TW_MAX_BRIGHTNESS := 16383': device_dir / 'BoardConfig.mk',
        'TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888': device_dir / 'BoardConfig.mk',
        'FOX_VENDOR_BOOT_RECOVERY=1': device_dir / 'vendorsetup.sh',
        'FOX_LOCAL_CALLBACK_SCRIPT=': device_dir / 'vendorsetup.sh',
        'OF_ENABLE_LPTOOLS=1': device_dir / 'vendorsetup.sh',
        'OF_USE_DMCTL=1': device_dir / 'vendorsetup.sh',
    }
    for marker, p in invariants.items():
        if p.is_file() and marker in read_text(p):
            green(f'invariant: {marker}')
        else:
            error(errors, f'missing invariant: {marker}')

    first_stage = device_dir / 'recovery/root/first_stage_ramdisk/fstab.mt6899'
    if first_stage.is_file():
        fst = read_text(first_stage)
        if re.search(r'(^|[,\s])(avb(?:=|\b)|verify(?:=|\b))', fst):
            error(errors, 'first-stage fstab unexpectedly contains AVB/verify flag')
        else:
            green('first-stage fstab keeps project no-AVB fs_mgr policy')

    if 'ALLOW_MISSING_DEPENDENCIES := true' in combined or 'ALLOW_MISSING_DEPENDENCIES=true' in combined:
        warn('ALLOW_MISSING_DEPENDENCIES is still enabled for first clean build; remove after dependencies resolve')

    if require_generated:
        for rel in REQUIRED_GENERATED_INPUTS:
            p = device_dir / rel
            if p.is_file() and p.stat().st_size > 0:
                green(f'generated hardware input: {rel}')
            else:
                error(errors, f'missing generated hardware input: {rel}')

        report = device_dir / 'prebuilt/generated/stock-input-report.txt'
        if report.is_file():
            rt = read_text(report)
            for marker in ('platform_build60_match=True', 'dtb_build60_match=True'):
                if marker in rt:
                    green(f'stock input report: {marker}')
                else:
                    error(errors, f'stock input report missing release gate: {marker}')


def check_source(source_root: Path, device_dir: Path, errors: list[str]):
    required = (
        'build/envsetup.sh',
        'bootable/recovery/variables.h',
        'bootable/recovery/partition.cpp',
        'vendor/recovery',
    )
    for rel in required:
        p = source_root / rel
        if p.exists():
            green(f'source: {rel}')
        else:
            error(errors, f'OrangeFox source missing: {rel}')

    patcher = device_dir / 'tools/apply-klee-source-patches.py'
    if patcher.is_file() and (source_root / 'bootable/recovery').is_dir():
        cp = subprocess.run(
            [sys.executable, str(patcher), str(source_root), '--check'],
            capture_output=True, text=True,
        )
        if cp.returncode == 0:
            green('OrangeFox core source patches applied')
        else:
            detail = (cp.stderr or cp.stdout).strip()
            error(errors, f'OrangeFox core source patch check failed: {detail}')


def check_vendor(source_root: Path, device_dir: Path, errors: list[str]):
    vendor_root = source_root / 'vendor/xiaomi/klee'
    prop_root = vendor_root / 'proprietary'
    if not vendor_root.is_dir():
        error(errors, 'generated vendor repo missing: vendor/xiaomi/klee')
        return
    green('generated vendor repo exists: vendor/xiaomi/klee')

    missing = []
    for rel in proprietary_paths(device_dir):
        p = prop_root / rel
        if not p.is_file():
            missing.append(rel)
    if missing:
        sample = ', '.join(missing[:6])
        suffix = '' if len(missing) <= 6 else f' (+{len(missing)-6} more)'
        error(errors, f'{len(missing)} proprietary inputs missing: {sample}{suffix}')
    else:
        green(f'all {len(proprietary_paths(device_dir))} proprietary inputs exist')

    names = find_module_names(vendor_root)
    for module in REQUIRED_PRIVATE_MODULES:
        if module in names:
            green(f'generated private module: {module}')
        else:
            error(errors, f'generated vendor makefiles do not define module: {module}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--source-root', type=Path, default=Path(os.environ.get('ANDROID_BUILD_TOP', '.')))
    ap.add_argument('--device-dir', type=Path)
    ap.add_argument('--device-only', action='store_true', help='check committed tree only; skip stock/vendor/source requirements')
    args = ap.parse_args()

    source_root = args.source_root.resolve()
    device_dir = args.device_dir.resolve() if args.device_dir else (source_root / 'device/xiaomi/klee')
    errors: list[str] = []

    print('KLEE CLEAN BUILD PREFLIGHT')
    print(f'source_root={source_root}')
    print(f'device_dir={device_dir}')
    print(f'mode={"device-only" if args.device_only else "full"}')
    print()

    check_device(device_dir, errors, require_generated=not args.device_only)
    if not args.device_only:
        check_source(source_root, device_dir, errors)
        check_vendor(source_root, device_dir, errors)

    print()
    if errors:
        print(f'KLEE PREFLIGHT: FAIL ({len(errors)} issue(s))')
        for i, msg in enumerate(errors, 1):
            print(f' {i}. {msg}')
        return 2

    print('KLEE PREFLIGHT: PASS')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
