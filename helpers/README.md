# Step 9 — Compiled Helper Audit

This step audits the four Build60 project-specific compiled helpers before any of them are committed
as public prebuilts.

The goal is to distinguish:
- helpers we can reasonably reconstruct as source;
- helpers that still require deeper reverse engineering / provenance recovery;
- vendor binaries, which belong to a separate proprietary extraction flow.

## Audit result

| Helper | Build60 size | SHA256 | Embedded source identity | Classification |
|---|---:|---|---|---|
| `foxs-merge` | 7128 | `80f91f3e39e18f59e593582a5e634b8ca890a16fc689bb87eb09180722491050` | `foxs_merge_v2.c` | **REWRITE_FROM_BEHAVIOR** |
| `klee_omapi_bridge` | 21812 | `432706c9481b8cffed0ac3c4b10e89141f75ecf807c15159b6d11c18d2cafe71` | `-` | **HOLD_PACKED_PREBUILT** |
| `aw86927_ff_constant_prime_noplay` | 3968 | `89bc266eecf0ea3ec3b45aa4078784c3fc7d0f0694154d71641ea01235d391a0` | `aw86927_ff_constant_prime_noplay.c` | **REWRITE_FROM_BEHAVIOR** |
| `aw86927_ff_prime_auto` | 3360 | `66cd2b34b649b089aa026c747d0b7eb25d49fb6b94096220f12483074110d08a` | `aw86927_ff_prime_auto.c` | **REWRITE_FROM_BEHAVIOR** |

## 1. `foxs-merge`

Build60 facts:

- ELF64 AArch64
- statically linked
- **not stripped**
- embedded source file name: `foxs_merge_v2.c`
- exported/internal symbols include:
  - `start_c`
  - `parse_file`
  - `parse_at`
  - `write_all_trunc`
- command interface visible in the binary:
  - `foxs-merge SRC DST ALLOWLIST`
  - `foxs-merge --probe FILE`
- known status strings include:
  - `versioned`
  - `headerless`
  - `legacy-corrupt`
  - `unknown-versioned`
  - `changed`
  - `unchanged`
  - `repaired`

The Build60 shell scripts tell us the required behavioral contract:

- `--probe FILE` reports the `.foxs` format class.
- merge mode selectively copies only allowlisted keys from SRC to DST.
- destination is rewritten by truncating the existing inode, preserving ownership/context.
- exit `0` = changed/success.
- exit `10` = unchanged.
- other non-zero codes are treated as merge/probe errors.

**Decision:** rewrite as source, then test against the known Build60 contract. Do not ship the old ELF as
the final public implementation.

## 2. `aw86927_ff_constant_prime_noplay`

Build60 facts:

- ELF64 AArch64
- statically linked
- **not stripped**
- embedded source file name: `aw86927_ff_constant_prime_noplay.c`
- very small program
- uses Linux input force-feedback ioctls directly
- scans `/dev/input/event0` ... `/dev/input/event7`
- identifies the Awinic/AW86927 haptic input node
- queries `EVIOCGEFFECTS`
- uploads:
  - periodic/custom effect 7
  - `FF_GAIN=0x7fff`
  - `FF_CONSTANT`
- intentionally does **not** PLAY the effect
- Build60 validated target state:
  - `effect_id=11`
  - `activate_mode=3`
  - strength/level equivalent to project target `0x80`

**Decision:** rewrite as source. The disassembly is small enough to reconstruct the syscall/ioctl behavior
without preserving the old ELF.

## 3. `aw86927_ff_prime_auto`

Build60 facts:

- ELF64 AArch64
- statically linked
- **not stripped**
- embedded source file name: `aw86927_ff_prime_auto.c`
- scans/autodetects the AW86927 input alias
- queries FF effect capacity
- uploads the legacy periodic/effect-7 primer
- emits diagnostic output

This helper was part of the earlier haptic bring-up path. Build37's final shell path directly uses
`aw86927_ff_constant_prime_noplay`, so before carrying `aw86927_ff_prime_auto` forever we should verify
whether anything in the final Build60 runtime still executes it.

**Decision:** source-rewrite candidate, but first confirm whether it is still runtime-required. If unused,
remove it from the final public tree instead of preserving dead compatibility code.

## 4. `klee_omapi_bridge`

Build60 facts:

- ELF64 AArch64 PIE
- statically linked
- stripped / no section header table
- **UPX packed**
- contains UPX 4.24 packer signature
- started by `init.recovery.keymint.rc` as:
  `service klee.omapi_bridge /system/bin/klee_omapi_bridge`
- runs as `system`
- groups: `system secure_element nfc`
- participates in the recovery Secure Element / OMAPI path used by Android 16 FBE bring-up.

The packed state means a superficial strings/symbol audit does not expose the actual bridge logic.

**Decision:** HOLD. Do not invent replacement source and do not call the tree fully source-reproducible yet.

Preferred next choices, in order:
1. recover the original project source from historical build material if it still exists;
2. unpack/decompile the helper and document its exact service contract;
3. rewrite a minimal source implementation from the recovered contract;
4. only as a temporary local build fallback, use a validated prebuilt with its exact Build60 hash.

The temporary-prebuilt fallback should not be the long-term public design.

---

# Important distinction

These four files are **project-specific compiled helpers**.

They are different from Xiaomi/vendor proprietary components such as:
- `touch_report`
- Weaver HAL binaries
- AuthSecret HAL
- touch kernel modules
- vendor libraries / firmware

Vendor components will be handled later through a stock extraction / proprietary-files flow.

---

# Step 9 public-tree policy

No compiled helper binary is added to the public tree in Step 9.

Instead the tree records:

```text
helpers/
└── README.md
```

and keeps Build60 hashes as golden references.

This means the reconstructed tree remains honest:
- source-friendly scripts: included;
- source patch layer: included;
- compiled project helpers: not yet falsely claimed as source;
- vendor blobs: not yet committed.

## Next step

**Step 10 should reconstruct the easiest compiled helper sources first:**

1. `aw86927_ff_constant_prime_noplay`
2. determine whether `aw86927_ff_prime_auto` is still referenced
3. `foxs-merge`

`klee_omapi_bridge` should remain isolated until its contract is recovered.
