# How To Use - Hebri-AI-Harness 0.17.1

Esta guia es la entrada practica para usar el harness sin leer todo el arbol.
La autoridad operativa sigue siendo `.hebrinex/` cuando existe en un proyecto
consumidor; en este repo fuente la autoridad es el source template.

## Regla corta

1. Si el proyecto tiene `.hebrinex/`, trabajar contra esa carpeta.
2. Si no tiene `.hebrinex/`, no operar con un harness externo: hacer bootstrap
   con `scripts/hebrinex.ps1 bootstrap`.
3. Declarar contrato de sesion antes de diagnosticar, editar o ejecutar.
4. Cargar solo el kernel: binding, session pin, memory registry/routing,
   context budget y entrypoint.
5. Antes de efectos, presentar preflight y esperar `SI` explicito.
6. Antes de escribir o implementar, pasar por detractor senior o registrar
   bypass aprobado.
7. No cerrar `done` sin evidencia, gates, estado, registry, locks y cierre de
   agentes cuando aplique.

## Instalacion en un proyecto

### Candidato central P06

El repositorio puede construir un MSI local Windows x64 con
`scripts/validate-packaging.ps1`. Es un artefacto de ingenieria sin firma, no
una release instalable aceptada. `hebrinex.exe` valida el payload y delega el
nucleo en Windows PowerShell 5.1; `hebrinex.exe mcp` falla cerrado con
`OPTIONAL_FEATURE_MISSING` hasta incorporar un runtime Node redistribuible y
probar su cierre offline.

No ejecutar el MSI en este host ni en un consumidor real sin un nuevo
preflight. Las pruebas de instalacion, PATH/registro, ACL, repair y uninstall
pertenecen a P07/P08 sobre una VM descartable.

### Verificar antes de copiar

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 bootstrap -CheckOnly -ProjectRoot C:\path\project
```

`-CheckOnly` no escribe. Debe mostrar `writes=false`, `apply_available=true` y
el plan de bootstrap.

### Aplicar bootstrap

Solo despues del preflight y del `SI` del operador:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 bootstrap -Apply -ProjectRoot C:\path\project
```

El resultado esperado es `<project_root>\.hebrinex\` con
`PROJECT_BINDING.yaml` en modo `bound`. `.hebrinex/` no se sube al Git del
proyecto consumidor.

### Actualizar un proyecto bound

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 update-bound -CheckOnly -ProjectRoot C:\path\project
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 update-bound -Apply -ProjectRoot C:\path\project
```

`update-bound` preserva identidad, progreso, memoria, locks, approvals,
backups, reportes y overrides locales segun `SHARED_MANIFEST.yaml`.

## Comandos CLI

Entrada estable:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 <command> [args]
```

El contrato publico vive en `orquestador/method/cli-contract.md`. Comandos
cerrados en 0.17.1:

| Comando | Escribe | Uso |
|---|---:|---|
| `help` | no | Lista comandos y markers `cli_contract_version=0.5`. |
| `status` | no | Binding, version, root, locks y autoridad runtime. |
| `budget` | no | Presupuestos de contexto por perfil. |
| `usage` | no | Tokens estimados, ahorro medido y markers parseables. |
| `preflight` | no | Genera plantilla de preflight para pedir `SI`. |
| `approve` | si con `-Apply` | Materializa un `SI` como approval envelope. |
| `validate` | no operativo | Ejecuta validacion estructural. |
| `audit` | no operativo | Ejecuta auditoria del harness. |
| `migrate` | si con `-Apply` | Migra una instancia soportada con backup/reporte. |
| `bootstrap` | si con `-Apply` | Copia y vincula `.hebrinex/` en un proyecto. |
| `update-bound` | si con `-Apply` | Actualiza una instancia bound preservando estado. |
| `list-bound-backups` | no | Lista backups disponibles de una instancia bound. |
| `restore-bound` | si con `-Apply` | Restaura un backup bound por `BackupId`. |
| `command` | solo read-only con `-Apply` | Clasifica/ejecuta via Command Gateway. |
| `state-machine` | no | Valida transiciones de ciclo/agente. |
| `agent-runtime` | no | Valida rol/capability antes de operar. |
| `lock` | si salvo `-List` | Adquiere, libera o lista locks exclusivos. |

### Ejemplos seguros

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 status
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 budget
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 usage
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 validate -RunNegativeTests
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 audit -RunNegativeTests
```

### Approval y gateway

Crear un approval para el texto exacto aprobado:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 approve -Apply -CommandText "Get-Content README.md" -Purpose "lectura aprobada" -TtlMinutes 30
```

Clasificar sin ejecutar:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 command -CheckOnly -CommandText "Get-Content README.md" -ApprovalId APR-<id>
```

Ejecutar solo si el gateway permite el plan:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 command -Apply -CommandText "Test-Path README.md"
```

`command -Apply` no es una shell general. Solo ejecuta planes read-only
estrictos allowlisted dentro del root: `Get-Content`, `Select-String`,
`Test-Path`, `Get-ChildItem` y `git status --short`. Comandos compuestos,
red, escrituras, paths inseguros o approvals vencidos/borrados/mismatch quedan
bloqueados.

### Locks

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 lock -Acquire -Paths "README.md,HOW_TO_USE.md" -Owner "leader" -TtlMinutes 120 -Reason "docs update"
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 lock -List
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 lock -Release -LockId L-<id>
```

Un lock activo bloquea escrituras solapadas. Si el host no puede hacer locks
reales, debe simular el rol y registrar la evidencia de forma trazable.

## Que se puede hacer

- Leer y diagnosticar con kernel minimo.
- Usar `-CheckOnly` para inspeccionar planes antes de escribir.
- Usar `approve -Apply` solo despues del `SI` humano.
- Usar MCP como runtime comun para comandos, approvals, gates, memoria, roles,
  locks, auditoria y review.
- Instalar instrucciones persistentes por host cuando el adapter lo soporte.
- Actualizar instancias bound con `update-bound`, preservando estado local.
- Simular roles cuando el host no tenga subagentes reales, siempre declarandolo.

## Que no se puede hacer

- Operar un proyecto con un harness externo si no existe `.hebrinex/`.
- Subir `.hebrinex/` al Git del proyecto consumidor.
- Tomar memoria conversacional como evidencia.
- Cargar `complete/`, prompts completos, manifest o README completo por defecto.
- Editar, ejecutar red, git remoto o comandos con efecto sin preflight y `SI`.
- Mezclar roles: leader coordina, implementer edita, reviewer revisa.
- Declarar `done` sin estado, registry, gates, evidencia, verification matrix
  cuando aplique, final report cuando aplique, agent closure y locks resueltos.
- Usar MCP o hooks como bypass del Command Gateway.

## Uso con cada IA

La via recomendada para agentes de rol es el daemon MCP cuando el host soporta
MCP. Las instrucciones persistentes son la primera capa; MCP es la capa de
enforcement compartida; prompt manual es fallback.

### Claude Code

Estado: production.

Instalar instrucciones y subagentes nativos:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/install-host-integrations.ps1 -HostName claude -ProjectRoot C:\path\project -CheckOnly
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/install-host-integrations.ps1 -HostName claude -ProjectRoot C:\path\project -Apply
```

Instalar `CLAUDE.md` y hooks reales:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/install-claude-hooks.ps1 -ProjectRoot C:\path\project -CheckOnly
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/install-claude-hooks.ps1 -ProjectRoot C:\path\project -Apply
```

Resultado esperado: `CLAUDE.md`, `.claude/settings.json`,
`.claude/agents/auditor-detractor.md` y `.claude/agents/reviewer.md`. Los
hooks cubren `SessionStart`, `PreToolUse`, `Stop` y `PreCompact`. MCP usa
`.mcp.json`.

### Codex

Estado: production.

Codex lee `AGENTS.md`. Para MCP, configurar `~/.codex/config.toml` o
`.codex/config.toml` en un proyecto trusted:

```toml
[mcp_servers.hebrinex]
command = "node"
args = [".hebrinex/mcp/server.mjs"]
```

Los agentes de rol se hacen via MCP (`agent_audit`, `agent_review`) o por
simulacion trazable si MCP no esta conectado.

### Cursor

Estado: experimental.

Instalar regla persistente:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/install-host-integrations.ps1 -HostName cursor -ProjectRoot C:\path\project -CheckOnly
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/install-host-integrations.ps1 -HostName cursor -ProjectRoot C:\path\project -Apply
```

Resultado esperado: `.cursor/rules/hebrinex.mdc`. Para MCP usar
`.cursor/mcp.json` con `mcpServers.hebrinex`.

### GitHub Copilot / VS Code

Estado: experimental.

Instalar instrucciones persistentes:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/install-host-integrations.ps1 -HostName copilot -ProjectRoot C:\path\project -CheckOnly
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/install-host-integrations.ps1 -HostName copilot -ProjectRoot C:\path\project -Apply
```

Resultado esperado: `.github/copilot-instructions.md`. Para MCP en VS Code usar
`.vscode/mcp.json` con clave top-level `servers`, no `mcpServers`.

### Gemini CLI

Estado: experimental.

Usar contexto persistente `GEMINI.md` o `AGENTS.md` segun el proyecto. Para MCP,
crear `.gemini/settings.json`:

```json
{
  "mcpServers": {
    "hebrinex": {
      "command": "node",
      "args": [".hebrinex/mcp/server.mjs"]
    }
  }
}
```

Hooks: soporte limitado. Mantener preflight y `SI` visibles en el chat.

### Qwen Code

Estado: experimental.

Usar `QWEN.md` como contexto persistente cuando exista. Para MCP, crear
`.qwen/settings.json`:

```json
{
  "mcpServers": {
    "hebrinex": {
      "command": "node",
      "args": [".hebrinex/mcp/server.mjs"]
    }
  }
}
```

Qwen Code declara hooks y MCP, pero el harness debe seguir verificando por
contrato: kernel minimo, preflight, `SI`, roles y evidencia.

### DeepSeek

Estado: experimental.

El CLI oficial Deep Code no tiene contrato estable de hooks, MCP ni archivo de
instrucciones persistente para este harness. Usar fallback `generic-ai`: pegar
el contrato de `AGENTS.md`, declarar simulacion de roles, pedir preflight/`SI`
y no afirmar subagentes reales.

### Generic AI

Estado: production como fallback.

Usar cuando el host no tenga adapter nativo o MCP. Pasos minimos:

1. Pegar o referenciar `AGENTS.md`.
2. Declarar contrato de sesion.
3. Cargar kernel minimo desde `.hebrinex/`.
4. Simular roles de forma explicita.
5. Pedir preflight y `SI` antes de efectos.
6. Registrar evidencia en archivos del harness si hubo trabajo operativo.

## Daemon MCP

Instalar dependencias:

```sh
cd mcp
npm install
```

Smoke:

```sh
cd mcp
node smoke.mjs
```

Tools expuestas: `run_command`, `preflight_approve`, `approval_check`,
`session_contract`, `gate_check`, `memory_route`, `close_cycle_check`,
`session_usage`, `role_assume`, `lock_acquire`, `lock_release`,
`agent_audit`, `agent_review`.

Backends read-only para `agent_audit` y `agent_review`:

- `claude-cli`: `claude -p --output-format json --allowedTools "Read,Grep,Glob"`
- `codex-cli`: `codex exec --sandbox read-only -`
- `none`: falla con instrucciones; usar subagente nativo o simulacion manual.

Config: `mcp/agents-backend.yaml`. Override local no trackeado:
`mcp/agents-backend.local.yaml`.

## Verificacion recomendada

En el repo fuente:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validate-harness.ps1 -RunNegativeTests
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validate-release.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/check-adapter-drift.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validate-mcp.ps1 -RunNegativeTests
```

En un proyecto bound:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .hebrinex\scripts\hebrinex.ps1 status -Root .hebrinex
pwsh -NoProfile -ExecutionPolicy Bypass -File .hebrinex\scripts\hebrinex.ps1 validate -Root .hebrinex -RunNegativeTests
```

Si un host se comporta de manera distinta, no se asume intencion: verificar si
esta leyendo el archivo persistente correcto, si MCP esta conectado, si el
kernel se cargo desde `.hebrinex/` y si el ultimo efecto tuvo preflight + `SI`.
