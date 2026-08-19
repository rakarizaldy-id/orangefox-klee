#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Apply minimal Klee recovery-core deltas to OrangeFox fox_12.1.

Fail-closed and idempotent. Modifies only:
  * bootable/recovery/variables.h
  * bootable/recovery/partition.cpp
"""
from pathlib import Path
import argparse
import re

BRANCH_LINE = '#define FOX_BRANCH\t\t"klee"'
ODM_MARKER = 'KleeOdmEbusySourceFixV1'


def fail(msg: str):
    raise SystemExit('KLEE SOURCE PATCH ERROR: ' + msg)


def recovery_dir(root: Path) -> Path:
    root = root.resolve()
    if (root / 'variables.h').is_file() and (root / 'partition.cpp').is_file():
        return root
    candidate = root / 'bootable/recovery'
    if candidate.is_dir():
        return candidate
    fail(f'cannot find bootable/recovery below {root}')


def patch_branch(path: Path) -> bool:
    text = path.read_text(encoding='utf-8')
    lines = re.findall(r'(?m)^#define[ \t]+FOX_BRANCH[ \t]+.*$', text)
    if len(lines) != 1:
        fail(f'{path}: expected exactly one FOX_BRANCH define, found {len(lines)}')
    if re.fullmatch(r'#define[ \t]+FOX_BRANCH[ \t]+"klee"[ \t]*', lines[0]):
        return False
    new, n = re.subn(
        r'(?m)^#define[ \t]+FOX_BRANCH[ \t]+.*$',
        BRANCH_LINE,
        text,
        count=1,
    )
    if n != 1:
        fail(f'{path}: unable to replace FOX_BRANCH')
    path.write_text(new, encoding='utf-8')
    return True


def find_function(text: str, signature: str):
    start = text.find(signature)
    if start < 0:
        fail(f'partition.cpp: missing function signature: {signature}')
    brace = text.find('{', start)
    if brace < 0:
        fail('partition.cpp: malformed UnMount function')
    depth = 0
    for i in range(brace, len(text)):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                return start, i + 1
    fail('partition.cpp: unterminated UnMount function')


def patch_odm_unmount(path: Path) -> bool:
    text = path.read_text(encoding='utf-8')
    start, end = find_function(text, 'bool TWPartition::UnMount(bool Display_Error, int flags)')
    func = text[start:end]

    if ODM_MARKER in func:
        required = [
            'Mount_Point == "/odm"',
            'unmount_errno == EBUSY',
            'MNT_DETACH',
            'errno = unmount_errno;',
        ]
        missing = [x for x in required if x not in func]
        if missing:
            fail('partition.cpp: ODM marker exists but contract is incomplete: ' + ', '.join(missing))
        return False

    anchor = '\t\tumount2(Mount_Point.c_str(), flags);\n\t\tif (Is_Mounted()) {'
    count = func.count(anchor)
    if count != 1:
        fail(
            'partition.cpp: expected exactly one fox_12.1 unmount anchor inside '
            f'TWPartition::UnMount, found {count}; upstream changed'
        )

    replacement = '''\t\t// KleeOdmEbusySourceFixV1
\t\t// Build60 used an LD_PRELOAD fixed-offset ELF hook to hide EBUSY for
\t\t// /odm. Keep the required behavior in source instead: on the exact
\t\t// EBUSY + /odm case, try a lazy detach and only report success after
\t\t// the mount table confirms that /odm is gone.
\t\terrno = 0;
\t\tumount2(Mount_Point.c_str(), flags);
\t\tconst int unmount_errno = errno;
\t\tif (Is_Mounted()) {
\t\t\tif (Mount_Point == "/odm" && unmount_errno == EBUSY) {
\t\t\t\tLOGINFO("Klee: /odm unmount returned EBUSY; trying lazy detach\\n");
\t\t\t\terrno = 0;
\t\t\t\t(void)umount2(Mount_Point.c_str(), MNT_DETACH);
\t\t\t\tusleep(200000);
\t\t\t\tif (!Is_Mounted()) {
\t\t\t\t\tLOGINFO("Klee: /odm lazy detach succeeded\\n");
\t\t\t\t\treturn true;
\t\t\t\t}
\t\t\t\t// Preserve the original failure reason for the normal error path.
\t\t\t\terrno = unmount_errno;
\t\t\t}'''

    patched_func = func.replace(anchor, replacement, 1)
    if patched_func.count(ODM_MARKER) != 1:
        fail('partition.cpp: ODM patch marker count mismatch')
    path.write_text(text[:start] + patched_func + text[end:], encoding='utf-8')
    return True


def check_state(recovery: Path):
    variables = (recovery / 'variables.h').read_text(encoding='utf-8')
    partition = (recovery / 'partition.cpp').read_text(encoding='utf-8')
    if not re.search(r'(?m)^#define[ \t]+FOX_BRANCH[ \t]+"klee"[ \t]*$', variables):
        fail('FOX_BRANCH is not klee')
    if partition.count(ODM_MARKER) != 1:
        fail('ODM source fix marker count is not one')
    block = partition[partition.find(ODM_MARKER):]
    for marker in ('Mount_Point == "/odm"', 'unmount_errno == EBUSY', 'MNT_DETACH', 'errno = unmount_errno;'):
        if marker not in block:
            fail(f'ODM source fix missing {marker}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('source_root', type=Path, help='OrangeFox source root, or bootable/recovery itself')
    ap.add_argument('--check', action='store_true')
    args = ap.parse_args()
    recovery = recovery_dir(args.source_root)

    if args.check:
        check_state(recovery)
        print('KLEE SOURCE PATCH CHECK: PASS')
        return 0

    branch_changed = patch_branch(recovery / 'variables.h')
    odm_changed = patch_odm_unmount(recovery / 'partition.cpp')
    check_state(recovery)
    print('KLEE SOURCE PATCH: PASS')
    print(f' - FOX_BRANCH=klee: {"patched" if branch_changed else "already applied"}')
    print(f' - /odm EBUSY source fix: {"patched" if odm_changed else "already applied"}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
