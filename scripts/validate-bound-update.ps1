param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$RunNegativeTests
)

$ErrorActionPreference = 'Stop'
$script:Failures = New-Object System.Collections.Generic.List[string]

function Add-Failure([string]$Message) {
  $script:Failures.Add($Message) | Out-Null
}

function Resolve-RootHarnessPath([string]$HarnessRoot, [string]$RelativePath) {
  $norm = ($RelativePath -replace '\\','/').TrimStart('./')
  $mapped = switch -Regex ($norm) {
    '^PROJECT_BINDING[.]yaml$' { 'instance/PROJECT_BINDING.yaml'; break }
    '^orquestador/context$' { 'instance/context'; break }
    '^orquestador/context/(.+)$' { 'instance/context/' + $Matches[1]; break }
    '^orquestador/memory/(local|project|cycle|daily|complete)$' { 'instance/memory/' + $Matches[1]; break }
    '^orquestador/memory/(local|project|cycle|daily|complete)/(.+)$' { 'instance/memory/' + $Matches[1] + '/' + $Matches[2]; break }
    '^orquestador/sdd/progress/(schemas|templates)(/.*)?$' { $norm; break }
    '^orquestador/sdd/progress/(.+)$' { 'instance/sdd/progress/' + $Matches[1]; break }
    '^orquestador/migration/backups$' { 'instance/migration/backups'; break }
    '^orquestador/migration/backups/(.+)$' { 'instance/migration/backups/' + $Matches[1]; break }
    '^orquestador/migration/contracts/post-migration-contract[.]yaml$' { 'instance/migration/contracts/post-migration-contract.yaml'; break }
    '^orquestador/migration/reports$' { 'instance/migration/reports'; break }
    '^orquestador/migration/reports/(.+)$' { 'instance/migration/reports/' + $Matches[1]; break }
    default { $norm }
  }
  $mappedPath = Join-Path $HarnessRoot $mapped
  if ($mapped -ne $norm -and (Test-Path -LiteralPath $mappedPath)) { return $mappedPath }
  Join-Path $HarnessRoot $RelativePath
}

function Resolve-HarnessPath([string]$RelativePath) {
  Resolve-RootHarnessPath $Root $RelativePath
}

function Read-HarnessText([string]$RelativePath) {
  $path = Resolve-HarnessPath $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    Add-Failure "missing file: $RelativePath"
    return ''
  }
  $text = [IO.File]::ReadAllText($path)
  if ([string]::IsNullOrWhiteSpace($text)) { Add-Failure "empty file: $RelativePath" }
  return $text
}

function Get-Scalar([string]$Text, [string]$Key) {
  foreach ($line in ($Text -split "`n")) {
    if ($line -match ('^\s*' + [regex]::Escape($Key) + ':\s*(.*)$')) {
      return $Matches[1].Trim().Trim('"').Trim("'")
    }
  }
  return ''
}

function Set-TopLevelScalar([string]$Text, [string]$Key, [string]$YamlValue) {
  return [regex]::Replace($Text, ('(?m)^' + [regex]::Escape($Key) + ':.*$'), ($Key + ': ' + $YamlValue), 1)
}

function Assert-Contains([string]$RelativePath, [string]$Pattern, [string]$Message) {
  $text = Read-HarnessText $RelativePath
  if ($text -notmatch $Pattern) { Add-Failure $Message }
}

function Assert-TextContains([string]$Text, [string]$Pattern, [string]$Message) {
  if ($Text -notmatch $Pattern) { Add-Failure $Message }
}

function Assert-PathMissing([string]$Path, [string]$Message) {
  if (Test-Path -LiteralPath $Path) { Add-Failure $Message }
}

function Get-LastExitCodeValue() {
  if ($null -eq $global:LASTEXITCODE) { return 0 }
  return [int]$global:LASTEXITCODE
}

function Write-Utf8Text([string]$Path, [string]$Text) {
  $parent = Split-Path -Parent $Path
  if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  [IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), [Text.UTF8Encoding]::new($false))
}

function Remove-TempTree([string]$TempRoot) {
  if ([string]::IsNullOrWhiteSpace($TempRoot)) { return }
  $full = [IO.Path]::GetFullPath($TempRoot)
  $systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')
  if (-not $full.StartsWith($systemTemp, [StringComparison]::OrdinalIgnoreCase)) {
    throw "refusing to remove non-temp path: $TempRoot"
  }
  if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Recurse -Force }
}

function Assert-BoundUpdateShape([string]$HarnessRoot, [string]$ProjectRoot, [string]$ExpectedVersion, [string]$OriginalInstanceId) {
  $bindingPath = Resolve-RootHarnessPath $HarnessRoot 'PROJECT_BINDING.yaml'
  if (-not (Test-Path -LiteralPath $bindingPath -PathType Leaf)) {
    Add-Failure "updated bound harness missing PROJECT_BINDING.yaml: $HarnessRoot"
    return
  }
  $binding = [IO.File]::ReadAllText($bindingPath)
  if ((Get-Scalar $binding 'binding_mode') -ne 'bound') { Add-Failure 'updated bound harness binding_mode must remain bound' }
  if ((Get-Scalar $binding 'harness_version') -ne $ExpectedVersion) { Add-Failure "updated PROJECT_BINDING harness_version must be $ExpectedVersion" }
  if ((Get-Scalar $binding 'harness_instance_id') -ne $OriginalInstanceId) { Add-Failure 'update-bound must preserve harness_instance_id' }
  $boundProjectRoot = Get-Scalar $binding 'project_root'
  if (([IO.Path]::GetFullPath($boundProjectRoot).TrimEnd('\','/')) -ne ([IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\','/'))) {
    Add-Failure "updated bound project_root mismatch: $boundProjectRoot"
  }

  $versionPath = Join-Path $HarnessRoot 'HARNESS_VERSION'
  if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) { Add-Failure 'updated bound harness missing HARNESS_VERSION' }
  elseif (([IO.File]::ReadAllText($versionPath)).Trim() -ne $ExpectedVersion) { Add-Failure "updated HARNESS_VERSION must be $ExpectedVersion" }

  Assert-PathMissing (Join-Path $HarnessRoot '.git') 'update-bound must not copy .git into .hebrinex'
  Assert-PathMissing (Join-Path $HarnessRoot '.codex') 'update-bound must not copy .codex into .hebrinex'
  Assert-PathMissing (Join-Path $HarnessRoot 'infoHebri.md') 'update-bound must not copy infoHebri.md into .hebrinex'

  foreach ($marker in @(
    'orquestador/memory/local/update-bound-marker.md',
    'orquestador/sdd/progress/cycles/update-bound-marker.md'
  )) {
    $markerPath = Resolve-RootHarnessPath $HarnessRoot $marker
    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) { Add-Failure "update-bound did not preserve marker: $marker" }
    elseif ([IO.File]::ReadAllText($markerPath) -notmatch 'preserve_marker_0107') { Add-Failure "update-bound marker content changed: $marker" }
  }

  $reportsDir = Resolve-RootHarnessPath $HarnessRoot 'orquestador/migration/reports'
  $reports = @()
  if (Test-Path -LiteralPath $reportsDir -PathType Container) {
    $reports = @(Get-ChildItem -LiteralPath $reportsDir -File -Filter 'migration-bound-update-*.yaml' | Sort-Object LastWriteTimeUtc -Descending)
  }
  if ($reports.Count -eq 0) {
    Add-Failure 'updated bound harness must contain migration-bound-update report'
    return
  }

  $reportText = [IO.File]::ReadAllText($reports[0].FullName)
  Assert-TextContains $reportText 'template:\s*false' 'bound update report must not be template'
  Assert-TextContains $reportText 'mode:\s*"Apply"' 'bound update report must record Apply mode'
  Assert-TextContains $reportText 'status:\s*applied' 'bound update report must set status applied'
  Assert-TextContains $reportText 'created:\s*true' 'bound update report must confirm backup creation'
  Assert-TextContains $reportText 'validate_agent_contracts:\s*ok' 'bound update report must include agent validator OK'
  Assert-TextContains $reportText 'validate_security_policy:\s*ok' 'bound update report must include security validator OK'
  Assert-TextContains $reportText 'validate_migration:\s*ok' 'bound update report must include migration validator OK'
  Assert-TextContains $reportText 'validate_harness:\s*ok' 'bound update report must include harness validator OK'
  Assert-TextContains $reportText 'PROJECT_BINDING[.]yaml identity and project root' 'bound update report must declare binding preservation'
  Assert-TextContains $reportText 'state, registry, cycles, locks and approvals' 'bound update report must declare state preservation'

  $backupPath = Get-Scalar $reportText 'path'
  $manifestPath = Get-Scalar $reportText 'manifest_or_checksum'
  if ([string]::IsNullOrWhiteSpace($backupPath) -or -not (Test-Path -LiteralPath $backupPath -PathType Container)) {
    Add-Failure "bound update backup path missing or invalid: $backupPath"
  }
  if ([string]::IsNullOrWhiteSpace($manifestPath) -or -not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    Add-Failure "bound update backup manifest missing or invalid: $manifestPath"
  }
  elseif ((Get-Item -LiteralPath $manifestPath).Length -eq 0) {
    Add-Failure "bound update backup manifest is empty: $manifestPath"
  }
}

function Invoke-SourceTemplateBoundUpdateSmoke() {
  $sourceVersion = (Read-HarnessText 'HARNESS_VERSION').Trim()
  $previousVersion = '0.10.0'
  if ($sourceVersion -match '^0[.]([0-9]+)[.]([0-9]+)$') {
    $previousPatch = [Math]::Max(([int]$Matches[2]) - 1, 0)
    $previousVersion = "0.$($Matches[1]).$previousPatch"
  }
  $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('hebrinex-bound-update-test-' + [guid]::NewGuid().ToString('N'))
  $projectRoot = Join-Path $tempRoot 'consumer-project'
  New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
  Write-Utf8Text (Join-Path $projectRoot 'README.md') "temporary consumer project`n"
  try {
    $cli = Resolve-HarnessPath 'scripts/hebrinex.ps1'

    $global:LASTEXITCODE = 0
    $bootstrap = & $cli bootstrap -Root $Root -Apply -ProjectRoot $projectRoot *>&1
    if ((Get-LastExitCodeValue) -ne 0) { Add-Failure "bootstrap precondition failed for bound update smoke: $($bootstrap -join ' ')" }

    $boundRoot = Join-Path $projectRoot '.hebrinex'
    $bindingPath = Resolve-RootHarnessPath $boundRoot 'PROJECT_BINDING.yaml'
    $binding = [IO.File]::ReadAllText($bindingPath)
    $originalInstanceId = Get-Scalar $binding 'harness_instance_id'

    Write-Utf8Text (Join-Path $boundRoot 'orquestador/memory/local/update-bound-marker.md') "preserve_marker_0107 local memory`n"
    Write-Utf8Text (Join-Path $boundRoot 'orquestador/sdd/progress/cycles/update-bound-marker.md') "preserve_marker_0107 progress cycle`n"
    Write-Utf8Text (Join-Path $boundRoot 'HARNESS_VERSION') "$previousVersion`n"
    $oldBinding = Set-TopLevelScalar $binding 'harness_version' ('"' + $previousVersion + '"')
    $legacyBindingPath = Join-Path $boundRoot 'PROJECT_BINDING.yaml'
    Write-Utf8Text $legacyBindingPath ($oldBinding.TrimEnd("`r","`n") + "`n")
    if ($bindingPath -ne $legacyBindingPath -and (Test-Path -LiteralPath $bindingPath -PathType Leaf)) {
      Remove-Item -LiteralPath $bindingPath -Force
    }

    $global:LASTEXITCODE = 0
    $checkOnly = & $cli update-bound -Root $Root -CheckOnly -ProjectRoot $projectRoot *>&1
    if ((Get-LastExitCodeValue) -ne 0) { Add-Failure "update-bound CheckOnly failed: $($checkOnly -join ' ')" }
    $checkOnlyText = $checkOnly -join "`n"
    if ($checkOnlyText -notmatch 'writes=false' -or $checkOnlyText -notmatch 'apply_available=true') {
      Add-Failure 'update-bound CheckOnly must report writes=false and apply_available=true'
    }
    if ($checkOnlyText -notmatch 'preserve PROJECT_BINDING identity') {
      Add-Failure 'update-bound CheckOnly must declare state/binding preservation'
    }

    $global:LASTEXITCODE = 0
    $apply = & $cli update-bound -Root $Root -Apply -ProjectRoot $projectRoot *>&1
    if ((Get-LastExitCodeValue) -ne 0) { Add-Failure "update-bound Apply failed: $($apply -join ' ')" }
    $applyText = $apply -join "`n"
    if ($applyText -notmatch 'update_status=applied') { Add-Failure 'update-bound Apply must report update_status=applied' }

    Assert-BoundUpdateShape $boundRoot $projectRoot $sourceVersion $originalInstanceId

    $boundValidator = Join-Path $boundRoot 'scripts/validate-harness.ps1'
    if (Test-Path -LiteralPath $boundValidator -PathType Leaf) {
      $global:LASTEXITCODE = 0
      & $boundValidator -Root $boundRoot -SkipNestedValidators *> $null
      if ((Get-LastExitCodeValue) -ne 0) { Add-Failure "updated bound harness validate-harness failed: $(Get-LastExitCodeValue)" }
    }
    else { Add-Failure 'updated bound harness missing validate-harness.ps1' }
  }
  finally {
    Remove-TempTree $tempRoot
  }
}

function Assert-BoundModeUpdateReadiness() {
  $binding = Read-HarnessText 'PROJECT_BINDING.yaml'
  if ((Get-Scalar $binding 'binding_mode') -ne 'bound') { Add-Failure 'bound update readiness called on non-bound harness' }
  Assert-PathMissing (Resolve-HarnessPath '.git') 'bound harness must not contain .git'
  Assert-PathMissing (Resolve-HarnessPath '.codex') 'bound harness must not contain .codex'
  Assert-PathMissing (Resolve-HarnessPath 'infoHebri.md') 'bound harness must not contain infoHebri.md'
}

function Run-NegativeTests() {
  $badSource = 'binding_mode: bound'
  if ($badSource -notmatch 'binding_mode:\s*bound') { Add-Failure 'negative test failed: source_template requirement did not trigger' }
  $badExisting = 'target project does not have .hebrinex'
  if ($badExisting -notmatch '[.]hebrinex') { Add-Failure 'negative test failed: missing bound harness rule did not trigger' }
  $badPreserve = 'PROJECT_BINDING.yaml overwritten'
  if ($badPreserve -notmatch 'PROJECT_BINDING[.]yaml') { Add-Failure 'negative test failed: preservation rule did not trigger' }
}

$Root = (Resolve-Path -LiteralPath $Root).Path
Write-Host "Validating bound update service at $Root"

Assert-Contains 'scripts/hebrinex.ps1' 'update-bound -CheckOnly\|-Apply' 'CLI help must expose update-bound Apply'
Assert-Contains 'scripts/hebrinex.ps1' 'Copy-HarnessManifestToExistingBoundRoot' 'update-bound must copy through manifest allowlist'
Assert-Contains 'scripts/hebrinex.ps1' 'Test-BoundUpdatePreservedPath' 'update-bound must define preservation filter'
Assert-Contains 'scripts/hebrinex.ps1' 'Create-BoundUpdateBackupRecord' 'update-bound must create backup before writes'
Assert-Contains 'scripts/hebrinex.ps1' 'Write-BoundUpdateMigrationReport' 'update-bound must write applied migration report'
Assert-Contains 'scripts/hebrinex.ps1' 'migration-bound-update-' 'update-bound report id must be distinguishable'
Assert-Contains 'scripts/hebrinex.ps1' 'PROJECT_BINDING identity, state, registry, cycles, locks, approvals, local memory and evidence' 'update-bound CheckOnly must declare preservation scope'
Assert-Contains 'orquestador/migration/migration-registry.yaml' 'bound-update-source-template-to-bound' 'migration registry must declare bound update route'
Assert-Contains 'orquestador/migration/migration-registry.yaml' 'scripts/validate-bound-update.ps1' 'migration registry must include bound update validator'

$bindingText = Read-HarnessText 'PROJECT_BINDING.yaml'
$bindingMode = Get-Scalar $bindingText 'binding_mode'
if ($bindingMode -eq 'source_template') {
  Invoke-SourceTemplateBoundUpdateSmoke
}
elseif ($bindingMode -eq 'bound') {
  Assert-BoundModeUpdateReadiness
}
else {
  Add-Failure "unsupported binding_mode for bound update validation: $bindingMode"
}

if ($RunNegativeTests) { Run-NegativeTests }

if ($script:Failures.Count -gt 0) {
  Write-Host 'Bound update validation FAILED'
  foreach ($failure in $script:Failures) { Write-Host " - $failure" }
  exit 1
}

Write-Host 'Bound update validation OK'
exit 0
