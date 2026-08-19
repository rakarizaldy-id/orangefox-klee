#
# SPDX-License-Identifier: Apache-2.0
# Independent reconstruction for POCO X8 Pro (klee)
#

DEVICE_PATH := device/xiaomi/klee

# Bring-up concession only. Step17 must try removing this after the first clean
# source build proves all dependencies are declared.
ALLOW_MISSING_DEPENDENCIES := true

# Architecture -------------------------------------------------------
# Build60 reports cortex-a55 as the Bionic runtime variant. Product ABI is
# still 64-bit-only; the second architecture mirrors the validated build
# environment without exposing 32-bit product apps.
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a55
TARGET_CPU_VARIANT_RUNTIME := cortex-a55

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a55

TARGET_OTA_ASSERT_DEVICE := klee
TARGET_BOARD_PLATFORM := mt6899
TARGET_BOOTLOADER_BOARD_NAME := mt6899
TARGET_NO_BOOTLOADER := true

# Kernel / DTB / DTBO -----------------------------------------------
# Recovery lives in vendor_boot and does not replace the Android boot kernel.
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_NO_KERNEL := true
BOARD_KERNEL_SEPARATED_DTBO := true

KLEE_GENERATED_PREBUILT := $(DEVICE_PATH)/prebuilt/generated
TARGET_PREBUILT_DTB := $(KLEE_GENERATED_PREBUILT)/mt6899-klee.dtb
BOARD_PREBUILT_DTBOIMAGE := $(KLEE_GENERATED_PREBUILT)/dtbo.img

# Build60 vendor_boot v4 geometry.
BOARD_KERNEL_BASE := 0x3fff8000
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x26f08000
BOARD_TAGS_OFFSET := 0x07c88000
BOARD_DTB_OFFSET := 0x07c88000
BOARD_HEADER_SIZE := 2128
BOARD_KERNEL_PAGESIZE := 4096
BOARD_BOOT_HEADER_VERSION := 4
BOARD_RAMDISK_USE_LZ4 := true

# Despite the name, AOSP's classic vendor_boot make path derives the
# --vendor_cmdline from BOARD_KERNEL_CMDLINE. Keep this variable rather than
# inventing an unconsumed BOARD_VENDOR_CMDLINE.
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 erofs.reserved_pages=64

BOARD_MKBOOTIMG_ARGS += --dtb $(TARGET_PREBUILT_DTB)
BOARD_MKBOOTIMG_ARGS += --base $(BOARD_KERNEL_BASE)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE) --board ""
BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET)
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_TAGS_OFFSET)
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --dtb_offset $(BOARD_DTB_OFFSET)

BOARD_USES_GENERIC_KERNEL_IMAGE := true
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true

# Do not stage duplicate vendor modules. The stock-derived PLATFORM fragment
# carries its own hardware modules, while Klee touch modules are loaded at
# runtime from the installed ROM's /vendor_dlkm.

# Physical partition geometry ---------------------------------------
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
BOARD_SUPER_PARTITION_SIZE := 12884901888

# No BOARD_SUPER_PARTITION_GROUPS is declared: this recovery-only tree does
# not build super.img, so a guessed group name/allocatable size is harmful.

# Filesystems --------------------------------------------------------
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
TARGET_USERIMAGES_USE_EROFS := true
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_USES_METADATA_PARTITION := true
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab
BOARD_HAS_LARGE_FILESYSTEM := true
BOARD_SUPPRESS_SECURE_ERASE := true

# FBE ---------------------------------------------------------------
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_USE_FSCRYPT_POLICY := 2

# Deliberately no BOARD_AVB_ENABLE. This recovery-only tree does not build or
# sign Android AVB images; Android's vbmeta chain remains a separate concern.

# Display / brightness ----------------------------------------------
TW_THEME := portrait_hdpi
TARGET_SCREEN_WIDTH := 1268
TARGET_SCREEN_HEIGHT := 2756
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TW_BRIGHTNESS_PATH := "/sys/class/leds/lcd-backlight/brightness"
TW_MAX_BRIGHTNESS := 16383
TW_DEFAULT_BRIGHTNESS := 4915
TW_USE_LEGACY_BATTERY_SERVICES := true

# Storage / USB / recovery tools ------------------------------------
RECOVERY_SDCARD_ON_DATA := true
TW_HAS_MTP := true
TW_MTP_DEVICE := /dev/mtp_usb
TW_NO_USB_STORAGE := true
TW_EXCLUDE_DEFAULT_USB_INIT := true

TW_INCLUDE_FASTBOOTD := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_EROFS := true
TW_EXCLUDE_APEX := true
TW_DEFAULT_LANGUAGE := en_US

TARGET_USES_LOGD := true
TWRP_INCLUDE_LOGCAT := true

TW_RECOVERY_ADDITIONAL_RELINK_LIBRARY_FILES += \
    $(TARGET_OUT_SHARED_LIBRARIES)/libtrusty.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/libklee_libcxx_compat.so
