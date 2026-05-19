# Hebri-AI-Harness

Este directorio oculto contiene el sistema operativo para agentes IA, basado en la metodologia [Hebri-AI-Structure](https://github.com/HebrineX/Hebri-AI-Structure). Convierte el proyecto en un entorno estructurado por SDD, roles cerrados, ownership, gates y memoria por archivos.

## Como usarlo en 5 pasos

1. Revisar `AGENTS.md` y completar stack/comandos.
2. Elegir modo: `automatico` o `manual`.
3. Cargar solo el perfil de contexto necesario desde `orquestador/context-profiles.md`.
4. Registrar fase/slice en `PROGRESS.md` y `orquestador/sdd/progress/registry.md`.
5. Ejecutar el ciclo SDD: spec, aprobacion humana, implementacion, review, gates y cierre.

## Economia de Contexto

No cargues todo `.hebrinex`. Usar perfiles reduce 70-85% del contexto por ciclo:
- `leader`: estado, modos, protocolo y registry.
- `spec_author`: contexto de producto/arquitectura + templates SDD.
- `implementer`: spec activa + lock + policies minimas.
- `reviewer`: spec + artefacto impl + gate log.
- `bootstrap`: solo cuando se crea/regenera un harness.

## Modos

- `automatico`: el leader decide pasos seguros dentro del scope, pero pide `SI` antes de editar, correr comandos, llamar modelos/APIs o cambiar estado.
- `manual`: el usuario acepta cada cambio y cada paso. En una fase con 5 slices, se pide aprobacion por slice.

## Limite Multiagente

Maximo 5 agentes activos totales: 1 leader + 4 subagentes. Para 30 agentes se usan ciclos registrados, no 30 ejecuciones simultaneas.

## Que NO es

No es una aplicacion runtime por si sola, no reemplaza tests del proyecto y no concede permisos externos sin aprobacion humana.
