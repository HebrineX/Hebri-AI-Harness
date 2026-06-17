---
description: "Migrar cualquier .hebrinex previo a Hebri-AI-Harness 0.8.9 sin contaminar proyectos"
---

# Migracion a Hebri-AI-Harness 0.8.9

Si no existe `.hebrinex/`, buscar fuente local libre `source_template`, copiarla a `<project_root>/.hebrinex/` excluyendo materialmente `infoHebri.md`, `.git/` y temporales, y vincular como `bound`.

Entrada minima post-copia: `PROJECT_BINDING.yaml`, `session-pin.md`, `memory-registry.yaml`, `memory-routing.yaml`, `context-budget.yaml` y entrypoint.

Preservar contexto local: `PROGRESS.md`, `orquestador/context/`, specs, state, registry, cycles, approvals, gates, reports, closures y locks. No escribir sin preflight + `SI`. No subir `.hebrinex/` al repo consumidor.