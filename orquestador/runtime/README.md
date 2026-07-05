# Runtime Control Plane

El runtime es una vista operativa liviana. No es autoridad.

Autoridad real:
- `PROJECT_BINDING.yaml`.
- `orquestador/sdd/progress/state.yaml`.
- `orquestador/sdd/progress/registry.yaml`.
- gate logs, approvals, evidence y locks.

`active-session` puede ayudar al re-entry, status y presupuesto, pero no puede declarar `done`, aprobar acciones ni reemplazar evidencia.
Si contradice estado/registry, gana estado/registry y se reconstruye runtime.

## Enforcement 0.12.0

0.12.0 agrega decisiones ejecutables read-only:

- `scripts/state-machine.ps1` lee `orquestador/agents/lifecycle-registry.yaml` y bloquea transiciones invalidas.
- `scripts/agent-runtime.ps1` lee agent registry, capability registry y contratos de rol para bloquear capabilities faltantes o denegadas.

Estas decisiones no reemplazan state, registry ni evidencia. Sirven como gate operativo antes de instanciar un agente, cambiar lifecycle o permitir una capability.
