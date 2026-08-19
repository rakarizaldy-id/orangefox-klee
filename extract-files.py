#!/usr/bin/env -S PYTHONPATH=../../../tools/extract-utils python3
#
# SPDX-License-Identifier: Apache-2.0
#

from extract_utils.fixups_lib import (
    lib_fixups,
    lib_fixups_user_type,
)
from extract_utils.main import (
    ExtractUtils,
    ExtractUtilsModule,
)


def lib_fixup_klee_private(lib: str, partition: str, *args, **kwargs):
    """
    Avoid collisions with source-built AIDL runtime libraries.

    The Build60 OMAPI bridge deliberately links the stock/vendor V1 NDK
    implementations while compiling against current generated AIDL headers.
    """
    return f'klee_{lib}'


lib_fixups: lib_fixups_user_type = {
    **lib_fixups,
    (
        'android.hardware.secure_element-V1-ndk',
        'android.se.omapi-V1-ndk',
    ): lib_fixup_klee_private,
}


module = ExtractUtilsModule(
    'klee',
    'xiaomi',
    lib_fixups=lib_fixups,
)


if __name__ == '__main__':
    utils = ExtractUtils.device(module)
    utils.run()
