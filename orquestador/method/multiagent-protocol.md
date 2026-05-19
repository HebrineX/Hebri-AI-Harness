# Protocolo Multiagente

Este harness permite muchos agentes logicos, pero limita la concurrencia operativa para mantener trazabilidad y evitar conflictos.

## Regla de Concurrencia

Maximo 5 agentes activos en total:

| Slot | Rol | Uso |
|---|---|---|
| 0 | leader | Orquesta, decide, registra, bloquea o libera ciclos |
| 1 | subagente | explorer, spec_author, implementer, reviewer o worker |
| 2 | subagente | idem |
| 3 | subagente | idem |
| 4 | subagente | idem |

Un pedido de 30 agentes se procesa como 30 asignaciones logicas en ciclos. Cada ciclo puede activar hasta 4 subagentes porque el leader ocupa el quinto slot.

## Ciclo

1. `G0_context_ready`: el leader define objetivo, modo, scope y riesgos.
2. `G1_dispatch_ready`: el leader registra asignaciones y ownership.
3. `G2_locks_acquired`: cada tarea con escritura tiene lock valido.
4. `G3_execution_complete`: subagentes entregan artefactos.
5. `G4_review_or_validation`: reviewer o leader valida evidencia.
6. `G5_handoff_complete`: queda handoff y registry actualizado.

Cada gate produce `pass`, `fail` o `blocked`.

## Registry

Archivo canonico: `.hebrinex/orquestador/sdd/progress/registry.md`.

Campos obligatorios por asignacion:

```text
agent_id: A-001
cycle_id: C-001
slot: 1
role: explorer | spec_author | implementer | reviewer | worker
slice_id: [id]
status: queued | running | blocked | done | cancelled
mode: automatico | manual
owned_files: [rutas]
readonly_files: [rutas]
started_at: YYYY-MM-DDTHH:mm:ssZ
last_update: YYYY-MM-DDTHH:mm:ssZ
handoff_to: [role | human | none]
blocking_reason: [texto | none]
artifacts: [rutas]
```

## Locks de Ownership

Ruta canonica: `.hebrinex/orquestador/sdd/progress/locks/`.

Un implementer o worker con escritura no puede empezar si no existe lock valido.

Formato:

```text
lock_id: L-001
cycle_id: C-001
slice_id: [id]
owner_agent_id: A-001
role: implementer
paths:
  - src/example.ts
mode: exclusive | append-only | generated
expires_at: YYYY-MM-DDTHH:mm:ssZ
reason: [por que se bloquea]
status: active | released | expired | blocked
```

## Categorias de Archivo

| Categoria | Lectura | Escritura | Regla |
|---|---|---|---|
| `exclusive` | Muchos | Uno | Requiere lock exclusivo |
| `shared-read` | Muchos | Ninguno | Lectura solamente |
| `append-only` | Muchos | Varios con entradas separadas | No se reescribe contenido ajeno |
| `generated` | Muchos | Uno via comando acordado | Registrar comando generador |
| `forbidden` | Ninguno salvo aprobacion | Ninguna | Requiere humano |

## Gate Log

Cada ciclo/slice mantiene un gate log:

```text
Gate: G0_context_ready
Resultado: pass | fail | blocked
Responsable: leader
Fecha: YYYY-MM-DD
Evidencia:
  - [archivo/comando/output]
Siguiente accion:
  - [accion]
```

## Handoff Minimo

Cada rol que termina debe dejar:

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

## Definicion Estricta de Done

Una tarea esta `done` solo si:
- Spec aprobada, si aplica SDD.
- Requirements cubiertos por tasks y tests/evidencia.
- Gate log completo.
- Verificacion ejecutada o bloqueo por verificacion no disponible registrado.
- Reviewer aprueba o leader cierra tarea no-SDD de bajo riesgo.
- Gaps nuevos registrados.
- Locks liberados o expirados con razon.
- Registry actualizado.
