# CLAUDE.md - Hebri Harness Entry

Este proyecto esta gobernado por Hebri-AI-Harness. Claude debe usar este
archivo como bootstrap persistente aunque los hooks no hayan corrido todavia.

## Resolucion del harness

1. Si existe `.hebrinex/binding.json`, ese binding fija identidad y ubicacion de la
   instancia; el producto compartido se resuelve por la instalacion confiable, nunca
   por una ruta ejecutable tomada del binding.
2. Si existe `.hebrinex/PROJECT_BINDING.yaml`, usar el layout legacy local.
3. Si no existe `.hebrinex/` y existe `PROJECT_BINDING.yaml` en esta raiz,
   tratar esta carpeta como repo fuente `source_template`.
4. No usar un harness externo no validado como autoridad del proyecto activo.

## Entrada minima antes de actuar

Leer solo el kernel:

1. `.hebrinex/binding.json` en central, o `PROJECT_BINDING.yaml` en legacy/fuente
2. `orquestador/memory/local/session-pin.md`
3. `orquestador/memory/memory-registry.yaml`
4. `orquestador/memory/memory-routing.yaml`
5. `orquestador/context-budget.yaml`
6. entrypoint aplicable en `orquestador/entrypoints/`

Despues declarar contrato de sesion con hechos observados, no inferencias.

## Reglas no negociables

- Rol del chat: interprete.
- Leader visible obligatorio; si no hay subagentes reales, simular roles de
  forma explicita y trazable.
- No escribir, ejecutar comandos con efecto, usar red ni git remoto sin
  preflight y `SI` explicito del operador.
- No usar memoria interna de Claude como evidencia.
- No cargar `infoHebri.md`, `orquestador/memory/complete/*`, changelog completo,
  README completo ni todo `.hebrinex/` por defecto.
- Ante logs, errores o debug: reconstruir contrato, estado, ciclo y evidencia
  antes de proponer acciones.

## Reentry brief

Si existe en modo legacy, usar el brief generado:

- legacy bound project: `.hebrinex/orquestador/runtime/claude/reentry-brief.md`
- source template: `orquestador/runtime/claude/reentry-brief.md`

En `central_instance`, el hook calcula el brief sin escribir. Si el binding no se
resuelve, ejecutar primero `scripts/hebrinex-central.ps1 status` y proponer
`reconcile`; no buscar scripts dentro del proyecto.

En modo legacy/fuente, si no existe o esta viejo, proponer ejecutar:

- legacy bound project: `.hebrinex/scripts/claude-reentry.ps1`
- source template: `scripts/claude-reentry.ps1`

El brief ayuda, pero no reemplaza este contrato minimo.
