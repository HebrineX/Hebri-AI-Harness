# Fragment: Claude Hooks

Claude usa reentry brief generado. Hooks implementados: SessionStart (reentry brief), PreToolUse Bash|PowerShell (command gateway), PreToolUse Edit|Write|NotebookEdit (writeguard: rutas protegidas + locks), Stop (pendientes abiertos, warn) y PreCompact (cierre de memoria antes de compactar). Modo warn por defecto; ver orquestador/integrations/claude/hooks-policy.md.
