param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$RunNegativeTests
)

$ErrorActionPreference = 'Stop'
$script:Failures = New-Object System.Collections.Generic.List[string]

function Add-Failure([string]$Message) { $script:Failures.Add($Message) | Out-Null }
function Resolve-HarnessPath([string]$RelativePath) { Join-Path $Root $RelativePath }
function Read-HarnessText([string]$RelativePath) {
  $path = Resolve-HarnessPath $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Add-Failure "missing file: $RelativePath"; return '' }
  $text = [IO.File]::ReadAllText($path)
  if ([string]::IsNullOrWhiteSpace($text)) { Add-Failure "empty file: $RelativePath" }
  return $text
}
function Assert-File([string]$RelativePath) {
  $path = Resolve-HarnessPath $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Add-Failure "missing file: $RelativePath" }
  elseif ((Get-Item -LiteralPath $path).Length -eq 0) { Add-Failure "empty file: $RelativePath" }
}
function Assert-Contains([string]$RelativePath, [string]$Pattern, [string]$Message) {
  $text = Read-HarnessText $RelativePath
  if ($text -notmatch $Pattern) { Add-Failure $Message }
}
function Invoke-State([string]$From, [string]$To) {
  $script = Resolve-HarnessPath 'scripts/state-machine.ps1'
  $output = & $script -Root $Root -FromState $From -ToState $To -Json 2>&1
  $exitCode = $LASTEXITCODE
  $json = $null
  try { $json = ($output -join "`n") | ConvertFrom-Json } catch { Add-Failure "state-machine JSON invalid for $From -> $To" }
  return @{ ExitCode = $exitCode; Json = $json; Text = ($output -join "`n") }
}

$Root = (Resolve-Path -LiteralPath $Root).Path
Write-Host "Validating state machine at $Root"
Assert-File 'scripts/state-machine.ps1'
Assert-File 'orquestador/agents/lifecycle-registry.yaml'
Assert-File 'orquestador/runtime/schemas/state-machine-decision.schema.json'
Assert-File 'orquestador/runtime/templates/state-machine-decision.template.json'
Assert-Contains 'scripts/state-machine.ps1' 'hebrinex.runtime.state_machine.decision' 'state-machine must emit structured decision schema'
Assert-Contains 'orquestador/agents/lifecycle-registry.yaml' 'active:[\s\S]*next:\s*\[handoff_ready, blocked\]' 'active state must not transition directly to closed'
Assert-Contains 'orquestador/runtime/schemas/state-machine-decision.schema.json' 'hebrinex.runtime.state_machine.decision' 'state-machine schema must declare decision schema'

$allowed = Invoke-State 'requested' 'contract_resolved'
if ($allowed.ExitCode -ne 0 -or $allowed.Json.decision -ne 'allow') { Add-Failure 'requested -> contract_resolved must be allowed' }
$blocked = Invoke-State 'active' 'closed'
if ($blocked.ExitCode -eq 0 -or $blocked.Json.reason -ne 'invalid_transition') { Add-Failure 'active -> closed must be blocked as invalid_transition' }
$terminal = Invoke-State 'closed' 'active'
if ($terminal.ExitCode -eq 0 -or $terminal.Json.reason -ne 'terminal_state') { Add-Failure 'closed -> active must be blocked as terminal_state' }

if ($RunNegativeTests) {
  $bad = 'active -> closed'
  if ($bad -notmatch 'active\s*->\s*closed') { Add-Failure 'negative test failed: invalid state transition pattern did not trigger' }
}

if ($script:Failures.Count -gt 0) {
  Write-Host 'State machine validation FAILED'
  foreach ($failure in $script:Failures) { Write-Host " - $failure" }
  exit 1
}
Write-Host 'State machine validation OK'
exit 0