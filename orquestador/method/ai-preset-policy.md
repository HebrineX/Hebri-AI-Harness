# AI Preset Policy

Version: 0.7.8

Esta politica define presets minimos para Codex, Claude y Gemini cuando el operador necesita recuperar el foco del harness.

## Objetivo

Cada IA debe recibir el mismo contrato operativo, adaptado a su forma de trabajo, para evitar que el agente actue directo ante logs, errores o debug.

## Preset Minimo

Todo preset debe incluir:

- Hebri-AI-Harness como contrato obligatorio;
- project root;
- harness path o regla de bootstrap;
- chat como interprete;
- leader visible;
- maximo 5 agentes activos;
- lectura de `PROJECT_BINDING.yaml`;
- lectura de `AGENTS.md` y `session-contract.md`;
- preflight antes de efectos;
- re-entry si hay compactacion o desvio;
- prohibicion de usar harness externo como autoridad;
- regla de evidencia antes de changelog/release/docs historicas.

## Regla

Un preset no reemplaza al harness. Solo obliga a la IA a encontrarlo, validarlo y obedecerlo.

## Bloqueos

Bloquear si:

- el preset permite editar antes de contrato;
- no exige `SI` antes de efectos;
- no menciona binding;
- no separa interprete, leader y roles;
- permite operar desde un harness de otra carpeta.
