# Hebri-AI-Harness

Referencia operativa actual: **0.7.0**.

Este directorio oculto contiene el sistema operativo para agentes IA, basado en la metodologia [Hebri-AI-Structure](https://github.com/HebrineX/Hebri-AI-Structure). Convierte el proyecto en un entorno estructurado por SDD, roles cerrados, roles minimos con perfiles parametrizados, ownership, gates, auditoria, reporter, detractor pass y memoria por archivos.

## Como usarlo en 5 pasos

1. Validar `PROJECT_BINDING.yaml` y confirmar que el harness pertenece al proyecto activo.
2. Revisar `AGENTS.md` y completar stack/comandos.
3. Elegir modo: `automatico` o `manual`.
4. Cargar solo el perfil de contexto necesario desde `orquestador/context-profiles.md`.
5. Registrar fase/slice en `PROGRESS.md` y `orquestador/sdd/progress/registry.md`, luego ejecutar spec, aprobacion humana, implementacion, review, gates y cierre.

## Bootstrap Seguro

Si un proyecto no tiene `.hebrinex`, no se opera usando un harness local externo.

Flujo correcto:

1. Buscar una fuente local libre con `PROJECT_BINDING.yaml` y `binding_mode: source_template`.
2. Copiar esa fuente a `<project_root>/.hebrinex/`.
3. Cambiar la copia a `binding_mode: bound`.
4. Completar `project_root`, `project_name`, `repo_remote`, `bound_at` y `harness_instance_id`.
5. Si no existe fuente local libre, bajar obligatoriamente `https://github.com/HebrineX/Hebri-AI-Harness` y vincular la copia al proyecto.

Regla: una fuente local libre se copia; nunca se usa directamente para operar un proyecto consumidor.

## Economia de Contexto

No cargues todo `.hebrinex`. Usar perfiles reduce 70-85% del contexto por ciclo:

- `leader`: estado, modos, protocolo, taxonomia de roles y registry.
- `spec_author`: contexto de producto/arquitectura + templates SDD.
- `implementer`: spec activa + lock + policies minimas.
- `reviewer`: spec + artefacto impl + gate log.
- `auditor`: state, registry, gates, evidence, risk y detractor pass.
- `reporter`: outputs de auditor/reviewer/leader y audiencia objetivo.
- `bootstrap`: solo cuando se crea/regenera un harness.

## Modos

- `automatico`: el leader decide pasos seguros dentro del scope, pero pide `SI` antes de editar, correr comandos, llamar modelos/APIs o cambiar estado.
- `manual`: el usuario acepta cada cambio y cada paso. En una fase con 5 slices, se pide aprobacion por slice.

## Limite Multiagente

Maximo 5 agentes activos totales: 1 leader + 4 subagentes. Las especializaciones se expresan como perfiles, no como mas agentes. Para 30 asignaciones se usan ciclos registrados, no 30 ejecuciones simultaneas.

## Novedades 0.7.0

- `PROJECT_BINDING.yaml` vincula cada `.hebrinex` con su proyecto.
- Separacion estricta entre `source_template` y `bound`.
- `harness-resolution.md` prohíbe usar un harness externo como autoridad operativa.
- Re-entry post-compactacion obliga a validar binding, state, registry y approvals.
- Preflight y approval envelope incluyen `project_root`, `harness_path`, binding y scope externo.
- Prompt de migracion desde cualquier version previa a `0.7.0`.

## Novedades 0.6.0

- Anti-confirmation bias: el sistema valida por evidencia, no por autoridad humana o de agentes.
- Roles minimos con perfiles parametrizados: `interpreter`, `leader`, `executor`, `reviewer`, `auditor`, `reporter`.
- `auditor(profile: detractor)` para cuestionar conclusiones antes de cierres importantes.
- `reporter(profile: operator|technical|executive)` para comunicar sin ocultar riesgos.
- Clarification checklist, analysis checklist, blast radius y task graph como P0 antes de ejecutar.
- Registry Kanban con `role`, `profile`, `objective` y estado verificable.

## Que NO es

No es una aplicacion runtime por si sola, no reemplaza tests del proyecto y no concede permisos externos sin aprobacion humana.
