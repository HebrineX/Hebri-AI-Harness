# Evidence Schema

Toda evidencia operativa debe permitir reconstruir que paso, quien lo pidio, que se aprobo, que se ejecuto y que resultado tuvo.

## Campos Minimos

```yaml
evidence_id: E-001
cycle_id: C-001
slice_id: ""
agent_id: A-001
role: leader | explorer | spec_author | implementer | reviewer | worker | interpreter
approval_id: APR-001 | none
action_type: read | edit | command | network | git | tool | handoff | gate | closure
summary: ""
inputs:
  files_read: []
  files_written: []
  command: ""
  tool: ""
outputs:
  exit_code: null
  result: pass | fail | blocked | not_run
  stdout_summary: ""
  stderr_summary: ""
  artifacts: []
risk: low | medium | high
created_at: ""
```

## Regla

Si una accion cambia estado o tiene costo/riesgo, debe referenciar `approval_id`. Si no hay aprobacion requerida, usar `approval_id: none` y justificarlo en `summary`.
