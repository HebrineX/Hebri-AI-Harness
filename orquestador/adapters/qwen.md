# Qwen Adapter

Contrato base compartido: leer `orquestador/adapters/_shared-core.md` (entrada minima 0.17.0, presupuesto en `orquestador/context-budget.yaml`, preflight + `SI` antes de efectos).

Notas especificas: Qwen Code soporta contexto persistente `QWEN.md` jerarquico, hooks (feature documentada) y MCP via `mcpServers` en `.qwen/settings.json`. Agentes de rol via daemon MCP. Maturity: experimental. Investigado 2026-07-05 (ver `orquestador/sdd/specs/adapter-investigation-2026-07.md`).
