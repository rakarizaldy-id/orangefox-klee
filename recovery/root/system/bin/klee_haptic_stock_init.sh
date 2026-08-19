#!/system/bin/sh
# KleeHapticStockLikeV2 - Build35 TEST
# SELinux-safe AW86927 init: keep the stock vendor firmware mounted with its
# vendor_file label until the kernel firmware request has completed, then unmount.

LOG=/tmp/recovery.log
ROOT=/tmp/klee_haptic
VDLKM_MNT=$ROOT/vendor_dlkm
VENDOR_MNT=$ROOT/vendor
MOD=$ROOT/haptic.ko
FW=$VENDOR_MNT/firmware/aw8697_haptic.bin
EXPECT_MOD=a1e78648378b79faa4a90bc2ec50f243b770686d3d2784b25d04bc14e5ea3c38
EXPECT_FW=9fb21dac566e26ffb1bf9f5e2cbb352c51ff7c9ee58b98c15a8947617d9ad543

log_i() { echo "I:KleeHapticV2: $*" >> "$LOG"; }
slot="$(getprop ro.boot.slot_suffix)"

find_part() {
    p="$1"
    for d in         "/dev/block/mapper/${p}${slot}"         "/dev/block/mapper/${p}"         "/dev/block/mapper/${p}_a"         "/dev/block/mapper/${p}_b"         "/dev/block/by-name/${p}${slot}"         "/dev/block/by-name/${p}"
    do
        [ -b "$d" ] && { echo "$d"; return 0; }
    done
    return 1
}

mount_ro_temp() {
    dev="$1"; mnt="$2"
    mkdir -p "$mnt"
    mount -t erofs -o ro "$dev" "$mnt" >/dev/null 2>&1 && return 0
    mount -t ext4 -o ro "$dev" "$mnt" >/dev/null 2>&1 && return 0
    return 1
}

restore_fw_path() {
    if [ -e /sys/module/firmware_class/parameters/path ]; then
        printf '%s' "$oldpath" > /sys/module/firmware_class/parameters/path 2>/dev/null
    fi
}

cleanup_mounts() {
    umount "$VDLKM_MNT" >/dev/null 2>&1
    umount "$VENDOR_MNT" >/dev/null 2>&1
}

log_i "starting SELinux-safe stock-backed AW86927 init; slot=${slot:-unknown}"
mkdir -p "$ROOT"

# Wait for logical mapper creation plus the already-embedded miev dependency.
i=0
while [ "$i" -lt 180 ]; do
    vdlkm_dev="$(find_part vendor_dlkm)"
    vendor_dev="$(find_part vendor)"
    if [ -n "$vdlkm_dev" ] && [ -n "$vendor_dev" ] && [ -d /sys/module/miev ] && [ -e /sys/bus/i2c/devices/0-005a/name ]; then
        break
    fi
    i=$((i + 1))
    sleep 1
done

if [ -z "$vdlkm_dev" ] || [ -z "$vendor_dev" ] || [ ! -d /sys/module/miev ]; then
    log_i "backend prerequisites not ready after ${i}s; leaving OrangeFox unchanged"
    exit 0
fi

cleanup_mounts
if ! mount_ro_temp "$vdlkm_dev" "$VDLKM_MNT"; then
    log_i "cannot mount $vdlkm_dev read-only"
    exit 0
fi
if [ ! -r "$VDLKM_MNT/lib/modules/haptic.ko" ]; then
    log_i "stock haptic.ko not found"
    cleanup_mounts
    exit 0
fi
cp "$VDLKM_MNT/lib/modules/haptic.ko" "$MOD" || { cleanup_mounts; exit 0; }
umount "$VDLKM_MNT" >/dev/null 2>&1

# Keep vendor mounted until firmware_class has successfully consumed the blob.
if ! mount_ro_temp "$vendor_dev" "$VENDOR_MNT"; then
    log_i "cannot mount $vendor_dev read-only"
    exit 0
fi
if [ ! -r "$FW" ]; then
    log_i "stock aw8697_haptic.bin not found"
    cleanup_mounts
    exit 0
fi

mod_sha="$(sha256sum "$MOD" 2>/dev/null | awk '{print $1}')"
fw_sha="$(sha256sum "$FW" 2>/dev/null | awk '{print $1}')"
log_i "stock hashes module=$mod_sha firmware=$fw_sha"
if [ "$mod_sha" != "$EXPECT_MOD" ] || [ "$fw_sha" != "$EXPECT_FW" ]; then
    log_i "stock asset hash mismatch; refusing unvalidated haptic backend"
    cleanup_mounts
    exit 0
fi

oldpath="$(cat /sys/module/firmware_class/parameters/path 2>/dev/null)"
fwdir="$VENDOR_MNT/firmware"
if [ -n "$oldpath" ]; then
    printf '%s' "$fwdir,$oldpath" > /sys/module/firmware_class/parameters/path
else
    printf '%s' "$fwdir" > /sys/module/firmware_class/parameters/path
fi
log_i "firmware path temporarily points at stock vendor_file context"

if [ ! -d /sys/module/haptic ]; then
    if insmod "$MOD" >> "$LOG" 2>&1; then
        log_i "haptic.ko loaded"
    else
        log_i "haptic.ko insmod failed"
        restore_fw_path
        cleanup_mounts
        exit 0
    fi
else
    log_i "haptic module already loaded"
fi

P=/sys/bus/i2c/devices/0-005a
j=0
while [ "$j" -lt 20 ]; do
    if [ -w "$P/effect_id" ] && [ -L "$P/driver" ]; then
        break
    fi
    j=$((j + 1))
    sleep 1
done
if [ ! -w "$P/effect_id" ]; then
    log_i "AW86927 sysfs backend did not become ready"
    restore_fw_path
    cleanup_mounts
    exit 0
fi

# The stock driver schedules its RAM firmware request after probe. Keep the
# labeled vendor mount alive until that request completes. If it does not fire,
# use the driver's ram_update sysfs as a bounded fallback while the mount is live.
fw_ok=0
k=0
while [ "$k" -lt 16 ]; do
    if dmesg | grep -q 'aw86927_ram_loaded: ram firmware update complete!'; then
        fw_ok=1
        break
    fi
    k=$((k + 1))
    sleep 0.5
done

if [ "$fw_ok" -ne 1 ] && [ -w "$P/ram_update" ]; then
    log_i "scheduled RAM load not observed; triggering ram_update fallback"
    echo 1 > "$P/ram_update"
    k=0
    while [ "$k" -lt 12 ]; do
        if dmesg | grep -q 'aw86927_ram_loaded: ram firmware update complete!'; then
            fw_ok=1
            break
        fi
        k=$((k + 1))
        sleep 0.5
    done
fi

if [ "$fw_ok" -ne 1 ]; then
    log_i "RAM firmware did not complete; leaving effect unprimed"
    restore_fw_path
    cleanup_mounts
    exit 0
fi

# Firmware is now resident in AW86927 RAM; restore firmware_class path and release
# the temporary vendor mount before normal OrangeFox/fastbootd use.
restore_fw_path
umount "$VENDOR_MNT" >/dev/null 2>&1

echo 7 > "$P/effect_id"
effect="$(cat "$P/effect_id" 2>/dev/null)"
index="$(cat "$P/index" 2>/dev/null)"
gain="$(cat "$P/gain" 2>/dev/null)"
log_i "RAM firmware loaded; effect-7 backend ready: $effect; $index; gain=$gain"

# Build37: validated NO-PLAY constant-duration primer. The static primer auto-detects
# the awinic_haptic input node by EVIOCGNAME, so event numbering may change across boots.
# Stage A uploads FF_PERIODIC/custom effect 7 at magnitude 0x7fff without PLAY, then
# sends FF_GAIN=0x7fff. Stage B uploads FF_CONSTANT without PLAY. The resulting driver
# state is effect_id=11 / activate_mode=3 / level=0x80, while OrangeFox continues to
# use its unchanged sysfs duration+activate backend. This makes the vibration sliders
# control real physical duration while preserving stock-like strength.
if /system/bin/aw86927_ff_constant_prime_noplay >> "$LOG" 2>&1; then
    effect="$(cat "$P/effect_id" 2>/dev/null)"
    mode="$(cat "$P/activate_mode" 2>/dev/null)"
    index="$(cat "$P/index" 2>/dev/null)"
    gain="$(cat "$P/gain" 2>/dev/null)"
    log_i "CONST NO-PLAY prime complete: $effect; $mode; $index; gain=$gain; target level=0x80"
else
    ff_rc=$?
    log_i "CONST NO-PLAY prime failed rc=$ff_rc; Build36 sysfs haptic backend remains usable"
fi

exit 0
