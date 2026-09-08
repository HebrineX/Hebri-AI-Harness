# P00 — Baseline y contrato de ejecución

Estado: **plan propuesto; no ejecutado**. Owner: team leader. Requisitos: R02, R03, R06, R08, R09, R10, R16, R17, R18. Dependencias: ninguna implementación; sí aprobación explícita del alcance operativo de P00.

## Resultado y límites

Producir una línea de base verificable del producto y de consumidores de prueba, y convertir las decisiones abiertas en contratos que las fases siguientes puedan ejecutar. Esta fase no instala software, no modifica consumidores reales, no corrige automáticamente bindings y no considera los resultados históricos como pruebas nuevas. Crear documentación de planificación tampoco autoriza las implementaciones descritas aquí.

El proyecto de producto es el directorio que contiene este `migracion/`; todas las rutas de producto citadas son relativas a esa raíz. Un consumidor es otro directorio, identificado expresamente en el plan de operación. Nunca deducir el consumidor del directorio actual de una terminal. El baseline distinguirá fecha de observación, versión declarada, bytes inspeccionados y pruebas realmente ejecutadas.

## Entradas y bloqueo

Leer [requisitos](../REQUISITOS.md), [roadmap](../ROADMAP.md), [decisiones](../FUENTES-DECISIONES.md), `AGENTS.md`, `PROJECT_BINDING.yaml`, `HARNESS_VERSION`, `SHARED_MANIFEST.yaml` y los fragmentos necesarios del kernel vigente. La ausencia de `.hebrinex/` no habilita usar una fuente externa como autoridad del consumidor: registrar el caso y solicitar la excepción o bootstrap correspondiente. Para este repositorio fuente, conservar la excepción documental aprobada sólo dentro de su alcance.

Bloquear si no puede determinarse la raíz, si una aprobación presupone efectos no enumerados, si hay modificaciones previas sin propietario conocido o si el límite de contexto obliga a omitir restricciones. Una contradicción `source_template`/`bound` se documenta como discrepancia, con ambos archivos; no se resuelve eligiendo el valor conveniente. La versión `0.17.1` es un antecedente que debe verificarse de nuevo al ejecutar la fase.

## Contexto y responsabilidades

Aplicar `leader_light` hasta 2.600 tokens de kernel cuando alcance; `audit_global` hasta 12.000 sólo con autorización. Estimar con caracteres/4, registrar archivos y separar código consultado del kernel según el contrato actual. Un worker recibe un subproblema con referencias exactas; no recibe toda la auditoría por defecto. Si el presupuesto exige fragmentar la tarea, el leader publica slices más pequeños antes de delegar. La política final de contexto se desarrolla en [agentes y contexto](../AGENTES-CONTEXTO.md).

El leader mantiene contrato, alcance y gates; un implementer documental registra el inventario; reviewer verifica muestras y consistencia sin editar; auditor detractor cuestiona necesidad, dependencias y archivos nuevos. Mantener como máximo cinco agentes totales o el límite menor impuesto por el host. No declarar subagentes reales donde sólo existe simulación.

## Write-set futuro

Existentes potencialmente afectados: registros operativos de ciclo, state y registry, únicamente mediante el contrato vigente y aprobación separada. Futuros: evidencia del baseline y registro de decisiones dentro del ciclo autorizado; fixtures sanitizadas de consumidores en un directorio de pruebas aprobado. Owner documental: implementer; owner de registros de coordinación: leader. No cambiar CLI, plantillas compartidas, `.gitignore` de consumidores ni archivos personales en P00.

## Tareas ordenadas

| ID / rol | Entrada y acción | Salida y aceptación |
|---|---|---|
| P00-T01 / leader | Releer el contrato local y reconstruir estado desde archivos; identificar autorización y raíz. | Contrato fechado con rol, fase, read/write-set, presupuesto y discrepancias. Ningún campo inferido se etiqueta observado. |
| P00-T02 / implementer | Inventariar rutas compartidas/locales del manifiesto y cotejar scripts, MCP y hooks. | Tabla recurso→lector→escritor→raíz actual→clase futura. Cada escritor tiene referencia de archivo y símbolo o línea comprobada. |
| P00-T03 / implementer | Capturar comportamiento CLI existente, incluido contrato `stable0.5`, desde implementación y pruebas. | Catálogo de parámetros, salida y efectos documentados; ausencias y dudas explícitas. Se preserva como oracle de compatibilidad. |
| P00-T04 / auditor | Evaluar servicio bajo demanda frente a daemon, bases de datos y dependencias. | Dictamen motivado; servicio residente sólo si una necesidad aceptada no puede satisfacerse bajo demanda. |
| P00-T05 / leader | Resolver decisiones bloqueantes con responsables y evidencia requerida. | Registro de Windows/arquitectura/motor soportados, schema nuevo y límites iniciales. Si falta evidencia, asignar experimento bloqueante, no prometer soporte. |
| P00-T06 / implementer | Diseñar fixtures sin datos reales: proyecto nuevo, legacy intacto, drift, conflicto, copia duplicada y estado corrupto. | Inventario de fixtures y contenido esperado; secretos y evidencia histórica excluidos. |
| P00-T07 / reviewer | Contrastar requisitos, clasificación, decisiones y fixtures. | Revisión independiente con hallazgos abiertos o aceptación documental. No confundir aceptación de diseño con runtime probado. |
| P00-T08 / leader | Publicar gates y handoff por fase. | P01 puede comenzar sin consultar este chat, con entradas localizables y condiciones de stop. |

## Interfaces y errores

El inventario es evidencia, no una API nueva. Cada registro incluirá ID, ruta relativa, clasificación, origen de observación y estado `observed`, `inferred` o `not_run`. Definir los errores semánticos `ROOT_UNRESOLVED`, `BINDING_CONFLICT`, `APPROVAL_SCOPE_MISMATCH` y `CONTEXT_BUDGET_EXCEEDED`; los nombres de código son propuestos hasta fijar el contrato versionado. Un error devuelve causa, evidencia y próxima acción permitida sin imprimir secretos. No emitir comandos inventados como si existieran.

## Verificación ejecutable posterior

| ID | Preparación y acción | Oracle, evidencia y cleanup |
|---|---|---|
| P00-V01 | Tomar inventario del árbol autorizado; repetir el análisis de lectura. | Hashes y rutas permanecen iguales salvo evidencia expresamente autorizada. Guardar diff de inventarios; no borrar archivos previos. |
| P00-V02 | Entregar a reviewer tres casos de binding contradictorio. | Detecta todos y no propone mutación silenciosa. Registrar dictamen y referencias; fixtures se eliminan sólo dentro de su raíz comprobada. |
| P00-V03 | Seleccionar cinco escritores reales y seguir su resolución de rutas. | Cada uno aparece en T02 con destino verificable; comparar contra código, no contra una regex preparada. Evidencia: matriz firmada por rol revisor. |
| P00-V04 | Dar a otro agente sólo contrato, baseline y fase P01. | Puede nombrar entradas, límites y bloqueos sin memoria de chat. Registrar preguntas faltantes como defectos del handoff. No hay cleanup externo. |

## Preflight, gates y recuperación

Antes de capturar evidencia persistente, declarar ID, acción, CWD, read-set, write-set exacto, comandos, red/Git/externo, riesgo, rollback y verificación; esperar `SI` para los efectos. Pruebas que generan temporales también son efectos. No correr validadores del producto como lectura sin revisar sus escrituras.

Gate de entrada: autorización y contrato reconstruidos. Gate de salida: inventario revisado, decisiones bloqueantes resueltas o pruebas asignadas como bloqueantes, matriz R01–R18 sin requisitos huérfanos y auditor detractor favorable. Ninguna prueba pendiente puede figurar `passed`.

Si el baseline cambia durante la fase, invalidar solamente las observaciones afectadas y repetirlas; no sobrescribir evidencia anterior. Si falla una escritura documental, conservar preimagen y registrar operación incompleta. El rollback documental restaura archivos exactos, respetando modificaciones posteriores; no restaura snapshots completos de un repositorio ajeno.

## Handoff

Entregar enlace al baseline, decisiones y hashes; lista de dudas abiertas; estado de aprobación; operaciones ejecutadas y no ejecutadas; agentes y locks cerrados; siguiente tarea P01-T01. Un nuevo ejecutor debe leer primero [README](../README.md), esta fase y [arquitectura](../ARQUITECTURA-CONTRATOS.md), verificar vigencia del baseline y obtener nueva aprobación si cambia el write-set.
