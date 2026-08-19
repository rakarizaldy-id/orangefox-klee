# Technical History — OrangeFox `klee` project, Chat1 → Chat9

## 1. Platform foundation
- Target: POCO X8 Pro `klee`, MT6899 family.
- Recovery is delivered through a 64 MiB `vendor_boot` image.
- Device is Virtual A/B with dynamic partitions in physical `super`.
- Development rule evolved toward minimal deltas: once a subsystem reached runtime closure, later builds
  preserved it byte-identically unless new runtime evidence justified reopening it.

## 2. Android 16 FBE / Weaver / AuthSecret
The early project first established IDXM decryption, then investigated Pure CN.

### IDXM
Directly validated ROM:
`OS3.0.303.0.WPJIDXM`

The final non-CN path uses NXP Weaver plus Xiaomi MIAuthSecret. On the tested IDXM state the Weaver
backend reported key size 16 and user 0 decryption succeeded.

### Pure CN
Directly validated ROM:
`OS3.0.304.0.WPJCNXM`

A controlled NXP test reached the Weaver applet but returned incorrect-key at credential verification.
The recovery also contained Xiaomi Weaver/CPace. Switching Pure CN to that backend produced key size 32
and successful user 0 decryption.

### Final universal behavior
- `ro.boot.ptcountrycode=cn` -> Xiaomi Weaver/CPace.
- non-CN -> NXP Weaver + Xiaomi MIAuthSecret.
- key size is reported by the backend; it is not globally forced.
- other non-CN regions follow the NXP path by design but were not individually claimed as device-tested.

## 3. Fastbootd and Windows USB
The fastbootd issue was not one single bug. Work covered USB configfs duplication, VINTF/service
declarations, AIDL Fastboot service compatibility, service domain/SELinux behavior and host driver binding.

Windows finally enumerated fastbootd as VID `18D1`, PID `4EE0`; binding Google Android Bootloader
Interface produced:
- `fastboot devices` -> detected;
- `is-userspace` -> yes;
- `product` -> klee.

A Rodin-inspired pre-detach experiment was explicitly rejected and is not part of the final baseline.

## 4. Display / screenshot / ODM / thermal investigations
The project investigated recovery panel glitch behavior, DRM/DPMS state, screenshot correctness,
ODM busy-unmount warnings, and recovery idle load/thermal behavior.

Display/screenshot mitigations became inherited core invariants. ODM busy warnings were not treated as
proof of a broken `super` when mapping/decryption remained healthy. Thermal/load work was diagnostic and
should not be advertised as a final user-facing thermal feature unless independently validated.

## 5. Persistent OrangeFox settings
The settings problem was unusually difficult because OrangeFox can read profile state before and after
FBE decrypt from different storage contexts.

The final architecture grew through Builds7–38 and uses metadata/persist/media/fallback reconciliation:
- safe post-decrypt bootstrap;
- a physical persist anchor enabling pre-PIN metadata bind on later boots;
- selective preference reconciliation rather than blind copying;
- direct-PIN and encrypted-main handling;
- media-shadow handling;
- first-install bootstrap in FoxSettingsSyncV8;
- fresh-media and fallback self-heal with absent-only/fail-safe guards.

This architecture was deliberately preserved through Fenrir and later wipe builds.

## 6. Theme/status preload
ThemeSync and status-variable preload went through several race/permission iterations.
The stable design uses safe metadata staging, correct file modes, first-post-decrypt latch behavior and
deterministic cleanup while preserving explicit reset semantics.

## 7. Novatek touch
`KleeTouchFixV3` established defensive ODM handling, firmware visibility checks, retries and
`touch_report` stabilization.

Build59 later discovered a different touch-related problem: the same init-managed `touch_report` process
held ODM firmware files open during Format Data. That was a wipe lifecycle issue, not a regression of
the original startup touch fix.

Build60 finally gives the service a complete lifecycle:
- startup stabilization;
- Format Data PRE quiesce for ODM release;
- POSTDATAMEDIA resume when PRE actually stopped it.

## 8. AW86927 haptic
Build34 began stock-like integration. Build35 made firmware loading SELinux-safe by reading the exact
stock firmware from a labeled vendor source. Build36 used a NO-PLAY FF primer to reach strong level
without a boot vibration. Build37 moved the final UI path to the `FF_CONSTANT`-compatible backend state
(`effect_id=11`, `activate_mode=3`) so requested slider duration maps to actual motor duration while
retaining the stronger level. Build38 froze this as a core invariant.

## 9. Klee Tools
The diagnostic UI itself required several failed threading experiments:
- Build39 `twrp xset`: deadlock;
- Build40 `cmd -> ftls`: unsuitable threaded behavior;
- Build41 list-style results: technically worked but rejected UX;
- Build42 live console Self-Test: accepted;
- Build43 Storage / Partition Health: accepted;
- Build44 Clear OrangeFox Logs: accepted.

True in-memory GUI console clearing was parked because deleting log files does not clear process-RAM
console history.

## 10. Fenrir Install / Repair
Fenrir became the bootchain/recovery synchronizer:
- validated embedded preloader and LK assets;
- exact meaningful size/hash verification;
- idempotent A/B repair;
- persistent vendor_boot cache;
- final verification before `FENRIR READY`.

Build46 added FBE fail-closed behavior: when user 0 is not decrypted, destructive Fenrir work is refused
with zero writes.

Build47 fixed upgrade safety. A valid but older cache is `STALE`, not golden. It is refreshed atomically
from the currently running active vendor_boot before inactive-slot repair. Corrupt cache remains REFUSE.

Final project operational rule:
For a currently installed **non-Fenrir HOS**, first Fenrir conversion requires **Format Data** before
booting System.

## 11. Format Data / Advanced Wipe
### Settings aliases and `mi_ext`
Builds48–54 made persist propagation private, introduced targeted alias cleanup, moved wipe preparation
into native TWRP queues, removed a duplicate `mi_ext` ext4 fallback for the real EROFS logical partition,
and added narrow fresh-media profile bootstrap.

### Advanced Wipe Data / Android 16 FBE
Advanced Wipe Data preserves media, but native wiping removed parent directory skeletons required by
Android 16 user-storage preparation. The keys survived; required parents did not.

Build55 added guarded post-Data recreation and fallback-profile self-heal, but Builds55–57 exposed TWRP
threading races. Source-level inspection showed the correct pattern: all threaded child actions that must
sequence together belong in one GUIAction worker.

Build58 final sequence:
`PRE -> native WIPE -> POSTLIST -> queue_done`

Runtime closure passed Data-only, Cache-only, Dalvik-only, combined Dalvik+Cache+Data, reboot FBE and
profile convergence.

### Format Data ODM blocker
Build58 Format Data later failed because `touch_report` held:
- `/odm/firmware/smooth.tflite`
- `/odm/firmware/water_check.tflite`

Build59 automatically stopped the service before native DATAMEDIA unmap and achieved successful dynamic
unmap plus `/data` and `/metadata` F2FS format.

### Post-format touch closure
Build59 left the service stopped after success. Build60 adds guarded POSTDATAMEDIA resume. Repeated and
post-System regression tests passed with ODM still unmounted.

## 12. HyperDot sparse SUPER validation
The source HyperDot SUPER payload was Android sparse, expanded logical size 12 GiB.

Two wrong/limited paths were proven:
- one 6.55 GB `package_unsparse_file()` entry exceeded the updater binary sparse-entry limit;
- `package_extract_file()` copied sparse container bytes directly to physical SUPER and broke logical
  mappings.

The working design resparsed the payload to eight Android sparse fragments under a conservative
per-entry size and used `package_unsparse_file()` for each fragment. Static inspection of the custom
updater binary established success truthiness suitable for fail-closed `assert(...)`.

The final OrangeFox ZIP test reached `Super flash complete`, no process errors, `operation_end status=0`,
then recovered valid `_a` logical mappings and booted Android to Setup Wizard after Format Data.

The Windows BAT flasher remained a separate follow-up test when this OrangeFox Build60 master release
was packaged.

## 13. Release engineering principles
- one change at a time;
- keep solved subsystems closed unless runtime regression appears;
- distinguish static proof, runtime proof and inference;
- preserve known-good DTB/bootconfig/non-recovery fragments;
- fail closed for destructive operations;
- do not treat a GUI “Success” string as enough without log/state verification.
