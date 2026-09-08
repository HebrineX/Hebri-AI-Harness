# P04 — CLI, binding y catálogo recuperable

Estado: **plan propuesto; no ejecutado**. Owner: leader de integración. Requisitos R01, R02, R03, R04, R06, R07, R10, R13, R16, R17, R18. Dependencias P01–P03 aceptadas. Referencias: [arquitectura](../ARQUITECTURA-CONTRATOS.md), [agentes](../AGENTES-CONTEXTO.md), [validación](../VALIDACION.md).

## Objetivo y exclusiones

Ofrecer una interfaz bajo demanda que inicialice una instancia liviana, resuelva el producto central y permita consultar/reconciliar proyectos. No copiar scripts, políticas y prompts completos en cada consumidor. Conservar el contrato CLI legacy `stable0.5` hasta introducir una interfaz nueva explícitamente versionada. Las palabras `init`, `bind`, `status`, `doctor`, `validate`, `list`, `migrate`, `upgrade` y `unbind` describen la interfaz propuesta; **no son instrucciones para ejecutar comandos existentes**.

No implementar aún la conversión legacy ni el mantenimiento MSI. Los comandos correspondientes deben declararse no disponibles o entregar un plan soportado, nunca éxito ficticio. El catálogo por usuario es un índice reconstruible: no puede ejecutar código ni reemplazar binding, memoria o estado del proyecto.

## Entradas y bloqueos

Leer contratos de raíces, operaciones y taskpack aceptados; `scripts/hebrinex.ps1`; validadores de CLI/bootstrap; binding legacy y datos semilla clasificados; schemas nuevos normativos. Bloquear init si hay instancia preexistente incompatible, identidad duplicada no resuelta, raíz fuera del soporte o modificación `.gitignore` necesaria no incluida en aprobación. La detección de un proyecto no es permiso para cambiarlo.

La semilla debe iniciar en estado pendiente, sin aprobación, lock, historial de tareas realizadas o evidencia de esta fuente. `binding.json` es el nuevo contrato central; YAML sigue siendo entrada legacy, no una segunda autoridad editable para el mismo proyecto. Si ambos contradicen identidad o modo, fallar con instrucciones de reconciliación.

## Contexto y write-set futuro

Worker usa esta fase por sección, schemas y símbolo CLI necesario; presupuesto operativo 3.500 tokens y registro separado de instrucciones host, código, evidencia y salida reservada. Leader mantiene su perfil aprobado; cargar el inventario entero sólo si se está revisando cobertura. Una lectura parcial no puede omitir reglas de identidad o aprobación.

Existentes: CLI y validadores relacionados; hooks/adaptadores que dependan de `.hebrinex/scripts` según matriz P00. Futuros: schema binding JSON, schema de entrada de catálogo, semilla de instancia, pruebas de CLI central. Datos futuros por operación: `.hebrinex/binding.json`, configuración e `instance/`; entrada `%LOCALAPPDATA%/Hebri-AI-Harness/projects/<projectId>.json`; recuperación de catálogo si corresponde. Rutas concretas serán resueltas y enumeradas en el preflight de cada operación. No escribir en `ProgramData` ni modificar catálogo de otros usuarios.

## Tareas

| ID / rol | Entrada y acción | Salida y aceptación |
|---|---|---|
| P04-T01 / implementer | Definir grammar/versionado de CLI nueva junto al oracle stable0.5. | Ayuda, salidas, errores y efectos de cada comando; compatibilidad antigua probada. |
| P04-T02 / implementer | Implementar binding JSON desde schema aprobado. | ID estable, raíces relativas verificadas, requisitos API/schema y discovery confiable; ninguna ruta executable arbitraria. |
| P04-T03 / implementer | Implementar init mediante plan, aprobación, lock, staging, validación y commit. | Instancia mínima válida y sin datos heredados; repetición idempotente o conflicto explícito. |
| P04-T04 / implementer | Implementar catálogo por archivo/proyecto y reparación de registro incompleto. | Proyecto válido sobrevive fallo del índice; estado `registration_pending` es detectable y reconciliable. |
| P04-T05 / implementer | Implementar status/list/doctor-check sin efectos. | No crea cache, carpetas ni actualiza último acceso durante consultas. Health se calcula o se identifica como observación fechada. |
| P04-T06 / implementer | Implementar reconciliación de movido, ausente y duplicado. | Si ambas rutas existen con mismo ID, requiere distinguir copia/traslado; copia independiente obtiene ID nuevo mediante aprobación. |
| P04-T07 / implementer | Implementar unbind conservador y adaptar hooks. | Desvincula sin borrar datos; hooks invocan producto central confiable; scripts locales no elevados. |
| P04-T08 / reviewer | Probar semántica, efectos y experiencia desde documentación pública. | Otro operador completa flujo sin conocimiento del árbol fuente. |

## Interfaces y errores

El binding contiene identidad y compatibilidad; el catálogo contiene ubicación conocida y observaciones fechadas, no secretos ni aprobaciones. Última versión verificada es una observación, no autoridad de selección. La interfaz de consulta devuelve versión efectiva y estado del producto sin persistirlos implícitamente.

Errores propuestos: `PROJECT_ALREADY_BOUND`, `PROJECT_ID_DUPLICATE`, `PROJECT_MOVED`, `PROJECT_NOT_FOUND`, `BINDING_SCHEMA_UNSUPPORTED`, `REGISTRATION_PENDING`, `RUNTIME_NOT_INSTALLED`, `GITIGNORE_APPROVAL_REQUIRED`. Si falla registro después del commit local, la operación completa retorna `status: failed`, `exit_code: 8` (`RECOVERY_REQUIRED`), `writes_performed: true` y lista los efectos confirmados. El binding válido se conserva y el catálogo queda pendiente; nunca retornar `applied` o exit 0. No revertir datos válidos del proyecto sin explicar el plan. Buscar proyectos exige raíces delimitadas; no escanear todos los discos por defecto.

## Pruebas concretas

| ID | Preparación y acción | Oracle, evidencia y cleanup |
|---|---|---|
| P04-V01 | Crear dos proyectos vacíos en fixture y ejecutar init aprobado. | Tienen IDs distintos, sólo datos locales y ninguna copia de runtime; inventario por clasificación. Cleanup incluye catálogo test, nunca perfil real. |
| P04-V02 | Ejecutar init segunda vez y con bindings contradictorios. | Primer caso no duplica ni reinicia memoria; segundo bloquea sin sobrescribir. Comparar hashes. |
| P04-V03 | Denegar escritura del catálogo después de commit local. | Proyecto válido con registration_pending; reconciliación aprobada crea una única entrada. Guardar journal. |
| P04-V04 | Mover fixture y después duplicarlo conservando ID. | Traslado se reconcilia; copia simultánea exige identidad nueva. No decide por nombre de carpeta. |
| P04-V05 | Corromper/eliminar entrada de catálogo y consultar/reconstruir. | Consulta no muta; reconstrucción sólo en raíces aprobadas y desde binding validado. Memoria queda intacta. |
| P04-V06 | Ejecutar status/list/doctor-check sobre proyecto inexistente y válido. | Inventarios del usuario, producto y proyectos no cambian. Output distingue ausencia de corrupción. |
| P04-V07 | Hacer unbind y ejecutar hooks en host compatible. | Datos conservados; hook descubre instalación válida o falla con reparación; no ejecuta script externo testigo. |

## Preflight y gates

Separar efectos de código/test de binding real. El preflight de init incluye `.gitignore` si se propone modificarlo; preflight de catálogo identifica usuario y raíces. Instalar hooks globales es un efecto distinto de crear una instancia local. No invocar Git ni abrir red como consecuencia oculta de descubrir proyectos.

Auditor detractor verifica que el catálogo no duplique autoridad y que la semilla no replique el producto. Reviewer ejecuta casos negativos sobre el componente real. Gate de salida: CLI versionada, consultas sin writes, legacy estable y dos proyectos aislados funcionando offline con producto fixture/instalación de prueba aprobada.

## Recuperación y handoff

Si falla staging, limpiar sólo objetos propios después de registrar error; si falla catálogo, conservar la instancia válida y reconciliar; si falla unbind, mantener binding coherente o señalar recuperación. El rollback nunca borra datos del usuario porque el índice falló. Conservar preimagen de `.gitignore` y no sobrescribir ediciones concurrentes al revertir.

Handoff a P05 incluye CLI exacta vigente, schema, semillas, errores, ubicaciones resueltas y pruebas. Handoff a P06 incluye contrato del launcher y descubrimiento sin rutas personales. Un nuevo agente lee [README](../README.md), esta fase, comandos versionados y evidencia de aceptación, verifica instalación/identidad y solicita aprobación del efecto siguiente.
