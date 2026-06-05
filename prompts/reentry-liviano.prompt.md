---
description: "Reconstruir contrato usando memoria local, diaria y de ciclo sin cargar todo el harness"
---

# Reentry liviano

Usa Hebri-AI-Harness 0.8.0.

1. Lee `PROJECT_BINDING.yaml`.
2. Lee `orquestador/memory/local/session-pin.md`.
3. Lee `orquestador/memory/memory-registry.yaml`.
4. Lee `orquestador/memory/memory-routing.yaml`.
5. Aplica `orquestador/entrypoints/reentry-light.md`.
6. Lee `state.yaml` y `registry.yaml`.
7. Declara contrato reconstruido.
8. No ejecutes acciones con efecto sin preflight y SI.

Salida:
- capas cargadas;
- estado reconstruido;
- bloqueos;
- siguiente paso.