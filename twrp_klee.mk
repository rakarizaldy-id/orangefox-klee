#
# SPDX-License-Identifier: Apache-2.0
# Independent reconstruction for POCO X8 Pro (klee)
#

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, device/xiaomi/klee/device.mk)
$(call inherit-product, vendor/twrp/config/common.mk)

PRODUCT_DEVICE := klee
PRODUCT_NAME := twrp_klee
PRODUCT_BRAND := POCO
PRODUCT_MODEL := POCO X8 Pro
PRODUCT_MANUFACTURER := Xiaomi
