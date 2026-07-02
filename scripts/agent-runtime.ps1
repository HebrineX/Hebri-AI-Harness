param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [string]$RoleId = '',
  [string]$Capability = '',
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

function Test-CapabilityDefined([string]$RegistryText, [string]$Name) {
  $inside = $false
  foreach ($line in ($RegistryText -split "`n")) {
    if ($line -match '^capabilities:\s*$') { $inside = $true; continue }
    if ($inside -and $line -match '^role_defaults:\s*$') { return $false }
    if ($inside -and $line -match ('^\s{2}' + [regex]::Escape($Name) + ':\s*$')) { return $true }
  }
  return $false
}

function Get-InlineList([string]$Text, [string]$Key) {
  if ($Text -match ([regex]::Escape($Key) + ':\s*\[([^\]]*)\]')) {
    return @($Matches[1].Split(',') | ForEach-Object { $_.Trim().Trim('"').Trim("'") } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  }
  return @()
}

function Get-RoleDefaultsBlock([string]$RegistryText, [string]$Role) {
  $lines = New-Object System.Collections.Generic.List[string]
  $insideDefaults = $false
  $insideRole = $false
  foreach ($line in ($RegistryText -split "`n")) {
    if ($line -match '^role_defaults:\s*$') { $insideDefaults = $true; continue }
    if (-not $insideDefaults) { continue }
    if ($line -match ('^\s{2}' + [regex]::Escape($Role) + ':\s*$')) { $insideRole = $true; continue }
    if ($insideRole -and $line -match '^\s{2}[A-Za-z0-9_.-]+:\s*$') { break }
    if ($insideRole) { [void]$lines.Add($line) }
  }
  return ($lines -join "`n")
}

$Root = (Resolve-Path -LiteralPath $Root).Path
$agentRegistry = Read-HarnessText 'orquestador/agents/agent-registry.yaml'
$capabilityRegistry = Read-HarnessText 'orquestador/agents/capability-registry.yaml'
$decision = 'allow'
$reason = 'capability_allowed'
$contractRef = ''
$transitionDecision = $null

if ([string]::IsNullOrWhiteSpace($RoleId) -or [string]::IsNullOrWhiteSpace($Capability)) {
  $decision = 'block'; $reason = 'missing_role_or_capability'
}
elseif ($agentRegistry -notmatch ('(?m)^\s*-\s*id:\s*' + [regex]::Escape($RoleId) + '\s*$')) {
  $decision = 'block'; $reason = 'unknown_role'
}
else {
  $contractRef = "orquestador/agents/role-contracts/$RoleId.yaml"
  $contractPath = Resolve-HarnessPath $contractRef
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    $decision = 'block'; $reason = 'missing_role_contract'
  }
  elseif (-not (Test-CapabilityDefined $capabilityRegistry $Capability)) {
    $decision = 'block'; $reason = 'unknown_capability'
  }
  else {
    $roleDefaults = Get-RoleDefaultsBlock $capabilityRegistry $RoleId
    $contractText = [IO.File]::ReadAllText($contractPath)
    $defaultAllow = @(Get-InlineList $roleDefaults 'allow')
    $defaultDeny = @(Get-InlineList $roleDefaults 'deny')
    $contractAllow = @(Get-InlineList $contractText 'allow')
    $contractDeny = @(Get-InlineList $contractText 'deny')
    if (($defaultDeny + $contractDeny) -contains $Capability) {
      $decision = 'block'; $reason = 'denied_capability'
    }
    elseif (-not (($defaultAllow + $contractAllow) -contains $Capability)) {
      $decision = 'block'; $reason = 'missing_capability'
    }
  }
}

if ($decision -eq 'allow' -and -not [string]::IsNullOrWhiteSpace($FromState) -and -not [string]::IsNullOrWhiteSpace($ToState)) {
  $stateScript = Resolve-HarnessPath 'scripts/state-machine.ps1'
  $stateOutput = & $stateScript -Root $Root -FromState $FromState -ToState $ToState -Json 2>&1
  $stateExit = $LASTEXITCODE
  try { $transitionDecision = ($stateOutput -join "`n") | ConvertFrom-Json }
  catch { $transitionDecision = $null }
  if ($stateExit -ne 0) {
    $decision = 'block'
    if ($null -ne $transitionDecision -and -not [string]::IsNullOrWhiteSpace($transitionDecision.reason)) { $reason = $transitionDecision.reason }
    else { $reason = 'invalid_transition' }
  }
}

$result = [ordered]@{
  schema = 'hebrinex.runtime.agent_enforcement.decision'
  version = '0.1'
  root = $Root
  role_id = $RoleId
  capability = $Capability
  contract_ref = $contractRef
  from_state = $FromState
  to_state = $ToState
  decision = $decision
  reason = $reason
  writes = $false
  transition = $transitionDecision
}

if ($Json) {
  $result | ConvertTo-Json -Depth 10
}
else {
  Write-Output 'Hebri-AI-Harness Agent Runtime Enforcement'
  foreach ($key in $result.Keys) {
    if ($key -ne 'transition') { Write-Output "$key=$($result[$key])" }
  }
  if ($decision -eq 'allow') { Write-Output 'Agent runtime enforcement OK' }
  else { Write-Output 'Agent runtime enforcement BLOCKED' }
}

if ($decision -eq 'allow') { exit 0 }
exit 1