#
# SPDX-License-Identifier: Apache-2.0
#
# Proprietary inputs are extracted to vendor/xiaomi/klee by extract-files.py.
# This file maps only the device/vendor-specific pieces required in recovery.
#

KLEE_VENDOR_PATH := vendor/xiaomi/klee/proprietary

PRODUCT_COPY_FILES += \
    $(KLEE_VENDOR_PATH)/vendor/bin/hw/android.hardware.boot-service.mtk:recovery/root/vendor/bin/hw/android.hardware.boot-service.mtk \
    $(KLEE_VENDOR_PATH)/vendor/bin/tee-supplicant:recovery/root/vendor/bin/tee-supplicant \
    $(KLEE_VENDOR_PATH)/vendor/bin/hw/android.hardware.gatekeeper-service.mitee:recovery/root/vendor/bin/hw/android.hardware.gatekeeper-service.mitee \
    $(KLEE_VENDOR_PATH)/vendor/bin/hw/android.hardware.security.keymint@3.0-service.mitee:recovery/root/vendor/bin/hw/android.hardware.security.keymint@3.0-service.mitee \
    $(KLEE_VENDOR_PATH)/vendor/bin/hw/vendor.xiaomi.hardware.secure_element-service:recovery/root/vendor/bin/hw/vendor.xiaomi.hardware.secure_element-service \
    $(KLEE_VENDOR_PATH)/vendor/bin/hw/android.hardware.weaver-service.nxp:recovery/root/vendor/bin/hw/android.hardware.weaver-service.nxp \
    $(KLEE_VENDOR_PATH)/vendor/bin/hw/android.hardware.weaver:recovery/root/vendor/bin/hw/android.hardware.weaver \
    $(KLEE_VENDOR_PATH)/vendor/bin/hw/vendor.xiaomi.hardware.authsecretd:recovery/root/vendor/bin/hw/vendor.xiaomi.hardware.authsecretd \
    $(KLEE_VENDOR_PATH)/vendor/lib64/android.hardware.secure_element-V1-ndk.so:recovery/root/vendor/lib64/android.hardware.secure_element-V1-ndk.so \
    $(KLEE_VENDOR_PATH)/vendor/lib64/android.hardware.secure_element@1.0.so:recovery/root/vendor/lib64/android.hardware.secure_element@1.0.so \
    $(KLEE_VENDOR_PATH)/vendor/lib64/android.hardware.secure_element@1.1.so:recovery/root/vendor/lib64/android.hardware.secure_element@1.1.so \
    $(KLEE_VENDOR_PATH)/vendor/lib64/android.hardware.secure_element@1.2.so:recovery/root/vendor/lib64/android.hardware.secure_element@1.2.so \
    $(KLEE_VENDOR_PATH)/vendor/lib64/android.hardware.weaver-V2-ndk.so:recovery/root/vendor/lib64/android.hardware.weaver-V2-ndk.so \
    $(KLEE_VENDOR_PATH)/vendor/lib64/android.se.omapi-V1-ndk.so:recovery/root/vendor/lib64/android.se.omapi-V1-ndk.so \
    $(KLEE_VENDOR_PATH)/vendor/lib64/ese_weaver.nxp.so:recovery/root/system/lib64/ese_weaver.nxp.so \
    $(KLEE_VENDOR_PATH)/vendor/lib64/libjc_keymint_transport.nxp.so:recovery/root/system/lib64/libjc_keymint_transport.nxp.so \
    $(KLEE_VENDOR_PATH)/vendor/lib64/libmigpese@2.0.so:recovery/root/system/lib64/libmigpese@2.0.so \
    $(KLEE_VENDOR_PATH)/vendor/lib64/libteecli.so:recovery/root/system/lib64/libteecli.so \
    $(KLEE_VENDOR_PATH)/vendor/lib64/vendor.xiaomi.hardware.aidl.mtdservice-V1-ndk.so:recovery/root/system/lib64/vendor.xiaomi.hardware.aidl.mtdservice-V1-ndk.so \
    $(KLEE_VENDOR_PATH)/vendor/lib64/vendor.xiaomi.hardware.cpace-V1-ndk.so:recovery/root/vendor/lib64/vendor.xiaomi.hardware.cpace-V1-ndk.so \
    $(KLEE_VENDOR_PATH)/vendor/lib64/vendor.xiaomi.hardware.miauthsecretd-V1-ndk.so:recovery/root/vendor/lib64/vendor.xiaomi.hardware.miauthsecretd-V1-ndk.so \
    $(KLEE_VENDOR_PATH)/vendor/lib64/libclang_rt.ubsan_standalone-aarch64-android.so:recovery/root/vendor/lib64/libclang_rt.ubsan_standalone-aarch64-android.so \
    $(KLEE_VENDOR_PATH)/vendor/lib64/libmisight.so:recovery/root/vendor/lib64/libmisight.so \
    $(KLEE_VENDOR_PATH)/system/lib64/libc++_hos.so:recovery/root/system/lib64/libc++_hos.so \
    $(KLEE_VENDOR_PATH)/vendor/mitee/ta/2e8fade5-0c7a-46cc-810e6468baee66b9.ta:recovery/root/vendor/mitee/ta/2e8fade5-0c7a-46cc-810e6468baee66b9.ta \
    $(KLEE_VENDOR_PATH)/vendor/mitee/ta/4d573443-6a56-4272-ac6f2425af9ef9bb.ta:recovery/root/vendor/mitee/ta/4d573443-6a56-4272-ac6f2425af9ef9bb.ta \
    $(KLEE_VENDOR_PATH)/vendor/mitee/ta/8aaaf201-2460-0010-aabbccdd00000006.ta:recovery/root/vendor/mitee/ta/8aaaf201-2460-0010-aabbccdd00000006.ta \
    $(KLEE_VENDOR_PATH)/vendor/mitee/ta/dba51a17-0563-11e7-93b16fa7b0071a51.ta:recovery/root/vendor/mitee/ta/dba51a17-0563-11e7-93b16fa7b0071a51.ta \
    $(KLEE_VENDOR_PATH)/vendor/bin/touch_report:recovery/root/vendor/bin/touch_report \
    $(KLEE_VENDOR_PATH)/vendor/lib64/libtouchreport.so:recovery/root/vendor/lib64/libtouchreport.so \
    $(KLEE_VENDOR_PATH)/vendor/lib64/libtouchreport_alg.so:recovery/root/vendor/lib64/libtouchreport_alg.so \
    $(KLEE_VENDOR_PATH)/vendor/lib64/libtouchreport_hal.so:recovery/root/vendor/lib64/libtouchreport_hal.so \
    $(KLEE_VENDOR_PATH)/vendor/lib64/libtouchreport_sensor.so:recovery/root/vendor/lib64/libtouchreport_sensor.so
