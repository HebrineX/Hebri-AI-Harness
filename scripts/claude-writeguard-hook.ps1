# claude-writeguard-hook.ps1 - Claude Code PreToolUse hook for Edit|Write|NotebookEdit.
#
# Reads the hook payload from stdin, resolves the target file path and answers:
#   - path in write-scope-registry claude_hook_protected_paths -> permissionDecision=ask
#   - path covered by an active non-expired lock                -> permissionDecision=ask (with lock_id)
#   - anything else (including paths outside the harness root)  -> no output (defer)
#
# This hook runs on EVERY edit: it must stay fast and must never break the flow.
# Fail-open by design: any error in the hook itself exits 0 with no output.

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
  if ($toolName -notin @('Edit', 'Write', 'NotebookEdit')) { exit 0 }

  $filePath = [string]$payload.tool_input.file_path
  if ([string]::IsNullOrWhiteSpace($filePath)) { $filePath = [string]$payload.tool_input.notebook_path }
  if ([string]::IsNullOrWhiteSpace($filePath)) { exit 0 }

  $harnessRoot = Split-Path -Parent $PSScriptRoot
  if (-not [IO.Path]::IsPathRooted($filePath)) { $filePath = Join-Path $harnessRoot $filePath }
  $fullPath = [IO.Path]::GetFullPath($filePath)
  $rootFull = [IO.Path]::GetFullPath($harnessRoot).TrimEnd('\', '/')
  $comparison = [StringComparison]::OrdinalIgnoreCase
  $underRoot = $fullPath.StartsWith(($rootFull + [IO.Path]::DirectorySeparatorChar), $comparison) -or
    $fullPath.StartsWith(($rootFull + [IO.Path]::AltDirectorySeparatorChar), $comparison)
  # Paths outside the harness stay with the normal Claude Code permission flow.
  if (-not $underRoot) { exit 0 }
  $relativePath = ($fullPath.Substring($rootFull.Length).TrimStart('\', '/')) -replace '\\', '/'

  Import-Module (Join-Path $PSScriptRoot 'lib/hebri-common.psm1') -Force -DisableNameChecking -Scope Local

  # a) Protected paths from the write-scope registry.
  $registryPath = Join-Path $harnessRoot 'orquestador/security/write-scope-registry.yaml'
  if (Test-Path -LiteralPath $registryPath -PathType Leaf) {
    $registryText = [IO.File]::ReadAllText($registryPath)
    foreach ($protected in (Get-YamlList -Text $registryText -Key 'claude_hook_protected_paths')) {
      if (Test-LockPathOverlap -PathA $relativePath -PathB $protected) {
        Write-HookDecision 'ask' "hebrinex writeguard: '$relativePath' esta protegido por write-scope-registry (regla '$protected'). Editarlo requiere SI explicito del operador."
        exit 0
      }
    }
  }

  # b) Active non-expired locks over the path.
  $lock = Find-LockForPath -Root $harnessRoot -Path $relativePath
  if ($null -ne $lock) {
    Write-HookDecision 'ask' "hebrinex writeguard: '$relativePath' esta lockeado por $($lock.LockId) (owner=$($lock.Owner), expires_at=$($lock.ExpiresAt)). Editarlo requiere SI explicito del operador o liberar el lock."
    exit 0
  }

  # c) No decision: defer to the normal permission flow.
  exit 0
}
catch {
  exit 0
}
