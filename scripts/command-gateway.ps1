param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$CheckOnly,
  [switch]$Apply,
  [string]$CommandText = '',
  [string]$Purpose = '',
  [string]$ApprovalId = '',
  [string]$RiskClass = '',
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

function Get-YamlList([string]$Text, [string]$Key) {
  $items = New-Object System.Collections.Generic.List[string]
  $inside = $false
  foreach ($line in ($Text -split "`n")) {
    if ($line -match ('^' + [regex]::Escape($Key) + ':\s*$')) {
      $inside = $true
      continue
    }
    if ($inside -and $line -match '^[A-Za-z0-9_.-]+:\s*') { break }
    if ($inside -and $line -match '^\s*-\s*(.+?)\s*$') {
      $value = $Matches[1].Trim().Trim('"').Trim("'")
      if (-not [string]::IsNullOrWhiteSpace($value)) { [void]$items.Add($value) }
    }
  }
  return $items
}

function Test-ContainsLiteral([string]$Text, [string]$Needle) {
  if ([string]::IsNullOrWhiteSpace($Needle)) { return $false }
  return $Text.IndexOf($Needle, [StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Test-BlockedPatternMatch([string]$Text, [string]$Pattern) {
  if (Test-ContainsLiteral $Text $Pattern) { return $true }
  $lower = $Text.ToLowerInvariant()
  $needle = $Pattern.ToLowerInvariant()
  if ($needle -eq 'curl |') { return ($lower -match '^curl\b') -and ($Text -match '[|]') }
  if ($needle -eq 'iwr |') { return ($lower -match '^(iwr|invoke-webrequest)\b') -and ($Text -match '[|]') }
  return $false
}

function Test-StartsWithPattern([string]$Text, [string]$Pattern) {
  if ([string]::IsNullOrWhiteSpace($Pattern)) { return $false }
  return $Text.Equals($Pattern, [StringComparison]::OrdinalIgnoreCase) -or
    $Text.StartsWith(($Pattern + ' '), [StringComparison]::OrdinalIgnoreCase)
}

function Redact-Command([string]$Text) {
  $redacted = [regex]::Replace($Text, '(?i)(api[_-]?key|token|secret|password)\s*[:=]\s*\S+', '$1=[REDACTED]')
  return [regex]::Replace($redacted, '(?i)bearer\s+[a-z0-9._\-]+', 'Bearer [REDACTED]')
}

function Test-SecretBearingCommand([string]$Text) {
  return $Text -match '(?i)(^|\s)(\.env|[^ \t]*\.env|[^ \t]*\.key|[^ \t]*\.pem|[^ \t]*\.pfx|[^ \t]*credentials[^ \t]*|[^ \t]*token[^ \t]*)($|\s)' -or
    $Text -match '(?i)(api[_-]?key|token|secret|password)\s*[:=]\s*\S+' -or
    $Text -match '(?i)bearer\s+[a-z0-9._\-]+'
}

function Get-DetectedRiskClass([string]$Text, [string]$MatchedPattern) {
  $lower = $Text.ToLowerInvariant()
  $pattern = $MatchedPattern.ToLowerInvariant()
  if ($pattern -match 'git push|git reset' -or $lower -match '^git\s+(push|pull|fetch|clone|remote)\b') { return 'git_remote' }
  if ($pattern -match 'curl|iwr' -or $lower -match '^(curl|wget|iwr|invoke-webrequest)\b') { return 'network' }
  if ($pattern -match 'rm -rf|remove-item' -or $lower -match '\b(remove-item|del|erase|rmdir)\b') { return 'destructive' }
  if ($lower -match '(\.env|token|secret|password|credential|\.pem|\.key|\.pfx)') { return 'secrets' }
  if ($pattern -match 'invoke-expression|iex' -or $lower -match '\b(start-process|set-executionpolicy)\b') { return 'privileged' }
  if ($lower -match '\b(set-content|add-content|out-file|new-item|copy-item|move-item)\b') { return 'write' }
  return 'unknown'
}

function Test-ShellComposition([string]$Text) {
  return $Text -match '(\|\||&&|[|;<>])'
}

if (($CheckOnly -and $Apply) -or (-not $CheckOnly -and -not $Apply)) {
  throw 'command-gateway requires exactly one mode: -CheckOnly. -Apply is reserved for a later slice.'
}
if ($Apply) {
  throw 'command-gateway Apply is not implemented in this release. This gateway does not execute arbitrary commands.'
}

$Root = (Resolve-Path -LiteralPath $Root).Path
$registryText = Read-HarnessText 'orquestador/security/command-risk-registry.yaml'
$blockedPatterns = Get-YamlList $registryText 'blocked_patterns'
$safePatterns = Get-YamlList $registryText 'safe_patterns'
$command = $CommandText.Trim()

$decision = 'block'
$reason = 'unknown_command'
$matchedPattern = ''
$detectedRisk = 'unknown'
$requiresPreflight = $true
$requiresSi = $true

if ([string]::IsNullOrWhiteSpace($command)) {
  $reason = 'empty_command'
}
else {
  foreach ($pattern in $blockedPatterns) {
    if (Test-BlockedPatternMatch $command $pattern) {
      $matchedPattern = $pattern
      $reason = 'blocked_pattern'
      $detectedRisk = Get-DetectedRiskClass $command $matchedPattern
      break
    }
  }

  if ([string]::IsNullOrWhiteSpace($matchedPattern) -and (Test-SecretBearingCommand $command)) {
    $reason = 'secret_bearing_command_requires_approval'
    $detectedRisk = 'secrets'
  }

  if ([string]::IsNullOrWhiteSpace($matchedPattern) -and (Test-ShellComposition $command)) {
    $reason = 'composite_shell_requires_manual_review'
    $detectedRisk = Get-DetectedRiskClass $command ''
  }

  if ([string]::IsNullOrWhiteSpace($matchedPattern) -and $reason -eq 'unknown_command') {
    foreach ($pattern in $safePatterns) {
      if (Test-StartsWithPattern $command $pattern) {
        $matchedPattern = $pattern
        $decision = 'allow'
        $reason = 'safe_read_only_pattern'
        $detectedRisk = 'read_only'
        $requiresPreflight = $false
        $requiresSi = $false
        break
      }
    }
  }

  if ($decision -ne 'allow' -and $detectedRisk -eq 'unknown') {
    $detectedRisk = Get-DetectedRiskClass $command $matchedPattern
  }
}

if (-not [string]::IsNullOrWhiteSpace($RiskClass) -and $RiskClass -ne $detectedRisk) {
  $decision = 'block'
  $reason = 'declared_risk_mismatch'
  $requiresPreflight = $true
  $requiresSi = $true
}

$safeCommand = Redact-Command $command
$effectiveApprovalId = $ApprovalId
if ([string]::IsNullOrWhiteSpace($effectiveApprovalId)) { $effectiveApprovalId = 'COMMAND-GATEWAY-REQUIRED' }

$preflight = [ordered]@{
  enabled = $requiresPreflight
  approval_id = $effectiveApprovalId
  action = "Review command before any execution: $safeCommand"
  cwd = $Root
  read_set = 'orquestador/security/command-risk-registry.yaml, orquestador/security/secrets-policy.yaml'
  write_set = 'none declared by gateway'
  command_tool = $safeCommand
  network_git_external = if ($detectedRisk -in @('network','git_remote')) { 'yes' } else { 'no by default' }
  risk = $detectedRisk
  verification = 'human review plus command evidence outside gateway'
  expected_evidence = 'SI approval, command output, exit code and redacted logs'
  requires_si = $requiresSi
}

$result = [ordered]@{
  schema = 'hebrinex.command_gateway.result'
  version = '0.2'
  root = $Root
  mode = 'CheckOnly'
  command_text = $safeCommand
  purpose = $Purpose
  approval_id = $ApprovalId
  decision = $decision
  risk_class = $detectedRisk
  requires_preflight = $requiresPreflight
  requires_si = $requiresSi
  writes = $false
  executes = $false
  matched_pattern = $matchedPattern
  reason = $reason
  generated_preflight = $preflight
  next_step = if ($decision -eq 'allow') { 'external caller may request a separate execution approval if needed' } else { 'use generated_preflight before any execution' }
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
  if ($decision -eq 'allow') { exit 0 }
  exit 2
}

Write-Output 'Hebri-AI-Harness Command Gateway'
Write-Output "root=$Root"
Write-Output 'mode=CheckOnly'
Write-Output "command_text=$safeCommand"
Write-Output "purpose=$Purpose"
Write-Output "approval_id=$ApprovalId"
Write-Output "decision=$decision"
Write-Output "risk_class=$detectedRisk"
Write-Output "requires_preflight=$($requiresPreflight.ToString().ToLowerInvariant())"
Write-Output "requires_si=$($requiresSi.ToString().ToLowerInvariant())"
Write-Output "writes=false"
Write-Output "executes=false"
Write-Output "matched_pattern=$matchedPattern"
Write-Output "reason=$reason"
Write-Output "structured_result_json=$(($result | ConvertTo-Json -Depth 8 -Compress))"

if ($decision -eq 'allow') {
  Write-Output 'Command Gateway OK'
  exit 0
}

Write-Output 'Command Gateway BLOCKED'
exit 2
