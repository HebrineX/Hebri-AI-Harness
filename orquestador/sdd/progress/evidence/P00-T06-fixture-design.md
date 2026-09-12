# Evidence - P00-T06 Sanitized Fixture Design

```yaml
evidence_id: E-P00-T06-001
cycle_id: C-001
slice_id: P00-T06
agent_id: A-P00-I03
role: executor
declared_task_role: implementer
execution_mode: simulated_roles
approval_id: P00-T06-EXEC-016
action_type: fixture_design
summary: "Design sanitized fixtures for new, legacy, drift, conflict, duplicate and corrupt-state cases."
result: accepted_design_with_blockers
created_at: "2026-09-09"
```

## Scope and Status

This artifact defines the future fixture inventory and expected content. It does not instantiate consumer trees, implement schemas, alter product validators or prove runtime behavior. Every executable result remains `not_run` until its owning phase creates the fixture under an approved test root and invokes the real implementation.

The design covers R01, R03, R04, R05, R07, R16 and R17, plus P00-V02. It carries forward the P00-T05 boundary: central binding `hebrinex.binding@1`, API line `1`, one active engine per line and fail-closed incompatibility.

## Proposed Fixture Package

Future root, subject to a later implementation approval:

```text
orquestador/testing/fixtures/central-binding/
  README.md
  FX-CB-001-new-project/
  FX-CB-002-legacy-intact/
  FX-CB-003-legacy-drift/
  FX-CB-004-binding-conflict/
  FX-CB-005-duplicate-copy/
  FX-CB-006-corrupt-state/
```

Each scenario directory contains explicit files rather than inherited mutable state:

```text
fixture-manifest.json        fixture ID, classification, requirements and operation
input/                       synthetic project/catalog templates
expected/result.json         semantic oracle; no host-specific absolute paths
expected/unchanged-paths.txt paths whose pre/post hashes must match
expected/changed-paths.txt   exact allowed changes; empty for fail-closed cases
```

The implementation runner materializes templates beneath a verified system-temporary root named `hebrinex-central-fixture-<run-id>`. It rejects cleanup unless the resolved absolute target remains under that root. Static template hashes are stored separately from hashes created after path-token expansion.

## Common Manifest Contract

The future `fixture-manifest.json` shape must contain at least:

| Field | Required content |
|---|---|
| `schema` | `hebrinex.test.fixture` |
| `schema_version` | integer `1` |
| `fixture_id` | one stable `FX-CB-*` ID |
| `classification` | `positive`, `negative` or `mixed` |
| `requirements` | explicit Rxx IDs |
| `source_contracts` | paths plus SHA-256 for schema/decision inputs |
| `template_tokens` | allowlist such as `${FIXTURE_ROOT}`, `${PROJECT_ROOT_A}`, `${PROJECT_ROOT_B}` |
| `operation` | candidate protocol operation and `CheckOnly`/`Apply` mode |
| `preconditions` | files, identities and engine/schema state before invocation |
| `oracle` | status, semantic error, candidate exit code, writes flag and next action |
| `snapshot_scope` | exact paths hashed before and after |
| `cleanup_scope` | the one verified temporary root |

Unknown manifest properties fail schema validation. Token expansion is data substitution only: it cannot inject an executable path, provider path, traversal, ADS, UNC root or a path outside the temporary fixture root.

## Fixture Inventory

| Fixture | Classification | Synthetic input | Operation | Expected oracle |
|---|---|---|---|---|
| `FX-CB-001-new-project` | positive/mixed | One project marker; no `.hebrinex`, binding, instance or catalog entry. Fixed project ID is assigned in the plan, not read from ambient state. | `project.inspect`, then `project.bind` in `CheckOnly` | Inspect returns `CONTEXT_NOT_FOUND` with zero writes. Bind returns `planned`, lists only binding/instance/catalog effects, reports no copied engine payload and performs zero writes. |
| `FX-CB-002-legacy-intact` | positive candidate | One `.hebrinex/PROJECT_BINDING.yaml` with `binding_mode: bound`, exact materialized project root, fixed instance ID and legacy `0.17.1` source shape; no JSON binding. Minimal instance markers have known hashes. | `context.resolve`, then `migration.plan` | Resolver identifies `legacy` explicitly and does not fall back to central mode. Plan preserves identity/state and performs zero writes. Executable positive status is blocked by the legacy schema-version discrepancy below. |
| `FX-CB-003-legacy-drift` | mixed/negative | Legacy fixture plus one modified manifest-known shared file and one unknown synthetic local file containing only `fixture custom content`. | `migration.plan` in `CheckOnly` | Result inventories both differences, classifies preserve/conflict action, sets `apply_available: false` until conflict resolution and leaves every hash unchanged. Unknown content is never dropped or copied to product payload. |
| `FX-CB-004-binding-conflict` | negative family | Simultaneous legacy YAML and central JSON with deliberately contradictory identity/root/API variants. | `context.resolve` | Returns conflict/incompatibility explicitly, never chooses by timestamp, never rewrites either binding and performs zero writes. Variants are listed below. |
| `FX-CB-005-duplicate-copy` | negative | Two authorized synthetic project roots with the same `project_id` but distinct `instance_id`, root and marker hashes; fixture-scoped catalog may contain one stale entry. | `catalog.reconcile`, then context resolution for each root | Returns `CONFLICT`; neither project grants authority over the other, no ID is regenerated, and pre/post snapshots for both projects match. |
| `FX-CB-006-corrupt-state` | negative | Valid central-binding template plus a deliberately truncated or structurally invalid instance state file; no real evidence, approval, lock or backup data. | An operation that requires instance state | Returns `INTEGRITY_FAILURE` candidate exit `7`, links a recovery-oriented next action, does not recreate state silently and performs zero writes. Executable oracle waits for a repaired canonical state schema. |

## P00-V02 Contradictory Cases

The reviewer receives three independent contradictions, not three labels over one tree:

1. `FX-CB-004-A-id-conflict`: YAML instance identity and JSON `project_id`/`instance_id` disagree for the same materialized root. Expected semantic class: `CONFLICT`, candidate exit `6`.
2. `FX-CB-004-B-root-moved`: binding identity is stable but one binding names a different materialized project root. Expected diagnosis: moved/root conflict and explicit rebind planning; zero automatic mutation.
3. `FX-CB-005-duplicate-copy`: two roots claim the same project ID. Expected semantic class: `CONFLICT`, candidate exit `6`; both roots remain unchanged.

An additional `FX-CB-004-C-api-incompatible` variant sets `required_engine.api_line` to an unsupported value. Its expected semantic class is `INCOMPATIBLE_CONTRACT`, candidate exit `4`, not a generic conflict.

## Expected Synthetic Content

Deterministic identifiers use reserved-looking fixture values only inside the temporary test scope:

```text
project A: 11111111-1111-4111-8111-111111111111
instance A: aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa
project B: 22222222-2222-4222-8222-222222222222
instance B: bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb
timestamp: 2000-01-01T00:00:00Z
```

Central binding templates follow the P00-T05 required field boundary. They contain `layout: central_instance`, `required_engine.api_line: "1"`, candidate minimum engine `0.18.0`, state schema version `1` and only materialized fixture-root paths. Legacy templates contain only the documented `PROJECT_BINDING.yaml` keys needed by the selected route.

No fixture contains:

- a real username, machine path, repository remote, e-mail address or project name;
- `.git`, `.codex`, `infoHebri.md`, host settings or user memory;
- credentials, token-like values, private keys, environment files or secret-bearing commands;
- copied approvals, locks, journals, backups, reports, audit logs or historical evidence;
- text that purports to grant approval, including a standalone operator `SI`;
- network calls, package downloads, executable payloads or links escaping the fixture root.

## Oracle and Snapshot Rules

- Static fixtures prove only their declared shape. Acceptance requires the real resolver/migration/catalog implementation to consume them.
- `expected/result.json` uses candidate API-line-1 semantics from the architecture. P01/P02 must freeze any code before implementation tests depend on it.
- Every `CheckOnly` and fail-closed case requires `writes_performed: false`, an empty changed-path list and equal pre/post hashes.
- The drift case must preserve exact bytes for the unknown file and must not silently normalize the modified shared file.
- The duplicate case snapshots both project roots and the fixture-scoped catalog; a command scoped to A cannot change B.
- The corrupt-state case cannot report success, synthesize a replacement or classify the invalid file as absent.
- Diagnostics may refer to fixture-relative paths and IDs, but output comparison must redact the materialized host-temporary prefix.
- Cleanup occurs in a `finally` path after preserving the sanitized result/hashes required by the test. A failed safety check leaves the tree and reports the path rather than deleting an unverified target.

## Reuse and Gaps in Existing Tests

- `scripts/validate-bootstrap.ps1` already creates a temporary consumer, validates the resolved path and refuses cleanup outside system temp. The future runner should reuse that safety discipline.
- `scripts/validate-bound-update.ps1` already exercises marker preservation and pre-write backup behavior for the copied legacy layout.
- `scripts/validate-fixtures.ps1` currently validates small fixture files mostly by regex. It must not be treated as proof that a JSON binding, resolver or migration implementation rejected an input.
- The new central fixture family should be added to a real schema/parser/conformance validator only when P01/P02/P04 implementation exists. T06 does not modify the current validator.

## Blocking Contract Defects

1. `PROJECT_BINDING.yaml` declares Harness `0.17.1`, while `orquestador/policies/schemas/project-binding.schema.yaml` requires `0.17.0`. Until an owner fixes or versions this contract, `FX-CB-002-legacy-intact` is an observed legacy candidate, not a proven valid fixture.
2. `orquestador/sdd/progress/schemas/state.schema.yaml` contains literal `` `n `` sequences. Until corrected, the corrupt-state fixture cannot distinguish a deliberately corrupt input from defects in the supposed valid schema.
3. `hebrinex.binding@1` and its executable validator remain `not_run` under P00-B12. The templates above are design inputs, not accepted runtime payloads.

## Validation Evidence

- JSON migration state and 44 audit events parsed successfully; event IDs were unique before the final validation record.
- `git diff --check` returned exit `0`.
- Aggregate `scripts/validate-harness.ps1 -RunNegativeTests` returned exit `0`; release, stable CLI, bootstrap, bound update/backups/restore, agent contracts, security, migration, existing fixtures, gateway, state machine and agent runtime passed.
- Soft context warnings remain: `leader_light 3846/2600` (hard `5200`) and `runtime_reentry 2937/1600` (hard `3200`). The next slice must compact the live registry before adding enough history to cross the hard limit; limits are not raised.
- Locks directory contains only its retained `_README.md` marker after validation.
- No central-binding fixture tree or product validator was created or modified; all designed fixture executions remain `not_run`.

## Input Hashes

```text
444950D3A526B819D655EC981FC37CB3BB64CD2BA54BB1CD364083519EFD7539  migracion/fases/P00-baseline-y-contrato.md
772C2231C9372F04C5FF4A71C8571F35FBC9E2A6AE7ACE3075E16F10C42990F2  migracion/REQUISITOS.md
71ABF7621FA4F23A69C51FCB74900930F0F97A4DC0D032419677C1A183007818  migracion/ARQUITECTURA-CONTRATOS.md
8D6E3610114F8356A21415DA310975A895503AB9C1FCFC240C5A5DEC9B0E2011  migracion/VALIDACION.md
8B0B3E8CF05CB549ECCD1CD333D5A03036AB1EEF68EF586A6E3488422AE6B015  orquestador/sdd/progress/evidence/P00-T05-blocking-decisions.md
ECCCA881B8E0D1657F6D537FA199ADA058E5F1B10F0449F87096DC1D3438478C  orquestador/testing/fixtures/README.md
04BEA48732C0605BDBFB05E8AB37F6CC42C34A68DB5A527CEA79A26D30E8B2AD  scripts/validate-fixtures.ps1
E469B02986DBF31F2F84707974D3C90329EB0F1E9B37CDB60F1CC557D4459ABB  scripts/validate-bootstrap.ps1
5A6EDDF4FAB359A37475DB291F8AC8587CE631734A344EB76CAA8C0F5E9DB9B6  scripts/validate-migration.ps1
03F9D6C4146072772DB45445D635AD6AB3F65CE573887799E7061B1FC7586856  scripts/validate-bound-update.ps1
891A1C88ACC28D9B0A8EF9BABCF2A7A13D8EFA83EC90132D29B2EBBF841DABB4  PROJECT_BINDING.yaml
B79982CC3E9C70B066FA04A34A82F0CBC530C096BDC705054D6ECD581E5AA16F  orquestador/policies/schemas/project-binding.schema.yaml
8D5377C0EBFC1203D155E06DE1D52019F93516DA9E22AB4CC29942AC9B51069B  orquestador/sdd/progress/schemas/state.schema.yaml
```

## Handoff

P00-T06 is complete as a fixture design. P00-T07 must independently compare these six groups, the three contradictory variants, P00 decisions and R01-R18. It must report design defects or documentary acceptance without presenting any fixture as executed.
