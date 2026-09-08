# P02 — Estado, aprobaciones, aislamiento y recuperación

Estado: **plan propuesto; no ejecutado**. Owner: leader de seguridad operativa. Requisitos R02, R04, R06, R07, R10, R16, R17. Dependencias: P00 y P01 aceptadas. Contratos vinculantes: [arquitectura](../ARQUITECTURA-CONTRATOS.md), [validación](../VALIDACION.md), [requisitos](../REQUISITOS.md).

## Objetivo y exclusiones

Hacer que cada mutación de estado use una identidad de proyecto verificada, aprobación acotada, exclusión concurrente y una estrategia de recuperación. La instalación central no convierte al agente en autoridad ilimitada sobre consumidores. El estado, approvals, locks, journal y evidencia permanecen fuera del producto instalado. No incorporar un daemon, base de datos o broker privilegiado mientras el sistema de archivos local y procesos bajo demanda satisfagan los casos aprobados.

No habilitar todavía migración de consumidores reales ni ejecutar comandos de proyecto elevados. La fase no autoriza al implementer a aprobar su trabajo; las aprobaciones humanas se registran como tales sólo cuando hay una respuesta humana verificable para el alcance.

## Entradas, contexto y condiciones de stop

Read-set mínimo: interfaz P01; `scripts/command-gateway.ps1`; `scripts/state-machine.ps1`; `scripts/lib/hebri-common.psm1`; despachos mutables de `scripts/hebrinex.ps1`; schemas de approval/lock/state identificados por inventario. Cargar por operación, no todo el árbol. Presupuesto inicial: 3.500 tokens operativos por worker y 2.600 para leader; security policy y allowlists aplicables se leen completas dentro de su scope. Si no caben, reducir scope o solicitar presupuesto, jamás abreviar restricciones que cambian permisos.

Bloquear cuando una operación carezca de write-set enumerado, cuando no pueda probarse la raíz del lock, cuando el filesystem esté fuera de la matriz soportada o cuando el proceso no pueda distinguir recuperación de ejecución nueva. Un log histórico `passed` no autoriza consumir un approval nuevo.

## Write-set futuro

Existentes: gateway, biblioteca común, máquina de estados y puntos de mutación CLI; validadores relacionados y schemas actuales. Futuros: schema/versionado de journal y pruebas de concurrencia/fallos. Evitar inventar un módulo por operación; extraer una primitiva compartida sólo cuando tenga consumidores reales. Owner: implementer de runtime. Fixtures incluyen dos proyectos aislados y un directorio externo testigo. State/registry de la fase se actualizan por leader conforme al contrato operativo.

## Tareas ordenadas

| ID / rol | Entrada y trabajo | Salida y aceptación |
|---|---|---|
| P02-T01 / implementer | Enumerar todos los puntos que crean, modifican o eliminan datos, incluido rate-limit. | Inventario completo de efectos; ninguna consulta informa `writes=false` si persiste datos. |
| P02-T02 / implementer | Definir approval ligado a projectId, operación, plan/hash, raíces, versión de código, vigencia y alcance. | Validación rechaza ID falso, expirado, proyecto ajeno, plan cambiado y consumo incompatible. El texto de comando no sustituye la autorización humana. |
| P02-T03 / implementer | Implementar estados del journal canónico: prepared, applying, committed, rolling_back, rolled_back, recovery_required. La aprobación es una precondición separada, no un estado adicional del journal. | Transiciones permitidas con evidencia y equivalencia con ARQUITECTURA-CONTRATOS; error/interrupción no se presenta como éxito. |
| P02-T04 / implementer | Implementar adquisición exclusiva y atómica de lock por alcance. | Dos procesos no adquieren simultáneamente recursos solapados; registrar propietario, PID e identidad temporal del proceso. |
| P02-T05 / implementer | Implementar publicación segura de un archivo y journal para cambios multiarquivo. | Precondiciones y hashes se revalidan antes de commit; journal permite identificar la última etapa confirmada. No prometer atomicidad global entre volúmenes. |
| P02-T06 / implementer | Integrar los escritores enumerados, incluido bootstrap/update/restore en su modo permitido. | No existe bypass silencioso de approval/lock por dispatch directo. Excepciones documentadas requieren gate explícito. |
| P02-T07 / implementer | Definir recuperación de lock huérfano y operación interrumpida. | Recuperación verifica identidad del proceso y journal; TTL por sí solo no roba un lock activo. |
| P02-T08 / reviewer | Ejecutar adversariales y fallos inyectados en cada frontera. | Aislamiento, no pérdida silenciosa y resultados consistentes demostrados; findings abiertos bloquean salida. |

## Interfaces y errores

Toda mutación recibe un contexto resuelto por P01 y un descriptor de operación. Retorna operationId, estado final, recursos efectivamente cambiados, ubicación de evidencia y necesidad de recuperación. La consulta de estado de una operación es de lectura; persistir último acceso requiere otra operación declarada.

Errores propuestos: `APPROVAL_REQUIRED`, `APPROVAL_EXPIRED`, `APPROVAL_SCOPE_MISMATCH`, `LOCK_BUSY`, `LOCK_OWNER_UNVERIFIED`, `PRECONDITION_CHANGED`, `RECOVERY_REQUIRED`, `FILESYSTEM_UNSUPPORTED`. El error no imprime payload de secretos ni el contenido completo de comandos sensibles. Los nombres se formalizan en una API versionada antes de cambiar salida de CLI `stable0.5`.

La aprobación puede autorizar un plan con varios pasos, pero debe listar todos sus efectos. Reintentar después de fallo sólo utiliza la misma aprobación cuando el contrato define ese reintento como parte de la misma operación y las precondiciones siguen vigentes. No tratar una aprobación como token reutilizable para tareas distintas.

## Pruebas con oracle

| ID | Preparación y acción | Resultado exigido, evidencia y cleanup |
|---|---|---|
| P02-V01 | Dos procesos reales esperan una barrera y solicitan lock sobre el mismo fixture. | Sólo uno adquiere; el segundo recibe conflicto. Guardar timestamps/resultados; liberar con protocolo, no borrar lock a mano. |
| P02-V02 | Repetir con proyectos distintos. | Ambos progresan sin escribir en el otro proyecto. Comparar inventarios por projectId; limpiar fixtures propios. |
| P02-V03 | Invocar mutación real con approval expirado, ID ajeno y plan alterado. | Todas fallan sin writes de negocio. Registrar efectos de auditoría previstos separadamente; comprobar directorio testigo intacto. |
| P02-V04 | Terminar el proceso entre preparación, backup, publicación y commit. | Nueva invocación detecta recovery_required y ofrece camino determinado por journal. Ejecutar recuperación y comparar hashes con estado esperado. |
| P02-V05 | Crear lock con PID reutilizado o propietario no verificable. | No robar automáticamente; devolver diagnóstico y requerir recuperación aprobada. Guardar datos sanitizados de identidad. |
| P02-V06 | Modificar archivo entre plan y commit. | PRECONDITION_CHANGED; no sobrescribir edición concurrente. Conservar ambas evidencias y fixture hasta revisión. |
| P02-V07 | Ejecutar status y validación de lectura dos veces. | No crea rate-limit, cache, access timestamp persistido ni directorios. Evidencia: inventarios iguales. |

## Preflight, gates y rollback

El preflight especificará procesos hijos, interrupciones deliberadas, fixtures, registros de prueba y cleanup; nunca inyectar fallos sobre consumidores reales. Para la ejecución elevada o instalación se requiere otra fase. Auditor detractor revisa si basta exclusión por archivo con stdlib/plataforma; reviewer evalúa la implementación y no edita correcciones. El implementer responde hallazgos mediante nuevos cambios revisados.

Gate de salida exige que todos los escritores conocidos estén integrados o bloqueados explícitamente en modo central, pruebas reales de concurrencia y journal recuperable. Un test skipped de seguridad no satisface el gate. Locks activos, operaciones sin cierre o registros contradictorios impiden declarar complete.

Rollback de código no revierte automáticamente schema de estado. Antes de revertir, comprobar compatibilidad; si la fase introdujo datos nuevos, restaurar fixture o usar una transformación inversa especificada. En proyectos reales, preservar cualquier cambio posterior. El journal y el registro de una falla permanecen como evidencia, con retención y privacidad definidas.

## Handoff

Entregar inventario de escritores, versión del descriptor de operación, transición de estados, esquema de lock, matriz de fallos y resultados. P03 y P04 deben conocer cuáles controles aplica el runtime y cuáles dependen del host. Un ejecutor nuevo lee [README](../README.md), esta fase, interfaces P01 y último gate; empieza verificando locks y journal antes de cualquier mutación.
