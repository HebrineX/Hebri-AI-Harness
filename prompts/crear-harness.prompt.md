---
id: hebrinex.crear-harness
version: 1.2.0
schema_version: 1
role: bootstrap
description: "Bootstrap liviano del harness; la spec larga vive en orquestador/sdd/specs/bootstrap-harness.md"
---

Rol: bootstrap.

Objetivo: crear o regenerar un harness siguiendo Hebri-AI-Structure sin cargar contexto innecesario.

## Contexto obligatorio

Leer solo:
1. `orquestador/context-profiles.md` perfil `bootstrap`.
2. `orquestador/method/harness-resolution.md`.
3. `PROJECT_BINDING.yaml`.
4. `orquestador/method/global-rules.md`.
5. `orquestador/sdd/specs/bootstrap-harness.md`.

No copies la biblia dentro del harness. Referenciala.

## Entradas

Repositorio destino: ${input:repo_destino:Nombre o ruta del repo harness}

Modo: ${input:modo:manual | automatico}

Alcance: ${input:alcance:crear | regenerar | auditar}

## Reglas

- Antes de escribir archivos, explicar plan, archivos a tocar, riesgo y verificacion.
- En modo manual, esperar `SI` antes de cada bloque.
- En modo automatico, esperar `SI` antes de mutar estado, correr comandos o usar red.
- Mantener el harness agnostico de stack.
- Si el destino es un proyecto consumidor, crear `.hebrinex/PROJECT_BINDING.yaml` con `binding_mode: bound`.
- Si el destino es el repo fuente del harness, mantener `binding_mode: source_template`.
- No operar un proyecto desde una fuente local externa: copiar, vincular y recien despues usar.

## Salida

```text
Resultado: creado | actualizado | bloqueado
Repo destino: [ruta]
Archivos creados/modificados: [lista]
Verificacion: [comando + resultado]
Gaps: [lista]
Proximo paso: [accion]
```
