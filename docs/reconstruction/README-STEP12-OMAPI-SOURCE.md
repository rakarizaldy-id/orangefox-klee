# Step 12 — Source reconstruction of the recovery OMAPI bridge

Step 12 removes the last required project-specific historical ELF from the
source story.

Added:

```text
helpers/omapi-bridge/
├── Android.bp
├── libcxx_compat.cpp
├── omapi_bridge.cpp
├── omapi_protocol.h
├── omapi_protocol_test.cpp
└── RECONSTRUCTION-PROOF.md
```

`device.mk` now requests:

```text
klee_omapi_bridge
libklee_libcxx_compat
```

## Status

- Build60 UPX bridge unpack/audit: PASS
- service/property/dependency cross-check: PASS
- protocol logic host compile: PASS
- protocol tests: PASS
- project bridge source: reconstructed
- libc++ ABI compatibility shim: reconstructed
- old packed bridge ELF included in tree: **NO**

## Project-specific compiled helpers after Step 12

| Component | Final state |
|---|---|
| `aw86927_ff_constant_prime_noplay` | source-built |
| `foxs-merge` | source-built |
| `klee_omapi_bridge` | source-built |
| `libklee_libcxx_compat` | source-built |
| `aw86927_ff_prime_auto` | removed; not referenced by final Build60 runtime |

The remaining non-source components are now primarily Xiaomi/vendor device
inputs rather than custom project helper executables.

## Next step

Step 13 should build the proprietary extraction map for the vendor components
actually required by the golden recovery, beginning with the two OMAPI/Secure
Element NDK libraries and then the FBE/touch HAL/module sets.
