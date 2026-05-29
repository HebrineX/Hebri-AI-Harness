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
| 1 | subagente | executor, reviewer, auditor, reporter o perfil compatible |
| 2 | subagente | idem |
| 3 | subagente | idem |
| 4 | subagente | idem |

El chat interprete no consume slot. Si el chat asume leader por aprobacion explicita, consume slot 0.

Un pedido de 30 agentes se procesa como 30 asignaciones logicas en ciclos. Cada ciclo puede activar hasta 4 subagentes porque el leader ocupa el quinto slot.

## Roles Minimos y Perfiles

Roles minimos: `interpreter`, `leader`, `executor`, `reviewer`, `auditor`, `reporter`.

```yaml
auditor:
  profiles: [harness_compliance, cost, security, architecture, release, pipeline, detractor]
reporter:
  profiles: [operator, technical, executive]
executor:
  profiles: [spec_author, implementer, worker, docs_writer, prompt_engineer]
```

Regla anti-explosion: no se crea un rol nuevo si la necesidad puede expresarse como perfil de un rol existente.

## Ciclo

1. `G0_session_contract`: contrato de sesion declarado y modo definido.
2. `G1_context_ready`: objetivo, modo, scope y riesgos claros.
   - `G1A_clarification_complete`: preguntas bloqueantes resueltas o supuestos aceptados.
   - `G1B_analysis_complete`: requisitos, constraints, riesgos y evidencia esperada revisados.
   - `G1C_blast_radius_declared`: read-set, write-set, comandos, red, git, rollback y riesgos declarados.
3. `G2_dispatch_ready`: el leader registra asignaciones y ownership.
   - `G2A_task_graph_ready`: dependencias, waves y paralelismo definidos.
4. `G3_locks_acquired`: cada tarea con escritura tiene lock valido.
5. `G4_execution_complete`: subagentes entregan artefactos.
6. `G5_review_or_validation`: reviewer valida evidencia o leader cierra solo tarea no-SDD de bajo riesgo.
   - `G5A_detractor_pass_complete`: decisiones importantes revisadas por `auditor(profile: detractor)`.
   - `G5B_release_reconstruction_complete`: changelog/release docs/roadmap historico revisados contra matriz de evidencia si fueron tocados.
   - `G5C_deploy_migration_complete`: deploy/migracion reconstruida con entorno, comando, evidencia y rollback si aplica.
   - `G5D_reference_drift_complete`: version y referencias operativas sin drift si se cierra una version.
   - `G5E_ci_pipeline_history_complete`: iteraciones de CI/pipeline mapeadas si fueron parte del cambio.
   - `G5F_backlog_classification_complete`: P0/P1/P2 justificados por impacto, bloqueo y dependencia.
   - `G5G_audit_report_contract_complete`: auditor y reporter separados sin cambio de veredicto.
   - `G5H_final_report_crosslink_complete`: final report conectado con evidencia, gates, closures, locks y gaps.
7. `G6_agent_closure_complete`: todos los agentes abiertos tienen cierre, handoff y locks resueltos.
8. `G7_handoff_complete`: queda handoff, registry actualizado y consolidacion del leader.

Cada gate produce `pass`, `fail` o `blocked`.

## Registry

Archivo canonico: `.hebrinex/orquestador/sdd/progress/registry.yaml`. `registry.md` puede existir como vista humana.

Campos obligatorios por asignacion:

```yaml
agent_id: A-001
cycle_id: C-001
slot: 0
role: leader | executor | reviewer | auditor | reporter | explorer | spec_author | implementer | worker
profile: none | harness_compliance | cost | security | architecture | release | pipeline | detractor | operator | technical | executive
visible_to_operator: true
slice_id: slice-001
status: todo | ready | in_progress | review | blocked | done | cancelled | legacy_unverified
mode: automatico | manual
objective: "objetivo concreto"
owned_files: []
readonly_files: []
started_at: YYYY-MM-DDTHH:mm:ssZ
last_update: YYYY-MM-DDTHH:mm:ssZ
handoff_to: leader | reviewer | auditor | reporter | human | none
blocking_reason: none
artifacts: []
```

## Gate Log

Cada ciclo/slice mantiene un gate log:

```text
Gate: G0_session_contract | G1_context_ready | G1A_clarification_complete | G1B_analysis_complete | G1C_blast_radius_declared | G2_dispatch_ready | G2A_task_graph_ready | G3_locks_acquired | G4_execution_complete | G5_review_or_validation | G5A_detractor_pass_complete | G5B_release_reconstruction_complete | G5C_deploy_migration_complete | G5D_reference_drift_complete | G5E_ci_pipeline_history_complete | G5F_backlog_classification_complete | G5G_audit_report_contract_complete | G5H_final_report_crosslink_complete | G6_agent_closure_complete | G7_handoff_complete
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

- `PROJECT_BINDING.yaml` valido y coherente con el proyecto activo.
- Contrato de sesion cumplido.
- Leader visible y consolidacion final registrada.
- Clarification, analysis y blast radius completos cuando aplique.
- Spec aprobada, si aplica SDD.
- Requirements cubiertos por tasks y tests/evidencia.
- Gate log completo, incluyendo `G6_agent_closure_complete`.
- Detractor pass completo si el cierre es importante o de riesgo medio/alto.
- Release reconstruction completo si se tocaron changelog, release notes, README versionado, deploy docs historicos o roadmap consolidado.
- Controles condicionales 0.7.x completos cuando aplican: deploy/migracion, drift de referencias, CI/pipeline, backlog, auditor/reporter y cross-links.
- Verificacion ejecutada o bloqueo por verificacion no disponible registrado.
- Reviewer aprueba o leader cierra tarea no-SDD de bajo riesgo.
- Gaps nuevos registrados.
- Agentes cerrados explicitamente.
- Locks liberados o expirados con razon.
- Registry actualizado.

## Artefactos Estructurados P0

- `orquestador/sdd/progress/state.yaml`
- `orquestador/sdd/progress/registry.yaml`
- `PROJECT_BINDING.yaml`
- `orquestador/sdd/progress/templates/reentry-checklist.md`
- `orquestador/sdd/progress/cycles/<cycle-id>/audit.jsonl`
- `orquestador/sdd/progress/cycles/<cycle-id>/gate-log.yaml`
- `orquestador/sdd/progress/cycles/<cycle-id>/<slice>/verification-matrix.yaml`
- `orquestador/sdd/progress/cycles/<cycle-id>/<slice>/final-report.md`
- `orquestador/sdd/progress/templates/clarification-checklist.md`
- `orquestador/sdd/progress/templates/analysis-checklist.md`
- `orquestador/sdd/progress/templates/blast-radius.md`
- `orquestador/sdd/progress/templates/task-graph.yaml`
- `orquestador/sdd/progress/templates/agent-profile-template.yaml`
- `orquestador/sdd/progress/templates/detractor-pass.md`
- `orquestador/sdd/progress/templates/changelog-reconstruction-checklist.md`
- `orquestador/sdd/progress/templates/release-history-matrix.yaml`
- `orquestador/sdd/progress/templates/deploy-migration-checklist.md`
- `orquestador/sdd/progress/templates/reference-drift-matrix.yaml`
- `orquestador/sdd/progress/templates/ci-pipeline-history.yaml`
- `orquestador/sdd/progress/templates/backlog-classification-matrix.yaml`
- `orquestador/sdd/progress/templates/audit-report-contract.md`
- `orquestador/sdd/progress/templates/final-report-crosslink-checklist.md`
- `orquestador/sdd/progress/templates/ai-preset-contract.md`
- `orquestador/sdd/progress/templates/agent-closure.md`

Regla: una fase/slice solo cambia de estado si `state.yaml`, gate log, audit trail, verification matrix, final report y cierre de agentes son coherentes.
