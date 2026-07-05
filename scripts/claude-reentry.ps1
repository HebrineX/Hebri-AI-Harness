param([switch]$CheckOnly)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $PSScriptRoot 'lib/hebri-common.psm1') -Force -DisableNameChecking -Scope Local

$briefDir = Join-Path $Root "orquestador/runtime/claude"
$brief = Join-Path $briefDir "reentry-brief.md"
$binding = Join-Path $Root "PROJECT_BINDING.yaml"
if (-not (Test-Path -LiteralPath $binding)) { Write-Error "PROJECT_BINDING.yaml missing" }
Ensure-Directory $briefDir
if ($CheckOnly -and -not (Test-Path -LiteralPath $brief)) { Write-Error "Claude reentry brief missing" }

if (-not $CheckOnly) {
  $version = (Get-Content -LiteralPath (Join-Path $Root "HARNESS_VERSION") -TotalCount 1)
  $bindingText = [IO.File]::ReadAllText($binding)
  $statePath = Join-Path $Root "orquestador/sdd/progress/state.yaml"
  $stateText = if (Test-Path -LiteralPath $statePath) { [IO.File]::ReadAllText($statePath) } else { '' }
  $locks = Get-LockInventory -Root $Root

  $content = @(
    '# Claude Reentry Brief',
    '',
    "- Harness path: $Root",
    "- Version: $version",
    "- Binding: $(Get-Scalar -Text $bindingText -Key 'binding_mode')",
    "- State mode: $(Get-Scalar -Text $stateText -Key 'mode')",
    "- Session contract: $(Get-SectionScalar -Text $stateText -Section 'session_contract' -Key 'status')",
    "- Active cycle: $(Get-SectionScalar -Text $stateText -Section 'active_cycle' -Key 'status')",
    "- Open locks: $($locks.Active.Count + $locks.Expired.Count) (expired: $($locks.Expired.Count))",
    '- Approvals expired: true',
    '- Actions with effects require preflight + SI',
    '- SI se materializa con: scripts/hebrinex.ps1 approve -Apply -CommandText <accion>'
  )
  Write-Utf8Text -Path $brief -Text (($content -join "`n") + "`n")
  # SessionStart hook stdout is injected into the session context.
  Write-Output ($content -join "`n")
}
Write-Host "OK. Claude reentry checked."
