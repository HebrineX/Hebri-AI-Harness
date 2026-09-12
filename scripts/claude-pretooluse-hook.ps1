# claude-pretooluse-hook.ps1 - Claude Code PreToolUse hook.
#
# Reads the hook payload from stdin, classifies Bash/PowerShell commands with the
# Command Gateway and answers with a permission decision:
#   - gateway allow            -> permissionDecision=allow  (safe read-only, skip prompt)
#   - gateway blocked_pattern  -> permissionDecision=ask    (forces explicit operator SI)
#   - anything else            -> no output                 (defer to normal permission flow)
#
# Fail-open by design: if the gateway or parsing fails, the hook emits nothing and
# Claude Code's own permission system remains in charge.

param(
  [ValidateSet('source_template','legacy_bound','central_instance')][string]$RuntimeMode = 'source_template',
  [string]$InstallRoot = (Split-Path -Parent $PSScriptRoot),
  [string]$ProjectRoot = '',
  [string]$CatalogRoot = ''
)

$ErrorActionPreference = 'Stop'

function Write-HookDecision([string]$Decision, [string]$Reason) {
  $output = @{
    hookSpecificOutput = @{
      hookEventName = 'PreToolUse'
      permissionDecision = $Decision
      permissionDecisionReason = $Reason
    }
  }
  $output | ConvertTo-Json -Depth 4 -Compress
}

try {
  $raw = [Console]::In.ReadToEnd()
  if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
  $payload = $raw | ConvertFrom-Json
  $toolName = [string]$payload.tool_name
  if ($toolName -ne 'Bash' -and $toolName -ne 'PowerShell') { exit 0 }
  $commandText = [string]$payload.tool_input.command
  if ([string]::IsNullOrWhiteSpace($commandText)) { exit 0 }

  $harnessRoot = [IO.Path]::GetFullPath($InstallRoot)
  if ($RuntimeMode -eq 'central_instance') {
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot = (Get-Location).Path }
    Import-Module (Join-Path $PSScriptRoot 'lib/hebri-common.psm1') -Force -DisableNameChecking -Scope Local
    [void](Resolve-HebriRuntimeContext -InstallRoot $harnessRoot -ProjectRoot $ProjectRoot -DeploymentMode central_instance -CatalogRoot $CatalogRoot)
  }
  $gatewayScript = Join-Path $harnessRoot 'scripts/command-gateway.ps1'
  if (-not (Test-Path -LiteralPath $gatewayScript -PathType Leaf)) { exit 0 }

  $gatewayOutput = & $gatewayScript -Root $harnessRoot -CheckOnly -Json -CommandText $commandText 2>$null
  $result = ($gatewayOutput -join "`n") | ConvertFrom-Json

  if ($result.decision -eq 'allow') {
    Write-HookDecision 'allow' "hebrinex gateway: $($result.reason) (risk=$($result.risk_class))"
    exit 0
  }
  if ($result.reason -eq 'blocked_pattern') {
    Write-HookDecision 'ask' "hebrinex gateway BLOCKED pattern '$($result.matched_pattern)' (risk=$($result.risk_class)). Esta accion requiere SI explicito del operador."
    exit 0
  }
  # unknown/composite/secrets: defer to the normal Claude Code permission flow.
  exit 0
}
catch {
  exit 0
}
