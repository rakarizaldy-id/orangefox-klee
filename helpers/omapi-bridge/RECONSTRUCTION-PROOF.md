# Klee recovery OMAPI bridge — reconstruction proof

## Golden Build60 references

Packed Build60 executable:

- path: `/system/bin/klee_omapi_bridge`
- size: `21812` bytes
- SHA256: `432706c9481b8cffed0ac3c4b10e89141f75ecf807c15159b6d11c18d2cafe71`
- architecture: AArch64
- container: UPX 4.24 packed ELF

The packed executable was decoded locally by following the UPX Unix `b_info`
block format. Its six blocks use method `14` (LZMA); the executable block uses
filter `0x52`, the UPX ARM64 26-bit branch filter.

Reconstructed unpacked ELF:

- size: `135160` bytes
- SHA256: `8396dbb19df517eba94ab0efc2ab2926aacd3f3218d3afb819098543e3d432f8`
- interpreter: `/system/bin/linker64`
- Android ABI level recorded by ELF: 34
- Build ID: `5f3fca0325380f95b5d4db1cf067a9e5`

No packed or unpacked historical executable is shipped by this source tree.

## Golden dynamic contract

The unpacked Build60 ELF directly requires:

- `android.hardware.secure_element-V1-ndk.so`
- `android.se.omapi-V1-ndk.so`
- `libklee_libcxx_compat.so`
- `libbase.so`
- `libbinder_ndk.so`
- `liblog.so`
- `libc++.so`
- standard Android C runtime libraries

Its observable Binder/property contract includes:

- hardware backend: `android.hardware.secure_element.ISecureElement/eSE1`
- OMAPI service: `android.se.omapi.ISecureElementService/default`
- sole recovery reader: `eSE1`
- ready property: `vendor.omapi_bridge.ready=1`
- 4-thread Binder pool
- 10-second Secure Element connection wait

## Behavioral contract recovered

The bridge exposes the Android OMAPI AIDL façade over the hardware Secure
Element AIDL service.

### APDU forwarding

- responses shorter than a two-byte status word are rejected as I/O errors;
- `SW1=0x6c` retries the command once with the returned expected length when
  the original command has at least five bytes;
- `SW1=0x61` is followed by GET RESPONSE APDUs;
- GET RESPONSE chaining is bounded to 32 rounds;
- intermediate payload bytes are accumulated and the final status word is
  retained.

### Channel behavior

- basic channel number is `0`;
- logical channel range is `0..19`;
- CLA routing preserves the OMAPI/ISO-7816 channel encoding, including the
  secure-messaging bit translation for channels 4..19;
- closing basic channel first sends a deselect-style SELECT APDU and ignores
  a later close-channel failure for channel zero;
- `selectNext` accepts success/warning status families `90xx`, `62xx`, `63xx`;
- `6axx` is returned as “not selected”; other status words are unsupported.

### Session/open validation

- AID is either empty or 5..16 bytes;
- P2 is one of `00`, `04`, `08`, `0c`;
- listener must not be null;
- a session cannot open channels after it is closed;
- opening a session checks Secure Element presence.

### Recovery service policy

- only reader `eSE1` is exposed;
- NFC event permission requests are always denied for each supplied package;
- reader reset forwards to the hardware Secure Element reset call.

## Public-source provenance note

During the audit, a public historical Klee file with the same service contract
was discovered in `xiaomi-klee-devs/twrp_device_xiaomi_klee` at commit
`a68dee1dc414bdae42d09baa7235a02a2457375f`.

That file has no per-file license header, and no repository `LICENSE` was found
at that commit. Therefore this reconstruction does **not** import that file into
the tree. It was used only as corroborating evidence after the Build60 binary
contract had already been recovered.

The implementation in this directory is a separately structured behavioral
reimplementation and is not claimed to be a clean-room legal process or a
byte-identical reproduction of the historical source.

## `libklee_libcxx_compat`

Build60 also contains:

- `/system/lib64/libklee_libcxx_compat.so`
- SHA256: `981251ed419bc84bd35494ab8b647efb38fb883339b35d48b00140baa4f3661c`

`init.recovery.keymint.rc` preloads this DSO for the Secure Element service and
the OMAPI bridge. The source implementation here provides the missing
`std::__1::__libcpp_verbose_abort(char const*, ...)` ABI symbol by logging and
aborting. This keeps the vendor NDK libraries compatible with the recovery
libc++ runtime.

## Verification performed in Step 12

Host-only protocol test compiled with:

```text
clang++ -std=c++17 -O2 -Wall -Wextra -Werror
```

and passed tests for:

- AID length validation;
- P2 validation;
- channel 0, 3, 4, 19 and invalid 20 CLA routing;
- secure-messaging CLA translation;
- SELECT NEXT status classification;
- `6C` retry decision;
- `61` continuation decision.

A static cross-check against the unpacked Build60 ELF also passed for the two
Binder service names, reader name, ready property, vendor AIDL dependencies,
service-manager calls, 10-second wait, and 32-round GET RESPONSE bound.

## Remaining external dependency

The bridge source is complete, but the tree still needs the two validated
vendor V1 NDK shared libraries through the proprietary extraction layer:

- `android.hardware.secure_element-V1-ndk.so`
- `android.se.omapi-V1-ndk.so`

Those are vendor inputs, not project-specific helper binaries, and are handled
in the next proprietary-file reconstruction step.
