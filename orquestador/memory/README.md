# Memory Layer

Esta carpeta define la memoria operativa del harness. No depende de la memoria conversacional de una IA.

## Principio

La memoria conversacional es accidental. La memoria del harness es contractual. El orquestador decide que capas se cargan.

## Capas

| Capa | Carga por defecto | Uso | Vencimiento |
|---|---:|---|---|
| local | si | contrato activo, foco actual, session pin | cambio de sesion, cwd o proyecto |
| daily | si, si corresponde al dia | decisiones y contexto fresco del dia | cierre del dia o archivo diario |
| cycle | si hay ciclo activo | fase/slice, roles, locks, gates y approvals | cierre del ciclo |
| project | por perfil | hechos estables, arquitectura, decisiones vigentes | cambio arquitectonico |
| complete | no | auditoria global, migracion o reconstruccion historica | manual |

## Regla de carga

1. Leer `memory-registry.yaml`.
2. Leer la ruta indicada por `memory-routing.yaml` segun el entrypoint.
3. No cargar `complete/` sin aprobacion humana y motivo declarado.
4. Si la memoria requerida falta, usar `entrypoints/reentry-light.md` antes de actuar.

## Autoridad

- `memory-registry.yaml` decide capas activas.
- `local/session-pin.md` condensa el contrato minimo.
- `daily/` no reemplaza `state.yaml` ni `registry.yaml`.
- `complete/` no se usa para trabajo diario salvo auditoria o reconstruccion.