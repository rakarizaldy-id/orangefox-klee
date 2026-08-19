#!/system/bin/sh
#
# OrangeFox klee splash persistence backend
# vendor_boot header v4 / recovery vendor-ramdisk fragment
#
# Args:
#   1 spl_bg_user
#   2 spl_bg_on
#   3 spl_bg_color
#   4 spl_logo_type
#   5 spl_ofr
#   6 of_splash_max_size (KiB)
#

BG_USER="${1:-0}"
BG_ON="${2:-0}"
BG_COLOR="${3:-#00000000}"
LOGO_TYPE="${4:-o}"
SHOW_OFR="${5:-1}"
MAX_KB="${6:-4096}"

MB="/system/bin/magiskboot"
WORK="/tmp/klee_splash_vendorboot"
LOG="/tmp/recovery.log"

log_i() {
    echo "I:KleeSplash: $*" >> "$LOG"
}

fail() {
    echo "E:KleeSplash: $*" >> "$LOG"
    echo "E:KleeSplash: workdir kept at $WORK" >> "$LOG"
    exit 1
}

[ -x "$MB" ] || fail "magiskboot is missing"

SLOT="$(getprop ro.boot.slot_suffix)"
case "$SLOT" in
    _a|_b) BLOCK="/dev/block/by-name/vendor_boot${SLOT}" ;;
    *)     BLOCK="/dev/block/by-name/vendor_boot" ;;
esac

[ -b "$BLOCK" ] || fail "vendor_boot block device not found: $BLOCK"

rm -rf "$WORK"
mkdir -p "$WORK/unpack" "$WORK/verify" || fail "cannot create workdir"

log_i "using $BLOCK"
log_i "copying active vendor_boot"

dd if="$BLOCK" of="$WORK/unpack/vendor_boot.img" bs=4M >> "$LOG" 2>&1 ||
    fail "cannot read active vendor_boot"

cd "$WORK/unpack" || fail "cannot enter unpack directory"

log_i "unpacking vendor_boot"
"$MB" unpack -h vendor_boot.img >> "$LOG" 2>&1 ||
    fail "magiskboot unpack failed"

[ -f vendor_ramdisk_recovery.cpio ] ||
    fail "recovery vendor-ramdisk fragment was not found"
[ -f vendor_ramdisk_.cpio ] ||
    fail "normal vendor-ramdisk fragment was not found"
[ -f dtb ] ||
    fail "dtb was not found"

"$MB" cpio vendor_ramdisk_recovery.cpio \
    "extract system/bin/recovery $WORK/recovery.before" >> "$LOG" 2>&1 ||
    fail "cannot extract recovery binary for verification"

if [ "$BG_USER" = "1" ]; then
    case "$LOGO_TYPE" in
        o) logo_color="F86314" ;;
        w) logo_color="ffffff" ;;
        d) logo_color="353535" ;;
        0) logo_color="ffffff" ;;
        *) fail "invalid splash logo type: $LOGO_TYPE" ;;
    esac

    if [ "$LOGO_TYPE" = "0" ]; then
        logo_on="!--"
    else
        logo_on=""
    fi

    if [ "$SHOW_OFR" = "1" ] && [ "$LOGO_TYPE" != "0" ]; then
        logo_ofr=""
    else
        logo_ofr="!--"
    fi

    if [ "$BG_ON" = "1" ]; then
        USER_PNG="/twres/images/Splash/user.png"
        [ -f "$USER_PNG" ] || fail "staged splash PNG is missing"

        png_bytes="$(stat -c %s "$USER_PNG" 2>/dev/null)"
        max_bytes="$(expr "$MAX_KB" \* 1024 2>/dev/null)"
        [ -n "$png_bytes" ] || fail "cannot determine splash PNG size"
        [ -n "$max_bytes" ] || fail "invalid splash size limit"

        if [ "$png_bytes" -gt "$max_bytes" ]; then
            fail "splash PNG is larger than ${MAX_KB} KiB"
        fi

        cp "$USER_PNG" "$WORK/user.png" ||
            fail "cannot stage custom splash PNG"
        bg_on=""
    else
        cp "/twres/images/Splash/empty.png" "$WORK/user.png" ||
            fail "cannot stage empty splash PNG"
        bg_on="!--"
    fi

    sed -e "s/#SHOWOFR#/${logo_ofr}/g" \
        -e "s/#TCOLOR#/${logo_color}/g" \
        -e "s/#BG_COLOR#/${BG_COLOR}/g" \
        -e "s/#LOGO_TYPE#/${LOGO_TYPE}/g" \
        -e "s/#LOGO_ON#/${logo_on}/g" \
        -e "s/#BG_IMG#/${bg_on}/g" \
        "/twres/themes/sed/splash.xml" > "$WORK/splash.xml" ||
        fail "cannot generate splash.xml"

    "$MB" cpio vendor_ramdisk_recovery.cpio \
        "add 0644 twres/images/Splash/user.png $WORK/user.png" >> "$LOG" 2>&1 ||
        fail "cannot replace splash PNG in recovery ramdisk"
else
    cp "/twres/themes/sed/splash_orig.xml" "$WORK/splash.xml" ||
        fail "cannot stage original splash.xml"
fi

"$MB" cpio vendor_ramdisk_recovery.cpio \
    "add 0644 twres/splash.xml $WORK/splash.xml" >> "$LOG" 2>&1 ||
    fail "cannot replace splash.xml in recovery ramdisk"

log_i "repacking vendor_boot"
"$MB" repack vendor_boot.img "$WORK/new-vendor_boot.img" >> "$LOG" 2>&1 ||
    fail "magiskboot repack failed"

[ -f "$WORK/new-vendor_boot.img" ] ||
    fail "repacked vendor_boot image was not created"

image_size="$(stat -c %s "$WORK/new-vendor_boot.img" 2>/dev/null)"
block_size="$(blockdev --getsize64 "$BLOCK" 2>/dev/null)"
[ -n "$image_size" ] || fail "cannot determine repacked image size"
[ -n "$block_size" ] || fail "cannot determine vendor_boot size"
[ "$image_size" = "$block_size" ] ||
    fail "repacked image size ${image_size} does not match vendor_boot size ${block_size}"

cp "$WORK/new-vendor_boot.img" "$WORK/verify/new-vendor_boot.img" ||
    fail "cannot stage verification image"

cd "$WORK/verify" || fail "cannot enter verification directory"

log_i "verifying repacked vendor_boot"
"$MB" unpack -h new-vendor_boot.img >> "$LOG" 2>&1 ||
    fail "repacked vendor_boot cannot be unpacked"

[ -f vendor_ramdisk_recovery.cpio ] ||
    fail "verification recovery fragment is missing"
[ -f vendor_ramdisk_.cpio ] ||
    fail "verification normal fragment is missing"
[ -f dtb ] ||
    fail "verification dtb is missing"

cmp -s vendor_ramdisk_.cpio "$WORK/unpack/vendor_ramdisk_.cpio" ||
    fail "normal vendor ramdisk changed unexpectedly"
cmp -s dtb "$WORK/unpack/dtb" ||
    fail "dtb changed unexpectedly"

"$MB" cpio vendor_ramdisk_recovery.cpio \
    "extract system/bin/recovery $WORK/recovery.after" >> "$LOG" 2>&1 ||
    fail "cannot extract recovery binary from verification image"

cmp -s "$WORK/recovery.before" "$WORK/recovery.after" ||
    fail "recovery binary changed unexpectedly"

"$MB" cpio vendor_ramdisk_recovery.cpio \
    "extract twres/splash.xml $WORK/splash.after.xml" >> "$LOG" 2>&1 ||
    fail "cannot extract splash.xml from verification image"

cmp -s "$WORK/splash.xml" "$WORK/splash.after.xml" ||
    fail "splash.xml verification failed"

if [ "$BG_USER" = "1" ]; then
    "$MB" cpio vendor_ramdisk_recovery.cpio \
        "extract twres/images/Splash/user.png $WORK/user.after.png" >> "$LOG" 2>&1 ||
        fail "cannot extract splash PNG from verification image"

    cmp -s "$WORK/user.png" "$WORK/user.after.png" ||
        fail "splash PNG verification failed"
fi

log_i "pre-flash verification passed; flashing $BLOCK"

dd if="$WORK/new-vendor_boot.img" of="$BLOCK" bs=4M >> "$LOG" 2>&1 ||
    fail "vendor_boot flash failed"
sync

cmp -s "$WORK/new-vendor_boot.img" "$BLOCK" ||
    fail "post-flash byte verification failed"

cp "$WORK/splash.xml" /twres/splash.xml ||
    fail "flash succeeded but runtime splash.xml update failed"

if [ "$BG_USER" = "1" ] && [ "$BG_ON" != "1" ]; then
    cp "$WORK/user.png" /twres/images/Splash/user.png 2>/dev/null
fi

twrp xset spl_parsed=0 >/dev/null 2>&1

log_i "splash update completed successfully"
rm -rf "$WORK"
exit 0
