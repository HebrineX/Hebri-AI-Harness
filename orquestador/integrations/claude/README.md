# Claude Code Integration

Objetivo: rehidratar contrato desde archivos, no desde memoria de Claude.

Uso recomendado:
- `CLAUDE.md` del proyecto apunta al brief generado.
- `SessionStart` genera `orquestador/runtime/claude/reentry-brief.md`.
- `UserPromptSubmit` valida binding/version/brief fresco.
- `PreToolUse` bloquea efectos sin preflight + `SI` cuando el host lo soporte.

Modo por defecto: `warn`. `enforce` solo para acciones con efecto.
