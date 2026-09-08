# Roadmap y puertas de avance

Estado documental: propuesta revisada; implementación pendiente. Todas las fases de implementación están `planned`; ninguna está aplicada ni validada en runtime.

## Secuencia

| Fase | Entrega verificable | Depende de | Requisitos principales | Pruebas |
|---|---|---|---|---|
| [P00](fases/P00-baseline-y-contrato.md) | Baseline, alcance, contrato operativo, decisiones y criterios congelados. | Revisión del plan | R01, R03, R08, R17, R18 | T00 |
| [P01](fases/P01-layout-y-resolucion.md) | Tres raíces y resolver único; layout clasificado por defecto como denegado. | P00 | R01, R02, R03, R16 | T01 |
| [P02](fases/P02-estado-aprobaciones-y-aislamiento.md) | Estado por instancia, approvals con identidad y efectos recuperables. | P01 | R03, R04, R06, R07, R16, R17 | T02 |
| [P03](fases/P03-agentes-contexto-y-proveedores.md) | Roles/capacidades, task packs acotados, handoff y proveedores evaluables. | P02 | R08, R09, R10, R11, R12, R17 | T03 |
| [P04](fases/P04-cli-binding-y-registro.md) | CLI central, binding y catálogo recuperable; shims/adaptadores compatibles. | P01, P02, P03 | R01, R03, R04, R06, R11, R17 | T04 |
| [P05](fases/P05-migracion-legacy.md) | Migración explícita de consumidores con drift y restauración comprobada. | P04 | R03, R05, R07, R16 | T05 |
| [P06](fases/P06-payload-launcher-y-msi.md) | Payload inventariado, launcher y MSI reproducible con operación offline definida. | P04, P05 | R01, R13, R14, R16 | T06 |
| [P07](fases/P07-upgrade-repair-y-uninstall.md) | Ciclo de mantenimiento MSI probado sin migrar ni borrar estados de proyectos. | P06 | R03, R05, R07, R15, R16 | T07 |
| [P08](fases/P08-validacion-integral.md) | Matriz integral con evidencia, benchmark y prueba de continuidad por otro equipo. | P03, P05, P07 | R01–R18 | T08 |
| [P09](fases/P09-release-y-operacion.md) | Release trazable, runbook y cierre; publicación bajo autorización separada. | P08 | R13, R14, R15, R17, R18 | T09 |

La secuencia es deliberadamente conservadora: el packaging depende de los contratos de aislamiento y migración. Se permite investigar o preparar fixtures independientes en paralelo cuando el leader asigna write-sets disjuntos; no se permite cerrar una fase saltando sus dependencias.

## Gate común de una fase

| Momento | Evidencia obligatoria | Responsable |
|---|---|---|
| Entrada | Dependencias aceptadas; árbol/revisión actual; read-set; riesgos y decisiones pendientes. | Leader |
| Antes de escribir | Auditor `detractor_senior` favorable o bypass expresamente aprobado; preflight concreto; aprobación real para los efectos; locks cuando corresponda. | Auditor + autoridad de aprobación |
| Producción | Task pack con presupuesto, implementación dentro del write-set, journal de efectos y evidencias. | Implementer |
| Revisión | Diff/artefactos, contratos aplicables, pruebas pertinentes; hallazgos independientes sin editar producción. | Reviewer |
| Salida | Aceptaciones PASS con evidencia; pendientes y riesgos explícitos; rollback; handoff frío; agentes/locks resueltos. | Leader, sobre revisión independiente |

`PASS` no se obtiene sólo porque exista el archivo o porque el código contenga una cadena esperada. Las pruebas deben observar la conducta contractual, incluyendo errores y ausencia de efectos fuera del scope. Un resultado `not_run`, `blocked` o `skipped` no cuenta como PASS.

## Replanificación y alcance

- Cambiar sólo los archivos y efectos del preflight vigente. Si aparecen nuevos privilegios, red, dependencias, otro proyecto, packaging/publicación o borrados, detener ese efecto y presentar un preflight nuevo.
- Un defecto que invalida el resolver, autorización o aislamiento bloquea las fases consumidoras. Registrar la dependencia afectada y volver a la fase propietaria.
- Una actualización de documentación no habilita instalar ni ejecutar software. Un MSI construido no habilita instalarlo; una instalación de prueba no habilita publicación.
- Si una prueba revela escritura en `InstallRoot` desde el consumidor, mezcla de instancias o approval reutilizable fuera de scope, no aceptar una excepción silenciosa: corregir el contrato/implementación y repetir los casos afectados.

## Cómo repartir el trabajo

Asignar tareas pequeñas por contrato y evidencia, no por “leer el repositorio completo”. Por ejemplo, P01 puede separar resolver, fixtures y revisión estática, siempre con productores distintos del aprobador. Los límites efectivos son `min(capacidad_del_host, 5)` agentes activos totales, incluido el leader; si el host no soporta agentes reales, registrar simulación explícita de roles.

No elegir proveedores más caros, agregar servicios, descargar runtimes ni aumentar el alcance de un benchmark sin autorización para ese costo/efecto. Los resultados deben identificar proveedor, modelo, versión, settings y dataset para permitir comparación.

## Cierre del roadmap

P09 sólo puede pasar a `accepted` cuando R01–R18 estén cubiertos por evidencia aplicable, el instalador haya pasado la matriz Windows acordada y otra persona/equipo pueda ejecutar el runbook sin recurrir al chat original. Los riesgos pendientes deben tener responsable y decisión registrada; cualquier waiver debe indicar requisito, efecto y vigencia. El cierre no borra evidencia ni convierte omisiones en éxitos.
