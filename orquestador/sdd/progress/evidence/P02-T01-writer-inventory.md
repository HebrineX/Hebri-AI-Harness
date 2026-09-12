# P02-T01 - State writer inventory

Phase: P02. Reviewer scope: repository runtime scripts, direct filesystem primitives and effect dispatchers.

## Direct and delegated writers

| Surface | Durable effects | P02 disposition |
|---|---|---|
| `scripts/command-gateway.ps1` | Persists `runtime/gateway-rate.json` before an approved Apply command. | Central Apply requires operation-safety/1. Apply now reports `writes=true`; CheckOnly remains pure. |
| `scripts/hebrinex.ps1` bootstrap/update/restore | Creates/copies bound harness data, `.gitignore`, backups, reports, bindings and restore output. | Guarded before the first target creation in `central_instance`. Context is forwarded to nested migration and gateway dispatch. |
| `scripts/hebrinex.ps1` approval/lock | Creates legacy approval envelopes and Markdown locks. | Classified as control-plane compatibility. Legacy lock mutation is blocked in `central_instance`; operation-safety/1 replaces it there. |
| `scripts/migrate-harness.ps1` | Writes backups, manifests, migration contract and report. | Central Apply requires descriptor, scoped approval, lock and applying journal. |
| `scripts/build-instructions.ps1` | Regenerates role contracts, prompts and capability defaults with `-WriteOutputs`. | Central write mode is guarded; default comparison mode is read-only. |
| `scripts/claude-reentry.ps1` | Creates and writes the reentry brief outside CheckOnly. | Central write mode is guarded. The prior CheckOnly directory creation defect was removed. |
| `scripts/install-claude-hooks.ps1` | Writes `CLAUDE.md` and `.claude/settings.json`. | Central Apply is guarded before project/directory creation. |
| `scripts/install-host-integrations.ps1` | Writes host integration files. | Central Apply is guarded before target directory creation. |
| `scripts/regularize-state.ps1` | Creates backup and rewrites progress state. | Central Apply is guarded; CheckOnly remains read-only. |
| `scripts/regularize-registry.ps1` | Creates backup and rewrites progress registry. | Central Apply is guarded; CheckOnly remains read-only. |
| `scripts/lib/hebri-common.psm1` | Legacy control-plane files plus v1 approvals, locks, journals, backups and results. | Versioned operation-safety/1 authority. Approval creation is an explicit control-plane prerequisite, not a business writer bypass. |
| Validation scripts and operation worker | Create marker-owned disposable fixtures and validation approvals. | Fixture-only; isolated per validator process and cleaned by ownership marker. |

`scripts/state-machine.ps1`, `scripts/agent-runtime.ps1`, status paths and hook policy checks have no direct durable write primitive. `mcp/server.mjs` spawns CLI/Git processes but does not directly write files; automatic central-mode selection remains a P03/P04 host integration requirement.

## Corrected observations

- Gateway Apply previously persisted rate state while its result could report `writes=false`; the v0.5 result now reports the effect.
- Claude reentry CheckOnly previously created its output directory; creation now occurs only in write mode.
- `hebrinex approve -Risk` previously failed to forward the supplied risk to the legacy envelope. Future envelopes persist the declared risk and the CLI validator checks it.
- Historical envelope `APR-20260909T150307Z-6dd2d0` remains immutable and contains the old risk-field defect. Human scope is evidenced separately by `P02-COMPLETE-021`; the historical record was not rewritten.

Verdict: complete for the current source-template runtime and explicit `central_instance` guard surface. Activation by future launchers is not claimed here.
