# P06 — Payload, launcher e instalación MSI

Estado: **implementación local completa; candidato unsigned, gate de instalación bloqueado**. Owner: leader de distribución. Requisitos R01, R02, R03, R11, R13, R14, R16, R17, R18. Dependencias: P01–P05 aceptadas localmente. Referencias: [arquitectura](../ARQUITECTURA-CONTRATOS.md), [decisiones](../FUENTES-DECISIONES.md), [validación](../VALIDACION.md).

## Resultado ejecutado en C-010

P06-T01..T08 produjeron un payload central allowlisted, launcher nativo x64 y
MSI WiX 5.0.2 por máquina. El payload incluye baselines `0.10.11` y `0.16.0`
derivados exclusivamente del manifest de cada tag, metadata de release y
manifest de integridad. `scripts/validate-packaging.ps1` pasa 43 checks:
payload reproducible, quoting/Unicode/metacaracteres, CWD hostil, tamper,
feature MCP ausente, decompilación e ICE del MSI.

La matriz local pasa P06-V03, V04, V05 y V07. P06-V06 es parcial: núcleo PASS y
MCP ausente falla cerrado; MCP presente no se ejecutó. P06-V01 y V02 siguen
`blocked` porque esta aprobación excluyó instalación, elevación, PATH/registro
reales, ACL/usuario estándar y VM limpia/offline. El MSI es por ello un
candidato para P07, no una release aceptada.

## Objetivo y exclusiones

Construir un MSI reproducible que instale el producto una vez por máquina y exponga un launcher estable. El payload contiene código y contratos compartidos, no datos de este repositorio fuente ni copias de proyectos. Una línea API compatible mantiene una versión activa; no se implementa selección automática entre múltiples versiones exactas. La instalación es un servicio invocable bajo demanda, sin daemon, task scheduler o servicio Windows residente por defecto.

No migrar proyectos desde el instalador, no descargar dependencias al inicializar consumidores y no ejecutar scripts de un proyecto con elevación. No certificar soporte Windows/motor por inferencia: P00 define matriz y esta fase demuestra instalación limpia dentro de ella. Upgrade, repair y uninstall completos se aceptan en P07.

## Entradas y bloqueos

Read-set: layout y resolver P01; contrato CLI/launcher P04; `HARNESS_VERSION`; `.github/workflows/ci.yml`; `mcp/package.json` y lockfile sólo para feature MCP; fuentes oficiales verificadas de toolset elegible. La ausencia de un archivo de packaging previo no autoriza empaquetar todo el árbol. El payload debe derivarse de una allowlist revisada.

Antes de usar WiX, fijar versión, procedencia, licencia/condiciones y dependencias en una decisión concreta; si faltan herramientas o aceptación de condiciones, gate bloqueado. Descargar SDKs, instalar herramientas y firmar con credenciales son efectos separados. La decisión de PowerShell mínimo se resuelve con pruebas reales: si PowerShell 5.1 falla por dependencia material, documentar la causa y aprobar provisión offline de PowerShell 7 antes de declarar soporte.

## Contexto y write-set futuro

Worker recibe esta fase, layout, contrato de launcher y fragmento de build pertinente. Presupuesto documental inicial 3.500 tokens; el total incluye host, tarea, código, logs, salida y margen según [AGENTES-CONTEXTO](../AGENTES-CONTEXTO.md). No cargar corpus completo de runtime para cambiar authoring MSI. Reviewer recibe inventario de payload y pruebas independientes.

Futuros: `packaging/msi/` con proyecto WiX y authoring declarativo; fuente del launcher en ubicación fijada por decisión P00; manifiesto de hashes generado; pipeline/build de packaging y pruebas Windows. Existentes: workflow CI y exclusiones de outputs del repositorio fuente, si aprobadas. Artefactos: MSI, logs, inventario y hashes en output de build acotado; nunca commit de certificados privados ni secretos. Instalar en VM crea archivos bajo Program Files y registros de máquina/PATH listados en preflight.

## Tareas

| ID / rol | Entrada y acción | Salida y aceptación |
|---|---|---|
| P06-T01 / leader + auditor | Fijar plataforma, motor, toolset y feature MCP con dependencia mínima. | Decisión versionada y prerequisitos offline identificados; ninguna obligación pendiente se oculta. |
| P06-T02 / implementer | Generar staging de payload desde layout allowlist. | Inventario exacto excluye memoria, approvals, evidence histórica, archivos personales, backups y secretos. |
| P06-T03 / implementer | Implementar launcher y discovery confiable. | Trata argumentos como datos, conserva exit code y streams, encuentra motor por ruta confiable y no busca ejecutables en CWD. |
| P06-T04 / implementer | Authoring MSI declarativo por máquina. | Componentes, identidad, instalación, registros y PATH controlados; sin acciones que recorren consumidores. |
| P06-T05 / implementer | Implementar build fijado y manifest de integridad. | Source/toolchain identificables, hashes de payload reproducibles; firma separada de comparación pre-firma. |
| P06-T06 / implementer | Empaquetar prerequisitos seleccionados o bloquear feature con diagnóstico. | Instalación y uso esencial offline; MCP opcional no requiere npm install por consumidor. |
| P06-T07 / reviewer | Ejecutar instalación limpia, consola nueva y usuario estándar en VM. | Launcher operativo y producto sólo lectura para usuario; datos locales separados. |
| P06-T08 / leader | Registrar artefacto candidato con pruebas y limitaciones. | Candidato pasa a P07; no se publica como release aceptado todavía. |

## Interfaces y errores

Launcher entrega contexto de instalación validado y proyecto explícito al runtime. Preserva códigos CLI versionados; errores propios se distinguen de errores del motor. Semánticas: `ENGINE_MISSING`, `ENGINE_VERSION_UNSUPPORTED`, `INSTALLATION_CORRUPT`, `RUNTIME_API_UNSUPPORTED`, `OPTIONAL_FEATURE_MISSING`. La reparación sugerida no se ejecuta automáticamente. Comandos de instalación/silent/logging se documentarán con la sintaxis real del MSI producido; este plan no es un script instalable.

La familia registrada resuelve `api_line` y versión efectiva. Binding requiere versión mínima y schemas soportados; incompatibilidad falla antes de tocar datos. El MSI puede registrar su instalación, pero nunca confía en un catálogo de usuario para decidir qué ejecutar con privilegios. El launcher no carga DLLs ni scripts desde el directorio actual por conveniencia.

## Pruebas

| ID | Preparación y acción | Oracle, evidencia y cleanup |
|---|---|---|
| P06-V01 | VM limpia sin red ni herramientas de desarrollo; instalar MSI con log. | Exit code documentado, producto presente, prerequisitos satisfechos y ninguna descarga. Guardar log, hash y snapshot; cleanup mediante uninstall probado o revertir VM. |
| P06-V02 | Abrir consola nueva como usuario estándar y ejecutar consulta CLI con proyecto fixture. | Resolución correcta y cero writes en Program Files; inventario/ACL y salida prueban funcionamiento. |
| P06-V03 | Invocar launcher con espacios, Unicode, comillas y metacaracteres en argumentos/rutas. | Argumentos llegan íntegros, script testigo de inyección no se ejecuta; exit code/streams preservados. |
| P06-V04 | Colocar ejecutable o DLL testigo en CWD y alterar producto. | Testigo no se carga; integridad alterada produce error antes de acción del proyecto. |
| P06-V05 | Dos builds aislados con mismas entradas fijadas. | Inventario y hashes de payload coinciden; diferencias de MSI por firma/timestamp se explican y aíslan, no se promete identidad binaria no probada. |
| P06-V06 | Instalar sin MCP y con feature MCP offline. | Núcleo funciona en ambos; MCP ausente da diagnóstico explícito y presente funciona con dependencias centrales. |
| P06-V07 | Inspeccionar payload generado contra categorías excluidas y archivos fuente conocidos. | Cero datos de instancia/personales/históricos; evidencia de inventario y comprobaciones dirigidas sin imprimir secretos. |

## Preflight y gates

Separar authoring, descarga/build, firma, instalación VM y publicación. Preflight de instalación describe elevación, filesystem, registry y PATH; no incluye consumidores reales. Auditor detractor revisa launcher/dependencias y rechaza servicio residente sin requisito probado. Reviewer inspecciona MSI y ejecuta pruebas, no valida únicamente archivos WiX.

Gate de salida: instalación limpia offline, usuario estándar, payload íntegro y ausencia de scripts proyecto elevados. Un test con red habilitada no demuestra offline; un build en máquina del autor no demuestra entorno limpio. Si no hay VM disponible, marcar pruebas bloqueadas y conservar candidato sin declarar aceptación.

Resultado C-010: el gate de implementación/build local pasa y el gate de
instalación permanece bloqueado conforme a la última oración anterior. La
validación ICE se ejecutó fuera del sandbox sin instalar; el primer intento
dentro del sandbox no pudo acceder al servicio Windows Installer y se conservó
en el log de artefactos.

## Fallos y handoff

Ante fallo de install, conservar log y snapshot, verificar rollback del instalador y no borrar directorios a mano para ocultar restos. Si PATH no aparece en consola existente, probar sesión nueva conforme contrato; no confundir caché de entorno con ausencia de registro. Rollback de build sólo retira outputs propios y restaura cambios acotados de authoring.

Handoff a P07: MSI exacto/hash, identidad de producto/upgrade, toolchain, inventario, ACL, prerequisitos, logs, matriz de plataformas y casos bloqueados. Otro operador debe poder construir e instalar desde [README](../README.md), decisiones y documentación de build, sin inferir ubicaciones personales ni usar este chat.
