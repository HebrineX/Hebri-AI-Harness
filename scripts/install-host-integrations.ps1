param(
  [Parameter(Mandatory = $true)][ValidateSet('claude', 'cursor', 'copilot')][string]$HostName,
  [string]$ProjectRoot = (Resolve-Path .).Path,
  [string]$CatalogRoot = '',
  [switch]$CheckOnly,
  [switch]$Apply,
  [ValidateSet('source_template','legacy_bound','central_instance')][string]$RuntimeMode = 'source_template',
  [string]$OperationDescriptorPath = '',
  [string]$ScopedApprovalStoreRoot = '',
  [string]$ScopedApprovalId = '',
  [string]$OperationLockPath = '',
  [string]$OperationJournalPath = ''
)

# Instala en un proyecto consumidor las integraciones nativas GENERADAS por
# scripts/build-instructions.ps1 (mismo patron que install-claude-hooks.ps1):
# - claude: CLAUDE.md + subagentes de rol read-only -> <project>/.claude/agents/
# - cursor: reglas persistentes -> <project>/.cursor/rules/hebrinex.mdc
# - copilot: instrucciones persistentes -> <project>/.github/copilot-instructions.md
# Los templates viven en orquestador/integrations/<host>/ y NUNCA se editan a
# mano (fuente unica agents/<rol>.md y fragments del instruction-builder).

$ErrorActionPreference = 'Stop'

if (($CheckOnly -and $Apply) -or (-not $CheckOnly -and -not $Apply)) {
  throw 'install-host-integrations requires exactly one mode: -CheckOnly or -Apply'
}

$harnessRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $PSScriptRoot 'lib/hebri-common.psm1') -Force -DisableNameChecking -Prefix 'Op' -Scope Local

if ($RuntimeMode -eq 'central_instance') {
  [void](Resolve-OpHebriRuntimeContext -InstallRoot $harnessRoot -ProjectRoot $ProjectRoot -DeploymentMode central_instance -CatalogRoot $CatalogRoot)
}

$plan = switch ($HostName) {
  'claude' {
    @(
      @{ Source = 'orquestador/integrations/claude/CLAUDE.template.md'; Target = 'CLAUDE.md' },
      @{ Source = 'orquestador/integrations/claude/agents/auditor-detractor.md'; Target = '.claude/agents/auditor-detractor.md' },
      @{ Source = 'orquestador/integrations/claude/agents/reviewer.md'; Target = '.claude/agents/reviewer.md' }
    )
  }
  'cursor' {
    @(
      @{ Source = 'orquestador/integrations/cursor/rules/hebrinex.mdc'; Target = '.cursor/rules/hebrinex.mdc' }
    )
  }
  'copilot' {
    @(
      @{ Source = 'orquestador/integrations/copilot/copilot-instructions.md'; Target = '.github/copilot-instructions.md' }
    )
  }
}

foreach ($step in $plan) {
  $sourcePath = Join-Path $harnessRoot $step.Source
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "missing harness template: $($step.Source) (regenerar con scripts/build-instructions.ps1 -WriteOutputs)"
  }
}

Write-Host 'Hebri-AI-Harness host integrations installer'
Write-Host "host=$HostName"
Write-Host "project_root=$ProjectRoot"
Write-Host "harness_root=$harnessRoot"

if ($CheckOnly) {
  Write-Host 'planned_steps:'
  foreach ($step in $plan) {
    Write-Host " - copy $($step.Source) -> $($step.Target)"
  }
  Write-Host 'writes=false'
  Write-Host 'apply_available=true'
  exit 0
}

$integrationTargets = @($plan | ForEach-Object { Join-Path $ProjectRoot $_.Target })
[void](Assert-OpOperationMutationAuthorized -RuntimeMode $RuntimeMode -ExpectedOperation 'install-host-integrations:apply' -WritePaths $integrationTargets -DescriptorPath $OperationDescriptorPath -ApprovalStoreRoot $ScopedApprovalStoreRoot -ApprovalId $ScopedApprovalId -LockPath $OperationLockPath -JournalPath $OperationJournalPath)

foreach ($step in $plan) {
  $sourcePath = Join-Path $harnessRoot $step.Source
  $targetPath = Join-Path $ProjectRoot $step.Target
  $targetDir = Split-Path -Parent $targetPath
  if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
  }
  $content = [IO.File]::ReadAllText($sourcePath) -replace "`r`n", "`n"
  [IO.File]::WriteAllText($targetPath, $content, [Text.UTF8Encoding]::new($false))
  Write-Host "installed: $($step.Target)"
}

Write-Host 'writes=true'
Write-Host 'install_status=applied'
exit 0
