# AW86927 Constant Prime Reconstruction Proof

Golden Build60 helper:

- path: `/system/bin/aw86927_ff_constant_prime_noplay`
- SHA256: `89bc266eecf0ea3ec3b45aa4078784c3fc7d0f0694154d71641ea01235d391a0`
- size: `3968` bytes
- ELF64 AArch64, static, not stripped
- embedded source identity: `aw86927_ff_constant_prime_noplay.c`

## Golden binary -> reconstructed source mapping

| Golden operation | Reconstructed source |
|---|---|
| scan event0..event7 | `kInputPaths[]` in the same order |
| `EVIOCGNAME(128)` | `ioctl(fd, EVIOCGNAME(sizeof(name)), name)` |
| require `awinic_haptic` | exact `strcmp()` target |
| `EVIOCGEFFECTS` | same ioctl and positive-capacity guard |
| `FF_PERIODIC` | same type `0x51` |
| replay length 70 ms | same |
| waveform `FF_CUSTOM` | same type `0x5d` |
| magnitude `0x7fff` | same |
| custom length 3 | same |
| custom samples | `{7, 0, 0}` |
| remove periodic slot | `EVIOCRMFF` |
| set force-feedback gain | `EV_FF / FF_GAIN / 0x7fff` |
| sync input event | `EV_SYN / SYN_REPORT / 0` |
| settle delay | 30,000,000 ns (30 ms) |
| `FF_CONSTANT` | same type `0x52` |
| constant replay length | 40 ms |
| constant level | `0x7fff` |
| remove constant slot | `EVIOCRMFF` |
| PLAY event | **none** |
| success line | `PRIMED effect11/mode3/strength0x80 NO-PLAY` |
| failure exits | 1 through 7 preserve Build60 stage boundaries |

## ABI guards

The source has compile-time checks for the exact arm64/Linux input ABI relied on by Build60:

- `sizeof(struct ff_effect) == 48`
- `sizeof(struct input_event) == 24`
- `EVIOCGEFFECTS == 0x80044584`
- `EVIOCSFF == 0x40304580`
- `EVIOCRMFF == 0x40044581`

## Validation completed in Step 10

- source compiles with `-Wall -Wextra -Werror`: **PASS**
- host ABI static assertions: **PASS**
- no-device failure path returns exit code `1`: **PASS**
- expected first-line diagnostic: **PASS**
- no-device diagnostic `awinic_haptic not found`: **PASS**

This is a behavioral/source reconstruction, not an attempt to reproduce the original ELF byte-for-byte.
The definitive device acceptance test will happen after the first source-built recovery is produced.
