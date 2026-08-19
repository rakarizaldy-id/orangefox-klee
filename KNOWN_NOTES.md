# Known Notes / Boundaries

1. **Build60 post-Format Data touch loss is fixed.** A recovery reboot should not be documented as the
   normal workaround. If it reappears, capture `/tmp/recovery.log` and treat it as regression evidence.

2. **ODM need not be remounted to restore touch after Format Data.** Runtime proof showed
   `touch_report` can restart while `/odm` and its mapper remain absent.

3. **Fenrir requires decrypted user 0.** The established fail-closed guard remains part of the design.

4. **First non-Fenrir HOS -> Fenrir conversion requires Format Data.** This supersedes older project
   notes where the clean conversion requirement was still pending/uncertain.

5. **Format Data erases userdata-resident Fenrir cache.** It does not erase already-written preloader/LK/
   vendor_boot partitions. A later decrypted Fenrir run can seed/synchronize cache from the active recovery.

6. **Other non-CN ROM regions are not individually claimed as tested.** Final selector routes them through
   the validated non-CN NXP path, but direct user validation recorded in the history is IDXM and Pure CN.

7. **Clear Console is not shipped as a true in-memory console clear.** Clear OrangeFox Logs is implemented;
   the RAM-backed GUI console problem was deliberately parked.

8. **Thermal/load work was investigation, not a marketed final thermal feature.**

9. **HyperDot clean boot was validated to Android Setup Wizard.** The specific final ZIP test was not
   completed through full account/setup to Home before the next project test.

10. **Windows BAT Build60 test is separate/pending at package time.** Do not claim it as completed from this ZIP.

11. **Internal OrangeFox build-date metadata can reflect the inherited base build date.** Use the Build60
   image SHA256 as the authoritative public artifact identity.

12. **Do not reconstruct multi-sparse SUPER fragments with ordinary binary concatenation.**
