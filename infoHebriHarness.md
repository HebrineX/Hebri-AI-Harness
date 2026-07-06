# infoHebriHarness

Resumen operativo de los cambios preparados para Hebri-AI-Harness 0.16.0.

## Version

- Version objetivo: 0.16.0.
- Base remota corregida: hotfixes posteriores a 0.15.0 absorbidos antes del release.
- Estado de CI previo: el fallo de GitHub Actions por `.gitattributes` y por `./init.sh` quedo corregido antes de montar 0.16.0.

## Cambios principales

- Se agregan integraciones host para Claude, Cursor y Copilot.
- Se agregan agentes nativos Claude generados desde fuentes canonicas del harness.
- Se agrega backend MCP para agentes con roles `agent_audit` y `agent_review`.
- Se agrega configuracion de backends en `mcp/agents-backend.yaml`.
- Se agrega ruta de migracion `0.15.0-to-0.16.0`.
- Se refuerza la matriz de adapters para declarar madurez, soporte de hooks, soporte de role agents y via recomendada.
- Se agrega documentacion de portabilidad MCP por host.
- Se agrega fixture negativa para bloquear herramientas de escritura desde agente Claude read-only.

## Seguridad y CI

- `hebrinex usage` mide dotfiles con APIs `System.IO` para evitar fallos del provider de PowerShell en Linux.
- Los validadores de bootstrap, bound update, backups y restore usan checks de archivo compatibles con dotfiles.
- `init.sh` queda trackeado con bit ejecutable `100755` para que GitHub Actions pueda correr `./init.sh`.
- `validate-release` recalcula `savings_docs_pct` y mantiene el claim conservador de 90%.

## Validacion local ejecutada

- `scripts/hebrinex.ps1 usage`: OK, `savings_docs_pct=94`.
- `scripts/validate-release.ps1`: OK.
- `scripts/validate-harness.ps1 -RunNegativeTests -SkipNestedValidators`: OK.
- `scripts/validate-cli.ps1 -RunNegativeTests`: OK.
- `scripts/validate-bootstrap.ps1 -RunNegativeTests`: OK.
- `scripts/validate-bound-update.ps1 -RunNegativeTests`: OK.
- `scripts/validate-bound-backups.ps1 -RunNegativeTests`: OK.
- `scripts/validate-bound-restore.ps1 -RunNegativeTests`: OK.
- `scripts/validate-agent-contracts.ps1 -RunNegativeTests`: OK.
- `scripts/validate-security-policy.ps1 -RunNegativeTests`: OK.
- `scripts/validate-migration.ps1 -RunNegativeTests`: OK.
- `scripts/validate-fixtures.ps1 -RunNegativeTests`: OK.
- `scripts/validate-command-gateway.ps1 -RunNegativeTests`: OK.
- `scripts/validate-state-machine.ps1 -RunNegativeTests`: OK.
- `scripts/validate-agent-runtime.ps1 -RunNegativeTests`: OK.
- `scripts/audit-harness.ps1 -RunNegativeTests`: OK.
- `scripts/check-adapter-drift.ps1`: OK.
- `scripts/validate-mcp.ps1 -RunNegativeTests`: OK, smoke MCP omitido localmente por SDK no instalado.
- `./init.sh` desde Git Bash: OK.

## Nota

Este archivo es informativo y no reemplaza los contratos operativos del harness.
