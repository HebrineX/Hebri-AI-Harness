# claude-precompact-hook.ps1 - Claude Code PreCompact hook.
#
# Before the context is compacted it re-runs the memory-closure-checklist
# verification (same preconditions as the close_cycle_check MCP tool / CLI
# logic) and emits a summary of what would remain unclosed, so the session can
# persist that state to files BEFORE losing memory. Clean state = silence.
#
# Fail-open by design: any error in the hook itself exits 0 with no output.

$ErrorActionPreference = 'Stop'

try {
  [void][Console]::In.ReadToEnd()

  $harnessRoot = Split-Path -Parent $PSScriptRoot
  Import-Module (Join-Path $PSScriptRoot 'lib/hebri-common.psm1') -Force -DisableNameChecking -Scope Local

  $gaps = New-Object System.Collections.Generic.List[string]

  $statePath = Join-Path $harnessRoot 'orquestador/sdd/progress/state.yaml'
  if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
    $gaps.Add('falta orquestador/sdd/progress/state.yaml') | Out-Null
    $stateText = ''
  }
  else {
    $stateText = [IO.File]::ReadAllText($statePath)
  }

  # Locks reales (inventario de archivos, no solo state.yaml).
  $locks = Get-LockInventory -Root $harnessRoot
  if (($locks.Active.Count + $locks.Expired.Count) -gt 0) {
    $lockIds = @($locks.Active + $locks.Expired | ForEach-Object { $_.LockId })
    $gaps.Add("locks abiertos sin liberar: $($lockIds -join ', ')") | Out-Null
  }

  if (-not [string]::IsNullOrWhiteSpace($stateText)) {
    # open_locks / open_agents en state deben estar vacios o justificados.
    foreach ($key in @('open_locks', 'open_agents')) {
      $items = @(Get-YamlList -Text $stateText -Key $key)
      if ($items.Count -gt 0) {
        $gaps.Add("state.yaml ${key} no esta vacio: $($items -join ', ')") | Out-Null
      }
    }

    $cycleId = Get-SectionScalar -Text $stateText -Section 'active_cycle' -Key 'cycle_id'
    $cycleStatus = Get-SectionScalar -Text $stateText -Section 'active_cycle' -Key 'status'
    if (-not [string]::IsNullOrWhiteSpace($cycleId) -and $cycleStatus -notin @('', 'pending', 'done')) {
      $lastFinalReport = Get-Scalar -Text $stateText -Key 'last_final_report'
      if ([string]::IsNullOrWhiteSpace($lastFinalReport)) {
        $gaps.Add("ciclo $cycleId (status=$cycleStatus) sin last_final_report enlazado") | Out-Null
      }
      elseif (-not (Test-Path -LiteralPath (Join-Path $harnessRoot $lastFinalReport) -PathType Leaf)) {
        $gaps.Add("last_final_report apunta a archivo inexistente: $lastFinalReport") | Out-Null
      }
      $verificationStatus = Get-SectionScalar -Text $stateText -Section 'verification' -Key 'status'
      if ($verificationStatus -notin @('passed', 'not_applicable')) {
        $gaps.Add("verification.status=$verificationStatus (se espera passed o not_applicable antes de cerrar)") | Out-Null
      }
    }
  }

  # Archivos requeridos por el memory-closure-checklist.
  foreach ($rel in @(
    'orquestador/memory/local/active-contract.md',
    'orquestador/memory/local/current-focus.md',
    'orquestador/memory/local/session-pin.md',
    'orquestador/sdd/progress/registry.yaml',
    'orquestador/sdd/progress/templates/memory-closure-checklist.md'
  )) {
    if (-not (Test-Path -LiteralPath (Join-Path $harnessRoot $rel) -PathType Leaf)) {
      $gaps.Add("falta archivo de cierre de memoria: $rel") | Out-Null
    }
  }

  # Handoffs de continuidad abiertos.
  $progressDir = Join-Path $harnessRoot 'orquestador/sdd/progress'
  if (Test-Path -LiteralPath $progressDir -PathType Container) {
    foreach ($handoff in (Get-ChildItem -LiteralPath $progressDir -File -Filter 'HANDOFF-*.md' -ErrorAction SilentlyContinue)) {
      $gaps.Add("handoff de continuidad abierto: orquestador/sdd/progress/$($handoff.Name) (actualizarlo ANTES de compactar)") | Out-Null
    }
  }

  if ($gaps.Count -eq 0) { exit 0 }

  $message = "hebrinex precompact-check: la compactacion va a perder memoria de sesion y quedan $($gaps.Count) item(s) sin cerrar. Persistir a archivos antes de seguir:`n" +
    (($gaps | ForEach-Object { "- $_" }) -join "`n") +
    "`nChecklist: orquestador/sdd/progress/templates/memory-closure-checklist.md; recuperacion post-compactacion: entrypoint compactation_recovery."
  @{ systemMessage = $message } | ConvertTo-Json -Depth 3 -Compress
  exit 0
}
catch {
  exit 0
}
