# Step16 core-patch proof

## Native branch identity

OrangeFox `variables.h` defines `FOX_BRANCH` as a compile-time macro. The same
macro initializes DataManager `fox_branch` and is used in release metadata.
Build60 runtime shows both the startup `(branch: klee)` identity and
`[Branch] : klee`.

The clean tree therefore patches the source definition to:

```c
#define FOX_BRANCH "klee"
```

No finished recovery ELF patch is retained.

## ODM EBUSY cleanup

Build60's `libodm_ebusy_suppress.so` had SHA256:

```text
c392dbda3f24516948c343153d2c05ce0df6756178760bf42d207bc1b3cb4bb7
```

It was loaded with `LD_PRELOAD` and rewrote fixed AArch64 instruction offsets
inside `/system/bin/recovery`. Disassembly showed its functional exception was
specific to `errno == EBUSY` and mount point `/odm`.

Step16 replaces that binary coupling with source logic:

1. normal `umount2()`;
2. save errno immediately;
3. only for `/odm` + `EBUSY`, attempt `MNT_DETACH`;
4. wait 200 ms;
5. return success only if the mount table confirms `/odm` is gone;
6. otherwise restore the original errno and follow the normal error path.

This is intentionally stricter than blindly suppressing EBUSY.

Build59/60's primary ordering solution remains unchanged: `klee-wipe-prep`
stops `touch_report` before ODM teardown, and Build60 resumes it in
`POSTDATAMEDIA`.

## Historical broad patch rejected

The old device tree's large recovery patch contained unrelated OTG, key-chord,
font/language, and other edits. It is not carried forward. Its ODM lazy-unmount
hunk is historical evidence only; the clean source implementation above is the
final representation.
