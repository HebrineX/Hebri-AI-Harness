# Context Loading Policy

Version: 0.8.0

## Objetivo

Reducir tokens y evitar que el agente cargue todo el harness por ansiedad operativa.

## Orden recomendado

1. `PROJECT_BINDING.yaml`.
2. `orquestador/memory/local/session-pin.md`.
3. `orquestador/memory/memory-registry.yaml`.
4. `orquestador/memory/memory-routing.yaml`.
5. Entrypoint elegido.
6. Perfil de contexto minimo en `orquestador/context-profiles.md`.
7. Fuentes SDD/evidencia solo si el perfil las exige.

## Carga completa

La carga completa es una accion de alto costo. Requiere motivo, alcance y, si hay efecto posterior, aprobacion humana.