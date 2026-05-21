# Protocolo Multiagente

Este harness permite muchos agentes logicos, pero limita la concurrencia operativa para mantener trazabilidad y evitar conflictos.

## Separacion Chat / Leader

El chat visible es interprete por defecto. Su responsabilidad es comunicar estado, pedir aprobaciones y transmitir resultados.

El leader es el coordinador operativo. Debe quedar visible desde el inicio mediante uno de estos mecanismos:

1. Subagente leader real, si la herramienta lo permite y el operador aprobo abrirlo.
2. Artefacto/brief de leader en `orquestador/sdd/progress/`.
3. Bloque explicito de estado en conversacion marcado como `Leader`.

Si el leader no esta visible, no se puede despachar workers ni cerrar fases.

## Regla de Concurrencia

Maximo 5 agentes activos en total:

| Slot | Rol | Uso |
|---|---|---|
| 0 | leader | Orquesta, decide, registra, bloquea o libera ciclos |
| 1 | subagente | explorer, spec_author, implementer, reviewer o worker |
| 2 | subagente | idem |
| 3 | subagente | idem |
| 4 | subagente | idem |

El chat interprete no consume slot. Si el chat asume leader por aprobacion explicita, consume slot 0.

Un pedido de 30 agentes se procesa como 30 asignaciones logicas en ciclos. Cada ciclo puede activar hasta 4 subagentes porque el leader ocupa el quinto slot.

## Ciclo

1. `G0_session_contract`: contrato de sesion declarado y modo definido.
2. `G1_context_ready`: el leader define objetivo, modo, scope y riesgos.
3. `G2_dispatch_ready`: el leader registra asignaciones y ownership.
4. `G3_locks_acquired`: cada tarea con escritura tiene lock valido.
5. `G4_execution_complete`: subagentes entregan artefactos.
6. `G5_review_or_validation`: reviewer valida evidencia o leader cierra solo tarea no-SDD de bajo riesgo.
7. `G6_agent_closure_complete`: todos los agentes abiertos tienen cierre, handoff y locks resueltos.`n8. `G7_handoff_complete`: queda handoff, registry actualizado y consolidacion del leader.

Cada gate produce `pass`, `fail` o `blocked`.

## Registry

Archivo canonico: `.hebrinex/orquestador/sdd/progress/registry.md`.

Campos obligatorios por asignacion:

```text
agent_id: A-001
cycle_id: C-001
slot: 0 | 1 | 2 | 3 | 4
role: leader | explorer | spec_author | implementer | reviewer | worker
visible_to_operator: true | false
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
Gate: G0_session_contract | G1_context_ready | G2_dispatch_ready | G3_locks_acquired | G4_execution_complete | G5_review_or_validation | G6_agent_closure_complete | G7_handoff_complete
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

## Reporte al Operador

Cada cambio relevante se resume en tres bloques:

```text
Estado:
- [rol/agente/ciclo/slice]

Bloqueos:
- [ninguno | lista]

Siguiente paso:
- [accion]
- Requiere SI: si | no
```

## Definicion Estricta de Done

Una tarea esta `done` solo si:
- Contrato de sesion cumplido.
- Leader visible y consolidacion final registrada.
- Spec aprobada, si aplica SDD.
- Requirements cubiertos por tasks y tests/evidencia.
- Gate log completo, incluyendo `G6_agent_closure_complete`.
- Verificacion ejecutada o bloqueo por verificacion no disponible registrado.
- Reviewer aprueba o leader cierra tarea no-SDD de bajo riesgo.
- Gaps nuevos registrados.
- Agentes cerrados explicitamente.`n- Locks liberados o expirados con razon.
- Registry actualizado.

## Artefactos Estructurados P0

Markdown conserva la vista humana, pero el cierre operativo se valida contra artefactos estructurados:

- `orquestador/sdd/progress/state.yaml`
- `orquestador/sdd/progress/registry.yaml`
- `orquestador/sdd/progress/cycles/<cycle-id>/audit.jsonl`
- `orquestador/sdd/progress/cycles/<cycle-id>/gate-log.yaml`
- `orquestador/sdd/progress/cycles/<cycle-id>/<slice>/verification-matrix.yaml`
- `orquestador/sdd/progress/cycles/<cycle-id>/<slice>/final-report.md`
- `orquestador/sdd/progress/templates/agent-closure.md`

Regla: una fase/slice solo cambia de estado si `state.yaml`, gate log, audit trail, verification matrix, final report y cierre de agentes son coherentes.
