# Progress Operativo

Esta carpeta conserva la memoria entre agentes. El chat coordina; estos archivos son la fuente de verdad operativa.

## Archivos Canonicos

| Archivo / Carpeta | Uso |
|---|---|
| `state.yaml` | Fuente canonica de fase, slice, modo, approvals, gates, locks y agentes abiertos |
| `registry.yaml` | Registro estructurado de ciclos/agentes; `registry.md` queda como vista humana |
| `registry.md` | Vista humana de ciclos, agentes, slots, roles y artefactos |
| `blocked.md` | Cola de bloqueos priorizada |
| `locks/` | Locks de ownership por slice/ciclo |
| `cycles/<cycle-id>/` | Evidencia, audit log, gates, handoffs, verification matrix, final report y cierres de agentes |

## Estructura Recomendada

```text
progress/
  state.yaml
  registry.yaml
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

## Artefactos P0 Obligatorios

| Artefacto | Regla |
|---|---|
| `state.yaml` | Ninguna fase/slice cambia de estado si no queda reflejada aca. |
| `audit.jsonl` | Todo evento relevante se registra append-only. |
| `gate-log.yaml` | Cada gate produce `pass`, `fail` o `blocked`. |
| `verification-matrix.yaml` | Ningun requirement se considera cubierto sin evidencia. |
| `final-report.md` | Ningun ciclo/fase cierra sin reporte final. |
| `agent-closure.md` | Ningun agente queda abierto al cerrar ciclo. |

## Gate de Cierre de Agentes

`G6_agent_closure_complete` es obligatorio. Debe pasar antes de `G7_handoff_complete`.

Bloquea si:
- Hay subagentes activos.
- Falta handoff de un agente.
- Hay locks activos sin liberar.
- Falta listar artefactos producidos.
- El leader no consolido estado final.
