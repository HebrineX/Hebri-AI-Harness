# Deploy Migration Checklist

```yaml
checklist_id: DPL-YYYYMMDD-001
cycle_id: C-000
scope:
  artifact_target: ""
  environment: local # local | ci | staging | production | unknown
sources:
  scripts: []
  workflows: []
  docs: []
  logs: []
  commits: []
checks:
  source_and_destination_declared: false
  commands_declared: false
  environment_declared: false
  result_evidence_present: false
  rollback_declared: false
  poc_vs_production_separated: false
  changelog_version_mapped: false
gaps: []
result: pending # pass | blocked | fail
blocking_reason: ""
```
