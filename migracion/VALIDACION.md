# Matriz de validación y evidencia

Estado: propuesta revisada; implementación pendiente. **Todos los tests de producto de este documento están `not_run`.** La inspección del código y la validación de enlaces/JSON del plan no son ejecución del Harness, construcción de MSI ni prueba runtime.

## 1. Organización y trazabilidad

Los IDs **Pxx-Vnn de los archivos de fase son los identificadores normativos de ejecución y evidencia**. `T00`–`T09` son vistas de conjunto de esas suites; Txx.n son agrupaciones de escenarios para navegar requisitos, no un segundo contrato ni una equivalencia numérica con Vnn. El registro de una ejecución usa Pxx-Vnn, requisitos y escenario efectivamente probado. Una prueba que cubre dos requisitos debe demostrar ambos, no sólo declarar sus IDs.

| Vista de suite | Casos normativos definidos en la fase | Cantidad |
|---|---|---:|
| T00 | P00-V01, P00-V02, P00-V03, P00-V04 | 4 |
| T01 | P01-V01, P01-V02, P01-V03, P01-V04, P01-V05, P01-V06 | 6 |
| T02 | P02-V01, P02-V02, P02-V03, P02-V04, P02-V05, P02-V06, P02-V07 | 7 |
| T03 | P03-V01, P03-V02, P03-V03, P03-V04, P03-V05, P03-V06 | 6 |
| T04 | P04-V01, P04-V02, P04-V03, P04-V04, P04-V05, P04-V06, P04-V07 | 7 |
| T05 | P05-V01, P05-V02, P05-V03, P05-V04, P05-V05, P05-V06, P05-V07, P05-V08 | 8 |
| T06 | P06-V01, P06-V02, P06-V03, P06-V04, P06-V05, P06-V06, P06-V07 | 7 |
| T07 | P07-V01, P07-V02, P07-V03, P07-V04, P07-V05, P07-V06, P07-V07, P07-V08 | 8 |
| T08 | P08-V01, P08-V02, P08-V03, P08-V04, P08-V05, P08-V06, P08-V07, P08-V08 | 8 |
| T09 | P09-V01, P09-V02, P09-V03, P09-V04, P09-V05, P09-V06 | 6 |

Son 67 casos propuestos, todos `not_run`. La enumeración demuestra trazabilidad documental, no cobertura runtime ni PASS. Cada caso se ejecuta con las variantes/precondiciones/criterios de su fase y los escenarios aplicables que se describen a continuación.

| Suite | Fase | Requisitos cubiertos | Estado inicial |
|---|---|---|---|
| T00 | [P00](fases/P00-baseline-y-contrato.md) | R01, R03, R08, R17, R18 | not_run |
| T01 | [P01](fases/P01-layout-y-resolucion.md) | R01, R02, R03, R16 | not_run |
| T02 | [P02](fases/P02-estado-aprobaciones-y-aislamiento.md) | R02, R03, R04, R06, R07, R16, R17 | not_run |
| T03 | [P03](fases/P03-agentes-contexto-y-proveedores.md) | R08, R09, R10, R11, R12 | not_run |
| T04 | [P04](fases/P04-cli-binding-y-registro.md) | R01, R03, R04, R06, R11, R17 | not_run |
| T05 | [P05](fases/P05-migracion-legacy.md) | R03, R05, R07, R16 | not_run |
| T06 | [P06](fases/P06-payload-launcher-y-msi.md) | R01, R13, R14, R16 | not_run |
| T07 | [P07](fases/P07-upgrade-repair-y-uninstall.md) | R03, R05, R07, R15, R16 | not_run |
| T08 | [P08](fases/P08-validacion-integral.md) | R01–R18 | not_run |
| T09 | [P09](fases/P09-release-y-operacion.md) | R13, R14, R15, R17, R18 | not_run |

## 2. Casos y resultados esperados

Cada fila hereda estado `not_run`. `PASS` requiere resultado observado y evidencia disponible. Los escenarios de error deben invocar la implementación real en un fixture; comparar strings fabricados con regex no demuestra rechazo.

| Caso | Ejecución propuesta | Resultado / evidencia mínima |
|---|---|---|
| T00.1 | Inventariar baseline, versiones, rutas y contratos del árbol autorizado. | Manifest con hashes, scope/exclusiones y discrepancias; distinguir producto, instancia y personal. |
| T00.2 | Reconstruir una operación desde registros y contrastarlos con archivos. | Identidad, rol, fase y próximo paso verificables; contradicciones registradas, sin convertir conversación en evidencia. |
| T01.1 | Resolver proyecto legacy y dos instancias centrales contra un mismo motor. | Mapeos correctos; sólo estado/shims permitidos por proyecto; inventarios y tamaños medidos. |
| T01.2 | Solicitar lecturas y escrituras por clase de path. | Lecturas permitidas; escritura de consumidor en InstallRoot denegada; hash del producto intacto. |
| T01.3 | Binding ausente, duplicado, movido, schema desconocido y motor incompatible. | Error estable y accionable; sin fallback ni rebind silencioso; cero cambios. |
| T01.4 | Espacios, Unicode, prefijos similares, traversal, junction/symlink y ruta que cambia entre plan/apply. | Contención real; casos peligrosos denegados; no se accede al destino fuera de scope. |
| T02.1 | Dos proyectos simultáneos con estados y usuarios/ACL de fixture diferentes. | A no modifica B; sin estado mutable compartido; snapshots antes/después. |
| T02.2 | Approval válido y casos vencido, revocado, falso SI, replay, comando/plan/proyecto/capability distintos. | Sólo el caso válido produce efectos exactos; consumo y rechazos trazables. |
| T02.3 | Locks concurrentes y fallas antes/durante/después de commit; reinicio del proceso. | Journal consistente; conflicto explícito; recuperación sin pérdida ni doble aplicación. |
| T02.4 | Paquete/input alterado, permisos insuficientes y logs con credenciales ficticias. | Integridad/privilegios bloquean; logs redactados; ningún secreto de fixture filtrado. |
| T02.5 | Falla parcial después de una escritura y antes del reporte final. | `actual_effects` veraces; no falso no-write/PASS; journal y next_action recuperables. |
| T03.1 | Solicitudes por cada rol y capability, incluyendo autoaprobación y reviewer que intenta editar. | Deny por defecto y separación probada; modo real/simulado veraz. |
| T03.2 | Task pack dentro/fuera de presupuesto, falta de invariantes, referencia alterada y logs con instrucciones maliciosas. | Conteo/método registrados; stop/repack o bloqueo; no obedecer instrucciones de logs. |
| T03.3 | Handoff frío a lector sin chat; cambiar hash de una referencia y retirar caché. | Reentry desde fuente; detecta drift; identifica acción/precondiciones/pruebas sin pedir datos disponibles. |
| T03.4 | Cada adaptador y un host sin hooks/tools de enforcement. | Matriz real de capabilities; `unsupported/not_tested` explícitos; efectos críticos bloqueados. |
| T03.5 | Selección de modelo/proveedor dentro y fuera de presupuesto/capabilities/costo autorizado. | Decisión trazable; no escalada de costo implícita; salida no equivale a prueba de calidad equivalente. |
| T04.1 | Bind central nuevo, segundo bind idempotente y CLI desde CWD ajeno. | Binding/instancia correctos; motor no copiado; operación sin depender de ruta de scripts local. |
| T04.2 | IDs duplicados, proyecto movido y JSON/YAML activos contradictorios. | Conflicto/rebind explícito; identidad no sobreescrita; diagnóstico consistente CLI/MCP. |
| T04.3 | Catálogo ausente/corrupto/parcial, entrada de otro usuario y fallo al registrar tras bind. | Reconstrucción desde proyectos autorizados; instancia válida conservada; recovery/reconcile sin elevar autoridad del índice. |
| T04.4 | Comparar plan/apply con cambios de precondiciones y verificar contrato JSON/CLI estable. | Hash/preflight coinciden o bloquean; exit codes compatibles según versión; efectos completos, incluido catálogo. |
| T04.5 | Shims e integraciones necesarias; invocación con espacios y actualización del launcher. | Rutas correctas, argumentos preservados, personalizaciones no pisadas y limits de enforcement visibles. |
| T05.1 | Migrar cada versión/layout legacy que se declare soportado, con dry run previo. | CheckOnly no cambia árbol; apply conserva contexto/memoria/evidencia y no agrega datos personales al producto. |
| T05.2 | Drift local, archivos desconocidos, bindings parciales y rutas antiguas compartidas/instancia. | Plan describe conflictos y preservación; no overwrite silencioso; schema final válido. |
| T05.3 | Backup corrupto, traversal en BackupId/rutas, symlink y destino fuera de scope. | Rechazo real antes de restaurar; hashes y contención verificados. |
| T05.4 | Cortar migración en cada punto durable; recuperar y restaurar con cambio externo posterior. | Recuperación idempotente; cambios posteriores no pisados; backup/restore y journal verificables. |
| T06.1 | Construir payload dos veces con toolchain/inputs fijados e instalar MSI en Windows limpio. | Inventario/contenido sin firma reproducibles; componentes y launcher correctos; logs MSI. |
| T06.2 | Instalar/operar VM sin red con y sin runtimes/features opcionales. | Base funciona con prerequisitos declarados; feature ausente falla temprano; ninguna descarga oculta. |
| T06.3 | Lanzar desde nueva consola/CWD diferente, rutas con espacios, usuario estándar y cuenta de instalación. | PATH/launcher resuelven instalación confiable; exit code y quoting correctos. |
| T06.4 | Payload alterado, firma/hash inválido, ACL producto modificada y privilegio insuficiente. | Rechazo/diagnóstico previsto; procesos del consumidor no escriben producto. |
| T07.1 | Upgrade compatible y caso schema/API incompatible con proyectos de distintos usuarios. | Producto actualiza según contrato; no descubre/ejecuta proyectos ajenos; incompatible falla cerrado sin tocar datos. |
| T07.2 | Borrar/corromper componente del producto y ejecutar repair. | Producto recuperado; instancias, catálogo e integraciones personalizadas preservados. |
| T07.3 | Uninstall con procesos abiertos y varias instancias existentes. | Sólo recursos del producto retirados; datos conservados; reinicio/lock/exit code documentados. |
| T07.4 | Inyectar fallas de upgrade y probar rollback; por separado restaurar instancia autorizada. | Estados MSI y datos no confundidos; versión/datos compatibles o bloqueo explícito; evidencia de recuperación. |
| T08.1 | Ejecutar matriz de regresión por versiones/plataformas declaradas. | R01–R18 trazables, todos gates críticos PASS; skips/bloqueos visibles; no extrapolar ambientes. |
| T08.2 | Benchmark de contexto/modelos con baseline y corpus fijados. | Calidad/gates preservados; tokens, costo, reintentos y latencia medidos con incertidumbre; ahorro sólo si cumple criterio acordado. |
| T08.3 | Equipo distinto ejecuta instalación, vinculación, operación, incidente y recuperación usando sólo documentación. | Handoff frío PASS y runbook suficiente; preguntas/datos faltantes corregidos y reprobados. |
| T09.1 | Ensayar checklist/runbook de release y operación desde artefactos aprobados. | Hashes, firma cuando aplique, fuentes, evidencia, riesgos, rollback y aprobación de publicación correlacionados. |
| T09.2 | Verificar inventario de licencias/runtimes y procedimiento offline desde artefactos entregados. | Obligaciones/avisos presentes, versiones fijadas, componentes redistribuibles y límites conocidos. |

## 3. Matriz de ambientes

P00/P06 deben fijar versiones exactas antes de ejecutar; “Windows actual” no es una especificación de soporte.

| Ambiente | Propósito | Condición de aceptación |
|---|---|---|
| CI Ubuntu + PowerShell | Mantener los contratos/smokes existentes aplicables. | PASS sólo para ese ambiente; no certifica MSI. |
| CI Windows | Build de payload/MSI, schemas y tests Windows automatizables. | Toolchain fijada y logs; un runner hospedado con runtimes preinstalados no equivale a Windows limpio. |
| VM Windows limpia | Install/launcher/ACL/repair/uninstall. | Snapshot identificado, edición/build/arquitectura/usuario/runtimes inventariados. |
| VM Windows offline | Ausencia de dependencias/descargas ocultas. | Red deshabilitada o egress bloqueado verificablemente; paquetes/prerrequisitos disponibles según contrato. |
| VM con versión anterior | Upgrade, incompatibilidad y rollback. | Artefactos previos identificados y estados de proyectos con hashes. |
| Host/adaptador por proveedor | Capabilities, hooks, handoff y evaluación. | Versión/settings registrados; límites de enforcement explícitos. |

No declarar soporte ARM64, PowerShell 5.1, WSL o un host adicional por analogía. Si se los incluye, agregar casos y ambiente específico. Pruebas MSI con elevación pertenecen a VM desechable/snapshot y requieren aprobación; no deben afectar proyectos reales del operador.

## 4. Evidencia y estados

Ubicación futura preferida: `instance/sdd/progress/evidence/<run_id>/`, con referencia desde estado/gates y manifest de hashes. No crear esa evidencia de producto en esta etapa documental. Cada resultado contiene:

- Test central y local, requisitos/fase, autor/reviewer, fecha UTC, revisión del código y del fixture.
- Ambiente y versiones; comando/acción exacta; approval del efecto; precondiciones.
- Esperado/observado, exit code, stdout/stderr redactados, tiempos y archivos antes/después.
- Hashes de inputs, outputs, backups y logs; journal/operation ID cuando aplique.
- Estado `not_run`, `running`, `pass`, `fail`, `blocked`, `skipped` o `not_applicable`, con motivo y próxima acción. `not_applicable` requiere justificación revisada.

Los ejemplos del plan, capturas sueltas y cadenas “validation OK” sin comando/ambiente no alcanzan. Una prueba no ejecutada no se marca `pass` para cerrar una fase. Conservar intentos fallidos y reintentos; no sobrescribir la primera falla con el último éxito.

## 5. Benchmark y criterios candidatos

P03 es propietario de la decisión de performance. Antes del benchmark, congelar corpus, escenarios, cantidad de repeticiones, versiones/modelos/settings, límites de costo y criterios de aceptación. No ajustar umbrales después de ver resultados para obtener PASS.

Candidatos a aceptar o reemplazar explícitamente antes de medir:

- Cero violaciones críticas y 100% de gates de seguridad/autoridad; ninguna regresión de criterios funcionales por caso.
- Al menos 10 repeticiones por caso/configuración como mínimo operativo inicial; registrar tamaño de muestra, dispersión y fallos. Diez corridas no prueban equivalencia estadística entre proveedores no deterministas.
- Objetivo de reducción de mediana de input de al menos 30%, con p95 de input no mayor al baseline y reintentos agregados no mayores al baseline +10%. Son umbrales propuestos, no pedidos del usuario ni logros observados.
- Medir además tokens de salida, latencia p95, costo total y costo por tarea aceptada. Si baseline tiene cero reintentos, no dividir por cero: fijar previamente el criterio absoluto.

Un ahorro que pierde corrección o gates falla. Si no se logra ahorro, reportar ese resultado y revisar diseño; no ocultar mayor output, reintentos o latencia. El ahorro de disco del payload y el ahorro de contexto son métricas distintas.

## 6. Uso de validadores actuales

La suite actual ofrece validación estática y smokes útiles, pero debe reclasificarse por efectos antes de ejecutarla:

| Script actual | Efecto/limitación observado por lectura |
|---|---|
| `scripts/validate-bootstrap.ps1` | Crea consumidor temporal, ejecuta bootstrap Apply y elimina el fixture. |
| `scripts/validate-bound-update.ps1`, `validate-bound-restore.ps1`, `validate-bound-backups.ps1` | Preparan/modifican instancias temporales y prueban servicios. |
| `scripts/validate-harness.ps1` | Tiene simulaciones con copia/borrado temporal e invoca validadores anidados. |
| `scripts/validate-mcp.ps1` | Puede ejecutar Node smoke; puede omitirlo si faltan Node/SDK. Un skip no prueba MCP. |
| `init.sh` | Llama múltiples validadores con efectos de fixtures; no es diagnóstico puramente de lectura. |
| `regularize-state.ps1`, `regularize-registry.ps1`, `build-instructions.ps1` | Defaults de lectura; escriben con flags de aplicación/generación. No atribuirles escritura por defecto. |

Las referencias precisas están en [FUENTES-DECISIONES.md](FUENTES-DECISIONES.md). El preflight de pruebas debe declarar el árbol temporal y su eliminación, límites de rutas, procesos, red y privilegios. Para borrado recursivo Windows, verificar ruta absoluta dentro del fixture y usar una sola shell con paths literales. No ejecutar un validador sólo por su nombre sin revisar sus efectos.
