#!/bin/bash
#
# SPDX-License-Identifier: Apache-2.0
#

export TARGET_ARCH="arm64"
export LC_ALL="C"
export ALLOW_MISSING_DEPENDENCIES=true

export FOX_AB_DEVICE=1
export FOX_VIRTUAL_AB_DEVICE=1
export FOX_VENDOR_BOOT_RECOVERY=1
export FOX_LOCAL_CALLBACK_SCRIPT="device/xiaomi/klee/tools/fox-callback.sh"

# Build60's metadata-backed profile exists before normal /data media.
export FOX_ALLOW_EARLY_SETTINGS_LOAD=1

# Current OrangeFox variable names for tools used by Build60.
export OF_ENABLE_LPTOOLS=1
export OF_USE_DMCTL=1

export OF_MAINTAINER="RakaRizaldy"

# FOX_VERSION is obsolete/currently automatic.
