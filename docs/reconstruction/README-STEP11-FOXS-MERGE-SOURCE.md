# Step 11 — foxs-merge source reconstruction

The final Build60 `foxs-merge` helper is now represented as source.

```text
helpers/foxs-merge/
├── Android.bp
├── foxs_merge_v2.c
├── test_foxs_merge.py
└── RECONSTRUCTION-PROOF.md
```

`device.mk` builds `foxs-merge` as a recovery package.

## Status

- source reconstruction: PASS
- strict host compile: PASS
- synthetic `.foxs` format/merge corpus: PASS
- inode-preserving truncate behavior: PASS
- Build60 golden hash recorded: PASS

`foxs-merge` is the selective bridge used by the final settings/profile
architecture, so non-allowlisted environment/security keys remain local to the
destination profile.

## Remaining project-specific compiled helper

`klee_omapi_bridge` is now the only required project-specific compiled helper
that has not yet been reconstructed to source.

`aw86927_ff_prime_auto` remains intentionally excluded because the final
Build60 runtime does not reference it.
