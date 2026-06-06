# Reentry Light

Ruta: `reentry_light`.
Presupuesto: <= 1800 tokens.

Usar cuando hay compactacion, logs, cambio de tema o duda de foco sin auditoria completa.

Leer:
- `PROJECT_BINDING.yaml`
- `orquestador/memory/local/session-pin.md`
- `orquestador/memory/local/active-contract.md`
- `orquestador/memory/local/current-focus.md`
- `orquestador/memory/memory-registry.yaml`
- `orquestador/memory/memory-routing.yaml`
- `orquestador/context-budget.yaml`
- memoria diaria o de ciclo solo si `memory-registry.yaml` la marca activa

No leer:
- `orquestador/memory/complete/`
- todo el repo
- `AGENTS.md` completo salvo que falte contrato kernel
- `session-contract-extended.md`
- `infoHebri.md`

Salida: estado reconstruido, bloqueos, siguiente paso y si requiere `SI`.