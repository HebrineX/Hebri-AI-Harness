# Re-entry Checklist

Usar cuando una sesion fue compactada, resumida, retomada desde logs, cambió el cwd o hay dudas sobre el proyecto activo.

```yaml
reentry_id: RE-001
cycle_id: C-001
reason: compactation | resumed_session | cwd_changed | project_changed | log_debug | unknown
checked_at: ""
project_root: ""
harness_path: ""
binding_status: source_template | bound | missing | mismatch
session_contract_declared: false
state_read: false
registry_read: false
progress_read: false
active_cycle_confirmed: false
open_agents_reviewed: false
open_locks_reviewed: false
handoffs_reviewed: false
old_approvals_expired: false
operator_revalidated_scope: false
result: pass | blocked
blocking_reason: ""
```

## Regla

No se continua una tarea con escritura, comando, red, git, subagentes con efecto o cambio SDD despues de re-entry hasta que este checklist resulte `pass`.

El resumen de compactacion es contexto auxiliar, no autoridad operativa.
