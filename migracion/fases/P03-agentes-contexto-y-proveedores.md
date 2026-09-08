# P03 — Agentes, contexto limitado y proveedores

Estado: **plan propuesto; no ejecutado**. Owner: team leader de orquestación. Requisitos R06, R08, R09, R10, R11, R12, R13, R16, R17, R18. Dependencias P00–P02 aceptadas. Contrato normativo de detalle: [agentes y contexto](../AGENTES-CONTEXTO.md); arquitectura: [contratos](../ARQUITECTURA-CONTRATOS.md).

## Resultado y exclusiones

Conservar el rol del Harness: estructurar trabajo, limitar capacidades y coordinar agentes con contexto acotado. El sistema central entrega paquetes de tarea verificables y capacidades explícitas. No asumir que todos los agentes, modelos o hosts cumplen igual sólo por recibir el mismo prompt. Un contrato escrito orienta conducta; un control del runtime puede impedir una operación; la documentación debe distinguir ambos niveles.

Esta fase no entrena modelos, no crea un agente omnipotente y no promete ausencia de fallos. Tampoco hace de una tabla de precios una prueba de calidad. La selección de modelo/proveedor se basa en capacidades declaradas, resultados medidos y restricciones del usuario. Las restricciones de aprobación, rutas y seguridad permanecen íntegramente disponibles en cada ejecución relevante.

## Entradas y bloqueos

Leer contratos P00–P02; [requisitos](../REQUISITOS.md); `scripts/agent-runtime.ps1`; validadores de runtime y contratos de agentes; `mcp/agent-backends.mjs`, `mcp/agents-backend.yaml` y perfiles de contexto seleccionados. Consultar adaptadores particulares sólo cuando se evalúe ese host. No cargar todos los prompts, pricing, historial y memoria completa para una tarea individual.

Bloquear cualquier ejecución si faltan restricciones obligatorias, capacidad de aprobación independiente o contexto suficiente para leer entradas críticas. Si un host no implementa una capacidad, declarar `unsupported` o modo limitado; no simular enforcement invisible. Cambiar a otro proveedor puede implicar salida de datos del entorno y requiere aprobación con read-set y destino. Las evaluaciones con servicios pagos o red son efectos separados.

## Presupuesto medido

El worker recibe esta fase por sección, taskpack y contratos seleccionados. El líder conserva un resumen operativo hasta 2.600 tokens de kernel, pero ese número **no representa la entrada total**. Cada ejecución contabiliza host/system, instrucciones de tarea, contratos, herramientas, código/evidencia, historial necesario y reserva de salida. Registrar estimación previa y uso real cuando el host lo informe; cuando falte telemetría, marcar estimado, nunca inventar consumo real.

La aceptación de ahorro usa un corpus fijo y repetible. Antes de cambiar el sistema, medir baseline de tokens, éxito de criterios, violaciones, reintentos y correcciones humanas. El objetivo porcentual y umbrales definidos en [VALIDACION](../VALIDACION.md) se fijan antes del experimento; no bajar el umbral después de observar resultados. Como gate mínimo: cero violaciones de invariantes; ningún caso previamente aprobado puede perder un criterio crítico; mejora de contexto demostrada en mediana y p95 sin regresión, conforme a los umbrales precongelados de VALIDACION, informando también coste total con reintentos. Si ahorro y calidad discrepan, bloquear promoción y rediseñar paquete.

## Write-set futuro

Existentes: runtime de agentes, adapters/MCP y validadores mencionados, perfiles de contexto y construcción de instrucciones cuando corresponda. Futuros: schemas task/request/result/handoff definidos en [AGENTES-CONTEXTO](../AGENTES-CONTEXTO.md), corpus de evaluación sanitizado y pruebas de conformidad. No duplicar schemas dentro de cada adaptador. Owner implementer: runtime; reviewer independiente: conformidad; leader: decisiones y presupuesto.

## Tareas

| ID / rol | Entrada y acción | Salida y aceptación |
|---|---|---|
| P03-T01 / implementer | Mapear leader, implementer, reviewer, auditor, reporter a capacidades verificables. | Matriz rol→read/write/tool/approval; producción y aprobación separadas. Si roles se simulan, queda explícito en evidencia. |
| P03-T02 / implementer | Implementar paquete de tarea según schema normativo. | Incluye objetivo, entradas referenciadas por hash, alcance, invariantes, presupuesto, salida, pruebas, stop y handoff; entradas ausentes bloquean despacho. |
| P03-T03 / implementer | Implementar carga selectiva por rol/tarea y procedencia de contenido. | Logs indican por qué se cargó cada archivo; datos externos no adquieren autoridad de instrucciones. |
| P03-T04 / implementer | Separar capacidades de host, adaptador y modelo. | Matriz indica enforcement real, instrucción solamente y capacidad no disponible; modo limitado muestra sus restricciones. |
| P03-T05 / implementer | Implementar result y handoff verificables. | Resultado enlaza cambios/evidencia, incertidumbres, operaciones pendientes y próximo paso; el nuevo agente revalida hashes y approvals. |
| P03-T06 / leader | Fijar corpus, baseline, candidatos y umbrales antes de ejecutar evaluación. | Acta de experimento reproducible; no confunde menor precio con mejor resultado. |
| P03-T07 / implementer | Ejecutar corpus por candidato y modo, incluyendo contexto reducido y reentry. | Dataset con calidad por criterio, tokens, latencia, reintentos y limitaciones de telemetría. |
| P03-T08 / reviewer + auditor | Revisar resultados, bypasses y separación de roles. | Recomendación por clase de tarea; no declaración de equivalencia universal. |

## Interfaces y errores

Consumir request/result/handoff del contrato central, sin crear variantes locales. El adaptador debe traducir transporte, no alterar objetivos, límites o significado de éxito. Errores semánticos: `CAPABILITY_UNSUPPORTED`, `CONTEXT_INCOMPLETE`, `CONTEXT_BUDGET_EXCEEDED`, `EVIDENCE_STALE`, `ROLE_CONFLICT`, `PROVIDER_UNAVAILABLE`. Reintento de proveedor no hereda autorización para nuevas escrituras ni para enviar datos a un destino distinto.

Un handoff debe permitir distinguir observado de inferido y `not_run` de `passed`. Si el contexto resumido omite una allowlist, gate o restricción aplicable, el runtime debe solicitar la fuente completa antes de continuar. La memoria sirve para localizar evidencia, no para reemplazarla.

## Pruebas

| ID | Preparación y acción | Oracle, evidencia y cleanup |
|---|---|---|
| P03-V01 | Despachar tarea de sólo lectura y solicitar escritura desde el agente. | Runtime/host con enforcement la bloquea; host sin enforcement no se certifica para ese caso. Registrar capa efectiva y archivo testigo intacto. |
| P03-V02 | Quitar una restricción obligatoria del taskpack y reducir presupuesto. | Despacho bloqueado, sin autoampliación ni omisión. Guardar error y reporte de carga. |
| P03-V03 | Interrumpir tarea y entregar handoff a otro agente sin historial. | Reconstruye estado desde fuentes; detecta hash cambiado y aprobación vencida; no repite efectos ya committeados. |
| P03-V04 | Ejecutar corpus baseline y candidato con mismas fixtures/criterios. | Cumple umbrales preacordados, informa distribución y coste de reintentos. Retener dataset sanitizado, retirar credenciales temporales por protocolo. |
| P03-V05 | Simular caída de proveedor, respuesta malformada e instrucciones hostiles en evidencia. | Sin elevación de autoridad ni ejecución de contenido externo; fallo accionable y recuperable. |
| P03-V06 | Usar adaptador sin subagentes reales. | Salida declara roles simulados y límites; nunca inventa agentes o revisión independiente. |

## Preflight, gates y recuperación

El preflight distingue edición local, ejecución de tests, uso de modelos/red, envío de fixtures y consumo pagado. Auditor detractor debe justificar cada capa adicional de orquestación. Reviewer comprueba invariantes y corpus, sin editar solución ni aprobar sus propias implementaciones. El gate exige evidencia de calidad y contexto; una reducción teórica de tamaño de archivos no basta.

Si falla el adaptador o se agota contexto, detener la tarea en un punto recuperable, conservar journal y emitir handoff mínimo verificable. No continuar con restricciones truncadas. Rollback restablece versión de taskpack/adaptador compatible; si el nuevo esquema produjo datos, conservarlos y transformar sólo mediante ruta definida. Cerrar procesos y locks de evaluación, sin borrar evidence que sustenta hallazgos.

## Handoff

Publicar schemas, matriz de capacidades, corpus/versiones, métricas, umbrales y resultados; limitaciones por host; ejemplos de reentry; lista de controles garantizados por runtime y los meramente instruidos. P04 integra estos contratos al servicio bajo demanda. Otro agente comienza por [README](../README.md), esta fase y los artefactos de contrato; verifica recursos, no necesita copiar toda la conversación.
