#!/system/bin/sh
# klee / HyperOS FBE FINAL4 preparation.
# The stock Xiaomi Weaver binary, CPace NDK library and Weaver TA are embedded
# in the recovery ramdisk, so recovery /vendor stays untouched throughout the
# normal OrangeFox decrypt flow.

logk() {
    echo "klee_fbe_prep: $*" > /dev/kmsg
}

logk "starting FINAL4 embedded-Weaver prep"

# MiTEE REE secure storage lives on persist.  It must be writable before
# Weaver Read: the on-device raw-syscall trace proved RO caused O_RDWR=EROFS,
# followed by pwrite64=EBADF and TEEC 0xFFFF3024.
mount -o remount,rw /mnt/vendor/persist 2>/dev/null
if ! grep -q ' /mnt/vendor/persist .* rw,' /proc/mounts 2>/dev/null; then
    logk "ERROR: /mnt/vendor/persist is not rw"
    exit 20
fi
logk "persist is rw"

# Verify embedded components without exposing stock logical vendor/odm.
if [ ! -x /vendor/bin/hw/android.hardware.weaver ]; then
    logk "ERROR: embedded Xiaomi miweaver missing"
    exit 21
fi
if [ ! -f /vendor/lib64/vendor.xiaomi.hardware.cpace-V1-ndk.so ]; then
    logk "ERROR: embedded CPace library missing"
    exit 22
fi
if [ ! -f /vendor/mitee/ta/8aaaf201-2460-0010-aabbccdd00000006.ta ]; then
    logk "ERROR: embedded Weaver TA missing"
    exit 23
fi
logk "embedded Weaver components present"

# Let metadata encryption finish first so /data exists before CPace/Weaver is
# instantiated.  Also wait for the recovery KeyMint/Gatekeeper stack, but do
# not wait for or manipulate any OrangeFox GUI page.
i=0
while [ "$i" -lt 60 ]; do
    KM="$(getprop init.svc.vendor.keymint-mitee)"
    GK="$(getprop init.svc.vendor.gatekeeper_mitee)"
    TEE="$(getprop init.svc.tee-supplicant)"
    if grep -q ' /data ' /proc/mounts 2>/dev/null && [ "$KM" = "running" ] && [ "$GK" = "running" ] && [ "$TEE" = "running" ]; then
        break
    fi
    /system/bin/sleep 1
    i=$((i + 1))
done

if ! grep -q ' /data ' /proc/mounts 2>/dev/null; then
    logk "ERROR: /data did not mount; not starting Weaver"
    exit 24
fi
logk "crypto/data ready: tee=$TEE keymint=$KM gatekeeper=$GK"

COUNTRY="$(getprop ro.boot.ptcountrycode)"
if [ "$COUNTRY" = "cn" ] || [ "$COUNTRY" = "CN" ]; then
    # Pure CN: Xiaomi Weaver/CPace reports the 32-byte Weaver key configuration
    # used by CN credentials. Do not launch the Global NXP/AuthSecret backend.
    logk "weaver selector: country=$COUNTRY backend=xiaomi"
    WV="$(getprop init.svc.vendor.weaver_xiaomi)"
    if [ "$WV" != "running" ]; then
        setprop ctl.start vendor.weaver_xiaomi
    fi

    i=0
    while [ "$i" -lt 10 ]; do
        WV="$(getprop init.svc.vendor.weaver_xiaomi)"
        [ "$WV" = "running" ] && break
        /system/bin/sleep 1
        i=$((i + 1))
    done
    logk "CN Xiaomi Weaver state=$WV pid=$(getprop init.svc_debug_pid.vendor.weaver_xiaomi)"
    [ "$WV" = "running" ] || exit 25
else
    # Non-CN: preserve the proven Global/IDXM NXP + MIAuthSecret sequence.
    logk "weaver selector: country=${COUNTRY:-unknown} backend=nxp"
    WV="$(getprop init.svc.vendor.weaver_nxp)"
    if [ "$WV" != "running" ]; then
        setprop ctl.start vendor.weaver_nxp
    fi

    i=0
    while [ "$i" -lt 10 ]; do
        WV="$(getprop init.svc.vendor.weaver_nxp)"
        [ "$WV" = "running" ] && break
        /system/bin/sleep 1
        i=$((i + 1))
    done
    logk "weaver pre-authsecret state=$WV pid=$(getprop init.svc_debug_pid.vendor.weaver_nxp)"
    [ "$WV" = "running" ] || exit 25

    # The NXP binary blocks in AServiceManager_waitForService(IMIAuthSecret).
    # Give it time to reach that wait before starting the stock lazy AuthSecret.
    /system/bin/sleep 1

    AS="$(getprop init.svc.miweaver_hal_service)"
    if [ "$AS" != "running" ]; then
        setprop ctl.start miweaver_hal_service
    fi
    i=0
    while [ "$i" -lt 10 ]; do
        AS="$(getprop init.svc.miweaver_hal_service)"
        [ "$AS" = "running" ] && break
        /system/bin/sleep 1
        i=$((i + 1))
    done
    logk "authsecret post-weaver state=$AS pid=$(getprop init.svc_debug_pid.miweaver_hal_service)"
fi
exit 0
