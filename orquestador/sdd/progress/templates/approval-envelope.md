# Approval Envelope

```yaml
approval_id: APR-001
cycle_id: C-001
requested_by: A-000
role: leader
status: pending | approved | executed | closed | expired | invalidated_scope_changed
action_type: edit_files | run_command | spawn_agent | network | git_local | git_remote | change_sdd_state | release_lock
exact_action: ""
cwd: ""
project_root: ""
harness_path: ""
binding_status: source_template | bound | missing | mismatch
external_write_scope: []
write_set: []
read_set: []
command: ""
tools: []
risk: low | medium | high
verification: ""
invalidates_if:
  - command_changes
  - cwd_changes
  - project_root_changes
  - harness_path_changes
  - binding_status_changes
  - write_set_changes
  - read_set_changes
  - external_write_scope_changes
  - network_or_git_scope_changes
  - risk_changes
expires_at: ""
human_decision: pending | approved | denied
approved_text: "SI"
evidence_ref: ""
```

## Regla

El `SI` aprueba solo este envelope. Cambiar comando, scope, cwd, project_root, harness_path, binding, write-set, red, git, scope externo o riesgo invalida la aprobacion y requiere un nuevo envelope.

Commit y push son envelopes distintos. Una aprobacion de commit no cubre push.

Una aprobacion de una sesion anterior expira despues de compactacion, cambio de cwd o cambio de proyecto, salvo revalidacion explicita del operador.
