# Claude Code Adapter

Contrato base compartido: leer `orquestador/adapters/_shared-core.md` (entrada minima 0.17.0, presupuesto en `orquestador/context-budget.yaml`, preflight + `SI` antes de efectos).

Notas especificas: archivo de instrucciones persistente `CLAUDE.md`; hooks reales soportados; subagentes de rol REALES (`.claude/agents/`: auditor-detractor, reviewer; instalables con `scripts/install-host-integrations.ps1 -HostName claude`); MCP via `.mcp.json`. Maturity: production. Investigado 2026-07-05 (ver `orquestador/sdd/specs/adapter-investigation-2026-07.md`).

## Claude Integration 0.17.0

- Usar `orquestador/integrations/claude/CLAUDE.template.md` como entrada y materializarlo como `CLAUDE.md` en la raiz del proyecto.
- Hooks reales: `SessionStart` genera e inyecta `orquestador/runtime/claude/reentry-brief.md`
  (`scripts/claude-reentry.*`); `PreToolUse` clasifica comandos con el Command Gateway
  (`scripts/claude-pretooluse-hook.ps1`).
- Instalar instrucciones persistentes/subagentes con `scripts/install-host-integrations.ps1 -HostName claude -CheckOnly|-Apply`.
- Instalar instrucciones persistentes/hooks con `scripts/install-claude-hooks.ps1 -CheckOnly|-Apply`.
- Politica completa en `orquestador/integrations/claude/hooks-policy.md`.
