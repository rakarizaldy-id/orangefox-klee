#!/system/bin/sh
# FoxSettingsSyncV8 (Build38): V7 lifecycle plus first-install bootstrap.
# Encrypted-main keeps Build28/V6's proven FALL close-write bridge.
# Direct-PIN treats predecrypt metadata as authoritative, waits for the REAL
# decrypted normal profile (/data/media/0/Fox/.foxs), seeds selected prefs into
# it before native InfoManager loads /sdcard/Fox/.foxs, and never lets a stale
# normal profile flow back into fallback/metadata.
LOG=/tmp/recovery.log
D=/sdcard/Fox/.foxs
N=/data/media/0/Fox/.foxs
M=/metadata/Fox/.foxs
F=/data/recovery/Fox/.foxs
P=/mnt/vendor/persist/.foxs
MERGE=/system/bin/foxs-merge
LIST=/system/etc/fox-user-prefs.list
STATE=/tmp/fox-settings-sync-v8
p(){ echo "I:FoxSettingsSyncV8: $*" >> "$LOG"; }
fmt(){ "$MERGE" --probe "$1" 2>/dev/null; }
mt(){ stat -c %Y "$1" 2>/dev/null; }
normal_line(){ grep -nF "InfoManager loading from '/sdcard/Fox/.foxs'." "$LOG" 2>/dev/null | tail -n 1 | cut -d: -f1; }

# inotifyd callback is used only by encrypted-main fallback_to_normal mode.
if [ -n "$1" ]; then
    case "$1" in *w*) ;; *) exit 0 ;; esac
    [ -d "$STATE" ] || exit 0
    [ -e "$STATE/claimed" ] && exit 0
    : > "$STATE/claimed"
    mode=$(cat "$STATE/mode" 2>/dev/null)
    if [ "$mode" = "fallback_to_normal" ]; then
        out=$("$MERGE" "$F" "$D" "$LIST" 2>/dev/null); rc=$?
        if [ "$rc" = "0" ]; then p "INOTIFY critical fallback -> normal ($out)"
        elif [ "$rc" = "10" ]; then p "INOTIFY critical fallback -> normal (unchanged)"
        else p "INOTIFY critical fallback -> normal error rc=$rc"
        fi
        chown media_rw:media_rw "$D" 2>/dev/null
        chmod 0664 "$D" 2>/dev/null
    else
        p "INOTIFY event with unexpected mode=$mode"
    fi
    : > "$STATE/done"
    exit 0
fi

[ "$(getprop twrp.decrypt.done)" = "true" ] || exit 0
rm -rf "$STATE"; mkdir -p "$STATE" /metadata/Fox
p "post-decrypt hook started"

anchor=$(grep -nF "Data successfully decrypted" "$LOG" 2>/dev/null | tail -n 1 | cut -d: -f1)
[ -n "$anchor" ] || anchor=0
fl=$(grep -nF "InfoManager loading from '/data/recovery/Fox/.foxs'." "$LOG" 2>/dev/null | tail -n 1 | cut -d: -f1)
fallback_loaded=0
if [ -n "$fl" ]; then
    if [ "$anchor" -eq 0 ] 2>/dev/null || [ "$fl" -lt "$anchor" ] 2>/dev/null; then fallback_loaded=1; fi
fi
p "decrypt anchor=$anchor fallback_loaded=$fallback_loaded line=${fl:-0}"

if [ "$fallback_loaded" = "0" ]; then
    # DIRECT PIN -------------------------------------------------------------
    # Startup already loaded /persist -> metadata before PIN, so metadata is the
    # authoritative user-preference snapshot for this direct-decrypt lifecycle.
    # The Build29 race was caused by touching /sdcard while the real decrypted
    # /data/media/0 was not visible yet, then later trusting the stale real normal.
    mf=$(fmt "$M"); ff=$(fmt "$F")
    p "direct-PIN formats metadata=$mf fallback=$ff real-normal=$(fmt "$N")"
    if [ "$mf" != "versioned" ]; then
        # Build38 FIRST-INSTALL BOOTSTRAP ------------------------------------
        # A genuinely fresh OrangeFox state has no metadata profile and no
        # encrypted fallback yet. In that one case, the freshly-created REAL
        # decrypted normal profile is authoritative by definition. Non-empty
        # invalid/corrupt stores still take V7's fail-safe path below.
        if [ ! -s "$M" ] && [ ! -s "$F" ]; then
            p "direct-PIN first-install bootstrap: metadata/fallback absent"

            # Wait for native OrangeFox to create a complete versioned normal
            # profile on the real decrypted /data/media/0 filesystem.
            i=0; nf="invalid"
            while [ "$i" -lt 300 ]; do
                nf=$(fmt "$N")
                [ "$nf" = "versioned" ] && break
                sleep 0.02
                i=$((i+1))
            done
            if [ "$nf" != "versioned" ]; then
                p "first-install real-normal readiness timeout format=$nf; fail-safe no propagation"
                rm -rf "$STATE"
                exit 0
            fi
            p "first-install real-normal ready"

            # Do not obscure /sdcard/Fox/.foxs while native InfoManager may still
            # be creating/loading it. Latch its first post-decrypt normal load;
            # theme reload is preferred but not required for the bootstrap copy.
            i=0; line=""; theme=""
            while [ "$i" -lt 500 ]; do
                if [ -z "$line" ]; then
                    cand=$(normal_line)
                    if [ -n "$cand" ] && [ "$cand" -gt "$anchor" ] 2>/dev/null; then line=$cand; fi
                fi
                if [ -n "$line" ]; then
                    theme=$(grep -nF "Theme reloaded" "$LOG" 2>/dev/null | tail -n 1 | cut -d: -f1)
                    if [ -n "$theme" ] && [ "$theme" -gt "$line" ] 2>/dev/null; then break; fi
                fi
                sleep 0.02
                i=$((i+1))
            done
            if [ -z "$line" ] || ! [ "$line" -gt "$anchor" ] 2>/dev/null; then
                p "first-install native normal-load timeout; fail-safe no propagation"
                rm -rf "$STATE"
                exit 0
            fi
            p "first-install native normal-load line=$line theme=${theme:-0}"

            # Re-probe after native load, then whole-file bootstrap the two
            # authoritative pre-decrypt stores. This exact N -> M/F flow was
            # validated runtime with identical SHA256 across all three files.
            nf=$(fmt "$N")
            if [ "$nf" != "versioned" ]; then
                p "first-install real-normal changed format=$nf; fail-safe no propagation"
                rm -rf "$STATE"
                exit 0
            fi
            mkdir -p /metadata/Fox /data/recovery/Fox
            cat "$N" > "$M" 2>/dev/null || { p "first-install normal -> metadata failed"; rm -rf "$STATE"; exit 0; }
            cat "$N" > "$F" 2>/dev/null || { p "first-install normal -> fallback failed"; rm -rf "$STATE"; exit 0; }
            chown media_rw:media_rw "$M" "$F" 2>/dev/null
            chmod 0664 "$M" "$F" 2>/dev/null
            sync
            if [ "$(fmt "$M")" != "versioned" ] || [ "$(fmt "$F")" != "versioned" ]; then
                p "first-install bootstrap verification failed; authoritative files preserved for diagnosis"
                rm -rf "$STATE"
                exit 0
            fi
            p "first-install normal -> metadata+fallback complete"

            # Prepare the physical persist inode required by init's existing
            # metadata/Fox/.foxs -> /persist/.foxs bind on the NEXT recovery boot.
            # Do not create a new bind here; keep the proven init lifecycle intact.
            if [ ! -e "$P" ]; then
                if mount -o remount,rw /mnt/vendor/persist 2>/dev/null; then
                    if : > "$P" 2>/dev/null; then
                        chmod 0600 "$P" 2>/dev/null
                        chown root:root "$P" 2>/dev/null
                        p "first-install persist target prepared"
                    else
                        p "first-install persist target create failed"
                    fi
                    sync
                    mount -o remount,ro /mnt/vendor/persist 2>/dev/null
                else
                    p "first-install persist remount rw failed"
                fi
            else
                p "first-install persist target already present"
            fi

            # Native normal profile has already loaded. Bind authoritative metadata
            # over the normal path now so any settings changed later in this first
            # decrypted session persist exactly like established direct-PIN boots.
            if mountpoint -q "$D" 2>/dev/null; then
                p "first-install normal target already a mountpoint"
            else
                mount --bind "$M" "$D" 2>/dev/null && p "first-install metadata bound to normal post-load" || p "first-install metadata bind post-load failed"
            fi
            rm -rf "$STATE"
            p "first-install bootstrap complete"
            exit 0
        fi

        p "direct-PIN metadata not versioned; fail-safe no propagation"
        rm -rf "$STATE"
        exit 0
    fi

    # Build54 POST-FORMAT FRESH-MEDIA BOOTSTRAP -------------------------
    # Format Data can leave authoritative versioned metadata/fallback profiles
    # while the newly-created real /data/media/0 has no .foxs at all. Seed only
    # that truly-absent normal file. An existing invalid/corrupt normal remains on
    # Build38's proven fail-safe path below and is never overwritten here.
    if [ "$mf" = "versioned" ] && [ "$ff" = "versioned" ] && [ ! -e "$N" ]; then
        seedtmp="$N.klee-seed.$$"
        mkdir -p /data/media/0/Fox
        rm -f "$seedtmp" 2>/dev/null
        if cat "$M" > "$seedtmp" 2>/dev/null; then
            chown media_rw:media_rw "$seedtmp" 2>/dev/null
            chmod 0664 "$seedtmp" 2>/dev/null
            if [ "$(fmt "$seedtmp")" = "versioned" ] && mv -f "$seedtmp" "$N" 2>/dev/null; then
                sync
                p "direct-PIN post-format fresh-media bootstrap metadata -> real-normal"
            else
                rm -f "$seedtmp" 2>/dev/null
                p "direct-PIN post-format fresh-media bootstrap verify/install failed; fail-safe no propagation"
                rm -rf "$STATE"
                exit 0
            fi
        else
            rm -f "$seedtmp" 2>/dev/null
            p "direct-PIN post-format fresh-media bootstrap copy failed; fail-safe no propagation"
            rm -rf "$STATE"
            exit 0
        fi
    fi

    # Wait for the actual decrypted normal file, not /sdcard's transient target.
    # Abort if native normal load is observed before we can seed it: preserving
    # authoritative metadata/fallback is safer than propagating a stale normal.
    i=0; nf="invalid"; line=""
    while [ "$i" -lt 200 ]; do
        nf=$(fmt "$N")
        if [ "$nf" = "versioned" ]; then break; fi
        line=$(normal_line)
        if [ -n "$line" ] && [ "$line" -gt "$anchor" ] 2>/dev/null; then
            p "direct-PIN native normal load raced before seed line=$line; fail-safe no propagation"
            rm -rf "$STATE"
            exit 0
        fi
        sleep 0.02
        i=$((i+1))
    done
    if [ "$nf" != "versioned" ]; then
        p "direct-PIN real-normal readiness timeout format=$nf; fail-safe no propagation"
        rm -rf "$STATE"
        exit 0
    fi

    # One final race check immediately before the critical seed.
    line=$(normal_line)
    if [ -n "$line" ] && [ "$line" -gt "$anchor" ] 2>/dev/null; then
        p "direct-PIN native normal load won final race line=$line; fail-safe no propagation"
        rm -rf "$STATE"
        exit 0
    fi

    out=$("$MERGE" "$M" "$N" "$LIST" 2>/dev/null); rc=$?
    if [ "$rc" = "0" ]; then
        p "direct-PIN pre-load metadata -> real-normal ($out)"
    elif [ "$rc" = "10" ]; then
        p "direct-PIN pre-load metadata -> real-normal (unchanged)"
    else
        p "direct-PIN pre-load seed error rc=$rc; fail-safe no propagation"
        rm -rf "$STATE"
        exit 0
    fi
    chown media_rw:media_rw "$N" 2>/dev/null
    chmod 0664 "$N" 2>/dev/null

    # Wait for the FIRST observed native normal load and its theme reload. Keep
    # that first line fixed so later repeated InfoManager loads cannot move the goal.
    i=0; line=""; theme=""
    while [ "$i" -lt 200 ]; do
        if [ -z "$line" ]; then
            cand=$(normal_line)
            if [ -n "$cand" ] && [ "$cand" -gt "$anchor" ] 2>/dev/null; then line=$cand; fi
        fi
        if [ -n "$line" ]; then
            theme=$(grep -nF "Theme reloaded" "$LOG" 2>/dev/null | tail -n 1 | cut -d: -f1)
            if [ -n "$theme" ] && [ "$theme" -gt "$line" ] 2>/dev/null; then break; fi
        fi
        sleep 0.02
        i=$((i+1))
    done
    if [ -z "$line" ] || ! [ "$line" -gt "$anchor" ] 2>/dev/null; then
        p "direct-PIN native normal-load timeout after seed; authoritative stores preserved"
        rm -rf "$STATE"
        exit 0
    fi
    p "direct-PIN native normal-load line=$line theme=${theme:-0}"

    # Verify selected prefs survived native load. A changed result here means the
    # native load raced/rewrote the file: repair disk but DO NOT propagate it.
    out=$("$MERGE" "$M" "$N" "$LIST" 2>/dev/null); rc=$?
    if [ "$rc" = "10" ]; then
        p "direct-PIN post-load verify metadata == real-normal"
    elif [ "$rc" = "0" ]; then
        p "direct-PIN post-load verify repaired drift ($out); fail-safe no propagation"
        chown media_rw:media_rw "$N" 2>/dev/null
        chmod 0664 "$N" 2>/dev/null
        rm -rf "$STATE"
        exit 0
    else
        p "direct-PIN post-load verify error rc=$rc; fail-safe no propagation"
        rm -rf "$STATE"
        exit 0
    fi

    # Build55 POST-DATA-WIPE FALLBACK BOOTSTRAP ----------------------
    # Advanced Wipe /data preserves /data/media and authoritative metadata, but
    # deletes /data/recovery/Fox/.foxs. Recreate ONLY a truly-absent fallback,
    # and only after M and the real decrypted normal profile have been proven
    # versioned/equal by the direct-PIN path above. Existing invalid/corrupt F is
    # never overwritten and retains Build38's fail-safe behavior.
    if [ "$mf" = "versioned" ] && [ "$(fmt "$N")" = "versioned" ] && [ ! -e "$F" ]; then
        seedtmp="$F.klee-seed.$$"
        mkdir -p /data/recovery/Fox
        rm -f "$seedtmp" 2>/dev/null
        if cat "$M" > "$seedtmp" 2>/dev/null; then
            chown media_rw:media_rw "$seedtmp" 2>/dev/null
            chmod 0664 "$seedtmp" 2>/dev/null
            if [ "$(fmt "$seedtmp")" = "versioned" ] && mv -f "$seedtmp" "$F" 2>/dev/null; then
                chown media_rw:media_rw "$F" 2>/dev/null
                chmod 0664 "$F" 2>/dev/null
                sync
                ff=versioned
                p "direct-PIN post-data-wipe fallback bootstrap metadata -> fallback"
            else
                rm -f "$seedtmp" 2>/dev/null
                p "direct-PIN post-data-wipe fallback bootstrap verify/install failed; fail-safe keep absent"
            fi
        else
            rm -f "$seedtmp" 2>/dev/null
            p "direct-PIN post-data-wipe fallback bootstrap copy failed; fail-safe keep absent"
        fi
    fi

    # Catch up fallback only from authoritative metadata, never from NORMAL.
    if [ "$ff" = "versioned" ]; then
        out=$("$MERGE" "$M" "$F" "$LIST" 2>/dev/null); rc=$?
        if [ "$rc" = "0" ]; then p "direct-PIN metadata -> fallback ($out)"
        elif [ "$rc" = "10" ]; then p "direct-PIN metadata -> fallback (unchanged)"
        else p "direct-PIN metadata -> fallback error rc=$rc (non-fatal)"
        fi
        chown media_rw:media_rw "$F" 2>/dev/null
        chmod 0664 "$F" 2>/dev/null
    else
        p "direct-PIN fallback format=$ff; skip catch-up"
    fi

    # Metadata is already authoritative. Bind it over /sdcard only AFTER native
    # has loaded the correctly-seeded real normal, preserving Build22 persistence.
    sync
    if mountpoint -q "$D" 2>/dev/null; then
        p "normal target already a mountpoint"
    else
        mount --bind "$M" "$D" 2>/dev/null && p "authoritative metadata bound to normal post-load" || p "metadata bind post-load failed"
    fi

    # Preserve Build22 physical persist anchor bootstrap for next boot.
    if [ ! -e "$P" ]; then
        if mount -o remount,rw /mnt/vendor/persist 2>/dev/null; then
            if : > "$P" 2>/dev/null; then chmod 0600 "$P" 2>/dev/null; p "persist target prepared"; else p "persist target create failed"; fi
            sync
            mount -o remount,ro /mnt/vendor/persist 2>/dev/null
        else
            p "persist remount rw failed"
        fi
    else
        p "persist target already present"
    fi
    rm -rf "$STATE"
    p "post-decrypt hook complete"
    exit 0
fi

# ENCRYPTED-MAIN -------------------------------------------------------------
# Keep Build28/V6's proven behavior intact for Cancel -> encrypted-main -> PIN.
mkdir -p /sdcard/Fox

# Prepare NORMAL whole-file base before native normal-profile load. Metadata mirrors
# the previously selected normal profile from the last decrypted session.
mf=$(fmt "$M"); df=$(fmt "$D"); ff=$(fmt "$F")
base=""
if [ "$mf" = "versioned" ] && [ "$df" != "versioned" ]; then
    base=M
elif [ "$df" = "versioned" ] && [ "$mf" != "versioned" ]; then
    base=D
elif [ -s "$M" ] && [ -s "$D" ]; then
    mm=$(mt "$M"); dm=$(mt "$D"); [ -n "$mm" ] || mm=0; [ -n "$dm" ] || dm=0
    if [ "$dm" -gt "$mm" ] 2>/dev/null; then base=D; else base=M; fi
elif [ -s "$D" ]; then
    base=D
elif [ -s "$M" ]; then
    base=M
elif [ -s "$F" ] && [ "$ff" = "versioned" ]; then
    base=F
fi
p "pre-branch formats metadata=$mf normal=$df fallback=$ff base=$base"
case "$base" in
    M) cat "$M" > "$D" 2>/dev/null || { p "metadata -> normal pre-branch failed"; rm -rf "$STATE"; exit 0; }; p "metadata -> normal pre-branch" ;;
    D) p "normal kept as pre-branch base" ;;
    F) cat "$F" > "$D" 2>/dev/null || { p "fallback normal seed failed"; rm -rf "$STATE"; exit 0; }; p "fallback seeded pre-branch normal" ;;
    *) p "no usable normal base; fail-open"; rm -rf "$STATE"; exit 0 ;;
esac
chown media_rw:media_rw "$D" 2>/dev/null
chmod 0664 "$D" 2>/dev/null

# Proven Build27 path: native will save current encrypted-main RAM prefs to FALL.
# Catch close-write and bridge selected user prefs into normal before native loads D.
echo fallback_to_normal > "$STATE/mode"
/system/bin/inotifyd "$0" "$F:ww" &
watchpid=$!
p "inotify armed pid=$watchpid mode=fallback_to_normal"

i=0
while [ "$i" -lt 100 ]; do
    [ -e "$STATE/done" ] && break
    sleep 0.05
    i=$((i+1))
done
kill "$watchpid" 2>/dev/null
wait "$watchpid" 2>/dev/null
if [ ! -e "$STATE/done" ]; then
    p "inotify native FALL close timeout; fail-open"
    rm -rf "$STATE"
    exit 0
fi
p "critical event completed"

# D already contains bridged prefs; wait until native normal load is observed.
i=0; line=""
while [ "$i" -lt 60 ]; do
    line=$(normal_line)
    if [ -n "$line" ] && [ "$line" -gt "$anchor" ] 2>/dev/null; then break; fi
    sleep 0.05
    i=$((i+1))
done
p "post-critical normal-load line=${line:-0}"

# Persist the selected normal profile to metadata and bind it for the rest of this
# decrypted session. This remains byte-for-behavior equivalent to V6 encrypted path.
cat "$D" > "$M" 2>/dev/null || { p "normal -> metadata post-load failed"; rm -rf "$STATE"; exit 0; }
chown media_rw:media_rw "$M" "$D" 2>/dev/null
chmod 0664 "$M" "$D" 2>/dev/null
sync
if mountpoint -q "$D" 2>/dev/null; then
    p "normal target already a mountpoint"
else
    mount --bind "$M" "$D" 2>/dev/null && p "normal mirrored to metadata and bound post-load" || p "metadata bind post-load failed"
fi

# Preserve Build22 physical persist anchor bootstrap for next boot.
if [ ! -e "$P" ]; then
    if mount -o remount,rw /mnt/vendor/persist 2>/dev/null; then
        if : > "$P" 2>/dev/null; then chmod 0600 "$P" 2>/dev/null; p "persist target prepared"; else p "persist target create failed"; fi
        sync
        mount -o remount,ro /mnt/vendor/persist 2>/dev/null
    else
        p "persist remount rw failed"
    fi
else
    p "persist target already present"
fi
rm -rf "$STATE"
p "post-decrypt hook complete"
exit 0
