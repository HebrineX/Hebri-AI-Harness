# Changelog

## [0.7.9] - 2026-05-29

### Added
- `orquestador/harness-manifest.txt` como manifiesto estructural canonico para directorios y archivos obligatorios.

### Changed
- `init.sh` deja de duplicar listas largas de estructura y valida desde el manifest.
- `bootstrap-harness.md` fue condensado al flujo actual para evitar confusion con la estructura legacy `.github/orquestador/`.
- Placeholders de `AGENTS.md`/`PROGRESS.md` se informan como `INFO` en `source_template` y como `WARN` en `bound`.
- Se completa el perfil `pipeline` en ejemplos/profiles de auditoria.

### Rationale
- Optimizacion interna de mantenibilidad: mismo comportamiento funcional, menor duplicacion y menor riesgo de drift entre estructura, version y validacion.

## [0.7.8] - 2026-05-29

### Added
- `orquestador/method/ai-preset-policy.md` para presets anti-desvio por IA.
- Templates y prompts para Codex, Claude y Gemini con contrato, binding, re-entry y preflight.

### Changed
- La version operativa actual pasa a 0.7.8.
- `init.sh` valida todos los gates incrementales de la linea 0.7.x.

## [0.7.7] - 2026-05-29

### Added
- `orquestador/method/final-report-evidence-policy.md`.
- `orquestador/sdd/progress/templates/final-report-crosslink-checklist.md`.
- `prompts/cerrar-con-evidencia.prompt.md`.

### Rationale
- Evita cierres `done` sin links verificables a gate log, audit trail, verification matrix, agent closure, locks, gaps y validaciones.

## [0.7.6] - 2026-05-29

### Added
- `orquestador/method/audit-reporting-policy.md`.
- `orquestador/sdd/progress/templates/audit-report-contract.md`.
- `prompts/auditar-y-reportar.prompt.md`.

### Rationale
- Refuerza que el auditor define veredicto por evidencia y el reporter comunica sin alterar el resultado.

## [0.7.5] - 2026-05-29

### Added
- `orquestador/method/backlog-policy.md`.
- `orquestador/sdd/progress/templates/backlog-classification-matrix.yaml`.
- `prompts/clasificar-roadmap.prompt.md`.

### Rationale
- Ordena P0/P1/P2 por bloqueo, impacto, dependencia y criterio de cierre, no por preferencia del agente.

## [0.7.4] - 2026-05-29

### Added
- `orquestador/method/ci-pipeline-policy.md`.
- `orquestador/sdd/progress/templates/ci-pipeline-history.yaml`.
- `prompts/reconstruir-ci-pipeline.prompt.md`.

### Rationale
- Evita colapsar iteraciones de CI/pipeline cuando el operador necesita documentar como se llego a un pipeline funcional.

## [0.7.3] - 2026-05-29

### Added
- `orquestador/method/reference-drift-policy.md`.
- `orquestador/sdd/progress/templates/reference-drift-matrix.yaml`.
- `prompts/validar-referencias-version.prompt.md`.

### Rationale
- Evita inconsistencias entre `HARNESS_VERSION`, `PROJECT_BINDING.yaml`, README, changelog, prompts e `init.sh`.

## [0.7.2] - 2026-05-29

### Added
- `orquestador/method/deploy-migration-policy.md`.
- `orquestador/sdd/progress/templates/deploy-migration-checklist.md`.
- `prompts/reconstruir-deploy-migracion.prompt.md`.

### Rationale
- Evita documentar deploys o migraciones sin comandos, entorno, evidencia, version/ciclo y rollback.

## [0.7.1] - 2026-05-29

### Added
- `orquestador/method/changelog-policy.md` para bloquear cambios de changelog/release docs sin reconstruccion historica previa.
- `orquestador/method/evidence-reconstruction.md` para tratar changelog, release notes, roadmap, deploy docs, reportes y auditorias como artefactos derivados de evidencia.
- `orquestador/sdd/progress/templates/changelog-reconstruction-checklist.md` y `release-history-matrix.yaml` como evidencia obligatoria antes de editar historial/versiones.
- `prompts/actualizar-changelog.prompt.md` para usar un flujo repetible ante pedidos de completar, ordenar o corregir changelog.
- Roadmap incremental `0.7.x` en `future-p1.md` para sumar controles omitidos como versiones chicas, sin salto estructural a 0.8.

### Changed
- `init.sh` valida la version 0.7.1 y la existencia del gate de reconstruccion historica.
- `AGENTS.md`, `session-contract.md`, `multiagent-protocol.md`, `context-profiles.md` y `risk-criteria.md` integran el control de artefactos derivados.

### Rationale
- Cambio motivado por ERR-05: en la version 0.6 el changelog requirio multiples correcciones manuales porque el agente no leyo `git log`, `PROGRESS.md` y registry juntos antes de escribir. 0.7.1 convierte esa reconstruccion en gate obligatorio.

## [0.7.0] - 2026-05-29

### Added
- `PROJECT_BINDING.yaml` para distinguir harness fuente (`source_template`) de harness vinculado a un proyecto (`bound`).
- `orquestador/method/harness-resolution.md` con reglas estrictas de bootstrap, copia, binding y anti-contaminacion entre proyectos.
- `orquestador/sdd/progress/templates/reentry-checklist.md` para reanudar despues de compactacion sin perder contrato, ciclo ni approvals.
- `prompts/migrar-harness-0-7.prompt.md` para migrar cualquier version previa a 0.7.0.
- `prompts/usuario-contrato-reentry.prompt.md` para que el operador pueda exigir contrato, compactacion y re-entry cuando un agente pierde foco.
- Campos de `project_root`, `harness_path`, `binding_status`, `external_write_scope` e invalidacion en approval/preflight.

### Changed
- El fallback local ya no permite usar cualquier `.hebrinex` disponible. Solo puede usarse una fuente libre `source_template`, copiarla al proyecto y vincularla antes de operar.
- `session-contract.md` separa `bootstrap` de `operation` y bloquea operar con un harness ubicado fuera de la raiz del proyecto activo.
- `init.sh` valida `PROJECT_BINDING.yaml`, imprime binding/ruta/version y detecta mismatch de proyecto cuando el harness esta `bound`.
- `AGENTS.md` y `README.md` quedan alineados a resolucion estricta y re-entry post-compactacion.

### Rationale
- Cambio motivado por auditorias de uso en SIA Actualizaciones, SIA Charts y Network/WAF Sentinels: el patron recurrente fue abandono del harness por compactacion, APRs no estrictos y riesgo de tomar un `.hebrinex` de otra carpeta. 0.7.0 convierte ese riesgo en hard lock operativo.

## [0.6.0] - 2026-05-23

### Added
- `HARNESS_VERSION` para declarar version operativa del harness.
- `agent-role-taxonomy.md` con roles minimos, perfiles parametrizados y regla anti-explosion de agentes.
- Templates P0: `clarification-checklist.md`, `analysis-checklist.md`, `blast-radius.md`, `task-graph.yaml`, `agent-profile-template.yaml` y `detractor-pass.md`.
- Roles `auditor.md` y `reporter.md` para separar auditoria, contradiccion tecnica y comunicacion al operador.
- Anti-confirmation bias y detractor pass como controles contra errores del usuario y de los agentes.

### Changed
- `multiagent-protocol.md` incorpora subgates G1A/G1B/G1C/G2A/G5A, roles minimos, perfiles y registry Kanban.
- `global-rules.md`, `AGENTS.md`, `context-profiles.md`, `registry.yaml`, `state.schema.yaml` e `init.sh` quedan alineados al P0 de 0.6.0.
- Se corrigen literales rotos de salto de linea en contratos y perfiles.


## [0.5.0] - 2026-05-21

### Added
- Artefactos P0 estructurados para que el harness no dependa solo de Markdown: `state.yaml`, `registry.yaml`, templates de approval, preflight, verification matrix, final report y agent closure.
- `tool-policy.yaml`, `command-taxonomy.md`, `write-set-policy.md` y `secret-denylist.md` para gobernanza deny-by-default de tools, comandos, escritura, red, git y secretos.
- Template de `audit.jsonl` y `gate-log.yaml` por ciclo para trazabilidad append-only y gates validables.
- Ciclo de cierre de agentes como P0 obligatorio mediante `G6_agent_closure_complete`.
- `future-p1.md` para listar mejoras candidatas de version futura sin activarlas todavia.

### Changed
- `AGENTS.md`, `session-contract.md`, `multiagent-protocol.md`, `permissions.md`, `context-profiles.md` y `progress/_README.md` ahora tratan estado estructurado, preflight, evidence schema y cierre de agentes como parte del contrato operativo.
- `init.sh` valida los nuevos artefactos P0.
## [0.4.0] - 2026-05-21

### Added
- `orquestador/method/session-contract.md` como contrato obligatorio de arranque, hard locks y correccion de desvios.
- Bootstrap obligatorio de sesion con chat como interprete, leader visible, modo, fase/slice y aprobacion requerida.
- Referencia explicita a `Nicolas-Melluso/Nox-Harness` como benchmark metodologico para reforzar contrato operativo, write-set, evidencia y gobierno del propio harness.

### Changed
- `AGENTS.md` ahora declara que `.hebrinex` es vehiculo operativo completo, no referencia opcional.
- `multiagent-protocol.md` separa chat/interprete de leader y exige leader visible para despachar o cerrar fases.
- `operating-modes.md` endurece modo manual por defecto para escritura, comandos, subagentes, git y red.
- Prompts de `leader`, `worker`, `implementer` y `reviewer` bloquean mezcla de roles y exigen handoffs.
- `init.sh` valida la existencia y referencia del contrato de sesion.
## [0.3.0] - 2026-05-19

### Added
- `orquestador/context-profiles.md` con perfiles de carga por rol para reducir contexto.
- `orquestador/method/global-rules.md` para centralizar reglas repetidas.
- `orquestador/sdd/specs/bootstrap-harness.md` conserva la spec larga de bootstrap fuera del prompt diario.

### Changed
- Prompts de `leader`, `spec_author`, `implementer`, `reviewer` y `crear-harness` reducidos para referenciar perfiles y reglas globales.
- README y AGENTS ahora indican no cargar todo `.hebrinex` por defecto.
## [0.2.0] - 2026-05-19

### Added
- Modos de operacion `automatico` y `manual` con aprobacion humana explicita.
- Protocolo multiagente con limite de 5 agentes activos totales: 1 leader + 4 subagentes.
- Registry, blocked queue y locks de ownership bajo `orquestador/sdd/progress/`.
- Guia `ai-engineering.md` para separar dominio, workflows, prompts, LLM client, tools, retries, validacion, cache y observabilidad.

### Changed
- `AGENTS.md` ahora usa rutas canonicas bajo `.hebrinex/orquestador/`.
- Politicas de permisos y riesgo distinguen aprobacion humana vs escalada al leader.
- `init.sh` valida nuevos contratos, archivos vacios, rutas obsoletas y placeholders operativos.

## [0.1.0] - 2026-05-19

- Bootstrap inicial del harness.
