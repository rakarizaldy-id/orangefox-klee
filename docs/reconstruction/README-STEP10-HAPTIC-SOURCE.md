# Step 10 — First compiled helper reconstructed as source

`aw86927_ff_constant_prime_noplay` is no longer treated as a Build60-only prebuilt.

The tree now contains:

```text
helpers/aw86927/
├── Android.bp
├── aw86927_ff_constant_prime_noplay.c
└── RECONSTRUCTION-PROOF.md
```

`device.mk` adds the module to `PRODUCT_PACKAGES`.

The Soong module is a recovery-only static executable so the build produces the helper for the recovery
ramdisk rather than copying the old Build60 ELF.

## Runtime contract preserved

The source performs exactly the two-stage **NO-PLAY** primer required by the final Build37/Build60 haptic
path:

1. locate `awinic_haptic`;
2. upload/remove FF_PERIODIC custom effect 7;
3. send FF_GAIN=0x7fff + SYN_REPORT;
4. wait 30 ms;
5. upload/remove FF_CONSTANT with level 0x7fff and replay length 40 ms;
6. exit without issuing an FF PLAY event.

The shell-side `klee_haptic_stock_init.sh` remains unchanged and continues to call the same executable path.

## `aw86927_ff_prime_auto`

Still omitted from the source tree because Step 9 found no final Build60 runtime reference to it. We will
not preserve dead bring-up code unless a later dependency proves it is required.

## Remaining compiled project helpers

- `foxs-merge` — next source-rewrite target.
- `klee_omapi_bridge` — still HOLD; UPX-packed and requires contract recovery before rewrite.
