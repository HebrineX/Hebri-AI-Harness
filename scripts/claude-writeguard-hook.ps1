# claude-writeguard-hook.ps1 - Claude Code PreToolUse hook for Edit|Write|NotebookEdit.
#
# Reads the hook payload from stdin, resolves the target file path and answers:
#   - path in write-scope-registry claude_hook_protected_paths -> permissionDecision=ask
#   - path covered by an active non-expired lock                -> permissionDecision=ask (with lock_id)
#   - anything else (including paths outside the harness root)  -> no output (defer)
#
# This hook runs on EVERY edit: it must stay fast and must never break the flow.
# Fail-open by design: any error in the hook itself exits 0 with no output.

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
  if ($toolName -notin @('Edit', 'Write', 'NotebookEdit')) { exit 0 }

  $filePath = [string]$payload.tool_input.file_path
  if ([string]::IsNullOrWhiteSpace($filePath)) { $filePath = [string]$payload.tool_input.notebook_path }
  if ([string]::IsNullOrWhiteSpace($filePath)) { exit 0 }

  $harnessRoot = [IO.Path]::GetFullPath($InstallRoot)
  Import-Module (Join-Path $PSScriptRoot 'lib/hebri-common.psm1') -Force -DisableNameChecking -Scope Local
  $scopeRoot = $harnessRoot
  $stateRoot = $harnessRoot
  if ($RuntimeMode -eq 'central_instance') {
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot = (Get-Location).Path }
    $context = Resolve-HebriRuntimeContext -InstallRoot $harnessRoot -ProjectRoot $ProjectRoot -DeploymentMode central_instance -CatalogRoot $CatalogRoot
    $scopeRoot = [string]$context.project_root
    $stateRoot = Join-Path $scopeRoot '.hebrinex'
  }
  if (-not [IO.Path]::IsPathRooted($filePath)) { $filePath = Join-Path $scopeRoot $filePath }
  $fullPath = [IO.Path]::GetFullPath($filePath)
  $rootFull = [IO.Path]::GetFullPath($scopeRoot).TrimEnd('\', '/')
  $comparison = [StringComparison]::OrdinalIgnoreCase
  $underRoot = $fullPath.StartsWith(($rootFull + [IO.Path]::DirectorySeparatorChar), $comparison) -or
    $fullPath.StartsWith(($rootFull + [IO.Path]::AltDirectorySeparatorChar), $comparison)
  # Paths outside the harness stay with the normal Claude Code permission flow.
  if (-not $underRoot) { exit 0 }
  $relativePath = ($fullPath.Substring($rootFull.Length).TrimStart('\', '/')) -replace '\\', '/'

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
  $lock = Find-LockForPath -Root $stateRoot -Path $relativePath
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
