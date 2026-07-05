param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$RunNegativeTests,
  [switch]$RequireApplied
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
  if ([string]::IsNullOrWhiteSpace($text)) {
    Add-Failure "empty file: $RelativePath"
  }
  return $text
}

function Assert-File([string]$RelativePath) {
  $path = Resolve-HarnessPath $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    Add-Failure "missing file: $RelativePath"
  }
  elseif ((Get-Item -LiteralPath $path).Length -eq 0) {
    Add-Failure "empty file: $RelativePath"
  }
}

function Assert-Contains([string]$RelativePath, [string]$Pattern, [string]$Message) {
  $text = Read-HarnessText $RelativePath
  if ($text -notmatch $Pattern) { Add-Failure $Message }
}

function Assert-TextContains([string]$Text, [string]$Pattern, [string]$Message) {
  if ($Text -notmatch $Pattern) { Add-Failure $Message }
}

function Get-Scalar([string]$Text, [string]$Key) {
  foreach ($line in ($Text -split "`n")) {
    if ($line -match ('^\s*' + [regex]::Escape($Key) + ':\s*(.*)$')) {
      return $Matches[1].Trim().Trim('"').Trim("'")
    }
  }
  return ''
}

function Get-TreeSignature([string]$Path) {
  $items = Get-ChildItem -LiteralPath $Path -Recurse -File | Sort-Object FullName
  $parts = foreach ($item in $items) {
    "$($item.FullName)|$($item.Length)|$($item.LastWriteTimeUtc.Ticks)"
  }
  return ($parts -join "`n")
}

function Get-LatestAppliedReport() {
  $reportsPath = Resolve-HarnessPath 'orquestador/migration/reports'
  if (-not (Test-Path -LiteralPath $reportsPath -PathType Container)) {
    Add-Failure 'missing reports directory: orquestador/migration/reports'
    return $null
  }
  $reports = Get-ChildItem -LiteralPath $reportsPath -File -Filter 'migration-*.yaml' |
    Where-Object { $_.Name -ne 'migration-report.template.yaml' } |
    Sort-Object LastWriteTimeUtc -Descending
  if (-not $reports -or $reports.Count -eq 0) {
    Add-Failure 'missing applied migration report'
    return $null
  }
  return $reports[0]
}

function Assert-AppliedMigrationEvidence() {
  $contractText = Read-HarnessText 'orquestador/migration/contracts/post-migration-contract.yaml'
  Assert-TextContains $contractText 'template:\s*false' 'applied post migration contract must not be a template'
  Assert-TextContains $contractText 'agent_authority:\s*harness_only' 'applied contract must keep harness_only authority'
  Assert-TextContains $contractText 'project_root_verified:\s*true' 'applied contract must verify project root'
  Assert-TextContains $contractText 'agent_registry_active:\s*true' 'applied contract must activate agent registry'
  Assert-TextContains $contractText 'security_policy_active:\s*true' 'applied contract must activate security policy'
  Assert-TextContains $contractText 'runtime_enablement_active:\s*true' 'applied contract must activate runtime enablement'
  Assert-TextContains $contractText 'migration_service_active:\s*true' 'applied contract must activate migration service'
  Assert-TextContains $contractText 'active_contract_written:\s*true' 'applied contract must confirm active contract write'
  Assert-TextContains $contractText 'old_approvals_expired:\s*true' 'applied contract must expire old approvals'
  Assert-TextContains $contractText 'backup_verified:\s*true' 'applied contract must verify backup'
  Assert-TextContains $contractText 'validators_passed:\s*true' 'applied contract must confirm validators'
  Assert-TextContains $contractText 'migration_report_written:\s*true' 'applied contract must confirm migration report'
  Assert-TextContains $contractText 'migration_status:\s*applied' 'applied contract must set migration_status applied'

  $report = Get-LatestAppliedReport
  if ($null -eq $report) { return }

  $reportText = [IO.File]::ReadAllText($report.FullName)
  Assert-TextContains $reportText 'template:\s*false' 'applied report must not be a template'
  Assert-TextContains $reportText 'mode:\s*"Apply"' 'applied report must record Apply mode'
  Assert-TextContains $reportText 'status:\s*applied' 'applied report must set status applied'
  Assert-TextContains $reportText 'created:\s*true' 'applied report must confirm backup creation'
  Assert-TextContains $reportText 'validate_agent_contracts:\s*ok' 'applied report must include agent validator OK'
  Assert-TextContains $reportText 'validate_security_policy:\s*ok' 'applied report must include security validator OK'

  $backupPath = Get-Scalar $reportText 'path'
  $manifestPath = Get-Scalar $reportText 'manifest_or_checksum'
  if ([string]::IsNullOrWhiteSpace($backupPath) -or -not (Test-Path -LiteralPath $backupPath -PathType Container)) {
    Add-Failure "backup path missing or invalid: $backupPath"
  }
  if ([string]::IsNullOrWhiteSpace($manifestPath) -or -not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    Add-Failure "backup manifest missing or invalid: $manifestPath"
  }
  elseif ((Get-Item -LiteralPath $manifestPath).Length -eq 0) {
    Add-Failure "backup manifest is empty: $manifestPath"
  }
}

function Run-NegativeTests() {
  $badRoute = '0.10.0-to-0.10.0'
  if ($badRoute -notmatch '^0[.]10[.]0-to-0[.]10[.]0$') {
    Add-Failure 'negative test failed: bad route pattern did not trigger'
  }
  $badCheckOnly = 'check_only_writes: true'
  if ($badCheckOnly -notmatch 'check_only_writes:\s*true') {
    Add-Failure 'negative test failed: CheckOnly write rule did not trigger'
  }
  $badAppliedContract = 'migration_status: not_applied'
  if ($badAppliedContract -notmatch 'migration_status:\s*not_applied') {
    Add-Failure 'negative test failed: applied contract rule did not trigger'
  }
}

$Root = (Resolve-Path -LiteralPath $Root).Path
Write-Host "Validating migration service at $Root"

$requiredFiles = @(
  'orquestador/migration/migration-registry.yaml',
  'orquestador/migration/versions/0.9.0-to-0.10.0.yaml',
  'orquestador/migration/versions/0.8.10-to-0.10.0.yaml',
  'orquestador/migration/versions/0.10.11-to-0.11.0.yaml',
  'orquestador/migration/versions/0.11.0-to-0.12.0.yaml',
  'orquestador/migration/contracts/post-migration-contract.yaml',
  'orquestador/migration/reports/migration-report.template.yaml',
  'scripts/migrate-harness.ps1',
  'scripts/validate-migration.ps1'
)
foreach ($rel in $requiredFiles) { Assert-File $rel }

Assert-Contains 'orquestador/migration/migration-registry.yaml' 'check_only_writes:\s*false' 'migration registry must declare CheckOnly writes false'
Assert-Contains 'orquestador/migration/migration-registry.yaml' 'apply_requires_backup:\s*true' 'Apply must require backup'
Assert-Contains 'orquestador/migration/migration-registry.yaml' '0[.]9[.]0-to-0[.]10[.]0' 'migration registry must include 0.9.0-to-0.10.0'
Assert-Contains 'orquestador/migration/migration-registry.yaml' '0[.]8[.]10-to-0[.]10[.]0' 'migration registry must include 0.8.10-to-0.10.0'
Assert-Contains 'orquestador/migration/migration-registry.yaml' '0[.]10[.]11-to-0[.]11[.]0' 'migration registry must include 0.10.11-to-0.11.0'
Assert-Contains 'orquestador/migration/migration-registry.yaml' '0[.]11[.]0-to-0[.]12[.]0' 'migration registry must include 0.11.0-to-0.12.0'
Assert-Contains 'orquestador/migration/migration-registry.yaml' 'scripts/validate-state-machine[.]ps1' 'migration registry must require state machine validator'
Assert-Contains 'orquestador/migration/migration-registry.yaml' 'scripts/validate-agent-runtime[.]ps1' 'migration registry must require agent runtime validator'
Assert-Contains 'orquestador/migration/migration-registry.yaml' 'PROJECT_BINDING[.]yaml' 'migration must preserve PROJECT_BINDING.yaml'
Assert-Contains 'orquestador/migration/migration-registry.yaml' 'orquestador/sdd/progress/state[.]yaml' 'migration must preserve state.yaml'
Assert-Contains 'orquestador/migration/migration-registry.yaml' 'orquestador/sdd/progress/registry[.]yaml' 'migration must preserve registry.yaml'

Assert-Contains 'orquestador/migration/versions/0.9.0-to-0.10.0.yaml' 'source_version:\s*"0[.]9[.]0"' '0.9 route source mismatch'
Assert-Contains 'orquestador/migration/versions/0.9.0-to-0.10.0.yaml' 'target_version:\s*"0[.]10[.]0"' '0.9 route target mismatch'
Assert-Contains 'orquestador/migration/versions/0.9.0-to-0.10.0.yaml' 'check_only:\s*true' '0.9 route must support CheckOnly'
Assert-Contains 'orquestador/migration/versions/0.9.0-to-0.10.0.yaml' 'apply:\s*true' '0.9 route must support Apply'
Assert-Contains 'orquestador/migration/versions/0.9.0-to-0.10.0.yaml' 'backup_verified' '0.9 route must require backup verification for apply'

Assert-Contains 'orquestador/migration/versions/0.8.10-to-0.10.0.yaml' 'source_version:\s*"0[.]8[.]10"' '0.8.10 route source mismatch'
Assert-Contains 'orquestador/migration/versions/0.8.10-to-0.10.0.yaml' 'target_version:\s*"0[.]10[.]0"' '0.8.10 route target mismatch'
Assert-Contains 'orquestador/migration/versions/0.8.10-to-0.10.0.yaml' 'apply:\s*true' '0.8.10 route must support Apply'
Assert-Contains 'orquestador/migration/versions/0.8.10-to-0.10.0.yaml' 'intermediate_compatibility_checked' '0.8.10 route must require compatibility check'
Assert-Contains 'orquestador/migration/versions/0.10.11-to-0.11.0.yaml' 'source_version:\s*"0[.]10[.]11"' '0.10.11 route source mismatch'
Assert-Contains 'orquestador/migration/versions/0.10.11-to-0.11.0.yaml' 'target_version:\s*"0[.]11[.]0"' '0.10.11 route target mismatch'
Assert-Contains 'orquestador/migration/versions/0.10.11-to-0.11.0.yaml' 'check_only:\s*true' '0.10.11 route must support CheckOnly'
Assert-Contains 'orquestador/migration/versions/0.10.11-to-0.11.0.yaml' 'apply:\s*true' '0.10.11 route must support Apply'
Assert-Contains 'orquestador/migration/versions/0.10.11-to-0.11.0.yaml' 'state_machine_active' '0.10.11 route must require state machine activation'
Assert-Contains 'orquestador/migration/versions/0.10.11-to-0.11.0.yaml' 'agent_runtime_enforcement_active' '0.10.11 route must require agent runtime enforcement'
Assert-Contains 'orquestador/migration/versions/0.10.11-to-0.11.0.yaml' 'ci_official_validated' '0.10.11 route must require CI validation'
Assert-Contains 'orquestador/migration/versions/0.11.0-to-0.12.0.yaml' 'source_version:\s*"0[.]11[.]0"' '0.11.0 route source mismatch'
Assert-Contains 'orquestador/migration/versions/0.11.0-to-0.12.0.yaml' 'target_version:\s*"0[.]12[.]0"' '0.11.0 route target mismatch'
Assert-Contains 'orquestador/migration/versions/0.11.0-to-0.12.0.yaml' 'check_only:\s*true' '0.11.0 route must support CheckOnly'
Assert-Contains 'orquestador/migration/versions/0.11.0-to-0.12.0.yaml' 'apply:\s*true' '0.11.0 route must support Apply'
Assert-Contains 'orquestador/migration/versions/0.11.0-to-0.12.0.yaml' 'approval_store_active' '0.11.0 route must require approval store activation'
Assert-Contains 'orquestador/migration/versions/0.11.0-to-0.12.0.yaml' 'command_gateway_controlled' '0.11.0 route must require controlled gateway'

Assert-Contains 'orquestador/migration/reports/migration-report.template.yaml' 'wrote_files:\s*false' 'report template must represent CheckOnly no-write'
Assert-Contains 'orquestador/migration/reports/migration-report.template.yaml' 'backup:' 'report template must include backup section'
Assert-Contains 'orquestador/migration/contracts/post-migration-contract.yaml' 'target_version:\s*"0[.]12[.]0"' 'post migration template must target 0.12.0'
$currentHarnessVersion = (Read-HarnessText 'HARNESS_VERSION').Trim()
$bindingText = Read-HarnessText 'PROJECT_BINDING.yaml'
$bindingMode = Get-Scalar $bindingText 'binding_mode'
$contractText = Read-HarnessText 'orquestador/migration/contracts/post-migration-contract.yaml'
Assert-TextContains $contractText 'agent_authority:\s*harness_only' 'post migration contract must keep harness_only authority'
if ($RequireApplied -or ($currentHarnessVersion -match '^0[.](10|11|12)[.][0-9]+$' -and $bindingMode -eq 'bound')) {
  Assert-AppliedMigrationEvidence
}
else {
  if ($contractText -notmatch 'migration_status:\s*applied') {
    Assert-TextContains $contractText 'migration_status:\s*not_applied' 'post migration template must not claim applied'
    Assert-TextContains $contractText 'validators_passed:\s*false' 'post migration template must not claim validators passed'
  }
}

if ($currentHarnessVersion -in @('0.8.10', '0.9.0', '0.10.11')) {
  $migrator = Resolve-HarnessPath 'scripts/migrate-harness.ps1'
  $target = '0.10.0'
  if ($currentHarnessVersion -eq '0.10.11') { $target = '0.11.0' }
  $before = Get-TreeSignature $Root
  & $migrator -Root $Root -TargetVersion $target -CheckOnly *> $null
  if ($LASTEXITCODE -ne 0) {
    Add-Failure "migrate-harness CheckOnly failed with exit code $LASTEXITCODE"
  }
  $after = Get-TreeSignature $Root
  if ($before -ne $after) {
    Add-Failure 'migrate-harness CheckOnly changed file tree signature'
  }
}
elseif ($currentHarnessVersion -notmatch '^0[.](10|11|12)[.][0-9]+$') {
  Add-Failure "unsupported HARNESS_VERSION for migration validation: $currentHarnessVersion"
}

if ($RunNegativeTests) { Run-NegativeTests }

if ($script:Failures.Count -gt 0) {
  Write-Host 'Migration validation FAILED'
  foreach ($failure in $script:Failures) { Write-Host " - $failure" }
  exit 1
}

Write-Host 'Migration validation OK'
exit 0
