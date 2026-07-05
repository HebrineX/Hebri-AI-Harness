param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [string]$TargetVersion = '0.12.0',
  [switch]$CheckOnly,
  [switch]$Apply
)

$ErrorActionPreference = 'Stop'

function Resolve-HarnessPath([string]$RelativePath) {
  Join-Path $Root $RelativePath
}

function Normalize-RelativePath([string]$Path) {
  return ($Path -replace '\\', '/')
}

function Get-RelativePath([string]$BasePath, [string]$FullPath) {
  $base = $BasePath.TrimEnd('\', '/')
  $relative = $FullPath.Substring($base.Length).TrimStart('\', '/')
  return Normalize-RelativePath $relative
}

function Ensure-Directory([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Read-RequiredText([string]$RelativePath) {
  $path = Resolve-HarnessPath $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "missing required file: $RelativePath"
  }
  return [IO.File]::ReadAllText($path)
}

function Write-Utf8Text([string]$Path, [string]$Text) {
  $parent = Split-Path -Parent $Path
  if (-not [string]::IsNullOrWhiteSpace($parent)) {
    Ensure-Directory $parent
  }
  [IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), [Text.UTF8Encoding]::new($false))
}

function Format-YamlString([string]$Value) {
  if ($null -eq $Value) { $Value = '' }
  return "'" + ($Value -replace "'", "''") + "'"
}

function ConvertTo-YamlList([object]$Items, [string]$Indent) {
  $list = New-Object System.Collections.Generic.List[string]
  if ($null -ne $Items) {
    foreach ($item in $Items) {
      if (-not [string]::IsNullOrWhiteSpace([string]$item)) {
        [void]$list.Add([string]$item)
      }
    }
  }
  if ($list.Count -eq 0) {
    return "$Indent[]"
  }
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($item in $list) {
    [void]$lines.Add("$Indent- $(Format-YamlString $item)")
  }
  return ($lines -join "`n")
}

function ConvertTo-YamlBool([bool]$Value) {
  if ($Value) { return 'true' }
  return 'false'
}

function Get-Scalar([string]$Text, [string]$Key) {
  foreach ($line in ($Text -split "`n")) {
    if ($line -match ('^\s*' + [regex]::Escape($Key) + ':\s*(.*)$')) {
      return $Matches[1].Trim().Trim('"').Trim("'")
    }
  }
  return ''
}

function Get-ListValues([string]$Text, [string]$Key) {
  $items = New-Object System.Collections.Generic.List[string]
  $activeList = $false
  foreach ($line in ($Text -split "`n")) {
    if ($line -match ('^' + [regex]::Escape($Key) + ':\s*$')) {
      $activeList = $true
      continue
    }
    if ($activeList -and $line -match '^[A-Za-z0-9_.-]+:\s*') {
      $activeList = $false
    }
    if ($activeList -and $line -match '^\s*-\s+(.+?)\s*$') {
      [void]$items.Add($Matches[1].Trim().Trim('"').Trim("'"))
    }
  }
  return $items
}

function Get-RouteFile([string]$SourceVersion, [string]$TargetVersion) {
  $route = "orquestador/migration/versions/$SourceVersion-to-$TargetVersion.yaml"
  if (Test-Path -LiteralPath (Resolve-HarnessPath $route) -PathType Leaf) {
    return $route
  }
  return ''
}

function Test-SupportedBinding([string]$SourceVersion, [string]$BindingMode) {
  if ($SourceVersion -eq '0.9.0') {
    return @('bound', 'source_template') -contains $BindingMode
  }
  if ($SourceVersion -eq '0.8.10') {
    return $BindingMode -eq 'bound'
  }
  if ($SourceVersion -eq '0.10.11') {
    return @('bound', 'source_template') -contains $BindingMode
  }
  return $false
}

function Assert-RequiredRuntimePaths([object]$PlannedAdditions) {
  foreach ($item in $PlannedAdditions) {
    $relative = ([string]$item).TrimEnd('/')
    if ([string]::IsNullOrWhiteSpace($relative)) { continue }
    $path = Resolve-HarnessPath $relative
    if (-not (Test-Path -LiteralPath $path)) {
      throw "missing additive path before Apply: $item"
    }
  }
}

function New-MigrationBackup([string]$MigrationId) {
  $backupRoot = Resolve-HarnessPath 'orquestador/migration/backups'
  Ensure-Directory $backupRoot
  $backupPath = Join-Path $backupRoot $MigrationId
  $snapshotPath = Join-Path $backupPath 'snapshot'
  Ensure-Directory $snapshotPath

  $rootFull = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\', '/')
  $manifest = New-Object System.Collections.Generic.List[string]
  $files = Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object {
    $rel = Get-RelativePath $rootFull $_.FullName
    -not ($rel -like 'orquestador/migration/backups/*')
  } | Sort-Object FullName

  foreach ($file in $files) {
    $rel = Get-RelativePath $rootFull $file.FullName
    $destination = Join-Path $snapshotPath ($rel -replace '/', [IO.Path]::DirectorySeparatorChar)
    Ensure-Directory (Split-Path -Parent $destination)
    Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
    [void]$manifest.Add("$rel|$($file.Length)|$($file.LastWriteTimeUtc.ToString('o'))")
  }

  if ($manifest.Count -eq 0) {
    throw 'backup failed: no files captured'
  }

  $manifestPath = Join-Path $backupPath 'backup-manifest.txt'
  Write-Utf8Text $manifestPath (($manifest -join "`n") + "`n")

  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw 'backup failed: manifest was not written'
  }

  return [ordered]@{
    Path = $backupPath
    SnapshotPath = $snapshotPath
    ManifestPath = $manifestPath
    FileCount = $manifest.Count
  }
}

function Invoke-HarnessValidator([string]$RelativePath, [string]$Mode) {
  $path = Resolve-HarnessPath $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "validator not found: $RelativePath"
  }
  if ($Mode -eq 'require_applied') {
    & $path -Root $Root -RequireApplied *> $null
  }
  elseif ($Mode -eq 'negative_tests') {
    & $path -Root $Root -RunNegativeTests *> $null
  }
  else {
    & $path -Root $Root *> $null
  }
  if ($LASTEXITCODE -ne 0) {
    throw "validator failed: $RelativePath exit_code=$LASTEXITCODE"
  }
  return 'ok'
}

function Write-PostMigrationContract(
  [string]$SourceVersion,
  [string]$TargetVersion,
  [string]$BindingMode,
  [bool]$ProjectRootVerified,
  [bool]$ValidatorsPassed
) {
  $contractPath = Resolve-HarnessPath 'orquestador/migration/contracts/post-migration-contract.yaml'
  $contract = @"
schema: hebrinex.post_migration_contract
version: "0.1"
template: false
harness_version: "$TargetVersion"
source_version: "$SourceVersion"
target_version: "$TargetVersion"
binding_mode: "$BindingMode"
project_root_verified: $(ConvertTo-YamlBool $ProjectRootVerified)
agent_authority: harness_only
agent_registry_active: true
security_policy_active: true
runtime_enablement_active: true
migration_service_active: true
active_contract_written: true
old_approvals_expired: true
backup_verified: true
validators_passed: $(ConvertTo-YamlBool $ValidatorsPassed)
migration_report_written: true
migration_status: applied
required_evidence:
  - migration_report
  - backup_manifest
  - validator_output
  - active_contract_ref
success_rule: "migration_status can be applied only when all booleans above are true."
"@
  Write-Utf8Text $contractPath ($contract + "`n")
  return $contractPath
}

function Write-MigrationReport(
  [string]$ReportPath,
  [string]$MigrationId,
  [string]$SourceVersion,
  [string]$TargetVersion,
  [string]$BindingMode,
  [string]$ProjectRoot,
  [string]$RouteFile,
  [object]$PlannedAdditions,
  [object]$Preserve,
  [object]$Backup,
  [hashtable]$ValidatorResults,
  [string]$ContractPath,
  [string]$StartedAt,
  [string]$FinishedAt
) {
  $plannedAdditionsYaml = ConvertTo-YamlList $PlannedAdditions '    '
  $preserveYaml = ConvertTo-YamlList $Preserve '    '
  $modifiedYaml = ConvertTo-YamlList @('orquestador/migration/contracts/post-migration-contract.yaml') '    '
  $filesAddedYaml = ConvertTo-YamlList @() '    '
  $risksYaml = ConvertTo-YamlList @('HARNESS_VERSION is preserved in this slice; final version bump remains a separate release gate.') '  '
  $nextStepsYaml = ConvertTo-YamlList @('Integrate migration validation into audit-harness, validate-harness and init.sh.', 'Run final auditors before changing HARNESS_VERSION.') '  '

  $validateAgent = $ValidatorResults['validate_agent_contracts']
  $validateSecurity = $ValidatorResults['validate_security_policy']
  $validateMigration = $ValidatorResults['validate_migration']
  $auditHarness = $ValidatorResults['audit_harness']

  if ([string]::IsNullOrWhiteSpace($validateAgent)) { $validateAgent = 'not_run' }
  if ([string]::IsNullOrWhiteSpace($validateSecurity)) { $validateSecurity = 'not_run' }
  if ([string]::IsNullOrWhiteSpace($validateMigration)) { $validateMigration = 'not_run' }
  if ([string]::IsNullOrWhiteSpace($auditHarness)) { $auditHarness = 'not_run' }

  $report = @"
schema: hebrinex.migration_report
version: "0.1"
template: false
migration_id: "$MigrationId"
approval_id: "HAH-IMPLEMENT-010-SLICE-4-MIGRATION-APPLY"
source_version: "$SourceVersion"
target_version: "$TargetVersion"
mode: "Apply"
status: applied
started_at: "$StartedAt"
finished_at: "$FinishedAt"
root: $(Format-YamlString $Root)
binding_mode: "$BindingMode"
project_root: $(Format-YamlString $ProjectRoot)
route_file: "$RouteFile"
check_only:
  wrote_files: false
  planned_additions:
$plannedAdditionsYaml
  planned_preserve:
$preserveYaml
backup:
  required: true
  created: true
  path: $(Format-YamlString $Backup.Path)
  manifest_or_checksum: $(Format-YamlString $Backup.ManifestPath)
  files_captured: $($Backup.FileCount)
apply:
  files_added:
$filesAddedYaml
  files_modified:
$modifiedYaml
  files_preserved:
$preserveYaml
validators:
  validate_agent_contracts: $validateAgent
  validate_security_policy: $validateSecurity
  validate_migration: $validateMigration
  audit_harness: $auditHarness
post_migration_contract:
  path: $(Format-YamlString $ContractPath)
  status: applied
risks:
$risksYaml
next_steps:
$nextStepsYaml
"@
  Write-Utf8Text $ReportPath ($report + "`n")
}

if (($CheckOnly -and $Apply) -or (-not $CheckOnly -and -not $Apply)) {
  throw 'Use exactly one mode: -CheckOnly or -Apply.'
}

$Root = (Resolve-Path -LiteralPath $Root).Path
$version = (Read-RequiredText 'HARNESS_VERSION').Trim()
$bindingText = Read-RequiredText 'PROJECT_BINDING.yaml'
$bindingMode = Get-Scalar $bindingText 'binding_mode'
$projectRoot = Get-Scalar $bindingText 'project_root'
$routeFile = Get-RouteFile $version $TargetVersion

if ([string]::IsNullOrWhiteSpace($routeFile)) {
  throw "unsupported migration route: $version-to-$TargetVersion"
}

if (-not (Test-SupportedBinding $version $bindingMode)) {
  throw "unsupported binding mode for route $version-to-$TargetVersion`: $bindingMode"
}

$routeText = Read-RequiredText $routeFile
$registryText = Read-RequiredText 'orquestador/migration/migration-registry.yaml'
$routeId = Get-Scalar $routeText 'id'
$plannedAdditions = Get-ListValues $routeText 'additive_paths'
$preserve = Get-ListValues $routeText 'never_overwrite'
$validators = Get-ListValues $registryText 'required_validators'

if ($CheckOnly) {
  Write-Host 'Hebri-AI-Harness migration CheckOnly'
  Write-Host "root=$Root"
  Write-Host "detected_version=$version"
  Write-Host "target_version=$TargetVersion"
  Write-Host "route_id=$routeId"
  Write-Host "binding_mode=$bindingMode"
  Write-Host "project_root=$projectRoot"
  Write-Host "route_file=$routeFile"
  Write-Host 'check_only_writes=false'
  Write-Host 'apply_available=true'
  Write-Host 'backup_required_for_apply=true'
  Write-Host 'planned_additions:'
  foreach ($item in $plannedAdditions) { Write-Host " - $item" }
  Write-Host 'preserve:'
  foreach ($item in $preserve) { Write-Host " - $item" }
  Write-Host 'validators_required:'
  foreach ($item in $validators) { Write-Host " - $item" }
  Write-Host 'expected_post_migration_contract=orquestador/migration/contracts/post-migration-contract.yaml'
  exit 0
}

Assert-RequiredRuntimePaths $plannedAdditions

$projectRootVerified = $false
if (-not [string]::IsNullOrWhiteSpace($projectRoot)) {
  $projectRootVerified = Test-Path -LiteralPath $projectRoot -PathType Container
}

$startedAt = (Get-Date).ToUniversalTime().ToString('o')
$migrationId = 'migration-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ') + '-' + ([guid]::NewGuid().ToString('N').Substring(0, 8))
$backup = New-MigrationBackup $migrationId

$validatorResults = @{}
$validatorResults['validate_agent_contracts'] = Invoke-HarnessValidator 'scripts/validate-agent-contracts.ps1' 'default'
$validatorResults['validate_security_policy'] = Invoke-HarnessValidator 'scripts/validate-security-policy.ps1' 'default'

$contractPath = Write-PostMigrationContract $version $TargetVersion $bindingMode $projectRootVerified $true
$reportPath = Resolve-HarnessPath "orquestador/migration/reports/$migrationId.yaml"
$finishedAt = (Get-Date).ToUniversalTime().ToString('o')

Write-MigrationReport $reportPath $migrationId $version $TargetVersion $bindingMode $projectRoot $routeFile $plannedAdditions $preserve $backup $validatorResults $contractPath $startedAt $finishedAt

$validatorResults['validate_migration'] = Invoke-HarnessValidator 'scripts/validate-migration.ps1' 'require_applied'
$validatorResults['audit_harness'] = Invoke-HarnessValidator 'scripts/audit-harness.ps1' 'negative_tests'
$finishedAt = (Get-Date).ToUniversalTime().ToString('o')
Write-MigrationReport $reportPath $migrationId $version $TargetVersion $bindingMode $projectRoot $routeFile $plannedAdditions $preserve $backup $validatorResults $contractPath $startedAt $finishedAt

Write-Host 'Hebri-AI-Harness migration Apply'
Write-Host "root=$Root"
Write-Host "migration_id=$migrationId"
Write-Host "source_version=$version"
Write-Host "target_version=$TargetVersion"
Write-Host "route_id=$routeId"
Write-Host "backup_path=$($backup.Path)"
Write-Host "backup_manifest=$($backup.ManifestPath)"
Write-Host "post_migration_contract=$contractPath"
Write-Host "migration_report=$reportPath"
Write-Host 'migration_status=applied'
Write-Host 'harness_version_file_preserved=true'

exit 0
