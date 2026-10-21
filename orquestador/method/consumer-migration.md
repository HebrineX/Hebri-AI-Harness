# Migracion acotada de un consumidor

El entrypoint `scripts/migrate-consumer.ps1` ejecuta el motor existente
`hebrinex.ps1 update-bound`. No instala otro motor ni migra multiples proyectos.
Solo admite Windows y discos locales fijos, sin reparse points en ancestros ni
descendientes del destino. Requiere una distribucion fuente confiable 0.17.3
`source_template`; el consumidor debe estar entre 0.16.0 y 0.17.3 inclusive.
No admite layout central-runtime, downgrade, identidad ambigua ni locks activos.
El inventario del destino tiene limites duros: profundidad 32, 10000 entradas y
128 MiB. Al superarlos se detiene; no recorta silenciosamente el snapshot.
Omite .git/.codex en la raiz del harness y rechaza esas carpetas anidadas en
estado que el motor podria recorrer. Un lock vigente marcado active bloquea
incluso si expiro: resolverlo por la autoridad y regenerar el plan. No interpreta
locks historicos dentro de backups como locks actuales.
Se seleccionan registros `*.lock.md` y su campo `status`, como en el inventario
existente; el ejemplo activo de `locks/_README.md` no es un registro de lock.
Un nombre que contenga template no exime a un registro real de este control.
Cada invocacion mantiene una cache de ancestros existentes ya verificados como
directorios sin reparse. Nunca cachea archivos, rutas ausentes ni la hoja que se
esta comprobando; la cache se vacia despues del motor. CheckOnly y Apply tienen
caches independientes. Esto requiere la ausencia de escritores concurrentes
indicada abajo; no protege contra sustituciones adversariales durante el comando.

`Root` es la distribucion que ejecuta el codigo. `ProjectRoot` es el proyecto
consumidor, cuya `.hebrinex` sigue siendo la autoridad. El binding canónico
`instance/PROJECT_BINDING.yaml` tiene prioridad. Un binding raiz `source_template`
es normal; uno `bound` atrasado es valido solamente si identidad y project_root
coinciden. La version canonica debe coincidir con `HARNESS_VERSION`; el pin
legacy no se usa como version autoritativa.

## Plan y autorizacion

Declarar contrato, leader, alcance, riesgo y pase detractor antes de escribir.
No ejecutar sobre consumidores reales sin el SI para ese proyecto y ese plan.
Ejemplo PowerShell, reemplazando las dos rutas por rutas locales verificadas:

```powershell
$source = 'C:\distribuciones\Hebri-AI-Harness-0.17.3'
$project = 'C:\proyectos\consumidor'
$entry = Join-Path $source 'scripts/migrate-consumer.ps1'
$cli = Join-Path $source 'scripts/hebrinex.ps1'
$plan = & $entry -Root $source -ProjectRoot $project -CheckOnly | ConvertFrom-Json
$plan | ConvertTo-Json -Depth 12
```

CheckOnly no escribe. El JSON enumera adds, overwrites, preserved, conflictos,
efectos adicionales del motor y snapshot. Todo contenido distinto que seria
sobrescrito se considera conflicto: no se presume que una diferencia pertenece
a una version anterior. Revisar cada archivo antes de aceptar la lista exacta.
No aceptar automaticamente una lista obtenida de una herramienta.
Tambien enumera `imports` (source, destination y sha256) y
`pending_directories`, calculados desde el mapa de migracion del propio motor.
Los destinos canonicos existentes se preservan; los tipos incompatibles bloquean
CheckOnly. `approval_imports` enumera por separado las aprobaciones legacy que
se copiaran a destinos canonicos faltantes. Sus almacenes e imports quedan fuera
del snapshot para permitir emitir el permiso entre CheckOnly y Apply. Apply
recalcula esa lista y verifica sus hashes; nunca sobrescribe approvals canonicos.
`metadata_updates` describe exclusivamente la actualizacion del campo
harness_version del session-pin efectivo: source, destination canonico,
before_sha256 y after_sha256. Reutiliza el converter del motor y UTF-8 estricto,
conservando BOM, finales de linea y todos los demas caracteres. Un pin ausente,
ambiguo o contradictorio bloquea CheckOnly. El snapshot incluye esta actualizacion
y Apply verifica el hash del pin canonico resultante despues del motor.

```powershell
# Solo despues de revisar cada overwrite y obtener el SI correspondiente:
$accepted = ConvertTo-Json -InputObject @($plan.overwrites) -Compress
$plan = & $entry -Root $source -ProjectRoot $project -CheckOnly `
  -AcceptOverwritePathsJson $accepted | ConvertFrom-Json
# Presentar el preflight y command_text exacto; esperar SI antes de approve.
& $cli approve -Root (Join-Path $project '.hebrinex') -Apply `
  -CommandText $plan.command_text -Purpose 'Migracion revisada de un consumidor'
# Usar el APR devuelto, no el approval de otro proyecto o de otra accion:
$approvalId = 'APR-ID-DEVUELTO'
& $entry -Root $source -ProjectRoot $project -Apply -Snapshot $plan.snapshot `
  -AcceptOverwritePathsJson $accepted -ApprovalId $approvalId
```

`command_text` vincula entrypoint, ambas raices, modo Apply, snapshot y texto
exacto de AcceptOverwritePathsJson. ApprovalId es la credencial que se obtiene
despues de aprobar ese comando y no forma parte del texto aprobado. No ejecutar
command_text con Invoke-Expression; invocar los parametros como arriba.
El snapshot incluye motor, modulo, entrypoint, manifest, contenido distribuido,
estado del destino y `.gitignore` del proyecto. Excluye los almacenes legacy y
canonico de approvals para permitir emitir el permiso entre plan y Apply.
Cambiar fuente o destino requiere nuevo plan y nueva aprobacion.

La exclusion gitignore se valida con la misma regla que usa el motor: una linea
literal `.hebrinex/` (tambien admite slash inicial o sin slash final), sin espacios
iniciales. Una negacion posterior a la ultima exclusion explicita bloquea de
forma conservadora; revisar las reglas en vez de sobrescribir su intencion.
Si hay repositorio Git, se consulta el indice con `ls-files` sin locks opcionales
ni fsmonitor. Un `.hebrinex` ya rastreado bloquea: desindexarlo es otra accion Git,
no parte del migrador. Overrides de entorno Git requieren revision separada.
Las aprobaciones canonicas existentes se capturan al comenzar Apply y se
verifican byte a byte mediante SHA256, aunque no formen parte del snapshot estable.

El motor preserva estado y configuracion local segun su politica; lo canonico
existente gana, y legacy solo completa destinos faltantes. Puede escribir backup,
reporte, contrato post-migracion, binding canonico y `.gitignore` del proyecto.
No se lee infoHebri; rutas reconocibles de credenciales se rechazan. No es un
detector universal de secretos: el agente debe verificar el alcance local.
La aceptacion de overwrites nunca desactiva controles de ruta o tipo.

Noop exige ausencia de imports, approval_imports, metadata_updates y directorios pendientes,
igualdad del contenido distribuido, version, autoridad canonica y
exclusion `.hebrinex` en gitignore. No basta el numero de version. Apply verifica
los hashes distribuidos, imports, contenido canonico preservado, identidad,
project_root, version, pin y exclusion gitignore tras ejecutar el motor. Los
archivos administrativos que el motor actualiza (binding, pin y contrato
post-migracion) no se comparan como contenido canonico inmutable. Si falla despues de invocarlo,
reporta `failed_writes_possible`: puede haber escrituras parciales. No hay
garantia de backup completo. Los errores identifican la etapa; los fallos tras
invocar el motor incluyen `error_stage` en el JSON. No hay
rollback automatico ni exclusion mutua contra escritores externos concurrentes;
mantener el proyecto sin otros escritores durante CheckOnly/Apply.

## Recuperacion explicita

Conservar el backup id y reporte cuando esten disponibles en engine_output.
El motor puede fallar antes de devolver el ID; engine_output no esta garantizado
en un fallo y el backup puede estar incompleto. Tras reconstruir estado y
evidencia, enumerar los backups del destino exacto con el comando existente:

```powershell
& $cli list-bound-backups -Root $source -ProjectRoot $project -CheckOnly
```

Revisar el directorio canonico del consumidor
`<ProjectRoot>/.hebrinex/instance/migration/backups`, correlacionar el backup con
la operacion fallida y verificar manifest e integridad. No seleccionar
automaticamente el mas reciente ni asumir que un directorio existente es un
backup completo. Con el ID exacto identificado, inspeccionar ese backup:

```powershell
$backupId = 'migration-bound-update-ID-EXACTO'
& $cli restore-bound -Root $source -ProjectRoot $project -BackupId $backupId -CheckOnly
# Preflight separado, revisar manifest e integridad del backup, esperar SI:
& $cli restore-bound -Root $source -ProjectRoot $project -BackupId $backupId -Apply
```

Esta ruta de recuperacion es el comando existente del motor: no ofrece el
snapshot ni el gate de approval del nuevo wrapper. No usar su Apply desatendido;
requiere preflight y SI separado del operador. Restore es un overlay de los
archivos del backup: NO elimina archivos agregados ni restaura `.gitignore` del
proyecto. Tampoco promete restauracion completa de un layout legacy. Revisar
binding, estado, archivos restantes y validadores antes de continuar.

## Validacion y cierre

Ejecutar `scripts/validate-consumer-migration.ps1 -Root <fixture-limpio>`
en PowerShell 7 y Windows PowerShell 5.1. El validador copia solo la distribucion
a un directorio temporal, crea consumidores mediante bootstrap y prueba Apply
legacy/canonico, approvals, snapshots obsoletos, preservacion, idempotencia y
limites reales de recovery. No usa consumidores reales. Otros hosts emiten SKIP.
La fixture fuente debe incluir manifest y metadata integrados de 0.17.3.
Son fixtures sinteticas representativas creadas desde esa distribucion: legacy
con version 0.16.0, canonica con 0.17.2 y rerun en 0.17.3.
Los session-pin existentes se ajustan a la version anterior de cada fixture.
Tambien se ajustan shared manifest, presupuesto, registro de instrucciones y
contrato post-migracion para no simular una version vieja con metadata nueva.
Se agregan BOM, CRLF y un comentario personalizado; despues de Apply se exige
igualdad byte a byte salvo la version, backup del pin original y noop sin otra
actualizacion de metadata. Se rechazan campos de version ausentes, duplicados o
contradictorios.
Estas pruebas no certifican por si solas la coherencia de todo el contrato
operativo preservado; revisar sus pins y referencias antes de cerrar.
Tambien se comprueba el rechazo de 0.17.4 y de HARNESS_VERSION inconsistente
con el binding efectivo.
Esto no acredita pruebas sobre distribuciones historicas reales ni sobre todas
las versiones intermedias del rango admitido.

Recovery tiene expectativas separadas: el layout canonico coherente debe
restaurar y validar; el backup legacy no contiene los archivos canonicos creados
por la migracion. Su overlay conserva esas adiciones y el test exige el rechazo
especifico del contrato de version resultante, ademas de recuperar el pin y
HARNESS_VERSION respaldados. Ese rechazo no significa recuperacion operativa
exitosa ni autoriza a continuar usando el consumidor inconsistente.

El implementer entrega archivos y limitaciones al reviewer; no se autoaprueba.
El leader conserva responsabilidad sobre state, registry, gates, evidencia,
verification matrix, agent closure y locks antes de declarar cierre.
