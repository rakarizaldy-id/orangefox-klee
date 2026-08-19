#!/system/bin/sh
# KleeFoxProfileSyncV2 (Build29): one-shot predecrypt reconciliation plus
# sink-only media-shadow alignment. It never polls continuously. User-facing
# prefs are selectively reconciled between metadata (/persist startup profile)
# and OrangeFox's encrypted fallback; the final fallback prefs are then copied
# selectively into /data/media/.foxs so Cancel -> encrypted-main cannot briefly
# load stale user-facing settings. The media shadow never participates as source.
LOG=/tmp/recovery.log
META=/metadata/Fox/.foxs
FALL=/data/recovery/Fox/.foxs
SHADOW=/data/media/.foxs
MERGE=/system/bin/foxs-merge
LIST=/system/etc/fox-user-prefs.list

log_i(){ echo "I:KleeFoxProfileSyncV2: $*" >> "$LOG"; }
fmt(){ "$MERGE" --probe "$1" 2>/dev/null; }
mtime(){ stat -c %Y "$1" 2>/dev/null; }
merge_one(){
    src="$1"; dst="$2"; tag="$3"
    out=$("$MERGE" "$src" "$dst" "$LIST" 2>/dev/null); rc=$?
    if [ "$rc" = "0" ]; then
        chown media_rw:media_rw "$dst" 2>/dev/null
        chmod 0664 "$dst" 2>/dev/null
        sync
        log_i "$tag ($out)"
    elif [ "$rc" = "10" ]; then
        log_i "$tag (unchanged)"
    else
        log_i "merge error rc=$rc: $tag"
    fi
}
sync_shadow(){
    # /data/media/.foxs is only a transient pre-fallback profile. Never let it
    # win by mtime and never whole-file copy into it: preserve context keys such
    # as tw_storage_path=/data/media. Only touch an already-valid native file.
    [ -s "$SHADOW" ] || { log_i "media shadow skip: unavailable"; return; }
    sf=$(fmt "$SHADOW"); ff_now=$(fmt "$FALL")
    if [ "$ff_now" != "versioned" ]; then
        log_i "media shadow skip: fallback format=$ff_now"
        return
    fi
    if [ "$sf" != "versioned" ]; then
        log_i "media shadow skip: format=$sf"
        return
    fi
    out=$("$MERGE" "$FALL" "$SHADOW" "$LIST" 2>/dev/null); rc=$?
    if [ "$rc" = "0" ]; then
        # foxs-merge truncates the existing inode, preserving shadow ownership,
        # mode and non-allowlisted environment keys.
        sync
        log_i "media shadow <- fallback ($out)"
    elif [ "$rc" = "10" ]; then
        log_i "media shadow <- fallback (unchanged)"
    else
        log_i "media shadow merge error rc=$rc"
    fi
}

log_i "one-shot started"
# /data/recovery appears only after metadata-encrypted userdata is mounted.
i=0
while [ "$i" -lt 30 ]; do
    [ -s "$META" ] && [ -s "$FALL" ] && break
    sleep 1
    i=$((i+1))
done
[ -s "$META" ] && [ -s "$FALL" ] || { log_i "skip: metadata/fallback unavailable"; exit 0; }

mf=$(fmt "$META"); ff=$(fmt "$FALL")
log_i "formats metadata=$mf fallback=$ff"

# A native versioned file always outranks Build23's known header-stripped file,
# regardless of mtime. This is the recovery/self-heal path after Build23.
if [ "$ff" = "versioned" ] && [ "$mf" != "versioned" ]; then
    merge_one "$FALL" "$META" "fallback -> metadata self-heal"
    sync_shadow
    exit 0
fi
if [ "$mf" = "versioned" ] && [ "$ff" != "versioned" ]; then
    merge_one "$META" "$FALL" "metadata -> fallback self-heal"
    sync_shadow
    exit 0
fi

mm=$(mtime "$META"); fm=$(mtime "$FALL")
[ -n "$mm" ] || mm=0
[ -n "$fm" ] || fm=0
if [ "$fm" -gt "$mm" ] 2>/dev/null; then
    merge_one "$FALL" "$META" "newer fallback -> metadata"
elif [ "$mm" -gt "$fm" ] 2>/dev/null; then
    merge_one "$META" "$FALL" "newer metadata -> fallback"
else
    # Equal-time predecrypt ambiguity: encrypted fallback is the active
    # encrypted-main profile, so let its user-facing prefs win.
    merge_one "$FALL" "$META" "equal-time fallback -> metadata"
fi
sync_shadow
exit 0
