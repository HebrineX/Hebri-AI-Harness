# Migracion legacy reversible `central1`

P05 convierte una copia completa `<project>/.hebrinex/` en una instancia liviana
sin eliminar la copia anterior. El snapshot queda bajo
`<project>/.hebrinex-migration/<operationId>/snapshot/`, fuera del arbol reemplazado,
con inventario y SHA-256 por archivo.

## Alcance soportado

| Version legacy | Referencia ensayada | Estado P05 |
|---|---|---|
| `0.10.11` | tag Git local `v0.10.11` | soportada por la matriz local |
| `0.16.0` | tag Git local `v0.16.0` | soportada por la matriz local |
| cualquier otra | sin baseline P05 ensayado | `LEGACY_VERSION_UNSUPPORTED` |

P06 decide como distribuir baselines empaquetados. P05 no descarga versiones, no
migra consumidores reales y no convierte cercania semantica en compatibilidad.

## Clasificacion

- `intact`: producto igual al baseline; se sustituye por referencia central.
- `modified`: producto con drift; exige una decision `preserve` especifica.
- `local`: memoria, state y datos de instancia; se proyecta a `instance/`.
- `unknown`: no pertenece al baseline; se conserva en `instance/legacy-preserved/`.
- `personal`: sólo entra al snapshot; su ruta no aparece en el plan ni en el catalogo.
- `generated`: sólo entra al snapshot.
- `LEGACY_CANONICAL_CONFLICT`: dos rutas convergen al mismo destino con bytes distintos.

No existe una regla automatica de "gana legacy". El plan es read-only e inmutable:
cualquier cambio en archivos, baseline, rutas o descriptor exige generar otro plan y
obtener otro `SI`.

## Flujo de migracion

1. Crear un baseline JSON desde una referencia local confiable usando
   `New-HebriLegacyBaseline`; registrar version, referencia y SHA-256.
2. Ejecutar `migrate -CheckOnly` con `ProjectRoot`, `CatalogRoot` y `BaselinePath`
   explicitos. En un repositorio Git, `.hebrinex-migration/` debe estar excluido antes.
3. Resolver cada `CONFLICT_DECISION_REQUIRED` mediante un documento de decisiones
   cerrado. La unica accion admitida en P05 es `preserve` por ruta exacta.
4. Revisar `roots`, `write_set`, clasificaciones, espacio, hashes, precondiciones y
   `descriptor_hash`. Persistir el descriptor sólo dentro del write-set aprobado.
5. Tras el `SI` humano, ejecutar `approve -Apply` y obtener el envelope `APR2`.
6. Ejecutar `migrate -Apply` con el mismo descriptor, approval y raices.
7. Confirmar binding, instancia, snapshot, journal y catalogo. No borrar el snapshot.

Ejemplo de plan:

```powershell
$cli = '<InstallRoot>/scripts/hebrinex-central.ps1'
$plan = (& $cli migrate -InstallRoot '<InstallRoot>' -ProjectRoot '<ProjectRoot>' `
  -CatalogRoot '<CatalogRoot>' -BaselinePath '<BaselinePath>' `
  -DecisionsPath '<DecisionsPath>' -CheckOnly -Json) | ConvertFrom-Json
$plan.details.descriptor
```

Apply, después del `SI` exacto y con el descriptor revisado en `<DescriptorPath>`:

```powershell
$approval = (& $cli approve -InstallRoot '<InstallRoot>' `
  -OperationDescriptorPath '<DescriptorPath>' -HumanEvidenceId '<ApprovalIdVisible>' `
  -Apply -Json) | ConvertFrom-Json
& $cli migrate -InstallRoot '<InstallRoot>' -ProjectRoot '<ProjectRoot>' `
  -CatalogRoot '<CatalogRoot>' -OperationDescriptorPath '<DescriptorPath>' `
  -ScopedApprovalId $approval.details.approval_id -Apply -Json
```

## Restore

`migrate -Restore -CheckOnly -SnapshotPath <snapshot>` verifica primero el manifiesto,
el arbol completo y el estado post-migracion. Si la instancia central cambio, devuelve
`POST_MIGRATION_CHANGES`. `-PreservePostMigrationChanges` incorpora al plan una copia
exacta de la instancia divergente antes de publicar el snapshot legacy; no autoriza
sobrescritura silenciosa.

El restore tambien usa descriptor + `SI` + `APR2` + `-Apply`. Conserva tanto el
snapshot original como `post-migration-preserved`; eliminar cualquiera requiere una
accion y aprobacion separadas.

## Recuperacion

- Antes de publicacion, un fallo revierte la fuente sólo si puede probar hashes y
  ownership del staging.
- Después de publicacion, devuelve `MIGRATION_RECOVERY_REQUIRED`, `exit_code: 8` y
  conserva instancia, snapshot y journal para inspeccion.
- Si sólo falla el catalogo, devuelve `REGISTRATION_PENDING`; la instancia queda
  valida y pending. Se corrige mediante un plan nuevo, nunca repitiendo apply a ciegas.
- Un snapshot o backup alterado devuelve `BACKUP_INTEGRITY_FAILED` antes del restore.

## Validacion

```powershell
pwsh -File <InstallRoot>/scripts/validate-legacy-migration.ps1 -Root <InstallRoot> -RunNegativeTests
pwsh -File <InstallRoot>/scripts/validate-legacy-migration.ps1 -Root <InstallRoot> -RunNegativeTests -UseGitTags
```

La primera matriz ejecuta P05-V01..V08 en fixtures aislados. `-UseGitTags` agrega las
referencias locales `v0.10.11` y `v0.16.0`; no usa red ni convierte otros tags en
soportados.
