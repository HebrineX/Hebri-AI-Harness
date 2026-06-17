param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [string]$StatePath = "",
  [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath $Root).Path
if ([string]::IsNullOrWhiteSpace($StatePath)) { $StatePath = Join-Path $Root 'orquestador/sdd/progress/state.yaml' }
if (-not (Test-Path -LiteralPath $StatePath)) { Write-Error "state.yaml missing: $StatePath" }

function Get-ScalarValue([string]$Path, [string]$Key) {
  if (-not (Test-Path -LiteralPath $Path)) { return '' }
  foreach ($line in ([IO.File]::ReadAllLines($Path))) {
    if ($line -match ('^' + [regex]::Escape($Key) + ':\s*(.*)$')) { return $Matches[1].Trim().Trim('"') }
  }
  return ''
}

function Has-TopKey([string]$Text, [string]$Key) {
  return ($Text -match ('(?m)^' + [regex]::Escape($Key) + ':'))
}

function Ensure-TopBlock([string]$Text, [string]$Key, [string[]]$Block, [System.Collections.Generic.List[string]]$Changes) {
  if (Has-TopKey $Text $Key) { return $Text }
  $Changes.Add("add top-level key: $Key") | Out-Null
  return $Text.TrimEnd() + "`n" + (($Block -join "`n") + "`n")
}

function Ensure-InlineListItems([string]$Text, [string]$Key, [string[]]$Items, [System.Collections.Generic.List[string]]$Changes) {
  $pattern = '(?m)^' + [regex]::Escape($Key) + ':\s*\[(.*?)\]\s*$'
  $match = [regex]::Match($Text, $pattern)
  if (-not $match.Success) { return $Text }
  $existing = @($match.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  $merged = New-Object System.Collections.Generic.List[string]
  foreach ($item in $existing) { if (-not $merged.Contains($item)) { $merged.Add($item) | Out-Null } }
  foreach ($item in $Items) {
    if (-not $merged.Contains($item)) { $merged.Add($item) | Out-Null; $Changes.Add("add ${Key}: $item") | Out-Null }
  }
  $newLine = $Key + ': [' + (($merged.ToArray()) -join ', ') + ']'
  return $Text.Substring(0, $match.Index) + $newLine + $Text.Substring($match.Index + $match.Length)
}

$text = [IO.File]::ReadAllText($StatePath)
$changes = New-Object System.Collections.Generic.List[string]
$bindingPath = Join-Path $Root 'PROJECT_BINDING.yaml'
$bindingMode = Get-ScalarValue $bindingPath 'binding_mode'
$projectRoot = Get-ScalarValue $bindingPath 'project_root'
if ([string]::IsNullOrWhiteSpace($bindingMode)) { $bindingMode = 'needs_review' }

$text = Ensure-TopBlock $text 'project_binding' @(
  'project_binding:',
  "  status: $bindingMode",
  '  source: "PROJECT_BINDING.yaml"',
  ("  project_root: `"$projectRoot`"")
  '  harness_path: ""'
) $changes

$text = Ensure-TopBlock $text 'conditional_gates' @(
  'conditional_gates: [G5C_deploy_migration_complete, G5D_reference_drift_complete, G5E_ci_pipeline_history_complete, G5F_backlog_classification_complete, G5G_audit_report_contract_complete, G5H_final_report_crosslink_complete]'
) $changes

$text = Ensure-InlineListItems $text 'required_gates' @('G3A_detractor_senior_pre_implementation','G5I_memory_consistency_complete','G6_agent_closure_complete') $changes

if ($changes.Count -eq 0) {
  Write-Host 'OK. state.yaml already regularized.'
  exit 0
}

Write-Host 'State regularization plan:'
$changes | ForEach-Object { Write-Host "- $_" }

if (-not $Apply) {
  Write-Host 'CheckOnly: no files written. Re-run with -Apply to write changes.'
  exit 1
}

$backup = $StatePath + '.bak'
Copy-Item -LiteralPath $StatePath -Destination $backup -Force
[IO.File]::WriteAllText($StatePath, (($text -replace "`r`n", "`n") -replace "`r", "`n"), [Text.UTF8Encoding]::new($false))
Write-Host "OK. state.yaml regularized. Backup: $backup"