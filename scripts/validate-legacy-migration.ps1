param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$RunNegativeTests,
  [switch]$UseGitTags
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath $Root).Path
Import-Module (Join-Path $PSScriptRoot 'lib/legacy-migration-service.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'lib/hebri-common.psm1') -Force -DisableNameChecking

$script:Checks = 0
$script:Failures = New-Object System.Collections.Generic.List[string]
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('hebrinex-p05-' + [guid]::NewGuid().ToString('N'))
$fixtureSource = Join-Path $Root 'orquestador/testing/fixtures/legacy-migration/baseline-source'
$decisionFixture = Join-Path $Root 'orquestador/testing/fixtures/legacy-migration/decisions-preserve.json'

function Assert-P05 {
  param([bool]$Condition, [string]$Message)
  $script:Checks++
  if (-not $Condition) { [void]$script:Failures.Add($Message) }
}

function Write-TestText {
  param([string]$Path, [string]$Text)
  [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
  [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function Write-TestJson {
  param([string]$Path, [object]$Value)
  Write-HebriAtomicJsonDocument -Path $Path -Value $Value
}

function Copy-TestTree {
  param([string]$Source, [string]$Destination)
  [void][IO.Directory]::CreateDirectory($Destination)
  $sourceFull = [IO.Path]::GetFullPath($Source).TrimEnd('\','/')
  foreach ($file in @(Get-ChildItem -LiteralPath $sourceFull -Recurse -Force -File)) {
    $relative = $file.FullName.Substring($sourceFull.Length).TrimStart('\','/')
    $target = Join-Path $Destination $relative
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $target))
    [IO.File]::Copy($file.FullName, $target, $false)
  }
}

function New-TestConsumer {
  param([string]$Name, [string]$BaselinePath)
  $project = Join-Path $tempRoot $Name
  $legacy = Join-Path $project '.hebrinex'
  [void][IO.Directory]::CreateDirectory($project)
  Copy-TestTree -Source $fixtureSource -Destination $legacy
  Write-TestText (Join-Path $project '.hebrinex-migration-fixture') "P05 fixture only`n"
  $legacyId = 'LEGACY-' + $Name
  $binding = @"
schema: hebrinex.project_binding
version: "0.1"
harness_version: "0.16.0"
binding_mode: bound
harness_instance_id: "$legacyId"
project_name: "$Name"
project_root: "$($project -replace '\\','/')"
repo_remote: ""
source_repo: "fixture"
created_at: "2026-09-10T00:00:00Z"
bound_at: "2026-09-10T00:00:00Z"
"@
  Write-TestText (Join-Path $legacy 'PROJECT_BINDING.yaml') $binding
  return [pscustomobject]@{ Project = $project; Legacy = $legacy; Catalog = Join-Path $tempRoot ($Name + '-catalog'); Baseline = $BaselinePath; LegacyId = $legacyId }
}

function Approve-And-Apply {
  param([object]$PlanResult, [string]$Evidence = 'P05-FIXTURE-SI')
  $descriptor = $PlanResult.details.descriptor
  $approval = New-HebriScopedApprovalEnvelope -Descriptor $descriptor -HumanEvidenceId $Evidence -HumanDecision approved -ApprovedText 'SI' -TtlMinutes 60
  return Invoke-HebriLegacyMigrationOperation -Descriptor $descriptor -ApprovalId $approval.Id
}

function New-TestDescriptorFromPlan {
  param([object]$Original, [object]$Plan)
  $context = [pscustomobject]@{
    install_root = [string]$Original.roots.install_root
    project_root = [string]$Original.roots.project_root
    instance_root = [string]$Original.roots.instance_root
    catalog_root = [string]$Original.roots.catalog_root
    project_id = [string]$Original.project_id
  }
  return New-HebriOperationDescriptor -Context $context -Operation ([string]$Original.operation) -WriteSet @($Original.write_set) -CodeVersion ([string]$Original.code_version) -Plan $Plan -OperationId ([string]$Original.operation_id)
}

function Assert-CentralApplied {
  param([object]$Fixture, [object]$Result)
  $applied = ($Result.status -eq 'applied' -and $Result.reason -eq 'MIGRATION_APPLIED' -and $Result.writes_performed)
  Assert-P05 $applied "$($Fixture.Project): migration did not apply (status=$($Result.status), reason=$($Result.reason), error=$($Result.details.error))"
  if (-not $applied) { return }
  Assert-P05 (Test-Path -LiteralPath (Join-Path $Fixture.Legacy 'binding.json') -PathType Leaf) "$($Fixture.Project): central binding missing"
  Assert-P05 (-not (Test-Path -LiteralPath (Join-Path $Fixture.Legacy 'shared.txt'))) "$($Fixture.Project): intact product was copied into lightweight instance"
  Assert-P05 (Test-Path -LiteralPath (Join-Path $Fixture.Legacy 'instance/memory/local/note.txt') -PathType Leaf) "$($Fixture.Project): instance memory was not preserved"
  Assert-P05 (Test-Path -LiteralPath $Result.details.snapshot_path -PathType Container) "$($Fixture.Project): snapshot missing"
  Assert-P05 (Test-Path -LiteralPath $Result.details.snapshot_manifest_path -PathType Leaf) "$($Fixture.Project): snapshot manifest missing"
  $binding = Read-HebriJsonDocument (Join-Path $Fixture.Legacy 'binding.json')
  $catalogPath = Join-Path (Join-Path $Fixture.Catalog 'projects') ($binding.project_id + '.json')
  Assert-P05 (Test-Path -LiteralPath $catalogPath -PathType Leaf) "$($Fixture.Project): catalog entry missing"
  if (Test-Path -LiteralPath $catalogPath -PathType Leaf) {
    $catalog = Read-HebriJsonDocument $catalogPath
    Assert-P05 ($catalog.state -eq 'active' -and $catalog.project_root -eq [IO.Path]::GetFullPath($Fixture.Project).TrimEnd('\','/')) "$($Fixture.Project): catalog entry is not active/canonical"
  }
}

function Invoke-TagMatrix {
  param([string]$Tag)
  $safe = ($Root -replace '\\','/')
  $tagName = $Tag.TrimStart('v').Replace('.','-')
  $zip = Join-Path $tempRoot ($tagName + '.zip')
  $source = Join-Path $tempRoot ($tagName + '-source')
  & git -c "safe.directory=$safe" archive --format=zip -o $zip $Tag
  if ($LASTEXITCODE -ne 0) { throw "git archive failed for $Tag" }
  Expand-Archive -LiteralPath $zip -DestinationPath $source
  $version = [IO.File]::ReadAllText((Join-Path $source 'HARNESS_VERSION')).Trim()
  $baselinePath = Join-Path $tempRoot ($tagName + '-baseline.json')
  $baseline = New-HebriLegacyBaseline -SourceRoot $source -SourceVersion $version -SourceRef $Tag -OutputPath $baselinePath
  Assert-P05 (@($baseline.files).Count -gt 300) "$Tag baseline did not cover the tracked release tree"
  Assert-P05 ($baseline.inventory_scope -eq 'release_manifest' -and $baseline.source_manifest_sha256 -match '^[a-f0-9]{64}$') "$Tag baseline did not use its release manifest as authority"
  Assert-P05 (@($baseline.files | Where-Object { $_.path -eq 'infoHebriHarness.md' }).Count -eq 0) "$Tag baseline leaked undeclared personal metadata"
  $project = Join-Path $tempRoot ($tagName + '-project')
  [void][IO.Directory]::CreateDirectory($project)
  [IO.Directory]::Move($source, (Join-Path $project '.hebrinex'))
  Write-TestText (Join-Path $project '.hebrinex-migration-fixture') "P05 fixture only`n"
  $bindingPath = Join-Path $project '.hebrinex/PROJECT_BINDING.yaml'
  $bindingText = [IO.File]::ReadAllText($bindingPath)
  $bindingText = [regex]::Replace($bindingText, '(?m)^binding_mode:.*$', 'binding_mode: bound')
  $bindingText = [regex]::Replace($bindingText, '(?m)^harness_instance_id:.*$', ('harness_instance_id: "LEGACY-' + $tagName + '"'))
  $bindingText = [regex]::Replace($bindingText, '(?m)^project_root:.*$', ('project_root: "' + ($project -replace '\\','/') + '"'))
  Write-TestText $bindingPath $bindingText
  $catalog = Join-Path $tempRoot ($tagName + '-catalog')
  $plan = New-HebriLegacyMigrationPlan -InstallRoot $Root -ProjectRoot $project -CatalogRoot $catalog -BaselinePath $baselinePath
  Assert-P05 ($plan.status -eq 'planned') "$Tag trusted baseline did not produce a migration plan: $($plan.reason)"
  if ($plan.status -eq 'planned') {
    $result = Approve-And-Apply $plan ('P05-' + $Tag + '-SI')
    Assert-P05 ($result.status -eq 'applied') "$Tag trusted baseline migration failed: $($result.reason)"
  }
  return [pscustomobject]@{ tag = $Tag; version = $version; files = @($baseline.files).Count; tree_sha256 = $baseline.tree_sha256; status = $plan.status; reason = $plan.reason }
}

try {
  [void][IO.Directory]::CreateDirectory($tempRoot)
  foreach ($required in @($fixtureSource,$decisionFixture)) { Assert-P05 (Test-Path -LiteralPath $required) "fixture missing: $required" }
  $baselinePath = Join-Path $tempRoot 'baseline-0.16.0.json'
  $baseline = New-HebriLegacyBaseline -SourceRoot $fixtureSource -SourceVersion '0.16.0' -SourceRef 'fixture:v0.16.0' -OutputPath $baselinePath
  Assert-P05 ((Test-HebriLegacyBaseline $baseline).Valid) 'P05-T01 generated baseline was rejected'
  Assert-P05 (@($baseline.files).Count -eq 5) 'P05-T01 baseline file inventory is incomplete'
  Assert-P05 ($baseline.inventory_scope -eq 'all_files' -and $null -eq $baseline.source_manifest_sha256) 'P05-T01 manifest-free fixture scope is incorrect'

  # P05-V01: pure plan and pristine migration.
  $v1 = New-TestConsumer 'v01-pristine' $baselinePath
  $privatePath1 = Join-Path $v1.Legacy '.env'
  Write-TestText $privatePath1 "P05_PRIVATE_FIXTURE=do-not-print`n"
  $privateHash1 = Get-HebriFileSha256 $privatePath1
  $planInventoryBefore = @(Get-ChildItem -LiteralPath $v1.Project -Force).Count
  $plan1 = New-HebriLegacyMigrationPlan -InstallRoot $Root -ProjectRoot $v1.Project -CatalogRoot $v1.Catalog -BaselinePath $baselinePath
  $planInventoryAfter = @(Get-ChildItem -LiteralPath $v1.Project -Force).Count
  Assert-P05 ($plan1.status -eq 'planned' -and -not $plan1.writes_performed) 'P05-V01 pristine plan was not pure/planned'
  Assert-P05 ($planInventoryBefore -eq $planInventoryAfter -and -not (Test-Path -LiteralPath (Join-Path $v1.Project '.hebrinex-migration'))) 'P05-V01 planning created filesystem state'
  Assert-P05 (($plan1 | ConvertTo-Json -Depth 40) -notmatch '[.]env|do-not-print') 'P05-V01 personal path or content leaked into plan output'
  if ($plan1.status -eq 'planned') {
    $result1 = Approve-And-Apply $plan1
    Assert-CentralApplied $v1 $result1
    if ($result1.status -eq 'applied') {
      Assert-P05 (-not (Test-Path -LiteralPath (Join-Path $v1.Legacy '.env'))) 'P05-V01 personal file was copied into the lightweight instance'
      Assert-P05 ((Get-HebriFileSha256 (Join-Path $result1.details.snapshot_path '.env')) -eq $privateHash1) 'P05-V01 personal file was not preserved byte-for-byte in the snapshot'
    }
  }

  # P05-V02: modified product requires a recorded preserve decision; unknown data survives.
  $v2 = New-TestConsumer 'v02-drift' $baselinePath
  Write-TestText (Join-Path $v2.Legacy 'shared.txt') "custom shared`n"
  Write-TestText (Join-Path $v2.Legacy 'custom/config.txt') "local unknown`n"
  $blocked2 = New-HebriLegacyMigrationPlan -InstallRoot $Root -ProjectRoot $v2.Project -CatalogRoot $v2.Catalog -BaselinePath $baselinePath
  Assert-P05 ($blocked2.status -eq 'blocked' -and $blocked2.reason -eq 'CONFLICT_DECISION_REQUIRED') 'P05-V02 modified product did not require an explicit decision'
  $plan2 = New-HebriLegacyMigrationPlan -InstallRoot $Root -ProjectRoot $v2.Project -CatalogRoot $v2.Catalog -BaselinePath $baselinePath -DecisionsPath $decisionFixture
  Assert-P05 ($plan2.status -eq 'planned' -and $plan2.details.classifications.modified -eq 1 -and $plan2.details.classifications.unknown -eq 1) 'P05-V02 classified drift incorrectly'
  if ($plan2.status -eq 'planned') {
    $result2 = Approve-And-Apply $plan2
    Assert-CentralApplied $v2 $result2
    if ($result2.status -eq 'applied') {
      Assert-P05 ([IO.File]::ReadAllText((Join-Path $v2.Legacy 'instance/legacy-preserved/shared.txt')) -eq "custom shared`n") 'P05-V02 modified shared file was not preserved byte-for-byte'
      Assert-P05 ([IO.File]::ReadAllText((Join-Path $v2.Legacy 'instance/legacy-preserved/custom/config.txt')) -eq "local unknown`n") 'P05-V02 unknown file was not preserved'
    }
  }

  # P05-V03: flat/canonical duplicate with different bytes blocks before approval.
  $v3 = New-TestConsumer 'v03-conflict' $baselinePath
  Write-TestText (Join-Path $v3.Legacy 'instance/memory/local/note.txt') "canonical conflict`n"
  $plan3 = New-HebriLegacyMigrationPlan -InstallRoot $Root -ProjectRoot $v3.Project -CatalogRoot $v3.Catalog -BaselinePath $baselinePath
  Assert-P05 ($plan3.status -eq 'blocked' -and $plan3.reason -eq 'LEGACY_CANONICAL_CONFLICT' -and -not $plan3.writes_performed) 'P05-V03 legacy/canonical conflict did not fail closed'

  # P05-V04: prior backups are relocated once, then excluded from repeated snapshots.
  $v4a = New-TestConsumer 'v04-backup-a' $baselinePath
  Write-TestText (Join-Path $v4a.Legacy 'orquestador/migration/backups/old/snapshot/data.txt') "old backup`n"
  $plan4a = New-HebriLegacyMigrationPlan -InstallRoot $Root -ProjectRoot $v4a.Project -CatalogRoot $v4a.Catalog -BaselinePath $baselinePath
  $result4a = if ($plan4a.status -eq 'planned') { Approve-And-Apply $plan4a } else { $plan4a }
  Assert-P05 ($result4a.status -eq 'applied') 'P05-V04 migration with pre-existing backups failed'
  if ($result4a.status -eq 'applied') {
    $manifest4a = Read-HebriJsonDocument $result4a.details.snapshot_manifest_path
    Assert-P05 (@($manifest4a.files | Where-Object { $_.path -like 'orquestador/migration/backups/*' -or $_.path -like 'instance/migration/backups/*' }).Count -eq 0) 'P05-V04 snapshot retained a prior backup tree'
    Assert-P05 ((Test-Path -LiteralPath $result4a.details.prior_backups_manifest_path -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $result4a.details.prior_backups_path 'orquestador/migration/backups/old/snapshot/data.txt') -PathType Leaf)) 'P05-V04 prior backup was not preserved outside the restore snapshot'
    $restorePlan4 = New-HebriLegacyRestorePlan -InstallRoot $Root -ProjectRoot $v4a.Project -CatalogRoot $v4a.Catalog -SnapshotPath $result4a.details.snapshot_path
    $restoreResult4 = if ($restorePlan4.status -eq 'planned') { Approve-And-Apply $restorePlan4 'P05-V04-RESTORE-SI' } else { $restorePlan4 }
    $plan4b = if ($restoreResult4.status -eq 'applied') { New-HebriLegacyMigrationPlan -InstallRoot $Root -ProjectRoot $v4a.Project -CatalogRoot $v4a.Catalog -BaselinePath $baselinePath } else { $restoreResult4 }
    $result4b = if ($plan4b.status -eq 'planned') { Approve-And-Apply $plan4b 'P05-V04-REPEAT-SI' } else { $plan4b }
    Assert-P05 ($restoreResult4.status -eq 'applied' -and $result4b.status -eq 'applied') 'P05-V04 restore/repeated migration failed'
    if ($result4b.status -eq 'applied') {
      $manifest4b = Read-HebriJsonDocument $result4b.details.snapshot_manifest_path
      Assert-P05 (@($manifest4a.files).Count -eq @($manifest4b.files).Count -and $manifest4a.source_tree_sha256 -eq $manifest4b.source_tree_sha256) 'P05-V04 repeated snapshot grew or changed without source data changes'
      Assert-P05 (@($manifest4b.files | Where-Object { $_.path -like '*migration/backups/*' -or $_.path -like '.hebrinex-migration/*' }).Count -eq 0) 'P05-V04 repeated snapshot captured a backup or staging tree'
    }
  }

  # P05-V05: failures before publication roll back; catalog failure preserves valid pending state.
  foreach ($point in @('during_staging','after_snapshot','before_publish')) {
    $fx = New-TestConsumer ('v05-' + $point) $baselinePath
    $plan = New-HebriLegacyMigrationPlan -InstallRoot $Root -ProjectRoot $fx.Project -CatalogRoot $fx.Catalog -BaselinePath $baselinePath -FailurePoint $point
    $result = if ($plan.status -eq 'planned') { Approve-And-Apply $plan } else { $plan }
    Assert-P05 ($result.status -eq 'failed' -and $result.details.rolled_back -eq $true) "P05-V05 $point did not report a verified rollback"
    Assert-P05 (Test-Path -LiteralPath (Join-Path $fx.Legacy 'PROJECT_BINDING.yaml') -PathType Leaf) "P05-V05 $point did not restore the legacy source"
    Assert-P05 (-not (Test-Path -LiteralPath (Join-Path $fx.Legacy 'binding.json'))) "P05-V05 $point left a false central binding"
  }
  $v5c = New-TestConsumer 'v05-catalog' $baselinePath
  $plan5c = New-HebriLegacyMigrationPlan -InstallRoot $Root -ProjectRoot $v5c.Project -CatalogRoot $v5c.Catalog -BaselinePath $baselinePath -FailurePoint catalog
  $result5c = if ($plan5c.status -eq 'planned') { Approve-And-Apply $plan5c } else { $plan5c }
  Assert-P05 ($result5c.status -eq 'failed' -and $result5c.reason -eq 'REGISTRATION_PENDING' -and $result5c.exit_code -eq 8 -and $result5c.writes_performed) 'P05-V05 catalog failure was reported as success or lost write truth'
  Assert-P05 (Test-Path -LiteralPath (Join-Path $v5c.Legacy 'binding.json') -PathType Leaf) 'P05-V05 catalog failure did not preserve valid local binding'
  if (Test-Path -LiteralPath (Join-Path $v5c.Legacy 'instance/registration.json') -PathType Leaf) { Assert-P05 ((Read-HebriJsonDocument (Join-Path $v5c.Legacy 'instance/registration.json')).status -eq 'pending') 'P05-V05 catalog failure did not preserve pending registration' }
  $v5p = New-TestConsumer 'v05-after-publish' $baselinePath
  $plan5p = New-HebriLegacyMigrationPlan -InstallRoot $Root -ProjectRoot $v5p.Project -CatalogRoot $v5p.Catalog -BaselinePath $baselinePath -FailurePoint after_publish
  $result5p = if ($plan5p.status -eq 'planned') { Approve-And-Apply $plan5p } else { $plan5p }
  Assert-P05 ($result5p.status -eq 'failed' -and $result5p.reason -eq 'MIGRATION_RECOVERY_REQUIRED' -and $result5p.exit_code -eq 8 -and $result5p.writes_performed) 'P05-V05 post-publication failure did not require explicit recovery'
  Assert-P05 ((Test-Path -LiteralPath (Join-Path $v5p.Legacy 'binding.json') -PathType Leaf) -and (Test-Path -LiteralPath $result5p.details.snapshot_path -PathType Container)) 'P05-V05 post-publication failure lost the published instance or snapshot'

  # P05-V06: post-migration changes block restore unless the reviewed plan preserves them.
  $v6 = New-TestConsumer 'v06-restore' $baselinePath
  $plan6 = New-HebriLegacyMigrationPlan -InstallRoot $Root -ProjectRoot $v6.Project -CatalogRoot $v6.Catalog -BaselinePath $baselinePath
  $result6 = if ($plan6.status -eq 'planned') { Approve-And-Apply $plan6 } else { $plan6 }
  Assert-P05 ($result6.status -eq 'applied') 'P05-V06 setup migration failed'
  if ($result6.status -eq 'applied') {
    Write-TestText (Join-Path $v6.Legacy 'instance/memory/local/note.txt') "post migration change`n"
    $blockedRestore = New-HebriLegacyRestorePlan -InstallRoot $Root -ProjectRoot $v6.Project -CatalogRoot $v6.Catalog -SnapshotPath $result6.details.snapshot_path
    Assert-P05 ($blockedRestore.status -eq 'blocked' -and $blockedRestore.reason -eq 'POST_MIGRATION_CHANGES') 'P05-V06 restore ignored post-migration changes'
    $restorePlan = New-HebriLegacyRestorePlan -InstallRoot $Root -ProjectRoot $v6.Project -CatalogRoot $v6.Catalog -SnapshotPath $result6.details.snapshot_path -PreservePostMigrationChanges
    Assert-P05 ($restorePlan.status -eq 'planned') 'P05-V06 explicit preservation did not produce restore plan'
    if ($restorePlan.status -eq 'planned') {
      $restoreResult = Approve-And-Apply $restorePlan 'P05-RESTORE-SI'
      Assert-P05 ($restoreResult.status -eq 'applied' -and $restoreResult.reason -eq 'LEGACY_RESTORED') 'P05-V06 approved restore failed'
      Assert-P05 (Test-Path -LiteralPath (Join-Path $v6.Legacy 'PROJECT_BINDING.yaml') -PathType Leaf) 'P05-V06 legacy binding was not restored'
      Assert-P05 (-not (Test-Path -LiteralPath (Join-Path $v6.Legacy 'binding.json'))) 'P05-V06 central binding remained after legacy restore'
      Assert-P05 ([IO.File]::ReadAllText((Join-Path $restoreResult.details.preserved_post_migration_path 'instance/memory/local/note.txt')) -eq "post migration change`n") 'P05-V06 post-migration change was not preserved'
    }
  }

  # P05-V07: corrupt snapshot is rejected before restore writes.
  $v7 = New-TestConsumer 'v07-corrupt' $baselinePath
  $plan7 = New-HebriLegacyMigrationPlan -InstallRoot $Root -ProjectRoot $v7.Project -CatalogRoot $v7.Catalog -BaselinePath $baselinePath
  $result7 = if ($plan7.status -eq 'planned') { Approve-And-Apply $plan7 } else { $plan7 }
  if ($result7.status -eq 'applied') {
    Write-TestText (Join-Path $result7.details.snapshot_path 'shared.txt') "corrupt`n"
    $restore7 = New-HebriLegacyRestorePlan -InstallRoot $Root -ProjectRoot $v7.Project -CatalogRoot $v7.Catalog -SnapshotPath $result7.details.snapshot_path
    Assert-P05 ($restore7.status -eq 'blocked' -and $restore7.reason -eq 'BACKUP_INTEGRITY_FAILED' -and -not $restore7.writes_performed) 'P05-V07 corrupt snapshot reached restore apply'
  }
  else { Assert-P05 $false 'P05-V07 setup migration failed' }

  # P05-V08: space, containment and occupied lock fail before mutation.
  $v8s = New-TestConsumer 'v08-space' $baselinePath
  $spacePlan = New-HebriLegacyMigrationPlan -InstallRoot $Root -ProjectRoot $v8s.Project -CatalogRoot $v8s.Catalog -BaselinePath $baselinePath -AvailableBytesOverride 0
  Assert-P05 ($spacePlan.status -eq 'blocked' -and $spacePlan.reason -eq 'INSUFFICIENT_SPACE') 'P05-V08 insufficient space was not rejected'
  $v8p = New-TestConsumer 'v08-path' $baselinePath
  $outsidePlan = New-HebriLegacyMigrationPlan -InstallRoot $Root -ProjectRoot $v8p.Project -CatalogRoot $v8p.Catalog -BaselinePath $baselinePath -SnapshotBase (Join-Path $tempRoot 'outside-snapshot')
  Assert-P05 ($outsidePlan.status -eq 'blocked' -and $outsidePlan.reason -eq 'PATH_OUTSIDE_ROOT') 'P05-V08 outside snapshot path was accepted'
  $v8r = New-TestConsumer 'v08-reparse' $baselinePath
  $outsideReparse = Join-Path $tempRoot 'v08-reparse-outside'
  Write-TestText (Join-Path $outsideReparse 'witness.txt') "outside witness unchanged`n"
  $junctionPath = Join-Path $v8r.Legacy 'external-junction'
  try { $null = New-Item -ItemType Junction -Path $junctionPath -Target $outsideReparse }
  catch { Assert-P05 $false "P05-V08 could not create junction fixture: $($_.Exception.Message)" }
  if (Test-Path -LiteralPath $junctionPath) {
    $reparsePlan = New-HebriLegacyMigrationPlan -InstallRoot $Root -ProjectRoot $v8r.Project -CatalogRoot $v8r.Catalog -BaselinePath $baselinePath
    Assert-P05 ($reparsePlan.status -eq 'blocked' -and $reparsePlan.reason -eq 'REPARSE_POINT_UNSUPPORTED' -and -not $reparsePlan.writes_performed) 'P05-V08 reparse point was followed or accepted'
    [IO.Directory]::Delete($junctionPath)
    Assert-P05 ([IO.File]::ReadAllText((Join-Path $outsideReparse 'witness.txt')) -eq "outside witness unchanged`n") 'P05-V08 reparse rejection modified the external target'
  }
  $v8l = New-TestConsumer 'v08-lock' $baselinePath
  $lockPlan = New-HebriLegacyMigrationPlan -InstallRoot $Root -ProjectRoot $v8l.Project -CatalogRoot $v8l.Catalog -BaselinePath $baselinePath
  if ($lockPlan.status -eq 'planned') {
    $descriptor8 = $lockPlan.details.descriptor
    $approval8 = New-HebriScopedApprovalEnvelope -Descriptor $descriptor8 -HumanEvidenceId 'P05-LOCK-SI' -HumanDecision approved -ApprovedText 'SI'
    $held = Enter-HebriOperationLock -Descriptor $descriptor8 -ApprovalId $approval8.Id
    try {
      $blockedLock = Invoke-HebriLegacyMigrationOperation -Descriptor $descriptor8 -ApprovalId $approval8.Id
      Assert-P05 ($blockedLock.status -eq 'failed' -and $blockedLock.reason -eq 'LOCK_BUSY' -and -not $blockedLock.writes_performed) 'P05-V08 occupied lock did not block before mutation'
    }
    finally { [void](Exit-HebriOperationLock -LockPath $held.Path) }
  }
  else { Assert-P05 $false 'P05-V08 lock setup plan failed' }

  if ($RunNegativeTests) {
    $badBaseline = ($baseline | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
    $badBaseline.files[0].path = '../escape.txt'
    Assert-P05 (-not (Test-HebriLegacyBaseline $badBaseline).Valid) 'negative: traversal baseline was accepted'
    $badHash = ($baseline | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
    $badHash.tree_sha256 = ('0' * 64)
    Assert-P05 (-not (Test-HebriLegacyBaseline $badHash).Valid) 'negative: incorrect baseline tree hash was accepted'
    $crafted = ($plan1.details.descriptor | ConvertTo-Json -Depth 40 | ConvertFrom-Json)
    $crafted.plan.action = 'invented'
    Assert-P05 (-not (Test-HebriLegacyMigrationDescriptor $crafted).Valid) 'negative: unsupported migration action was accepted'
    $extraPlan = ($plan1.details.descriptor.plan | ConvertTo-Json -Depth 40 | ConvertFrom-Json)
    $extraPlan | Add-Member -NotePropertyName injected_write -NotePropertyValue 'outside-contract'
    $extraDescriptor = New-TestDescriptorFromPlan -Original $plan1.details.descriptor -Plan $extraPlan
    Assert-P05 (-not (Test-HebriLegacyMigrationDescriptor $extraDescriptor).Valid) 'negative: an undeclared plan property was accepted'
    $unsafePlan = ($plan1.details.descriptor.plan | ConvertTo-Json -Depth 40 | ConvertFrom-Json)
    $copyItem = @($unsafePlan.files | Where-Object { $_.disposition -eq 'instance_copy' } | Select-Object -First 1)
    if ($copyItem.Count -eq 1) { $copyItem[0].destination = '../escape.txt' }
    $unsafeDescriptor = New-TestDescriptorFromPlan -Original $plan1.details.descriptor -Plan $unsafePlan
    Assert-P05 ($copyItem.Count -eq 1 -and -not (Test-HebriLegacyMigrationDescriptor $unsafeDescriptor).Valid) 'negative: an unsafe destination in a rehashed descriptor was accepted'
    $overrideFixture = New-TestConsumer 'negative-fixture-override' $baselinePath
    Remove-Item -LiteralPath (Join-Path $overrideFixture.Project '.hebrinex-migration-fixture') -Force
    $forbiddenOverride = New-HebriLegacyMigrationPlan -InstallRoot $Root -ProjectRoot $overrideFixture.Project -CatalogRoot $overrideFixture.Catalog -BaselinePath $baselinePath -FailurePoint during_staging
    Assert-P05 ($forbiddenOverride.status -eq 'blocked' -and $forbiddenOverride.reason -eq 'OPERATION_DESCRIPTOR_INVALID') 'negative: failure injection was accepted outside an isolated fixture'
  }

  $tagResults = @()
  if ($UseGitTags) {
    foreach ($tag in @('v0.10.11','v0.16.0')) { $tagResults += Invoke-TagMatrix $tag }
    foreach ($tagResult in $tagResults) { Write-Host "P05-TAG=$($tagResult.tag) files=$($tagResult.files) tree_sha256=$($tagResult.tree_sha256) plan=$($tagResult.status) reason=$($tagResult.reason)" }
  }

  if ($script:Failures.Count -gt 0) {
    Write-Host "P05 legacy migration validation checks=$($script:Checks) failures=$($script:Failures.Count)"
    $script:Failures | ForEach-Object { Write-Host "FAIL: $_" }
    exit 1
  }
  Write-Host "P05 legacy migration validation checks=$($script:Checks)"
  Write-Host 'P05-V01..V08=pass'
  if ($UseGitTags) { Write-Host 'P05 trusted local tag matrix=pass' }
  Write-Host 'P05 legacy migration validation OK'
}
finally {
  if (Test-Path -LiteralPath $tempRoot -PathType Container) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
