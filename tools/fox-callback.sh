#!/bin/bash
#
# OrangeFox local callback for POCO X8 Pro (klee)
#
set -euo pipefail

RAMDISK="${1:-}"
PHASE="${2:-}"

SELF_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
DEVICE_DIR="$(dirname "$SELF_DIR")"

case "$PHASE" in
    --first-call)
        echo "I:klee callback: applying Build60-equivalent ramdisk deltas"
        python3 "$DEVICE_DIR/patches/orangefox/apply-klee-ramdisk.py" "$RAMDISK" "$DEVICE_DIR"
        ;;
    --last-call)
        # No release-zip mutation is required at this reconstruction stage.
        echo "I:klee callback: last-call no-op"
        ;;
    *)
        echo "E:klee callback: unexpected phase '$PHASE'" >&2
        exit 2
        ;;
esac
