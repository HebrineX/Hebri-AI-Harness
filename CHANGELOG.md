# Changelog

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
