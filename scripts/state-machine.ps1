param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [string]$FromState = '',
  [string]$ToState = '',
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Resolve-HarnessPath([string]$RelativePath) {
  Join-Path $Root $RelativePath
}

function Read-HarnessText([string]$RelativePath) {
  $path = Resolve-HarnessPath $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "missing file: $RelativePath"
  }
  return [IO.File]::ReadAllText($path)
}

function Get-DeclaredStates([string]$Text) {
  $states = New-Object System.Collections.Generic.List[string]
  $inside = $false
  foreach ($line in ($Text -split "`n")) {
    if ($line -match '^states:\s*$') { $inside = $true; continue }
    if ($inside -and $line -match '^[A-Za-z0-9_.-]+:\s*') { break }
    if ($inside -and $line -match '^\s*-\s+([A-Za-z0-9_.-]+)\s*$') { [void]$states.Add($Matches[1]) }
  }
  return $states
}

function Get-TransitionBlock([string]$Text, [string]$State) {
  $lines = New-Object System.Collections.Generic.List[string]
  $insideTransitions = $false
  $insideState = $false
  foreach ($line in ($Text -split "`n")) {
    if ($line -match '^transitions:\s*$') { $insideTransitions = $true; continue }
    if ($insideTransitions -and $line -match '^[A-Za-z0-9_.-]+:\s*' -and $line -notmatch '^transitions:\s*$') {
      if ($insideState) { break }
      if ($line -notmatch '^\s') { $insideTransitions = $false }
    }
    if (-not $insideTransitions) { continue }
    if ($line -match ('^\s{2}' + [regex]::Escape($State) + ':\s*$')) { $insideState = $true; continue }
    if ($insideState -and $line -match '^\s{2}[A-Za-z0-9_.-]+:\s*$') { break }
    if ($insideState) { [void]$lines.Add($line) }
  }
  return ($lines -join "`n")
}

function Get-NextStates([string]$Block) {
  if ($Block -match 'next:\s*\[([^\]]*)\]') {
    return @($Matches[1].Split(',') | ForEach-Object { $_.Trim().Trim('"').Trim("'") } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  }
  return @()
}

$Root = (Resolve-Path -LiteralPath $Root).Path
$lifecycleText = Read-HarnessText 'orquestador/agents/lifecycle-registry.yaml'
$states = @(Get-DeclaredStates $lifecycleText)
$decision = 'allow'
$reason = 'transition_allowed'

if ([string]::IsNullOrWhiteSpace($FromState) -or [string]::IsNullOrWhiteSpace($ToState)) {
  $decision = 'block'; $reason = 'missing_state'
}
elseif ($states -notcontains $FromState) {
  $decision = 'block'; $reason = 'unknown_from_state'
}
elseif ($states -notcontains $ToState) {
  $decision = 'block'; $reason = 'unknown_to_state'
}
else {
  $block = Get-TransitionBlock $lifecycleText $FromState
  if ($block -match 'terminal:\s*true') {
    $decision = 'block'; $reason = 'terminal_state'
  }
  else {
    $next = @(Get-NextStates $block)
    if ($next -notcontains $ToState) {
      $decision = 'block'; $reason = 'invalid_transition'
    }
  }
}

$result = [ordered]@{
  schema = 'hebrinex.runtime.state_machine.decision'
  version = '0.1'
  root = $Root
  from_state = $FromState
  to_state = $ToState
  decision = $decision
  reason = $reason
  writes = $false
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
}
else {
  Write-Output 'Hebri-AI-Harness State Machine'
  foreach ($key in $result.Keys) { Write-Output "$key=$($result[$key])" }
  if ($decision -eq 'allow') { Write-Output 'State machine OK' }
  else { Write-Output 'State machine BLOCKED' }
}

if ($decision -eq 'allow') { exit 0 }
exit 1