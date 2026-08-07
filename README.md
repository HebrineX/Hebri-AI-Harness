# Hebri-AI-Harness

Referencia operativa actual: **0.17.1**.

Sistema operativo para agentes IA basado en [Hebri-AI-Structure](https://github.com/HebrineX/Hebri-AI-Structure). Objetivo: contrato, trazabilidad y aprobaciones con el minimo contexto — ahorro medido: 90% (hebrinex usage) frente a leer la documentacion operativa completa (`AGENTS.md` + `method/` + `prompts/`).

## Uso Diario

1. Validar `PROJECT_BINDING.yaml`.
2. Cargar kernel minimo: `session-pin`, `memory-registry`, `memory-routing`, `context-budget` y entrypoint.
3. Declarar contrato de sesion.
4. Elegir perfil minimo desde `orquestador/context-profiles.md`.
5. Pedir `SI` antes de efectos.
6. Ejecutar `auditor(profile: detractor_senior)` antes de implementar o escribir.
7. Cerrar con evidencia y `memory-closure-checklist.md` si hubo trabajo operativo.

## Presupuestos

| Ruta | Presupuesto |
|---|---:|
| `memory_bootstrap` | <= 1700 tokens |
| `first_message` | <= 1800 tokens |
| `reentry_light` | <= 1800 tokens |
| `debug_log_intake` | <= 2000 tokens + logs |
| `leader_light` | <= 2600 tokens |
| `leader_full` | <= 8000 tokens y requiere motivo |
| `audit_global` | <= 12000 tokens y requiere `SI` |

Denegado por defecto: documentacion personal/local, memoria `complete/`, `CHANGELOG.md`, `README.md`, manifest, `init.sh`, prompts completos y todos los metodos.

## Bootstrap Seguro

Si un proyecto no tiene `.hebrinex`, no se opera con un harness externo. Se copia una fuente libre `source_template` a `<project_root>/.hebrinex/`, excluyendo materialmente documentacion personal/local, `.git/` y temporales, y luego se vincula como `bound`.

## Novedades Actuales

- Cache compartida declarativa: `SHARED_MANIFEST.yaml` versiona qué directorios son compartibles (`shared_dirs`) y qué estado debe ser copia real por proyecto (`instance_dirs` + `instance_path_map`). La ruta 0.16.0 -> 0.17.0 conserva binding, progreso, memoria, backups/reportes, runtime y overrides locales bajo `instance/`, sin convertir un harness externo en autoridad operativa.
- Agentes de rol multiplataforma via daemon MCP: tools `agent_audit(plan_or_diff)` (detractor-senior, gate G3A) y `agent_review(diff, acceptance_criteria)` (reviewer) arman el prompt desde la fuente unica `agents/<rol>.md` y lo corren con un backend read-only configurable (`mcp/agents-backend.yaml`: `claude-cli` | `codex-cli` | `none`; override por maquina git-ignored `agents-backend.local.yaml`; interfaz abierta para `ollama`). La MISMA capacidad de auditoria en cualquier host con MCP.
- Bootstrap robusto para Claude Code: `CLAUDE.md` ahora materializa el contrato minimo aun si los hooks no corrieron; `scripts/install-host-integrations.ps1 -HostName claude -Apply` instala `CLAUDE.md` y subagentes, y `scripts/install-claude-hooks.ps1 -Apply` instala `CLAUDE.md` y mergea hooks.
- Subagentes nativos reales en Claude Code (proyeccion opcional de la misma fuente unica): `auditor-detractor` y `reviewer` con tools read-only enforceadas por el host, generados por el instruction-builder e instalables con `scripts/install-host-integrations.ps1 -HostName claude -Apply`.
- Adapters nativos generados para Cursor (`.cursor/rules/hebrinex.mdc`) y Copilot (`.github/copilot-instructions.md`) desde los mismos fragments que `AGENTS.md`; instalador `install-host-integrations.ps1 -HostName cursor|copilot`.
- Conexion MCP por host documentada y verificada (fuentes citadas): `orquestador/portability/mcp-hosts.md` (Claude Code, Cursor, Codex CLI, VS Code/Copilot, Gemini CLI, Qwen Code).
- Vaporware muerto: investigacion real de adapters (`orquestador/sdd/specs/adapter-investigation-2026-07.md`). Codex CLI tiene hooks estables y MCP; Qwen Code tiene `QWEN.md`+hooks+MCP; el CLI oficial de DeepSeek no documenta hooks/MCP. Ningun adapter queda en `hook_support: unknown`; todos declaran `maturity` y via recomendada (ver tabla en "Adapter portability").
- Locks ejecutables: `hebrinex lock -Acquire/-Release/-List` crea, libera e inventaria locks exclusivos `L-*.lock.md` en `orquestador/sdd/progress/locks/` con owner, paths y TTL; adquirir un path ya lockeado por un lock activo no vencido falla con `lock_conflict`. Tools MCP `lock_acquire`/`lock_release` envuelven el comando. Contrato CLI sube a `0.5`.
- Writeguard de ediciones: hook `PreToolUse` para `Edit|Write|NotebookEdit` (`scripts/claude-writeguard-hook.ps1`) que degrada a `permissionDecision=ask` las escrituras sobre rutas protegidas del write-scope-registry (`PROJECT_BINDING.yaml`, `HARNESS_VERSION`, `approvals/`, `locks/`) y sobre paths cubiertos por locks activos (con el `lock_id` en el motivo). Fail-open ante errores del propio hook.
- Hooks `Stop` y `PreCompact`: al terminar cada turno el harness avisa (sin bloquear) si quedan locks, approvals vigentes, ciclo sin cerrar o `HANDOFF-*` pendientes; antes de compactar emite el resumen del memory-closure-checklist para persistir estado antes de perder memoria.
- Rate limiting del gateway: las ejecuciones `-Apply` permitidas se limitan con ventana deslizante (`rate_limit` en `command-risk-registry.yaml`, default 30/min; excedida -> `decision=block`, `reason=rate_limit_exceeded`). `CheckOnly` no se limita; estado runtime en `orquestador/runtime/gateway-rate.json` (generado, fuera del manifest).
- Identidad de rol via MCP: `role_assume(role_id)` valida contra el agent-registry y fija el rol en el estado del proceso del daemon; las tools con efecto (`run_command`, `lock_acquire`, `lock_release`) consultan `agent-runtime.ps1` con ESE rol. Limite residual documentado en `orquestador/agents/README.md`: el CLI directo sigue aceptando `-RoleId` autodeclarado.
- Daemon MCP "hebrinex" (`mcp/`): un unico servidor MCP local (Node, stdio) expone el enforcement del harness como tools para Claude Code, Cursor, Codex CLI y cualquier cliente MCP, en lugar de 8 adapters de prompt. Ver seccion "Daemon MCP".
- Fuente unica de roles: `agents/<rol>.md` contiene bloques marcados desde los que `scripts/build-instructions.ps1 -WriteOutputs` genera `orquestador/agents/role-contracts/*.yaml`, `prompts/roles/*.prompt.md` y el bloque `role_defaults` de `capability-registry.yaml`. Los derivados llevan aviso GENERATED y no se editan a mano: el drift-check (`build-instructions.ps1` en modo default, corrido por `init.sh` y `validate-drift.ps1`) falla si alguien lo hace.
- Medicion real de consumo: `hebrinex usage` mide el kernel contra la documentacion operativa (`docs_tree_tokens=`, `savings_docs_pct=` — denominador del claim de este README) y contra el arbol completo del manifest (`full_tree_tokens=`, `savings_pct=`, metrica para la poda), con una linea por perfil. `validate-release.ps1` recalcula `savings_docs_pct` y falla si el porcentaje citado en este README deriva mas de ±5 puntos del medido.
- CLI estable: `scripts/hebrinex.ps1` expone contrato versionado (0.5), markers parseables y validacion dedicada con `validate-cli.ps1`.
- Approval store ejecutable: `hebrinex approve -Apply` materializa el `SI` como envelope con expiracion y hash exacto de la accion; el Command Gateway valida `-ApprovalId` contra el almacen y bloquea envelopes falsos, vencidos o con comando distinto.
- Hooks reales de Claude Code: `SessionStart` inyecta el reentry brief y `PreToolUse` clasifica comandos con el gateway (`allow` sin prompt para read-only seguro, `ask` para patrones bloqueados). Instalador: `scripts/install-claude-hooks.ps1`.
- Gateway endurecido: rechazo de symlinks en Apply, kill del arbol de procesos completo en timeout y modulo comun `scripts/lib/hebri-common.psm1`.
- `status` reporta locks abiertos y vencidos (`open_locks`, `expired_locks`).
- Adapters condensados: cuerpo comun unico en `orquestador/adapters/_shared-core.md`; cada `<host>.md` solo lleva notas especificas.
- Runtime enforcement ejecutable: `state-machine` bloquea transiciones invalidas y `agent-runtime` bloquea roles/capabilities no permitidas.
- CI oficial: GitHub Actions ejecuta validadores, auditores, drift checks,
  fixtures de migracion, fixtures negativos de seguridad, CLI estable e `init.sh`.
- Agent Contract System: los agentes existen por contratos YAML gobernados por el harness, no por prompts ni autoasignacion de IA.
- Seguridad AppSec verificable: permisos, write-scope, comandos, red, secretos, escalacion, logging y supply-chain se validan por registries.
- Servicio de migracion: rutas 0.8.10/0.9.0 -> 0.10.0, 0.10.11 -> 0.11.0, 0.11.0 -> 0.12.0, 0.12.0 -> 0.13.0, 0.13.0 -> 0.14.0, 0.14.0 -> 0.15.0, 0.15.0 -> 0.16.0 y 0.16.0 -> 0.17.0 con CheckOnly, Apply con backup, reporte y contrato post-migracion aplicado.
- Schemas y fixtures de validacion cubren contratos de agentes, seguridad y
  migracion con casos negativos.
- Command Gateway seguro: `hebrinex command -CheckOnly` clasifica comandos y
  `hebrinex command -Apply` ejecuta solo comandos read-only allowlisted, con
  timeout, root acotado, salida redactada y bloqueo deny-by-default.
- `init.sh` bloquea drift de version operativo fuera de `CHANGELOG.md`.
- `state.yaml` queda estructuralmente valido.
- Adapters y presets usan entrada minima: binding, session pin, registry, routing, budget y entrypoint.
- `memory-closure-checklist.md` obliga a cerrar local/daily/cycle/project antes de `done`.
- Bootstrap/migracion excluyen materialmente documentacion personal/local.
## Validacion Local

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validate-harness.ps1 -RunNegativeTests
```

Esta validacion revisa manifest, schemas, presupuestos, exclusion de documentacion personal/local, migracion bound simulada y presets livianos por defecto. No reemplaza el contrato del harness; lo protege contra drift estructural.

## CI Oficial

El source template incluye `.github/workflows/ci.yml`. El job `Harness contract`
corre en `pull_request` y `push` a `main`:

- `scripts/validate-cli.ps1 -RunNegativeTests`
- `scripts/validate-harness.ps1 -RunNegativeTests`
- `scripts/audit-harness.ps1 -RunNegativeTests`
- `scripts/check-adapter-drift.ps1`
- fixtures/validadores de migracion
- fixtures/validadores negativos de seguridad
- `scripts/validate-state-machine.ps1 -RunNegativeTests`
- `scripts/validate-agent-runtime.ps1 -RunNegativeTests`
- `scripts/validate-mcp.ps1 -RunNegativeTests` (con `npm ci` previo en `mcp/`)
- `./init.sh`

Para bloquear merges, GitHub debe marcar `Harness contract` como required check
en branch protection.

## CLI Core

`scripts/hebrinex.ps1` es la entrada unica liviana y estable para operar scripts
del harness sin cargar todo el contexto. El contrato publico vive en
`orquestador/method/cli-contract.md` y se valida con `scripts/validate-cli.ps1`.

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 help
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 status
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 budget
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 usage
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 preflight
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 validate -RunNegativeTests
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 audit -RunNegativeTests
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 migrate -CheckOnly
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 bootstrap -CheckOnly -ProjectRoot C:\path\project
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 update-bound -CheckOnly -ProjectRoot C:\path\project
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 list-bound-backups -CheckOnly -ProjectRoot C:\path\project
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 restore-bound -CheckOnly -ProjectRoot C:\path\project -BackupId <id>
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 approve -Apply -CommandText "Get-Content README.md" -TtlMinutes 30
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 command -CheckOnly -CommandText "Get-Content README.md" -ApprovalId APR-<id>
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 command -Apply -CommandText "Test-Path README.md"
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 state-machine -FromState requested -ToState contract_resolved -Json
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 agent-runtime -RoleId implementer -Capability edit_approved_write_set -Json
```

La salida de `help` incluye `cli_contract_version=0.4`, `cli_status=stable` y
la lista cerrada de comandos publicos. `status`, `budget`, `usage`, `preflight` y los
modos `-CheckOnly` no escriben. La CLI delega en validadores, migrador,
bootstrap/update/restore, Command Gateway, state machine y agent runtime existentes; no reemplaza
`state.yaml`, `registry.yaml`, gates ni evidencia.

`command -CheckOnly` no ejecuta el comando recibido. Solo clasifica contra
`orquestador/security/command-risk-registry.yaml`, redacciona secretos simples,
bloquea comandos desconocidos o compuestos y devuelve si requiere preflight/SI.
`command -Apply` conserva deny-by-default y solo ejecuta planes read-only
estrictos (`Get-Content`, `Select-String`, `Test-Path`, `Get-ChildItem`,
`git status --short`) dentro del root del harness. Con `-Json`, emite
`hebrinex.command_gateway.result` con decision, ejecucion y evidencia redactada.

`state-machine` lee `orquestador/agents/lifecycle-registry.yaml` y devuelve una decision `allow|block` sin escribir archivos. `agent-runtime` lee `agent-registry.yaml`, `capability-registry.yaml` y contratos de rol para bloquear capabilities faltantes o denegadas antes de operar.

## Daemon MCP

`mcp/server.mjs` es un servidor MCP local (transporte stdio, SDK oficial
`@modelcontextprotocol/sdk`) que envuelve los scripts PowerShell existentes.
No reimplementa politica: toda ejecucion pasa por el Command Gateway y todo
approval por el approval store.

Tools expuestas:

| Tool | Funcion |
|---|---|
| `run_command` | Unica via de ejecucion: corre el comando via gateway `-Apply`; si la decision es `block`, la tool falla con el reason y el preflight generado. |
| `preflight_approve` | Materializa el `SI` del operador como envelope (`hebrinex approve -Apply`); devuelve `approval_id` + expiracion. |
| `approval_check` | Valida un `approval_id` contra el almacen (estado, expiracion, hash exacto del comando). |
| `session_contract` | Devuelve el contrato de sesion armado desde binding/state/registry dentro del presupuesto `leader_light`. |
| `gate_check` | Clasifica que gates G5B..G5I aplican al scope tocado segun `git status/diff` (read-only). |
| `memory_route` | Decide el entrypoint (`first_message` \| `reentry_light` \| `debug_log_intake` \| `compactation_recovery`) segun estado real. |
| `close_cycle_check` | Verifica el `memory-closure-checklist` (evidencia, locks/agentes/handoffs abiertos) antes de permitir `done`. |
| `session_usage` | Reporta tokens/turnos/costo estimado de la sesion desde los transcripts de Claude Code (precios en `mcp/model-pricing.yaml`). |
| `role_assume` | Fija el rol de la sesion en el estado del daemon; las tools con efecto consultan `agent-runtime.ps1` con ese rol. |
| `lock_acquire` / `lock_release` | Envuelven `hebrinex lock` (locks exclusivos con owner/TTL; conflicto -> `lock_conflict`). |
| `agent_audit` | Rol detractor-senior (gate G3A) sobre un plan/diff con backend read-only configurable; veredicto `aceptar \| simplificar \| bloquear \| pedir evidencia`. |
| `agent_review` | Rol reviewer sobre un diff + acceptance criteria; decision `aprobado \| bloqueado`. |

Instalacion y smoke:

```sh
cd mcp && npm install && node smoke.mjs
```

Claude Code lo detecta solo via `.mcp.json` en la raiz. Para Cursor y Codex CLI
ver `mcp/README.md`. Validacion: `scripts/validate-mcp.ps1` (estructura siempre;
smoke solo si hay `node` y dependencias, skip limpio si no), integrado en
`init.sh` y CI.

## Detractor Senior

Antes de implementar, el leader debe pasar por auditor(profile: detractor_senior) o registrar bypass aprobado. El objetivo es llegar al mismo resultado con menos codigo, menos dependencias y menos abstracciones, sin sacrificar seguridad, datos, accesibilidad, contrato ni evidencia.

Tres vias validas para el gate G3A (ver `orquestador/method/minimal-implementation-policy.md`): tool MCP `agent_audit` (recomendada, agnostica del host), subagente nativo `auditor-detractor` (Claude Code) o simulacion manual trazable (fallback universal).

## Adapter portability

El contrato portable vive en orquestador/portability/core-skills.yaml y la cobertura por IA en orquestador/portability/adapter-matrix.yaml. Los adapters .yaml son declarativos y se verifican con scripts/check-adapter-drift.ps1 (que ademas prohibe `hook_support: unknown` y exige tools read-only en los subagentes nativos).

Estado por host (investigado 2026-07-05; fuentes en `orquestador/sdd/specs/adapter-investigation-2026-07.md`). La via recomendada de agentes de rol es el daemon MCP en todo host que soporte MCP — un solo runtime agnostico, no 8 prompts distintos:

| Adapter | Maturity | Hooks | MCP | Agentes de rol (via recomendada) |
|---|---|---|---|---|
| claude-code | production | si (5 eventos, instalados) | `.mcp.json` | subagentes nativos + daemon MCP |
| codex | production | si (engine estable v0.124.0) | `~/.codex/config.toml` | daemon MCP |
| cursor | experimental | si (Cursor 1.7, no integrados) | `.cursor/mcp.json` | daemon MCP |
| copilot | experimental | no documentados | `.vscode/mcp.json` | daemon MCP |
| gemini | experimental | limited | `.gemini/settings.json` | daemon MCP |
| qwen | experimental | si (Qwen Code) | `.qwen/settings.json` | daemon MCP |
| deepseek | experimental | no (CLI oficial) | no documentado | simulacion por prompt |
| generic-ai | production | n/a | n/a | simulacion por prompt |
