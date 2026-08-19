# Full Changelog — Project start / Chat1 → Chat9 / Build60 FINAL

This file is the consolidated chronology of the `klee` OrangeFox project through the current Chat9 final release. Early periods are summarized from the preserved historical handoffs; tracked build numbers become increasingly exact from Build6 onward.

## Foundation — earliest conversations before tracked Build6

The project began as an OrangeFox R12.0 bring-up for POCO X8 Pro `klee` on the MT6899 family. The early work established the platform facts and solved or characterized the foundations that later builds had to preserve:

- recovery lives in 64 MiB `vendor_boot`, not a standalone recovery partition;
- Virtual A/B slot behavior and fastboot flashing workflow;
- IDXM Android 16 FBE/decryption bring-up;
- later CN FBE validation including Weaver/authsecret/NXP services;
- fastbootd USB detection and Windows driver behavior;
- display/panel glitch investigation and mitigation;
- screenshot/display stack fixes;
- ODM mount/unmount behavior;
- ADB root, MTP and dynamic-partition behavior;
- recovery idle thermal/load investigation;
- OrangeFox release/statusbar/theme customization;
- persistent settings architecture investigation across `/persist`, `/metadata` and encrypted `/data` stores.

These became the platform invariants that later builds were expected not to regress.

---

## Build6–15 — FBE-safe settings bootstrap + touch

### Build6
Early experimental baseline/provenance image.

### Build7
Stable FBE/PIN baseline. Post-decrypt `.foxs` could sync to metadata and bind into the settings path. Fresh-state pre-decrypt anchor was still missing.

### Build8 — rejected
Tried a directory overlay on `/persist`. Result: stuck/glitch at logo.

### Build9 — rejected
Tried a physical persist placeholder plus metadata bind before decrypt. Preload appeared to work but the design was more aggressive and coincided with a transient KeyMint/Vold failure state.

### Build10 — rejected
Temporary persist copy with early cleanup. Cleanup occurred before decrypt and the approach was abandoned.

### Build11–12 — diagnostic
Explored longer-lived and delayed persist handling; no advantage over the later Build13 architecture.

### Build13 — breakthrough
Introduced post-decrypt anchor bootstrap:

- first clean recovery boot does not create a dangerous pre-decrypt target;
- FBE decrypts normally;
- after decrypt, seed `/metadata/Fox/.foxs`;
- bind metadata to user settings;
- create a zero-byte physical `/mnt/vendor/persist/.foxs` anchor;
- next recovery boot can bind metadata over `/persist/.foxs` before PIN.

Validated PIN/FBE, settings preload/persistence, anchor regeneration, clean-room bootstrap and Android→recovery roundtrip.

### Build14
Fallback/cleanup variant; no useful advantage.

### Build15 — early final
Build13 functionality plus stronger `KleeTouchFixV3` for Novatek touch: defensive ODM handling, firmware visibility checks, retries, `touch_report` stabilization and diagnostics. Clean-room sanity PASS.

---

## Build16–23 — theme/status preload and selective profile architecture

### Build16 — ThemeSync V1
Pre-decrypt theme staging introduced. Failed because metadata theme XML permissions were considered insecure by init.

### Build17 — ThemeSync V2
Fixed theme file mode to 0644; staging worked, but shutdown behavior could delete the last-known-good theme cache.

### Build18
First status-variable preload attempt; manual patch worked but init launcher did not.

### Build19
Synchronous launcher fixed startup, but cleanup unbound patched status variables too early after decrypt.

### Build20
Delayed cleanup added, but polling tracked a moving “latest InfoManager” marker and could time out.

### Build21 — StatusVarsPreload V3
Latched the first post-decrypt InfoManager load and first subsequent theme reload; deterministic cleanup. Dynamic status roundtrip PASS.

### Build22 — stable candidate
ThemeSync V3 fixed shutdown deletion while preserving explicit reset behavior. Repeated recovery reboot + dynamic theme changes PASS. FBE, touch and status preload remained stable.

### Build23 — experimental
Introduced selective profile synchronization (`foxs-merge`, allowlist, profile watcher). Discovered OrangeFox also reads native encrypted stores and that a generated fallback could be rejected for file-version mismatch. Build23 was not final.

---

## Build24–33 — settings-sync closure and release identity

### Build24
Fixed parser/self-heal header corruption; post-decrypt polling race remained.

### Build25
GUI-page bridge created a nested threaded-action collision; rejected.

### Build26
Investigated toybox `inotifyd`; `:w` was insufficient on-device.

### Build27
`:ww` inotify bridge passed encrypted-main testing but direct-PIN timeout behavior remained.

### Build28
Direct-PIN and encrypted-main settings core passed. Broader testing exposed stale media-shadow brightness flash on Cancel.

### Build29
Added media-shadow sink and fixed the flash. Deliberate mismatch testing exposed a direct-PIN stale-normal race.

### Build30 — settings functional baseline
FoxSettingsSyncV7 + KleeFoxProfileSyncV2 solved direct-PIN stale-normal reconciliation, encrypted fallback handling, media shadow, selective user-facing preferences and context-specific `tw_storage_path`. Clean factory bootstrap was validated.

### Build31
Branding/release presentation experiment and temporary cosmetic `[Branch]` workaround; not final provenance fix.

### Build32
Patched the native recovery binary so `[Branch] : klee` is real, not a log-only workaround.

### Build33
Added `ro.orangefox.device_model=POCO X8 Pro`, giving the friendly startup line `POCO X8 Pro (klee)` while preserving internal identifiers.

---

## Build34–38 — AW86927 haptic + stable core baseline

### Build34
First stock-like AW86927 haptic integration test.

### Build35
Made firmware loading SELinux-safe by using the labeled stock vendor source rather than copying firmware into tmpfs.

### Build36
FF no-play primer proved OrangeFox could later reach stronger haptic level without producing a boot vibration.

### Build37
Moved to `FF_CONSTANT` duration path (`effect_id=11`, `activate_mode=3`) so UI duration maps to real motor duration while retaining strong haptics.

### Build38 — stable core baseline
Upgraded settings synchronization to FoxSettingsSyncV8 and solved first-install settings bootstrap. Build38 was promoted as the stable core baseline. Core invariants included FBE (IDXM/CN), touch, display/screenshot, settings persistence, fastbootd, ODM, status/theme/release behavior, ADB root and haptic backend.

---

## Build39–44 — Klee Tools diagnostics

### Build39
First Recovery Self-Test UI attempt using `twrp xset`; ADB worked but threaded UI invocation deadlocked.

### Build40
Tried `cmd → ftls`; still unsuitable due to threaded-action behavior.

### Build41
One-shot list-style status UI; technically worked but UX was rejected.

### Build42
Moved Self-Test to OrangeFox native live console using `terminalcommand` + action page. Runtime UX approved.

### Build43
Added Storage / Partition Health with ROM-agnostic dynamic-partition checks. Runtime approved.

### Build44
Added Clear OrangeFox Logs with native swipe confirmation. Runtime PASS. “Clear Console” itself was later parked because the visible console history is process-RAM state; deleting log files is not equivalent to clearing the GUI console.

---

## Build45–47 — Fenrir Install / Repair

### Build45
First integrated Fenrir workflow:

- embedded validated preloader and LK assets;
- exact-size/hash verification;
- idempotent preloader/LK repair;
- persistent vendor_boot cache;
- A/B vendor_boot verification/repair;
- final `FENRIR READY` verification.

### Build46
Added fail-closed FBE guard. Fenrir refuses destructive operations unless `twrp.user.0.decrypt=1` and `twrp.decrypt.done=true`. Locked state exits with code 4 and performs zero bootchain/cache writes.

### Build47 — Fenrir release baseline
Made vendor_boot cache upgrade-safe:

- valid cache equal to active recovery → `VERIFIED`;
- valid but different cache → `STALE`;
- STALE cache atomically refreshed from the currently running active vendor_boot;
- invalid/corrupt cache → `REFUSE`;
- inactive slot repaired only from refreshed/verified cache;
- second run is idempotent and zero-write.

Runtime matrix PASS for pre-decrypt refusal, stale-cache refresh, active-slot protection, inactive repair, reboot persistence and idempotency.

---

## Build48–54 — Format Data, metadata aliases and fresh-media profile bootstrap

### Build48
Made `/persist` mount propagation private (`MS_PRIVATE`) after the bind, reducing propagation side effects during destructive wipe operations.

### Build49
Introduced `klee-wipe-prep` and a TWRP wrapper to prepare metadata-destructive wipes. Early GUI invocation still had action-thread issues.

### Build50
`KleeWipePrepV2` expanded alias cleanup to `/persist/.foxs`, physical persist target, `/sdcard/Fox/.foxs` and `/data/media/0/Fox/.foxs`. It only unmounted aliases; no settings files were deleted or copied.

### Build51
Changed the GUI helper action from `terminalcommand` to `cmd`; threaded conflict still remained.

### Build52
Moved to OrangeFox/TWRP native two-action queues:

- Advanced Wipe: helper `LIST` → native `wipe LIST`;
- Format Data: helper `DATAMEDIA` → native `wipe DATAMEDIA`.

This removed the previous standalone helper action design.

### Build53
Diagnosed duplicate `mi_ext` parser objects. The actual `mi_ext` is EROFS, so the duplicate ext4 fallback line was removed while all other logical partition entries remained untouched. GUI Format Data then passed full dynamic unmap + userdata/metadata formatting.

### Build54
Added narrow fresh-media `.foxs` bootstrap after Format Data. If metadata and fallback are valid/versioned and the real normal media profile is truly absent, metadata is atomically seeded into `/data/media/0/Fox/.foxs`. Existing invalid/corrupt media profiles remain fail-safe.

Runtime validation around Build53/54:

- GUI Format Data: PASS;
- dynamic unmap, including single `mi_ext`: PASS;
- Android post-format boot with fresh metadata encryption: PASS;
- first recovery boot media bootstrap: PASS;
- second recovery boot persistence: PASS;
- Fenrir meaningful preloader/LK hashes remained golden;
- Cache and Dalvik wipes passed.

---

## Build55–58 — Advanced Wipe Data / Android 16 FBE closure

### Root-cause discovery after Build54
Advanced Wipe → Data returned status 0 and correctly preserved `/data/media`, but the next recovery boot failed `fscrypt_init_user0()` even though metadata encryption and key material were intact.

Investigation proved the native preserve-media wipe removed parent directory skeletons required by Android 16 user-storage preparation. Manually recreating those parents with tested owner/mode/context immediately restored `user0=1`, `twrp.decrypt.done=true` and normal FBE decryption.

The wipe also deletes `/data/recovery/Fox/.foxs`, while metadata and media profiles survive.

### Build55
Added two narrow fixes:

1. `klee-wipe-prep POSTLIST` recreates only missing Android 16 FBE parents after an Advanced Wipe list containing `/data;`, with guards for metadata exclusion, mounted `/data`, and surviving encryption key roots.
2. FoxSettingsSyncV8 can bootstrap the fallback `.foxs` only when it is truly absent and metadata + real-normal profiles are valid; corrupt/invalid fallback remains fail-safe.

Both helper logic and profile self-heal were proven manually. GUI sequencing was still wrong: completion attempted POSTLIST while the threaded wipe action was active.

### Build56
Introduced a `klee_wipe_queue_done` latch so completion waits until action2 returns. This fixed the earlier action1→completion transition, but a smaller worker-teardown race remained after native wipe completion.

### Build57
Added `tw_busy=0` guards. Runtime proved `tw_busy` can become 0 before TWRP `ActionThread::m_thread_running` is cleared, so completion still attempted a second threaded `cmd` too early.

### Build58 — final closure design
Source inspection of TWRP `gui/action.cpp` showed `wipe`, `cmd`, and `terminalcommand` are threaded actions, while `ActionThread::run()` executes every child action of the same GUIAction sequentially before clearing `m_thread_running`.

Build58 therefore moved POSTLIST into the same Advanced Wipe LIST worker:

`PRE → native WIPE → POSTLIST → queue_done`

The completion page performs no command. Non-LIST two-action paths, including Format Data / `DATAMEDIA`, do not receive POSTLIST.

### Build58 runtime closure

Direct tests:

- Data-only wipe: PASS;
- automatic FBE parent repair: PASS;
- no `Another threaded action`: PASS;
- reboot after Data wipe without manual repair: FBE PASS;
- four `.foxs` stores converge to identical hash: PASS;
- Cache-only wipe: PASS;
- Dalvik/ART-only wipe: PASS;
- Dalvik + Cache + Data combined list: PASS;
- combo POSTLIST detects `/data;` and repairs parents: PASS;
- reboot after combo wipe: FBE PASS;
- final closure check: Build58 active, FBE `1/true`, no thread conflict, four `.foxs` identical.

**Build58 is the release/closure build for the Advanced Wipe Data + Android 16 FBE issue.**


---

## Build59 — final Format Data `/odm` quiesce closure

After Build58 was declared the Advanced Wipe/FBE closure build, a fresh HyperOS-mod + Fenrir test reopened the destructive Format Data path under a different runtime state.

### New runtime failure discovered

Before Build59, GUI Format Data entered native `Unmap_Super_Devices`, successfully removed several logical partitions, then failed on `/odm`:

- `/odm` was mounted EROFS;
- `/vendor/bin/touch_report` was still running;
- runtime `/proc/<pid>/fd` inspection proved it held `/odm/firmware/smooth.tflite` and `/odm/firmware/water_check.tflite` open;
- native unmap then emitted `Unable to unmap dynamic partitions` and Format Data ended with status 1;
- the visible `Unable to mount storage` message was a downstream symptom, not the root cause.

The user explicitly rejected a manual ADB `stop touch_report` workaround. The GUI path had to be self-contained.

### Build59 delta

Only `system/bin/klee-wipe-prep` changed from Build58.

For `DATAMEDIA` / Format Data only:

1. detect the init-managed `touch_report` service;
2. request `stop touch_report` before native Format Data reaches dynamic unmap;
3. verify process exit with a bounded wait (up to 3 seconds);
4. fail closed if it cannot be quiesced;
5. leave Advanced Wipe LIST/POSTLIST logic unchanged;
6. do not restart the service in the same destructive session; init starts it normally on a later recovery boot.

### Build59 runtime acceptance

Final observed Format Data sequence:

- `KleeWipePrepV4: Format Data quiesce touch_report state=running`;
- `touch_report stopped; /odm release ready`;
- helper status 0;
- `Unmap_Super_Devices` removed system/vendor/product/mi_ext/system_ext/**odm**/system_dlkm/vendor_dlkm/odm_dlkm;
- userdata F2FS format completed successfully;
- metadata F2FS format completed successfully;
- final `operation_end - status=0`.

### HyperOS mod + Fenrir end-to-end validation

The final destructive-reset cycle was tested on a HyperOS mod rather than only the original stock baseline:

- Build58/59 OrangeFox `vendor_boot` was required for this particular mod to boot reliably in the tested environment;
- Fenrir installer accepted the mod environment after FBE was decrypted;
- preloader A/B were converted to the golden Fenrir payload and independently re-hashed;
- LK A/B were converted to the golden Fenrir payload and independently re-hashed;
- after bootchain conversion the existing encryption state was not usable, matching the previously known clean stock→Fenrir behavior;
- Build59 GUI Format Data rebuilt `/data` and `/metadata` in the Fenrir state;
- HyperOS mod then booted normally;
- recovery was entered again, metadata encryption opened, PIN was entered, and FBE finished with `user0=1`, `twrp.decrypt.done=true`, `User 0 Decrypted Successfully`, and `Data successfully decrypted`.

**Build59 is the FINAL RELEASE / closure build.**
---

## Build60 — post-Format-Data touch lifecycle closure / final public recovery

### Why Build60 exists
Build59 solved the real Format Data blocker: `touch_report` held ODM firmware files open, so native
dynamic-partition unmap could fail at `/odm`. Build59 correctly stopped the init-managed service before
the native `DATAMEDIA` wipe and completed `/data` + `/metadata` formatting.

Final clean-install testing exposed a second lifecycle issue. After Format Data completed, Build59 left
`touch_report` stopped. The kernel/input device still existed, but OrangeFox GUI touch was unusable until
recovery rebooted.

### Runtime root cause
Immediately after Build59 Format Data:

- `init.svc.touch_report=stopped`;
- touch_report PID absent;
- `/dev/input/event2` still identified as `NVTCapacitiveTouchScreen`;
- `/odm` and its mapper were already absent;
- manually running `start touch_report` restored GUI touch immediately without remounting ODM.

This proved the post-format problem was userspace service lifecycle, not Novatek hardware, firmware,
ODM mapper creation, or a missing input event node.

### Build60 delta
Build60 retains Build59 PRE quiesce and adds a guarded POST stage:

`PRE -> native DATAMEDIA -> POSTDATAMEDIA -> queue_done`

- PRE stops `touch_report` only when needed and records a per-run marker.
- Native Format Data runs with ODM released.
- POSTDATAMEDIA resumes `touch_report` only when that invocation actually stopped it.
- Resume is bounded and logged.
- No ODM remount is added.
- Advanced Wipe `LIST -> POSTLIST`, FBE/settings, Fenrir, recovery fstab, DTB, bootconfig and
  non-recovery fragments are preserved.

### Runtime validation
- Format Data -> touch auto-resume, no recovery reboot: **PASS**.
- Two Format Data cycles in one session: **PASS**.
- Dalvik/Cache wipe between those cycles: **PASS**.
- Boot System, return to recovery, Format Data again -> touch auto-resume: **PASS**.
- Final `touch_report=running` while ODM remains unmounted: **PASS**.
- Physical OrangeFox touch after Format Data: **PASS**.

### HyperDot clean-install acceptance context
The final HyperDot recovery ZIP test also passed its sparse SUPER path:

- `Super flash complete`;
- installer process ended with no errors;
- `operation_end - status=0`;
- post-recovery reboot slot `_a`;
- physical SUPER size `12884901888`;
- `product_a`, `system_a`, and `vendor_a` mappings valid;
- after Format Data Android reached Setup Wizard.

### Fenrir release rule finalized
For a currently installed **non-Fenrir HOS** state, the project procedure is:

`Fenrir Install / Repair -> Format Data -> Reboot System`

Format Data is **mandatory** for that first non-Fenrir -> Fenrir conversion in this project.
The final validation sequence booted System successfully.

### Final Build60 identity
- image size: `67108864` bytes;
- SHA256: `aa7fdc2ebc9f30ecbeaf18a6d982fd86de782600bdd30adf676a17c22e4d0251`.

**Build60 supersedes Build59 as the final public OrangeFox recovery release.**
