# Project Service `central1`

`scripts/hebrinex-central.ps1` administra instancias livianas que usan un producto
central. No reemplaza ni modifica `scripts/hebrinex.ps1` (`stable0.5`) y no copia
scripts, prompts, agentes ni politicas al proyecto consumidor.

## Autoridades y ubicaciones

- Binding: `<project>/.hebrinex/binding.json`. Autoridad de identidad y compatibilidad.
- Instancia: `<project>/.hebrinex/instance/`. Estado y datos del proyecto.
- Catalogo: `<catalog>/projects/<projectId>.json`. Indice reconstruible, no autoridad.
- Producto: `InstallRoot` validado. El binding no puede indicar comandos ni rutas de codigo.

El catalogo normal por usuario es `%LOCALAPPDATA%/Hebri-AI-Harness`, pero todas las
llamadas MCP requieren `catalog_root` explicito. Tests y automatizaciones deben usar
un catalogo fixture, nunca el perfil real.

## Interfaz

```powershell
pwsh -File <InstallRoot>/scripts/hebrinex-central.ps1 help -Json
```

Consultas sin efectos:

```powershell
pwsh -File <InstallRoot>/scripts/hebrinex-central.ps1 status -InstallRoot <InstallRoot> -ProjectRoot <ProjectRoot> -CatalogRoot <CatalogRoot> -Json
pwsh -File <InstallRoot>/scripts/hebrinex-central.ps1 list -CatalogRoot <CatalogRoot> -Json
pwsh -File <InstallRoot>/scripts/hebrinex-central.ps1 doctor -InstallRoot <InstallRoot> -ProjectRoot <ProjectRoot> -CatalogRoot <CatalogRoot> -Json
```

`status`, `list`, `doctor` y el alias `validate` no crean carpetas, cache ni marcas
de acceso. `migrate` implementa la conversion y el restore legacy reversible descritos
en [legacy-migration-central1.md](legacy-migration-central1.md). `upgrade` permanece
no disponible hasta P07.

## Flujo de mutacion

El mismo flujo se aplica a `init`/`bind`, `reconcile` y `unbind`:

1. Generar un plan read-only.
2. Revisar `roots`, `write_set`, `plan_hash`, `preconditions` y `descriptor_hash`.
3. Obtener `SI` humano para ese descriptor exacto.
4. Materializar un envelope `APR2` con `approve -Apply`.
5. Ejecutar el comando con el mismo descriptor y el `ScopedApprovalId`.
6. Confirmar con `status` y `doctor`.

Ejemplo PowerShell 7, manteniendo el descriptor en memoria:

```powershell
$cli = '<InstallRoot>/scripts/hebrinex-central.ps1'
$plan = (& $cli init -InstallRoot '<InstallRoot>' -ProjectRoot '<ProjectRoot>' -CatalogRoot '<CatalogRoot>' -IncludeGitIgnore -CheckOnly -Json) | ConvertFrom-Json
$descriptorJson = $plan.details.descriptor | ConvertTo-Json -Depth 40 -Compress

# Solo despues del SI humano:
$approval = (& $cli approve -InstallRoot '<InstallRoot>' -OperationDescriptorJson $descriptorJson -HumanEvidenceId '<approval-id-visible>' -Apply -Json) | ConvertFrom-Json
& $cli init -InstallRoot '<InstallRoot>' -ProjectRoot '<ProjectRoot>' -CatalogRoot '<CatalogRoot>' -OperationDescriptorJson $descriptorJson -ScopedApprovalId $approval.details.approval_id -Apply -Json
```

En Windows PowerShell 5.1 se recomienda guardar el descriptor revisado en un archivo
temporal aprobado y usar `-OperationDescriptorPath`; evita las diferencias de quoting
de argumentos JSON largos. `Apply` vuelve a comprobar que las tres raices de CLI
coincidan con el descriptor.

## Reconcile y unbind

- Registro pendiente o catalogo ausente/corrupto: `reconcile` reconstruye una sola
  entrada desde el binding validado.
- Proyecto movido: pasar la raiz actual y las raices conocidas mediante
  `-SearchRoots <root1>,<root2>`; no se escanean discos.
- Dos raices existentes con el mismo ID: bloquea `PROJECT_ID_DUPLICATE`.
  `-CopyAsNew` asigna IDs nuevos solamente a la copia elegida y requiere aprobacion.
- `unbind` archiva el binding dentro de la instancia, marca el indice como `unbound`
  y elimina el binding activo al final. No borra datos del usuario.

## Fallos y recuperacion

Un fallo de catalogo posterior al commit local devuelve:

- `status: failed`
- `reason: REGISTRATION_PENDING`
- `exit_code: 8`
- `writes_performed: true`

El binding y la semilla pendientes se conservan. Se corrige `CatalogRoot`, se genera
un plan `reconcile` nuevo y se obtiene otro `SI`; nunca se reutiliza el descriptor
anterior. Otros conflictos de identidad, schema, precondicion o raiz salen con codigo
3 sin sobrescribir la autoridad existente. Un fallo de migracion posterior a la
publicacion sale con codigo 8 y evidencia recuperable; `upgrade` no disponible sale 4.

## MCP y hooks

La tool MCP `project_service` envuelve esta CLI. No mantiene proyecto global y exige
raices explicitas para comandos de proyecto/catalago. Con un rol asumido, `approve`
y todo `apply: true` requieren `edit_approved_write_set`.

Los hooks Claude instalados para `central_instance` ejecutan scripts absolutos del
`InstallRoot` confiable y pasan `-ProjectRoot '.'`. El producto se lee del centro y
el estado se lee de `.hebrinex/instance`; ningún script del proyecto es ejecutado.

## Validacion

```powershell
pwsh -File <InstallRoot>/scripts/validate-project-service.ps1 -Root <InstallRoot> -RunNegativeTests
pwsh -File <InstallRoot>/scripts/validate-legacy-migration.ps1 -Root <InstallRoot> -RunNegativeTests
pwsh -File <InstallRoot>/scripts/validate-mcp.ps1 -Root <InstallRoot> -RunNegativeTests -NoGit
```

El primer comando cubre P04-V01..V07; el segundo cubre P05-V01..V08. Ambos usan
fixtures marcados y limpian sólo su propia raiz temporal. `-NoGit` omite el
`gate_check` del smoke MCP cuando la sesion no tiene aprobacion Git; no omite las
pruebas de `project_service`.
