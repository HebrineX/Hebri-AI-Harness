# Claude Hooks Policy

Hooks implementados (ver `settings.template.json` e instalador `scripts/install-claude-hooks.ps1`):

- `SessionStart`: ejecuta `scripts/claude-reentry.ps1` desde el producto central.
  En `central_instance` resuelve `.hebrinex/binding.json`, calcula el brief y lo
  inyecta sin persistir acceso ni copiar scripts. En modos legacy conserva el brief
  local de `orquestador/runtime/claude/reentry-brief.md`.
- `PreToolUse` (matcher `Bash|PowerShell`): ejecuta `scripts/claude-pretooluse-hook.ps1`,
  que clasifica el comando con el Command Gateway y responde:
  - gateway `allow` -> `permissionDecision=allow` (read-only seguro, sin prompt).
  - gateway `blocked_pattern` -> `permissionDecision=ask` (fuerza `SI` explicito del
    operador aunque el comando este allowlisted en el host).
  - resto (composite, secrets, unknown) -> sin decision; aplica el flujo de permisos
    normal de Claude Code.
- `PreToolUse` (matcher `Edit|Write|NotebookEdit`): ejecuta
  `scripts/claude-writeguard-hook.ps1`, que valida el `file_path` (o `notebook_path`)
  del tool input contra:
  - `claude_hook_protected_paths` de `orquestador/security/write-scope-registry.yaml`
    (PROJECT_BINDING.yaml, HARNESS_VERSION, approvals/, locks/) -> `permissionDecision=ask`
    con el motivo;
  - locks activos no vencidos de `orquestador/sdd/progress/locks/` -> `ask` con el
    `lock_id` en el motivo;
  - resto (incluidos paths fuera del root del harness) -> sin decision (defer).
- `Stop`: ejecuta `scripts/claude-stop-hook.ps1`. Al terminar cada turno revisa locks
  activos/vencidos, approvals vigentes sin consumir, ciclo activo sin cerrar y
  `HANDOFF-*` pendientes; si hay algo abierto emite `systemMessage` con la lista
  (advierte, NO bloquea el stop). Si todo esta limpio, silencio.
- `PreCompact`: ejecuta `scripts/claude-precompact-hook.ps1`. Antes de compactar corre
  la verificacion del memory-closure-checklist (misma logica que la tool MCP
  `close_cycle_check`) y emite `systemMessage` con lo que quedaria sin cerrar, para
  que la sesion lo persista a archivos antes de perder memoria.

Todos los hooks son fail-open respecto de si mismos: cualquier error interno del hook
sale con exit 0 sin output, y el flujo de permisos normal de Claude Code queda a cargo.
El writeguard corre en cada edicion: tiene que mantenerse rapido y jamas romper el
flujo si el harness esta a medias.

En `central_instance`, el instalador fija la ruta absoluta del producto confiable y
pasa `-ProjectRoot '.'`; el binding nunca contiene una ruta ejecutable. Estado,
memoria y locks se resuelven bajo `.hebrinex/instance`, mientras scripts, schemas y
politicas se leen del `InstallRoot`. El placeholder `__HEBRINEX_INSTALL_ROOT__` de
`settings.template.json` siempre es reemplazado por el instalador; no es una orden
lista para ejecutar manualmente. Si el proyecto fue movido, duplicado o desvinculado,
`SessionStart` falla con una instruccion de `status/reconcile` en vez de buscar o
ejecutar scripts dentro del proyecto.

Instalacion: `scripts/install-claude-hooks.ps1 -CheckOnly` muestra el plan;
`-Apply` instala/actualiza `<project_root>/CLAUDE.md` y mergea los hooks en
`<project_root>/.claude/settings.json`. Para una instancia central se agrega
`-RuntimeMode central_instance -ProjectRoot <root> -CatalogRoot <root-catalogo>`.

El `SI` del operador se materializa con `hebrinex approve -Apply -CommandText <accion>`,
que crea un approval envelope con expiracion y hash exacto de la accion. El gateway
valida `-ApprovalId` contra ese almacen y bloquea envelopes falsos, vencidos o con
comando distinto. El gateway ademas limita las ejecuciones `-Apply` con una ventana
deslizante (`rate_limit` en `orquestador/security/command-risk-registry.yaml`; excedida
-> `decision=block`, `reason=rate_limit_exceeded`).

Los hooks no son evidencia. La evidencia sigue en archivos del harness y salidas de comandos.
