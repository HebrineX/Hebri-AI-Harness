# Changelog

## [Unreleased]

## [0.17.1] - 2026-08-07

### Fixed
- Claude Code ya no depende solo de hooks o memoria del host: `CLAUDE.template.md` incluye bootstrap persistente con resolucion de harness, kernel minimo y reglas no negociables.
- `scripts/install-host-integrations.ps1 -HostName claude` instala `CLAUDE.md` ademas de los subagentes nativos.
- `scripts/install-claude-hooks.ps1 -Apply` instala/actualiza `CLAUDE.md` y mergea `.claude/settings.json`, resolviendo rutas bound/source-template.
- `scripts/validate-harness.ps1` valida funcionalmente la instalacion Claude y evita repetir `audit-harness.ps1` como agregador duplicado.

## [0.17.0] - 2026-08-03

### Added
- `SHARED_MANIFEST.yaml` como contrato versionado para consumidores: `shared_dirs` reemplaza listas hardcodeadas de cache compartida, `instance_dirs` declara copia real por proyecto e `instance_path_map` documenta la migracion desde rutas legacy 0.16.x.
- Carpeta canonica `instance/` para estado por proyecto, con README operativo y ruta de migracion `orquestador/migration/versions/0.16.0-to-0.17.0.yaml`.

### Changed
- `harness-resolution.md` ahora exige que las CLIs consumidoras lean `SHARED_MANIFEST.yaml` antes de decidir junction/symlink vs copia real.
- `update-bound` preserva estado legacy y copia binding, progreso, memoria, specs reales, backups/reportes, runtime generado y overrides MCP locales hacia `instance/` sin romper `binding_mode: bound`.
- Runtime, MCP y validadores resuelven rutas con compatibilidad: prefieren `instance/` si existe y caen a la estructura 0.16.x durante migracion.

## [0.16.0] - 2026-07-05

### Added
- Agentes de rol multiplataforma via daemon MCP (la via AGNOSTICA del host de IA): tools `agent_audit(plan_or_diff)` (rol detractor-senior; satisface el gate G3A) y `agent_review(diff, acceptance_criteria)` (rol reviewer; decision `aprobado | bloqueado`) en `mcp/server.mjs`. El daemon arma el prompt en runtime desde la fuente unica `agents/<rol>.md` (cortando las capas derivadas) y lo ejecuta con un backend read-only configurable en `mcp/agents-backend.yaml`: `claude-cli` (`claude -p --output-format json --allowedTools "Read,Grep,Glob"`, sintaxis verificada contra code.claude.com/docs/en/headless), `codex-cli` (`codex exec --sandbox read-only -`, verificada contra developers.openai.com/codex; el sandbox read-only es ademas el default de `codex exec`, sin limite que documentar) o `none` (falla con `agents_backend_not_configured` + instrucciones). El comando del backend es un string FIJO y el prompt viaja por stdin (sin interpolacion de shell). Interfaz abierta para backends nuevos (ollama, fase siguiente): una entrada en la config + una en el registro `BACKENDS` de `mcp/agent-backends.mjs` (nuevo), sin tocar las tools. Override por maquina git-ignored `mcp/agents-backend.local.yaml` (backend/timeout/comandos; para CLIs fuera de PATH). Veredicto parseado de la salida obligatoria del rol (`Veredicto:` / `Resultado:` / `Decision:`) + salida cruda. Demo real via daemon con backend `codex-cli`: plan "agregar libreria yaml" -> `bloquear`; diff de prueba -> `bloqueado` (evidencia en `orquestador/sdd/progress/evidence/mcp-dogfood-fase8.md`).
- Proyeccion nativa OPCIONAL para Claude Code (subagentes reales, tools enforceadas por el host): `orquestador/integrations/claude/agents/auditor-detractor.md` y `reviewer.md`, generados por el instruction-builder desde bloques `<!-- hebrinex:generate claude-agent -->` en las MISMAS fuentes unicas (`agents/detractor-senior.md`, `agents/reviewer.md`; secciones `native_agents`/`host_instructions` nuevas en `instruction-registry.yaml`). Frontmatter con `tools: Read, Grep, Glob` (solo lectura). Cubiertos por el drift-check del builder.
- Instalador `scripts/install-host-integrations.ps1 -HostName claude|cursor|copilot -CheckOnly|-Apply` (mismo patron que install-claude-hooks): copia los templates generados al proyecto consumidor (`.claude/agents/`, `.cursor/rules/hebrinex.mdc`, `.github/copilot-instructions.md`).
- Adapters nativos generados para Cursor y Copilot desde los MISMOS fragments que AGENTS.md (kernel + preflight + denylists + roles + puntero al daemon MCP como runtime recomendado): `orquestador/integrations/cursor/rules/hebrinex.mdc` (formato `.mdc` con frontmatter `alwaysApply: true`, verificado contra docs de Cursor) y `orquestador/integrations/copilot/copilot-instructions.md` (deteccion automatica en VS Code, verificado contra docs de GitHub).
- `orquestador/portability/mcp-hosts.md`: conexion del daemon MCP por host con snippets verificados por WebSearch 2026-07-05 y fuente citada (Claude Code `.mcp.json`, Cursor `.cursor/mcp.json`, Codex `~/.codex/config.toml [mcp_servers]`, VS Code/Copilot `.vscode/mcp.json` con clave `servers`, Gemini CLI `.gemini/settings.json`, Qwen Code `.qwen/settings.json`; DeepSeek sin via oficial documentada) + verificacion post-conexion minima (13 tools).
- Investigacion de adapters `orquestador/sdd/specs/adapter-investigation-2026-07.md` (fecha y fuente por hallazgo). Vaporware muerto: Codex CLI tiene hooks de lifecycle ESTABLES (engine estable desde v0.124.0: `hooks.json` / `[hooks]` en config.toml) y MCP; Cursor tiene hooks reales desde 1.7 (`.cursor/hooks.json`); Qwen Code tiene `QWEN.md` jerarquico + hooks + MCP; el CLI oficial de DeepSeek (Deep Code) NO documenta hooks/MCP/instrucciones persistentes (solo Agent Skills). Ningun adapter queda en `hook_support: unknown`.
- Gate G3A con tres vias validas documentadas en `orquestador/method/minimal-implementation-policy.md`: daemon MCP (`agent_audit`, recomendada/agnostica), subagente nativo (hosts con subagentes reales) y simulacion manual trazable (fallback universal, NO se borra). Las tres derivan de la misma fuente unica.
- Fixture negativo `orquestador/testing/fixtures/negative/claude-agent-write-tool.md` (subagente nativo con tool de escritura): `check-adapter-drift.ps1` DEBE detectarlo (self-test) y `validate-fixtures.ps1` lo exige.
- Ruta de migracion `orquestador/migration/versions/0.15.0-to-0.16.0.yaml` + entrada en `migration-registry.yaml` (apply requiere: tools agent_audit/agent_review, config de backends, instalador de integraciones, templates nativos generados y adapters sin `unknown`).

### Changed
- Los 8 `orquestador/adapters/*.yaml` + `adapter-matrix.yaml` declaran ahora `maturity` (production: claude-code, codex, generic-ai; experimental: cursor, copilot, gemini, qwen, deepseek), `role_agents` (`native_subagents_or_mcp_daemon` | `via_mcp_daemon` | `prompt_simulation`), `mcp_config_file`, `investigated_at: "2026-07-05"` e `investigation` (puntero al doc). `claude-code.yaml`: `supports_real_subagents: true` + `subagent_roles: [auditor, reviewer]`. `qwen.yaml`: `QWEN.md` + hooks yes. `deepseek.yaml`: `host_prompt_or_skills` + hooks no. `codex.yaml`: hooks yes con la lista real de eventos. `cursor.yaml`: `.cursor/rules/hebrinex.mdc` + hooks yes. `adapter.schema.yaml` exige las claves nuevas; notas de los `.md` de adapters actualizadas con mecanismo real y fecha.
- `scripts/build-instructions.ps1`: parser generico de secciones del registry (`Get-RegistrySectionEntries`), insercion de aviso GENERATED post-frontmatter (`Add-GeneratedNotice`, reutilizada por prompts/agentes) y generacion de los 4 derivados nuevos (2 subagentes nativos + reglas Cursor + instrucciones Copilot); el drift-check default los cubre.
- `scripts/check-adapter-drift.ps1`: exige `maturity`/`role_agents`/`investigated_at` en cada adapter, prohibe `hook_support: unknown` (adapters y matrix), exige `supports_real_subagents: true` + roles en claude-code, y verifica que los subagentes nativos (templates del harness y `.claude/agents/` si existe) declaren SOLO tools read-only, con self-test contra el fixture negativo.
- `scripts/validate-mcp.ps1`: exige las 13 tools (incluye `agent_audit`/`agent_review`), `mcp/agents-backend.yaml` (schema, backend valido, comandos read-only con `--allowedTools "Read,Grep,Glob"` y `--sandbox read-only`), error claro sin backend, prompts desde las fuentes unicas, stdin en el modulo de backends y las entradas nuevas del manifest. `mcp/smoke.mjs`: 13 tools + negativos (`agent_audit` con backend `none` -> `agents_backend_not_configured`; `agent_review` con backend desconocido -> `agents_backend_unknown` listando los conocidos); no corre backends reales (costo/latencia no deterministas).
- `scripts/validate-migration.ps1`: regex de versiones extendida a 0.16, asserts de la ruta 0.15.0-to-0.16.0 y el contrato post-migracion apunta a 0.16.0.
- `mcp/README.md`: tabla con las 13 tools + seccion de backends de agentes de rol; conexion por cliente apunta a `orquestador/portability/mcp-hosts.md`.
- README: novedades 0.16.0 y tabla de adapters con maturity y via recomendada.

### Fixed
- hebrinex usage ahora resuelve Root a path absoluto y mide archivos con System.IO en vez del provider de PowerShell, evitando que GitHub Actions/Linux falle al recomputar savings_docs_pct cuando el manifest incluye .gitattributes. (Fix hecho tras el tag 0.15.0; sale en este release. Baseline `usage-baseline-0.15.0.yaml` recalculado: full_tree 225233 -> 245575 tokens.)

## [0.15.0] - 2026-07-05

### Added
- Locks ejecutables: `hebrinex lock -Acquire|-Release|-List` (contrato CLI sube a `0.5`). `-Acquire` crea `L-*.lock.md` en `orquestador/sdd/progress/locks/` con owner, paths, TTL (`-TtlMinutes`, default 120) y `status: active`; adquirir un path que se solapa (igualdad o prefijo de directorio) con un lock activo no vencido falla con `lock_conflict` nombrando el lock duenio. `-Release` marca `status: released` (+`released_at`); `-List` inventaria activos/vencidos reutilizando `Get-LockInventory` del modulo comun (que ahora expone owner y paths por lock). Helpers nuevos en `hebri-common.psm1`: `Test-LockPathOverlap`, `Find-LockForPath`, `New-HarnessLock`, `Set-HarnessLockReleased`.
- Hook PreToolUse para ediciones (`scripts/claude-writeguard-hook.ps1`, matcher `Edit|Write|NotebookEdit` en ambos settings): valida el `file_path`/`notebook_path` del tool input contra (a) la seccion nueva `claude_hook_protected_paths` de `orquestador/security/write-scope-registry.yaml` (`PROJECT_BINDING.yaml`, `HARNESS_VERSION`, `approvals/`, `locks/`) -> `permissionDecision=ask` con el motivo, (b) locks activos no vencidos -> `ask` con el `lock_id`, (c) resto (incluidos paths fuera del root) -> defer al flujo normal de permisos. Fail-open (exit 0 sin output) ante errores del propio hook.
- Hook `Stop` (`scripts/claude-stop-hook.ps1`): al terminar cada turno revisa locks activos/vencidos, approvals vigentes sin consumir, ciclo activo sin cerrar y `HANDOFF-*` pendientes; si hay algo abierto emite `systemMessage` con la lista (advierte, no bloquea el stop); si todo esta limpio, silencio.
- Hook `PreCompact` (`scripts/claude-precompact-hook.ps1`): antes de compactar corre la verificacion del memory-closure-checklist (misma logica que `close_cycle_check`) y emite el resumen de lo que quedaria sin cerrar, para persistir a archivos antes de perder memoria.
- Rate limiting del gateway: ventana deslizante sobre ejecuciones `-Apply` permitidas, persistida en `orquestador/runtime/gateway-rate.json` (estado runtime generado: gitignoreado, fuera del manifest; su ausencia resetea la ventana). Limite configurable en `command-risk-registry.yaml` (`rate_limit: apply_max_per_window: 30, window_seconds: 60`). Excedido -> `decision=block`, `reason=rate_limit_exceeded` (exit 2). `CheckOnly` es clasificacion pura y no se limita; los blocks no consumen cupo.
- Identidad de rol via MCP (honesta): tool `role_assume(role_id)` valida contra `agent-registry.yaml` y guarda el rol en el estado del proceso del daemon; las tools con efecto consultan `agent-runtime.ps1` con ESE rol (`run_command`: `run_local_validation` o `run_readonly_audit`; `lock_acquire`/`lock_release`: `edit_approved_write_set`) y fallan con `role_capability_blocked` si el rol no tiene la capability. Tools MCP `lock_acquire`/`lock_release` envuelven `hebrinex lock`. Sin `role_assume` previo las tools funcionan sin check de rol y lo exponen como `role_enforced=false`. Limite residual documentado en `orquestador/agents/README.md` (nuevo): el CLI directo sigue aceptando `-RoleId` autodeclarado; la garantia fuerte existe solo via MCP.
- Ruta de migracion `orquestador/migration/versions/0.14.0-to-0.15.0.yaml` + entrada en `migration-registry.yaml`.

### Changed
- `hooks-policy.md` ya no lista hooks "recomendados no implementados": los cinco hooks (SessionStart, PreToolUse x2, Stop, PreCompact) estan implementados y documentados; `install-claude-hooks.ps1` instala los cinco scripts y ambos matchers de PreToolUse.
- `scripts/validate-cli.ps1` cubre el comando `lock` (roundtrip acquire/list/conflict/release, negativos `lock_conflict`, `lock_not_found`, modos exclusivos) y el contrato `0.5`; `scripts/validate-command-gateway.ps1` cubre `rate_limit_exceeded` (llenando la ventana sin tocar config, CheckOnly no limitado, reset al borrar el estado); `scripts/validate-mcp.ps1` exige las 11 tools, el rol en estado del daemon y que las tools de lock envuelvan el CLI; `mcp/smoke.mjs` ejercita locks (acquire/conflicto/release), `role_assume` (rol invalido, reviewer bloqueado por capability, implementer ok con owner=rol del daemon) y limpia sus archivos de lock.
- `scripts/validate-harness.ps1` exige los hooks nuevos en `settings.template.json`, los tres scripts nuevos en el manifest y que `gateway-rate.json` NO este en el manifest; marker CLI `0.5`.
- `scripts/validate-migration.ps1` soporta 0.15.x y exige la ruta y el contrato post-migracion 0.15.0.

### Fixed
- `hebrinex usage` ahora resuelve `Root` a path absoluto y mide archivos del manifest con `System.IO`, evitando fallas de provider en GitHub Actions/Linux al recomputar `savings_docs_pct` cuando el manifest incluye `.gitattributes`.
- `validate-harness.ps1` y las rutas CLI de bootstrap/update-bound/backups/restore ahora validan archivos del manifest con `System.IO`, evitando falsos faltantes de dotfiles (`.gitattributes`, `.gitignore`, `.mcp.json`) en bound harnesses bajo GitHub Actions/Linux.

### Added
- `hebrinex usage` (CLI, contrato publico sube a `0.4`): mide en tokens estimados (chars/4, mismo metodo que `budget`) el kernel minimo (binding + session-pin + memory-registry + memory-routing + context-budget + entrypoint first-message), cada perfil de `context-budget.yaml` (los perfiles con read-set dinamico — `leader_full`, `audit_global`, `adapter_portability` — se reportan `dynamic`, no se inventan file-sets), la documentacion operativa (`AGENTS.md` + `method/` + `prompts/` segun manifest) y el arbol completo declarado en `orquestador/harness-manifest.txt`. Markers parseables: `kernel_tokens=`, `docs_tree_tokens=`, `savings_docs_pct=`, `full_tree_tokens=`, `savings_pct=` (enteros) y una linea `profile_<name>_tokens=` por perfil. Read-only (`writes=false`).
- Tool MCP `session_usage` (`mcp/server.mjs`): parsea los transcripts JSONL de Claude Code del proyecto (`~/.claude/projects/<proyecto>/*.jsonl`) y reporta para la sesion mas reciente (o un `session_id` dado) tokens in/out/cache totales y por modelo (con desglose cache 5m/1h), turnos y costo estimado en USD. Precios por modelo en `mcp/model-pricing.yaml` (tabla editable, nada hardcodeado). Sin transcripts falla con error claro (`transcripts_dir_not_found` / `transcript_not_found`), no inventa datos. Probada contra una sesion real de esta fase.
- `mcp/model-pricing.yaml`: tabla de precios editable (USD por millon de tokens, con `cache_read`/`cache_write_5m`/`cache_write_1h`); match de modelo por prefijo mas largo para cubrir ids con sufijo de fecha.
- Baseline de consumo `orquestador/sdd/progress/evidence/usage-baseline-0.14.0.yaml`: snapshot de kernel_tokens, tokens por perfil, full_tree_tokens y savings_pct medido; la fase de poda metodologica (0.17.0) demostrara su ahorro con diff contra este archivo.
- Ruta de migracion `orquestador/migration/versions/0.13.0-to-0.14.0.yaml` + entrada en `migration-registry.yaml`.

### Changed
- El README deja de declarar el objetivo anterior de ahorro de contexto como claim sin medir: ahora cita un porcentaje conservador respaldado por medicion ("ahorro medido: 90% (hebrinex usage)", medido: 94% frente a la documentacion operativa completa y 99% frente al arbol completo del manifest). `validate-release.ps1` recalcula `savings_docs_pct` invocando `hebrinex usage` y falla si el numero del README difiere en mas de ±5 puntos del medido - el denominador del claim es la documentacion operativa, no el arbol completo, para no inflar el numero comparando contra package-lock y codigo.
- `scripts/validate-cli.ps1` cubre `usage` (markers, perfiles medidos/dynamic, rango 0-100 de savings_pct) y el contrato `0.4`; `scripts/validate-mcp.ps1` exige `session_usage`, `mcp/model-pricing.yaml` (sin precios en el codigo) y errores claros sin transcripts; `mcp/smoke.mjs` valida las 8 tools y ejercita `session_usage` (datos reales o error claro, nunca datos inventados).
- `scripts/validate-migration.ps1` soporta 0.14.x y exige la ruta y el contrato post-migracion 0.14.0.

## [0.13.1] - 2026-07-05

### Fixed
- `validate-bootstrap.ps1` now validates bootstrapped bound harnesses with `validate-harness.ps1 -SkipNestedValidators`, avoiding recursive/source-template validation inside `.hebrinex` while preserving full validation for the source template.
- Bound validator failures in `hebrinex.ps1` now include the last validator output lines instead of only `exit_code`, making CI failures actionable.

### Added
- Migration route `orquestador/migration/versions/0.13.0-to-0.13.1.yaml` for the bootstrap/bound validation hotfix.

## [0.13.0] - 2026-07-05

### Added
- Daemon MCP "hebrinex" (`mcp/server.mjs`, SDK oficial `@modelcontextprotocol/sdk`, transporte stdio) que envuelve los scripts PowerShell existentes: `run_command` (unica via de ejecucion, via command gateway `-Apply`; block => la tool falla con reason y preflight generado), `preflight_approve` (crea envelopes via `hebrinex approve -Apply`, devuelve `approval_id` + expiracion), `approval_check` (valida un id contra el almacen via gateway CheckOnly), `session_contract` (contrato de sesion armado desde PROJECT_BINDING/state/registry/budget dentro del presupuesto `leader_light`), `gate_check` (clasifica gates G5B..G5I segun `git status/diff` read-only), `memory_route` (decide first_message | reentry_light | debug_log_intake | compactation_recovery segun estado real) y `close_cycle_check` (verifica memory-closure-checklist antes de `done`).
- `.mcp.json` registra el daemon para Claude Code; `mcp/README.md` documenta la conexion desde Cursor (`.cursor/mcp.json`) y Codex CLI (`~/.codex/config.toml`): un solo daemon local en lugar de 8 adapters de prompt.
- `mcp/smoke.mjs`: smoke test MCP real (cliente stdio) que valida las 7 tools, el block de comandos peligrosos y el rechazo de approvals inexistentes.
- `scripts/validate-mcp.ps1`: valida estructura del daemon siempre y corre el smoke solo si hay `node` y dependencias instaladas (skip limpio si no); integrado en `init.sh` y CI (step "MCP daemon").
- `agents/worker.md`: fuente narrativa del rol worker (antes solo existia como contrato y prompt derivados).
- Ruta de migracion `orquestador/migration/versions/0.12.0-to-0.13.0.yaml` + entrada en `migration-registry.yaml`.

### Changed
- Deduplicacion de capas de roles: `agents/<rol>.md` es la fuente unica; `orquestador/agents/role-contracts/*.yaml`, `prompts/roles/*.prompt.md` y el bloque `role_defaults` de `capability-registry.yaml` se generan con `scripts/build-instructions.ps1 -WriteOutputs` desde bloques marcados (`<!-- hebrinex:generate contract|role-defaults|prompt -->`). Semantica de roles sin cambios (los derivados solo suman avisos GENERATED).
- `scripts/build-instructions.ps1`: el modo default ahora es drift-check real (exit 2 listando derivados editados a mano); `-WriteOutputs` regenera los 13 derivados. `instruction-registry.yaml` declara `role_sources` y `role_defaults_target`.
- `scripts/validate-drift.ps1` exige el wiring `role_sources` e invoca el builder en modo check; `scripts/validate-agent-contracts.ps1` exige el header GENERATED en cada contrato y los bloques fuente en cada `agents/<rol>.md`.

## [0.12.0] - 2026-07-05

### Added
- Approval store ejecutable: `hebrinex approve -CheckOnly|-Apply` crea envelopes en `orquestador/sdd/progress/approvals/` con expiracion (`-TtlMinutes`) y hash SHA256 de la accion exacta.
- Command Gateway valida `-ApprovalId` contra el almacen: bloquea `approval_not_found`, `approval_expired`, `approval_not_approved`, `approval_command_mismatch`; el resultado expone `approval_status`/`approval_reason` (schema `0.4`).
- Hooks reales de Claude Code: `SessionStart` genera e inyecta el reentry brief; `PreToolUse` (`scripts/claude-pretooluse-hook.ps1`) clasifica Bash/PowerShell con el gateway (`allow` read-only seguro, `ask` para patrones bloqueados, defer para el resto). `.claude/settings.json` activo en el repo y `settings.template.json` con schema real de hooks.
- `scripts/install-claude-hooks.ps1` ahora instala de verdad (`-CheckOnly|-Apply`), mergeando hooks en `<project_root>/.claude/settings.json`.
- Modulo comun `scripts/lib/hebri-common.psm1` (YAML helpers, redaccion, approval store, inventario de locks) usado por gateway, CLI y reentry.
- `hebrinex status` reporta `open_locks`/`expired_locks` desde `orquestador/sdd/progress/locks/`.
- `orquestador/adapters/_shared-core.md`: cuerpo comun unico de adapters; los 8 `<host>.md` quedan como punteros con notas especificas.

### Changed
- La CLI publica sube a contrato `0.3` y expone `approve`.
- `context-budget.yaml` documenta el metodo de medicion (chars/4, solo kernel) y sincera `runtime_status` a 1000 tokens (medido: ~958).
- `claude-reentry.ps1/.sh` enriquecen el brief (binding, contrato, ciclo, locks) y lo emiten por stdout para inyeccion en contexto.

### Security
- Apply del gateway rechaza symlinks/junctions bajo el root (`symlink_not_allowed_in_apply`).
- El timeout de Apply mata el arbol de procesos completo (proceso hijo dedicado + `Kill(true)`/`taskkill /T`), no solo el job.
- Un `ApprovalId` inventado ya no se reporta como valido: bloquea la llamada.

## [0.11.0] - 2026-07-02

### Added
- `scripts/state-machine.ps1` para decidir transiciones permitidas desde `lifecycle-registry.yaml`.
- `scripts/agent-runtime.ps1` para aplicar enforcement runtime de roles, contratos y capabilities.
- Validadores `validate-state-machine.ps1` y `validate-agent-runtime.ps1` con pruebas negativas.
- Schemas/templates JSON de decisiones runtime y fixtures positivos/negativos de enforcement.
- Ruta declarativa `0.10.11 -> 0.11.0` en el servicio de migracion.

### Changed
- La CLI publica sube a contrato `0.2` y expone `state-machine` y `agent-runtime`.
- `validate-harness`, `audit-harness`, `init.sh`, `validate-release` y GitHub Actions exigen validacion de runtime enforcement.
- `release-roadmap.md` marca cerrado el hito Enforcement Release cuando pasan CLI, gateway, state machine, agent runtime, migracion y CI.

### Security
- Reviewer no puede obtener capability de escritura en runtime, implementer no aprueba y transiciones invalidas quedan bloqueadas por decision ejecutable.
- 0.11.0 deja de depender solo de reglas declarativas: el harness puede emitir decisiones machine-readable para capabilities y lifecycle.
## [0.10.11] - 2026-07-01

### Added
- `orquestador/method/cli-contract.md` como contrato publico de CLI estable.
- `scripts/validate-cli.ps1` para validar comandos publicos, markers parseables,
  modos `CheckOnly`/`Apply`, salida JSON del Command Gateway y negativos de modo.

### Changed
- `hebrinex.ps1 help` emite `cli_contract_version=0.1`, `cli_status=stable` y
  la lista cerrada de comandos publicos.
- `validate-harness.ps1`, `audit-harness.ps1`, `init.sh`, `validate-release.ps1`
  y GitHub Actions integran `validate-cli.ps1 -RunNegativeTests`.
- `release-roadmap.md` corrige la reconciliacion 0.10.x y mueve el corte de
  `0.11.0` despues de `0.10.11`.
- `README.md` documenta la CLI estable y todos los comandos publicos.

### Security
- La CLI queda bloqueada por contrato: comandos fuera del set estable no son
  superficie publica, los comandos con modo exigen exactamente un modo y
  `list-bound-backups` queda solo `CheckOnly`.
- `command -CheckOnly -Json` queda validado como no ejecutable y delegado al
  resultado estructurado `hebrinex.command_gateway.result`.

## [0.10.10] - 2026-07-01

### Added
- CI oficial en `.github/workflows/ci.yml` con job `Harness contract` para
  `pull_request` y `push` a `main`.
- `orquestador/method/release-roadmap.md` para reconciliar el desvio de
  numeracion 0.10.7/0.10.8/0.10.9 y fijar el corte hacia `0.11.0`.

### Changed
- `validate-release.ps1` valida que el source template tenga CI oficial con
  `validate-harness`, `audit-harness`, drift check, fixtures de migracion,
  fixtures negativos de seguridad e `init.sh`.
- `init.sh` valida la presencia y cobertura minima del workflow oficial cuando
  el harness esta en modo `source_template`.
- `README.md` documenta el check `Harness contract` y el requisito de branch
  protection para bloquear merges que rompan contrato, agentes, seguridad o
  migracion.

### Security
- CI ejecuta `validate-harness.ps1 -RunNegativeTests`,
  `audit-harness.ps1 -RunNegativeTests`, `check-adapter-drift.ps1`,
  validadores de migracion, fixtures negativos de seguridad, Command Gateway e
  `init.sh`.
- `0.10.10` deja cerrada la linea correctiva 0.10.x antes del enforcement
  release `0.11.0`.

## [0.10.9] - 2026-07-01

### Added
- `hebrinex.ps1 list-bound-backups -CheckOnly -ProjectRoot <path>` para
  inventariar backups disponibles en un harness bound antes de restaurar.
- `scripts/validate-bound-backups.ps1` con smoke end-to-end: bootstrap
  temporal, `update-bound`, backup valido, backup corrupto controlado y
  verificacion de inventario read-only.
- Ruta `bound-backup-inventory` en `migration-registry.yaml`.

### Changed
- `validate-harness.ps1`, `audit-harness.ps1`, `init.sh` y
  `harness-manifest.txt` integran `validate-bound-backups.ps1`.
- El flujo `restore-bound` queda complementado por una inspeccion previa de
  `BackupId` restaurables.

### Security
- El inventario marca como no restaurables backups sin `backup-manifest.txt`,
  sin `files/`, con paths inseguros, traversal, rutas excluidas o archivos
  faltantes.
- `list-bound-backups` es exclusivamente `CheckOnly`, reporta `writes=false`
  y no modifica el bound harness.
- La salida distingue `backup_restorable=true|false`, version capturada,
  cantidad de entradas, archivos restaurables, manifest y motivo de rechazo.

## [0.10.8] - 2026-07-01

### Added
- `hebrinex.ps1 restore-bound -CheckOnly|-Apply -ProjectRoot <path> -BackupId <id>`
  para restaurar un harness bound desde un backup previo de `update-bound`.
- `scripts/validate-bound-restore.ps1` con smoke end-to-end: bootstrap
  temporal, update con backup, restore `CheckOnly`, restore `Apply`,
  preservacion del binding y validacion del harness bound restaurado.
- Reporte aplicado `migration-bound-restore-*.yaml` con backup previo al
  restore, `source_backup_id` y resultados de validadores.

### Changed
- `validate-harness.ps1`, `audit-harness.ps1`, `init.sh` y
  `harness-manifest.txt` integran `validate-bound-restore.ps1`.
- `migration-registry.yaml` declara la ruta `bound-restore-from-backup`.

### Security
- `restore-bound` rechaza `BackupId` inseguros, traversal, rutas absolutas y
  backups fuera de `orquestador/migration/backups/`.
- `restore-bound Apply` crea backup pre-restore antes del primer write.
- `restore-bound Apply` restaura solo archivos listados en el
  `backup-manifest.txt` del backup seleccionado.
- El restore es no destructivo (`deletes_extra_files: false`) y corre
  validadores antes de declarar `restore_status=applied`.

## [0.10.7] - 2026-07-01

### Added
- `hebrinex.ps1 update-bound -CheckOnly|-Apply -ProjectRoot <path>` para
  actualizar un harness bound existente desde el source template.
- `scripts/validate-bound-update.ps1` con smoke end-to-end: bootstrap temporal,
  simulacion de version anterior, `update-bound CheckOnly`, `update-bound Apply`,
  verificacion de preservacion y validacion del harness bound actualizado.
- Reporte aplicado `migration-bound-update-*.yaml` y backup manifest para
  actualizaciones source_template -> bound.

### Changed
- `validate-harness.ps1`, `audit-harness.ps1`, `init.sh` y
  `harness-manifest.txt` integran `validate-bound-update.ps1`.
- `migration-registry.yaml` declara la ruta
  `bound-update-source-template-to-bound` y suma el validador de update-bound.

### Security
- `update-bound Apply` copia solo rutas declaradas en `harness-manifest.txt`.
- `update-bound Apply` preserva `PROJECT_BINDING.yaml`, state, registry,
  cycles, locks, approvals, memoria local/proyecto y evidencia de migracion.
- `update-bound Apply` exige backup antes del primer write y rechaza targets
  que no sean `.hebrinex` bound validos del proyecto consumidor.
- El update corre validadores del bound antes de declarar `update_status=applied`.

## [0.10.6] - 2026-07-01

### Added
- `hebrinex.ps1 bootstrap -Apply` para copiar un harness `source_template`
  hacia `<project_root>/.hebrinex` y dejarlo en modo `bound`.
- `scripts/validate-bootstrap.ps1` con smoke `CheckOnly`, smoke `Apply`,
  validacion de contrato post-migracion y validacion del harness bound.
- Reporte aplicado `migration-bootstrap-*.yaml`, backup manifest y contrato
  post-migracion para bootstrap source_template -> bound.

### Changed
- `validate-harness.ps1`, `audit-harness.ps1` e `init.sh` integran
  `validate-bootstrap.ps1`.
- `validate-command-gateway.ps1` mantiene `git status --short` como read-only
  en `CheckOnly`, pero no exige ejecucion exitosa en `Apply` cuando el harness
  bound no contiene `.git`.

### Security
- Bootstrap Apply copia solo rutas declaradas en `harness-manifest.txt`.
- Bootstrap Apply excluye `.git`, `.codex`, `infoHebri.md`, temporales y
  archivos locales no declarados.
- Bootstrap Apply rechaza targets inseguros: root vacio, root inexistente,
  root igual/dentro del source, root apuntando a `.hebrinex` o target con
  `.hebrinex` existente.
- El proyecto consumidor queda con `.hebrinex/` agregado a `.gitignore`,
  `PROJECT_BINDING.yaml` bound, state/memory/active-contract regularizados y
  validadores ejecutados antes de declarar `bootstrap_status=applied`.

## [0.10.5] - 2026-06-30

### Added
- `command-gateway.ps1 -Apply` para ejecutar solo comandos read-only
  allowlisted mediante un plan controlado, no mediante shell arbitrario.
- Evidencia estructurada de ejecucion en `hebrinex.command_gateway.result`:
  `execution.attempted`, `exit_code`, `timed_out`, `timeout_seconds`,
  `stdout` y `stderr` redactados.

### Changed
- `hebrinex.ps1 command` acepta `-CheckOnly|-Apply` y delega ambos modos en
  el Command Gateway.
- Schema/template del resultado del Command Gateway pasan a version `0.3` y
  admiten `mode: Apply` sin permitir escrituras.
- `validate-command-gateway.ps1` cubre Apply seguro, traversal fuera del root,
  flags no permitidas, secretos, comandos compuestos y git remoto.

### Security
- `Apply` mantiene deny-by-default: bloquea comandos desconocidos, compuestos,
  secretos, red, git remoto, escrituras, destructivos y paths fuera del root.
- La ejecucion queda limitada a `Get-Content`, `Select-String`, `Test-Path`,
  `Get-ChildItem` y `git status --short`, con timeout y salida redactada.

## [0.10.4] - 2026-06-30

### Added
- `scripts/hebrinex.ps1` como CLI Core liviana para `status`, `budget`,
  `preflight`, `validate`, `audit`, `migrate` y `bootstrap -CheckOnly`.
- Schemas livianos para Agent Registry, Agent Role Contract, Security Policy y
  Migration Registry.
- Fixtures positivos/negativos y `scripts/validate-fixtures.ps1` para cubrir
  roles invalidos, red default allow, path traversal y CheckOnly con escrituras.
- `scripts/command-gateway.ps1` como Command Gateway inicial en modo
  `CheckOnly`, sin ejecucion arbitraria de comandos.
- `scripts/validate-command-gateway.ps1` y fixtures de comandos para cubrir
  comandos read-only, `Invoke-Expression`, pipes remotos, `git push`, borrado
  recursivo forzado y comandos desconocidos.
- Schema/template `hebrinex.command_gateway.result` para decisiones
  estructuradas del Command Gateway y preflight generado.
- Fixtures de secretos y mismatch de riesgo declarado para el Command Gateway.

### Changed
- `validate-harness.ps1` valida que la CLI exista, este en manifest y que sus
  comandos read-only basicos funcionen.
- `validate-harness.ps1` y `audit-harness.ps1` integran validacion de fixtures.
- `hebrinex.ps1` agrega el subcomando `command -CheckOnly` y delega la decision
  en el Command Gateway.
- `hebrinex.ps1 command -CheckOnly -Json` emite una decision parseable por
  maquina sin ejecutar comandos.

### Security
- El gateway falla cerrado: comandos desconocidos o compuestos quedan
  bloqueados hasta preflight/aprobacion explicita y no se ejecutan en esta rama 0.10.x.
- Comandos que apuntan a secretos quedan bloqueados aunque usen herramientas
  read-only; los valores sensibles se redactan en la salida estructurada.

## [0.10.0] - 2026-06-30

### Added
- Agent Contract System canonico en `orquestador/agents/`: registry de agentes, capabilities, lifecycle, role contracts, security profiles, handoff contracts, runtime profiles, context packs, tool packs, playbooks, failure modes, rubrics y adapter profiles.
- Seguridad AppSec verificable en `orquestador/security/`: threat model, permissions, command risk, write-scope, network, secrets, escalation, logging y supply-chain policies.
- Servicio de migracion en `orquestador/migration/` con rutas `0.9.0 -> 0.10.0` y `0.8.10 -> 0.10.0`, `CheckOnly`, `Apply` con backup, reportes y contrato post-migracion aplicado.
- Validadores `validate-agent-contracts.ps1`, `validate-security-policy.ps1`, `validate-migration.ps1` y `audit-harness.ps1`.

### Changed
- La version operativa actual pasa a 0.10.0.
- `validate-harness.ps1` e `init.sh` integran los nuevos validadores y bloquean drift de agentes, seguridad y migracion.
- `harness-manifest.txt`, `registry-index.yaml`, `policy-registry.yaml` y `gate-registry.yaml` registran los nuevos contratos canonicos.
- El contrato post-migracion queda aplicado con backup, reporte y validadores OK.

### Security
- La autoridad de definicion de agentes queda en `harness_only`: la IA no puede definir agentes, roles, permisos, capabilities ni escalaciones.
- Se explicitan controles contra command injection, path traversal, symlink escape, secret leak, network abuse, git remote abuse y supply-chain remote code.
- Reviewer sigue sin editar, implementer sigue sin aprobar y leader sigue sin implementar.

### Rationale
- El harness gobierna agentes pero no se comporta como agente: transforma cualquier IA en un agente acotado por contrato, runtime, herramientas, contexto, seguridad, handoff y evidencia.

## [0.9.0] - 2026-06-29

### Changed
- Reorganiza `prompts/` por responsabilidad: roles, session, adapters, migration, audit, runtime, bootstrap y workflows.
- Agrega `orquestador/prompt-registry.yaml` como indice canonico de prompts para evitar mezclar presets IA, migraciones y roles en una carpeta plana.
- Agrega registries canonicos para adapters, context profiles, gates, policies y templates, con `orquestador/registry-index.yaml` como indice general.
- Agrega `prompts/migration/migrar-harness-0-8-10-a-0-9-0.prompt.md` para guiar upgrades desde 0.8.10.
- Actualiza manifest, perfiles de contexto y validadores para usar las rutas nuevas y comprobar rutas declaradas en registries.

### Fixed
- Alinea el estado source-template al modo default `automatico`.
- Corrige el cierre del bloque YAML runtime en `orquestador/memory/local/session-pin.md`.
## [0.8.10] - 2026-06-17

### Changed
- Los context budgets pasan de hard gate inmediato a soft warning registrado; solo bloquean si el consumo supera 2x el presupuesto declarado.
- `init.sh` resuelve PowerShell con fallback `pwsh -> powershell.exe -> powershell` para Windows sin PowerShell Core.
- Version operativa actual a 0.8.10.

### Rationale
- El presupuesto debe guiar y registrar desvíos sin bloquear migraciones por prompts o metadatos apenas superiores al límite. El bloqueo queda reservado para exceso claro.
## [0.8.9] - 2026-06-17

### Fixed
- `regularize-state.ps1` ahora agrega gates requeridos en listas inline, listas YAML multilínea o cuando `required_gates` no existe.
- `init.sh` deja de bloquear referencias históricas válidas a versiones antiguas y limita el drift check a archivos operativos activos.
- Los presupuestos `memory_bootstrap` y `leader_light` ganan margen controlado para evitar fallos por notas mínimas de migración.

### Changed
- Version operativa actual a 0.8.9.
- Validadores, adapters, presets, schemas y templates activos quedan alineados a 0.8.9.

### Rationale
- La migración no debe exigir limpieza manual de historia ni edición artesanal de gates; el harness debe corregir schema drift repetible y validar solo contrato operativo vigente.

## [0.8.8] - 2026-06-17

### Added
- `scripts/regularize-state.ps1` para migrar `state.yaml` preservado desde versiones anteriores agregando keys/gates faltantes.
- `scripts/regularize-registry.ps1` para migrar `registry.yaml` preservado agregando `kanban_statuses`, `roles` y `profiles` sin borrar ciclos.

### Changed
- `build-instructions.ps1` usa `SHA256.Create().ComputeHash(...)`, compatible con Windows PowerShell 5.1.
- `init.sh` y `validate-harness.ps1` validan regularizers y bloquean APIs hash no compatibles.
- Version operativa actual a 0.8.8.

### Rationale
- La migracion de proyectos debe preservar estado local, pero tambien regularizar schema drift de forma guiada y auditable.

## [0.8.7] - 2026-06-16

### Added
- `orquestador/instruction-builder/` con registry, fragments y report templates.
- Scripts `build-instructions` en modo check-only y `validate-drift` con pruebas negativas.
- Schemas para instruction registry y Claude reentry state.

### Changed
- Version operativa actual a 0.8.7.
- Presets/adapters pasan a tener una fuente canónica verificable para reducir drift entre IAs.

### Rationale
- Evita que cada IA mantenga copias divergentes del contrato: el core vive en fragments y el drift validator bloquea versiones, targets y denylists inconsistentes.

## [0.8.6] - 2026-06-16

### Added
- Integracion Claude Code con templates de hooks, `CLAUDE.template.md` y reentry brief.
- Scripts `claude-reentry` e instaladores preflight-only para hooks Claude.
- Template `claude-reentry-state.yaml` para persistir estado de rehidratacion no autoritativo.

### Changed
- Version operativa actual a 0.8.6.
- Claude deja de depender de memoria interna: reentry se reconstruye desde archivos del harness.

### Rationale
- Reduce fallos donde Claude pierde foco del harness: hooks/brief obligan reentrada verificable sin cargar todo el contexto.

## [0.8.5] - 2026-06-16

### Added
- `orquestador/runtime/` como control plane liviano para status, reentry, modo, audit y budget.
- Templates JSON y schemas para `active-session`, comandos y reportes runtime.
- `prompts/runtime/harness-runtime.prompt.md` para interpretar comandos `/harness` sin cargar todo el contrato.

### Changed
- Version operativa actual a 0.8.5.
- Runtime queda declarado como cache no autoritativa; estado, registry, gates y evidencia siguen siendo la autoridad.

### Rationale
- Reduce reentry repetitivo y consumo de tokens: primero runtime/status, autoridad completa solo si entra en budget o hay aprobacion.

## [0.8.4] - 2026-06-16

### Added
- `orquestador/portability/` con core portable y adapter matrix multi-IA.
- Adapters `.yaml` para Claude Code, Codex, Gemini, Cursor, Copilot, Qwen, DeepSeek y Generic AI.
- Schemas de adapter y matrix, mas `scripts/check-adapter-drift.ps1`.

### Changed
- Version operativa actual a 0.8.4.
- `adapter-contract.md`, manifest, init y validator pasan a cubrir portabilidad multi-IA.

### Rationale
- Tomando como referencia Ponytail, el harness separa core comun de adapters host-specific para reducir drift y hacer auditable como cada IA carga el contrato.

## [0.8.3] - 2026-06-16

### Added
- `auditor(profile: detractor_senior)` como pase obligatorio antes de implementacion o escritura.
- `agents/_schema.md` para estructura estable de agentes.
- `agents/detractor-senior.md`, `minimal-implementation-policy.md`, `detractor-senior-checklist.md` y `prompts/audit/detractor-senior.prompt.md`.
- Gate `G3A_detractor_senior_pre_implementation` para validar solucion minima correcta antes de `G4_execution_complete`.

### Changed
- Version operativa actual a 0.8.3.
- `multiagent-protocol.md`, `agent-role-taxonomy.md`, `state.yaml`, schema y validadores quedan alineados al nuevo pase pre-implementacion.

### Rationale
- Tomando como referencia Ponytail, el harness incorpora un senior detractor que busca menos codigo, menos dependencias y menos abstracciones, sin sacrificar seguridad, datos, accesibilidad, contrato ni evidencia.
## [0.8.2] - 2026-06-06

### Added
- `orquestador/sdd/progress/templates/memory-closure-checklist.md` para cerrar memoria local, daily, cycle y project antes de `done`.
- Validaciones en `init.sh` para drift operativo, presupuestos minimos y exclusion de documentacion personal/local.

### Changed
- Version operativa actual a 0.8.2.
- Adapters y presets usan entrada minima: `PROJECT_BINDING.yaml`, `session-pin.md`, `memory-registry.yaml`, `memory-routing.yaml`, `context-budget.yaml` y entrypoint.
- Bootstrap y migracion excluyen materialmente documentacion personal/local, `.git/` y temporales.

### Fixed
- `state.yaml` corrige gates pegados y separa correctamente `approvals`.
- Referencias operativas antiguas quedan alineadas al contrato vigente.

## [0.8.1] - 2026-06-06

### Added
- `orquestador/context-budget.yaml` with hard budgets for `memory_bootstrap`, `first_message`, `reentry_light`, `debug_log_intake`, `leader_light`, `leader_full` and `audit_global`.
- `orquestador/method/session-contract-extended.md` for low-frequency rules that should not be loaded on every message.
- `.gitignore` entry for local personal documentation so it never becomes operational context.

### Changed
- `AGENTS.md` and `session-contract.md` now act as a lightweight kernel.
- `context-profiles.md` now separates `leader_light` from `leader_full` and fixes the budget table drift.
- `context-loading-policy.md` makes budget reporting mandatory and treats over-budget loading as a stop condition.
- Entrypoints now deny full context by default and keep debug/log intake on the light route.
- README documents the token reduction target as a contract objective.

### Fixed
- Prevents local personal documentation from being copied into consumer `.hebrinex` contexts.
- Prevents logs/debug from triggering heavy leader context automatically.
## [0.8.0] - 2026-06-05

### Added
- `orquestador/memory/` con memoria estratificada local, diaria, de ciclo, de proyecto y completa.
- `orquestador/entrypoints/` para first message, reentry light/full, debug log intake y recovery post-compactacion.
- `orquestador/adapters/` para Codex, Claude Code, Gemini, Qwen, DeepSeek, Cursor, Copilot y Generic AI.
- Politicas `memory-layer-policy.md`, `adapter-contract.md` y `context-loading-policy.md`.
- Prompts operativos para reentry liviano/completo, memoria diaria, cierre de memoria de ciclo, auditoria de memoria, primer mensaje y entrada de logs/debug.

### Changed
- La version operativa actual pasa a 0.8.0.
- `init.sh` valida memoria, adapters y entrypoints desde el manifest.
- `PROJECT_BINDING.yaml` declara que la memoria operativa se gobierna desde `memory-registry.yaml`.
- Los presets por IA pasan a ser adapters gobernados por `ai-preset-policy.md`.

### Rationale
- La memoria conversacional no es confiable ni portable entre IAs. 0.8.0 convierte el re-entry en una rehidratacion por capas decidida por el orquestador, reduciendo reentradas manuales, drift y costo de contexto.
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
- `prompts/workflows/cerrar-con-evidencia.prompt.md`.

### Rationale
- Evita cierres `done` sin links verificables a gate log, audit trail, verification matrix, agent closure, locks, gaps y validaciones.

## [0.7.6] - 2026-05-29

### Added
- `orquestador/method/audit-reporting-policy.md`.
- `orquestador/sdd/progress/templates/audit-report-contract.md`.
- `prompts/audit/auditar-y-reportar.prompt.md`.

### Rationale
- Refuerza que el auditor define veredicto por evidencia y el reporter comunica sin alterar el resultado.

## [0.7.5] - 2026-05-29

### Added
- `orquestador/method/backlog-policy.md`.
- `orquestador/sdd/progress/templates/backlog-classification-matrix.yaml`.
- `prompts/workflows/clasificar-roadmap.prompt.md`.

### Rationale
- Ordena P0/P1/P2 por bloqueo, impacto, dependencia y criterio de cierre, no por preferencia del agente.

## [0.7.4] - 2026-05-29

### Added
- `orquestador/method/ci-pipeline-policy.md`.
- `orquestador/sdd/progress/templates/ci-pipeline-history.yaml`.
- `prompts/migration/reconstruir-ci-pipeline.prompt.md`.

### Rationale
- Evita colapsar iteraciones de CI/pipeline cuando el operador necesita documentar como se llego a un pipeline funcional.

## [0.7.3] - 2026-05-29

### Added
- `orquestador/method/reference-drift-policy.md`.
- `orquestador/sdd/progress/templates/reference-drift-matrix.yaml`.
- `prompts/audit/validar-referencias-version.prompt.md`.

### Rationale
- Evita inconsistencias entre `HARNESS_VERSION`, `PROJECT_BINDING.yaml`, README, changelog, prompts e `init.sh`.

## [0.7.2] - 2026-05-29

### Added
- `orquestador/method/deploy-migration-policy.md`.
- `orquestador/sdd/progress/templates/deploy-migration-checklist.md`.
- `prompts/migration/reconstruir-deploy-migracion.prompt.md`.

### Rationale
- Evita documentar deploys o migraciones sin comandos, entorno, evidencia, version/ciclo y rollback.

## [0.7.1] - 2026-05-29

### Added
- `orquestador/method/changelog-policy.md` para bloquear cambios de changelog/release docs sin reconstruccion historica previa.
- `orquestador/method/evidence-reconstruction.md` para tratar changelog, release notes, roadmap, deploy docs, reportes y auditorias como artefactos derivados de evidencia.
- `orquestador/sdd/progress/templates/changelog-reconstruction-checklist.md` y `release-history-matrix.yaml` como evidencia obligatoria antes de editar historial/versiones.
- `prompts/workflows/actualizar-changelog.prompt.md` para usar un flujo repetible ante pedidos de completar, ordenar o corregir changelog.
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
- `prompts/migration/migrar-harness-0-7.prompt.md` para migrar cualquier version previa a 0.7.0.
- `prompts/session/usuario-contrato-reentry.prompt.md` para que el operador pueda exigir contrato, compactacion y re-entry cuando un agente pierde foco.
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
