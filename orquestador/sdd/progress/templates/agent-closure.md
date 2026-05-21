# Agent Closure

Antes de cerrar un ciclo, cada agente abierto debe tener cierre explicito.

```yaml
closure_id: CL-001
cycle_id: C-001
agent_id: A-001
role: explorer | spec_author | implementer | reviewer | worker | leader
status: done | blocked | cancelled
artifacts: []
files_read: []
files_modified: []
locks_owned: []
locks_released: []
open_risks: []
handoff_to: leader | reviewer | human | none
closed_at: ""
```

## Regla P0

No se puede pasar `G6_agent_closure_complete` si existe un agente activo, sin handoff o sin cierre registrado.
