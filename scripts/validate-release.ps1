param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$RequireTag
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
  return [IO.File]::ReadAllText($path)
}

function Get-ScalarValue([string]$Text, [string]$Key) {
  foreach ($line in ($Text -split "`n")) {
    if ($line -match ('^' + [regex]::Escape($Key) + ':\s*(.*)$')) {
      return $Matches[1].Trim().Trim('"').Trim("'")
    }
  }
  return ''
}

function Assert-ContainsText([string]$RelativePath, [string]$Pattern, [string]$Message) {
  $text = Read-HarnessText $RelativePath
  if ($text -notmatch $Pattern) { Add-Failure $Message }
}

function Test-UnreleasedEmpty([string]$Changelog) {
  $inside = $false
  foreach ($line in ($Changelog -split "`n")) {
    if ($line -match '^## \[Unreleased\]') {
      $inside = $true
      continue
    }
    if ($inside -and $line -match '^## \[[^\]]+\]') { return $true }
    if ($inside -and -not [string]::IsNullOrWhiteSpace($line)) { return $false }
  }
  return $inside
}

$Root = (Resolve-Path -LiteralPath $Root).Path
Write-Host "Validating release contract at $Root"

$version = (Read-HarnessText 'HARNESS_VERSION').Trim()
if ($version -notmatch '^0[.][0-9]+[.][0-9]+$') {
  Add-Failure 'HARNESS_VERSION must be SemVer 0.x.y'
}

$binding = Read-HarnessText 'PROJECT_BINDING.yaml'
$bindingVersion = Get-ScalarValue $binding 'harness_version'
$bindingMode = Get-ScalarValue $binding 'binding_mode'
if ($bindingVersion -ne $version) {
  Add-Failure "PROJECT_BINDING.yaml harness_version must be $version"
}

Assert-ContainsText 'README.md' ('Referencia operativa actual:\s+\*\*' + [regex]::Escape($version) + '\*\*') "README.md must declare current version $version"
Assert-ContainsText 'AGENTS.md' ('Version operativa esperada:\s+' + [regex]::Escape($version)) "AGENTS.md must declare expected version $version"
Assert-ContainsText 'orquestador/context-budget.yaml' ('harness_version:\s*"' + [regex]::Escape($version) + '"') "context-budget must declare $version"
Assert-ContainsText 'orquestador/instruction-builder/instruction-registry.yaml' ('harness_version:\s*"' + [regex]::Escape($version) + '"') "instruction registry must declare $version"

$changelog = Read-HarnessText 'CHANGELOG.md'
if ($changelog -notmatch ('(?m)^## \[' + [regex]::Escape($version) + '\] - \d{4}-\d{2}-\d{2}\s*$')) {
  Add-Failure "CHANGELOG.md must contain a dated [$version] section"
}
if (-not (Test-UnreleasedEmpty $changelog)) {
  Add-Failure 'CHANGELOG.md [Unreleased] must be empty before publishing a version'
}

Assert-ContainsText 'scripts/validate-drift.ps1' 'HARNESS_VERSION must be SemVer 0[.]x[.]y' 'validate-drift.ps1 must not hardcode a patch release'
Assert-ContainsText 'scripts/validate-harness.ps1' 'currentHarnessVersion' 'validate-harness.ps1 must validate against HARNESS_VERSION dynamically'
Assert-ContainsText 'init.sh' 'HARNESS_RELEASE_VERSION' 'init.sh must validate against HARNESS_VERSION dynamically'

if ($bindingMode -eq 'source_template') {
  Assert-ContainsText '.github/workflows/ci.yml' 'pull_request:' 'source template CI must run on pull_request'
  Assert-ContainsText '.github/workflows/ci.yml' 'push:' 'source template CI must run on push'
  Assert-ContainsText '.github/workflows/ci.yml' 'validate-harness[.]ps1 -Root [.] -RunNegativeTests' 'CI must run validate-harness negative tests'
  Assert-ContainsText '.github/workflows/ci.yml' 'validate-cli[.]ps1 -Root [.] -RunNegativeTests' 'CI must run stable CLI validation'
  Assert-ContainsText '.github/workflows/ci.yml' 'audit-harness[.]ps1 -Root [.] -RunNegativeTests' 'CI must run audit-harness negative tests'
  Assert-ContainsText '.github/workflows/ci.yml' 'check-adapter-drift[.]ps1 -Root [.]' 'CI must run adapter drift check'
  Assert-ContainsText '.github/workflows/ci.yml' 'validate-migration[.]ps1 -Root [.] -RunNegativeTests' 'CI must run migration negative tests'
  Assert-ContainsText '.github/workflows/ci.yml' 'validate-security-policy[.]ps1 -Root [.] -RunNegativeTests' 'CI must run security negative tests'
  Assert-ContainsText '.github/workflows/ci.yml' 'validate-fixtures[.]ps1 -Root [.] -RunNegativeTests' 'CI must run fixture validation'
  Assert-ContainsText '.github/workflows/ci.yml' '[.]/init[.]sh' 'CI must run init.sh'
}

if ($RequireTag) {
  $tag = "v$version"
  $tagExists = $false
  try {
    & git -C $Root rev-parse -q --verify "refs/tags/$tag" *> $null
    $tagExists = ($LASTEXITCODE -eq 0)
  }
  catch {
    $tagExists = $false
  }
  if (-not $tagExists) { Add-Failure "missing local release tag: $tag" }
}

if ($script:Failures.Count -gt 0) {
  Write-Host 'Release validation FAILED'
  foreach ($failure in $script:Failures) { Write-Host " - $failure" }
  exit 1
}

Write-Host 'Release validation OK'
exit 0
