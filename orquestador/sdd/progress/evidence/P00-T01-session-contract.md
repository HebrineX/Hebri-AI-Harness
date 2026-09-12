# Evidence - P00-T01 Session Contract

```yaml
evidence_id: E-P00-T01-001
cycle_id: C-001
slice_id: P00-T01
agent_id: A-P00-L01
role: leader
execution_mode: simulated
approval_id: P00-T01-WRITE-011
action_type: edit
summary: "Reconstruct and persist the source-template session contract for P00-T01."
inputs:
  files_read:
    - AGENTS.md
    - PROJECT_BINDING.yaml
    - HARNESS_VERSION
    - SHARED_MANIFEST.yaml
    - orquestador/memory/local/session-pin.md
    - orquestador/memory/memory-registry.yaml
    - orquestador/memory/memory-routing.yaml
    - orquestador/context-budget.yaml
    - orquestador/entrypoints/compactation-recovery.md
    - orquestador/sdd/progress/state.yaml
    - orquestador/sdd/progress/registry.yaml
    - migracion/README.md
    - migracion/ROADMAP.md
    - migracion/REQUISITOS.md
    - migracion/FUENTES-DECISIONES.md
    - migracion/fases/P00-baseline-y-contrato.md
  files_written:
    - orquestador/sdd/progress/state.yaml
    - orquestador/sdd/progress/registry.yaml
    - orquestador/sdd/progress/cycles/C-001/gate-log.yaml
    - orquestador/sdd/progress/cycles/C-001/audit.jsonl
    - orquestador/sdd/progress/cycles/C-001/task-graph.yaml
    - orquestador/sdd/progress/cycles/C-001/detractor-senior.md
    - orquestador/sdd/progress/evidence/P00-T01-session-contract.md
    - migracion/operacion/state.json
  command: "apply_patch; validate-harness.ps1 -RunNegativeTests; git diff --check"
  tool: "Codex apply_patch and local validators"
outputs:
  exit_code: 0
  result: pass
  stdout_summary: "Harness validation passed. Soft warnings: leader_light 2930/2600 and runtime_reentry 2021/1600; both remain below their 2x hard limits. JSON, JSONL and git diff checks passed."
  stderr_summary: ""
  artifacts:
    - orquestador/sdd/progress/cycles/C-001/
    - orquestador/sdd/progress/evidence/P00-T01-session-contract.md
risk: medium
created_at: "2026-09-08"
```

## Reconstructed Contract

- Harness detected: yes; source repository authority
- Harness path: `C:/Ordenado_Hebri/01_Proyectos/Harness_Tools/Hebri-Ai-Harness`
- Project root: `C:/Ordenado_Hebri/01_Proyectos/Harness_Tools/Hebri-Ai-Harness`
- Binding: `source_template`
- Version: `0.17.1`
- Memory route: `compactation_recovery`
- Context budget: `leader_light`; latest validator observation `2503/2600`
- Mode: `automatico`
- Chat role: interpreter
- Leader: visible, simulated as `A-P00-L01`
- Active agents: 1/5 total, 0/4 subagents
- Cycle/phase/slice: `C-001 / P00 / P00-T01`
- Baseline Git revision: `f319b4bdf0bdc3c4a9b66db4f0e8787512912a04`
- Approval required before effects: yes

## Observed Discrepancies

1. `PROJECT_BINDING.yaml` and progress state declare `source_template`; `orquestador/memory/memory-registry.yaml` declares `bound`. The conflict remains open and was not resolved by inference.
2. `orquestador/sdd/progress/schemas/state.schema.yaml` contains literal `` `n `` sequences on lines that appear intended as separate YAML entries. P00-T01 records the observation but does not edit the schema.
3. The prior progress state had a pending session contract, no visible leader and no active cycle; it referenced historical phase-8 evidence, not evidence for P00.

## Scope Decision

The operator approved source-template maintenance only for the exact P00-T01 write-set. This does not authorize product changes, installation, consumer migration, fixtures, network access, Git commit/push or resolution of the binding discrepancy.

## Next Action

P00-T01 is complete. Prepare one consolidated preflight for P00-T02, using task-scoped reads because the active-cycle state pushes `leader_light` and `runtime_reentry` above their soft budgets. Do not execute P00-T02 under this approval.
