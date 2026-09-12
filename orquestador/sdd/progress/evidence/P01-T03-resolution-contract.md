# P01-T03 - Read and write resolution contract

Status: implemented and validated under `P01-COMPLETE-020`.

## Interface

- Entry point: `Resolve-HebriResourcePath`.
- Request schema: `hebrinex.runtime.path_request` version `1.0.0`, API line `1`.
- Result schema: `hebrinex.runtime.path_result` version `1.0.0`, API line `1`.
- Executable classification authority: `packaging/runtime-layout.json`.
- Unknown paths are denied by default.

The result identifies the logical resource, winning rule, classification, purpose, root kind/path, validated path, relative path, access, existence, writability, deployment mode and legacy-fallback flag.

## Separation

- `-Access read` requires existence unless `-AllowMissing` is explicit.
- Missing immutable product/template content returns `RUNTIME_INTEGRITY_FAILED`.
- Missing local state returns `LOCAL_STATE_MISSING`.
- `-Access write` returns a destination only. It does not create a directory or file.
- Product/template writes return `RESOURCE_WRITE_FORBIDDEN` before any creation.

## Evidence

- `P01-V01-ALL-RULES`: PASS; all 90 rules exercised.
- `P01-V01-PRODUCT-WRITE`: PASS; immutable write rejected.
- `P01-V01-INSTALL-UNCHANGED`: PASS.
- `P01-V02-MISSING-READ`: PASS.
- `P01-V02-PREPARE-PATH`: PASS.
- `P01-V02-NO-CREATE`: PASS.
- `P01-V02-OPTIONAL`: PASS; optional absence remained explicit.

The legacy `Resolve-HarnessPath`, `Get-HebriInstanceRelativePath` and `Read-HarnessText` functions were retained unchanged. Migration of existing consumers is deferred rather than silently changing their behavior.
