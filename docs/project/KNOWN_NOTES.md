# Known Notes / Boundaries

1. **Current release identity is the image hash, not an internal development number.**

   `OrangeFox-R12.0-Unofficial-klee-Fenrir-20260820.img`

   SHA256:
   `5740bd9c17e92d32e4dc24b02792a5c8aa54df94ad5233c1370af995269bcaf2`

2. **First true non-Fenrir -> Fenrir conversion requires Format Data before booting System.**

   Required sequence:
   `Fenrir Install / Repair -> Format Data -> Reboot System`.

3. **An already-Fenrir device does not automatically require another Format Data.**

   A status-only Fenrir verification or an inactive-slot `vendor_boot` repair is not a first conversion.

4. **Fenrir destructive work requires decrypted user 0.**

   The established FBE-locked guard is fail-closed.

5. **Settings use one runtime authority.**

   The authoritative settings file is `/metadata/Fox/.foxs`. Lifecycle aliases may appear at persist/media/recovery paths, but they are expected to converge to the same state rather than act as independent settings stores.

6. **Recovery Password and Android/FBE PIN are separate security layers.**

   When Recovery Password is enabled, the expected flow can contain both the Android/FBE credential gate and the OrangeFox Recovery Password gate.

7. **Theme/accent/navigation persistence is validated separately from a full custom `ui.zip`.**

   Falling back to stock `/twres/ui.xml` when a custom theme package is absent does not mean style/accent persistence is broken.

8. **Post-Format Data touch recovery is part of the validated architecture.**

   A recovery reboot should not be documented as the normal workaround. If touch loss returns, capture runtime evidence and treat it as a regression.

9. **A rare display glitch has been associated with native screen dim/off transitions, not Fenrir partition I/O.**

   Direct Fenrir verification kept brightness stable and did not reproduce the glitch. Do not patch Fenrir for this symptom without new evidence.

10. **Clear Saved OrangeFox Logs does not truncate the active `/tmp/recovery.log`.**

    True in-memory GUI console clearing is not shipped and remains parked.

11. **Direct firmware validation is recorded for IDXM and Pure CN.**

    - `OS3.0.303.0.WPJIDXM`
    - `OS3.0.304.0.WPJCNXM`

    Other regions should not be advertised as individually runtime-tested without new evidence.

12. **OrangeFox OTA / survival is intentionally unsupported for this unofficial release.**

13. **Thermal/load work was diagnostic investigation, not a marketed recovery feature.**

14. **Very large ROM ZIP transfer through recovery MTP showed corruption during testing.**

    ADB push was the validated transfer path for multi-gigabyte ROM test packages.

15. **The public source reconstruction and the current runtime release have different verification boundaries.**

    The repository reconstruction is still anchored to the historical Build60 source/recovery behavior baseline. The current 2026-08-20 runtime image includes later stabilization work that has not yet been independently reproduced from a completely fresh source checkout.
