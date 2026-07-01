# Claude Code Adapter

## Entrada minima 0.10.10

Antes de actuar, leer solo:
1. `PROJECT_BINDING.yaml`
2. `orquestador/memory/local/session-pin.md`
3. `orquestador/memory/memory-registry.yaml`
4. `orquestador/memory/memory-routing.yaml`
5. `orquestador/context-budget.yaml`
6. entrypoint aplicable en `orquestador/entrypoints/`

No usar memoria de la herramienta como evidencia. No cargar `infoHebri.md`. Preflight + `SI` antes de efectos.
## Reglas

- Este adapter traduce el contrato; no reemplaza .hebrinex.
- Si se pierde foco, usar
reentry-light.
- Si hay logs/debug, usar debug-log-intake.

## Claude Integration 0.10.10

Usar `orquestador/integrations/claude/CLAUDE.template.md` y generar `orquestador/runtime/claude/reentry-brief.md` con `scripts/claude-reentry.*`. Hooks en modo `warn` por defecto.
