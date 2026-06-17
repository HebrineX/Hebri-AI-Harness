param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [string]$RegistryPath = "",
  [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath $Root).Path
if ([string]::IsNullOrWhiteSpace($RegistryPath)) { $RegistryPath = Join-Path $Root 'orquestador/sdd/progress/registry.yaml' }
if (-not (Test-Path -LiteralPath $RegistryPath)) { Write-Error "registry.yaml missing: $RegistryPath" }

function Has-TopKey([string]$Text, [string]$Key) {
  return ($Text -match ('(?m)^' + [regex]::Escape($Key) + ':'))
}

function Ensure-TopBlockBeforeCycles([string]$Text, [string]$Key, [string[]]$Block, [System.Collections.Generic.List[string]]$Changes) {
  if (Has-TopKey $Text $Key) { return $Text }
  $Changes.Add("add top-level key: $Key") | Out-Null
  $blockText = ($Block -join "`n") + "`n"
  $cycles = [regex]::Match($Text, '(?m)^cycles:')
  if ($cycles.Success) {
    return $Text.Substring(0, $cycles.Index).TrimEnd() + "`n" + $blockText + $Text.Substring($cycles.Index)
  }
  return $Text.TrimEnd() + "`n" + $blockText
}

$text = [IO.File]::ReadAllText($RegistryPath)
$changes = New-Object System.Collections.Generic.List[string]

$text = Ensure-TopBlockBeforeCycles $text 'kanban_statuses' @(
  'kanban_statuses:',
  '  - todo',
  '  - ready',
  '  - in_progress',
  '  - review',
  '  - blocked',
  '  - done',
  '  - cancelled',
  '  - legacy_unverified'
) $changes

$text = Ensure-TopBlockBeforeCycles $text 'roles' @(
  'roles:',
  '  - interpreter',
  '  - leader',
  '  - executor',
  '  - reviewer',
  '  - auditor',
  '  - reporter'
) $changes

$text = Ensure-TopBlockBeforeCycles $text 'profiles' @(
  'profiles:',
  '  auditor:',
  '    - harness_compliance',
  '    - cost',
  '    - security',
  '    - architecture',
  '    - release',
  '    - pipeline',
  '    - detractor',
  '    - detractor_senior',
  '  reporter:',
  '    - operator',
  '    - technical',
  '    - executive'
) $changes

if (-not (Has-TopKey $text 'cycles')) {
  $changes.Add('add top-level key: cycles') | Out-Null
  $text = $text.TrimEnd() + "`ncycles: []`n"
}

if ($changes.Count -eq 0) {
  Write-Host 'OK. registry.yaml already regularized.'
  exit 0
}

Write-Host 'Registry regularization plan:'
$changes | ForEach-Object { Write-Host "- $_" }

if (-not $Apply) {
  Write-Host 'CheckOnly: no files written. Re-run with -Apply to write changes.'
  exit 1
}

$backup = $RegistryPath + '.bak'
Copy-Item -LiteralPath $RegistryPath -Destination $backup -Force
[IO.File]::WriteAllText($RegistryPath, (($text -replace "`r`n", "`n") -replace "`r", "`n"), [Text.UTF8Encoding]::new($false))
Write-Host "OK. registry.yaml regularized. Backup: $backup"