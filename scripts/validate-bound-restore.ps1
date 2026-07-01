param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$RunNegativeTests
)

$ErrorActionPreference = 'Stop'
$script:Failures = New-Object System.Collections.Generic.List[string]

function Add-Failure([string]$Message) {
  $script:Failures.Add($Message) | Out-Null
}

function Resolve-HarnessPath([string]$RelativePath) {
  Join-Path $Root $RelativePath
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

function Get-LatestBackupId([string]$HarnessRoot) {
  $backups = Join-Path $HarnessRoot 'orquestador/migration/backups'
  $latest = Get-ChildItem -LiteralPath $backups -Directory -Filter 'migration-bound-update-*' |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1
  if ($null -eq $latest) { return '' }
  return $latest.Name
}

function Assert-RestoreShape([string]$HarnessRoot, [string]$ProjectRoot, [string]$BackupId) {
  $markerPath = Join-Path $HarnessRoot 'orquestador/context/product.md'
  if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
    Add-Failure 'restore-bound target marker file missing after restore'
  }
  elseif ([IO.File]::ReadAllText($markerPath) -notmatch 'restore_marker_0108') {
    Add-Failure 'restore-bound did not restore manifest-backed file content'
  }

  $bindingPath = Join-Path $HarnessRoot 'PROJECT_BINDING.yaml'
  if (-not (Test-Path -LiteralPath $bindingPath -PathType Leaf)) { Add-Failure 'restore-bound removed PROJECT_BINDING.yaml' }
  else {
    $binding = [IO.File]::ReadAllText($bindingPath)
    if ((Get-Scalar $binding 'binding_mode') -ne 'bound') { Add-Failure 'restore-bound must keep binding_mode bound' }
    $boundProjectRoot = Get-Scalar $binding 'project_root'
    if (([IO.Path]::GetFullPath($boundProjectRoot).TrimEnd('\','/')) -ne ([IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\','/'))) {
      Add-Failure "restore-bound project_root mismatch: $boundProjectRoot"
    }
  }

  Assert-PathMissing (Join-Path $HarnessRoot '.git') 'restore-bound must not restore .git'
  Assert-PathMissing (Join-Path $HarnessRoot '.codex') 'restore-bound must not restore .codex'
  Assert-PathMissing (Join-Path $HarnessRoot 'infoHebri.md') 'restore-bound must not restore infoHebri.md'

  $reportsDir = Join-Path $HarnessRoot 'orquestador/migration/reports'
  $reports = @()
  if (Test-Path -LiteralPath $reportsDir -PathType Container) {
    $reports = @(Get-ChildItem -LiteralPath $reportsDir -File -Filter 'migration-bound-restore-*.yaml' | Sort-Object LastWriteTimeUtc -Descending)
  }
  if ($reports.Count -eq 0) {
    Add-Failure 'restore-bound must write migration-bound-restore report'
    return
  }
  $reportText = [IO.File]::ReadAllText($reports[0].FullName)
  Assert-TextContains $reportText 'template:\s*false' 'restore report must not be template'
  Assert-TextContains $reportText 'mode:\s*"Apply"' 'restore report must record Apply mode'
  Assert-TextContains $reportText 'status:\s*applied' 'restore report must set status applied'
  Assert-TextContains $reportText 'created:\s*true' 'restore report must confirm pre-restore backup creation'
  Assert-TextContains $reportText ([regex]::Escape("source_backup_id: '$BackupId'")) 'restore report must reference selected BackupId'
  Assert-TextContains $reportText 'deletes_extra_files:\s*false' 'restore report must declare non-destructive restore'
  Assert-TextContains $reportText 'validate_agent_contracts:\s*ok' 'restore report must include agent validator OK'
  Assert-TextContains $reportText 'validate_security_policy:\s*ok' 'restore report must include security validator OK'
  Assert-TextContains $reportText 'validate_migration:\s*ok' 'restore report must include migration validator OK'
  Assert-TextContains $reportText 'validate_harness:\s*ok' 'restore report must include harness validator OK'

  $backupPath = Get-Scalar $reportText 'path'
  $manifestPath = Get-Scalar $reportText 'manifest_or_checksum'
  if ([string]::IsNullOrWhiteSpace($backupPath) -or -not (Test-Path -LiteralPath $backupPath -PathType Container)) {
    Add-Failure "restore pre-backup path missing or invalid: $backupPath"
  }
  if ([string]::IsNullOrWhiteSpace($manifestPath) -or -not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    Add-Failure "restore pre-backup manifest missing or invalid: $manifestPath"
  }
}

function Invoke-SourceTemplateBoundRestoreSmoke() {
  $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('hebrinex-bound-restore-test-' + [guid]::NewGuid().ToString('N'))
  $projectRoot = Join-Path $tempRoot 'consumer-project'
  New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
  Write-Utf8Text (Join-Path $projectRoot 'README.md') "temporary consumer project`n"
  try {
    $cli = Resolve-HarnessPath 'scripts/hebrinex.ps1'

    $global:LASTEXITCODE = 0
    $bootstrap = & $cli bootstrap -Root $Root -Apply -ProjectRoot $projectRoot *>&1
    if ((Get-LastExitCodeValue) -ne 0) { Add-Failure "bootstrap precondition failed for restore smoke: $($bootstrap -join ' ')" }

    $boundRoot = Join-Path $projectRoot '.hebrinex'
    $markerPath = Join-Path $boundRoot 'orquestador/context/product.md'
    Write-Utf8Text $markerPath "restore_marker_0108 original product context`n"

    $global:LASTEXITCODE = 0
    $update = & $cli update-bound -Root $Root -Apply -ProjectRoot $projectRoot *>&1
    if ((Get-LastExitCodeValue) -ne 0) { Add-Failure "update-bound precondition failed for restore smoke: $($update -join ' ')" }
    $backupId = Get-LatestBackupId $boundRoot
    if ([string]::IsNullOrWhiteSpace($backupId)) { Add-Failure 'restore smoke could not find update-bound backup id' }

    $global:LASTEXITCODE = 0
    $checkOnly = & $cli restore-bound -Root $Root -CheckOnly -ProjectRoot $projectRoot -BackupId $backupId *>&1
    if ((Get-LastExitCodeValue) -ne 0) { Add-Failure "restore-bound CheckOnly failed: $($checkOnly -join ' ')" }
    $checkOnlyText = $checkOnly -join "`n"
    if ($checkOnlyText -notmatch 'writes=false' -or $checkOnlyText -notmatch 'restore_available=true') {
      Add-Failure 'restore-bound CheckOnly must report writes=false and restore_available=true'
    }
    if ($checkOnlyText -notmatch 'requires_backup_id=true') { Add-Failure 'restore-bound CheckOnly must require BackupId' }

    $global:LASTEXITCODE = 0
    $restore = & $cli restore-bound -Root $Root -Apply -ProjectRoot $projectRoot -BackupId $backupId *>&1
    if ((Get-LastExitCodeValue) -ne 0) { Add-Failure "restore-bound Apply failed: $($restore -join ' ')" }
    $restoreText = $restore -join "`n"
    if ($restoreText -notmatch 'restore_status=applied') { Add-Failure 'restore-bound Apply must report restore_status=applied' }

    Assert-RestoreShape $boundRoot $projectRoot $backupId

    $boundValidator = Join-Path $boundRoot 'scripts/validate-harness.ps1'
    if (Test-Path -LiteralPath $boundValidator -PathType Leaf) {
      $global:LASTEXITCODE = 0
      & $boundValidator -Root $boundRoot -RunNegativeTests *> $null
      if ((Get-LastExitCodeValue) -ne 0) { Add-Failure "restored bound harness validate-harness failed: $(Get-LastExitCodeValue)" }
    }
    else { Add-Failure 'restored bound harness missing validate-harness.ps1' }
  }
  finally {
    Remove-TempTree $tempRoot
  }
}

function Assert-BoundModeRestoreReadiness() {
  $binding = Read-HarnessText 'PROJECT_BINDING.yaml'
  if ((Get-Scalar $binding 'binding_mode') -ne 'bound') { Add-Failure 'bound restore readiness called on non-bound harness' }
  Assert-PathMissing (Resolve-HarnessPath '.git') 'bound harness must not contain .git'
  Assert-PathMissing (Resolve-HarnessPath '.codex') 'bound harness must not contain .codex'
  Assert-PathMissing (Resolve-HarnessPath 'infoHebri.md') 'bound harness must not contain infoHebri.md'
}

function Run-NegativeTests() {
  $badTraversal = '..\outside'
  if ($badTraversal -notmatch '[.][.]') { Add-Failure 'negative test failed: BackupId traversal rule did not trigger' }
  $badSeparator = 'backup/name'
  if ($badSeparator -notmatch '[\\/]') { Add-Failure 'negative test failed: BackupId separator rule did not trigger' }
  $badExcluded = 'infoHebri.md'
  if ($badExcluded -notmatch 'infoHebri[.]md') { Add-Failure 'negative test failed: excluded restore rule did not trigger' }
}

$Root = (Resolve-Path -LiteralPath $Root).Path
Write-Host "Validating bound restore service at $Root"

Assert-Contains 'scripts/hebrinex.ps1' 'restore-bound -CheckOnly\|-Apply' 'CLI help must expose restore-bound Apply'
Assert-Contains 'scripts/hebrinex.ps1' 'Resolve-BoundRestoreBackup' 'restore-bound must validate backup containment'
Assert-Contains 'scripts/hebrinex.ps1' 'Restore-BoundBackupFiles' 'restore-bound must restore from backup files'
Assert-Contains 'scripts/hebrinex.ps1' 'Write-BoundRestoreMigrationReport' 'restore-bound must write applied restore report'
Assert-Contains 'scripts/hebrinex.ps1' 'migration-bound-restore-' 'restore-bound report id must be distinguishable'
Assert-Contains 'scripts/hebrinex.ps1' 'deletes_extra_files: false' 'restore-bound must declare non-destructive restore'
Assert-Contains 'scripts/hebrinex.ps1' 'BackupId resolved outside migration backups' 'restore-bound must block backup path escape'
Assert-Contains 'scripts/hebrinex.ps1' 'restore manifest contains unsafe path' 'restore-bound must block manifest traversal'
Assert-Contains 'orquestador/migration/migration-registry.yaml' 'bound-restore-from-backup' 'migration registry must declare bound restore route'
Assert-Contains 'orquestador/migration/migration-registry.yaml' 'scripts/validate-bound-restore.ps1' 'migration registry must include bound restore validator'

$bindingText = Read-HarnessText 'PROJECT_BINDING.yaml'
$bindingMode = Get-Scalar $bindingText 'binding_mode'
if ($bindingMode -eq 'source_template') {
  Invoke-SourceTemplateBoundRestoreSmoke
}
elseif ($bindingMode -eq 'bound') {
  Assert-BoundModeRestoreReadiness
}
else {
  Add-Failure "unsupported binding_mode for bound restore validation: $bindingMode"
}

if ($RunNegativeTests) { Run-NegativeTests }

if ($script:Failures.Count -gt 0) {
  Write-Host 'Bound restore validation FAILED'
  foreach ($failure in $script:Failures) { Write-Host " - $failure" }
  exit 1
}

Write-Host 'Bound restore validation OK'
exit 0
