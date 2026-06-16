# Claude Hooks Policy

Hooks recomendados:
- `SessionStart`: generar brief liviano.
- `UserPromptSubmit`: validar contrato y ruta.
- `PreToolUse`: exigir preflight + `SI` para efectos.
- `PreCompact`: cerrar memoria/reentry checklist.
- `Stop`: advertir locks, agentes o gates abiertos.

Los hooks no son evidencia. La evidencia sigue en archivos del harness y salidas de comandos.
