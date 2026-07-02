param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$RunNegativeTests
)

$ErrorActionPreference = 'Stop'
$script:Failures = New-Object System.Collections.Generic.List[string]
$StableCommands = @('help','status','budget','preflight','validate','audit','migrate','bootstrap','update-bound','list-bound-backups','restore-bound','command','state-machine','agent-runtime')
$CommandCsv = $StableCommands -join ','

function Add-Failure([string]$Message) {
  $script:Failures.Add($Message) | Out-Null
}

function Resolve-HarnessPath([string]$RelativePath) {
  Join-Path $Root $RelativePath
}

function Read-HarnessText([string]$RelativePath) {
  $path = Resolve-HarnessPath $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    Add-Failure ('missing file: ' + $RelativePath)
    return ''
  }
  $text = [IO.File]::ReadAllText($path)
  if ([string]::IsNullOrWhiteSpace($text)) {
    Add-Failure ('empty file: ' + $RelativePath)
  }
  return $text
}

function Assert-File([string]$RelativePath) {
  $path = Resolve-HarnessPath $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    Add-Failure ('missing file: ' + $RelativePath)
  }
  elseif ((Get-Item -LiteralPath $path).Length -eq 0) {
    Add-Failure ('empty file: ' + $RelativePath)
  }
}

function Assert-Contains([string]$RelativePath, [string]$Pattern, [string]$Message) {
  $text = Read-HarnessText $RelativePath
  if ($text -notmatch $Pattern) { Add-Failure $Message }
}

function Resolve-PowerShellExecutable() {
  $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
  if ($null -ne $pwsh) { return $pwsh.Source }
  $powershell = Get-Command powershell -ErrorAction SilentlyContinue
  if ($null -ne $powershell) { return $powershell.Source }
  return (Get-Process -Id $PID).Path
}

function Invoke-Cli([string[]]$Arguments) {
  $scriptPath = Resolve-HarnessPath 'scripts/hebrinex.ps1'
  $ps = Resolve-PowerShellExecutable
  $global:LASTEXITCODE = 0
  $output = @()
  $exitCode = 0
  try {
    $output = & $ps -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments -Root $Root 2>&1
    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) { $exitCode = 0 }
  }
  catch {
    $output += $_.Exception.Message
    $exitCode = 1
  }
  return @{
    ExitCode = $exitCode
    Text = ($output -join "`n")
  }
}

function Assert-OutputContains([hashtable]$Result, [string]$Pattern, [string]$Message) {
  if ($Result.Text -notmatch $Pattern) { Add-Failure $Message }
}

function Assert-CliSuccess([string]$Name, [string[]]$Arguments) {
  $result = Invoke-Cli -Arguments $Arguments
  if ($result.ExitCode -ne 0) {
    Add-Failure ('CLI command should pass: ' + $Name)
  }
  return $result
}

function Assert-CliFailure([string]$Name, [string[]]$Arguments, [string]$ExpectedPattern) {
  $result = Invoke-Cli -Arguments $Arguments
  if ($result.ExitCode -eq 0) {
    Add-Failure ('CLI command should fail: ' + $Name)
  }
  if ($result.Text -notmatch $ExpectedPattern) {
    Add-Failure ('CLI failure did not match expected pattern: ' + $Name)
  }
  return $result
}

$Root = (Resolve-Path -LiteralPath $Root).Path
Write-Host ('Validating stable CLI at ' + $Root)

Assert-File 'scripts/hebrinex.ps1'
Assert-File 'orquestador/method/cli-contract.md'
Assert-File 'scripts/command-gateway.ps1'
Assert-File 'scripts/state-machine.ps1'
Assert-File 'scripts/agent-runtime.ps1'

$cliText = Read-HarnessText 'scripts/hebrinex.ps1'
$contractText = Read-HarnessText 'orquestador/method/cli-contract.md'

Assert-Contains 'scripts/hebrinex.ps1' 'Hebri-AI-Harness CLI Core' 'CLI must expose core marker'
Assert-Contains 'scripts/hebrinex.ps1' 'cli_contract_version=0[.]2' 'CLI help must expose contract version marker'
Assert-Contains 'scripts/hebrinex.ps1' 'cli_status=stable' 'CLI help must expose stable status marker'
Assert-Contains 'scripts/hebrinex.ps1' ('commands=' + [regex]::Escape($CommandCsv)) 'CLI help must expose full command set marker'
Assert-Contains 'scripts/hebrinex.ps1' 'migrate requires exactly one mode: -CheckOnly or -Apply' 'migrate must enforce exclusive mode'
Assert-Contains 'scripts/hebrinex.ps1' 'bootstrap requires exactly one mode: -CheckOnly or -Apply' 'bootstrap must enforce exclusive mode'
Assert-Contains 'scripts/hebrinex.ps1' 'update-bound requires exactly one mode: -CheckOnly or -Apply' 'update-bound must enforce exclusive mode'
Assert-Contains 'scripts/hebrinex.ps1' 'restore-bound requires exactly one mode: -CheckOnly or -Apply' 'restore-bound must enforce exclusive mode'
Assert-Contains 'scripts/hebrinex.ps1' 'command requires exactly one mode: -CheckOnly or -Apply' 'command must enforce exclusive mode'
Assert-Contains 'scripts/hebrinex.ps1' 'list-bound-backups supports only -CheckOnly' 'list-bound-backups must remain CheckOnly-only'
Assert-Contains 'scripts/state-machine.ps1' 'hebrinex.runtime.state_machine.decision' 'state-machine must expose decision schema'
Assert-Contains 'scripts/agent-runtime.ps1' 'hebrinex.runtime.agent_enforcement.decision' 'agent-runtime must expose decision schema'

foreach ($command in $StableCommands) {
  if ($cliText -notmatch ("'" + [regex]::Escape($command) + "'")) {
    Add-Failure ('CLI ValidateSet must include command: ' + $command)
  }
  if ($contractText -notmatch ('`' + [regex]::Escape($command) + '`')) {
    Add-Failure ('CLI contract must document command: ' + $command)
  }
}

Assert-Contains 'orquestador/method/cli-contract.md' 'A command outside this list is not part of the public CLI contract[.]' 'CLI contract must close public command set'
Assert-Contains 'orquestador/method/cli-contract.md' 'Mode-bearing commands require exactly one execution mode' 'CLI contract must define exclusive modes'
Assert-Contains 'orquestador/method/cli-contract.md' 'list-bound-backups` is inventory-only and supports only `-CheckOnly`' 'CLI contract must define backup inventory mode'
Assert-Contains 'orquestador/method/cli-contract.md' 'A release is not usable if the CLI contract validator is missing or failing[.]' 'CLI contract must define usability gate'

$help = Assert-CliSuccess -Name 'help' -Arguments @('help')
Assert-OutputContains $help 'Hebri-AI-Harness CLI Core' 'help output must include CLI marker'
Assert-OutputContains $help 'cli_contract_version=0[.]2' 'help output must include contract version'
Assert-OutputContains $help 'cli_status=stable' 'help output must include stable status'
Assert-OutputContains $help ('commands=' + [regex]::Escape($CommandCsv)) 'help output must include command csv'
foreach ($command in $StableCommands) {
  Assert-OutputContains $help ([regex]::Escape($command)) ('help output must mention command: ' + $command)
}

$status = Assert-CliSuccess -Name 'status' -Arguments @('status')
Assert-OutputContains $status 'harness_version=' 'status output must include harness_version'
Assert-OutputContains $status 'binding_mode=' 'status output must include binding_mode'
Assert-OutputContains $status 'runtime_authority=non_authoritative' 'status must declare non-authoritative runtime'

$budget = Assert-CliSuccess -Name 'budget' -Arguments @('budget')
foreach ($budgetKey in @('memory_bootstrap','first_message','debug_log_intake','leader_light','runtime_status','runtime_reentry')) {
  Assert-OutputContains $budget ($budgetKey + '=') ('budget output must include ' + $budgetKey)
}

$preflight = Assert-CliSuccess -Name 'preflight' -Arguments @('preflight','-ApprovalId','VALIDATE-CLI-CHECK','-Action','validate stable CLI','-ReadSet','scripts/hebrinex.ps1','-WriteSet','none','-Verification','validate-cli')
Assert-OutputContains $preflight 'Approval ID: VALIDATE-CLI-CHECK' 'preflight output must include approval id'
Assert-OutputContains $preflight 'Read-set: scripts/hebrinex[.]ps1' 'preflight output must include read set'
Assert-OutputContains $preflight 'Write-set: none' 'preflight output must include write set'
Assert-OutputContains $preflight 'Requiere SI: SI' 'preflight output must require SI'

$migrate = Assert-CliSuccess -Name 'migrate CheckOnly' -Arguments @('migrate','-CheckOnly')
Assert-OutputContains $migrate 'writes=false' 'migrate CheckOnly must declare writes=false'

$commandJson = Assert-CliSuccess -Name 'command CheckOnly Json' -Arguments @('command','-CheckOnly','-Json','-CommandText','Get-Content README.md')
try { $parsedCommand = $commandJson.Text | ConvertFrom-Json }
catch {
  Add-Failure 'CLI command -Json output must be valid JSON'
  $parsedCommand = $null
}
if ($null -ne $parsedCommand) {
  if ($parsedCommand.schema -ne 'hebrinex.command_gateway.result') { Add-Failure 'CLI command JSON must expose command gateway schema' }
  if ($parsedCommand.version -ne '0.3') { Add-Failure 'CLI command JSON must expose gateway result version 0.3' }
  if ($parsedCommand.mode -ne 'CheckOnly') { Add-Failure 'CLI command JSON must preserve CheckOnly mode' }
  if ($parsedCommand.executes -ne $false) { Add-Failure 'CLI command CheckOnly must not execute command text' }
}

$stateJson = Assert-CliSuccess -Name 'state-machine Json allow' -Arguments @('state-machine','-Json','-FromState','requested','-ToState','contract_resolved')
try { $parsedState = $stateJson.Text | ConvertFrom-Json }
catch {
  Add-Failure 'CLI state-machine -Json output must be valid JSON'
  $parsedState = $null
}
if ($null -ne $parsedState) {
  if ($parsedState.schema -ne 'hebrinex.runtime.state_machine.decision') { Add-Failure 'CLI state-machine JSON must expose state machine schema' }
  if ($parsedState.decision -ne 'allow') { Add-Failure 'CLI state-machine expected allow decision' }
  if ($parsedState.writes -ne $false) { Add-Failure 'CLI state-machine must be read-only' }
}

$agentJson = Assert-CliSuccess -Name 'agent-runtime Json allow' -Arguments @('agent-runtime','-Json','-RoleId','implementer','-Capability','edit_approved_write_set','-FromState','requested','-ToState','contract_resolved')
try { $parsedAgent = $agentJson.Text | ConvertFrom-Json }
catch {
  Add-Failure 'CLI agent-runtime -Json output must be valid JSON'
  $parsedAgent = $null
}
if ($null -ne $parsedAgent) {
  if ($parsedAgent.schema -ne 'hebrinex.runtime.agent_enforcement.decision') { Add-Failure 'CLI agent-runtime JSON must expose agent enforcement schema' }
  if ($parsedAgent.decision -ne 'allow') { Add-Failure 'CLI agent-runtime expected allow decision' }
  if ($parsedAgent.writes -ne $false) { Add-Failure 'CLI agent-runtime must be read-only' }
}

[void](Assert-CliFailure -Name 'state-machine invalid transition' -Arguments @('state-machine','-FromState','active','-ToState','closed') -ExpectedPattern 'invalid_transition')
[void](Assert-CliFailure -Name 'agent-runtime reviewer write blocked' -Arguments @('agent-runtime','-RoleId','reviewer','-Capability','edit_approved_write_set') -ExpectedPattern 'denied_capability')
[void](Assert-CliFailure -Name 'command missing mode' -Arguments @('command','-CommandText','Get-Content README.md') -ExpectedPattern 'command requires exactly one mode')
[void](Assert-CliFailure -Name 'list-bound-backups Apply blocked' -Arguments @('list-bound-backups','-Apply','-ProjectRoot',$Root) -ExpectedPattern 'list-bound-backups supports only -CheckOnly')
[void](Assert-CliFailure -Name 'migrate conflicting modes' -Arguments @('migrate','-CheckOnly','-Apply') -ExpectedPattern 'migrate requires exactly one mode')

if ($RunNegativeTests) {
  $badMode = 'command -CheckOnly -Apply'
  if ($badMode -notmatch '-CheckOnly[\s\S]*-Apply') {
    Add-Failure 'negative test failed: conflicting mode pattern did not trigger'
  }
  $unknownCommand = 'invent-agent'
  if ($StableCommands -contains $unknownCommand) {
    Add-Failure 'negative test failed: unknown command unexpectedly exists in stable command set'
  }
}

if ($script:Failures.Count -gt 0) {
  Write-Host 'Stable CLI validation FAILED'
  foreach ($failure in $script:Failures) { Write-Host (' - ' + $failure) }
  exit 1
}

Write-Host 'Stable CLI validation OK'
exit 0