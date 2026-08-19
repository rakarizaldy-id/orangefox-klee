#!/system/bin/sh
# KleeFoxThemeSyncV3: mirror OrangeFox per-user theme overrides into
# /metadata for pre-decrypt staging on the next recovery boot.
# V3 preserves the last-known-good metadata cache while userdata is
# temporarily unavailable during shutdown/reboot, preventing OFOX Reboot
# from erasing the pre-decrypt theme. Explicit theme removal is still mirrored
# when /data/media/0/Fox is accessible and the source override is truly absent.

LOG=/tmp/recovery.log
SRC=/data/media/0/Fox/.theme
FOXROOT=/data/media/0/Fox
DST=/metadata/Fox/.theme

log_i() {
    echo "I:KleeFoxThemeSyncV3: $*" >> "$LOG"
}

[ "$(getprop twrp.decrypt.done)" = "true" ] || exit 0

mkdir -p /metadata/Fox "$DST"
chmod 0700 "$DST" 2>/dev/null
log_i "post-decrypt watcher started"

sync_one() {
    name="$1"
    s="$SRC/$name"
    d="$DST/$name"

    if [ -s "$s" ]; then
        if [ ! -s "$d" ] || ! /system/bin/toybox cmp -s "$s" "$d"; then
            cat "$s" > "$d.tmp" 2>/dev/null || return
            chown media_rw:media_rw "$d.tmp" 2>/dev/null
            chmod 0644 "$d.tmp" 2>/dev/null
            mv -f "$d.tmp" "$d" 2>/dev/null || return
            sync
            log_i "synced $name to metadata"
        fi
        # Self-heal files created by older ThemeSync builds (0660), otherwise
        # init's pre-decrypt copy rejects them as insecure.
        chmod 0644 "$d" 2>/dev/null
        return
    fi

    # A missing source during reboot/shutdown is NOT a user theme reset.
    # OFOX may unmount /data/media while this watcher is still alive; V2
    # incorrectly treated that temporary disappearance as deletion and erased
    # the metadata cache. Preserve the last-known-good copy in that state.
    powerctl="$(getprop sys.powerctl 2>/dev/null)"
    if [ -n "$powerctl" ] || [ ! -d "$FOXROOT" ]; then
        return
    fi

    # User storage is still accessible but this override is genuinely absent:
    # mirror an explicit reset/removal into metadata.
    if [ -e "$d" ]; then
        rm -f "$d" "$d.tmp" 2>/dev/null
        sync
        log_i "removed metadata $name after explicit theme reset"
    fi
}

while true; do
    sync_one style.xml
    sync_one accent.xml
    sleep 2
done
