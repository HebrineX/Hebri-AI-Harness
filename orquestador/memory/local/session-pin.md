# Session Pin

Lectura minima obligatoria para rehidratar contrato sin cargar todo el harness.

## Memory layers

```yaml
schema: hebrinex.memory.session_pin
version: "0.1"
harness_version: "0.8.0"
binding_source: PROJECT_BINDING.yaml
memory_registry: orquestador/memory/memory-registry.yaml
memory_routing: orquestador/memory/memory-routing.yaml
session_contract: orquestador/method/session-contract.md
state: orquestador/sdd/progress/state.yaml
registry: orquestador/sdd/progress/registry.yaml
chat_role: interpreter
leader_required: true
max_active_agents_total: 5
approval_keyword: SI
external_effects_require_preflight: true
complete_memory_requires_approval: true
```

Si este archivo contradice `PROJECT_BINDING.yaml`, `state.yaml` o `registry.yaml`, detenerse y reconstruir desde las fuentes estructuradas.