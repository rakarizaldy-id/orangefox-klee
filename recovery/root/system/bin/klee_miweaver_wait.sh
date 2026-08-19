#!/system/bin/sh
# FINAL4: launch the stock Xiaomi Weaver implementation embedded directly in
# the recovery ramdisk.  Do not mount the ROM's /vendor or /odm here: changing
# those mountpoints while OrangeFox's decrypt UI is alive caused a stale/racy
# first decrypt attempt on-device.

logk() {
    echo "klee_miweaver_local: $*" > /dev/kmsg
}

MIWEAVER=/vendor/bin/hw/android.hardware.weaver
CPACE=/vendor/lib64/vendor.xiaomi.hardware.cpace-V1-ndk.so
TA=/vendor/mitee/ta/8aaaf201-2460-0010-aabbccdd00000006.ta

if [ ! -x "$MIWEAVER" ]; then
    logk "ERROR: embedded Xiaomi miweaver missing"
    exit 127
fi
if [ ! -f "$CPACE" ]; then
    logk "ERROR: embedded CPace library missing"
    exit 126
fi
if [ ! -f "$TA" ]; then
    logk "ERROR: embedded Weaver TA missing"
    exit 125
fi

logk "starting embedded Xiaomi miweaver"
exec "$MIWEAVER"
