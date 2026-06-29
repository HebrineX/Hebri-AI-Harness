---
description: "Auditar coherencia entre memoria, state, registry y evidencia"
---

# Auditar memoria

1. Lee `memory-registry.yaml`.
2. Revisa capas activas.
3. Compara contra `state.yaml`, `registry.yaml`, approvals y gates.
4. Clasifica hallazgos: stale, contradiction, missing, overreach.
5. Propone correccion sin editar hasta tener SI.