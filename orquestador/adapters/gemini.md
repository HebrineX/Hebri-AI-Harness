# Gemini Adapter

Contrato base compartido: leer `orquestador/adapters/_shared-core.md` (entrada minima 0.17.0, presupuesto en `orquestador/context-budget.yaml`, preflight + `SI` antes de efectos).

Notas especificas: contexto persistente `GEMINI.md`/`AGENTS.md` jerarquico; sin contrato de hooks documentado (limited); MCP via `mcpServers` en `.gemini/settings.json`. Agentes de rol via daemon MCP. Maturity: experimental. Investigado 2026-07-05 (ver `orquestador/sdd/specs/adapter-investigation-2026-07.md`).
