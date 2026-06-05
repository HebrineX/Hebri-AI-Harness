# AI Preset Policy

Version: 0.8.0

Esta politica define como configurar instrucciones persistentes para IAs sin duplicar el harness completo.

## Objetivo

Cada IA debe encontrar, validar y obedecer `.hebrinex`, cargar memoria por capas y usar el adapter correspondiente.

## Preset Minimo

Todo preset debe incluir:

- Hebri-AI-Harness como contrato obligatorio;
- regla de busqueda/copia/binding de `.hebrinex`;
- lectura de `PROJECT_BINDING.yaml`;
- lectura de `orquestador/memory/local/session-pin.md`;
- lectura de `orquestador/memory/memory-registry.yaml`;
- lectura de `orquestador/method/session-contract.md`;
- chat como interprete;
- leader visible;
- maximo 5 agentes activos;
- preflight y `SI` antes de efectos;
- reentry light ante compactacion, logs o perdida de foco;
- reentry full solo con motivo y aprobacion;
- prohibicion de usar harness externo como autoridad.

## Adapters

Usar `orquestador/adapters/<tool>.md` cuando exista. Si no existe, usar `orquestador/adapters/generic-ai.md`.

## Regla

Un preset no reemplaza al harness. Solo obliga a la IA a encontrarlo, validarlo, cargar su memoria minima y obedecerlo.

## Bloqueos

Bloquear si:

- el preset permite editar antes de contrato;
- no exige `SI` antes de efectos;
- no menciona binding;
- no carga `session-pin.md`;
- no respeta `memory-registry.yaml`;
- permite operar desde un harness de otra carpeta.