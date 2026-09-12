# P01-T02 - Runtime context contract

Status: implemented and validated under `P01-COMPLETE-020`.

## Versioned interface

- Schema: `hebrinex.runtime.context`
- Contract version: `1.0.0`
- Runtime API line: `1`
- PowerShell entrypoint: `Resolve-HebriRuntimeContext`
- Machine-readable schema: `orquestador/runtime/schemas/harness-runtime-context.schema.json`

The context contains `install_root`, `project_root`, `instance_root`, `catalog_root`, `project_id`, `deployment_mode`, `binding_path`, `harness_version`, `layout_sha256` and `trusted_install_source`.

## Root authority

| Field | Authority | Rejected alternative |
|---|---|---|
| `InstallRoot` | Explicit trusted launcher input plus runtime integrity validation | Binding field, CWD or existence search |
| `ProjectRoot` | Explicit caller input verified against the selected binding | CWD-only inference |
| `InstanceRoot` | Deterministic derivation from mode and verified project | Binding-supplied arbitrary path |
| `CatalogRoot` | Explicit input or current-user LocalApplicationData default | Project binding |
| `projectId` | Verified central or legacy binding identity | Folder name inference |

`central_instance`, `legacy_bound` and `source_template` are explicit modes. A context is reconstructed and compared on every resource resolution, so mutating a previously returned root produces `BINDING_CONFLICT`.

## Evidence

- `P01-V01-CONTEXT-A`: PASS.
- `P01-V01-CONTEXT-B`: PASS; two projects produced different instance roots.
- `P01-V03-SIMILAR-ROOT`: PASS; a modified context was rejected.
- The context schema and layout parsed in both PowerShell 7.6.5 and Windows PowerShell 5.1.26100.9444.

No Windows registry discovery was implemented or claimed; P06 owns installed-product discovery.
