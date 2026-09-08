# Seguimiento del plan documental

Estos registros coordinan exclusivamente el plan de `migracion/`. No reemplazan `orquestador/sdd/progress/state.yaml`, el registry, los approvals, los locks ni los gates del Harness vigente. Ningún valor de estos JSON autoriza comandos o acredita una implementación.

## Archivos y propietarios

| Archivo | Propósito y propietario | Ciclo de vida |
|---|---|---|
| [state.json](state.json) | Leader: estado documental, fases y próxima acción. | Actualizar al cambiar el plan o sus dependencias; conservar estado veraz. |
| [registry.json](registry.json) | Leader: entregas, roles y revisiones de este paquete. | Añadir entregas/revisiones verificables; no borrar interrupciones ni atribuir agentes ficticios. |
| [gates.json](gates.json) | Leader: checks documentales y límites de la aceptación. | Actualizar después de comprobar correcciones; producto/runtime permanecen separados. |

Los tres usan JSON estándar, UTF-8 y `schema_version: 1`; son registros de planificación, no schemas del producto propuesto. Referencias `../` se resuelven desde esta carpeta. No contienen secretos ni autoridad sobre proyectos consumidores.

## Estado de entrega

El paquete sustantivo fue revisado documentalmente. Los cinco ajustes de revisión fueron comprobados por lectura; el intérprete `/root` completó la comprobación final documental sin incidencias. Las diez fases permanecen `planned`, todas las pruebas de producto `not_run` y no existe aprobación de implementación en estos registros.

El SI anterior `A-20260906-RO-01` cubrió la auditoría de lectura. La petición directa posterior autorizó crear el plan en `migracion/`; no se transforma en un envelope ni en un SI para implementar. El agotamiento de cuota de dos autores ocurrió después de entregar sus especificaciones. Se conserva esa historia: `autor_fases` permanece registrado como `interrupted_quota_after_delivery`; `validation_analyst` retomó, completó los ajustes de los siete documentos centrales y cerró normalmente según comprobación comunicada por `/root`. Una interrupción anterior no se borra del registro.

## Reentrada sin chat

1. Leer [state.json](state.json), [README principal](../README.md), [roadmap](../ROADMAP.md) y [P00](../fases/P00-baseline-y-contrato.md).
2. Revalidar la autoridad operativa y el árbol actual según el Harness vigente; las observaciones de 2026-09-08 son un baseline documental, no hechos permanentes.
3. Identificar entradas, decisiones y bloqueos de P00. Preparar un preflight concreto con read-set, write-set, efectos, pruebas y rollback.
4. Obtener la aprobación requerida antes de esos efectos. Registrar la ejecución real en la autoridad operativa que se haya acordado; estos JSON pueden enlazarla, nunca sustituirla.
5. Separar resultado esperado de obtenido. Un dictamen documental favorable no es PASS de CLI, seguridad, rendimiento, migración o MSI.

Estados de fase previstos: `planned`, `ready`, `in_progress`, `review`, `accepted`, `blocked`. Cambiar un estado requiere evidencia y alcance autorizado; no avanzar fases por mera existencia de documentos. Las correcciones al plan permanecen dentro del scope documental aprobado; cualquier ampliación a producto, instalación, Git, red o consumidores vuelve a su preflight.

## Verificación y límites

Las comprobaciones realizadas por el leader abarcan conteos estructurales, lectura de correcciones y parseo de estos JSON. Las verificaciones informadas por `/root` se identifican como tales. El check final del intérprete cubrió enlaces, JSON y write-scope; su resultado queda registrado en `DOC-FINAL-PACKAGE`. No se ejecutó un validador del Harness para certificar estos registros por analogía.

Comprobación informada por `/root` antes de crear este tracking: 17 Markdown, 10 fases, 80 tareas, 67 casos locales, R01–R18 presentes en VALIDACION, cinco ejemplos JSON parseados y 116 enlaces revisados. En ese momento sólo faltaban los dos enlaces a `operacion/README.md` y `operacion/state.json`, ahora materializados. Ese resultado se conserva como antecedente, no como comprobación retroactiva de los cuatro archivos de tracking.

Comprobación final ejecutada por `/root` e informada al leader: 21 archivos, 10 fases, 80 tareas, 67 casos normativos `Pxx-Vnn`, 18 requisitos, 124 destinos de enlaces locales existentes, cinco ejemplos JSON y tres JSON de tracking parseados; `issues: []` y `requirements_missing: []`. El control del scope mantuvo sin altas, bajas ni cambios los 407 archivos inspeccionados fuera de `migracion/`, con las exclusiones declaradas en `gates.json`. El leader volvió a parsear los tres JSON después de registrar este cierre. Esta aceptación corresponde únicamente a documentos y consistencia estructural: runtime, MSI, seguridad, migración y benchmark siguen sin ejecutar.
