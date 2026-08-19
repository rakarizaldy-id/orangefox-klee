#
# SPDX-License-Identifier: Apache-2.0
# Independent reconstruction for POCO X8 Pro (klee)
#

LOCAL_PATH := device/xiaomi/klee

# Build60 reports ro.product.first_api_level=34.
PRODUCT_SHIPPING_API_LEVEL := 34

# Dynamic / Virtual A/B
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_USE_DYNAMIC_PARTITION_SIZE := true
ENABLE_VIRTUAL_AB := true
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/compression.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)
PRODUCT_BUILD_VENDOR_BOOT_IMAGE := true

PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.fuse.passthrough.enable=true \
    ro.twrp.vendor_boot=true

# Exact Build60 ro.vendor.build.ab_ota_partitions.
AB_OTA_UPDATER := true
TARGET_ENFORCE_AB_OTA_PARTITION_LIST := true
AB_OTA_PARTITIONS += \
    apusys \
    audio_dsp \
    boot \
    ccu \
    dpm \
    dtbo \
    gpueb \
    gz \
    init_boot \
    lk \
    logo \
    mcf_ota \
    mcupm \
    md1img \
    mi_ext \
    mvpu_algo \
    odm \
    odm_dlkm \
    pi_img \
    preloader_raw \
    product \
    scp \
    spmfw \
    sspm \
    system \
    system_dlkm \
    system_ext \
    tee \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor \
    vcp \
    vendor \
    vendor_boot \
    vendor_dlkm

# Device/vendor-specific recovery inputs.
$(call inherit-product, $(LOCAL_PATH)/recovery-proprietary.mk)

# Source-built project helpers + upstream binaries directly present/used in
# Build60. virtual_ab_ota/compression.mk may pull its own snapuserd modules as
# required by AOSP; they are not manually duplicated here.
PRODUCT_PACKAGES += \
    android.hardware.boot@1.2-service \
    android.hardware.health@2.1-service \
    bootctl \
    fastbootd \
    fsck.f2fs \
    make_f2fs \
    update_engine_sideload \
    aw86927_ff_constant_prime_noplay \
    foxs-merge \
    klee_omapi_bridge \
    libklee_libcxx_compat
