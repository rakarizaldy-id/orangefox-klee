# Step16 core-patch blocker discovered during Step15

Build60's `init.recovery.service.rc` preloads:

```text
/system/lib64/libodm_ebusy_suppress.so
```

Golden library:
- size: 4568
- SHA256: `c392dbda3f24516948c343153d2c05ce0df6756178760bf42d207bc1b3cb4bb7`
- ELF64 AArch64 shared object, not stripped
- embedded source identity: `libodm_ebusy_suppress.c`

The library performs an in-process, fixed-offset patch of the Build60 recovery ELF. That makes it a **recovery-core compatibility shim**, not a normal proprietary blob. It is deliberately not copied into Step15. Step16 must either reconstruct the shim/source safely for the selected OrangeFox recovery binary or replace the fixed-offset mechanism with an equivalent source-level recovery patch.

Golden service RC SHA256: `8f0512afd3ad7b88b5d3e35053e919238c27bbd3aa228a57e067fe80e6e5e29a`
