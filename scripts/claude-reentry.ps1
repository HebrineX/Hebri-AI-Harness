param(
  [switch]$CheckOnly,
  [ValidateSet('source_template','legacy_bound','central_instance')][string]$RuntimeMode = 'source_template',
  [string]$InstallRoot = (Split-Path -Parent $PSScriptRoot),
  [string]$ProjectRoot = '',
  [string]$CatalogRoot = '',
  [string]$OperationDescriptorPath = '',
  [string]$ScopedApprovalStoreRoot = '',
  [string]$ScopedApprovalId = '',
  [string]$OperationLockPath = '',
  [string]$OperationJournalPath = ''
)

$ErrorActionPreference = "Stop"
$Root = [IO.Path]::GetFullPath($InstallRoot)
Import-Module (Join-Path $PSScriptRoot 'lib/hebri-common.psm1') -Force -DisableNameChecking -Scope Local

if ($RuntimeMode -eq 'central_instance') {
  if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot = (Get-Location).Path }
  try {
    $context = Resolve-HebriRuntimeContext -InstallRoot $Root -ProjectRoot $ProjectRoot -DeploymentMode central_instance -CatalogRoot $CatalogRoot
  }
  catch {
    Write-Error ("PROJECT_NOT_FOUND: central hook could not resolve a valid binding. Run hebrinex-central status/reconcile. Detail: " + $_.Exception.Message)
  }
  $stateRoot = Join-Path ([string]$context.project_root) '.hebrinex'
  $statePath = Resolve-HarnessPath -Root $stateRoot -RelativePath 'orquestador/sdd/progress/state.yaml'
  $stateText = if (Test-Path -LiteralPath $statePath -PathType Leaf) { [IO.File]::ReadAllText($statePath) } else { '' }
  $locks = Get-LockInventory -Root $stateRoot
  $operationLockCount = 0
  $operationLocksRoot = Join-Path ([string]$context.instance_root) 'runtime/locks'
  if (Test-Path -LiteralPath $operationLocksRoot -PathType Container) {
    foreach ($file in @(Get-ChildItem -LiteralPath $operationLocksRoot -File -Filter 'OPLOCK-*.json' -ErrorAction SilentlyContinue)) {
      try { if ([string](([IO.File]::ReadAllText($file.FullName) | ConvertFrom-Json).status) -eq 'active') { $operationLockCount++ } } catch { }
    }
  }
  $content = @(
    '# Claude Reentry Brief',
    '',
    "- Harness path: $([string]$context.install_root)",
    "- Project root: $([string]$context.project_root)",
    "- Instance root: $([string]$context.instance_root)",
    "- Version: $([string]$context.harness_version)",
    '- Binding: central_instance',
    "- Project ID: $([string]$context.project_id)",
    "- State mode: $(Get-Scalar -Text $stateText -Key 'mode')",
    "- Session contract: $(Get-SectionScalar -Text $stateText -Section 'session_contract' -Key 'status')",
    "- Active cycle: $(Get-SectionScalar -Text $stateText -Section 'active_cycle' -Key 'status')",
    "- Open locks: $($locks.Active.Count + $locks.Expired.Count + $operationLockCount) (expired SDD: $($locks.Expired.Count))",
    '- Actions with effects require preflight + SI',
    '- This central hook computed the brief without writing project state'
  )
  if (-not $CheckOnly) { Write-Output ($content -join "`n") }
  Write-Host 'OK. Claude central reentry checked.'
  exit 0
}

$brief = Resolve-HarnessPath -Root $Root -RelativePath "orquestador/runtime/claude/reentry-brief.md"
$briefDir = Split-Path -Parent $brief
$binding = Resolve-HarnessPath -Root $Root -RelativePath "PROJECT_BINDING.yaml"
if (-not (Test-Path -LiteralPath $binding)) { Write-Error "PROJECT_BINDING.yaml missing" }
if ($CheckOnly -and -not (Test-Path -LiteralPath $brief)) { Write-Error "Claude reentry brief missing" }

if (-not $CheckOnly) {
  [void](Assert-OperationMutationAuthorized -RuntimeMode $RuntimeMode -ExpectedOperation 'claude-reentry:write-brief' -WritePaths @($brief) -DescriptorPath $OperationDescriptorPath -ApprovalStoreRoot $ScopedApprovalStoreRoot -ApprovalId $ScopedApprovalId -LockPath $OperationLockPath -JournalPath $OperationJournalPath)
  Ensure-Directory $briefDir
  $version = (Get-Content -LiteralPath (Join-Path $Root "HARNESS_VERSION") -TotalCount 1)
  $bindingText = [IO.File]::ReadAllText($binding)
  $statePath = Resolve-HarnessPath -Root $Root -RelativePath "orquestador/sdd/progress/state.yaml"
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
