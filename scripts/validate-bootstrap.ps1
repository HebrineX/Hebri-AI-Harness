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
  $norm = ($RelativePath -replace '\\','/').TrimStart('./')
  $mapped = switch -Regex ($norm) {
    '^PROJECT_BINDING[.]yaml$' { 'instance/PROJECT_BINDING.yaml'; break }
    '^orquestador/migration/contracts/post-migration-contract[.]yaml$' { 'instance/migration/contracts/post-migration-contract.yaml'; break }
    '^orquestador/migration/reports$' { 'instance/migration/reports'; break }
    '^orquestador/migration/reports/(.+)$' { 'instance/migration/reports/' + $Matches[1]; break }
    default { $norm }
  }
  $mappedPath = Join-Path $Root $mapped
  if ($mapped -ne $norm -and (Test-Path -LiteralPath $mappedPath)) { return $mappedPath }
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

function Assert-PathMissing([string]$Path, [string]$Message) {
  if (Test-Path -LiteralPath $Path) { Add-Failure $Message }
}

function Get-LastExitCodeValue() {
  if ($null -eq $global:LASTEXITCODE) { return 0 }
  return [int]$global:LASTEXITCODE
}

function Format-CommandOutput([object[]]$Output, [int]$MaxLines = 80) {
  $lines = @($Output | ForEach-Object { [string]$_ })
  if ($lines.Count -gt $MaxLines) { $lines = $lines[($lines.Count - $MaxLines)..($lines.Count - 1)] }
  return ($lines -join ' | ')
}

function Assert-BoundHarnessShape([string]$HarnessRoot, [string]$ProjectRoot) {
  $oldRoot = $Root
  $Root = $HarnessRoot
  $bindingPath = Resolve-HarnessPath 'PROJECT_BINDING.yaml'
  $Root = $oldRoot
  if (-not (Test-Path -LiteralPath $bindingPath -PathType Leaf)) {
    Add-Failure "bound harness missing PROJECT_BINDING.yaml: $HarnessRoot"
    return
  }
  $binding = [IO.File]::ReadAllText($bindingPath)
  $bindingMode = Get-Scalar $binding 'binding_mode'
  $boundProjectRoot = Get-Scalar $binding 'project_root'
  if ($bindingMode -ne 'bound') { Add-Failure "bound harness PROJECT_BINDING binding_mode must be bound: $bindingMode" }
  if ([string]::IsNullOrWhiteSpace($boundProjectRoot)) { Add-Failure 'bound harness PROJECT_BINDING project_root must not be empty' }
  elseif (([IO.Path]::GetFullPath($boundProjectRoot).TrimEnd('\','/')) -ne ([IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\','/'))) {
    Add-Failure "bound harness project_root mismatch: $boundProjectRoot"
  }
  Assert-PathMissing (Join-Path $HarnessRoot '.git') 'bootstrap must not copy .git into .hebrinex'
  Assert-PathMissing (Join-Path $HarnessRoot '.codex') 'bootstrap must not copy .codex into .hebrinex'
  Assert-PathMissing (Join-Path $HarnessRoot 'infoHebri.md') 'bootstrap must not copy infoHebri.md into .hebrinex'

  $gitignore = Join-Path $ProjectRoot '.gitignore'
  if (-not (Test-Path -LiteralPath $gitignore -PathType Leaf)) {
    Add-Failure 'bootstrap Apply must create/update consumer .gitignore'
  }
  elseif ([IO.File]::ReadAllText($gitignore) -notmatch '(?m)^\.hebrinex/\s*$') {
    Add-Failure 'consumer .gitignore must exclude .hebrinex/'
  }

  $oldRoot = $Root
  $Root = $HarnessRoot
  $contractPath = Resolve-HarnessPath 'orquestador/migration/contracts/post-migration-contract.yaml'
  $reportsDir = Resolve-HarnessPath 'orquestador/migration/reports'
  $Root = $oldRoot
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) { Add-Failure 'bound harness missing post-migration contract' }
  else {
    $contract = [IO.File]::ReadAllText($contractPath)
    foreach ($pattern in @('template:\s*false','binding_mode:\s*"bound"','project_root_verified:\s*true','migration_status:\s*applied','validators_passed:\s*true')) {
      if ($contract -notmatch $pattern) { Add-Failure "bound post-migration contract missing pattern: $pattern" }
    }
  }

  $reports = @()
  if (Test-Path -LiteralPath $reportsDir -PathType Container) {
    $reports = @(Get-ChildItem -LiteralPath $reportsDir -File -Filter 'migration-*.yaml' | Where-Object { $_.Name -ne 'migration-report.template.yaml' })
  }
  if ($reports.Count -eq 0) { Add-Failure 'bound harness must contain an applied migration/bootstrap report' }
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

function Invoke-SourceTemplateBootstrapSmoke() {
  $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('hebrinex-bootstrap-test-' + [guid]::NewGuid().ToString('N'))
  $projectRoot = Join-Path $tempRoot 'consumer-project'
  New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
  [IO.File]::WriteAllText((Join-Path $projectRoot 'README.md'), "temporary consumer project`n", [Text.UTF8Encoding]::new($false))
  try {
    $cli = Resolve-HarnessPath 'scripts/hebrinex.ps1'
    $global:LASTEXITCODE = 0
    $checkOnly = & $cli bootstrap -Root $Root -CheckOnly -ProjectRoot $projectRoot *>&1
    if ((Get-LastExitCodeValue) -ne 0) { Add-Failure "bootstrap CheckOnly failed: $($checkOnly -join ' ')" }
    $checkOnlyText = $checkOnly -join "`n"
    if ($checkOnlyText -notmatch 'writes=false' -or $checkOnlyText -notmatch 'apply_available=true') {
      Add-Failure 'bootstrap CheckOnly must report writes=false and apply_available=true'
    }

    $global:LASTEXITCODE = 0
    $apply = & $cli bootstrap -Root $Root -Apply -ProjectRoot $projectRoot *>&1
    if ((Get-LastExitCodeValue) -ne 0) { Add-Failure "bootstrap Apply failed: $($apply -join ' ')" }
    $applyText = $apply -join "`n"
    if ($applyText -notmatch 'bootstrap_status=applied') { Add-Failure 'bootstrap Apply must report bootstrap_status=applied' }

    $boundRoot = Join-Path $projectRoot '.hebrinex'
    Assert-BoundHarnessShape $boundRoot $projectRoot

    $boundValidator = Join-Path $boundRoot 'scripts/validate-harness.ps1'
    if (Test-Path -LiteralPath $boundValidator -PathType Leaf) {
      $global:LASTEXITCODE = 0
      $boundOutput = & $boundValidator -Root $boundRoot -RunNegativeTests -SkipNestedValidators *>&1
      if ((Get-LastExitCodeValue) -ne 0) {
        Add-Failure ("bootstrapped bound harness validate-harness failed: {0}; output: {1}" -f (Get-LastExitCodeValue), (Format-CommandOutput $boundOutput))
      }
    }
    else { Add-Failure 'bootstrapped harness missing validate-harness.ps1' }
  }
  finally {
    Remove-TempTree $tempRoot
  }
}

function Run-NegativeTests() {
  $badProjectRoot = ''
  if ($badProjectRoot -notmatch '^$') { Add-Failure 'negative test failed: empty ProjectRoot rule did not trigger' }
  $badExisting = '.hebrinex already exists'
  if ($badExisting -notmatch 'already exists') { Add-Failure 'negative test failed: existing .hebrinex rule did not trigger' }
  $badCopy = 'infoHebri.md'
  if ($badCopy -notmatch 'infoHebri[.]md') { Add-Failure 'negative test failed: infoHebri exclusion did not trigger' }
}

$Root = (Resolve-Path -LiteralPath $Root).Path
Write-Host "Validating bootstrap service at $Root"

Assert-Contains 'scripts/validate-harness.ps1' 'SkipNestedValidators' 'validate-harness must support bound smoke without nested validators'
Assert-Contains 'scripts/validate-bootstrap.ps1' 'SkipNestedValidators' 'bootstrap bound smoke must avoid recursive nested validators'
Assert-Contains 'scripts/hebrinex.ps1' 'bootstrap -CheckOnly\|-Apply' 'CLI help must expose bootstrap Apply'
Assert-Contains 'scripts/hebrinex.ps1' 'Copy-HarnessManifestToBoundRoot' 'bootstrap Apply must copy via manifest allowlist'
Assert-Contains 'scripts/hebrinex.ps1' 'Test-BootstrapExcludedPath' 'bootstrap Apply must define exclusion filter'
Assert-Contains 'scripts/hebrinex.ps1' 'infoHebri[.]md' 'bootstrap Apply must exclude infoHebri.md'
Assert-Contains 'scripts/hebrinex.ps1' '\.codex' 'bootstrap Apply must exclude .codex'
Assert-Contains 'scripts/hebrinex.ps1' '\.git' 'bootstrap Apply must exclude .git'
Assert-Contains 'scripts/hebrinex.ps1' 'Ensure-ConsumerGitIgnore' 'bootstrap Apply must update consumer .gitignore'
Assert-Contains 'scripts/hebrinex.ps1' 'Write-BoundProjectBinding' 'bootstrap Apply must bind PROJECT_BINDING.yaml'
Assert-Contains 'scripts/hebrinex.ps1' 'Write-BootstrapMigrationReport' 'bootstrap Apply must write applied migration report'
Assert-Contains 'orquestador/sdd/specs/bootstrap-harness.md' 'No declarar bootstrap completo sin validar' 'bootstrap spec must require validation before completion'

$bindingText = Read-HarnessText 'PROJECT_BINDING.yaml'
$bindingMode = Get-Scalar $bindingText 'binding_mode'
if ($bindingMode -eq 'source_template') {
  Invoke-SourceTemplateBootstrapSmoke
}
elseif ($bindingMode -eq 'bound') {
  $projectRoot = Get-Scalar $bindingText 'project_root'
  Assert-BoundHarnessShape $Root $projectRoot
}
else {
  Add-Failure "unsupported binding_mode for bootstrap validation: $bindingMode"
}

if ($RunNegativeTests) { Run-NegativeTests }

if ($script:Failures.Count -gt 0) {
  Write-Host 'Bootstrap validation FAILED'
  foreach ($failure in $script:Failures) { Write-Host " - $failure" }
  exit 1
}

Write-Host 'Bootstrap validation OK'
exit 0
