# Cursor Adapter

Contrato base compartido: leer `orquestador/adapters/_shared-core.md` (entrada minima 0.16.0, presupuesto en `orquestador/context-budget.yaml`, preflight + `SI` antes de efectos).

Notas especificas: reglas persistentes `.cursor/rules/hebrinex.mdc` (template generado, instalable con `scripts/install-host-integrations.ps1 -HostName cursor`); hooks reales desde Cursor 1.7 (`.cursor/hooks.json`, no integrados aun por el harness); MCP via `.cursor/mcp.json`. Agentes de rol via daemon MCP. Maturity: experimental. Investigado 2026-07-05 (ver `orquestador/sdd/specs/adapter-investigation-2026-07.md`).
