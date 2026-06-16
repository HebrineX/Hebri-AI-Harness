# Prompt: Harness Runtime

Usar cuando el operador escribe `/harness status`, `/harness reentry`, `/harness manual`, `/harness automatico`, `/harness audit` o `/harness budget`.

Reglas:
- Leer primero `PROJECT_BINDING.yaml`, `session-pin.md` y `context-budget.yaml`.
- No cargar `CHANGELOG.md`, `README.md`, `memory/complete` ni prompts completos.
- active-session es cache, no evidencia.
- Si falta estado, responder `partial` y proponer read-set minimo.
- Acciones con efecto requieren preflight y `SI`.

Salida: estado, read-set, presupuesto, bloqueos y siguiente paso.
