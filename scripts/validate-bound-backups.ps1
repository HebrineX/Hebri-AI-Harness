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

function Get-LatestBoundUpdateBackupId([string]$HarnessRoot) {
  $backups = Join-Path $HarnessRoot 'orquestador/migration/backups'
  $latest = Get-ChildItem -LiteralPath $backups -Directory -Filter 'migration-bound-update-*' |
    Where-Object { $_.Name -ne 'migration-bound-update-invalid-0109' } |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1
  if ($null -eq $latest) { return '' }
  return $latest.Name
}

function Add-InvalidBackupFixture([string]$HarnessRoot) {
  $badRoot = Join-Path $HarnessRoot 'orquestador/migration/backups/migration-bound-update-invalid-0109'
  $filesRoot = Join-Path $badRoot 'files'
  New-Item -ItemType Directory -Force -Path $filesRoot | Out-Null
  Write-Utf8Text (Join-Path $badRoot 'backup-manifest.txt') "..\outside.txt|1|2026-07-01T00:00:00.0000000Z|invalid_fixture`n"
  return 'migration-bound-update-invalid-0109'
}

function Assert-InventoryOutput([string]$OutputText, [string]$ValidBackupId, [string]$InvalidBackupId) {
  Assert-TextContains $OutputText 'Hebri-AI-Harness list-bound-backups CheckOnly' 'list-bound-backups must identify CheckOnly mode'
  Assert-TextContains $OutputText 'writes=false' 'list-bound-backups must be read-only'
  Assert-TextContains $OutputText 'backup_inventory_available=true' 'list-bound-backups must expose inventory availability'
  Assert-TextContains $OutputText 'inventory_status=ok' 'list-bound-backups must finish with OK status'
  Assert-TextContains $OutputText 'backup_count=[1-9][0-9]*' 'list-bound-backups must report backup_count'
  Assert-TextContains $OutputText 'restorable_count=[1-9][0-9]*' 'list-bound-backups must report at least one restorable backup in smoke'
  Assert-TextContains $OutputText ([regex]::Escape("backup_id=$ValidBackupId")) 'list-bound-backups must include the valid update backup id'
  Assert-TextContains $OutputText (('(?s)' + [regex]::Escape("backup_id=$ValidBackupId")) + '.*?backup_origin=update-bound.*?backup_status=ok.*?backup_restorable=true') 'valid update backup must be restorable'
  Assert-TextContains $OutputText (('(?s)' + [regex]::Escape("backup_id=$InvalidBackupId")) + '.*?backup_status=not_restorable.*?backup_restorable=false.*?unsafe_path') 'invalid backup fixture must be listed as not restorable'
  Assert-TextContains $OutputText 'backup_manifest=' 'list-bound-backups must show manifest path'
  Assert-TextContains $OutputText 'backup_files_root=' 'list-bound-backups must show files root'
  Assert-TextContains $OutputText 'backup_manifest_entries=' 'list-bound-backups must show manifest entry count'
  Assert-TextContains $OutputText 'backup_restorable_files=' 'list-bound-backups must show restorable file count'
  Assert-TextContains $OutputText 'backup_captured_version=0[.][0-9]+[.][0-9]+' 'list-bound-backups must show captured harness version when present'
}

function Invoke-SourceTemplateBoundBackupInventorySmoke() {
  $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('hebrinex-bound-backups-test-' + [guid]::NewGuid().ToString('N'))
  $projectRoot = Join-Path $tempRoot 'consumer-project'
  New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
  Write-Utf8Text (Join-Path $projectRoot 'README.md') "temporary consumer project`n"
  try {
    $cli = Resolve-HarnessPath 'scripts/hebrinex.ps1'

    $global:LASTEXITCODE = 0
    $bootstrap = & $cli bootstrap -Root $Root -Apply -ProjectRoot $projectRoot *>&1
    if ((Get-LastExitCodeValue) -ne 0) { Add-Failure "bootstrap precondition failed for backup inventory smoke: $($bootstrap -join ' ')" }

    $boundRoot = Join-Path $projectRoot '.hebrinex'

    $global:LASTEXITCODE = 0
    $update = & $cli update-bound -Root $Root -Apply -ProjectRoot $projectRoot *>&1
    if ((Get-LastExitCodeValue) -ne 0) { Add-Failure "update-bound precondition failed for backup inventory smoke: $($update -join ' ')" }

    $validBackupId = Get-LatestBoundUpdateBackupId $boundRoot
    if ([string]::IsNullOrWhiteSpace($validBackupId)) { Add-Failure 'backup inventory smoke could not find update-bound backup id' }
    $invalidBackupId = Add-InvalidBackupFixture $boundRoot

    Write-Utf8Text (Join-Path $boundRoot 'orquestador/context/product.md') "backup_inventory_marker_0109`n"

    $global:LASTEXITCODE = 0
    $inventory = & $cli list-bound-backups -Root $Root -CheckOnly -ProjectRoot $projectRoot *>&1
    if ((Get-LastExitCodeValue) -ne 0) { Add-Failure "list-bound-backups CheckOnly failed: $($inventory -join ' ')" }
    Assert-InventoryOutput ($inventory -join "`n") $validBackupId $invalidBackupId

    $markerPath = Join-Path $boundRoot 'orquestador/context/product.md'
    if ([IO.File]::ReadAllText($markerPath) -notmatch 'backup_inventory_marker_0109') {
      Add-Failure 'list-bound-backups must not mutate bound files'
    }
  }
  finally {
    Remove-TempTree $tempRoot
  }
}

function Assert-BoundModeBackupInventoryReadiness() {
  $binding = Read-HarnessText 'PROJECT_BINDING.yaml'
  if ((Get-Scalar $binding 'binding_mode') -ne 'bound') { Add-Failure 'bound backup readiness called on non-bound harness' }
  Assert-PathMissing (Resolve-HarnessPath '.git') 'bound harness must not contain .git'
  Assert-PathMissing (Resolve-HarnessPath '.codex') 'bound harness must not contain .codex'
  Assert-PathMissing (Resolve-HarnessPath 'infoHebri.md') 'bound harness must not contain infoHebri.md'
}

function Run-NegativeTests() {
  $badTraversal = '..\outside'
  if ($badTraversal -notmatch '[.][.]') { Add-Failure 'negative test failed: backup traversal rule did not trigger' }
  $badSeparator = 'backup/name'
  if ($badSeparator -notmatch '[\\/]') { Add-Failure 'negative test failed: backup separator rule did not trigger' }
  $badExcluded = 'infoHebri.md'
  if ($badExcluded -notmatch 'infoHebri[.]md') { Add-Failure 'negative test failed: excluded backup path rule did not trigger' }
  $badApply = 'list-bound-backups -Apply'
  if ($badApply -notmatch '-Apply') { Add-Failure 'negative test failed: apply mode rule did not trigger' }
}

$Root = (Resolve-Path -LiteralPath $Root).Path
Write-Host "Validating bound backup inventory at $Root"

Assert-Contains 'scripts/hebrinex.ps1' 'list-bound-backups -CheckOnly' 'CLI help must expose list-bound-backups CheckOnly'
Assert-Contains 'scripts/hebrinex.ps1' 'Get-BoundBackupInventoryItem' 'list-bound-backups must inspect each backup'
Assert-Contains 'scripts/hebrinex.ps1' 'Get-BoundBackupInventory' 'list-bound-backups must build backup inventory'
Assert-Contains 'scripts/hebrinex.ps1' 'Write-BoundBackupInventoryCheckOnly' 'list-bound-backups must expose CheckOnly output'
Assert-Contains 'scripts/hebrinex.ps1' 'backup_inventory_available=true' 'list-bound-backups must expose availability marker'
Assert-Contains 'scripts/hebrinex.ps1' 'backup_restorable=' 'list-bound-backups must expose restorable marker'
Assert-Contains 'scripts/hebrinex.ps1' 'source_outside_files_root' 'list-bound-backups must block source path escape'
Assert-Contains 'scripts/hebrinex.ps1' 'unsafe_path' 'list-bound-backups must flag unsafe manifest paths'
Assert-Contains 'orquestador/migration/migration-registry.yaml' 'bound-backup-inventory' 'migration registry must declare bound backup inventory route'
Assert-Contains 'orquestador/migration/migration-registry.yaml' 'scripts/validate-bound-backups.ps1' 'migration registry must include bound backup validator'

$bindingText = Read-HarnessText 'PROJECT_BINDING.yaml'
$bindingMode = Get-Scalar $bindingText 'binding_mode'
if ($bindingMode -eq 'source_template') {
  Invoke-SourceTemplateBoundBackupInventorySmoke
}
elseif ($bindingMode -eq 'bound') {
  Assert-BoundModeBackupInventoryReadiness
}
else {
  Add-Failure "unsupported binding_mode for backup inventory validation: $bindingMode"
}

if ($RunNegativeTests) { Run-NegativeTests }

if ($script:Failures.Count -gt 0) {
  Write-Host 'Bound backup inventory validation FAILED'
  foreach ($failure in $script:Failures) { Write-Host " - $failure" }
  exit 1
}

Write-Host 'Bound backup inventory validation OK'
exit 0
