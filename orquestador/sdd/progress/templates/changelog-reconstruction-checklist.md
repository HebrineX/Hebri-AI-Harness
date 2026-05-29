# Changelog Reconstruction Checklist

Usar antes de editar `CHANGELOG.md`, release notes o documentacion historica/versionada.

```yaml
checklist_id: CHG-YYYYMMDD-001
cycle_id: C-000
artifact_target: CHANGELOG.md
scope:
  from_version: ""
  to_version: ""
  release_name: ""
required_sources:
  changelog_md:
    path: CHANGELOG.md
    status: pending # pending | read | missing | not_applicable
  progress_md:
    path: PROGRESS.md
    status: pending
  state_yaml:
    path: orquestador/sdd/progress/state.yaml
    status: pending
  registry_yaml:
    path: orquestador/sdd/progress/registry.yaml
    status: pending
  registry_md:
    path: orquestador/sdd/progress/registry.md
    status: pending
  cycle_gate_logs:
    glob: orquestador/sdd/progress/cycles/**/gate-log.yaml
    status: pending
  cycle_final_reports:
    glob: orquestador/sdd/progress/cycles/**/final-report.md
    status: pending
  cycle_audit_trails:
    glob: orquestador/sdd/progress/cycles/**/audit.jsonl
    status: pending
  git_log:
    command: git log --oneline --decorate --date=short
    status: pending
  git_show_relevant:
    command: git show --stat <sha>
    status: pending
external_evidence:
  - id: ""
    description: ""
    status: pending # pending | read | missing | not_applicable
checks:
  facts_inferences_separated: false
  events_mapped_to_versions: false
  commits_mapped_to_events: false
  cycles_mapped_to_events: false
  ci_or_deploy_iterations_not_collapsed: false
  synthetic_versions_marked: false
  unmapped_events_listed: false
  contradictions_listed: false
  release_auditor_reviewed: false
result: pending # pass | blocked | fail
blocking_reason: ""
```

## Regla

Si `git log`, `PROGRESS.md` y al menos un registry existen, deben estar en `status: read` antes de escribir.
