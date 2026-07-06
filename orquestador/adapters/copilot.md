# Copilot Adapter

Contrato base compartido: leer `orquestador/adapters/_shared-core.md` (entrada minima 0.16.0, presupuesto en `orquestador/context-budget.yaml`, preflight + `SI` antes de efectos).

Notas especificas: archivo de instrucciones persistente `.github/copilot-instructions.md` (template generado, instalable con `scripts/install-host-integrations.ps1 -HostName copilot`); sin hooks de lifecycle documentados; MCP via `.vscode/mcp.json` (clave `servers`). Agentes de rol via daemon MCP. Maturity: experimental. Investigado 2026-07-05 (ver `orquestador/sdd/specs/adapter-investigation-2026-07.md`).
