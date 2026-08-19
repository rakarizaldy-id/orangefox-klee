/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Recovery-only libc++ ABI compatibility shim for klee vendor NDK libraries.
 */

#include <android/log.h>
#include <cstdarg>
#include <cstdlib>

extern "C" __attribute__((noreturn, visibility("default")))
void KleeVerboseAbort(const char* format, ...)
        __asm__("_ZNSt3__122__libcpp_verbose_abortEPKcz");

void KleeVerboseAbort(const char* format, ...) {
    va_list args;
    va_start(args, format);
    __android_log_vprint(ANDROID_LOG_FATAL, "klee-libcxx-compat", format, args);
    va_end(args);
    std::abort();
}
