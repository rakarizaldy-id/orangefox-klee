#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Clean first-build harness for POCO X8 Pro (klee), OrangeFox fox_12.1.

set -euo pipefail

TOP="${ANDROID_BUILD_TOP:-$(pwd)}"
DEVICE_DIR="$TOP/device/xiaomi/klee"
OUT_PRODUCT="$TOP/out/target/product/klee"

if [[ ! -f "$TOP/build/envsetup.sh" ]]; then
    echo "E: run this from the Android/OrangeFox source root" >&2
    exit 2
fi
if [[ ! -d "$DEVICE_DIR" ]]; then
    echo "E: missing device tree: $DEVICE_DIR" >&2
    exit 2
fi

cd "$TOP"

# 1. Patch only the two validated recovery-core deltas. The patcher is
# fail-closed and idempotent.
python3 "$DEVICE_DIR/tools/apply-klee-source-patches.py" "$TOP"
python3 "$DEVICE_DIR/tools/apply-klee-source-patches.py" "$TOP" --check

# 2. Make OrangeFox/TWRP environment functions available, then explicitly
# source the device exports so the FOX_* variables are guaranteed in this shell.
# shellcheck disable=SC1091
source build/envsetup.sh
# shellcheck disable=SC1091
source "$DEVICE_DIR/vendorsetup.sh"

# 3. Refuse to compile with missing stock/vendor inputs or un-applied patches.
python3 "$DEVICE_DIR/tools/preflight-klee-build.py" \
    --source-root "$TOP" \
    --device-dir "$DEVICE_DIR"

# 4. Standard OrangeFox/TWRP product selection.
lunch twrp_klee-eng

mkdir -p "$OUT_PRODUCT"
LOG="$OUT_PRODUCT/klee-first-source-build.log"

# 5. Build adbd plus vendor_boot-as-recovery. The produced vendor_boot is the
# source-build carrier used by Step18 to extract/compare the RECOVERY fragment;
# final Build60-style PLATFORM+RECOVERY+DTB composition remains a separate,
# deterministic Step14/18 repack operation.
set +e
mka adbd vendorbootimage 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
set -e

if [[ $status -ne 0 ]]; then
    echo
    echo "KLEE FIRST SOURCE BUILD: FAIL (status=$status)"
    echo "log=$LOG"
    exit "$status"
fi

echo
echo "KLEE FIRST SOURCE BUILD: PASS"
echo "log=$LOG"

if [[ -f "$OUT_PRODUCT/vendor_boot.img" ]]; then
    sha256sum "$OUT_PRODUCT/vendor_boot.img"
    echo "artifact=$OUT_PRODUCT/vendor_boot.img"
else
    echo "W: build passed but vendor_boot.img was not found at the usual product path" >&2
fi

echo
echo "Candidate recovery/vendor ramdisk outputs:"
find "$OUT_PRODUCT" -maxdepth 3 -type f \
    \( -iname '*vendor*ramdisk*' -o -iname '*recovery*ramdisk*' -o -name 'vendor_boot.img' \) \
    -print | sort || true
