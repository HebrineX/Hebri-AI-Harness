# Session Pin

Rehidrata contrato sin cargar todo.

```yaml
schema: hebrinex.memory.session_pin
version: "0.1"
harness_version: "0.10.8"
binding_source: PROJECT_BINDING.yaml
memory_registry: orquestador/memory/memory-registry.yaml
memory_routing: orquestador/memory/memory-routing.yaml
context_budget: orquestador/context-budget.yaml
session_contract: orquestador/method/session-contract.md
state: orquestador/sdd/progress/state.yaml
registry: orquestador/sdd/progress/registry.yaml
chat_role: interpreter
leader_required: true
max_active_agents_total: 5
approval_keyword: SI
external_effects_require_preflight: true
complete_memory_requires_approval: true
infohebri_operational_load: denied
```

Si contradice binding/state/registry, detenerse y reconstruir.

```yaml
runtime_active_session: orquestador/runtime/active-session.template.json
runtime_is_authority: false
```
