# P07 — Upgrade, reparación, desinstalación y rollback

Estado: **plan propuesto; no ejecutado**. Owner: leader de mantenimiento Windows. Requisitos R01, R03, R04, R05, R06, R07, R13, R14, R15, R16, R17, R18. Dependencias P05 y P06 aceptadas. Referencias [arquitectura](../ARQUITECTURA-CONTRATOS.md), [validación](../VALIDACION.md), [fuentes](../FUENTES-DECISIONES.md).

## Resultado y límites

Probar el ciclo de vida del producto sin cambiar ni eliminar datos de proyectos. Upgrade reemplaza código dentro de una línea API compatible; no convierte schemas locales. Repair restaura archivos administrados por MSI. Uninstall retira producto y sus entradas de sistema, conservando binding, memoria, catálogo y backups. Rollback de instalación fallida, rollback de un upgrade ya exitoso y rollback de migración son tres operaciones distintas con contratos diferentes.

No introducir minor upgrades/MSP ni múltiples versiones exactas simultáneas en el alcance inicial. No usar un proceso elevado para descubrir proyectos de otros usuarios y evaluar su contenido. Un proyecto incompatible queda sin disponibilidad operativa hasta contar con motor compatible o migración aprobada; no se modifica para hacerlo coincidir con el producto recién instalado.

## Entradas y bloqueo

MSI/hash y logs P06; producto N y N+1 construidos con toolchain fijado; compatibilidad de API/schema; fixtures con dos usuarios y dos proyectos; authoring MSI. Leer documentación oficial vigente del scheduling elegido antes de cambiarlo. Bloquear si no existe paquete anterior verificable, si N+1 cambia schema local sin ruta separada, o si la prueba no puede medir datos antes/después.

La identidad MSI y sus reglas de versionado deben fijarse antes de construir candidatos de upgrade. El producto debe mantener una familia estable y cambiar los identificadores necesarios conforme al tipo de upgrade. Las reglas efectivas se prueban; no basta un atributo en XML. Decisiones de scheduling/repair se registran en [FUENTES-DECISIONES](../FUENTES-DECISIONES.md).

## Contexto y write-set

Presupuesto documental 3.500 tokens por worker con entrada total contabilizada según [AGENTES-CONTEXTO](../AGENTES-CONTEXTO.md). Read-set acotado a authoring MSI, launcher discovery y matriz de compatibilidad. No cargar archivos de memoria real para probar preservación: usar marcadores sintéticos con hashes conocidos.

Existentes futuros de P06: authoring MSI, launcher si necesita diagnóstico, tests de packaging. Futuros de esta fase: pruebas lifecycle/fault injection y runbook de mantenimiento. Efectos VM: instalación/remoción de archivos, registro, PATH, procesos y snapshots autorizados. Los proyectos son fixtures con ownership explícito. No editar sus datos para conseguir que pase una prueba de preservación.

## Tareas

| ID / rol | Entrada y acción | Salida y aceptación |
|---|---|---|
| P07-T01 / implementer | Definir matriz N→N+1, misma versión, downgrade, API incompatible e instalación incompleta. | Resultado esperado por caso, sin fallback de datos ni migración automática. |
| P07-T02 / implementer | Authoring major upgrade con scheduling y rollback justificados. | Upgrade fallido conserva/restaura producto previo según contrato verificado; estados parciales diagnosticables. |
| P07-T03 / implementer | Definir repair para archivos versionados y scripts/documentos sin versión. | Archivo ausente o alterado queda restaurado mediante procedimiento documentado y pruebas; no asumir flags predeterminados suficientes. |
| P07-T04 / implementer | Asegurar uninstall declara sólo recursos propiedad del MSI. | No recorre ni elimina proyectos, catálogo, backups o memorias; elimina entradas propias del sistema. |
| P07-T05 / implementer | Diseñar rollback post-upgrade exitoso separado. | Prechequeo de compatibilidad, paquete previo verificado y plan de recuperación; ninguna degradación silenciosa de schema. |
| P07-T06 / implementer | Definir comportamiento con procesos activos. | Mantenimiento bloquea/cierra según interacción aprobada; nunca modifica proyecto para forzar salida. |
| P07-T07 / reviewer | Ejecutar matriz con fallos y hashes de datos antes/después. | Conservación demostrada para ambos usuarios; reportar fallos, reinicios y códigos reales. |
| P07-T08 / leader | Publicar runbook y gate lifecycle. | Operador externo puede repetir cada escenario y localizar su recuperación. |

## Interfaces y errores

El MSI actúa sobre producto por máquina, no depende del catálogo editable del usuario. La CLI muestra versión efectiva y necesidad de migración cuando corresponda, sin escribir durante consulta. Tras uninstall, el launcher puede no existir: no prometer que `doctor` funcionará; el camino es reinstalar el producto verificado y reconciliar bindings existentes.

Semánticas de error propuestas: `MAINTENANCE_IN_PROGRESS`, `PROCESS_IN_USE`, `INCOMPATIBLE_API`, `REPAIR_REQUIRED`, `PREVIOUS_PACKAGE_UNAVAILABLE`, `DOWNGRADE_UNSUPPORTED`. Los códigos reales MSI se registran junto al diagnóstico, sin sustituirlos por éxito genérico. Necesidad de reinicio debe comunicarse explícitamente. La documentación debe identificar qué recuperación usa privilegios y cuál opera sobre datos del usuario.

## Pruebas lifecycle

| ID | Preparación y acción | Oracle, evidencia y cleanup |
|---|---|---|
| P07-V01 | Instalar N, inicializar dos fixtures y actualizar a N+1 offline. | Producto actualizado; memoria/binding/state sin cambios; consultas usan API compatible. Guardar logs y hashes. |
| P07-V02 | Inyectar fallo después de retirada/preparación/publicación según scheduling real. | Producto previo recuperado o estado incompleto detectado con reparación definida; nunca éxito falso. Restaurar snapshot tras evidencia. |
| P07-V03 | Borrar archivo de producto y modificar script sin versión; ejecutar repair documentado. | Ambos vuelven a hashes de paquete; datos externos idénticos. Comprobar caso con cada flag real elegido. |
| P07-V04 | Desinstalar con dos usuarios y proyectos fuera del perfil actual. | Recursos MSI retirados; ambos datasets/catálogos intactos. No hubo enumeración de proyectos desde custom action elevada. |
| P07-V05 | Reinstalar tras uninstall y consultar bindings conservados. | Se recupera operación compatible sin reinicializar memoria ni cambiar IDs. |
| P07-V06 | Intentar downgrade y API incompatible. | Rechazo o procedimiento soportado explícito; cero mutación de proyecto. No se activa side-by-side no implementado. |
| P07-V07 | Mantener proceso runtime activo durante upgrade. | Resultado predefinido en P07-T06 y log de acción; no terminación indiscriminada de procesos. |
| P07-V08 | Actualizar catálogo malicioso con ruta de script testigo antes de maintenance. | MSI no carga ni ejecuta el testigo. Logs y marcador ausente prueban frontera de privilegios. |

## Preflight, gates y recuperación

Preflight enumera paquetes, VMs, elevación, fallos deliberados, usuarios de prueba y snapshots. Autorizar instalación no autoriza desinstalar producto de la máquina del usuario ni terminar procesos reales. Operaciones de test se realizan en VM aislada con fixture de ownership conocido. Auditor detractor revisa custom actions y prohíbe usar el mantenimiento como migrador de consumidores.

Gate de salida: logs y hashes de todos los escenarios críticos; scripts sin versión reparados; uninstall conserva datos; offline demostrado; incompatibilidad bloquea sin cambios. No aceptar sólo instalación limpia como prueba de lifecycle. Un hallazgo de pérdida de datos bloquea release aunque afecte a un caso poco frecuente.

Ante falla conservar log MSI, inventario de producto y datos y estado de procesos. Preferir reparación/reinstalación documentada a eliminar manualmente archivos del sistema. Rollback post-upgrade revalida si hubo migraciones separadas después; si las hubo, no instalar motor anterior incapaz de leerlas. Revertir snapshot es cleanup de laboratorio, no una promesa de recuperación en producción.

## Handoff

Entregar matriz ejecutada, paquetes N/N+1 y hashes, comandos reales de lifecycle, requisitos de elevación/reinicio y rutas de recuperación. P08 recibe pruebas reproducibles, no capturas aisladas. El siguiente ejecutor lee [README](../README.md), esta fase y último gate, confirma compatibilidad actual y utiliza aprobación nueva para cada entorno real.
