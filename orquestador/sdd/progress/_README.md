# Progress Operativo

Esta carpeta conserva la memoria entre agentes. El chat coordina; estos archivos son la fuente de verdad operativa.

## Archivos Canonicos

| Archivo / Carpeta | Uso |
|---|---|
| `registry.md` | Estado de ciclos, agentes, slots, roles y artefactos |
| `blocked.md` | Cola de bloqueos priorizada |
| `locks/` | Locks de ownership por slice/ciclo |
| `cycles/<cycle-id>/` | Evidencia, gates y handoffs de cada ciclo |

## Estructura Recomendada

```text
progress/
  registry.md
  blocked.md
  locks/
    L-001.lock.md
  cycles/
    C-001/
      gate-log.md
      health-report.md
      slice-auth-login/
        brief.md
        impl-agent-02.md
        review-agent-04.md
        handoff.md
```

## Registry Entry

```text
agent_id: A-001
cycle_id: C-001
slot: 1
role: implementer
slice_id: slice-auth-login
status: running
mode: automatico
owned_files:
  - src/auth/login.ts
readonly_files:
  - .hebrinex/orquestador/sdd/specs/slice-auth-login/requirements.md
artifacts:
  - .hebrinex/orquestador/sdd/progress/cycles/C-001/slice-auth-login/impl-agent-001.md
blocking_reason: none
```

## Gate Log

```text
Gate: G3_execution_complete
Resultado: pass | fail | blocked
Responsable: A-001
Fecha: YYYY-MM-DD
Evidencia:
  - Comando: npm test -- auth
  - Resultado: 12 passed
Siguiente accion:
  - reviewer revisa trazabilidad
```

## Handoff

```text
Estado actual:
Decision tomada:
Archivos leidos:
Archivos modificados:
Evidencia:
Bloqueos:
Proximo rol sugerido:
Contexto que no debe perderse:
```
