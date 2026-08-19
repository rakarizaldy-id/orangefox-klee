#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
SOURCE_ROOT="${1:-$PWD}"
SELF_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec python3 "$SELF_DIR/apply-klee-source-patches.py" "$SOURCE_ROOT"
