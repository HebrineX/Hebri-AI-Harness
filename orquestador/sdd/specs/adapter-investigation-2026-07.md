# Investigacion de adapters - 2026-07 (fase 8, release 0.16.0)

Fecha de investigacion: 2026-07-05. Metodo: WebSearch + fetch de docs oficiales.
Objetivo: matar el vaporware. Ningun adapter queda en `hook_support: unknown`;
cada uno declara `maturity` y via recomendada de agentes de rol (`role_agents`).

Jerarquia por host (principio rector): feature nativa > tool del daemon MCP >
simulacion por prompt. Todo host con MCP debe usar el daemon como runtime
recomendado (un solo runtime agnostico, no 8 prompts distintos).

## Resumen

| Adapter | hook_support | MCP | Instrucciones persistentes | maturity | role_agents |
|---|---|---|---|---|---|
| claude-code | yes | `.mcp.json` | `CLAUDE.md` | production | native_subagents_or_mcp_daemon |
| codex | yes | `~/.codex/config.toml` | `AGENTS.md` | production | via_mcp_daemon |
| cursor | yes | `.cursor/mcp.json` | `.cursor/rules/*.mdc` | experimental | via_mcp_daemon |
| copilot | no | `.vscode/mcp.json` | `.github/copilot-instructions.md` | experimental | via_mcp_daemon |
| gemini | limited | `.gemini/settings.json` | `GEMINI.md` | experimental | via_mcp_daemon |
| qwen | yes | `.qwen/settings.json` | `QWEN.md` | experimental | via_mcp_daemon |
| deepseek | no | no documentado (oficial) | skills `SKILL.md` (no kernel) | experimental | prompt_simulation |
| generic-ai | not_applicable | n/a | prompt manual | production | prompt_simulation |

## Detalle por adapter

### claude-code (production)

- Hooks: SI. SessionStart, UserPromptSubmit, PreToolUse, PreCompact, Stop;
  implementados y en uso en este harness (scripts/claude-*.ps1).
- Subagentes reales: SI (`.claude/agents/*.md` con frontmatter name/description/
  tools; el host enforcea las tools). Proyeccion instalable con
  `scripts/install-host-integrations.ps1 -HostName claude`.
- MCP: `.mcp.json` en la raiz. Fuente: https://code.claude.com/docs/en/mcp.
- Headless para backend de agentes: `claude -p --output-format json
  --allowedTools "Read,Grep,Glob"`. Fuente: https://code.claude.com/docs/en/headless.

### codex (production) - vaporware muerto

- Hooks: SI (cambio vs 0.15.0, que decia `app_or_plugin_dependent`). Engine de
  hooks estable desde v0.124.0 (2026-04): PreToolUse, PermissionRequest,
  PostToolUse, PreCompact, PostCompact, SessionStart, SubagentStart,
  SubagentStop, UserPromptSubmit, Stop; config en `hooks.json` o tablas
  `[hooks]` de `config.toml`. Fuentes: https://developers.openai.com/codex/hooks
  y https://developers.openai.com/codex/changelog (verificado 2026-07-05).
- Instrucciones persistentes: `AGENTS.md` (limite de bytes; reemplazable via
  `model_instructions_file`). Fuente: https://developers.openai.com/codex/config-reference.
- MCP: `[mcp_servers]` en `~/.codex/config.toml` o `.codex/config.toml` del
  proyecto (trusted). Fuente: https://developers.openai.com/codex/mcp.
- Headless read-only para backend de agentes: `codex exec --sandbox read-only -`
  (read-only es ademas el default de `codex exec`). Fuentes:
  https://developers.openai.com/codex/noninteractive y
  https://developers.openai.com/codex/cli/reference.
- Evidencia de esta fase: backend `codex-cli` ejercitado de verdad por
  `agent_audit`/`agent_review` (ver orquestador/sdd/progress/evidence/mcp-dogfood-fase8.md).

### cursor (experimental)

- Hooks: SI (desde Cursor 1.7): `.cursor/hooks.json` con beforeShellExecution,
  beforeMCPExecution, beforeReadFile, afterFileEdit, stop, etc. Adopcion aun
  limitada segun la propia comunidad; no integrado por este harness todavia.
  Fuente: https://cursor.com/docs/hooks (verificado 2026-07-05).
- Instrucciones persistentes: `.cursor/rules/*.mdc` (frontmatter description/
  globs/alwaysApply). Template generado:
  `orquestador/integrations/cursor/rules/hebrinex.mdc`; instalador
  `scripts/install-host-integrations.ps1 -HostName cursor`.
  Fuente: https://cursor.com/docs (rules), verificado 2026-07-05.
- MCP: `.cursor/mcp.json` (proyecto) / `~/.cursor/mcp.json` (global).
  Fuente: https://cursor.com/docs/mcp.
- maturity experimental: template + snippet MCP generados pero sin validacion
  end-to-end en Cursor real por este harness.

### copilot (experimental)

- Hooks: NO. Sin contrato de lifecycle hooks documentado para Copilot en
  VS Code (la customizacion documentada es instructions/prompts/agents/skills).
  Fuente: https://code.visualstudio.com/docs/agent-customization/custom-instructions
  (verificado 2026-07-05).
- Instrucciones persistentes: `.github/copilot-instructions.md` (deteccion
  automatica en VS Code; tambien lo usa el coding agent de github.com).
  Template generado: `orquestador/integrations/copilot/copilot-instructions.md`;
  instalador `scripts/install-host-integrations.ps1 -HostName copilot`.
  Fuente: https://docs.github.com/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot.
- MCP: `.vscode/mcp.json` con clave top-level `servers`.
  Fuente: https://code.visualstudio.com/docs/agents/reference/mcp-configuration.

### gemini (experimental)

- Hooks: limited (sin contrato de lifecycle hooks documentado en gemini-cli a
  la fecha; no investigado en profundidad esta fase porque no estaba en
  `unknown`). Fuente consultada: https://google-gemini.github.io/gemini-cli/docs/
  (verificado 2026-07-05, superficial).
- Instrucciones persistentes: `GEMINI.md` (o `AGENT.md`) jerarquico.
- MCP: `mcpServers` en `.gemini/settings.json` / `~/.gemini/settings.json`.
  Fuente: https://google-gemini.github.io/gemini-cli/docs/tools/mcp-server.html.

### qwen (experimental) - vaporware muerto

- Hooks: SI (cambio vs 0.15.0, que decia `unknown`). Qwen Code documenta
  "Hooks" como feature de usuario y lifecycle de sesion en su daemon.
  Fuente: https://qwenlm.github.io/qwen-code-docs/en/users/features/hooks/
  (verificado 2026-07-05).
- Instrucciones persistentes: `QWEN.md` jerarquico (global/proyecto/directorio),
  configurable via `context.fileName`. Fuentes:
  https://qwenlm.github.io/qwen-code-docs/en/users/features/memory/ y
  https://qwenlm.github.io/qwen-code-docs/en/users/configuration/settings/.
- MCP: `mcpServers` en `.qwen/settings.json` / `~/.qwen/settings.json`.
  Fuente: https://qwenlm.github.io/qwen-code-docs/en/users/features/mcp/.
- Conclusion: Qwen Code (fork de gemini-cli) es un host capaz completo
  (instrucciones + MCP + hooks); el adapter deja de ser vaporware y la via
  recomendada es el daemon MCP.

### deepseek (experimental) - vaporware muerto

- Hooks: NO (cambio vs 0.15.0, que decia `unknown`). El CLI oficial Deep Code
  (`npm install -g @vegamo/deepcode-cli`, settings en `~/.deepcode/settings.json`)
  documenta Agent Skills (`SKILL.md` user/project) pero NO documenta hooks, ni
  MCP, ni archivo de instrucciones persistentes tipo AGENTS.md. Fuente:
  https://api-docs.deepseek.com/quick_start/agent_integrations/deepcode
  (verificado 2026-07-05).
- Terceros (DeepSeek-TUI y similares) agregan MCP (`~/.deepseek/mcp.json`) y
  lectura de AGENTS.md, pero no son contrato oficial estable: no se declaran
  como mecanismo del adapter.
- Conclusion: el adapter deja de decir "unknown" y declara la realidad: hoy la
  via es simulacion por prompt (generic-ai) + skills opcionales; reevaluar
  cuando Deep Code documente MCP.

### generic-ai (production)

- Hooks: not_applicable (es el fallback por prompt puro; no hay host).
- Sigue siendo el fallback universal documentado; no cambia.

## Acciones tomadas en 0.16.0

- `orquestador/adapters/*.yaml` y `orquestador/portability/adapter-matrix.yaml`
  actualizados con `hook_support` real, `maturity`, `role_agents` e
  `investigated_at: 2026-07-05`.
- `claude-code.yaml`: `supports_real_subagents: true` (roles auditor, reviewer).
- `scripts/check-adapter-drift.ps1` exige los campos nuevos y falla si
  reaparece `unknown` o si un subagente nativo declara tools de escritura.
- Snippets MCP por host en `orquestador/portability/mcp-hosts.md`.
