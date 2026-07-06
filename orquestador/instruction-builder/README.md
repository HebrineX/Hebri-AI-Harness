# Instruction Builder

Fuente canonica para instrucciones por IA.

Reglas:
- Los fragments son el core reusable.
- El registry define targets y superficies.
- Los outputs generados no son evidencia por si mismos.
- Drift validator falla si version, target, fragment o denylists divergen.

El builder corre en modo check-only salvo que el operador apruebe escritura.

Capas generadas (0.16.0):
- Roles (`role_sources`): contratos YAML, prompts de rol y `role_defaults` de
  `capability-registry.yaml` desde los bloques marcados de `agents/<rol>.md`.
- Subagentes nativos Claude Code (`native_agents`): bloques `claude-agent` de
  `agents/detractor-senior.md` y `agents/reviewer.md` hacia
  `orquestador/integrations/claude/agents/*.md` (tools read-only).
- Instrucciones por host (`host_instructions`): `.cursor/rules/hebrinex.mdc` y
  `copilot-instructions.md` compuestas desde los fragments kernel + preflight +
  denylists + roles + puntero al daemon MCP.

Instalacion en proyectos consumidores: `scripts/install-host-integrations.ps1
-HostName claude|cursor|copilot -CheckOnly|-Apply`.
