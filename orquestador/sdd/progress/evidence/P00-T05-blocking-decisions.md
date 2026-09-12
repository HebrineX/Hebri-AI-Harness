# Evidence - P00-T05 Blocking Decisions

```yaml
evidence_id: E-P00-T05-001
cycle_id: C-001
slice_id: P00-T05
agent_id: A-P00-L01
role: leader
execution_mode: simulated_roles
approval_id: P00-T05-EXEC-015
action_type: blocking_decision_register
summary: "Classify Windows, architecture, engine, schema and initial limits without claiming untested support."
result: accepted_with_blocking_experiments
created_at: "2026-09-08"
```

## Decision Rule

`supported` requires the exact product artifact to pass its declared matrix. A local source-tree run can establish an observed development baseline or a validation candidate, but it cannot certify a clean machine, MSI lifecycle, offline operation or another architecture. Missing evidence is therefore `blocked` or `not_run`, never an inferred pass.

## Decision Register

| ID | Subject | Decision | State | Owner and required evidence |
|---|---|---|---|---|
| P00-D12 | Base platform | The first validation candidate is Windows client build `10.0.26200`, x64. No marketing edition is asserted because local APIs reported inconsistent product/build labels. | candidate, not supported | P06-T01/P06-T07: identify clean VM edition, build, patch, architecture and user; install the exact MSI and run launcher/core tests. |
| P00-D13 | Architecture | x64 is the only initial candidate. ARM64, x86, WSL and Windows Server are outside the initial support claim. | accepted scope limit | A later owner must add an explicit environment and full applicable matrix before adding any excluded target. |
| P00-D14 | Base PowerShell engine | `pwsh 7.6.5` x64 is the exact first candidate because it is the only version used for the passing local aggregate baseline. Do not claim a lower minimum yet. | candidate, not supported | P06-T01/P06-T07: decide bundled runtime versus prerequisite, review redistribution/license terms, then prove clean and offline operation with an exact version. |
| P00-D15 | Windows PowerShell 5.1 | Do not include 5.1 in the initial support claim. A local aggregate attempt under `5.1.26100.9278` failed at `validate-cli`; its parent process truncated terminating child stderr under `$ErrorActionPreference = 'Stop'`, so the current validator cannot prove this engine. | blocked experiment | CLI owner + P06-T01: make validation engine-pure and reliable, then run the full suite under 5.1 if support is still desired. No product fix is authorized in P00. |
| P00-D16 | Harness/API line | Adopt central runtime API line `1` with one active engine per compatible API line. `0.17.1` remains the observed source baseline; `0.18.0` is the candidate first central engine version, not an installed or supported release. | design accepted; release candidate not_run | P01-T08 defines the interface; P06/P07 prove release and compatibility. Incompatible API/schema fails closed without writes. |
| P00-D17 | New binding schema | Adopt JSON contract ID `hebrinex.binding`, integer `schema_version: 1`, `layout: central_instance`, and the required field boundary listed below. The current `PROJECT_BINDING.yaml` remains a separately identified legacy migration input and cannot be simultaneous authority. | design accepted; schema implementation not_run | P01-T02/P04-T02 implement one canonical Draft 2020-12 schema plus positive/negative fixtures; P05 proves transactional migration and conflict handling. |
| P00-D18 | Optional MCP engine | Node is not required by the base core. For MCP, local Node `22.16.0` and lockfile dependencies are only a development candidate; package metadata's `>=18` is a declaration, not a tested support range. | optional candidate, packaging blocked | P06-T01/P06-T06: choose exact Node strategy, declare direct dependencies, inventory licenses/hashes and pass offline smoke without hidden downloads. |
| P00-D19 | Initial operational limits | Preserve the exact existing agent/context/gateway limits below. Do not invent payload, latency, catalog-size or concurrency throughput limits before measurement. | accepted transitional limits | P03 owns benchmark thresholds; P04/P08 own concurrency and recovery measurement. Exceeding a hard safety limit blocks rather than silently raising it. |
| P00-D20 | Base topology | Keep P00-T04: on-demand core, one project context per invocation/session-scoped MCP process, file authority, no daemon, database or new dependency. | accepted | Reconsider only with the measured evidence listed in P00-T04. |

## Observed Environment

| Observation | Value | Confidence and limitation |
|---|---|---|
| OS runtime description | `Microsoft Windows 10.0.26200` | observed via .NET runtime API; not a product support statement |
| Registry identity | `ProductName=Windows 10 Pro`, `DisplayVersion=25H2`, `CurrentBuild=26200`, `UBR=9278` | observed; label/build combination is retained verbatim and not normalized |
| Architecture | OS `X64`, process `X64` | observed on this host only |
| PowerShell Core | `PSEdition=Core`, `7.6.5` | aggregate Harness validation passes locally with soft context warnings |
| Windows PowerShell | `PSEdition=Desktop`, `5.1.26100.9278` | installed; full compatibility not established |
| Node/npm | Node `v22.16.0`, npm `10.9.2` | observed tooling for optional MCP only |
| Provider CLIs | `codex` found; `claude` not found | observed host state; no role-backend execution in T05 |
| Packaging tool | `wix` command found | presence only; version, provenance, license, build and MSI are not_run |

`Get-CimInstance Win32_OperatingSystem` returned access denied in the restricted execution context. The runtime and registry reads above succeeded, so the denied query is not replaced with an inferred edition.

## Binding V1 Boundary

The P01/P04 implementation must express one canonical JSON Schema with:

- schema ID value `hebrinex.binding` and integer `schema_version: 1`;
- closed top-level object (`additionalProperties: false`);
- required `layout`, `project_id`, `instance_id`, `project_root`, `instance_relative_path`, `required_engine`, `state_schema_version`, `last_verified_engine_version`, `created_at` and `updated_at` fields;
- `layout` initially restricted to `central_instance`;
- non-empty unique IDs, explicit semantic-version parsing and UTC timestamps;
- relative instance path with traversal, alternate providers, ADS and unsupported reparse points rejected;
- `required_engine.api_line: "1"`; candidate minimum engine `0.18.0`, which cannot become a support claim before a matching implementation and compatibility fixtures exist;
- no executable path supplied by the project binding;
- explicit conflict if legacy YAML and JSON both appear authoritative.

Related release, instance-state, request/result, task-pack, handoff and journal schemas remain owned by their later phases. This decision does not create duplicate provisional schema files.

## Initial Limits

| Limit | Initial value | Scope |
|---|---|---|
| Active engine versions | one active engine per API line | no automatic side-by-side selection |
| Initial platform architecture | x64 only | candidate matrix, not certified support |
| MCP project isolation | one explicit project context per process/connection | required while `ROOT` and assumed role are process-global |
| Active agents | `min(host capacity, 5)` total | host has no real subagent facility in this run; roles are serialized simulations |
| Kernel budgets | values in `orquestador/context-budget.yaml` | current policy; hard stop at 2x soft threshold where implemented |
| Stable gateway child timeout | 120 seconds maximum | existing stable0.5 schema behavior, not a new service SLO |
| Safety violations | zero accepted | root, authority, role, approval, containment and integrity violations block |
| Payload/disk saving | measured baseline only | no invented percentage threshold |
| Runtime latency/catalog throughput | no accepted numeric target | P03/P04/P08 must freeze workload and thresholds before measurement |

Current budget validation remains below hard limits but emits soft warnings for `leader_light 3637/2600` (hard `5200`) and `runtime_reentry 2727/1600` (hard `3200`). The live registry must remain compact; T05 does not raise limits to hide this warning.

## Blocking Experiments

| Experiment | Phase/owner | Pass condition | Current state |
|---|---|---|---|
| WIN-X64-CLEAN-01 | P06-T07 reviewer | Exact Windows client x64 VM installs MSI, opens a new console and executes core validation as standard user. | not_run, blocks support |
| WIN-X64-OFFLINE-02 | P06-T06/P06-T07 | Core installs and runs with verified egress disabled and no downloads; prerequisites and hashes match inventory. | not_run, blocks support |
| PS-RUNTIME-03 | P06-T01 leader + auditor | Exact `pwsh` version and bundle/prerequisite policy are fixed with provenance, license and clean-VM proof. | not_run, blocks distribution |
| PS51-04 | CLI owner + P06-T01 | If 5.1 remains desired, validators execute children under 5.1, preserve full diagnostics and the complete suite passes on a named VM. | blocked; not in initial scope |
| SCHEMA-V1-05 | P01-T02/P04-T02 | Canonical schema and fixtures accept the contract above and reject unknown fields, traversal, invalid IDs/versions and ambiguous legacy authority. | not_run, blocks binding implementation |
| API-COMPAT-06 | P01-T08/P07-T01 | API line 1 and schema compatibility matrix pass upgrade/incompatible cases without project writes on failure. | not_run, blocks release |
| MCP-OFFLINE-07 | P06-T06 | Exact Node/dependency payload, direct dependency declarations, notices and hashes pass offline smoke; absence is diagnosed without breaking core. | blocked by P00-B07 |
| LIMITS-BENCH-08 | P03/P04/P08 | Corpus/workload, repetitions and thresholds are frozen before measurement; results include failures and p95. | not_run; no performance claim |

## Validation Evidence

- Local aggregate under `pwsh 7.6.5`: exit `0` after T05 tracking updates; all Harness validators passed with only the two recorded soft context-budget warnings.
- Local aggregate launched from Windows PowerShell `5.1.26100.9278`: exit `1`; `validate-cli` reported seven negative-output pattern mismatches while other reached validators passed. Reproduction showed `$ErrorActionPreference = 'Stop'` in the 5.1 parent retained only the first stderr line from the `pwsh` child, omitting the expected terminal message. This is a validator portability blocker, not proof that every product command fails on 5.1.
- CI is Ubuntu-only and invokes `pwsh`; it provides no Windows or MSI support evidence.
- No network, install, MSI build, service, schema implementation or product file was changed in T05.

## Input Hashes

SHA-256 snapshot used for this decision:

```text
CD81EC19767FFB807BADA6D48578A18D77A29ADB394E09E9CDFCD5EA9EEBB6A2  HARNESS_VERSION
891A1C88ACC28D9B0A8EF9BABCF2A7A13D8EFA83EC90132D29B2EBBF841DABB4  PROJECT_BINDING.yaml
B79982CC3E9C70B066FA04A34A82F0CBC530C096BDC705054D6ECD581E5AA16F  orquestador/policies/schemas/project-binding.schema.yaml
8D5377C0EBFC1203D155E06DE1D52019F93516DA9E22AB4CC29942AC9B51069B  orquestador/sdd/progress/schemas/state.schema.yaml
570D460DEE1E8A9BBB2B0E1D5FBED8136D40D2E49F06178CAD5BF2C41D748AFB  orquestador/runtime/schemas/harness-command.schema.json
33F064B45E57873B41E12CC439C7B84C23B2BF5B8A4EAF006A0F63C2ED445334  orquestador/runtime/schemas/command-gateway-result.schema.json
89D640A45FB5E413AC6A62BAFF4885F7764994519B4E5EC96B896453DF33153C  orquestador/runtime/schemas/active-session.schema.json
0A2F330A2CE62AFAF0DB1B0A5748D4F3D092DD869B4D5A26B329B950289D7BAA  orquestador/context-budget.yaml
103818DDD1AF72AC20C5BA2DF0461C67807CE1C491DD475B91452FC6C6A1F3D2  mcp/package.json
452FB3436496EDDD2881E8865F49B10200768B84D05F6F159BD7BEA7996A38CB  .github/workflows/ci.yml
BCC47BFE6540CDC36BA440A89167D4EB135577F72D2641A4AAE0533DC24997C9  migracion/FUENTES-DECISIONES.md
71ABF7621FA4F23A69C51FCB74900930F0F97A4DC0D032419677C1A183007818  migracion/ARQUITECTURA-CONTRATOS.md
8D6E3610114F8356A21415DA310975A895503AB9C1FCFC240C5A5DEC9B0E2011  migracion/VALIDACION.md
```

## Handoff

P00-T05 is complete as a decision point: it fixes the narrow initial candidate and contract boundary, and assigns every missing proof to an explicit blocking experiment. It does not certify a product platform. P00-T06 can now design sanitized fixtures against `hebrinex.binding@1`, including new, legacy, drift, conflict, duplicate and corrupt-state cases.
