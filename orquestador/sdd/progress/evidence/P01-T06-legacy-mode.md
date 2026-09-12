# P01-T06 - Explicit legacy mode and binding conflicts

Status: implemented and validated under `P01-COMPLETE-020`.

## Modes

- `source_template`: requires ProjectRoot equal to InstallRoot and a matching source binding.
- `legacy_bound`: requires InstallRoot exactly at `ProjectRoot/.hebrinex` and a verified `bound` YAML binding.
- `central_instance`: requires `ProjectRoot/.hebrinex/binding.json` and never falls back to legacy mutable paths.

Legacy/source fallback is limited to rules projected as `instance`. It reproduces the previous resolver oracle: use canonical `instance/...` when present, otherwise use the old flat path. Central mode always returns or requires the canonical project instance path.

The central binding v1 uses an allowlist of identity, layout and compatibility fields. Unknown fields, executable/script/install/command path fields, project-root mismatch, API mismatch and coexistence with legacy binding produce `BINDING_CONFLICT`. Binding data is never executed.

## Evidence

- `P01-V05-ROOT-FALLBACK`: PASS against module-qualified legacy oracle.
- `P01-V05-CANONICAL-PREFERRED`: PASS.
- `P01-V05-CENTRAL-NO-FALLBACK`: PASS with `LOCAL_STATE_MISSING` despite an InstallRoot decoy.
- `P01-V06-BINDING-INJECTION`: PASS with `BINDING_CONFLICT`.
- `P01-V06-WITNESS-NOT-RUN`: PASS.
- `P01-V06-DUAL-BINDING`: PASS.
- `P01-NEGATIVE-AMBIGUOUS-RULE`: PASS with `RUNTIME_INTEGRITY_FAILED`.

No project was migrated and no real binding/catalog was created outside temporary fixtures.
