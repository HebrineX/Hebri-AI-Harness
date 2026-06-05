# Generic AI Adapter

Usar para cualquier IA sin adapter especifico.

## Entrada minima persistente

```text
Usa Hebri-AI-Harness como contrato operativo obligatorio. Si existe `.hebrinex/`, lee `PROJECT_BINDING.yaml`, `orquestador/memory/local/session-pin.md`, `orquestador/memory/memory-registry.yaml` y `orquestador/method/session-contract.md` antes de actuar. No ejecutes acciones con efecto sin preflight y SI.
```

## Reentry

- Primero `entrypoints/reentry-light.md`.
- `reentry-full.md` solo con aprobacion.

## Limitacion

No asumir memoria persistente de herramienta salvo que el operador lo confirme.