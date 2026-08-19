# Runtime Test Matrix — Build60 FINAL

Legend:
- **PASS / Build60** — directly tested on Build60.
- **PASS / inherited** — previously runtime-tested and preserved through the final baseline.
- **PASS TO SETUP** — boot reached Android Setup Wizard; Home/setup completion not claimed.
- **PARKED / PENDING** — not a final release claim.

| Area | Test | Result |
|---|---|---|
| Identity | vendor_boot image is exactly 64 MiB | PASS / Build60 |
| Boot | OrangeFox Build60 boots on active slot | PASS / Build60 |
| Touch | touch works on recovery entry | PASS / Build60 |
| Format Data | PRE quiesces touch_report | PASS / Build60 |
| Format Data | native DATAMEDIA completes | PASS / Build60 |
| Format Data | POSTDATAMEDIA executes | PASS / Build60 |
| Format Data | touch_report final state running | PASS / Build60 |
| Format Data | physical touch works without recovery reboot | PASS / Build60 |
| Format Data | ODM remains unmounted while touch recovers | PASS / Build60 |
| Format Data | two cycles in same recovery session | PASS / Build60 |
| Wipe | Dalvik/Cache between repeated Format Data cycles | PASS / Build60 |
| Format Data | post-System regression | PASS / Build60 |
| FBE | metadata encryption decrypt | PASS / inherited |
| FBE | user 0 decrypt | PASS / inherited |
| FBE | IDXM NXP/MIAuthSecret path | PASS / inherited |
| FBE | Pure CN Xiaomi Weaver/CPace path | PASS / inherited |
| Settings | pre-decrypt metadata/persist bootstrap | PASS / inherited |
| Settings | direct-PIN/encrypted-main reconciliation | PASS / inherited |
| Settings | fallback/profile self-heal after Data wipe | PASS / inherited |
| Advanced Wipe | Data-only preserve-media wipe | PASS / inherited Build58 |
| Advanced Wipe | Android 16 FBE parent repair | PASS / inherited Build58 |
| Advanced Wipe | Cache-only | PASS / inherited Build58 |
| Advanced Wipe | Dalvik-only | PASS / inherited Build58 |
| Advanced Wipe | Dalvik+Cache+Data combined | PASS / inherited Build58 |
| GUI engine | no threaded-action conflict in final Build58 wipe design | PASS / inherited |
| Fenrir | FBE-locked refusal / zero writes | PASS / inherited Build46/47 |
| Fenrir | preloader/LK exact validation | PASS / inherited |
| Fenrir | stale vendor_boot cache refresh from active | PASS / inherited Build47 |
| Fenrir | active-slot downgrade protection | PASS / inherited Build47 |
| Fenrir | inactive-slot repair | PASS / inherited Build47 |
| Fenrir | idempotent second run / zero-write | PASS / inherited Build47 |
| Fenrir | Build60 session run | PASS / user-observed; detailed run log not captured |
| Fenrir | non-Fenrir -> Fenrir -> required Format Data -> System boot | PASS / Build60 session |
| Haptic | AW86927 strong constant-duration path | PASS / inherited Build37/38 |
| Display | display/panel mitigation | PASS / inherited |
| Screenshot | screenshot fix | PASS / inherited |
| Fastbootd | userspace fastboot + Windows recognition | PASS / inherited |
| Klee Tools | Recovery Self-Test | PASS / inherited |
| Klee Tools | Storage / Partition Health | PASS / inherited |
| Klee Tools | Clear OrangeFox Logs | PASS / inherited |
| Clear Console | true in-memory GUI console clear | PARKED |
| HyperDot ZIP | sparse SUPER installer `operation_end status=0` | PASS |
| HyperDot ZIP | post-reboot slot/mappers/SUPER size valid | PASS |
| HyperDot ZIP | clean boot after Format Data | PASS TO SETUP |
| HyperDot BAT | Windows BAT updated/tested with Build60 | PENDING / separate workflow |
