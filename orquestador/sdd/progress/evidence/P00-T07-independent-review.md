# Evidence - P00-T07 Independent Documentary Review

```yaml
evidence_id: E-P00-T07-001
cycle_id: C-001
slice_id: P00-T07
agent_id: A-P00-R01
role: reviewer
execution_mode: simulated_roles
independent_process: false
approval_id: P00-T07-EXEC-017
action_type: documentary_review
summary: "Review P00-T01 through T06 against R01-R18, primary samples, decisions and fixture design."
result: completed_with_findings
created_at: "2026-09-09"
```

## Review Boundary

The reviewer role was simulated and serialized because no real subagent facility was available. It did not edit product code, schemas, manifests, CLI, MCP or fixture trees. This is a traceable documentary review, not proof of independent-process review required for a product release.

Primary samples were checked in addition to prior evidence: binding/version authorities, shared manifest counts, five writer symbols, current CLI help, approval plumbing, MCP process-global context, schema defects and existing fixture validator behavior.

## Findings

### Critical

1. **P00-F01, authority conflict remains open.** `PROJECT_BINDING.yaml` and progress state say `source_template`; `orquestador/memory/memory-registry.yaml` says `bound`. A consumer/runtime must not choose the convenient value. P00-T08 must publish a formal precedence decision for this source repository and keep correction of the stale contract explicit.
2. **P00-F02, current contract schemas are not reliable validity oracles.** The legacy binding declares Harness `0.17.1` while its schema requires `0.17.0`; the progress-state schema contains literal `` `n `` sequences. They block executable legacy-intact/corrupt-state fixture acceptance until repaired or versioned.

### High

3. **P00-F03, R18 independent review is not demonstrated.** This reviewer is a simulated role in the same process. T07 is complete with findings as allowed by P00, but no release may cite it as independent review evidence.
4. **P00-F04, central product behavior is unimplemented.** `hebrinex.binding@1`, three-root resolver, central request/result/journal, catalog, MSI, offline payload and lifecycle tests remain `not_run`. This is expected at P00, but only documentary gates can close.
5. **P00-F05, current approval enforcement is incomplete across CLI branches.** The stable command gateway validates `ApprovalId`, but several write-capable CLI operations do not accept it directly. Procedural approval cannot be represented as runtime proof for R06.

### Medium

6. **P00-F06, manifest and path maps are not one executable authority.** `SHARED_MANIFEST.yaml` documents 21 shared directories, one instance directory, 17 mappings and six exclusions, but bootstrap/update still use the legacy structural manifest and mappings are duplicated across PowerShell and MCP.
7. **P00-F07, MCP packaging and isolation remain blocked.** Direct `zod` use is transitively supplied, `ROOT` and assumed role are process-global, the default Claude backend is absent locally and offline packaging is unproven.
8. **P00-F08, fixture checks are presently structural.** Existing fixture validation is mainly regex-based. The T06 central-binding designs must be consumed by real schema/parser/operation tests before any runtime PASS.
9. **P00-F09, live context tracking approaches a hard limit.** After T06, `runtime_reentry` was `2937/1600` against hard `3200`. T07 compacts closed-agent detail from the live registry while retaining IDs and records in task graph, audit and evidence.

## Task Review

| Task | Reviewer result | Basis and limitation |
|---|---|---|
| P00-T01 | complete with open discrepancies | Session/root/version/role/approval scope recorded; B01 and B02 intentionally unresolved. |
| P00-T02 | complete with findings | Inventory covers `21/1/17/6`; sampled writer symbols and manifest content support D01-D06. No central resolver exists. |
| P00-T03 | complete with warnings | Live help confirms stable0.5 and 17 commands; dedicated and aggregate validators passed. Dispatch coverage and direct ApprovalId gaps remain. |
| P00-T04 | decision accepted with blockers | On-demand core, optional session-scoped MCP, file authority, no database/daemon/new dependency are supported by current topology. Packaging/isolation are not proven. |
| P00-T05 | decision register complete | Narrow x64/pwsh candidate, API line 1, binding v1 boundary and blocking experiments are explicit. No platform is certified. |
| P00-T06 | design complete with blockers | Six synthetic scenario groups and three contradictions are specified. No fixture tree or execution exists. |

## R01-R18 Coverage Matrix

No requirement is orphaned: each has P00 evidence and/or an explicit later owner. `covered` below means documentary traceability only unless a runtime result is named.

| Req | P00 evidence/status | Remaining owner and test |
|---|---|---|
| R01 | T02 classifies shared/instance resources; T06 new-project oracle forbids engine copy. Design only. | P01/P04/P06; T01.1/T04.1/T06.1 not_run. |
| R02 | T02 records conflated roots and duplicated maps; T04/T05 preserve explicit per-invocation context. Design only. | P01/P02; resolver containment/ACL tests not_run. |
| R03 | T01 identifies authority conflict; T05 fixes binding-v1 boundary; T06 covers absent/moved/duplicate/incompatible cases. Blocked by F01/F02. | P01/P04/P05/P07; real binding tests not_run. |
| R04 | T04 rejects database/global service; T06 duplicate-copy oracle snapshots both projects/catalog. Design only. | P02/P04; isolation/reconcile tests not_run. |
| R05 | T06 legacy-intact/drift fixtures require CheckOnly, preservation and conflict plan. Design only. | P05/P07; migration/restore tests not_run. |
| R06 | T03 observes approval/gateway behavior and direct CLI gaps; T04 retains approval/file authority. Partial current-Harness evidence. | P02/P04; central replay/scope/hash tests not_run. |
| R07 | T04 chooses locks/journal/files; T06 requires unchanged snapshots on conflict/corruption. Design only. | P02/P05/P07; failure-injection/recovery not_run. |
| R08 | T01-T07 record separate role IDs, simulated execution and detractor passes. Enforcement validators pass for current Harness. | P03 host/capability matrix; true process independence not proven. |
| R09 | T01-T07 use task-scoped reads and measured budgets; warnings and hard limits are retained. Partial current-Harness evidence. | P03/T08 benchmark and total-context telemetry not_run. |
| R10 | Every P00 evidence file ends with a persistent next action; state/task graph/audit reconstruct progress. | P00-V04 and P03/T08 cold-handoff tests not_run. |
| R11 | T02 inventories host shims; T04 records MCP limits and missing backend. Design/observation only. | P03/P04 adapter capability matrix not_run. |
| R12 | T05 refuses invented performance claims and assigns pre-frozen benchmark work. | P03/P08 corpus/cost/quality benchmark not_run. |
| R13 | T04 inventories dependencies; T05 makes Node optional and assigns offline packaging experiments. | P06/P09 offline VM/license/runtime tests not_run. |
| R14 | T05 fixes only a Windows x64/pwsh validation candidate and explicitly denies MSI support claims. | P06 reproducible build/clean VM/launcher not_run. |
| R15 | T02 classifies persistent instance data; T04 separates product process from file authority. Lifecycle remains design only. | P07/P09 upgrade/repair/uninstall/restore not_run. |
| R16 | T02 excludes personal/host/dependency data; T06 bans secrets and path escapes and specifies guarded cleanup. | P01/P02/P05-P07 real containment/integrity/privilege tests not_run. |
| R17 | T01-T07 maintain evidence, audit, gates, exact outcomes and failed-attempt history. Central result/journal remains absent. | P01-P04/P08-P09 structured protocol tests not_run. |
| R18 | T07 supplies full documentary matrix and open findings; simulated review limitation is explicit. Not satisfied for release. | T08 cold handoff plus P08/P09 independent release evidence not_run. |

## P00 Verification Matrix

| Verification | Status | Reviewer conclusion |
|---|---|---|
| P00-V01 repeat read inventory/hashes | not_run | Input hashes exist per evidence, but no second complete inventory comparison was executed. |
| P00-V02 three contradictory bindings | reviewed_design_simulated | T06 provides independent ID, moved-root and duplicate-copy preimages; no real reviewer process or runtime fixture execution occurred. |
| P00-V03 five real writer traces | pass_documentary | T02 lists five symbols/destinations and T07 sampled the named primary symbols. This does not prove the future resolver. |
| P00-V04 cold handoff to another agent | not_run | T08 must publish a cold handoff; this same-process review cannot prove no-chat reconstruction. |

No `not_run` result is promoted to `pass`.

## Detractor and Recommendation

The T07 detractor accepts the review write-set and registry compaction, but rejects any statement that P00 proves product support, implementation or independent release review.

Recommendation: proceed to P00-T08 only for documentary gate publication and cold-handoff preparation. T08 must:

1. publish formal authority/precedence decisions for F01/F02 without silently editing product contracts;
2. retain all unresolved implementation and release tests as blockers or `not_run`;
3. close agents/locks and validate the final tracking tree;
4. mark P00 as documentary completion with open downstream blockers, not product acceptance;
5. require a new approval before P01 implementation, Git operations or any external effect.

## Validation Evidence

- Live `registry.yaml` was compacted to 3,211 characters. Closed agent IDs remain listed there; complete role/task/result records remain in task graph, audit and T01-T06 evidence.
- Aggregate `scripts/validate-harness.ps1 -RunNegativeTests` returned exit `0` after compaction. Release, stable CLI, bootstrap, bound update/backups/restore, agents, security, migration, existing fixtures, gateway, state machine and agent runtime passed.
- Context after compaction: `leader_light 3177/2600` (hard `5200`) and `runtime_reentry 2267/1600` (hard `3200`). Both remain soft warnings with restored hard-limit margin.
- Migration state parsed; 51 audit events parsed with unique IDs before final T07 records.
- `git diff --check` returned exit `0`; locks remain empty except the retained `_README.md` marker.
- No product/schema/fixture implementation, network, installation, commit or push occurred.

## Input Snapshot

Key SHA-256 values:

```text
444950D3A526B819D655EC981FC37CB3BB64CD2BA54BB1CD364083519EFD7539  migracion/fases/P00-baseline-y-contrato.md
772C2231C9372F04C5FF4A71C8571F35FBC9E2A6AE7ACE3075E16F10C42990F2  migracion/REQUISITOS.md
F089FFC8C2CAD9433DA31062F3823034B52AB9F8E5BF1E26CCFE0F6B7676F468  SHARED_MANIFEST.yaml
891A1C88ACC28D9B0A8EF9BABCF2A7A13D8EFA83EC90132D29B2EBBF841DABB4  PROJECT_BINDING.yaml
ECF5CCDC10D65A459E661953E9443FBD96ED8F02CF6C163CA10EA8C4C06A876B  orquestador/memory/memory-registry.yaml
B79982CC3E9C70B066FA04A34A82F0CBC530C096BDC705054D6ECD581E5AA16F  orquestador/policies/schemas/project-binding.schema.yaml
8D5377C0EBFC1203D155E06DE1D52019F93516DA9E22AB4CC29942AC9B51069B  orquestador/sdd/progress/schemas/state.schema.yaml
31AA08FEF1C53AF56910E7F68C226EC4ED4DBA0037D387ED2A155928E8F9B7D0  scripts/hebrinex.ps1
836FE551D84BA0CF661122EF10AF2912149B9270C6FF2DCA2DF065CF58A2698C  mcp/server.mjs
289DE58C255098A987B2E7155DB785425EE2F752C921EEF1119F3049F87F1A02  orquestador/sdd/progress/evidence/P00-T01-session-contract.md
2E60ECA6A87BAE644DD33E99E6E3A91D98763FBF5B36C62B025EB785D695E638  orquestador/sdd/progress/evidence/P00-T02-resource-inventory.md
F2BF40F7B2B858A97C78AE98FBC55C296026DA6D3D84CE1D8656FC6D981BA353  orquestador/sdd/progress/evidence/P00-T03-cli-baseline.md
745ECE6986EA4114A76EF117B325BDCCAFAC82E680C35DD81EF9E1363713B388  orquestador/sdd/progress/evidence/P00-T04-service-topology-decision.md
8B0B3E8CF05CB549ECCD1CD333D5A03036AB1EEF68EF586A6E3488422AE6B015  orquestador/sdd/progress/evidence/P00-T05-blocking-decisions.md
9E06D0CBED076E25C67E2AB80FAA1C997AFC40B385F8EEF12C0FC189151688A2  orquestador/sdd/progress/evidence/P00-T06-fixture-design.md
```

## Handoff

P00-T07 is complete with open findings. The next and final P00 task is P00-T08, limited to gates, formal decisions, final report and cold handoff. It cannot implement fixes or authorize P01.
