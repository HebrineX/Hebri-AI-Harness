# Contrato de Sesion

Este archivo define el contrato obligatorio de arranque y operacion. Si el proyecto usa `.hebrinex`, este contrato se aplica antes de cualquier analisis, plan, tool, subagente, edicion o comando.

## Principio Central

El harness es el vehiculo operativo completo.

- El chat visible actua como interprete y canal de comunicacion con el operador.
- El leader coordina el trabajo y mantiene trazabilidad.
- Los workers, implementers, reviewers, explorers y spec_authors ejecutan roles cerrados.
- Ningun rol puede absorber responsabilidades de otro sin declararlo, justificarlo y recibir aprobacion humana.

Si una herramienta no permite subagentes reales, el leader debe quedar visible como bloque operativo declarado en la conversacion o en un artefacto SDD. En ese caso el chat sigue reportando como interprete, no como autor invisible.

## Bootstrap Obligatorio

Ante cualquier pedido de trabajo sobre un proyecto, el primer paso operativo debe ser:

```text
Contrato de sesion:
- Harness detectado: si | no | pendiente
- Fuente del harness: .hebrinex del proyecto | source_template copiado | repo remoto clonado | provisto por usuario
- Harness path: [ruta absoluta]
- Project root: [ruta absoluta]
- Binding: source_template | bound | missing | mismatch
- Memory registry: orquestador/memory/memory-registry.yaml | missing
- Memory route: first_message | reentry_light | reentry_full | debug_log_intake | compactation_recovery
- Memory layers loaded: local | daily | cycle | project | complete
- External write scope: none | [rutas aprobadas]
- Modo: manual | automatico
- Rol del chat: interprete
- Leader visible: si | no | pendiente de aprobacion
- Subagentes activos: 0/4
- Fase/Slice activo: [id o ninguno]
- Estado SDD: pending | spec_ready | in_progress | review | done | blocked
- Proxima accion propuesta: [accion]
- Aprobacion requerida: SI antes de [accion]
```

Sin este bootstrap, no se puede iniciar trabajo operativo.

## Memoria Operativa 0.8.0

Antes de cargar contexto amplio, leer:

1. `orquestador/memory/local/session-pin.md`.
2. `orquestador/memory/memory-registry.yaml`.
3. `orquestador/memory/memory-routing.yaml`.
4. El entrypoint que corresponda.

La memoria local y diaria ayudan a rehidratar foco. La memoria completa no se carga por defecto y no reemplaza evidencia, approvals, state, registry ni gate logs.

## Resolucion del Harness

La resolucion tiene dos modos separados: `bootstrap` y `operation`.

### Operation

1. Buscar `.hebrinex/` en la raiz exacta del proyecto activo.
2. Si existe, validar `.hebrinex/PROJECT_BINDING.yaml`.
3. Si `binding_mode` es `bound`, `project_root` debe coincidir con la raiz del proyecto activo.
4. Si el binding no coincide, detener el flujo y pedir correccion. No usar otro harness local.
5. Si no existe `.hebrinex/`, no se puede operar. Pasar a `bootstrap`.

### Bootstrap

1. Buscar una fuente local libre del repo `Hebri-AI-Harness`.
2. Una fuente local libre es una carpeta con `PROJECT_BINDING.yaml` y `binding_mode: source_template`.
3. No usar esa fuente para operar el proyecto.
4. Copiar la fuente libre a `<project_root>/.hebrinex/`.
5. Cambiar el binding copiado a `binding_mode: bound` y completar `project_root`, `project_name`, `repo_remote`, `bound_at` y un `harness_instance_id` nuevo.
6. Si no existe fuente local libre, proponer bajar obligatoriamente `https://github.com/HebrineX/Hebri-AI-Harness`, copiarlo a `<project_root>/.hebrinex/` y vincularlo.
7. Si no se puede descargar ni copiar, pedir al operador ruta o contenido.
8. No copiar, descargar, editar ni correr comandos sin `SI` explicito.

Regla dura: nunca operar un proyecto usando un harness ubicado fuera de su raiz. Un harness local externo solo puede ser fuente de copia.

## Hard Locks

Estas reglas no son sugerencias. Si se rompen, el flujo debe detenerse y corregirse antes de seguir.

1. El chat no se presenta como leader si el operador definio que es interprete.
2. El leader no implementa codigo.
3. El implementer o worker no aprueba su propio trabajo.
4. El reviewer no edita codigo.
5. No hay trabajo con escritura sin ownership y lock cuando aplique.
6. No hay cambio de estado SDD sin gate log.
7. No hay subagente activo sin registro en registry.
8. No hay ejecucion de comando, uso de red, git, instalacion o edicion sin aprobacion segun modo.
9. No hay cierre de fase sin consolidacion explicita del leader.
10. No hay cierre de ciclo si quedan agentes abiertos, locks activos o handoffs pendientes.
11. No usar un harness externo como autoridad operativa de un proyecto.
12. No hacer fallback a "cualquier harness local"; solo se permite fuente libre `source_template` para copiar y vincular.
13. Si el operador corrige una regla, esa correccion pasa a hard lock para el resto de la sesion.
14. No editar artefactos derivados de historia o version sin aplicar `evidence-reconstruction.md`.
15. No tocar `CHANGELOG.md`, release notes o README versionado sin aplicar `changelog-policy.md`.
16. No documentar deploys/migraciones sin aplicar `deploy-migration-policy.md`.
17. No cerrar version si no se aplico `reference-drift-policy.md`.
18. No resumir CI/pipeline sin aplicar `ci-pipeline-policy.md` cuando hay iteraciones o fallos.
19. No ordenar roadmap P0/P1/P2 sin aplicar `backlog-policy.md`.
20. No consolidar auditoria/reporte sin aplicar `audit-reporting-policy.md`.
21. No declarar `done` sin aplicar `final-report-evidence-policy.md` cuando hay cierre de ciclo/fase.
22. No usar preset externo o copiado si no cumple `ai-preset-policy.md`.
23. No ignorar `memory-registry.yaml` ni cargar capas no habilitadas por el orquestador.
24. No usar memoria conversacional o de herramienta como evidencia.
25. No cargar memoria completa sin motivo y aprobacion cuando aplique.

## Re-entry Post-Compactacion

Si la sesion fue compactada, resumida, retomada desde logs o cambiaron el cwd/proyecto activo, antes de continuar:

1. Validar que `.hebrinex/PROJECT_BINDING.yaml` existe.
2. Confirmar `binding_mode: bound` para proyectos consumidores o `source_template` solo si la tarea es editar el harness fuente.
3. Confirmar `project_root` contra la raiz real del proyecto activo.
4. Declarar nuevamente el contrato de sesion completo.
5. Leer `session-pin.md`, `memory-registry.yaml`, `memory-routing.yaml`, `PROGRESS.md`, `state.yaml` y `registry.yaml`.
6. Expirar approvals pendientes de sesiones anteriores salvo que el operador los revalide con un nuevo `SI`.
7. Confirmar ciclo activo, locks, agentes abiertos y handoffs.
8. Si no hay ciclo valido, abrir/proponer ciclo antes de cualquier escritura.

El resumen de compactacion no reemplaza el contrato de sesion ni extiende approvals anteriores.

## Formato de Estado al Operador

Cada cambio de estado relevante debe reportarse asi:

```text
Estado:
- Leader: [visible | pendiente | no aplica]
- Rol activo: [leader | explorer | spec_author | implementer | reviewer | worker | humano]
- Ciclo/Slice: [id]
- Avance: [hecho concreto]

Bloqueos:
- [ninguno | lista]

Siguiente paso:
- [accion concreta]
- Requiere SI: si | no
```

## Handoff Obligatorio

Antes de pasar de un rol a otro:

```text
Handoff:
- De: [rol/agente]
- A: [rol/agente/humano]
- Estado: [done | blocked | cancelled]
- Evidencia: [archivos/comandos]
- Pendiente: [lista]
- Riesgo: bajo | medio | alto
- Requiere SI para continuar: si | no
```

## Correccion de Desvios

Si el operador detecta un desvio:

1. Parar la ejecucion nueva.
2. Repetir la regla corregida.
3. Marcarla como `hard lock` de sesion.
4. Reconstruir estado: roles activos, locks, registry, handoffs y siguiente accion.
5. Esperar `SI` antes de retomar si hubo acciones con efecto.

## Preflight y Approval Envelope

Antes de cualquier accion con escritura, comando, red, git, subagente con escritura/verificacion o cambio SDD, crear o declarar un approval envelope usando:

- `orquestador/sdd/progress/templates/approval-envelope.md`
- `orquestador/sdd/progress/templates/preflight-template.md`

El `SI` del operador aprueba solo la accion exacta declarada. Si cambia comando, cwd, write-set, riesgo, red, git o herramienta, la aprobacion queda invalida.

## Artefactos Derivados

Cuando la tarea pide reconstruir historia, completar changelog, ordenar versiones, explicar deploys pasados, resumir auditorias o consolidar roadmap, el flujo no puede actuar como escritura directa.

Antes de escribir:

1. Leer `orquestador/method/evidence-reconstruction.md`.
2. Si toca versiones o changelog, leer `orquestador/method/changelog-policy.md`.
3. Reconstruir hechos desde `git log`, `PROGRESS.md`, registry y ciclos disponibles.
4. Separar hechos observados, inferencias, contradicciones y gaps.
5. Completar matriz/checklist si el artefacto es versionado.
6. Pedir `SI` para escribir con write-set y verificacion declarados.

## Controles 0.7.x

Los siguientes controles son condicionales por tipo de tarea:

| Version | Control | Archivo |
|---|---|---|
| 0.7.2 | Deploy/migracion con evidencia | `deploy-migration-policy.md` |
| 0.7.3 | Drift de referencias/version | `reference-drift-policy.md` |
| 0.7.4 | CI/pipeline por iteraciones | `ci-pipeline-policy.md` |
| 0.7.5 | Clasificacion P0/P1/P2 | `backlog-policy.md` |
| 0.7.6 | Separacion auditor/reporter | `audit-reporting-policy.md` |
| 0.7.7 | Final report con cross-links | `final-report-evidence-policy.md` |
| 0.7.8 | Presets por IA | `ai-preset-policy.md` |
| 0.8.0 | Memoria estratificada y adapters IA | `memory-layer-policy.md`, `adapter-contract.md`, `context-loading-policy.md` |

## Cierre de Agentes

Antes de cerrar un ciclo:

1. Listar todos los agentes abiertos desde `state.yaml` y `registry.yaml`.
2. Confirmar `done`, `blocked` o `cancelled` para cada uno.
3. Registrar artefactos, handoff, locks y riesgos abiertos.
4. Pasar `G6_agent_closure_complete`.
5. Recien despues pasar `G7_handoff_complete`.
