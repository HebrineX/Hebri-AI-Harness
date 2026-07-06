# Codex Adapter

Contrato base compartido: leer `orquestador/adapters/_shared-core.md` (entrada minima 0.16.0, presupuesto en `orquestador/context-budget.yaml`, preflight + `SI` antes de efectos).

Notas especificas: archivo de instrucciones persistente `AGENTS.md`; hooks de lifecycle REALES (engine estable desde v0.124.0: `hooks.json` o `[hooks]` en `config.toml`); MCP via `[mcp_servers]` en `~/.codex/config.toml`. Agentes de rol via daemon MCP (`agent_audit`/`agent_review`); backend headless read-only `codex exec --sandbox read-only -`. Maturity: production. Investigado 2026-07-05 (ver `orquestador/sdd/specs/adapter-investigation-2026-07.md`).
