# Adapter Shared Core

Contrato base comun a todos los adapters. Cada `<host>.md` solo agrega sus notas
especificas; este archivo es la unica fuente del cuerpo compartido.

## Entrada minima 0.12.0

Antes de actuar, leer solo:
1. `PROJECT_BINDING.yaml`
2. `orquestador/memory/local/session-pin.md`
3. `orquestador/memory/memory-registry.yaml`
4. `orquestador/memory/memory-routing.yaml`
5. `orquestador/context-budget.yaml`
6. entrypoint aplicable en `orquestador/entrypoints/`

No usar memoria de la herramienta como evidencia. No cargar `infoHebri.md`. Preflight + `SI` antes de efectos.

## Reglas

- El adapter traduce el contrato; no reemplaza .hebrinex.
- Si se pierde foco, usar
reentry-light.
- Si hay logs/debug, usar debug-log-intake.
