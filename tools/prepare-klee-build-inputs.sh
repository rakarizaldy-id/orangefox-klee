#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Prepare the two non-source input layers before the first clean build.

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "usage: $0 STOCK_VENDOR_BOOT.img STOCK_DTBO.img [EXTRACT_SOURCE_DIR]" >&2
    echo "" >&2
    echo "EXTRACT_SOURCE_DIR is an unpacked stock-root accepted by extract-files.py." >&2
    exit 64
fi

TOP="${ANDROID_BUILD_TOP:-$(pwd)}"
DEVICE_DIR="$TOP/device/xiaomi/klee"
VENDOR_BOOT="$1"
DTBO="$2"
EXTRACT_SOURCE="${3:-}"

cd "$TOP"

python3 "$DEVICE_DIR/tools/prepare-klee-stock-inputs.py" \
    --vendor-boot "$VENDOR_BOOT" \
    --dtbo "$DTBO" \
    --device-dir "$DEVICE_DIR"

if [[ -n "$EXTRACT_SOURCE" ]]; then
    "$DEVICE_DIR/extract-files.py" "$EXTRACT_SOURCE"
    "$DEVICE_DIR/setup-makefiles.py"
else
    echo "I: hardware inputs prepared. Proprietary extraction skipped because EXTRACT_SOURCE_DIR was omitted."
fi
