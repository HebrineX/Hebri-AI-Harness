---
description: "Cerrar memoria de ciclo y separar lo estable de lo temporal"
---

# Cerrar memoria de ciclo

1. Lee memoria de ciclo activa.
2. Cruza con `state.yaml`, `registry.yaml`, gate log y closures.
3. Marca resultado, gaps y handoff.
4. Promueve a memoria de proyecto solo decisiones estables con evidencia.
5. No cierres si quedan locks, agents o gates abiertos.