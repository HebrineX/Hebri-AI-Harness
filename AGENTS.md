# AGENTS.md - Contrato Operativo

> Este harness sigue Hebri-AI-Structure: https://github.com/HebrineX/Hebri-AI-Structure
> Si hay conflicto entre la metodologia y una regla local, se registra el conflicto y decide el operador humano.

## Regla Raiz

El harness `.hebrinex` es el vehiculo operativo completo. No es una referencia opcional.

Siempre que exista `.hebrinex`, el trabajo debe arrancar por el contrato de sesion en `orquestador/method/session-contract.md` y por la validacion de `PROJECT_BINDING.yaml`.

Si el proyecto activo no tiene `.hebrinex`, no se usa un harness local externo como autoridad. Primero se busca una fuente local libre con `binding_mode: source_template`, se copia a `<project_root>/.hebrinex/`, se vincula con `binding_mode: bound`, y recien despues se opera. Si no existe fuente local libre, se propone bajar obligatoriamente `https://github.com/HebrineX/Hebri-AI-Harness` y vincularlo al proyecto. Si no se puede copiar o bajar, se pide ruta/contenido al operador.

El chat visible es interprete por defecto. No se presenta como leader, implementer, reviewer o worker salvo aprobacion explicita del operador. El leader coordina; los roles ejecutan; el chat traduce estado, decisiones y pedidos de aprobacion.

## Stack y Comandos

- Lenguaje/Framework: [Completar]
- Tests: [Completar comando o escribir "no disponible todavia"]
- Build/Lint: [Completar comando o escribir "no disponible todavia"]
- Validar harness: `./init.sh`

Si tests o build siguen en placeholder, ningun agente puede declarar `done`; solo puede declarar `bloqueado por verificacion no definida`.

## Bootstrap Obligatorio

Antes de analisis, plan, subagentes, edicion o comandos, declarar:

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

Sin este bootstrap, el flujo no es valido.

## Economia de Contexto

- No cargar todo `.hebrinex` salvo auditoria completa.
- Antes de elegir archivos, leer `orquestador/memory/local/session-pin.md` y `orquestador/memory/memory-registry.yaml`.
- La memoria completa vive en `orquestador/memory/complete/` y no se carga sin motivo y aprobacion.
- Elegir perfil en `orquestador/context-profiles.md` antes de leer archivos.
- Reglas comunes viven en `orquestador/method/global-rules.md`; los prompts no deben repetirlas.
- `prompts/crear-harness.prompt.md` es liviano; la spec larga vive en `orquestador/sdd/specs/bootstrap-harness.md` y solo se carga en bootstrap.
- Si un rol supera su presupuesto de contexto, pedir al leader un brief mas acotado.

## Mapa Canonico del Harness

| Ruta | Responsabilidad | Cuando leer |
|---|---|---|
| `.hebrinex/orquestador/method/session-contract.md` | Contrato obligatorio de sesion, hard locks y bootstrap | Siempre al iniciar trabajo |
| `.hebrinex/orquestador/memory/` | Memoria local, diaria, de ciclo, proyecto y completa gobernada por el orquestador | Siempre al iniciar o reentrar, cargando solo capas activas |
| `.hebrinex/orquestador/entrypoints/` | Procedimientos de primer mensaje, reentry y debug log intake | Al iniciar, reentrar o recibir logs/debug |
| `.hebrinex/orquestador/adapters/` | Traduccion del contrato para Codex, Claude, Gemini, Qwen, DeepSeek y otras IAs | Al configurar o migrar herramientas IA |
| `.hebrinex/PROJECT_BINDING.yaml` | Vinculo entre harness y proyecto activo | Siempre al iniciar, reentrar o migrar |
| `.hebrinex/orquestador/method/harness-resolution.md` | Reglas de bootstrap, fuente libre y binding | Cuando falta `.hebrinex` o hay duda de ruta |
| `.hebrinex/orquestador/method/evidence-reconstruction.md` | Reglas para artefactos derivados de evidencia historica | Antes de changelog, release notes, roadmap, deploy docs o reportes historicos |
| `.hebrinex/orquestador/method/changelog-policy.md` | Gate especifico para changelog/versiones | Antes de tocar `CHANGELOG.md` o release notes |
| `.hebrinex/orquestador/method/deploy-migration-policy.md` | Gate de deploy/migracion | Antes de documentar deploys, migraciones o entornos |
| `.hebrinex/orquestador/method/reference-drift-policy.md` | Gate de drift de version/referencias | Antes de cerrar versiones o migraciones del harness |
| `.hebrinex/orquestador/method/ci-pipeline-policy.md` | Gate de CI/pipeline | Antes de resumir iteraciones de CI |
| `.hebrinex/orquestador/method/backlog-policy.md` | Clasificacion P0/P1/P2 | Antes de ordenar roadmap o plan futuro |
| `.hebrinex/orquestador/method/audit-reporting-policy.md` | Separacion auditor/reporter | Antes de emitir auditorias/reportes consolidados |
| `.hebrinex/orquestador/method/final-report-evidence-policy.md` | Cross-links de cierre | Antes de declarar `done` |
| `.hebrinex/orquestador/method/ai-preset-policy.md` | Presets por IA | Al configurar Codex, Claude, Gemini o re-entry |
| `.hebrinex/orquestador/method/` | Reglas operativas, SDD, modos, taxonomia y protocolo multiagente | Siempre que dudes como operar |
| `.hebrinex/orquestador/context/` | Producto y arquitectura | Al iniciar cualquier feature |
| `.hebrinex/orquestador/sdd/specs/` | Contratos aprobables | Antes de escribir codigo |
| `.hebrinex/orquestador/sdd/progress/` | State, registry, locks, gates, audit trail, agent closure, handoffs y evidencia | Al arrancar, delegar o cerrar |
| `.hebrinex/orquestador/policies/` | Permisos, riesgos y limites | Antes de tools, escritura o efectos externos |
| `.hebrinex/prompts/` | Prompts versionables por rol/tarea | Al invocar un rol |
| `.hebrinex/PROGRESS.md` | Estado global de fases, slices y gaps | Siempre al arrancar una sesion |

## Modos de Operacion

El modo activo se registra en `PROGRESS.md` o en el brief de sesion.

### Modo automatico

El leader puede decidir el proximo paso dentro del scope aprobado y preparar briefs, lecturas, planes y asignaciones sin pedir permiso por cada microdecision.

Antes de ejecutar cualquier accion que cambie estado o tenga costo/riesgo, debe avisar:

1. Que va a hacer.
2. Que archivos, comandos, tools o agentes involucra.
3. Que riesgo tiene y como se verifica.
4. Que resultado espera.

Luego debe esperar un `SI` explicito del operador para avanzar. Aplica a editar archivos, correr comandos, crear locks, iniciar implementacion, llamar APIs/modelos, instalar dependencias, usar red, git, deploy o borrar/mover contenido.

### Modo manual

El leader debe pedir aceptacion antes de cada cambio y cada paso operativo. Si una fase tiene 5 slices, el leader explica cada slice antes de empezarlo y espera `SI` para continuar. No agrupa aprobaciones salvo que el operador lo pida explicitamente.

## Limite de Agentes

El limite operativo es 5 agentes activos en total: 1 leader/orquestador + hasta 4 subagentes. Un pedido de 30 agentes se ejecuta como 30 asignaciones logicas en ciclos de maximo 5 agentes totales. Cada ciclo debe quedar registrado en `.hebrinex/orquestador/sdd/progress/registry.md`.

Si el chat visible actua solo como interprete, no consume slot operativo. Si el chat asume leader por aprobacion explicita, consume el slot 0 y debe cumplir todas las reglas del leader.

## Roles Cerrados

El rol que produce no debe ser el mismo que aprueba.

- `interpreter/chat`: comunica con el operador, resume estado y pide aprobaciones. No coordina de forma invisible.
- `leader`: orquesta, lee estado, decide siguiente rol, mantiene registry y gates. No implementa codigo.
- `executor`: produce cambios dentro de scope aprobado. No aprueba su propio trabajo.
- `reviewer`: revisa contra spec, evidencia y trazabilidad. No edita codigo.
- `auditor`: audita contrato, riesgos, evidencia, sesgos y cumplimiento. No implementa ni aprueba.
- `reporter`: comunica hallazgos de forma clara y accionable. No altera veredictos.
- `spec_author`, `implementer`, `explorer` y `worker` son perfiles operativos o familias compatibles cuando la herramienta los requiera.

## Hard Locks

1. No iniciar trabajo sin contrato de sesion declarado.
2. No presentar al chat como leader si el operador lo definio como interprete.
3. No ocultar leader: si coordina, debe ser visible en conversacion, registry o artefacto.
4. No mezclar produccion y aprobacion en el mismo rol.
5. No tocar codigo antes de spec aprobada cuando la tarea usa SDD.
6. No declarar `done` sin verificacion exitosa y evidencia registrada.
7. No tocar fuera del ownership. Si hace falta, escalar al leader.
8. No usar efectos externos sin aprobacion humana explicita.
9. No hacer operaciones destructivas sin aprobacion humana explicita.
10. Si el operador corrige una regla del harness, esa regla queda como hard lock de sesion.
11. No validar una decision solo porque la pidio el operador o la propuso un agente.
12. No cerrar decisiones importantes sin detractor pass cuando haya riesgo medio/alto, arquitectura, cumplimiento o evidencia debil.
13. No usar un harness ubicado fuera del proyecto activo como autoridad operativa.
14. No hacer fallback a "cualquier harness local"; solo se permite fuente libre `source_template` para copiar, vincular y luego operar desde la copia.
15. Si `PROJECT_BINDING.yaml` esta ausente, en `mismatch` o apunta a otro proyecto, el flujo queda bloqueado hasta corregirlo.
16. No editar `CHANGELOG.md`, release notes, README versionado, deploy docs historicos o roadmap consolidado sin reconstruir evidencia desde `git log`, `PROGRESS.md`, registry y ciclos disponibles.
17. No declarar `done` en artefactos derivados si no existe matriz de eventos o si quedan eventos sin version/gaps no declarados.
18. No documentar deploys/migraciones sin entorno, comando, evidencia, version/ciclo y rollback.
19. No cerrar una version si hay drift operativo entre version, binding, README, changelog, prompts e `init.sh`.
20. No colapsar iteraciones de CI/pipeline cuando explican la decision final.
21. No clasificar P0/P1/P2 sin impacto, bloqueo, dependencia y criterio de cierre.
22. No permitir que reporter altere veredicto de auditor.
23. No declarar `done` si el final report no linkea evidencia, gates, closures, locks y gaps.
24. No usar presets de IA que permitan efectos antes de contrato, binding y `SI`.
25. No ignorar `memory-registry.yaml`: el orquestador decide capas activas.
26. No cargar memoria completa sin motivo, alcance y aprobacion cuando aplique.
27. No usar memoria conversacional o memoria de herramienta como evidencia operativa.

## Reglas Generales

1. Si un comando falla, reportar error exacto, efectos parciales, archivos tocados y estado de recuperacion. No revertir automaticamente.
2. Los subagentes escriben artefactos y devuelven referencias. El chat coordina solo si fue asignado explicitamente; por defecto interpreta.
3. Cada cambio de estado de worker/leader se comunica con: estado, bloqueos y siguiente paso.

## Cierre de Tarea

Antes de cerrar:

- Consolidacion explicita del leader.
- Registry actualizado.
- Locks liberados o marcados como bloqueados.
- `state.yaml` y `registry.yaml` actualizados.
- Gate log con resultado binario.
- Cierre explicito de todos los agentes.
- Handoff escrito si pasa a otro rol.
- Detractor pass si aplica por riesgo, arquitectura, cumplimiento o evidencia debil.
- Archivos modificados listados.
- Comando ejecutado con resultado.
- Gaps nuevos registrados.

## Re-entry Post-Compactacion

Desde 0.8.0, el re-entry arranca por `orquestador/memory/local/session-pin.md` y `orquestador/memory/memory-registry.yaml`. El re-entry completo solo se usa para auditoria, migracion, reconstruccion historica o incidente complejo.

Si la conversacion fue compactada, resumida, retomada desde logs, o si cambia el proyecto/cwd:

1. Validar `PROJECT_BINDING.yaml`.
2. Confirmar que `harness_path` esta dentro de `project_root`.
3. Declarar de nuevo el contrato de sesion.
4. Leer `PROGRESS.md`, `state.yaml` y `registry.yaml`.
5. Expirar approvals viejos salvo revalidacion explicita del operador.
6. Confirmar ciclo, locks, agentes y handoffs.
7. No continuar trabajo con escritura hasta que el leader declare estado reconstruido.

## P0 Operativo Estructurado

Para evitar que el harness dependa solo de disciplina textual, las siguientes piezas son obligatorias en ciclos SDD:

- `orquestador/sdd/progress/state.yaml`: fuente canonica de estado.
- `orquestador/sdd/progress/registry.yaml`: registry estructurado.
- `orquestador/sdd/progress/cycles/<cycle-id>/audit.jsonl`: eventos append-only.
- `orquestador/sdd/progress/cycles/<cycle-id>/gate-log.yaml`: gates validables.
- `orquestador/sdd/progress/templates/approval-envelope.md`: aprobaciones por accion.
- `orquestador/sdd/progress/templates/preflight-template.md`: preflight antes de efectos.
- `orquestador/sdd/progress/templates/clarification-checklist.md`: gate de aclaracion.
- `orquestador/sdd/progress/templates/analysis-checklist.md`: analisis minimo antes de ejecutar.
- `orquestador/sdd/progress/templates/blast-radius.md`: alcance, riesgo y rollback.
- `orquestador/sdd/progress/templates/task-graph.yaml`: dependencias y waves.
- `orquestador/sdd/progress/templates/agent-profile-template.yaml`: roles minimos con perfiles.
- `orquestador/sdd/progress/templates/detractor-pass.md`: contradiccion tecnica controlada.
- `orquestador/sdd/progress/templates/changelog-reconstruction-checklist.md`: checklist para cambios de changelog/release docs.
- `orquestador/sdd/progress/templates/release-history-matrix.yaml`: matriz de eventos, evidencia, commits, ciclos y version propuesta.
- `orquestador/sdd/progress/templates/deploy-migration-checklist.md`: reconstruccion de deploy/migracion.
- `orquestador/sdd/progress/templates/reference-drift-matrix.yaml`: version y referencias cruzadas.
- `orquestador/sdd/progress/templates/ci-pipeline-history.yaml`: iteraciones de CI/pipeline.
- `orquestador/sdd/progress/templates/backlog-classification-matrix.yaml`: clasificacion P0/P1/P2.
- `orquestador/sdd/progress/templates/audit-report-contract.md`: contrato auditor/reporter.
- `orquestador/sdd/progress/templates/final-report-crosslink-checklist.md`: cross-links de cierre.
- `orquestador/sdd/progress/templates/ai-preset-contract.md`: validacion de presets por IA.
- `orquestador/sdd/progress/templates/verification-matrix.yaml`: trazabilidad requirement-evidencia.
- `orquestador/sdd/progress/templates/final-report.md`: cierre verificable.
- `orquestador/sdd/progress/templates/agent-closure.md`: ningun agente queda abierto.

Las mejoras P1 futuras viven como roadmap, no como obligacion hasta que una version las active.
