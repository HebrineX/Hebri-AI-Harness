# Claude Code Integration

Objetivo: rehidratar contrato desde archivos, no desde memoria de Claude.

Uso recomendado:
- `CLAUDE.md` del proyecto apunta al brief generado.
- `SessionStart` genera `orquestador/runtime/claude/reentry-brief.md`.
- `UserPromptSubmit` valida binding/version/brief fresco.
- `PreToolUse` bloquea efectos sin preflight + `SI` cuando el host lo soporte.

Modo por defecto: `warn`. `enforce` solo para acciones con efecto.

Subagentes de rol nativos (0.17.0): `agents/auditor-detractor.md` y
`agents/reviewer.md` (GENERADOS por `scripts/build-instructions.ps1` desde la
fuente unica `agents/<rol>.md`; tools read-only). Se instalan en el
`.claude/agents/` del proyecto con
`scripts/install-host-integrations.ps1 -HostName claude -Apply`. La via
agnostica equivalente es el daemon MCP (`agent_audit` / `agent_review`).
