param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$RunNegativeTests
)

$ErrorActionPreference = 'Stop'
$script:Failures = New-Object System.Collections.Generic.List[string]

function Add-Failure([string]$Message) {
  $script:Failures.Add($Message) | Out-Null
}

function Invoke-Validator([string]$Name, [string]$ScriptPath) {
  if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
    Add-Failure "missing validator: $Name ($ScriptPath)"
    return
  }

  Write-Host "Running $Name"
  if ($RunNegativeTests) {
    & $ScriptPath -Root $Root -RunNegativeTests
  }
  else {
    & $ScriptPath -Root $Root
  }
  if ($LASTEXITCODE -ne 0) {
    Add-Failure "$Name failed with exit code $LASTEXITCODE"
  }
}

$Root = (Resolve-Path -LiteralPath $Root).Path
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Auditing Hebri-AI-Harness at $Root"

Invoke-Validator 'validate-agent-contracts' (Join-Path $scriptRoot 'validate-agent-contracts.ps1')
Invoke-Validator 'validate-security-policy' (Join-Path $scriptRoot 'validate-security-policy.ps1')
Invoke-Validator 'validate-migration' (Join-Path $scriptRoot 'validate-migration.ps1')
Invoke-Validator 'validate-fixtures' (Join-Path $scriptRoot 'validate-fixtures.ps1')
Invoke-Validator 'validate-command-gateway' (Join-Path $scriptRoot 'validate-command-gateway.ps1')

if ($script:Failures.Count -gt 0) {
  Write-Host 'Harness audit FAILED'
  foreach ($failure in $script:Failures) { Write-Host " - $failure" }
  exit 1
}

Write-Host 'Harness audit OK'
exit 0
