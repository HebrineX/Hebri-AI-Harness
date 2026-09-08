# P09 — Release, operación y mantenimiento sostenido

Estado: **plan propuesto; no ejecutado**. Owner: team leader de release. Requisitos R01, R03, R05, R06, R08, R09, R10, R11, R12, R13, R14, R15, R16, R17, R18. Dependencia P08 aceptada con candidato inmutable. Referencias: [roadmap](../ROADMAP.md), [requisitos](../REQUISITOS.md), [validación](../VALIDACION.md), [fuentes](../FUENTES-DECISIONES.md).

## Objetivo y exclusiones

Entregar un producto central instalable y un procedimiento de operación que no dependa de su autor. El release incluye MSI, hashes, condiciones de soporte, comandos verificados, recuperación y evidencia de aceptación. La operación normal sigue siendo bajo demanda y con límites de proyecto/rol/contexto. No habilitar telemetría externa, actualizaciones automáticas, servicios residentes o migraciones masivas como parte implícita de publicar.

Esta fase no autoriza Git, push, tags, publicación, firma externa ni instalación en equipos reales por el solo hecho de existir el roadmap. Cada efecto debe tener preflight y aprobación específica. Un release candidato aceptado técnicamente puede permanecer local hasta que se apruebe su distribución.

## Entradas y condiciones de stop

Entradas: candidato/hash aceptado P08, matriz completa, licencias y atribuciones del payload/toolchain, claves de firma referenciadas por mecanismo seguro si se utilizan, documentación de instalación/lifecycle, compatibilidad API/schema, restricciones por host/modelo y plan piloto. Leer release policy vigente únicamente para el scope release; no cargar CHANGELOG completo sin motivo.

Bloquear publicación si difiere el hash respecto de P08, faltan condiciones de distribución, hay secretos o datos de instancia en payload, se perdió evidencia, o el paquete requiere pasos manuales no documentados. Si una corrección modifica runtime/packaging, el candidato vuelve a pruebas afectadas; no reemplazar un artefacto publicado conservando identificador y hash declarado.

## Contexto y write-set futuro

Leader usa resumen de aceptación, riesgos y checklist de entrega; reporter recibe facts/evidencia y no puede cambiar veredicto. Presupuesto documental 2.600 tokens para coordinación, ampliación explícita si requiere revisión release completa. El total siempre incorpora instrucciones, código, logs, artefactos resumidos, salida y margen según [AGENTES-CONTEXTO](../AGENTES-CONTEXTO.md).

Existentes potenciales: versión, notas de release, documentación de operación y workflows, según árbol que exista al ejecutar P09. Futuros: runbooks definitivos, manifiesto público de artefactos y matriz de soporte. Efectos externos: firma, publicación, repositorio/release y distribución; cada destino debe nombrarse exactamente en preflight. Datos operativos de usuarios siguen fuera del paquete. No almacenar claves privadas, tokens o memoria personal en documentación ni evidencia.

## Tareas

| ID / rol | Entrada y acción | Salida y aceptación |
|---|---|---|
| P09-T01 / leader | Congelar candidato y revisar gates P00–P08. | Acta release con hash, versión, API/schema, plataforma, limitaciones y aprobaciones pendientes. |
| P09-T02 / implementer documental | Redactar instalación, operación diaria, upgrades, incidentes y recuperación desde pruebas reales. El reporter sólo comunica resultados ya revisados y no produce ni aprueba estos documentos. | Comandos comprobados, salidas esperadas, permisos y stops; no instrucciones basadas en supuestos. |
| P09-T03 / implementer | Preparar manifiesto de distribución, licencias y firma según decisión aceptada. | Artefactos identificables; secretos fuera; firma/hashes verificables. |
| P09-T04 / reviewer | Repetir revisión de payload y prueba documental fría contra paquete final. | Instrucciones suficientes para un tercero, versión/hash consistentes con aceptación. |
| P09-T05 / leader | Presentar preflight exacto de publicación o entrega local. | Autorización explícita separada; sin publicación mientras falte SI. |
| P09-T06 / release operator | Publicar o entregar el artefacto aprobado; verificar acceso e integridad. | URL/ruta usable, hashes coincidentes y resultado registrado; no sólo mensaje de éxito de upload. |
| P09-T07 / leader + operador piloto | El leader planifica y coordina el piloto aprobado en entorno delimitado; el operador piloto ejecuta la implementación. El leader no implementa. | Instancia real y recuperación verificadas; sin migración de otros proyectos por proximidad. |
| P09-T08 / leader | Cerrar agentes, locks, state, registry, gates y backlog operativo. | Cierre comprobable, defectos residuales con responsables y ninguna operación inconclusa oculta. |

## Contrato operativo posterior

Los runbooks deben cubrir al menos: instalar offline; iniciar/vincular proyecto; consultar estado sin efectos; ejecutar tarea con aprobación; cambiar de agente con handoff; catálogo perdido; proyecto movido/copiado; integridad fallida; lock/journal interrumpido; migración legacy; repair; uninstall conservador y reinstalación. Cada runbook identifica preparación, comando real, efecto, oracle, errores, recuperación y condiciones de escalación.

La versión efectiva del producto se observa desde instalación verificada; el catálogo no decide seguridad. Un nuevo release declara API/schema soportados y si requiere una migración separada. No prometer compatibilidad ilimitada con versiones antiguas o todos los proveedores. Modelos/adaptadores reevaluados pueden cambiar resultados: conservar corpus, condiciones y fecha, y repetir pruebas cuando cambien capacidades o integración.

Retención de logs, journals y backups debe especificar propietario, ubicación y criterio antes del piloto. Eliminar datos de recuperación requiere autorización; no usar uninstall para hacer limpieza del usuario. Observabilidad local registra operaciones/errores con mínimo dato necesario. Telemetría externa y alertas automáticas requieren decisiones y approvals adicionales.

## Pruebas de entrega

| ID | Preparación y acción | Oracle, evidencia y cleanup |
|---|---|---|
| P09-V01 | Descargar/obtener el artefacto desde el destino autorizado en entorno limpio. | Hash/firma coinciden con candidato; instalación verificada. Si no hay publicación aprobada, comprobar entrega local y marcar distribución externa not_run. |
| P09-V02 | Operador nuevo sigue runbooks de instalación, init, tarea, handoff y consulta. | Cumple flujo sin chat ni ayuda del autor; registrar dudas como defectos y repetir tras corregir. |
| P09-V03 | Ejecutar runbook de incidente en fixture con journal/lock interrumpido. | Recuperación conserva datos y evidencia, identifica raíz correcta y no roba lock activo. |
| P09-V04 | Inspeccionar manifiesto/payload/documentación para datos propios o credenciales. | Cero inclusiones prohibidas; resultado revisado sin imprimir valores sensibles. |
| P09-V05 | Simular retiro de release defectuoso y recuperación a paquete compatible anterior. | Procedimiento identifica usuarios afectados por medios autorizados, ofrece paquete/hash correcto y no revierte schemas silenciosamente. |
| P09-V06 | Revisar cierre de ciclo y backlog. | State/registry/gates coinciden, agents cerrados, locks resueltos, no tests pendientes presentados como passed. |

## Preflight y gates

El preflight de publicación informa repositorio/destino, archivos exactos, tags/versión si aplica, red, credenciales referenciadas, riesgo, verificación y rollback. Eliminar o reemplazar releases públicos tiene alcance propio; no hacerlo para ocultar errores. Firmar puede alterar bytes del MSI: el hash final firmado es el que debe pasar validación de entrega, relacionándolo con el payload probado.

Auditor detractor revisa mantenimiento innecesario y asegura que el producto siga simple. Reviewer verifica artefacto final y reporter publica únicamente el veredicto aprobado. Gate final exige acceso usable al resultado autorizado, recuperación documentada, matriz real y cierre operativo. Si falta aprobación externa, informar "candidato listo, publicación pendiente"; no declarar distribución completa.

## Fallos, rollback y handoff permanente

Si falla upload, comprobar destino antes de reintentar para evitar duplicados; si integridad difiere, retirar disponibilidad mediante acción aprobada y abrir incidente. Si el piloto falla, detener expansión, conservar evidencia y ejecutar recuperación aprobada sin afectar proyectos ajenos. Rollback del producto y del proyecto siguen contratos separados P07/P05.

El handoff final contiene ubicación de artefactos, hashes, fuentes de build, soporte, owners operativos, runbooks, métricas de contexto/calidad, historial de decisiones y limitaciones. El siguiente mantenedor comienza por [README](../README.md) y roadmap, verifica versión y gates vigentes y abre un nuevo ciclo con aprobación. No necesita asumir que los agentes futuros tendrán memoria de esta conversación ni que su proveedor conserva las mismas capacidades.
