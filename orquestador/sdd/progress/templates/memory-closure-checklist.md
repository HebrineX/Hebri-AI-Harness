# Memory Closure Checklist

Usar antes de cerrar fase, slice, ciclo o sesion con trabajo operativo.

```yaml
schema: hebrinex.memory.closure_checklist
version: "0.1"
cycle_id: ""
status: pending
local:
  current_focus_updated: false
  active_contract_matches_session: false
  operator_hard_locks_recorded: false
daily:
  daily_memory_updated_or_not_applicable: false
  transient_logs_summarized: false
  stale_daily_context_removed_or_marked: false
cycle:
  state_yaml_updated: false
  registry_yaml_updated: false
  gates_and_evidence_linked: false
  open_agents_empty_or_blocked: false
  open_locks_empty_or_blocked: false
project:
  stable_decisions_promoted: false
  architecture_or_product_memory_updated_if_changed: false
  no_transient_debug_noise_promoted: false
complete:
  used: false
  approval_id: ""
  evidence_refs: []
result:
  pass: false
  gaps: []
```

No declarar `done` si local/daily/cycle/project no fueron evaluadas. La memoria completa no se carga para cerrar por comodidad.