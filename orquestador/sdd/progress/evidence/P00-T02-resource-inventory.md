# Evidence - P00-T02 Resource Inventory

```yaml
evidence_id: E-P00-T02-001
cycle_id: C-001
slice_id: P00-T02
agent_id: A-P00-I01
role: executor
profile: worker
declared_task_role: implementer
execution_mode: simulated
approval_id: P00-T02-EXEC-012
action_type: analysis_and_documentation
summary: "Inventory shared, instance and project-local resources against scripts, MCP and hooks."
result: pass_with_open_discrepancies
created_at: "2026-09-08"
```

## Scope and Terms

- Current authority inspected: source repository at `C:/Ordenado_Hebri/01_Proyectos/Harness_Tools/Hebri-Ai-Harness`, binding `source_template`, version `0.17.1`.
- `Root` means the current harness root. In this source checkout all canonical `instance/*` targets are absent; only `instance/README.md` exists. Therefore current resolvers fall back to legacy paths under `Root`.
- A bound consumer root is currently `<ProjectRoot>/.hebrinex`; its paths are inferred from code because no consumer fixture was executed in T02.
- Future classes follow R02: immutable product payload under `InstallRoot`, per-project mutable data under `InstanceRoot`, and host shims/configuration under `ProjectRoot`.
- Status `observed/inferred` means current behavior was read from code while the future class is a migration target, not implemented proof.

## Reference Keys

- `SM`: `SHARED_MANIFEST.yaml:9-104`.
- `COPY-B`: `scripts/hebrinex.ps1:337` (`Copy-HarnessManifestToBoundRoot`), write at line 356.
- `COPY-U`: `scripts/hebrinex.ps1:686` (`Copy-HarnessManifestToExistingBoundRoot`), write at line 707.
- `MAP-PS`: `scripts/lib/hebri-common.psm1:6` (`Get-HebriInstanceRelativePath`) and line 35 (`Resolve-HarnessPath`).
- `MAP-CLI`: `scripts/hebrinex.ps1:53` (`Resolve-BoundHarnessPath`) and line 71 (`Resolve-BoundCanonicalPath`).
- `MAP-MCP`: `mcp/server.mjs:134` (`getInstanceRelativePath`) and line 166 (`resolveHarnessPath`).
- `LEGACY-COPY`: `scripts/hebrinex.ps1:714` (`Copy-BoundLegacyFileToCanonical`), line 724 (`Copy-BoundLegacyTreeToCanonical`) and line 746 (`Copy-BoundLegacyInstanceStateToCanonical`).

## Shared Resources (21/21)

All rows are declared by `SM`. `COPY-B` and `COPY-U` are both readers of source payload and writers of the current bound copy. They enumerate `orquestador/harness-manifest.txt`, not `SHARED_MANIFEST.yaml`; this difference is recorded as D01.

| ID | Resource | Reader observed | Writer observed | Current root | Future class | Status |
|---|---|---|---|---|---|---|
| S01 | `agents` | instruction builder reads role sources (`scripts/build-instructions.ps1:100-131`); `COPY-B`/`COPY-U` | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707`; generated projections `scripts/build-instructions.ps1:187-195` | `Root/agents`; copied to bound root | `InstallRoot/shared/agents` | observed/inferred |
| S02 | `mcp` | daemon loads modules/config (`mcp/server.mjs:9-20`; `mcp/agent-backends.mjs:59-81`); `COPY-B`/`COPY-U` | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707`; no direct daemon product writer | `Root/mcp`, except mapped local override | `InstallRoot/shared/mcp` with local override in `InstanceRoot` | observed/inferred |
| S03 | `prompts` | instruction builder reads prompt blocks (`scripts/build-instructions.ps1:100-115`); `COPY-B`/`COPY-U` | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707`; generated outputs `scripts/build-instructions.ps1:187-195` | `Root/prompts` | `InstallRoot/shared/prompts` | observed/inferred |
| S04 | `scripts` | CLI/MCP invoke scripts (`scripts/hebrinex.ps1:38`; `mcp/server.mjs:52-62`); `COPY-B`/`COPY-U` | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707`; source scripts otherwise maintained in product | `Root/scripts` | `InstallRoot/shared/scripts` | observed/inferred |
| S05 | `orquestador/adapters` | drift checks consume adapters (`init.sh:137-139`); `COPY-B`/`COPY-U` | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707` | `Root/orquestador/adapters` | `InstallRoot/shared/orquestador/adapters` | observed/inferred |
| S06 | `orquestador/agents` | agent runtime reads registries/contracts (`scripts/agent-runtime.ps1:56-80`); `COPY-B`/`COPY-U` | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707`; builder writes generated contracts/registry (`scripts/build-instructions.ps1:100-115,187-195`) | `Root/orquestador/agents` | `InstallRoot/shared/orquestador/agents` | observed/inferred |
| S07 | `orquestador/entrypoints` | budget profiles reference entrypoints (`scripts/hebrinex.ps1:165-169`); `COPY-B`/`COPY-U` | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707` | `Root/orquestador/entrypoints` | `InstallRoot/shared/orquestador/entrypoints` | observed/inferred |
| S08 | `orquestador/instruction-builder` | builder reads registry/fragments (`scripts/build-instructions.ps1:11-18`); `COPY-B`/`COPY-U` | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707` | `Root/orquestador/instruction-builder` | `InstallRoot/shared/orquestador/instruction-builder` | observed/inferred |
| S09 | `orquestador/integrations` | host installer reads generated templates (`scripts/install-host-integrations.ps1:24-57`); `COPY-B`/`COPY-U` | builder writes generated integration files (`scripts/build-instructions.ps1:127-195`); bound-copy writers `scripts/hebrinex.ps1:337/356,686/707` | `Root/orquestador/integrations` | `InstallRoot/shared/orquestador/integrations` | observed/inferred |
| S10 | `orquestador/method` | session contract and CLI profiles read methods (`mcp/server.mjs:461-540`; `init.sh:165`); `COPY-B`/`COPY-U` | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707` | `Root/orquestador/method` | `InstallRoot/shared/orquestador/method` | observed/inferred |
| S11 | `orquestador/migration/contracts` | migration/bootstrap services read templates/contracts (`scripts/hebrinex.ps1:553-582`; `scripts/migrate-harness.ps1:195-230`) | shared copy `scripts/hebrinex.ps1:337/356,686/707`; post-migration instance writer `scripts/hebrinex.ps1:553/582,777/806` | `Root/orquestador/migration/contracts`; applied contract is mapped exception | `InstallRoot/shared/.../contracts`, except applied contract in `InstanceRoot` | observed/inferred |
| S12 | `orquestador/migration/versions` | migration validator/routes read versions (`scripts/validate-harness.ps1:530`); `COPY-B`/`COPY-U` | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707` | `Root/orquestador/migration/versions` | `InstallRoot/shared/orquestador/migration/versions` | observed/inferred |
| S13 | `orquestador/policies` | validators and runtime consume policy files through product paths; `COPY-B`/`COPY-U` | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707` | `Root/orquestador/policies` | `InstallRoot/shared/orquestador/policies` | observed/inferred |
| S14 | `orquestador/portability` | initialization validates portability files (`init.sh:135-139`); `COPY-B`/`COPY-U` | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707` | `Root/orquestador/portability` | `InstallRoot/shared/orquestador/portability` | observed/inferred |
| S15 | `orquestador/runtime/schemas` | initialization/validators read schemas (`init.sh:144-147`; `scripts/validate-harness.ps1:550-555`) | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707` | `Root/orquestador/runtime/schemas` | `InstallRoot/shared/orquestador/runtime/schemas` | observed/inferred |
| S16 | `orquestador/runtime/templates` | initialization/validators read templates (`init.sh:146-147`; `scripts/validate-harness.ps1:552-555`) | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707` | `Root/orquestador/runtime/templates` | `InstallRoot/shared/orquestador/runtime/templates` | observed/inferred |
| S17 | `orquestador/sdd/progress/schemas` | validators read schemas; mapping explicitly exempts them (`scripts/lib/hebri-common.psm1:17`) | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707` | `Root/orquestador/sdd/progress/schemas` | `InstallRoot/shared/orquestador/sdd/progress/schemas` | observed/inferred |
| S18 | `orquestador/sdd/progress/templates` | mapping explicitly exempts templates (`scripts/lib/hebri-common.psm1:17`); `COPY-B`/`COPY-U` | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707` | `Root/orquestador/sdd/progress/templates` | `InstallRoot/shared/orquestador/sdd/progress/templates` | observed/inferred |
| S19 | `orquestador/sdd/specs/_template` | mapping explicitly exempts the template (`scripts/lib/hebri-common.psm1:20`); `COPY-B`/`COPY-U` | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707` | `Root/orquestador/sdd/specs/_template` | `InstallRoot/shared/orquestador/sdd/specs/_template` | observed/inferred |
| S20 | `orquestador/security` | initialization validates security registries (`init.sh:84-85`); `COPY-B`/`COPY-U` | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707` | `Root/orquestador/security` | `InstallRoot/shared/orquestador/security` | observed/inferred |
| S21 | `orquestador/testing` | validators consume test assets; `COPY-B`/`COPY-U` | bound-copy writers `scripts/hebrinex.ps1:337/356,686/707` | `Root/orquestador/testing` | `InstallRoot/shared/orquestador/testing` | observed/inferred |

## Instance Root and Mapped Resources (1/1 + 17/17)

| ID | Resource -> canonical path | Reader observed | Writer observed | Current root | Future class | Status |
|---|---|---|---|---|---|---|
| I00 | `instance` | declared by `SHARED_MANIFEST.yaml:31-32`; resolvers `MAP-PS`, `MAP-CLI`, `MAP-MCP` | bootstrap/update canonical writers below; no shared-cache writer allowed by `SHARED_MANIFEST.yaml:101-104` | `Root/instance` contains only `README.md` in source | `InstanceRoot` | observed/inferred |
| I01 | `PROJECT_BINDING.yaml` -> `instance/PROJECT_BINDING.yaml` | `MAP-PS`; CLI reads at `scripts/hebrinex.ps1:889,934`; MCP session contract at `mcp/server.mjs:461-485` through `MAP-MCP` | `Write-BoundProjectBinding` (`scripts/hebrinex.ps1:379/400`); `Update-BoundProjectBindingVersion` (`scripts/hebrinex.ps1:765/773`) | source uses legacy `Root/PROJECT_BINDING.yaml`; bound canonical preferred | `InstanceRoot/PROJECT_BINDING.yaml` | observed/inferred |
| I02 | `PROGRESS.md` -> `instance/PROGRESS.md` | mapping at `scripts/lib/hebri-common.psm1:10`; no semantic reader found in scoped search | `LEGACY-COPY` invocation `scripts/hebrinex.ps1:748` | legacy fallback under `Root/PROGRESS.md` | `InstanceRoot/PROGRESS.md` | observed/inferred |
| I03 | `orquestador/context` -> `instance/context` | mapping at `scripts/lib/hebri-common.psm1:11-12` and `MAP-MCP` | `LEGACY-COPY` tree invocation `scripts/hebrinex.ps1:753` | legacy fallback under `Root/orquestador/context` | `InstanceRoot/context` | observed/inferred |
| I04 | `orquestador/memory/memory-registry.yaml` -> `instance/memory/memory-registry.yaml` | budget/session readers `scripts/hebrinex.ps1:153-170`; MCP session reader `mcp/server.mjs:461-485` | `Update-BoundMemoryRegistry` (`scripts/hebrinex.ps1:435/441`); `LEGACY-COPY` at line 749 | source uses legacy path | `InstanceRoot/memory/memory-registry.yaml` | observed/inferred |
| I05 | `orquestador/memory/local` -> `instance/memory/local` | profile/session readers through `MAP-PS`; CLI budget references `scripts/hebrinex.ps1:154-170` | `Update-BoundActiveContract` (`scripts/hebrinex.ps1:444/466`); `LEGACY-COPY` loop at lines 754-755 | source uses legacy path | `InstanceRoot/memory/local` | observed/inferred |
| I06 | `orquestador/memory/project` -> `instance/memory/project` | `MAP-PS`/`MAP-MCP`; no task-specific semantic reader found | migration writer only: `LEGACY-COPY` loop `scripts/hebrinex.ps1:754-755` | source uses legacy path | `InstanceRoot/memory/project` | observed/inferred |
| I07 | `orquestador/memory/cycle` -> `instance/memory/cycle` | `MAP-PS`/`MAP-MCP`; no task-specific semantic reader found | migration writer only: `LEGACY-COPY` loop `scripts/hebrinex.ps1:754-755` | source uses legacy path | `InstanceRoot/memory/cycle` | observed/inferred |
| I08 | `orquestador/memory/daily` -> `instance/memory/daily` | `MAP-PS`/`MAP-MCP`; no task-specific semantic reader found | migration writer only: `LEGACY-COPY` loop `scripts/hebrinex.ps1:754-755` | source uses legacy path | `InstanceRoot/memory/daily` | observed/inferred |
| I09 | `orquestador/memory/complete` -> `instance/memory/complete` | `MAP-PS`/`MAP-MCP`; no task-specific semantic reader found | migration writer only: `LEGACY-COPY` loop `scripts/hebrinex.ps1:754-755` | source uses legacy path | `InstanceRoot/memory/complete` | observed/inferred |
| I10 | `orquestador/sdd/progress` -> `instance/sdd/progress` | CLI/state and MCP session/gate tools through `MAP-PS`/`MAP-MCP`; schemas/templates are shared exceptions (`scripts/lib/hebri-common.psm1:16-18`) | state writer `scripts/hebrinex.ps1:421/432`; approval writer `scripts/lib/hebri-common.psm1:182/224`; lock writers lines 353/402 and 412/430; regularizers `scripts/regularize-state.ps1:103-104`, `scripts/regularize-registry.ps1:88-89`; `LEGACY-COPY` line 757 | source uses legacy runtime tree | `InstanceRoot/sdd/progress`, excluding shared schemas/templates/readme | observed/inferred |
| I11 | `orquestador/sdd/specs` -> `instance/sdd/specs` | mapping `scripts/lib/hebri-common.psm1:19-21`; `_template` remains shared | migration writer only: `LEGACY-COPY` line 758 | source uses legacy path | `InstanceRoot/sdd/specs`, excluding `_template` | observed/inferred |
| I12 | `orquestador/migration/backups` -> `instance/migration/backups` | bootstrap/update/restore services through `MAP-CLI` | backup writers `scripts/hebrinex.ps1:531/549,641/674,682`; legacy migrator `scripts/migrate-harness.ps1:134/152/161`; `LEGACY-COPY` line 759 | source/legacy path unless canonical exists | `InstanceRoot/migration/backups` | observed/inferred |
| I13 | `orquestador/migration/contracts/post-migration-contract.yaml` -> `instance/migration/contracts/post-migration-contract.yaml` | `MAP-PS`/`MAP-CLI`/`MAP-MCP` | canonical writers `scripts/hebrinex.ps1:553/582,777/806`; flat legacy writer `scripts/migrate-harness.ps1:195/230` | source/legacy path unless canonical exists | `InstanceRoot/migration/contracts/post-migration-contract.yaml` | observed/inferred |
| I14 | `orquestador/migration/reports` -> `instance/migration/reports` | bootstrap/update/restore services through `MAP-CLI`; template stays shared | report writers `scripts/hebrinex.ps1:469/527,810/868,1155/1205`; flat legacy writer `scripts/migrate-harness.ps1:234/315`; `LEGACY-COPY` line 760 | source/legacy path unless canonical exists | `InstanceRoot/migration/reports`, excluding template | observed/inferred |
| I15 | `orquestador/runtime/gateway-rate.json` -> `instance/runtime/gateway-rate.json` | gateway through `MAP-PS` (`scripts/command-gateway.ps1:281-282`) | `Test-AndRecordApplyRate` writes via `Write-Utf8Text` (`scripts/command-gateway.ps1:281/310`); `LEGACY-COPY` line 750 | legacy fallback under `Root/orquestador/runtime` | `InstanceRoot/runtime/gateway-rate.json` | observed/inferred |
| I16 | `orquestador/runtime/claude` -> `instance/runtime/claude` | Claude reentry through `MAP-PS` (`scripts/claude-reentry.ps1:7-17`) | reentry brief writer `scripts/claude-reentry.ps1:35`; `LEGACY-COPY` line 761 | legacy fallback under `Root/orquestador/runtime/claude` | `InstanceRoot/runtime/claude` | observed/inferred |
| I17 | `mcp/agents-backend.local.yaml` -> `instance/mcp/agents-backend.local.yaml` | MCP backend loader prefers canonical then legacy (`mcp/agent-backends.mjs:59-81`) | migration writer only: `LEGACY-COPY` line 751; no configuration writer found | canonical preferred, legacy fallback | `InstanceRoot/mcp/agents-backend.local.yaml` | observed/inferred |

## ProjectRoot Host Outputs

These are not shared payload or instance state; they are generated/copied integration surfaces in the consumer project.

| ID | Resource | Reader | Writer with reference | Current root | Future class | Status |
|---|---|---|---|---|---|---|
| P01 | `CLAUDE.md` | Claude host | `scripts/install-claude-hooks.ps1:79`; alternate installer `scripts/install-host-integrations.ps1:24-29,68-74` | `ProjectRoot/CLAUDE.md` | `ProjectRoot` shim/instruction | observed |
| P02 | `.claude/settings.json` | Claude host | `scripts/install-claude-hooks.ps1:117-120` | `ProjectRoot/.claude/settings.json` | `ProjectRoot` host config | observed |
| P03 | `.claude/agents/*.md` | Claude host | `scripts/install-host-integrations.ps1:24-29,68-74` | `ProjectRoot/.claude/agents` | `ProjectRoot` host shim | observed |
| P04 | `.cursor/rules/hebrinex.mdc` | Cursor host | `scripts/install-host-integrations.ps1:31-35,68-74` | `ProjectRoot/.cursor/rules` | `ProjectRoot` host shim | observed |
| P05 | `.github/copilot-instructions.md` | Copilot host | `scripts/install-host-integrations.ps1:37-41,68-74` | `ProjectRoot/.github` | `ProjectRoot` host shim | observed |

## Excluded Resources (6/6)

| ID | Resource | Reader/writer evidence | Current root | Future class | Status |
|---|---|---|---|---|---|
| X01 | `.git` | excluded from copy by `scripts/hebrinex.ps1:1272`; Git owns writes, outside harness runtime | repository metadata | external/VCS, never shared payload | observed |
| X02 | `.codex` | exclusion predicate `scripts/hebrinex.ps1:330`; bootstrap negative `scripts/validate-bootstrap.ps1:85` | host-local metadata | external/host-local | observed |
| X03 | `mcp/node_modules` | MCP validator reads SDK at `scripts/validate-mcp.ps1:148`; CI writer is `npm ci` at `.github/workflows/ci.yml:76` | dependency install under source/CI workspace | build/runtime dependency cache, not payload sharing | observed |
| X04 | `infoHebri.md` | exclusion predicate `scripts/hebrinex.ps1:331`; validator `scripts/validate-harness.ps1:318,506` | forbidden in harness/bound copy | personal/local denied | observed |
| X05 | `infoHebriHarness.md` | declared exclusion `SHARED_MANIFEST.yaml:98`; no in-scope runtime reader/writer found | local-only if present | personal/local denied | observed |
| X06 | `.claude/settings.local.json` | declared exclusion `SHARED_MANIFEST.yaml:99`; no in-scope writer found | host-local project config | `ProjectRoot` local override, never shared | observed |

## Cross-check Findings

1. **D01 - manifest authority is not consumed uniformly (`observed`, open).** `SHARED_MANIFEST.yaml:7` requires consumers to read this manifest. Bootstrap/update instead enumerate `orquestador/harness-manifest.txt` in `scripts/hebrinex.ps1:337-338,586-588,686-691`. Validators check only selected declarations (`scripts/validate-harness.ps1:566-572`).
2. **D02 - instance mapping is duplicated (`observed`, open).** The same map exists in PowerShell (`scripts/lib/hebri-common.psm1:6-31`), CLI-local resolution (`scripts/hebrinex.ps1:42-78`) and MCP JavaScript (`mcp/server.mjs:134-170`). The manifest is declarative but is not the executable source of the map.
3. **D03 - current root selection is existence-dependent (`observed`, open).** `Resolve-HarnessPath` selects `instance/*` only when the mapped path exists, then falls back to the legacy path (`scripts/lib/hebri-common.psm1:40-45`; `mcp/server.mjs:166-170`). The source checkout has no mapped target beyond `instance/README.md`.
4. **D04 - two scripts bypass canonical instance resolution (`observed`, open).** `scripts/agent-runtime.ps1:12-14` joins `Root` directly. `scripts/migrate-harness.ps1:10-11` also uses a flat join while writing backups, reports and the applied contract (`:134-161,195-230,234-315`).
5. **D05 - root roles remain conflated (`observed`, open).** MCP has one process-global `ROOT` (`mcp/server.mjs:19-20`), and current CLI helpers receive one harness/bound root. No implemented request contract separates `InstallRoot`, `ProjectRoot` and `InstanceRoot`; that is future P01/P03 work under R02.
6. **D06 - host installers write ProjectRoot directly (`observed`, expected but future policy pending).** `install-claude-hooks.ps1` and `install-host-integrations.ps1` write host files at the supplied project root. P04 must preserve these as narrow shims/config, not recreate the shared payload.

## Five Writer Traces for P00-V03 Preparation

| Writer | Input resolution | Verified destination |
|---|---|---|
| `Write-BoundProjectBinding` (`scripts/hebrinex.ps1:379/400`) | `Resolve-BoundCanonicalPath` | `<BoundRoot>/instance/PROJECT_BINDING.yaml` |
| `Update-BoundState` (`scripts/hebrinex.ps1:421/432`) | read-compatible resolver + canonical writer | `<BoundRoot>/instance/sdd/progress/state.yaml` |
| `New-ApprovalEnvelope` (`scripts/lib/hebri-common.psm1:182/224`) | `Resolve-HarnessPath` over approvals dir | mapped path if it already exists, otherwise legacy fallback |
| `Test-AndRecordApplyRate` (`scripts/command-gateway.ps1:281/310`) | `Resolve-HarnessPath` | mapped rate file if present, otherwise legacy fallback |
| Claude reentry writer (`scripts/claude-reentry.ps1:7/35`) | `Resolve-HarnessPath` | mapped runtime/claude if present, otherwise legacy fallback |

## Verification and Limits

- Manifest coverage target: 21 shared directories, 1 instance directory, 17 mapped entries and 6 exclusions.
- Executed result: coverage check passed `21/1/17/6`; JSON and 15 JSONL entries parsed; `git diff --check` passed; `scripts/validate-harness.ps1 -RunNegativeTests` passed.
- Context warnings carried forward: `leader_light 3356/2600` (hard 5200) and `runtime_reentry 2446/1600` (hard 3200).
- Writer references include a file and a symbol or line for every writer claimed.
- No script, MCP module, hook, manifest, consumer fixture, network endpoint or Git state was changed by T02.
- No consumer, junction/symlink, installed service, daemon or MSI layout was executed; those outcomes remain `not_run`.
- D01-D06 are evidence for later phases, not fixes authorized by P00-T02.

## Handoff

P00-T02 is complete. The next sequential task is P00-T03: capture the existing CLI behavior and `stable0.5` compatibility oracle from implementation and tests.
