# Locks de Ownership

Crear un archivo `L-XXX.lock.md` antes de cualquier escritura por implementer o worker.

```text
lock_id: L-001
cycle_id: C-001
slice_id: [slice]
owner_agent_id: A-001
role: implementer
paths:
  - src/example.ts
mode: exclusive
expires_at: YYYY-MM-DDTHH:mm:ssZ
reason: [motivo]
status: active
```

Liberar el lock cambiando `status: released` y registrando evidencia en el gate log.
