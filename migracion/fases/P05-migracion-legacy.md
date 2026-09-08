# P05 — Migración legacy reversible y preservación de drift

Estado: **plan propuesto; no ejecutado**. Owner: leader de migración. Requisitos R02, R03, R04, R05, R06, R07, R10, R16, R17, R18. Dependencias P00–P04 aceptadas. Entradas normativas: [arquitectura](../ARQUITECTURA-CONTRATOS.md), [validación](../VALIDACION.md), [fuentes](../FUENTES-DECISIONES.md).

## Objetivo y exclusiones

Convertir consumidores con copia completa a instancia liviana sin perder memoria, estado, personalizaciones o archivos desconocidos. El migrador tiene que poder explicar qué preserva, qué sustituye por referencia central y qué necesita resolución humana. No ejecutar una migración masiva, no borrar backups y no asumir que el manifiesto de la versión actual describe todas las versiones anteriores.

La actualización del producto y la migración del proyecto son operaciones independientes. El MSI nunca migra proyectos. Una versión legacy sin ruta probada queda bloqueada; no se declara compatible porque su número parezca cercano. El primer ensayo usa fixtures, luego una copia desechable autorizada y sólo después un consumidor piloto con aprobación propia.

## Entradas y bloqueos

Read-set: inventario de consumidores P00; `scripts/migrate-harness.ps1`; funciones backup/import/update/restore de `scripts/hebrinex.ps1`; validadores de migración/backups/update/restore; schema y semilla central; referencia confiable del release legacy. Cargar sólo una familia de versión y sus conflictos por slice. Presupuesto operativo inicial 3.500 tokens por worker; entradas de usuario, código, evidencia y salida se contabilizan adicionalmente en el límite real del host.

Bloquear si legacy y canonical contienen bytes distintos del mismo recurso; si no se dispone de baseline confiable para decidir si un archivo compartido fue modificado; si hay symlinks/junctions no soportados, espacio insuficiente, lock activo o drift nuevo tras el plan. La ausencia de referencia convierte el recurso en no verificado, no en descartable. Los archivos personales no se imprimen ni se copian al producto o catálogo.

## Write-set futuro

Existentes de producto: migrador, funciones de backup/restore/import y validadores. Futuros: schema del plan/journal de migración, fixtures de versiones soportadas y tests de fallos. Datos del consumidor: staging acotado, copia de recuperación fuera del árbol recorrido por backup, futura `.hebrinex/` liviana, catálogo propio y `.gitignore` sólo si aprobado. Enumerar ubicaciones absolutas resueltas antes de ejecutar. Owner: implementer de migración; reviewer no modifica el algoritmo ni el consumidor.

## Tareas ordenadas

| ID / rol | Entrada y acción | Salida y aceptación |
|---|---|---|
| P05-T01 / implementer | Definir clasificación por recurso y baseline legacy confiable. | Intacto, modificado, local, desconocido, generado, conflicto o personal; cada elemento tiene hash/origen y decisión. |
| P05-T02 / implementer | Implementar plan de sólo lectura con presupuesto de espacio y precondiciones. | Write-set y backup/staging concretos, conflictos listados, ningún secreto en output. Plan no crea directorios. |
| P05-T03 / leader + usuario | Resolver conflictos y decidir tratamiento de modificaciones. | Decisiones específicas registradas; no existe regla automática "gana legacy" ni Copy-Item -Force general. |
| P05-T04 / implementer | Crear snapshot verificado fuera de la fuente recorrida, con hashes y lista exacta de archivos. | Backups previos quedan excluidos; repetición no genera anidación. Validar espacio y permisos antes de copiar. |
| P05-T05 / implementer | Construir instancia nueva en staging y validar preservación. | Memoria/state propios conservados; recursos de producto intactos sustituidos por referencia; desconocidos retenidos. |
| P05-T06 / implementer | Publicar mediante operación recuperable con lock fuera de la carpeta reemplazada. | Journal identifica etapas; catálogo se reconcilia después del commit; fallo deja estado diagnosticable. |
| P05-T07 / implementer | Implementar restore que respete cambios posteriores. | Detecta divergencias desde migración y propone preservación/reconciliación antes de revertir. |
| P05-T08 / reviewer | Ejecutar matriz por versión y fallos antes de autorizar piloto. | Evidencia de equivalencia y recuperación; versiones no ensayadas permanecen unsupported. |

## Interfaces y errores

El plan incluye projectId, modo/versión origen, destino/API/schema, inventario y hashes, clasificación, decisiones de conflicto, ubicación de snapshot, estimación de espacio, etapas, rollback y approvals. El plan es inmutable durante apply: un cambio obliga a nuevo plan y autorización. Su ubicación y schema se fijan con P02 para no duplicar journal.

Errores propuestos: `LEGACY_VERSION_UNSUPPORTED`, `BASELINE_UNVERIFIED`, `LEGACY_CANONICAL_CONFLICT`, `DRIFT_AFTER_PLAN`, `BACKUP_INTEGRITY_FAILED`, `INSUFFICIENT_SPACE`, `MIGRATION_RECOVERY_REQUIRED`, `POST_MIGRATION_CHANGES`. El output debe informar qué etapa ocurrió realmente; nunca indicar restored si sólo se copiaron algunos archivos. Restore necesita estrategia para archivos nuevos, no sólo sobrescritura de archivos antiguos.

## Pruebas reproducibles

| ID | Preparación y acción | Oracle, evidencia y cleanup |
|---|---|---|
| P05-V01 | Fixture legacy intacto con memoria y state identificables; plan/apply/validate. | Datos propios iguales por hash o transformación schema especificada; producto no duplicado; identidad estable. Conservar snapshot hasta revisar. |
| P05-V02 | Fixture con shared modificado y archivo desconocido. | Plan los muestra y apply no los pierde; resolución humana simulada explícitamente dentro del test. Comparar inventarios. |
| P05-V03 | Crear legacy/canonical distintos y llamar apply real. | Bloqueo previo a commit, ninguna variante sobreescrita. Evidencia incluye ambos hashes, no contenido privado. |
| P05-V04 | Repetir backup dos veces con backups anteriores presentes. | Segundo snapshot excluye todos los backups y staging; tamaño crece sólo con cambios de datos, no recursión. |
| P05-V05 | Inyectar fallo después de snapshot, durante staging, antes/después de publicación y durante catálogo. | Recovery determinista, sin estado declarado exitoso incompleto; recuperar y comparar contra oracle por etapa. |
| P05-V06 | Modificar memoria después de migrar y solicitar rollback. | Detecta cambio posterior y bloquea overwrite silencioso; preserva copia nueva con aprobación del plan revisado. |
| P05-V07 | Alterar archivo del snapshot y solicitar restore. | Rechazo por integridad antes de aplicar datos; no restauración parcial. |
| P05-V08 | Ensayar falta de espacio, ruta fuera de raíz y lock ocupado. | Fallan sin pérdida; cleanup sólo de staging propio identificado por operationId. |

## Preflight y gates

El preflight incluye lector de baseline, copy/write/delete, snapshot, catálogo, `.gitignore`, procesos y cleanup. **Eliminar backups o copia completa antigua requiere un SI separado**, aun cuando apply haya sido aprobado. Excluir backups de Git antes de crearlos cuando el contexto del consumidor lo requiera; si esa edición no está autorizada, detener el efecto correspondiente.

Auditor detractor revisa preservación, dependencias y duplicación de formatos. Reviewer ejecuta algoritmo real y comparación de archivos; una prueba que sólo busca strings en código no demuestra migración. Gate previo a piloto exige todas las pruebas críticas por versión, ninguna corrupción silenciosa y recuperación demostrada después de interrupción.

## Fallos, rollback y handoff

Una interrupción exige leer journal y comprobar archivos reales antes de continuar. No repetir apply a ciegas. Una migración comprometida correctamente con catálogo incompleto conserva datos y repara índice; una publicación parcial entra en recovery_required. No asumir atomicidad entre directorios o volúmenes. Rollback conserva evidencias y revalida precondiciones, snapshots y cambios posteriores.

Entregar matriz versión→ruta soportada→resultado; plan piloto revisado; hash del producto y baseline; backups localizables; instrucciones de recuperación exactas; operaciones pendientes y locks cerrados. El nuevo agente empieza por [README](../README.md), esta fase, último journal y binding real, y obtiene aprobación específica para un consumidor nuevo. Haber migrado un fixture no autoriza producción.
