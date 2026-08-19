# foxs-merge reconstruction proof

## Build60 golden reference

- ELF: AArch64, statically linked, not stripped
- Size: **7128 bytes**
- SHA256: `80f91f3e39e18f59e593582a5e634b8ca890a16fc689bb87eb09180722491050`
- Embedded source identity: `foxs_merge_v2.c`

Recovered symbols include `start_c`, `parse_file`, `parse_at`, and
`write_all_trunc`.

## Recovered .foxs contract

Each record is:

```text
uint16_le key_length_including_NUL
key bytes + NUL
uint16_le value_length_including_NUL
value bytes + NUL
```

Recovered limits:

- max entries: 256
- key/value encoded field length: 1..512 bytes including NUL
- `.foxs` input: max 65,535 bytes
- allowlist: max 65,534 bytes
- allowlist entries: max 192
- retained allowlist line payload: max 511 bytes
- serialized output buffer: max 65,536 bytes

Validated normal header:

```text
10 00 01 00
```

Probe classes / exit codes:

| Result | Exit |
|---|---:|
| `versioned` | 0 |
| `legacy-corrupt` | 11 |
| `headerless` | 12 |
| `unknown-versioned` | 13 |
| `invalid` | 20 |

Merge exit codes:

| Result | Exit |
|---|---:|
| changed/repaired | 0 |
| unchanged | 10 |
| usage | 64 |
| read-error | 65 |
| parse-error | 66 |
| allowlist-error | 67 |
| serialize-error | 68 |
| write-error | 69 |

## Reconstructed behavior

- imports only allowlisted keys from SRC;
- preserves all non-allowlisted DST keys;
- updates an existing destination key by value only;
- appends a missing allowlisted key when capacity permits;
- sorts destination entries by key after a changed merge;
- repairs a headerless destination from a prefixed source;
- repairs the known legacy-corrupt representation;
- writes using `O_TRUNC` on the existing destination inode;
- `fsync()` is issued before close.

The inode-preserving behavior is explicitly relied on by the final Build60
settings/profile scripts.

## Verification

Strict host compile:

```text
clang -std=c11 -O2 -Wall -Wextra -Werror
PASS
```

Corpus result:

```text
FOXS-MERGE TEST CORPUS: PASS
```

The corpus covers all four valid probe classes, selective allowlist merge,
preservation of non-allowlisted `tw_storage_path`, deterministic sorting,
unchanged exit 10, inode preservation, headerless repair, and legacy-corrupt
repair.

Reconstructed source SHA256:

`07b12400df85e2cf8c8ccd319934db0a74bf2208e193eb3c2c57409693fc0d6c`

This is an independent behavioral source reconstruction. The target is runtime
compatibility with Build60, not byte-for-byte reproduction of the historical
7,128-byte ELF.
