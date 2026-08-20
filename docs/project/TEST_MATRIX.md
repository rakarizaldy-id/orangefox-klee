# Runtime Test Matrix — Current Release

Current runtime release:

`OrangeFox-R12.0-Unofficial-klee-Fenrir-20260820.img`

SHA256:
`5740bd9c17e92d32e4dc24b02792a5c8aa54df94ad5233c1370af995269bcaf2`

Legend:
- **PASS / current** — directly validated in the current release stabilization phase.
- **PASS / inherited** — runtime-validated in the historical golden baseline and retained as a closed subsystem.
- **PASS TO SETUP** — boot reached Android Setup Wizard; completion to Home is not claimed.
- **PARKED / UNSUPPORTED** — intentionally not shipped or not claimed.

| Area | Test | Result |
|---|---|---|
| Identity | `vendor_boot` image is exactly 64 MiB | PASS / current |
| Boot | current OrangeFox release boots on `klee` | PASS / current |
| FBE | Android 16 metadata/user 0 decrypt | PASS / current |
| FBE | IDXM NXP + MIAuthSecret path | PASS / current |
| FBE | Pure CN Xiaomi Weaver/CPace path | PASS / current |
| Settings | encrypted RAM matches metadata authority | PASS / current |
| Settings | decrypted settings aliases converge to one inode/state | PASS / current |
| Settings | brightness persistence | PASS / current |
| Settings | screen-timeout persistence | PASS / current |
| Settings | hidden-files preference persistence | PASS / current |
| Settings | 24-hour time preference persistence | PASS / current |
| Recovery Password | encrypted Home/Back -> OFOX password flow | PASS / current |
| Recovery Password | decrypted -> OFOX password flow | PASS / current |
| Recovery Password | create/remove persistence | PASS / current |
| Theme | style/accent survives reload/reboot | PASS / current |
| Navigation | navbar/gesture preference survives reload/reboot | PASS / current |
| Touch | Novatek touch works on recovery entry | PASS / current |
| Haptic | AW86927 diagnostics/runtime path | PASS / current |
| Fenrir | PRELOADER A/B exact compare | PASS / current |
| Fenrir | LK A/B exact compare | PASS / current |
| Fenrir | active `vendor_boot` cache refresh | PASS / current |
| Fenrir | inactive-slot `vendor_boot` repair | PASS / current |
| Fenrir | final A/B `vendor_boot` equality | PASS / current |
| Fenrir | second run is MATCH/SKIP/status-only | PASS / current |
| Fenrir | first non-Fenrir conversion requires Format Data | PASS / inherited conversion validation + project rule |
| Display | normal recovery operation stable | PASS / current |
| Display | Fenrir direct run preserves brightness / no glitch | PASS / current |
| Display | rare screen dim/off transition glitch | KNOWN NOTE / not attributed to Fenrir |
| Format Data | PRE quiesces `touch_report` | PASS / inherited |
| Format Data | native DATAMEDIA completes | PASS / inherited |
| Format Data | POSTDATAMEDIA resumes touch service when required | PASS / inherited |
| Format Data | physical touch works without recovery reboot | PASS / inherited |
| Format Data | repeated same-session cycles | PASS / inherited |
| Format Data | post-System regression cycle | PASS / inherited |
| Advanced Wipe | Data-only preserve-media wipe | PASS / inherited |
| Advanced Wipe | Android 16 FBE parent repair | PASS / inherited |
| Advanced Wipe | Cache-only / Dalvik-only / combined | PASS / inherited |
| Fastbootd | userspace fastboot | PASS / inherited |
| Fastbootd | Windows `18D1:4EE0` enumeration | PASS / inherited |
| Screenshot | recovery screenshot path | PASS / inherited |
| Klee Tools | Recovery Diagnostics / Self-Test | PASS / current |
| Klee Tools | Storage / Partition Status | PASS / current |
| Klee Tools | Clear Saved OrangeFox Logs | PASS / current |
| Clear Console | true in-memory GUI console clear | PARKED / not shipped |
| HyperDot ZIP | sparse SUPER installer completed successfully | PASS / inherited |
| HyperDot ZIP | post-reboot logical mappings/SUPER state valid | PASS / inherited |
| HyperDot ZIP | clean boot after Format Data | PASS TO SETUP |
| OrangeFox OTA / survival | unofficial release OTA integration | UNSUPPORTED |
