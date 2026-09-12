# claude-stop-hook.ps1 - Claude Code Stop hook.
#
# At the end of each turn it inspects the harness state: active/expired locks,
# non-expired approval envelopes, an active cycle that is not closed, and
# HANDOFF-* continuity files. If anything is open it emits a visible warning
# via systemMessage WITHOUT blocking the stop; if everything is clean it stays
# silent (exit 0, no output).
#
# Fail-open by design: any error in the hook itself exits 0 with no output.

param(
  [ValidateSet('source_template','legacy_bound','central_instance')][string]$RuntimeMode = 'source_template',
  [string]$InstallRoot = (Split-Path -Parent $PSScriptRoot),
  [string]$ProjectRoot = '',
  [string]$CatalogRoot = ''
)

$ErrorActionPreference = 'Stop'

try {
  # Consume stdin so the hook never blocks on the payload pipe.
  [void][Console]::In.ReadToEnd()

  $harnessRoot = [IO.Path]::GetFullPath($InstallRoot)
  Import-Module (Join-Path $PSScriptRoot 'lib/hebri-common.psm1') -Force -DisableNameChecking -Scope Local
  $stateRoot = $harnessRoot
  $instanceRoot = ''
  if ($RuntimeMode -eq 'central_instance') {
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot = (Get-Location).Path }
    $context = Resolve-HebriRuntimeContext -InstallRoot $harnessRoot -ProjectRoot $ProjectRoot -DeploymentMode central_instance -CatalogRoot $CatalogRoot
    $stateRoot = Join-Path ([string]$context.project_root) '.hebrinex'
    $instanceRoot = [string]$context.instance_root
  }

  $warnings = New-Object System.Collections.Generic.List[string]

  # 1) Locks.
  $locks = Get-LockInventory -Root $stateRoot
  foreach ($lock in $locks.Active) {
    [void]$warnings.Add("lock activo: $($lock.LockId) (owner=$($lock.Owner), paths=$($lock.Paths -join ','), expires_at=$($lock.ExpiresAt))")
  }
  foreach ($lock in $locks.Expired) {
    [void]$warnings.Add("lock VENCIDO sin liberar: $($lock.LockId) (owner=$($lock.Owner), expires_at=$($lock.ExpiresAt))")
  }

  # 2) Approval envelopes still valid (approved and not expired).
  $approvalsDir = Resolve-HarnessPath -Root $stateRoot -RelativePath 'orquestador/sdd/progress/approvals'
  if (Test-Path -LiteralPath $approvalsDir -PathType Container) {
    $now = (Get-Date).ToUniversalTime()
    foreach ($file in (Get-ChildItem -LiteralPath $approvalsDir -File -Filter 'APR-*.yaml' -ErrorAction SilentlyContinue)) {
      $text = [IO.File]::ReadAllText($file.FullName)
      if ((Get-Scalar -Text $text -Key 'status') -ne 'approved') { continue }
      $expiresAt = Get-Scalar -Text $text -Key 'expires_at'
      $expiresParsed = [datetime]::MinValue
      $hasExpiry = -not [string]::IsNullOrWhiteSpace($expiresAt) -and [datetime]::TryParse($expiresAt, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$expiresParsed)
      if ($hasExpiry -and $expiresParsed -gt $now) {
        [void]$warnings.Add("approval activo sin consumir: $($file.BaseName) (expires_at=$expiresAt)")
      }
    }
  }

  if ($RuntimeMode -eq 'central_instance') {
    $scopedApprovalsDir = Join-Path $instanceRoot 'runtime/approvals'
    if (Test-Path -LiteralPath $scopedApprovalsDir -PathType Container) {
      $now = (Get-Date).ToUniversalTime()
      foreach ($file in @(Get-ChildItem -LiteralPath $scopedApprovalsDir -File -Filter 'APR2-*.json' -ErrorAction SilentlyContinue)) {
        try {
          $approval = [IO.File]::ReadAllText($file.FullName) | ConvertFrom-Json
          $expires = [datetime]::Parse([string]$approval.expires_at).ToUniversalTime()
          if ([string]$approval.status -eq 'approved' -and $expires -gt $now) { [void]$warnings.Add("scoped approval activo sin consumir: $($file.BaseName) (expires_at=$($approval.expires_at))") }
        }
        catch { [void]$warnings.Add("scoped approval ilegible: $($file.Name)") }
      }
    }
  }

  # 3) Active cycle not closed (state.yaml is the authority).
  $statePath = Resolve-HarnessPath -Root $stateRoot -RelativePath 'orquestador/sdd/progress/state.yaml'
  if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    $stateText = [IO.File]::ReadAllText($statePath)
    $cycleId = Get-SectionScalar -Text $stateText -Section 'active_cycle' -Key 'cycle_id'
    $cycleStatus = Get-SectionScalar -Text $stateText -Section 'active_cycle' -Key 'status'
    if (-not [string]::IsNullOrWhiteSpace($cycleId) -and $cycleStatus -notin @('', 'pending', 'done')) {
      [void]$warnings.Add("ciclo activo sin cerrar: $cycleId (status=$cycleStatus); gates del ciclo pendientes de resolver")
    }
  }

  # 4) Continuity handoffs.
  $progressDir = Resolve-HarnessPath -Root $stateRoot -RelativePath 'orquestador/sdd/progress'
  if (Test-Path -LiteralPath $progressDir -PathType Container) {
    foreach ($handoff in (Get-ChildItem -LiteralPath $progressDir -File -Filter 'HANDOFF-*.md' -ErrorAction SilentlyContinue)) {
      [void]$warnings.Add("handoff de continuidad pendiente: orquestador/sdd/progress/$($handoff.Name)")
    }
  }

  if ($warnings.Count -eq 0) { exit 0 }

  $message = "hebrinex stop-check: quedan $($warnings.Count) pendiente(s) del harness:`n" +
    (($warnings | ForEach-Object { "- $_" }) -join "`n")
  @{ systemMessage = $message } | ConvertTo-Json -Depth 3 -Compress
  exit 0
}
catch {
  exit 0
}
