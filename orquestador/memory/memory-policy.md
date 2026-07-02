# Memory Policy

Version: 0.11.0

## Objetivo

Evitar que el agente dependa de resumen de chat, memoria interna o re-entry manual repetido. La memoria se guarda en archivos y se carga por capas.

## Reglas

1. El leader mantiene `memory-registry.yaml`.
2. El chat visible reporta que memoria se cargo cuando hay re-entry o cambio de contexto.
3. Ningun rol carga memoria completa por comodidad.
4. La memoria diaria no puede sobrescribir hechos estables del proyecto.
5. La memoria local no puede inventar approvals vencidos.
6. La memoria de ciclo debe coincidir con `state.yaml` y `registry.yaml`.
7. La memoria completa requiere preflight y `SI` si implica lectura amplia o reconstruccion historica.
8. Si hay conflicto entre capas, gana la fuente mas estructurada: approvals/gates > state/registry > memory cycle > memory project > memory daily > memory local.

## Invalidation

Invalidar memoria local cuando cambia cwd, proyecto, binding, hay compactacion o el operador fija un nuevo hard lock.
Invalidar memoria diaria cuando cambia el dia operativo o el leader cierra jornada.
Invalidar memoria de ciclo cuando el ciclo pasa a `done`, `blocked` o `cancelled`.