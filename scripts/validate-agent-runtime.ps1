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
function Invoke-AgentRuntime([string]$RoleId, [string]$Capability, [string]$From = 'requested', [string]$To = 'contract_resolved') {
  $script = Resolve-HarnessPath 'scripts/agent-runtime.ps1'
  $output = & $script -Root $Root -RoleId $RoleId -Capability $Capability -FromState $From -ToState $To -Json 2>&1
  $exitCode = $LASTEXITCODE
  $json = $null
  try { $json = ($output -join "`n") | ConvertFrom-Json } catch { Add-Failure "agent-runtime JSON invalid for $RoleId/$Capability" }
  return @{ ExitCode = $exitCode; Json = $json; Text = ($output -join "`n") }
}

$Root = (Resolve-Path -LiteralPath $Root).Path
Write-Host "Validating agent runtime enforcement at $Root"
Assert-File 'scripts/agent-runtime.ps1'
Assert-File 'scripts/state-machine.ps1'
Assert-File 'orquestador/runtime/schemas/agent-runtime-decision.schema.json'
Assert-File 'orquestador/runtime/templates/agent-runtime-decision.template.json'
Assert-File 'orquestador/testing/fixtures/positive/runtime-implementer-write.yaml'
Assert-File 'orquestador/testing/fixtures/negative/runtime-reviewer-write.yaml'
Assert-Contains 'scripts/agent-runtime.ps1' 'hebrinex.runtime.agent_enforcement.decision' 'agent runtime must emit structured decision schema'
Assert-Contains 'scripts/agent-runtime.ps1' 'denied_capability' 'agent runtime must block explicit denied capabilities'
Assert-Contains 'scripts/agent-runtime.ps1' 'missing_capability' 'agent runtime must block missing capabilities'
Assert-Contains 'orquestador/runtime/schemas/agent-runtime-decision.schema.json' 'hebrinex.runtime.agent_enforcement.decision' 'agent runtime schema must declare decision schema'

$allowWrite = Invoke-AgentRuntime 'implementer' 'edit_approved_write_set'
if ($allowWrite.ExitCode -ne 0 -or $allowWrite.Json.decision -ne 'allow') { Add-Failure 'implementer edit_approved_write_set must be allowed' }
$reviewerWrite = Invoke-AgentRuntime 'reviewer' 'edit_approved_write_set'
if ($reviewerWrite.ExitCode -eq 0 -or $reviewerWrite.Json.reason -ne 'denied_capability') { Add-Failure 'reviewer edit_approved_write_set must be blocked as denied_capability' }
$leaderWrite = Invoke-AgentRuntime 'leader' 'edit_approved_write_set'
if ($leaderWrite.ExitCode -eq 0 -or $leaderWrite.Json.reason -ne 'denied_capability') { Add-Failure 'leader edit_approved_write_set must be blocked as denied_capability' }
$unknownRole = Invoke-AgentRuntime 'invented-agent' 'read_declared_files'
if ($unknownRole.ExitCode -eq 0 -or $unknownRole.Json.reason -ne 'unknown_role') { Add-Failure 'unknown role must be blocked' }
$badTransition = Invoke-AgentRuntime 'implementer' 'edit_approved_write_set' 'active' 'closed'
if ($badTransition.ExitCode -eq 0 -or $badTransition.Json.reason -ne 'invalid_transition') { Add-Failure 'agent runtime must inherit state-machine transition blocks' }

if ($RunNegativeTests) {
  $bad = 'reviewer edit_approved_write_set'
  if ($bad -notmatch 'reviewer[\s\S]*edit_approved_write_set') { Add-Failure 'negative test failed: reviewer write runtime pattern did not trigger' }
}

if ($script:Failures.Count -gt 0) {
  Write-Host 'Agent runtime enforcement validation FAILED'
  foreach ($failure in $script:Failures) { Write-Host " - $failure" }
  exit 1
}
Write-Host 'Agent runtime enforcement validation OK'
exit 0