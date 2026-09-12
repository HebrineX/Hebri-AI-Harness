# Fuentes, decisiones e inventario de cambios

Estado: implementación y evidencia local hasta P06 · Fecha de corte: 2026-09-11. Separar evidencia observada, inferencia y decisión. Las pruebas de instalación/VM siguen pendientes.

## 1. Evidencia local

| ID | Fuente y ubicación | Observación / límite |
|---|---|---|
| E01 | [PROJECT_BINDING.yaml](../PROJECT_BINDING.yaml), campos iniciales; [HARNESS_VERSION](../HARNESS_VERSION) | Raíz `source_template`, versión `0.17.1`. No existe un binding central JSON implementado por este plan. |
| E02 | [memory-registry.yaml:5](../orquestador/memory/memory-registry.yaml) | Declara `bound`, en conflicto con binding raíz. Requiere decisión/baseline; este plan no lo corrige. |
| E03 | [SHARED_MANIFEST.yaml:9,31,33,101–102](../SHARED_MANIFEST.yaml) | Declara shared, instance y mapeos; prohíbe compartir paths de instancia. No demuestra uso uniforme en todos los scripts. |
| E04 | [hebri-common.psm1:6,35–46](../scripts/lib/hebri-common.psm1) | Hay funciones existentes de mapeo y resolución que conviene reutilizar; no partir de un segundo framework. |
| E05 | [hebrinex.ps1:337,379,686,1315](../scripts/hebrinex.ps1) | Copia por manifest, escritura de binding y servicios bootstrap/update existentes. Son puntos de adaptación, no un instalador central ya disponible. |
| E06 | [validate-bootstrap.ps1:126–161](../scripts/validate-bootstrap.ps1) | Crea consumidor temporal, bootstrap Apply y limpieza; busca validador dentro de `.hebrinex/scripts`. |
| E07 | [validate-bound-update.ps1:181–224](../scripts/validate-bound-update.ps1); [validate-bound-restore.ps1:163–199](../scripts/validate-bound-restore.ps1) | Smokes reales de servicios sobre fixtures; siguen suponiendo scripts completos en consumidor. |
| E08 | [validate-harness.ps1:23–55,215–237](../scripts/validate-harness.ps1) | Remapea parte de instance y copia/borrar árbol temporal en simulación. Una ejecución no es sólo lectura. |
| E09 | [migrate-harness.ps1:3,10–11,110–120,333–334](../scripts/migrate-harness.ps1) | Default target `0.16.0`, resolver plano y fuentes admitidas limitadas a `0.8.10`, `0.9.0`, `0.10.11`. Otras fuentes se rechazan estáticamente por ese flujo. |
| E10 | [validate-migration.ps1:262–273,297–313](../scripts/validate-migration.ps1) | Verifica textos de rutas más nuevas, pero sólo invoca el migrador para las tres fuentes antiguas. No confundir con `update-bound`, servicio distinto. |
| E11 | [migrate-harness.ps1:143–164,366–403](../scripts/migrate-harness.ps1) | Backup del árbol con ruta/tamaño/mtime; requiere adiciones ya presentes y genera contratos/reportes. No es upgrade MSI transaccional. |
| E12 | [validate-bootstrap.ps1:165–171](../scripts/validate-bootstrap.ps1); [validate-bound-update.ps1:239–245](../scripts/validate-bound-update.ps1); [validate-bound-restore.ps1:214–220](../scripts/validate-bound-restore.ps1) | Algunos negativos comparan strings fabricados con regex; no ejecutan el rechazo del servicio. |
| E13 | [ci.yml:19,27–81](../.github/workflows/ci.yml) | CI observada: Ubuntu, PowerShell/Bash y npm; sin job Windows ni lifecycle MSI en ese archivo. |
| E14 | [mcp/package.json:12–16](../mcp/package.json); [validate-mcp.ps1:147–165](../scripts/validate-mcp.ps1) | Node `>=18`, SDK MCP `^1.29.0`; smoke puede omitirse si faltan Node/SDK. Declarar dependencia no prueba redistribución/offline. |
| E15 | [mcp/server.mjs:20,29–37,52–62](../mcp/server.mjs) | ROOT combina ubicación de scripts y CWD; elige `pwsh` salvo override. Requiere separar contexto del proyecto del código central. |
| E16 | [install-claude-hooks.ps1:17–22,46–50](../scripts/install-claude-hooks.ps1); [claude-reentry.ps1:4–9](../scripts/claude-reentry.ps1) | Integraciones dependen de scripts locales y PowerShell; necesitan launcher/contexto explícito y pruebas por host. |
| E17 | [init.sh:17,19–35,194–209](../init.sh) | Binding raíz, búsqueda de shells y suite de validadores. No usar como custom action MSI. |
| E18 | [regularize-state.ps1:97–104](../scripts/regularize-state.ps1); [regularize-registry.ps1:82–89](../scripts/regularize-registry.ps1); [build-instructions.ps1:1,192](../scripts/build-instructions.ps1) | Defaults de lectura; escrituras sólo con sus flags. Distinguirlos de los smokes con temporales. |
| E19 | [context-budget.yaml](../orquestador/context-budget.yaml) | Usa `file_chars_div_4`, excluye instrucciones del host/contrato visible y hoy advierte/bloquea a 2×. El objetivo de 90% no es evidencia de ahorro runtime en esta auditoría. |

Inventario estático de la auditoría: 397 archivos del manifest y 1.049.826 bytes. Kernel `first_message`: estimación 1.603 tokens por caracteres/4; una suma de 2.065 incluía el contrato visible, fuera de ese scope. No comparar ambas cuentas como regresión. P00 debe capturar comandos, inputs y hashes reproducibles antes de usarlos como baseline de aceptación.

Búsqueda de packaging: nombres de archivos visibles, incluidos ocultos y excluidos `.git`, `.codex`, dependencias, memoria completa y material personal; patrones de directorios packaging/installer/setup y extensiones MSI/WiX. Además, búsqueda de términos MSI/WiX/msiexec/repair/uninstall/offline en `scripts`, `mcp` y `.github`. No se encontraron archivos de packaging MSI/WiX en ese alcance. Esto no afirma ausencia de instaladores fuera del repositorio ni de archivos ignorados/excluidos no inspeccionados.

Evidencia P06 posterior: `packaging/` contiene layout, metadata, toolchain lock,
launcher C# y authoring WiX; `scripts/validate-packaging.ps1` pasó 43 checks. El
payload central tiene más de 400 archivos y excluye estado, approvals, locks,
evidencia, backups, dependencias Node y material personal. Los tags locales
produjeron baselines de 346 (`v0.10.11`) y 391 (`v0.16.0`) archivos. WiX ICE,
Harness PS7/PS5 y MCP/Node pasaron localmente; no hubo instalación ni red.

La búsqueda dirigida de código en scripts/MCP/init/CI no encontró paths personales fijos relevantes. No implica una auditoría universal de secretos; los campos, payload y logs requieren sus pruebas propias.

## 2. Documentación oficial consultada

Estas fuentes respaldan decisiones de plataforma, no certifican que el repositorio ya las implemente. Revisar vigencia y versión de toolchain al congelar P06.

| Fuente primaria | Uso en el plan |
|---|---|
| [Microsoft: Major Upgrades](https://learn.microsoft.com/en-us/windows/win32/msi/major-upgrades) | Modelo de upgrade MSI, identidad y compatibilidad; P07 debe comprobar secuencias y rollback. |
| [Microsoft: Installation Context](https://learn.microsoft.com/en-us/windows/win32/msi/installation-context) | Distinguir instalación por máquina/usuario, ubicaciones y privilegios. |
| [Microsoft: REINSTALLMODE](https://learn.microsoft.com/en-us/windows/win32/msi/reinstallmode) | Semántica de reparación/reinstalación; no asumir que repara datos de aplicación. |
| [Microsoft: Command-Line Options](https://learn.microsoft.com/en-us/windows/win32/msi/command-line-options) | Ejecución y logging MSI para el runbook y evidencia de VM. |
| [WiX: MSBuild](https://docs.firegiant.com/wix/tools/msbuild/) | Toolchain de build declarativa/reproducible y proyecto de packaging. |
| [WiX: MajorUpgrade](https://docs.firegiant.com/wix/schema/wxs/majorupgrade/) | Opciones de upgrade/downgrade y secuenciación que deben fijarse y probarse. |
| [WiX: Open Source Maintenance Fee](https://docs.firegiant.com/wix/osmf/) | Decisión de uso/licencia/obligaciones; pendiente revisar aplicabilidad antes de adoptar versión concreta. |
| [WiX: Signing](https://docs.firegiant.com/wix/tools/signing/) | Firma de artefactos, toolchain y conservación de evidencia de release. |

No se afirma un precio, una excepción de licencia ni disponibilidad de certificados. No guardar claves de firma, tokens o credenciales en el repositorio.

## 3. Decisiones de diseño y pendientes

Todas son propuestas del plan hasta revisión y aprobación de su implementación; no equivalen a efectos autorizados.

| ID | Decisión / motivo | Alternativa descartada o pendiente | Propietario / puerta |
|---|---|---|---|
| D01 | Tres raíces y resolver común; producto de sólo lectura para consumidores. | Cambiar sólo el destino de copia conserva supuestos erróneos. Reutilizar `hebri-common` antes de crear otro framework. | Leader + P01 |
| D02 | Instancia local preserva rutas canónicas existentes; binding JSON nuevo con schema explícito. | No mover otra vez approvals/evidencia/backups sin necesidad. YAML legacy permanece soportado por ruta de transición. | P01, P05 |
| D03 | Catálogo del usuario con `projects/<projectId>.json`, recuperable y no autoritativo. | Base de datos/servicio/global scanning no justificados. Catálogo nunca habilita efectos sobre proyectos ajenos. | P02, P04 |
| D04 | Servicio lógico bajo demanda con request/result JSON y journal local. | Daemon/servicio Windows/puerto permanente agrega operación sin necesidad probada. | P02, P04 |
| D05 | Approvals vinculados a hash/identidad/scope y separación de roles con deny por defecto. | No aceptar texto SI en artefactos ni confiar en `role` enviado por cliente. | P02, P03 |
| D06 | Contexto por tarea, evidencia incremental y handoff verificable sin chat. | Cargar todo el repo/transcript o usar caché como autoridad. No exigir embeddings/vector DB. | P03 |
| D07 | Una versión activa por línea API compatible; minimum engine + schemas probados. | Pins exactos/side-by-side automático no comprometidos. Incompatibilidad bloquea sin tocar datos; futura coexistencia mayor requiere diseño propio. | P00, P06, P07 |
| D08 | Candidato Windows x64 sin Bash; núcleo sobre Windows PowerShell 5.1 por ruta de sistema; MCP/Node ausente falla cerrado. | No redistribuir `pwsh`/Node de desarrollo ni descargar al instalar. Node/MCP offline sigue pendiente. | P06 implementado local; P08 aceptación host |
| D09 | MSI por máquina, launcher x64 .NET Framework 4.8 y componentes declarativos; no migrar datos de proyectos desde MSI. | Instalación por usuario o custom actions necesitan justificación y revisión aparte. | P06 implementado; P07 lifecycle |
| D10 | WiX 5.0.2 y Roslyn 5.3 fijados; inventario/hashes de payload reproducibles; MSI unsigned con ICE. | Bytes MSI no idénticos, firma y matriz VM pendientes; compilar no equivale a aceptar instalación. | P06 local; P07–P09 release |
| D11 | Benchmark con calidad/gates primero; umbrales candidatos congelados antes de medir. | No prometer 90% de ahorro ni equivalencia entre modelos. No ajustar criterios después de ver resultados. | P03, P08 |

Pendientes bloqueantes para implementación/release según fase: resolver discrepancia binding/memoria; fijar schema y línea API; definir Windows/arquitecturas/PowerShell soportados; decidir packaging/redistribución Node; revisar licencias WiX/runtimes; fijar versión exacta de toolchain; elegir launcher mínimo que preserve quoting; definir firma y custodia de credenciales; acordar corpus/costo/umbrales de benchmark; publicar matriz de adaptadores real. Cada pendiente debe tener decisión, evidencia y responsable, no sólo una casilla cerrada.

## 4. Inventario de archivos futuros

Este inventario es una propuesta de impacto. Las rutas nuevas no se crean en esta etapa; cada fase debe convertir su porción en un write-set exacto y revisado. Los archivos generados se cambian desde sus fuentes y builder, no a mano.

| Acción futura | Rutas o área | Razón / fase |
|---|---|---|
| Modificar | `scripts/lib/hebri-common.psm1`, `scripts/hebrinex.ps1` | Resolver común, separación de contexto e integración CLI; P01, P02, P04. |
| Modificar | `scripts/command-gateway.ps1`, `scripts/agent-runtime.ps1` y consumidores de rutas identificados | Approvals/capabilities/locks y raíz correcta; P02–P04. |
| Modificar | `mcp/server.mjs`, `mcp/agent-backends.mjs` | Contexto por invocación, compatibilidad y capabilities; P03–P04. |
| Modificar | `scripts/install-claude-hooks.ps1`, `scripts/claude-*.ps1`, `scripts/install-host-integrations.ps1` | Launcher/shims y preservación de configuración; P04. Expandir glob a paths exactos antes de aprobación. |
| Modificar | `scripts/migrate-harness.ps1`, servicios bootstrap/update/restore y sus validadores | Compatibilidad legacy, drift, backups con hashes y recuperación; P05. |
| Modificar | `SHARED_MANIFEST.yaml`, `orquestador/harness-manifest.txt` | Clasificación exhaustiva y payload; P01/P06. |
| Modificar | `orquestador/context-budget.yaml`, perfiles/entrypoints y fuentes de instruction-builder afectadas | Nueva política de carga y transición de autoridad; P03/P09. Enumerar sólo archivos necesarios. |
| Modificar | `.github/workflows/ci.yml`, `init.sh` si su compatibilidad lo requiere | CI Windows y ejecución por layouts; no usar init como instalador; P06/P08. |
| Crear, candidato | Schemas binding/request/result/task-pack/handoff/journal dentro de `orquestador/runtime/schemas/` | Contratos verificables; reutilizar/expandir schemas existentes cuando baste; P01–P03. |
| Crear, candidato | Fixtures central/offline/lifecycle dentro de `orquestador/testing/fixtures/` y validadores mínimos necesarios | Evitar una suite duplicada; cubrir conducta, no strings; P01–P08. |
| Crear, candidato | `packaging/msi/` con proyecto WiX, componentes y build/payload manifest | MSI declarativo; nombres exactos fijados por P06 tras resolver toolchain. |
| Crear en consumidor | `.hebrinex/binding.json` y sólo rutas de instancia/shims requeridas | Efectos aprobados por proyecto, nunca durante creación de este plan; P04/P05. |
| Mover mediante migración | Contenido legacy clasificado hacia su ruta canónica de instancia | Backup, plan, conflictos y rollback por proyecto; P05. Sin movimiento automático de datos ya canónicos. |
| Retirar gradualmente | Copias completas nuevas y resolvers/adaptadores duplicados obsoletos | Sólo tras equivalencia probada y transición legacy; no borrar consumidores existentes ni históricos; P05/P09. |

## 5. Revalidación

Antes de implementar, el equipo repite las lecturas pertinentes y registra revisión/hashes. Si una línea cambió, actualizar la referencia sin asumir que el hallazgo sigue vigente. Si una decisión cambia, enlazar requisitos, fases, pruebas y riesgos impactados; preservar el motivo histórico. Los resultados de tools y memoria conversacional orientan búsqueda, pero la aceptación final se apoya en artefactos y ejecución verificable.
