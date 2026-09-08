# P08 — Validación integral e independencia del ejecutor

Estado: **plan propuesto; no ejecutado**. Owner: leader de aceptación. Requisitos R01–R18. Dependencias P00–P07 aceptadas; sus pruebas son entradas, no sustituyen los recorridos integrales. Fuente normativa de cobertura: [VALIDACION](../VALIDACION.md). Referencias: [requisitos](../REQUISITOS.md), [arquitectura](../ARQUITECTURA-CONTRATOS.md), [agentes](../AGENTES-CONTEXTO.md).

## Objetivo y límites

Demostrar que el producto instalado cumple el rol del Harness en un entorno limpio, con dos proyectos aislados y ejecutores distintos. La aceptación reúne instalación, orquestación, contexto, aprobaciones, estado, migración, recuperación y mantenimiento. Un conjunto de unit tests exitosos no demuestra estos recorridos; una demo feliz tampoco cubre pérdida de datos o bypass de aprobación.

No implementar nuevas funcionalidades para ampliar el alcance durante aceptación. Defectos encontrados vuelven a la fase propietaria con caso reproducible, severidad y criterio de cierre; P08 se reejecuta sólo en superficies afectadas más los recorridos críticos. No usar consumidores reales para pruebas destructivas. No prometer que ningún agente podrá equivocarse: demostrar controles, documentación y límites con evidencia.

## Entradas y condiciones de bloqueo

Entradas exactas: MSI/hash candidato; versión de código y toolchain; paquete de evidencia de P00–P07; schemas y runbooks; corpus de P03; fixtures legacy de P05; VMs y cuentas de prueba; matriz de plataformas acordada. Validar que los hashes coinciden con el candidato, no con un build anterior. Bloquear si faltan evidencias críticas, si hay findings de pérdida de datos/integridad abiertos, o si algún esquema de salida cambió sin versionar.

Las pruebas usan los estados canónicos de [VALIDACION](../VALIDACION.md): `not_run`, `pass`, `fail`, `blocked` y `not_applicable` únicamente cuando ese contrato lo admita y con justificación revisada. No convertir un bloqueo de entorno en un aprobado. Registrar si la evidencia corresponde a simulación, componente real, fixture, VM limpia o consumidor piloto. Capturas de pantalla complementan logs y hashes, no reemplazan el oracle.

## Contexto y write-set futuro

El leader lee matriz de cobertura, riesgos y resultados compactos; cada tester recibe un recorrido y sus entradas exactas. Presupuesto documental inicial 3.500 tokens por tester y 2.600 para leader; calcular total con host, código, logs, evidencia, output y margen según [AGENTES-CONTEXTO](../AGENTES-CONTEXTO.md). No volcar logs completos si basta rango con hash del archivo completo disponible. Las restricciones críticas se mantienen literales.

Write-set de esta fase: fixtures/VMs autorizados, logs de resultados, matriz de aceptación y reportes de defectos. Modificaciones del producto pertenecen a su fase de origen y requieren preflight propio. Un tester no edita el resultado esperado para hacer pasar la solución. Cleanup se limita a recursos creados por la prueba, identificados por operationId y raíz comprobada.

## Tareas

| ID / rol | Entrada y acción | Salida y aceptación |
|---|---|---|
| P08-T01 / leader | Congelar candidato, matriz y criterios antes de pruebas. | Lista exacta de hashes, plataformas, suites Pxx-Vnn, responsables y exclusiones aprobadas. |
| P08-T02 / tester | Ejecutar recorrido nuevo offline: instalación, init de dos proyectos, tareas y consultas. | Operación esencial funciona sin runtime duplicado y sin writes cruzados. |
| P08-T03 / tester | Ejecutar proyecto legacy con drift, migración y recuperación. | Conservación y conflictos según P05; no se pierde dato desconocido. |
| P08-T04 / tester | Ejecutar tareas de varios roles con presupuesto acotado, interrupción y handoff frío. | Criterios de calidad y contexto de P03 satisfechos; aprobación y límites sobreviven reentry. |
| P08-T05 / tester | Ejecutar matriz adversarial de rutas, approvals, concurrencia, integridad y elevación. | Invariantes incumplidas bloquean release; evidencia identifica capa que aplica control. |
| P08-T06 / tester | Ejecutar upgrade, repair y uninstall manteniendo fixtures. | Producto cambia según contrato; datos/identidades conservados por hashes. |
| P08-T07 / reviewer | Encargar a otra persona o agente ejecutar runbooks sin chat. | Puede completar recorrido con documentos y artefactos; toda pregunta crítica descubre un defecto documental. |
| P08-T08 / leader + auditor | Consolidar defectos, límites y gates de release. | Decisión basada en cobertura real R01–R18, no porcentaje global que oculte fallo crítico. |

## Interfaces y reporte

Cada resultado identifica testId, candidato/hash, entorno, preparación, comando real, hora, exit code, esperado, observado, evidencia, cleanup y estado final. Los tests que invocan red/proveedores registran destino y aprobación. No incluir secretos ni comandos completos si contienen credenciales. El registro de un defecto incluye mínimo reproducer, severidad, requisito afectado, fase propietaria y prueba que deberá cambiar de `fail` a `pass`.

Los errores del runtime se comparan con el contrato versionado, incluidos códigos numéricos definidos en [ARQUITECTURA-CONTRATOS](../ARQUITECTURA-CONTRATOS.md). No basta que un proceso falle: debe fallar antes del efecto prohibido, informar causa correcta y dejar estado recuperable. Para un entorno no soportado, la aceptación exige rechazo claro, no ejecución incidentalmente exitosa.

## Recorridos de aceptación

| ID | Preparación y acción | Oracle, evidencia y cleanup |
|---|---|---|
| P08-V01 | VM limpia offline, instalar candidato y crear A/B; ejecutar tarea autorizada en A. | Sólo A cambia, producto compartido único, B intacto; logs y tres inventarios. Cleanup por lifecycle probado. |
| P08-V02 | Migrar fixture legacy conflictivo; resolver conflicto mediante aprobación específica, luego aplicar. | Primer intento bloqueado, segundo preserva datos conforme decisión; rollback probado con hashes. |
| P08-V03 | Interrumpir tarea con journal y transferir a agente sin historial. | No repite efectos committed, detecta approval/lock vigente y retoma desde evidencia. Registrar pack y resultado, sin memoria conversacional. |
| P08-V04 | Ejecutar corpus baseline/candidato según protocolo congelado P03. | Umbrales de calidad/contexto cumplidos; token real/estimado diferenciado y reintentos incluidos. |
| P08-V05 | Ejecutar batería de escapes y approvals inválidos contra CLI instalada. | Cero efectos prohibidos, errores correctos y proceso testigo no ejecutado. |
| P08-V06 | Upgrade→repair→uninstall→reinstall con ambos proyectos. | Hashes de datos estables salvo mutación de tarea aprobada; disponibilidad compatible restaurada. |
| P08-V07 | Operador externo sigue README, fases y runbooks sin acceso al chat. | Completa preparación, ejecución, verificación y recovery con decisiones documentadas. Registrar dudas y corregir antes de repetir. |
| P08-V08 | Probar plataforma/capacidad fuera de soporte declarado. | Rechazo explícito con acción posible; no se etiqueta proveedor equivalente ni enforcement inexistente. |

## Preflight y gates

Preflight delimita VMs, procesos, snapshots, cuentas, red/modelos, gastos y cleanup. Las pruebas de fallo y desinstalación requieren esa autorización concreta. Auditor detractor evalúa si evidencia corresponde a riesgos reales; reviewer independiente valida matriz y no autoriza su propia producción.

Gate de salida exige todas las pruebas críticas en `pass`, R01–R18 cubiertos, ningún bloqueo crítico abierto, resultados de contexto cuantificados, handoff frío exitoso y recuperación demostrada. Una exclusión de soporte debe aparecer tanto en documentos públicos como en runtime. No ocultar fallos tras promedio de casos aprobados.

## Recuperación y handoff

Ante fallo detener la secuencia antes de destruir evidencia, preservar logs y snapshot y abrir defecto. Repetir sólo después de cambio identificado y hash nuevo; relacionar resultados viejos/nuevos sin sobrescribir historia. Si queda lock o journal pendiente, resolverlo con el protocolo del producto antes del cleanup o registrar bloqueo.

Handoff a P09 contiene candidato aceptado/hash, matriz firmada por roles, reportes de revisión, límites, defectos residuales no críticos con disposición y runbooks demostrados. Otro operador puede reconstruir la decisión leyendo [README](../README.md), evidencia y criterios; ningún gate depende de una afirmación de este chat.
