# P01-T01 Canonical Path Classification

```yaml
evidence_id: E-P01-T01-001
cycle_id: C-002
phase_id: P01
slice_id: P01-T01
agent_id: A-P01-I01
role: executor
declared_task_role: architect-implementer
execution_mode: simulated
operator_approval_id: P01-T01-LAYOUT-019
runtime_approval_id: APR-20260909T052210Z-5eec12
action_type: documentary_path_contract
result: accepted_with_findings
created_at: "2026-09-09"
```

## Outcome Boundary

This document converts the P00 inventory into one canonical classification for P01. It does not implement `ResolveHarnessContext`, `ResolveHarnessPath`, schemas, payload packaging or consumer integration. Those remain owned by P01-T02 through P01-T08.

The classification covers:

- all 21 P00 shared roots;
- the instance root and all 17 P00 instance mappings;
- all five observed ProjectRoot host outputs;
- all six P00 sharing exclusions;
- all 36 structural-manifest entries not selected by the current shared, instance or exclusion lists;
- future binding, catalog and `.gitignore` targets already required by the architecture contract.

## Canonical Vocabulary

Only the architecture classes below are canonical. P01 task terms are recorded as `purpose` metadata so they do not create a competing enum.

| Class | Effective root | Read policy | Write policy | Task-term mapping |
|---|---|---|---|---|
| `product` | `InstallRoot` | Allowed after runtime integrity/version validation. | Denied to project runtime; installer lifecycle only. | `shared` |
| `template` | `InstallRoot` | Allowed as immutable input after integrity validation. | Template itself denied; materialization requires an explicit destination-class operation. | `template` |
| `instance` | `InstanceRoot`, except the exact new binding target under `ProjectRoot/.hebrinex` | Allowed for the bound project and declared operation. | Requires project scope, approval when effectful, containment and locks/journal where applicable. | `instance`, `backup`, instance-local `generated` |
| `integration` | `ProjectRoot` | Exact allowlist only. | Regenerable host shim/config only, with project approval; never shared engine payload. | ProjectRoot `generated` |
| `catalog` | `CatalogRoot` fixed by launcher for the current user | Auxiliary lookup only; never project authority. | Reconciler/diagnostic operation only, independently locked. | `catalog` |
| `denied` | none | Denied. | Denied. | `excluded`, unknown or ambiguous |

`shared`, `generated`, `backup` and `excluded` therefore remain useful purposes, not additional classes:

- `shared -> product/purpose=shared`;
- ProjectRoot `generated -> integration`;
- runtime/report `generated -> instance/purpose=generated`;
- `backup -> instance/purpose=backup`;
- `excluded -> denied`.

## Root Contract

| Root | Authority and derivation | Non-negotiable boundary |
|---|---|---|
| `InstallRoot` | Trusted launcher/registered product family plus integrity/version evidence. Never taken from an executable path in a project binding. | Consumer reads/executes verified product; consumer never writes it. |
| `ProjectRoot` | Explicit normalized project input verified against the binding. CWD alone is insufficient. | Operation for project A cannot resolve into project B. |
| `InstanceRoot` | Canonical `<ProjectRoot>/.hebrinex/instance`, derived only after ProjectRoot/binding validation. | Mutable project state never falls back to a same-named InstallRoot path. |
| `CatalogRoot` | Current-user platform location `%LOCALAPPDATA%/Hebri-AI-Harness`, selected by launcher/runtime policy. | Reconstructible metadata; cannot select code, identity or permissions. |

The central target layout remains:

```text
InstallRoot/{bin,engine,contracts,templates,payload-manifest.json,release.json}
ProjectRoot/.hebrinex/{binding.json,instance/...}
CatalogRoot/{projects/<projectId>.json,logs/...}
```

Exact physical relocation inside `InstallRoot` is a packaging concern for P06. P01 uses stable logical resource IDs so a package layout change does not silently change classification.

## Deterministic Classification

The executable implementation must apply these rules in order:

1. Accept a declared logical resource ID, access intent and explicit context; never classify a raw CWD-derived path as authority.
2. Normalize supported local syntax and reject empty resource IDs, traversal, absolute external paths, alternate providers, ADS and unsupported reparse traversal before matching.
3. Select rules by namespace and segment-boundary match. Exact path outranks prefix; a longer prefix outranks a shorter prefix.
4. If two rules of equal specificity disagree, return a classification conflict. Do not choose by file existence, timestamp or list order.
5. Apply access policy after class selection. `product` and `template` never return writable destinations to a consumer.
6. A missing optional resource remains in its declared class. Absence never triggers central-to-legacy or instance-to-product fallback.
7. If no rule matches, return `denied` with future semantic error `RESOURCE_UNKNOWN`.

The namespace distinction is required where the same relative text has different meanings. For example, source-repository `.gitignore` is denied from payload, while logical integration resource `project_gitignore` targets the exact `ProjectRoot/.gitignore` path.

## Product/Shared Classification (P00 S01-S21)

All entries are `class=product`, `root=InstallRoot`, `purpose=shared`, `consumer_write=deny`. More-specific overrides listed later win.

| P00 ID | Logical prefix | Specific override |
|---|---|---|
| S01 | `agents` | none |
| S02 | `mcp` | `mcp/agents-backend.local.yaml` is instance; `mcp/node_modules` is denied. |
| S03 | `prompts` | none |
| S04 | `scripts` | none |
| S05 | `orquestador/adapters` | none |
| S06 | `orquestador/agents` | none |
| S07 | `orquestador/entrypoints` | none |
| S08 | `orquestador/instruction-builder` | none |
| S09 | `orquestador/integrations` | product source/templates; generated host destinations are integration resources. |
| S10 | `orquestador/method` | none |
| S11 | `orquestador/migration/contracts` | exact `post-migration-contract.yaml` is instance. |
| S12 | `orquestador/migration/versions` | none |
| S13 | `orquestador/policies` | none |
| S14 | `orquestador/portability` | none |
| S15 | `orquestador/runtime/schemas` | none |
| S16 | `orquestador/runtime/templates` | class template. |
| S17 | `orquestador/sdd/progress/schemas` | none |
| S18 | `orquestador/sdd/progress/templates` | class template. |
| S19 | `orquestador/sdd/specs/_template` | class template. |
| S20 | `orquestador/security` | none |
| S21 | `orquestador/testing` | test product; production payload inclusion remains P06-owned. |

## Instance Classification (P00 I00-I17)

| P00 ID | Current logical resource | Canonical target | Class / purpose |
|---|---|---|---|
| I00 | `instance` | `InstanceRoot/.` | `instance/root` |
| I01 | `PROJECT_BINDING.yaml` | `InstanceRoot/PROJECT_BINDING.yaml` | `instance/legacy_binding` |
| I02 | `PROGRESS.md` | `InstanceRoot/PROGRESS.md` | `instance/project_progress` |
| I03 | `orquestador/context/**` | `InstanceRoot/context/**` | `instance/project_context` |
| I04 | `orquestador/memory/memory-registry.yaml` | `InstanceRoot/memory/memory-registry.yaml` | `instance/memory_registry` |
| I05 | `orquestador/memory/local/**` | `InstanceRoot/memory/local/**` | `instance/session_memory` |
| I06 | `orquestador/memory/project/**` | `InstanceRoot/memory/project/**` | `instance/project_memory` |
| I07 | `orquestador/memory/cycle/**` | `InstanceRoot/memory/cycle/**` | `instance/cycle_memory` |
| I08 | `orquestador/memory/daily/**` | `InstanceRoot/memory/daily/**` | `instance/daily_memory` |
| I09 | `orquestador/memory/complete/**` | `InstanceRoot/memory/complete/**` | `instance/complete_memory` |
| I10 | `orquestador/sdd/progress/**` | `InstanceRoot/sdd/progress/**` | `instance/runtime_progress`; product schemas/templates override. |
| I11 | `orquestador/sdd/specs/**` | `InstanceRoot/sdd/specs/**` | `instance/project_specs`; product `_template` overrides. |
| I12 | `orquestador/migration/backups/**` | `InstanceRoot/migration/backups/**` | `instance/backup` |
| I13 | `orquestador/migration/contracts/post-migration-contract.yaml` | `InstanceRoot/migration/contracts/post-migration-contract.yaml` | `instance/applied_contract` |
| I14 | `orquestador/migration/reports/**` | `InstanceRoot/migration/reports/**` | `instance/generated_report`; immutable report template overrides. |
| I15 | `orquestador/runtime/gateway-rate.json` | `InstanceRoot/runtime/gateway-rate.json` | `instance/generated_runtime` |
| I16 | `orquestador/runtime/claude/**` | `InstanceRoot/runtime/claude/**` | `instance/generated_runtime` |
| I17 | `mcp/agents-backend.local.yaml` | `InstanceRoot/mcp/agents-backend.local.yaml` | `instance/machine_override` |

The future `hebrinex.binding@1` target is an exact special resource: `ProjectRoot/.hebrinex/binding.json`, `class=instance`, `purpose=binding_identity`. It is outside `InstanceRoot` because it identifies and locates the instance; P01-T02/P04 own its schema and write flow. Legacy YAML and new JSON cannot both be selected as authority.

## Template Overrides

These rules are more specific than product or instance prefixes. Each is `class=template`, stored read-only in `InstallRoot`, and cannot itself be returned as a write target.

| ID | Current logical source | Intended use |
|---|---|---|
| TPL01 | `orquestador/runtime/templates/**` | Runtime contract seeds. |
| TPL02 | `orquestador/sdd/progress/templates/**` | Progress/cycle seeds. |
| TPL03 | `orquestador/sdd/specs/_template/**` | Specification seed. |
| TPL04 | `orquestador/migration/reports/migration-report.template.yaml` | Migration report seed; overrides generated report prefix. |
| TPL05 | `orquestador/runtime/active-session.template.json` | Active-session seed. |
| TPL06 | `instance/README.md` | Documentation seed only; not mutable instance state. |
| TPL07 | `.mcp.json` | Current host-config seed. It must not be copied verbatim for central mode because its command is root-relative; P04 owns generation. |

## ProjectRoot Integration Targets

These are exact `class=integration`, `root=ProjectRoot`, `purpose=generated_host_config` resources. Parent directories do not become writable allowlists.

| ID | Target | Origin/status |
|---|---|---|
| P01 | `CLAUDE.md` | Observed P00 writer. |
| P02 | `.claude/settings.json` | Observed P00 writer. |
| P03 | `.claude/agents/*.md` | Observed P00 writer; filename must come from a product allowlist. |
| P04 | `.cursor/rules/hebrinex.mdc` | Observed P00 writer. |
| P05 | `.github/copilot-instructions.md` | Observed P00 writer. |
| P06 | `.gitignore` merge for `.hebrinex/` | Architecture-required future target; source-repository `.gitignore` remains denied from payload. |

## Catalog Targets

| ID | Target | Class / authority |
|---|---|---|
| C01 | `CatalogRoot/projects/<projectId>.json` | `catalog/project_index`; reconstructible and non-authoritative. |
| C02 | `CatalogRoot/logs/**` | `catalog/generated_diagnostic`; no secrets and never project authority. |

Catalog entries cannot choose `InstallRoot`, change `ProjectRoot`, supply approvals or grant access to another project.

## Denied Resources

The six P00 exclusions remain exact/prefix deny rules:

| P00 ID | Resource | Reason |
|---|---|---|
| X01 | `.git/**` | External VCS metadata. |
| X02 | `.codex/**` | Host-local metadata. |
| X03 | `mcp/node_modules/**` | Dependency/build cache, not a shared runtime classification. |
| X04 | `infoHebri.md` | Personal/local denied. |
| X05 | `infoHebriHarness.md` | Personal/local denied. |
| X06 | `.claude/settings.local.json` | Host-local override, never shared. |

Additional exact denials from the structural-manifest gap are source repository metadata `.gitattributes` and `.gitignore`. Direct requests for mixed ancestor containers `orquestador`, `orquestador/memory`, `orquestador/sdd`, `orquestador/migration` and `orquestador/runtime` are denied; only classified descendants may resolve. Every other unmatched resource is denied by default.

## Disposition of the 36 Previously Unclassified Structural Entries

The current `SHARED_MANIFEST.yaml` lists do not select these 36 entries from `orquestador/harness-manifest.txt`. T01 assigns each a disposition:

| Disposition | Count | Entries |
|---|---:|---|
| `instance` | 1 | `instance` |
| `template` | 3 | `.mcp.json`; `instance/README.md`; `orquestador/runtime/active-session.template.json` |
| `denied` direct/source | 7 | `orquestador`; `orquestador/memory`; `orquestador/sdd`; `orquestador/migration`; `orquestador/runtime`; `.gitattributes`; `.gitignore` |
| `product` | 25 | `AGENTS.md`; `CHANGELOG.md`; `HARNESS_VERSION`; `HOW_TO_USE.md`; `SHARED_MANIFEST.yaml`; `init.sh`; `orquestador/context-budget.yaml`; `orquestador/context-profiles.md`; `orquestador/harness-manifest.txt`; `orquestador/memory/memory-policy.md`; `orquestador/memory/memory-routing.yaml`; `orquestador/memory/README.md`; `orquestador/README.md`; `orquestador/prompt-registry.yaml`; `orquestador/registry-index.yaml`; `orquestador/adapter-registry.yaml`; `orquestador/context-profile-registry.yaml`; `orquestador/gate-registry.yaml`; `orquestador/policy-registry.yaml`; `orquestador/template-registry.yaml`; `orquestador/source-of-truth.md`; `README.md`; `orquestador/migration/migration-registry.yaml`; `orquestador/runtime/README.md`; `orquestador/runtime/commands.md` |
| **Total** | **36** | Complete. |

The 25 product entries are immutable contracts, registries, engine entrypoints or product documentation. Their inclusion in an eventual shipping payload remains subject to P06 payload minimization; classification as product does not require every documentation file to ship.

## Coverage and Conflict Oracles

| Check | Result |
|---|---|
| P00 shared IDs S01-S21 classified | `21/21` |
| P00 instance IDs I00-I17 classified | `18/18` including root I00 |
| P00 ProjectRoot outputs classified | `5/5`; plus architecture target `.gitignore` |
| P00 exclusions classified | `6/6` |
| Structural manifest entries evaluated | `465` |
| Entries outside current shared/instance/exclusion lists | `36` |
| Explicit disposition of those gaps | `36/36` |
| Unknown default | `denied` |
| Equal-specificity conflicting rule | `0` by this contract; future parser must reject any introduced conflict |
| Product/template consumer writes | `denied` |
| Existence-dependent class fallback | `denied` |

P01-T07 must execute these oracles against the real resolver. This T01 result is a reviewed design oracle, not runtime proof.

## Remaining Owners

- **P01-T02:** version root/context fields and source of each value, including the binding exception.
- **P01-T03:** define read versus write resolution results and missing-resource semantics.
- **P01-T04:** implement normalization, containment and reparse defenses.
- **P01-T05:** implement trusted product discovery and integrity failure behavior.
- **P01-T06:** implement explicit legacy mode and binding conflicts without absence fallback.
- **P01-T07:** execute positive/negative resolver matrix and cross-consumer conformance.
- **P01-T08:** version the accepted interface and hand off to P02-P04.
- **P06:** choose the minimal shipping subset and physical paths inside InstallRoot.

## Input Hashes

```text
migracion/fases/P01-layout-y-resolucion.md d05ebe5f105a3e1550e736cb54d6e737b857e69b281eae2e445e01c5d8a82659
migracion/ARQUITECTURA-CONTRATOS.md 71abf7621fa4f23a69c51fcb74900930f0f97a4dc0d032419677c1a183007818
migracion/REQUISITOS.md 772c2231c9372f04c5ff4a71c8571f35fbc9e2a6ae7ace3075e16f10c42990f2
migracion/FUENTES-DECISIONES.md bcc47bfe6540cdc36ba440a89167d4eb135577f72d2641a4aae0533dc24997c9
SHARED_MANIFEST.yaml f089ffc8c2cad9433da31062f3823034b52ab9f8e5bf1e26ccfe0f6b7676f468
orquestador/harness-manifest.txt 781fa13ded83acc04e7f39d3721d8b476d920b1fb2f41ac38fa09436b2ab56bd
orquestador/sdd/progress/evidence/P00-T02-resource-inventory.md 2e60eca6a87bae644dd33e99e6e3a91d98763fbf5b36c62b025eb785d695e638
orquestador/sdd/progress/evidence/P00-T05-blocking-decisions.md 8b0b3e8cf05cb549eccd1cd333d5a03036ab1eef68ef586a6e3488422ae6b015
orquestador/sdd/progress/evidence/P00-T07-independent-review.md 61e7917655a524027e80e983a3872dacab3f64155752bbed32a233355c2f2b80
orquestador/sdd/progress/evidence/P00-T08-final-handoff.md c968f045bf66c24d00e80176db04ea489b80e267093a5e293e50a59602b8b69e
```

## Final Validation

- Independent recalculation from the two manifests found `465` structural entries and exactly `36` entries outside current shared/instance/exclusion selectors.
- The explicit T01 disposition set matched those `36` entries with zero missing and zero extra paths.
- Matrix ID counts are S=`21`, I=`18` including I00 and X=`6`.
- `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validate-harness.ps1 -RunNegativeTests` returned exit code `0`; all nested current-Harness validators passed.
- Soft context warnings remained below hard limits: `leader_light=2779/2600` with hard `5200`; `runtime_reentry=1869/1600` with hard `3200`.
- P01-V01 through P01-V06 remain `not_run`; the resolver and fixtures do not exist yet.

## Implementer Handoff

Review must verify the counts and precedence without editing this file. If accepted, P01-T02 receives the canonical classes, root contract, gap dispositions and unresolved executable owners above. P01-T02 requires a new exact approval; `P01-T01-LAYOUT-019` does not authorize it.

Review result: accepted with findings in `orquestador/sdd/progress/evidence/P01-T01-review.md`. No product or runtime PASS is implied.
