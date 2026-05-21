# Approval Envelope

```yaml
approval_id: APR-001
cycle_id: C-001
requested_by: A-000
role: leader
action_type: edit_files | run_command | spawn_agent | network | git_local | git_remote | change_sdd_state | release_lock
exact_action: ""
cwd: ""
write_set: []
read_set: []
command: ""
tools: []
risk: low | medium | high
verification: ""
expires_at: ""
human_decision: pending | approved | denied
approved_text: "SI"
evidence_ref: ""
```

## Regla

El `SI` aprueba solo este envelope. Cambiar comando, scope, cwd, write-set, red, git o riesgo invalida la aprobacion y requiere un nuevo envelope.
