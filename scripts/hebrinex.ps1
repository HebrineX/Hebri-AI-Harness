param(
  [Parameter(Position = 0)]
  [ValidateSet('help','status','budget','preflight','validate','audit','migrate','bootstrap','command')]
  [string]$Command = 'help',
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$RunNegativeTests,
  [switch]$CheckOnly,
  [switch]$Apply,
  [string]$TargetVersion = '0.10.0',
  [string]$ProjectRoot = '',
  [string]$ApprovalId = '',
  [string]$Action = '',
  [string]$ReadSet = '',
  [string]$WriteSet = '',
  [string]$Risk = 'bajo',
  [string]$Verification = '',
  [string]$CommandText = '',
  [string]$Purpose = '',
  [string]$RiskClass = ''
)

$ErrorActionPreference = 'Stop'

function Resolve-HarnessPath([string]$RelativePath) {
  Join-Path $Root $RelativePath
}

function Read-HarnessText([string]$RelativePath) {
  $path = Resolve-HarnessPath $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "missing file: $RelativePath"
  }
  return [IO.File]::ReadAllText($path)
}

function Get-Scalar([string]$Text, [string]$Key) {
  foreach ($line in ($Text -split "`n")) {
    if ($line -match ('^\s*' + [regex]::Escape($Key) + ':\s*(.*)$')) {
      return $Matches[1].Trim().Trim('"').Trim("'")
    }
  }
  return ''
}

function Get-SectionScalar([string]$Text, [string]$Section, [string]$Key) {
  $inside = $false
  foreach ($line in ($Text -split "`n")) {
    if ($line -match ('^' + [regex]::Escape($Section) + ':\s*$')) {
      $inside = $true
      continue
    }
    if ($inside -and $line -match '^[A-Za-z0-9_.-]+:\s*') {
      $inside = $false
    }
    if ($inside -and $line -match ('^\s+' + [regex]::Escape($Key) + ':\s*(.*)$')) {
      return $Matches[1].Trim().Trim('"').Trim("'")
    }
  }
  return ''
}

function Get-InlineBudget([string]$BudgetText, [string]$Name) {
  foreach ($line in ($BudgetText -split "`n")) {
    if ($line -match ('^\s*' + [regex]::Escape($Name) + ':\s*\{[^}]*max_tokens(?:_before_user_logs)?:\s*([0-9]+)')) {
      return [int]$Matches[1]
    }
  }
  return 0
}

function Estimate-Tokens([string[]]$RelativePaths) {
  $chars = 0
  foreach ($rel in $RelativePaths) {
    $path = Resolve-HarnessPath $rel
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      $chars += (Get-Item -LiteralPath $path).Length
    }
  }
  return [math]::Ceiling($chars / 4)
}

function Write-BudgetLine([string]$Name, [int]$MaxTokens, [string[]]$RelativePaths) {
  $used = Estimate-Tokens $RelativePaths
  $hard = $MaxTokens * 2
  $status = 'ok'
  if ($used -gt $hard) { $status = 'block' }
  elseif ($used -gt $MaxTokens) { $status = 'warn' }
  Write-Host "$Name=$used/$MaxTokens hard=$hard status=$status"
}

function Invoke-ChildScript {
  param(
    [string]$RelativePath,
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$Arguments
  )
  $scriptPath = Resolve-HarnessPath $RelativePath
  if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "missing script: $RelativePath"
  }
  & $scriptPath @Arguments
  $exitCode = $LASTEXITCODE
  if ($null -ne $exitCode -and $exitCode -ne 0) {
    exit $exitCode
  }
}

function Show-Help() {
  Write-Host 'Hebri-AI-Harness CLI Core'
  Write-Host ''
  Write-Host 'Usage:'
  Write-Host '  hebrinex.ps1 status [-Root <path>]'
  Write-Host '  hebrinex.ps1 budget [-Root <path>]'
  Write-Host '  hebrinex.ps1 preflight [-ApprovalId <id>] [-Action <text>] [-ReadSet <text>] [-WriteSet <text>]'
  Write-Host '  hebrinex.ps1 validate [-RunNegativeTests]'
  Write-Host '  hebrinex.ps1 audit [-RunNegativeTests]'
  Write-Host '  hebrinex.ps1 migrate -CheckOnly|-Apply [-TargetVersion 0.10.0]'
  Write-Host '  hebrinex.ps1 bootstrap -CheckOnly [-ProjectRoot <path>]'
  Write-Host '  hebrinex.ps1 command -CheckOnly -CommandText <command> [-Purpose <text>]'
}

$Root = (Resolve-Path -LiteralPath $Root).Path

switch ($Command) {
  'help' {
    Show-Help
  }
  'status' {
    $bindingText = Read-HarnessText 'PROJECT_BINDING.yaml'
    $stateText = Read-HarnessText 'orquestador/sdd/progress/state.yaml'
    $version = (Read-HarnessText 'HARNESS_VERSION').Trim()
    Write-Host 'Hebri-AI-Harness status'
    Write-Host "root=$Root"
    Write-Host "harness_version=$version"
    Write-Host "binding_mode=$(Get-Scalar $bindingText 'binding_mode')"
    Write-Host "project_root=$(Get-Scalar $bindingText 'project_root')"
    Write-Host "state_mode=$(Get-Scalar $stateText 'mode')"
    Write-Host "project_binding_status=$(Get-SectionScalar $stateText 'project_binding' 'status')"
    Write-Host "session_contract_status=$(Get-SectionScalar $stateText 'session_contract' 'status')"
    Write-Host "active_cycle_status=$(Get-SectionScalar $stateText 'active_cycle' 'status')"
    Write-Host "active_approval_id=$(Get-SectionScalar $stateText 'approvals' 'active_approval_id')"
    Write-Host 'runtime_authority=non_authoritative'
  }
  'budget' {
    $budgetText = Read-HarnessText 'orquestador/context-budget.yaml'
    Write-Host 'Hebri-AI-Harness budget'
    Write-BudgetLine 'memory_bootstrap' (Get-InlineBudget $budgetText 'memory_bootstrap') @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/reentry-light.md')
    Write-BudgetLine 'first_message' (Get-InlineBudget $budgetText 'first_message') @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/first-message.md')
    Write-BudgetLine 'debug_log_intake' (Get-InlineBudget $budgetText 'debug_log_intake') @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/debug-log-intake.md','orquestador/entrypoints/reentry-light.md')
    Write-BudgetLine 'leader_light' (Get-InlineBudget $budgetText 'leader_light') @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/sdd/progress/state.yaml','orquestador/sdd/progress/registry.yaml','orquestador/method/session-contract.md')
    Write-BudgetLine 'runtime_status' (Get-InlineBudget $budgetText 'runtime_status') @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/context-budget.yaml','orquestador/runtime/active-session.template.json')
    Write-BudgetLine 'runtime_reentry' (Get-InlineBudget $budgetText 'runtime_reentry') @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/context-budget.yaml','orquestador/runtime/active-session.template.json','orquestador/sdd/progress/state.yaml','orquestador/sdd/progress/registry.yaml')
  }
  'preflight' {
    Write-Host "Approval ID: $ApprovalId"
    Write-Host "Accion propuesta: $Action"
    Write-Host "CWD: $Root"
    Write-Host "Read-set: $ReadSet"
    Write-Host "Write-set: $WriteSet"
    Write-Host 'Comando/tool: scripts/hebrinex.ps1'
    Write-Host 'Red/git/externo: no por defecto'
    Write-Host "Riesgo: $Risk"
    Write-Host "Verificacion: $Verification"
    Write-Host 'Evidencia esperada: salida de comando y validadores aplicables'
    Write-Host 'Requiere SI: SI'
  }
  'validate' {
    $scriptPath = Resolve-HarnessPath 'scripts/validate-harness.ps1'
    if ($RunNegativeTests) { & $scriptPath -Root $Root -RunNegativeTests }
    else { & $scriptPath -Root $Root }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
  'audit' {
    $scriptPath = Resolve-HarnessPath 'scripts/audit-harness.ps1'
    if ($RunNegativeTests) { & $scriptPath -Root $Root -RunNegativeTests }
    else { & $scriptPath -Root $Root }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
  'migrate' {
    if (($CheckOnly -and $Apply) -or (-not $CheckOnly -and -not $Apply)) {
      throw 'migrate requires exactly one mode: -CheckOnly or -Apply'
    }
    $currentVersion = (Read-HarnessText 'HARNESS_VERSION').Trim()
    if ($currentVersion -eq $TargetVersion) {
      if ($CheckOnly) {
        Write-Host 'Hebri-AI-Harness migration CheckOnly'
        Write-Host "root=$Root"
        Write-Host "detected_version=$currentVersion"
        Write-Host "target_version=$TargetVersion"
        Write-Host 'migration_required=false'
        Write-Host 'writes=false'
        break
      }
      throw "current version already equals target version: $TargetVersion"
    }
    $scriptPath = Resolve-HarnessPath 'scripts/migrate-harness.ps1'
    if ($CheckOnly) { & $scriptPath -Root $Root -TargetVersion $TargetVersion -CheckOnly }
    else { & $scriptPath -Root $Root -TargetVersion $TargetVersion -Apply }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
  'bootstrap' {
    if (-not $CheckOnly -or $Apply) {
      throw 'bootstrap currently supports -CheckOnly only. Apply belongs to a later slice.'
    }
    $bindingText = Read-HarnessText 'PROJECT_BINDING.yaml'
    Write-Host 'Hebri-AI-Harness bootstrap CheckOnly'
    Write-Host "source_root=$Root"
    Write-Host "source_binding_mode=$(Get-Scalar $bindingText 'binding_mode')"
    Write-Host "target_project_root=$ProjectRoot"
    Write-Host 'planned_steps:'
    Write-Host ' - validate source_template'
    Write-Host ' - copy source to <project_root>/.hebrinex'
    Write-Host ' - exclude .git, .codex, local personal documentation and temporary files'
    Write-Host ' - set PROJECT_BINDING.yaml to bound'
    Write-Host ' - ensure consumer .gitignore excludes .hebrinex/'
    Write-Host ' - run validate-harness.ps1 and init.sh'
    Write-Host 'writes=false'
  }
  'command' {
    if (-not $CheckOnly -or $Apply) {
      throw 'command currently supports -CheckOnly only. Apply belongs to a later slice.'
    }
    $scriptPath = Resolve-HarnessPath 'scripts/command-gateway.ps1'
    & $scriptPath -Root $Root -CheckOnly -CommandText $CommandText -Purpose $Purpose -ApprovalId $ApprovalId -RiskClass $RiskClass
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
}
