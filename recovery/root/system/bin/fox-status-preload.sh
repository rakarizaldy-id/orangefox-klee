#!/system/bin/sh
# KleeStatusVarsPreloadV3: preserve saved OrangeFox status-bar variables
# before the GUI parses /twres/resources/vars.xml on the pre-decrypt screen,
# then keep the bind through the first post-decrypt theme reload.
# V3 latches the first post-decrypt InfoManager marker so later reloads cannot
# move the target and force the cleanup path to wait for its timeout.

LOG=/tmp/recovery.log
VARS=/twres/resources/vars.xml
TMP=/tmp/vars.status-preload.xml
FOX=/persist/.foxs

log_msg() {
    echo "I:KleeStatusVarsPreloadV3: $*" >> "$LOG"
}

do_cleanup() {
    reason="$1"
    if mount | grep -q " on $VARS "; then
        if umount "$VARS" 2>/dev/null; then
            log_msg "unbound patched vars.xml $reason"
        else
            log_msg "failed to unbind patched vars.xml $reason"
        fi
    fi
    rm -f "$TMP" 2>/dev/null
}

first_line_after() {
    pattern="$1"
    min_line="$2"
    grep -nF "$pattern" "$LOG" 2>/dev/null | cut -d: -f1 | while read n; do
        [ -n "$n" ] || continue
        if [ "$n" -gt "$min_line" ] 2>/dev/null; then
            echo "$n"
            break
        fi
    done
}

if [ "$1" = "cleanup" ]; then
    do_cleanup "by immediate cleanup"
    exit 0
fi

if [ "$1" = "cleanup-delayed" ]; then
    start_line=$(wc -l < "$LOG" 2>/dev/null)
    [ -n "$start_line" ] || start_line=0
    log_msg "delayed cleanup watcher started at line $start_line"

    info_line=0
    i=0
    while [ "$i" -lt 60 ]; do
        if [ "$info_line" -eq 0 ]; then
            candidate=$(first_line_after "InfoManager loading from '/sdcard/Fox/.foxs'." "$start_line")
            if [ -n "$candidate" ] && [ "$candidate" -gt 0 ] 2>/dev/null; then
                info_line="$candidate"
                log_msg "latched post-decrypt InfoManager at line $info_line"
            fi
        fi

        if [ "$info_line" -gt 0 ] 2>/dev/null; then
            reload_line=$(first_line_after "I:Theme reloaded" "$info_line")
            if [ -n "$reload_line" ] && [ "$reload_line" -gt "$info_line" ] 2>/dev/null; then
                log_msg "detected post-decrypt Theme reloaded at line $reload_line"
                # Give the GUI one short settle interval after its reload completed.
                sleep 1
                do_cleanup "after post-decrypt theme reload"
                exit 0
            fi
        fi

        sleep 1
        i=$((i + 1))
    done

    log_msg "delayed cleanup timeout"
    do_cleanup "after timeout"
    exit 0
fi

if [ ! -f "$FOX" ] || [ ! -f "$VARS" ]; then
    log_msg "skip: missing $FOX or $VARS"
    exit 0
fi

rm -f "$TMP"
cp "$VARS" "$TMP" || {
    log_msg "failed to copy vars.xml"
    exit 0
}
chmod 0644 "$TMP"

patched=0
for k in center_clock enable_battery show_cpu_temp style_battery hide_notch; do
    v=$(strings -n 1 "$FOX" 2>/dev/null | grep -A1 -x "$k" | tail -n 1)
    case "$v" in
        0|1|2)
            if grep -q "name=\"$k\"" "$TMP"; then
                sed -i "s#name=\"$k\" value=\"[^\"]*\"#name=\"$k\" value=\"$v\"#" "$TMP"
                log_msg "$k=$v"
                patched=1
            fi
            ;;
        *)
            log_msg "skip $k: invalid or missing value"
            ;;
    esac
done

if [ "$patched" != "1" ]; then
    log_msg "skip bind: no status variables patched"
    rm -f "$TMP"
    exit 0
fi

if mount --bind "$TMP" "$VARS"; then
    log_msg "bound patched vars.xml"
else
    log_msg "bind failed"
    rm -f "$TMP"
fi

exit 0
