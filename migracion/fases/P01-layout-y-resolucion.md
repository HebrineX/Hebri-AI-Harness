# P01 — Layout y resolución de raíces

Estado: **plan propuesto; no ejecutado**. Owner: leader de arquitectura. Requisitos: R01, R02, R03, R05, R13, R16, R17. Dependencia obligatoria: P00 aceptada. Referencias: [arquitectura](../ARQUITECTURA-CONTRATOS.md), [requisitos](../REQUISITOS.md) y [roadmap](../ROADMAP.md).

## Objetivo y exclusiones

Separar inequívocamente producto instalado, proyecto consumidor e instancia mutable. Un único resolver debe identificar recursos compartidos y locales para PowerShell, launcher y MCP. No construir todavía el MSI ni migrar proyectos reales. No corregir todos los lectores y escritores en esta fase: publicar la interfaz y pruebas del resolver; P02–P04 integran consumidores. El modo legacy sigue funcionando conforme al baseline, con selección explícita, hasta una migración aprobada.

La instalación central es un servicio bajo demanda: código compartido invocable cuando se necesita, sin proceso residente obligatorio. La selección de una instalación no puede venir de una ruta arbitraria incluida en un binding editable por el proyecto. El discovery debe resolver una familia de producto registrada y verificar la instalación antes de ejecutar sus componentes.

## Entradas y bloqueo

Entradas exactas: inventario P00; `SHARED_MANIFEST.yaml`; `scripts/lib/hebri-common.psm1`; fragmentos del mapa de `mcp/server.mjs`; binding y schemas actuales que identifique P00; decisiones de compatibilidad en [fuentes](../FUENTES-DECISIONES.md). No cargar prompts ni memoria histórica para diseñar rutas. Si se detecta un escritor no clasificado, bloquear publicación del contrato, ampliar el inventario y volver a revisión.

Bloquear ante categorías ambiguas, resolución relativa al CWD sin ProjectRoot explícito, fallback de dato mutable a InstallRoot o dependencias nuevas sin pase detractor. Un archivo local ausente puede significar estado incompleto; no significa permiso para usar el archivo compartido homónimo.

## Contexto y ownership

Worker: contrato del resolver, segmento del inventario relevante y pruebas, hasta 3.500 tokens de documentación operativa seleccionada; código por símbolos necesarios. Ese presupuesto parcial no habilita código ilimitado: el presupuesto TOTAL de [AGENTES-CONTEXTO](../AGENTES-CONTEXTO.md) incluye instrucciones host, tarea, documentos, código, outputs, reserva de respuesta y margen. Leader conserva presupuesto `leader_light` de 2.600 o solicita ampliación. Registrar cualquier ampliación y no resumir reglas de contención, allowlists o precedencia. Un reviewer recibe interfaz y casos negativos independientemente del razonamiento del autor.

Write-set futuro existente: `scripts/lib/hebri-common.psm1`, y sólo la integración mínima que las pruebas del resolver requieran. Futuros propuestos: `packaging/runtime-layout.json`, schema del layout y pruebas del resolver. El nombre final del módulo se fija antes del preflight; reutilizar biblioteca actual si evita una abstracción innecesaria. Producto y schemas son del implementer; aprobación y gates del leader/reviewer. No escribir bajo `Program Files` en pruebas unitarias: utilizar un fixture que simule su estructura y restricciones.

## Tareas

| ID / rol | Entrada y acción | Salida y criterio |
|---|---|---|
| P01-T01 / architect-implementer | Convertir clasificación P00 a categorías shared, template, instance, generated, backup y excluded. | Layout canónico sin solapamientos; rutas desconocidas denegadas por defecto. |
| P01-T02 / implementer | Especificar contexto `{InstallRoot, ProjectRoot, InstanceRoot, projectId, deploymentMode, runtimeApi}` y origen de cada campo. | Contrato versionado; no hay raíces obtenidas por heurística silenciosa. |
| P01-T03 / implementer | Definir funciones de lectura y destino de escritura separadas, con clasificación obligatoria. | Solicitar escritura de shared falla antes de crear directorios. Lectura opcional inexistente se distingue de corrupción. |
| P01-T04 / implementer | Implementar normalización y contención para rutas locales soportadas. | Rechaza traversal, ADS, providers ajenos, raíces incompatibles y reparse points no admitidos. La comparación es por segmentos, no prefijo textual simple. |
| P01-T05 / implementer | Definir discovery desde familia registrada e integridad del runtime. | Un binding con ruta executable inyectada no puede seleccionar código. Falta o corrupción del producto produce diagnóstico accionable. |
| P01-T06 / implementer | Añadir modo legacy explícito y detección de conflictos entre contratos. | Legacy conserva comportamiento documentado; central nunca vuelve a rutas legacy por ausencia de archivo. |
| P01-T07 / reviewer | Ejecutar matriz del resolver y revisar interfaces futuras PowerShell/MCP. | Mismo contexto y recurso tienen misma resolución en todos los consumidores previstos. |
| P01-T08 / leader | Fijar versión de interfaz y handoff a estado y adaptadores. | Cambios incompatibles necesitan versión nueva; contrato `stable0.5` no se redefine accidentalmente. |

## Interfaces y fallos

La respuesta de resolución debe incluir recurso lógico, clasificación, raíz efectiva, ruta validada, existencia y versión del contrato. No devolver un path de escritura para recursos compartidos. Las lecturas deben declarar si toleran ausencia; ningún consumidor debe interpretar un resultado vacío como CWD.

Errores semánticos propuestos: `RESOURCE_UNKNOWN`, `PATH_OUTSIDE_ROOT`, `REPARSE_POINT_UNSUPPORTED`, `RUNTIME_NOT_INSTALLED`, `RUNTIME_INTEGRITY_FAILED`, `BINDING_CONFLICT`, `LOCAL_STATE_MISSING`. El formato final y sus códigos numéricos se versionarán antes de integrarlos con CLI. No reutilizar éxito con un warning para una violación de frontera. Registrar path relativo cuando sea suficiente, evitando revelar rutas de otros usuarios.

## Pruebas concretas

| ID | Preparación / acción | Oracle / evidencia / cleanup |
|---|---|---|
| P01-V01 | Crear fixture con InstallRoot sólo lectura y dos proyectos; resolver reads y writes de cada clase. | Shared siempre sale de producto; mutable siempre del proyecto correcto. Inventarios prueban cero writes en producto. Borrar sólo fixture autorizado. |
| P01-V02 | Borrar un state local del fixture central. Ejecutar lectura obligatoria y, por separado, prepare-create con aprobación válida. | La lectura retorna `LOCAL_STATE_MISSING`; prepare-create devuelve únicamente el destino dentro de InstanceRoot y no crea archivos. Ninguna llamada retorna ruta compartida. Guardar resultados e inventario idéntico tras ambas consultas. |
| P01-V03 | Pasar `..`, path absoluto externo, nombre de raíz similar, ADS y provider a la función real. | Todos los escapes fallan antes de crear archivos. Evidencia incluye inventario externo intacto; no basta probar una regex aislada. |
| P01-V04 | Preparar junction y symlink en fixture si el host lo permite; repetir escritura. | Rechazo coherente. Si faltan privilegios, resultado `blocked`, no `passed`; repetir en VM adecuada. |
| P01-V05 | Ejecutar oracle legacy capturado en P00. | Salida y efectos siguen contrato anterior salvo diferencias explícitamente versionadas. Archivar diff y restaurar fixture. |
| P01-V06 | Alterar manifiesto de runtime y binding con ruta de script externo. | Se bloquea ejecución de código y se informa reparación. Comprobar que script testigo no se ejecutó. |

## Efectos, gates y rollback

El preflight identificará archivos exactos, fixtures, temporales, procesos y mecanismos de cleanup. Instalar un producto real o crear enlaces del sistema requiere alcance adicional; no es consecuencia implícita de una prueba de unidad. Auditor detractor valida la necesidad del nuevo layout y rechaza un segundo mapa manual. Reviewer confirma que el manifest de integridad se deriva del payload y no compite con la clasificación.

Salida exige pruebas positivas y negativas del resolver, compatibilidad legacy y matriz de escritores pendientes. Si una regla de contención depende de capacidades no disponibles en el motor elegido, registrar bloqueo antes de prometer soporte. Ante fallo, desactivar integración central incompleta y conservar modo legacy; no hacer fallback central→legacy en tiempo de ejecución. Restaurar sólo los archivos modificados si no tienen cambios posteriores y conservar evidencia del intento.

## Handoff reproducible

Publicar versión de contrato, layout, casos admitidos/denegados, matriz de plataformas probadas, referencias de tests y resultados. Indicar qué consumidores todavía usan mapa antiguo. P02 recibe un resolver aceptado, no sólo documentación. Un agente nuevo relee [README](../README.md), esta fase, interfaz vigente y últimos gates; verifica hashes antes de continuar y no necesita este chat para conocer errores o límites.
