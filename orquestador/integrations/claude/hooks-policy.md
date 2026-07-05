# Claude Hooks Policy

Hooks implementados (ver `settings.template.json` e instalador `scripts/install-claude-hooks.ps1`):

- `SessionStart`: ejecuta `scripts/claude-reentry.ps1`. Genera el brief liviano en
  `orquestador/runtime/claude/reentry-brief.md` y lo inyecta al contexto de la sesion
  (binding, estado de contrato, ciclo activo, locks abiertos/vencidos).
- `PreToolUse` (matcher `Bash|PowerShell`): ejecuta `scripts/claude-pretooluse-hook.ps1`,
  que clasifica el comando con el Command Gateway y responde:
  - gateway `allow` -> `permissionDecision=allow` (read-only seguro, sin prompt).
  - gateway `blocked_pattern` -> `permissionDecision=ask` (fuerza `SI` explicito del
    operador aunque el comando este allowlisted en el host).
  - resto (composite, secrets, unknown) -> sin decision; aplica el flujo de permisos
    normal de Claude Code.

Hooks recomendados aun no implementados:

- `PreCompact`: cerrar memoria/reentry checklist.
- `Stop`: advertir locks, agentes o gates abiertos.

Instalacion: `scripts/install-claude-hooks.ps1 -CheckOnly` muestra el plan;
`-Apply` mergea los hooks en `<project_root>/.claude/settings.json`.

El `SI` del operador se materializa con `hebrinex approve -Apply -CommandText <accion>`,
que crea un approval envelope con expiracion y hash exacto de la accion. El gateway
valida `-ApprovalId` contra ese almacen y bloquea envelopes falsos, vencidos o con
comando distinto.

Los hooks no son evidencia. La evidencia sigue en archivos del harness y salidas de comandos.
