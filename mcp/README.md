# Daemon MCP "hebrinex"

harness_version: "0.15.0"

Servidor MCP local (stdio, Node >= 18, SDK oficial `@modelcontextprotocol/sdk`)
que expone el enforcement del Hebri-AI-Harness como tools. Es la pieza
multiplataforma: un solo daemon en lugar de 8 adapters de prompt. El daemon no
reimplementa politica; envuelve los scripts PowerShell existentes:

| Tool | Que hace | Backend |
|---|---|---|
| `run_command` | Unica via de ejecucion. Corre el comando via gateway `-Apply`; si `decision=block` la tool falla con el reason y el preflight generado. | `scripts/command-gateway.ps1` |
| `preflight_approve` | Materializa el SI del operador: crea un approval envelope y devuelve `approval_id` + expiracion. | `scripts/hebrinex.ps1 approve -Apply` |
| `approval_check` | Valida un `approval_id` contra el almacen (estado, expiracion, hash exacto del comando). Read-only. | `scripts/command-gateway.ps1 -CheckOnly` |
| `session_contract` | Arma el contrato de sesion (PROJECT_BINDING + state + registry + budget) dentro del presupuesto `leader_light` de `context-budget.yaml`. | lectura directa |
| `gate_check` | Mira `git status/diff` (read-only) y clasifica que gates G5B..G5I de `gate-registry.yaml` aplican al scope tocado. | `git` read-only |
| `memory_route` | Decide el entrypoint (`first_message` \| `reentry_light` \| `debug_log_intake` \| `compactation_recovery`) segun estado real de sesion/archivos. | lectura directa |
| `close_cycle_check` | Verifica el memory-closure-checklist (evidencia, locks/agentes/handoffs abiertos, reporte final) antes de permitir `done`. | lectura directa |
| `session_usage` | Parsea los transcripts JSONL de Claude Code del proyecto y reporta tokens/turnos/costo estimado (precios editables en `mcp/model-pricing.yaml`). Read-only. | lectura directa |
| `role_assume` | Valida `role_id` contra el agent-registry y lo fija como rol de la sesion en el estado del proceso del daemon. | lectura directa + estado del daemon |
| `lock_acquire` | Adquiere un lock exclusivo (`L-*.lock.md`, owner/paths/TTL); solapamiento con un lock activo -> `lock_conflict`. Con rol asumido exige `edit_approved_write_set`. | `scripts/hebrinex.ps1 lock -Acquire` |
| `lock_release` | Libera un lock (`status: released`). Con rol asumido exige `edit_approved_write_set`. | `scripts/hebrinex.ps1 lock -Release` |

## Instalacion

```sh
cd mcp
npm install
```

Requiere Node >= 18 y PowerShell (`pwsh` o `powershell.exe`) en PATH.
Variables opcionales: `HEBRINEX_ROOT` (raiz del harness; default: carpeta padre
de `mcp/`) y `HEBRINEX_PWSH` (ruta explicita del ejecutable PowerShell).

## Smoke test

```sh
cd mcp
node smoke.mjs
```

Tambien lo corre `scripts/validate-mcp.ps1` (estructura siempre; smoke solo si
hay `node` y `mcp/node_modules/@modelcontextprotocol/sdk`).

## Conexion por cliente

### Claude Code

Ya registrado en `.mcp.json` en la raiz del repo. Claude Code lo detecta al
abrir el proyecto; aprobar el server cuando lo pregunte.

### Cursor

Crear `.cursor/mcp.json` en el proyecto (o `~/.cursor/mcp.json` global):

```json
{
  "mcpServers": {
    "hebrinex": {
      "command": "node",
      "args": ["C:\\ruta\\al\\harness\\mcp\\server.mjs"]
    }
  }
}
```

En un proyecto bound, la ruta es `<project_root>/.hebrinex/mcp/server.mjs` y
conviene fijar `env: { "HEBRINEX_ROOT": "<project_root>/.hebrinex" }`.

### Codex CLI

En `~/.codex/config.toml`:

```toml
[mcp_servers.hebrinex]
command = "node"
args = ["C:\\ruta\\al\\harness\\mcp\\server.mjs"]
```

### Otros clientes MCP (Gemini CLI, Copilot, etc.)

Cualquier cliente con soporte MCP stdio: comando `node`, argumento
`<harness>/mcp/server.mjs`. No expone red; todo es local.

## Contrato operativo

- `run_command` es la unica via de ejecucion: no hay bypass. El gateway decide
  allow/block contra `orquestador/security/command-risk-registry.yaml` y valida
  approvals contra `orquestador/sdd/progress/approvals/`.
- `preflight_approve` solo debe invocarse despues del SI explicito del operador
  humano; el envelope vale unicamente para el texto exacto aprobado y expira.
- Las tools de lectura no escriben nada en el harness.
- Identidad de rol: tras `role_assume`, las tools con efecto (`run_command`,
  `lock_acquire`, `lock_release`) consultan `scripts/agent-runtime.ps1` con el
  rol del daemon y fallan con `role_capability_blocked` si falta la capability.
  Sin rol asumido operan sin check (`role_enforced=false`). Limite residual
  documentado en `orquestador/agents/README.md`.
