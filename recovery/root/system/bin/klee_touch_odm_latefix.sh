#!/system/bin/sh
# KleeTouchFixV3: ODM-ready touch_report retry/stability helper
# Keep the Novatek firmware visible while touch_report initializes, and retry
# if the service exits during the early recovery boot race.

LOG=/tmp/recovery.log
FW=/odm/firmware/novatek_nt38771_p10_fw_tm.bin

log_i() {
    echo "I:KleeTouchFixV3: $*" >> "$LOG"
}

slot="$(getprop ro.boot.slot_suffix)"

find_odm_dev() {
    for d in \
        "/dev/block/mapper/odm${slot}" \
        /dev/block/mapper/odm \
        /dev/block/mapper/odm_a \
        /dev/block/mapper/odm_b \
        "/dev/block/by-name/odm${slot}" \
        /dev/block/by-name/odm
    do
        if [ -b "$d" ]; then
            echo "$d"
            return 0
        fi
    done
    return 1
}

ensure_odm() {
    if grep -q ' /odm ' /proc/mounts 2>/dev/null && [ -r "$FW" ]; then
        return 0
    fi

    odmdev="$(find_odm_dev)"
    if [ -z "$odmdev" ]; then
        return 1
    fi

    mkdir -p /odm
    if ! grep -q ' /odm ' /proc/mounts 2>/dev/null; then
        if mount -t erofs -o ro "$odmdev" /odm >> "$LOG" 2>&1; then
            log_i "mounted $odmdev on /odm"
        fi
    fi

    [ -r "$FW" ]
}

log_i "helper started; waiting for ODM + Novatek firmware"

wait_i=0
while [ "$wait_i" -lt 180 ]; do
    if ensure_odm; then
        break
    fi
    wait_i=$((wait_i + 1))
    sleep 1
done

if ! ensure_odm; then
    log_i "ODM/firmware not ready after ${wait_i}s; leaving stock touch_report state unchanged"
    exit 0
fi

attempt=1
while [ "$attempt" -le 8 ]; do
    # Recovery may have changed the /odm mount between attempts. Re-establish
    # firmware visibility before every touch_report restart.
    if ! ensure_odm; then
        log_i "attempt $attempt: ODM/firmware temporarily unavailable; retrying"
        attempt=$((attempt + 1))
        sleep 2
        continue
    fi

    log_i "attempt $attempt: restarting touch_report"
    stop touch_report 2>/dev/null
    sleep 1
    start touch_report 2>/dev/null

    # Give init/process startup up to 5 seconds.
    settle=0
    state=""
    while [ "$settle" -lt 5 ]; do
        state="$(getprop init.svc.touch_report)"
        if [ "$state" = "running" ]; then
            break
        fi
        settle=$((settle + 1))
        sleep 1
    done

    if [ "$state" = "running" ]; then
        # The old helper could see a transient start and exit too early. Hold
        # for a short stability window and verify it is still alive.
        sleep 5
        state="$(getprop init.svc.touch_report)"
        if [ "$state" = "running" ]; then
            pid="$(getprop init.svc_debug_pid.touch_report)"
            log_i "touch_report stable after attempt $attempt; pid=${pid:-unknown}"
            exit 0
        fi
        log_i "attempt $attempt: touch_report stopped during stability window"
    else
        log_i "attempt $attempt: touch_report did not reach running state (${state:-unknown})"
    fi

    attempt=$((attempt + 1))
    sleep 2
done

state="$(getprop init.svc.touch_report)"
log_i "all retries exhausted; final touch_report state=${state:-unknown}"
exit 0
