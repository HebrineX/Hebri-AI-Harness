param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$CheckOnly,
  [switch]$Apply,
  [string]$CommandText = '',
  [string]$Purpose = '',
  [string]$ApprovalId = '',
  [string]$RiskClass = '',
  [int]$TimeoutSeconds = 30,
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

function Redact-Text([string]$Text) {
  if ($null -eq $Text) { return '' }
  $redacted = [regex]::Replace($Text, '(?i)(api[_-]?key|token|secret|password)\s*[:=]\s*\S+', '$1=[REDACTED]')
  return [regex]::Replace($redacted, '(?i)bearer\s+[a-z0-9._\-]+', 'Bearer [REDACTED]')
}

function Redact-Command([string]$Text) {
  return Redact-Text $Text
}

function Limit-Text([string]$Text, [int]$MaxLength = 4000) {
  if ($null -eq $Text) { return '' }
  if ($Text.Length -le $MaxLength) { return $Text }
  return ($Text.Substring(0, $MaxLength) + '[TRUNCATED]')
}

function Test-SecretBearingCommand([string]$Text) {
  return $Text -match '(?i)(^|\s)(\.env|[^ \t]*\.env|[^ \t]*\.key|[^ \t]*\.pem|[^ \t]*\.pfx|[^ \t]*credentials[^ \t]*|[^ \t]*token[^ \t]*)($|\s)' -or
    $Text -match '(?i)(api[_-]?key|token|secret|password)\s*[:=]\s*\S+' -or
    $Text -match '(?i)bearer\s+[a-z0-9._\-]+'
}

function Test-SecretBearingPath([string]$Text) {
  return $Text -match '(?i)(\.env|\.key|\.pem|\.pfx|credentials|token|secret|password)'
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
  return $Text -match '(\|\||&&|[|;<>`]|[$][(]|[$][{]|(^|\s)&(\s|$))'
}

function Split-SimpleCommandLine([string]$Text) {
  if (Test-ShellComposition $Text) {
    throw 'composite_shell_requires_manual_review'
  }
  $tokens = New-Object System.Collections.Generic.List[string]
  foreach ($match in [regex]::Matches($Text, '"[^"]*"|''[^'']*''|\S+')) {
    $value = $match.Value
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
      $value = $value.Substring(1, $value.Length - 2)
    }
    [void]$tokens.Add($value)
  }
  return [string[]]$tokens
}

function Resolve-ReadOnlyPath([string]$PathText) {
  if ([string]::IsNullOrWhiteSpace($PathText)) { throw 'missing_path' }
  if ($PathText -match '[*?\[\]]') { throw 'wildcards_not_allowed_in_apply' }
  if ($PathText -match '^[A-Za-z]+::') { throw 'provider_paths_not_allowed_in_apply' }
  if (Test-SecretBearingPath $PathText) { throw 'secret_bearing_path_requires_approval' }

  $candidate = $PathText
  if (-not [IO.Path]::IsPathRooted($candidate)) {
    $candidate = Join-Path $Root $candidate
  }
  $fullPath = [IO.Path]::GetFullPath($candidate)
  $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  $comparison = [StringComparison]::OrdinalIgnoreCase
  if (-not ($fullPath.Equals($rootFull, $comparison) -or $fullPath.StartsWith(($rootFull + [IO.Path]::DirectorySeparatorChar), $comparison) -or $fullPath.StartsWith(($rootFull + [IO.Path]::AltDirectorySeparatorChar), $comparison))) {
    throw 'path_outside_root_not_allowed'
  }
  return $fullPath
}

function New-ApplyPlan([string]$Text) {
  $tokens = Split-SimpleCommandLine $Text
  if ($tokens.Count -eq 0) { throw 'empty_command' }
  $commandName = $tokens[0].ToLowerInvariant()

  if ($commandName -eq 'git') {
    if ($tokens.Count -eq 3 -and $tokens[1].Equals('status', [StringComparison]::OrdinalIgnoreCase) -and $tokens[2].Equals('--short', [StringComparison]::OrdinalIgnoreCase)) {
      return [ordered]@{ kind = 'git_status_short'; path = ''; pattern = '' }
    }
    throw 'apply_requires_strict_readonly_allowlist'
  }

  if ($commandName -eq 'get-content') {
    if ($tokens.Count -ne 2) { throw 'apply_requires_strict_readonly_allowlist' }
    return [ordered]@{ kind = 'get_content'; path = (Resolve-ReadOnlyPath $tokens[1]); pattern = '' }
  }

  if ($commandName -eq 'test-path') {
    if ($tokens.Count -ne 2) { throw 'apply_requires_strict_readonly_allowlist' }
    return [ordered]@{ kind = 'test_path'; path = (Resolve-ReadOnlyPath $tokens[1]); pattern = '' }
  }

  if ($commandName -eq 'get-childitem') {
    if ($tokens.Count -gt 2) { throw 'apply_requires_strict_readonly_allowlist' }
    $pathArg = if ($tokens.Count -eq 2) { $tokens[1] } else { '.' }
    return [ordered]@{ kind = 'get_childitem'; path = (Resolve-ReadOnlyPath $pathArg); pattern = '' }
  }

  if ($commandName -eq 'select-string') {
    if ($tokens.Count -ne 4) { throw 'apply_requires_strict_readonly_allowlist' }
    if ($tokens[2].Equals('-Pattern', [StringComparison]::OrdinalIgnoreCase)) {
      return [ordered]@{ kind = 'select_string'; path = (Resolve-ReadOnlyPath $tokens[1]); pattern = $tokens[3] }
    }
    if ($tokens[1].Equals('-Pattern', [StringComparison]::OrdinalIgnoreCase)) {
      return [ordered]@{ kind = 'select_string'; path = (Resolve-ReadOnlyPath $tokens[3]); pattern = $tokens[2] }
    }
    throw 'apply_requires_strict_readonly_allowlist'
  }

  throw 'apply_requires_strict_readonly_allowlist'
}

function Invoke-ApplyPlan([hashtable]$Plan) {
  $job = Start-Job -ScriptBlock {
    param($SerializedPlan, $JobRoot)
    $ErrorActionPreference = 'Stop'
    try {
      Set-Location -LiteralPath $JobRoot
      $kind = [string]$SerializedPlan['kind']
      $path = [string]$SerializedPlan['path']
      $pattern = [string]$SerializedPlan['pattern']
      switch ($kind) {
        'get_content' {
          $stdout = (Get-Content -LiteralPath $path -ErrorAction Stop | Out-String).TrimEnd()
          [pscustomobject]@{ ExitCode = 0; Stdout = $stdout; Stderr = '' }
        }
        'test_path' {
          $stdout = [string](Test-Path -LiteralPath $path)
          [pscustomobject]@{ ExitCode = 0; Stdout = $stdout; Stderr = '' }
        }
        'get_childitem' {
          $stdout = (Get-ChildItem -LiteralPath $path -Force -ErrorAction Stop | Select-Object Name,Mode,Length | Out-String).TrimEnd()
          [pscustomobject]@{ ExitCode = 0; Stdout = $stdout; Stderr = '' }
        }
        'select_string' {
          $stdout = (Select-String -LiteralPath $path -Pattern $pattern -ErrorAction Stop | Out-String).TrimEnd()
          [pscustomobject]@{ ExitCode = 0; Stdout = $stdout; Stderr = '' }
        }
        'git_status_short' {
          $output = & git -C $JobRoot status --short 2>&1
          $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
          [pscustomobject]@{ ExitCode = $exitCode; Stdout = (($output | Out-String).TrimEnd()); Stderr = '' }
        }
        default { [pscustomobject]@{ ExitCode = 2; Stdout = ''; Stderr = "unsupported apply plan: $kind" } }
      }
    }
    catch {
      [pscustomobject]@{ ExitCode = 1; Stdout = ''; Stderr = $_.Exception.Message }
    }
  } -ArgumentList $Plan, $Root

  $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
  if ($null -eq $completed) {
    Stop-Job -Job $job -Force | Out-Null
    Remove-Job -Job $job -Force | Out-Null
    return [ordered]@{ attempted = $true; exit_code = 124; timed_out = $true; timeout_seconds = $TimeoutSeconds; stdout = ''; stderr = 'command timed out' }
  }

  $received = Receive-Job -Job $job
  Remove-Job -Job $job -Force | Out-Null
  if ($null -eq $received) {
    return [ordered]@{ attempted = $true; exit_code = 1; timed_out = $false; timeout_seconds = $TimeoutSeconds; stdout = ''; stderr = 'no command output received' }
  }
  $item = @($received)[-1]
  return [ordered]@{
    attempted = $true
    exit_code = [int]$item.ExitCode
    timed_out = $false
    timeout_seconds = $TimeoutSeconds
    stdout = (Limit-Text (Redact-Text ([string]$item.Stdout)))
    stderr = (Limit-Text (Redact-Text ([string]$item.Stderr)))
  }
}

if (($CheckOnly -and $Apply) -or (-not $CheckOnly -and -not $Apply)) {
  throw 'command-gateway requires exactly one mode: -CheckOnly or -Apply.'
}
if ($TimeoutSeconds -lt 1 -or $TimeoutSeconds -gt 120) {
  throw 'TimeoutSeconds must be between 1 and 120.'
}

$Root = (Resolve-Path -LiteralPath $Root).Path
$registryText = Read-HarnessText 'orquestador/security/command-risk-registry.yaml'
$blockedPatterns = Get-YamlList $registryText 'blocked_patterns'
$safePatterns = Get-YamlList $registryText 'safe_patterns'
$command = $CommandText.Trim()
$mode = if ($Apply) { 'Apply' } else { 'CheckOnly' }

$decision = 'block'
$reason = 'unknown_command'
$matchedPattern = ''
$detectedRisk = 'unknown'
$requiresPreflight = $true
$requiresSi = $true
$executes = $false
$execution = [ordered]@{
  attempted = $false
  exit_code = $null
  timed_out = $false
  timeout_seconds = $TimeoutSeconds
  stdout = ''
  stderr = ''
}

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

if ($Apply -and $decision -eq 'allow') {
  try {
    $plan = New-ApplyPlan $command
    $execution = Invoke-ApplyPlan $plan
    $executes = $true
  }
  catch {
    $decision = 'block'
    $reason = $_.Exception.Message
    $requiresPreflight = $true
    $requiresSi = $true
    $executes = $false
  }
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
  version = '0.3'
  root = $Root
  mode = $mode
  command_text = $safeCommand
  purpose = $Purpose
  approval_id = $ApprovalId
  decision = $decision
  risk_class = $detectedRisk
  requires_preflight = $requiresPreflight
  requires_si = $requiresSi
  writes = $false
  executes = $executes
  matched_pattern = $matchedPattern
  reason = $reason
  generated_preflight = $preflight
  execution = $execution
  next_step = if ($decision -eq 'allow' -and $Apply) { 'read-only command executed by gateway with redacted evidence' } elseif ($decision -eq 'allow') { 'external caller may request Apply for read-only allowlisted execution' } else { 'use generated_preflight before any execution' }
}

$gatewayExitCode = 0
if ($decision -ne 'allow') { $gatewayExitCode = 2 }
elseif ($Apply -and $execution.attempted -and $null -ne $execution.exit_code -and [int]$execution.exit_code -ne 0) { $gatewayExitCode = [int]$execution.exit_code }

if ($Json) {
  $result | ConvertTo-Json -Depth 8
  exit $gatewayExitCode
}

Write-Output 'Hebri-AI-Harness Command Gateway'
Write-Output "root=$Root"
Write-Output "mode=$mode"
Write-Output "command_text=$safeCommand"
Write-Output "purpose=$Purpose"
Write-Output "approval_id=$ApprovalId"
Write-Output "decision=$decision"
Write-Output "risk_class=$detectedRisk"
Write-Output "requires_preflight=$($requiresPreflight.ToString().ToLowerInvariant())"
Write-Output "requires_si=$($requiresSi.ToString().ToLowerInvariant())"
Write-Output 'writes=false'
Write-Output "executes=$($executes.ToString().ToLowerInvariant())"
Write-Output "matched_pattern=$matchedPattern"
Write-Output "reason=$reason"
Write-Output "execution_attempted=$($execution.attempted.ToString().ToLowerInvariant())"
Write-Output "execution_exit_code=$($execution.exit_code)"
Write-Output "execution_timed_out=$($execution.timed_out.ToString().ToLowerInvariant())"
Write-Output "structured_result_json=$(($result | ConvertTo-Json -Depth 8 -Compress))"

if ($decision -eq 'allow') {
  Write-Output 'Command Gateway OK'
  exit $gatewayExitCode
}

Write-Output 'Command Gateway BLOCKED'
exit $gatewayExitCode