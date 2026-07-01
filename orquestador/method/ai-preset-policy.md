# AI Preset Policy

Version: 0.10.10

Todo preset debe exigir:

1. `PROJECT_BINDING.yaml`
2. `orquestador/memory/local/session-pin.md`
3. `orquestador/memory/memory-registry.yaml`
4. `orquestador/memory/memory-routing.yaml`
5. `orquestador/context-budget.yaml`
6. entrypoint aplicable

Reglas:
- No cargar `infoHebri.md`.
- No usar memoria de herramienta como evidencia.
- No habilitar efectos antes de contrato, binding, presupuesto y `SI`.
- `reentry_light` ante compactacion o perdida de foco.
- `debug_log_intake` ante logs/debug.
- `reentry_full` requiere motivo, presupuesto y aprobacion.