# Build History — Development Timeline

The detailed numbered timeline below documents the historical bring-up phase through the Build60 golden regression baseline.

The current public release is newer than this table. Later stabilization work intentionally is not expanded into every internal nano-build number here; the user-facing state is documented in `CHANGELOG.md` and `TEST_MATRIX.md`.

| Build | Focus | Key change | Final classification |
|---|---|---|---|
| Pre-Build6 | Foundation | Bring-up: vendor_boot/Virtual A/B, IDXM FBE, CN FBE investigation, fastbootd, display/screenshot, ODM, settings architecture | Historical consolidated phase |
| 6 | Experimental baseline | Early provenance image | Experimental |
| 7 | FBE/PIN baseline | Post-decrypt .foxs sync works; pre-decrypt anchor missing | Superseded |
| 8 | Persist overlay | Directory overlay on /persist | Rejected: stuck/glitch |
| 9 | Persist placeholder | Aggressive early bind/placeholder | Rejected |
| 10 | Temporary persist copy | Early cleanup | Rejected |
| 11–12 | Diagnostics | Delayed persist handling variants | Diagnostic |
| 13 | Settings anchor breakthrough | Post-decrypt metadata seed + physical persist anchor | Validated |
| 14 | Fallback variant | No useful advantage | Superseded |
| 15 | Touch stabilization | KleeTouchFixV3 Novatek/ODM/touch_report | Validated early final |
| 16 | ThemeSync V1 | Pre-decrypt theme staging | Rejected permission issue |
| 17 | ThemeSync V2 | 0644 theme cache | Superseded shutdown-cache issue |
| 18 | Status preload V1 | Manual patch worked, launcher did not | Experimental |
| 19 | Status synchronous launcher | Cleanup too early | Superseded |
| 20 | Delayed cleanup | Polling marker race | Superseded |
| 21 | StatusVarsPreload V3 | Latched deterministic cleanup | PASS |
| 22 | ThemeSync V3 | Shutdown/reset behavior fixed | PASS candidate |
| 23 | Selective profile sync | foxs-merge/allowlist watcher | Experimental |
| 24 | Profile parser fix | Header/self-heal corrected | Superseded race |
| 25 | GUI bridge | Nested threaded-action collision | Rejected |
| 26 | inotify :w | Insufficient on device | Diagnostic |
| 27 | inotify :ww | Encrypted-main passed, direct-PIN timeout remained | Superseded |
| 28 | Settings core | Direct-PIN/encrypted-main passed | Superseded by media-shadow issue |
| 29 | Media-shadow sink | Brightness flash fixed | Superseded by stale-normal race |
| 30 | Settings functional baseline | FoxSettingsSyncV7 + KleeFoxProfileSyncV2 | PASS |
| 31 | Branding experiment | Cosmetic branch workaround | Superseded |
| 32 | Native branch identity | Patched recovery binary for real [Branch]: klee | PASS |
| 33 | Device identity | POCO X8 Pro (klee) friendly model | PASS |
| 34 | Haptic stock-like V1 | AW86927 stock module/firmware integration | Test |
| 35 | Haptic SELinux-safe | Stock-labeled firmware path | PASS foundation |
| 36 | Haptic strength primer | NO-PLAY FF primer -> level 0x80 | PASS |
| 37 | Haptic duration closure | FF_CONSTANT effect_id=11 / mode=3 | PASS |
| 38 | Stable core baseline | FoxSettingsSyncV8 + first-install bootstrap; core invariants frozen | Stable baseline |
| 39 | Klee Tools Self-Test V1 | twrp xset UI | Rejected deadlock |
| 40 | Klee Tools ftls | cmd -> ftls | Rejected threaded behavior |
| 41 | List UI | One-shot results page | Worked, UX rejected |
| 42 | Live console Self-Test | terminalcommand + action page | PASS |
| 43 | Storage/Partition Health | ROM-agnostic checks | PASS |
| 44 | Clear OrangeFox Logs | Native swipe confirmation | PASS |
| 45 | Fenrir V1 | Bootchain + vendor_boot repair/cache | Test/PASS foundation |
| 46 | Fenrir FBE guard | Locked state REFUSE/zero writes | PASS |
| 47 | Fenrir release baseline | STALE cache refresh from active + anti-downgrade + idempotency | PASS baseline |
| 48 | Private persist propagation | MS_PRIVATE after bind | PASS inherited |
| 49 | Wipe-prep V1 | Metadata-destructive wipe helper | Experimental |
| 50 | Wipe-prep V2 | Expanded .foxs alias cleanup | PASS helper |
| 51 | GUI cmd helper | Thread conflict remained | Superseded |
| 52 | Native wipe queues | LIST/DATAMEDIA two-action architecture | PASS architecture |
| 53 | mi_ext closure | Removed duplicate ext4 fallback for real EROFS mi_ext | PASS |
| 54 | Fresh-media profile bootstrap | Absent-only metadata -> real-normal seed | PASS |
| 55 | Advanced Wipe FBE repair | POSTLIST + fallback self-heal | Logic proven; GUI sequencing incomplete |
| 56 | Queue-done latch | Reduced race | Superseded |
| 57 | tw_busy guard | Still raced ActionThread teardown | Rejected design |
| 58 | Advanced Wipe closure | PRE -> WIPE -> POSTLIST same worker | FULL RUNTIME PASS |
| 59 | Format Data ODM closure | Stop touch_report before DATAMEDIA dynamic unmap | FULL RUNTIME PASS; superseded by post-format touch issue |
| 60 | Format Data touch closure | POSTDATAMEDIA guarded resume | HISTORICAL GOLDEN / FULL REGRESSION PASS |

Exact per-build numbering before Build6 was not preserved strongly enough to reconstruct without guessing; those earliest changes are grouped under Foundation.

## Current release stabilization — 20 August 2026

After the historical Build60 baseline, the project completed a later stabilization phase focused on:

- one authoritative encrypted/decrypted OrangeFox settings store;
- safe pre-decrypt aliases without touching `/data` during early metadata-encryption startup;
- Recovery Password create/unlock/remove persistence;
- safe Home/Back routing from the Android/FBE PIN page;
- theme/accent/navigation persistence across reload and reboot;
- removal of custom threaded GUI hooks that raced native OrangeFox actions;
- safe Clear Saved Logs behavior without truncating the active recovery log;
- Fenrir A/B `vendor_boot` verification/repair against the current running recovery;
- runtime confirmation that the remaining rare visual glitch correlates with native screen dim/off transitions rather than Fenrir writes.

The runtime result of that phase is the current 2026-08-20 release image documented in `README.md`.
