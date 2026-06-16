# Runtime Control Plane

El runtime es una vista operativa liviana. No es autoridad.

Autoridad real:
- `PROJECT_BINDING.yaml`.
- `orquestador/sdd/progress/state.yaml`.
- `orquestador/sdd/progress/registry.yaml`.
- gate logs, approvals, evidence y locks.

`active-session` puede ayudar al re-entry, status y presupuesto, pero no puede declarar `done`, aprobar acciones ni reemplazar evidencia.
Si contradice estado/registry, gana estado/registry y se reconstruye runtime.
