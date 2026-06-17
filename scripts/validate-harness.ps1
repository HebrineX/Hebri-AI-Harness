param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$RunNegativeTests
)

$ErrorActionPreference = 'Stop'
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]

function Add-Failure([string]$Message) {
  $script:Failures.Add($Message) | Out-Null
}

function Add-Warning([string]$Message) {
  $script:Warnings.Add($Message) | Out-Null
}

function Resolve-HarnessPath([string]$RelativePath) {
  Join-Path $Root $RelativePath
}

function Read-HarnessText([string]$RelativePath) {
  $path = Resolve-HarnessPath $RelativePath
  if (-not (Test-Path -LiteralPath $path)) {
    Add-Failure "missing file: $RelativePath"
    return ''
  }
  $text = [IO.File]::ReadAllText($path)
  if ([string]::IsNullOrWhiteSpace($text)) {
    Add-Failure "empty file: $RelativePath"
  }
  return $text
}

function Assert-Contains([string]$RelativePath, [string]$Pattern, [string]$Message) {
  $text = Read-HarnessText $RelativePath
  if ($text -notmatch $Pattern) { Add-Failure $Message }
}

function Assert-NoContains([string]$RelativePath, [string]$Pattern, [string]$Message) {
  $text = Read-HarnessText $RelativePath
  if ($text -match $Pattern) { Add-Failure $Message }
}

function Get-TopLevelKeys([string]$Text) {
  $keys = New-Object System.Collections.Generic.HashSet[string]
  foreach ($line in ($Text -split "`n")) {
    if ($line -match '^([A-Za-z0-9_.-]+):') { [void]$keys.Add($Matches[1]) }
  }
  return $keys
}

function Assert-TopKeys([string]$RelativePath, [string[]]$Keys) {
  $text = Read-HarnessText $RelativePath
  $present = Get-TopLevelKeys $text
  foreach ($key in $Keys) {
    if (-not $present.Contains($key)) { Add-Failure "$RelativePath missing top-level key: $key" }
  }
}

function Assert-YamlSubsetHealth([string]$RelativePath) {
  $text = Read-HarnessText $RelativePath
  $lineNo = 0
  foreach ($line in ($text -split "`n")) {
    $lineNo++
    if ($line -match "`t") { Add-Failure "${RelativePath}:$lineNo contains tab indentation" }
    if ($line -match '(`n|\n)[0-9]+\.') { Add-Failure "${RelativePath}:$lineNo contains escaped newline artifact" }
    if ($line -match '^\s*-[^ ]') { Add-Failure "${RelativePath}:$lineNo has malformed list item spacing" }
    if ($line -match '\S\s{2,}-\s+\S' -and $line -notmatch '^\s*#') { Add-Failure "${RelativePath}:$lineNo may contain glued yaml/list content" }
  }
}

function Get-ScalarValue([string]$RelativePath, [string]$Key) {
  $text = Read-HarnessText $RelativePath
  foreach ($line in ($text -split "`n")) {
    if ($line -match ('^' + [regex]::Escape($Key) + ':\s*(.*)$')) {
      return $Matches[1].Trim().Trim('"')
    }
  }
  return ''
}

function Estimate-Tokens([string[]]$RelativePaths) {
  $chars = 0
  foreach ($rel in $RelativePaths) {
    $path = Resolve-HarnessPath $rel
    if (Test-Path -LiteralPath $path) { $chars += (Get-Item -LiteralPath $path).Length }
  }
  return [math]::Ceiling($chars / 4)
}

function Assert-Budget([string]$Name, [int]$MaxTokens, [string[]]$RelativePaths) {
  $used = Estimate-Tokens $RelativePaths
  $hardLimit = $MaxTokens * 2
  if ($used -gt $hardLimit) {
    Add-Failure "context budget hard limit exceeded: $Name uses $used > $hardLimit estimated tokens (soft budget $MaxTokens)"
  }
  elseif ($used -gt $MaxTokens) {
    Add-Warning "context budget soft limit exceeded: $Name uses $used > $MaxTokens estimated tokens (hard limit $hardLimit)"
  }
  else {
    Write-Host "budget ${Name}: $used/$MaxTokens"
  }
}

function Assert-PresetNotHeavyByDefault([string]$RelativePath) {
  $text = Read-HarnessText $RelativePath
  $hasAgents = $text -match 'AGENTS[.]md'
  $hasSession = $text -match 'session-contract[.]md'
  $hasState = $text -match 'state[.]yaml'
  $hasRegistry = $text -match 'registry[.]yaml'
  if ($hasAgents -and $hasSession -and $hasState -and $hasRegistry) {
    Add-Failure "$RelativePath loads AGENTS + session + state + registry by default"
  }
}


function Test-BoundCopySimulation() {
  $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('hebrinex-bound-test-' + [guid]::NewGuid().ToString('N'))
  $projectRoot = Join-Path $tempRoot 'project'
  $boundRoot = Join-Path $projectRoot '.hebrinex'
  New-Item -ItemType Directory -Force -Path $boundRoot | Out-Null
  $manifest = Read-HarnessText 'orquestador/harness-manifest.txt'
  foreach ($line in ($manifest -split "`n")) {
    if ($line -notmatch '^(dir|file)\s+(.+)$') { continue }
    $kind = $Matches[1]
    $rel = $Matches[2].Trim()
    if ($rel -eq 'infoHebri.md' -or $rel -like '.git/*') { continue }
    $src = Resolve-HarnessPath $rel
    $dst = Join-Path $boundRoot $rel
    if ($kind -eq 'dir') { New-Item -ItemType Directory -Force -Path $dst | Out-Null }
    if ($kind -eq 'file' -and (Test-Path -LiteralPath $src)) {
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
      Copy-Item -LiteralPath $src -Destination $dst -Force
    }
  }
  if (Test-Path -LiteralPath (Join-Path $boundRoot 'infoHebri.md')) {
    Add-Failure 'bound copy simulation copied infoHebri.md'
  }
  Remove-Item -LiteralPath $tempRoot -Recurse -Force
}

function Run-NegativeTests() {
  $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('hebrinex-negative-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
  try {
    $badManifest = 'file infoHebri.md'
    if ($badManifest -notmatch '^file infoHebri[.]md$') { Add-Failure 'negative test failed: manifest infoHebri rule did not trigger' }

    $badPreset = 'Leer AGENTS.md, session-contract.md, state.yaml y registry.yaml por defecto.'
    if (-not (($badPreset -match 'AGENTS[.]md') -and ($badPreset -match 'session-contract[.]md') -and ($badPreset -match 'state[.]yaml') -and ($badPreset -match 'registry[.]yaml'))) {
      Add-Failure 'negative test failed: heavy preset rule did not trigger'
    }

    $badYaml = "required_gates:  - G0_session_contract"
    if ($badYaml -notmatch '\S\s{2,}-\s+\S') { Add-Failure 'negative test failed: glued yaml rule did not trigger' }
  }
  finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

$Root = (Resolve-Path -LiteralPath $Root).Path
Write-Host "Validating Hebri-AI-Harness at $Root"

$manifestText = Read-HarnessText 'orquestador/harness-manifest.txt'
if ($manifestText -match '(?m)^file\s+infoHebri[.]md\s*$') { Add-Failure 'manifest must not include infoHebri.md' }
if (Test-Path -LiteralPath (Resolve-HarnessPath 'infoHebri.md')) { Add-Failure 'infoHebri.md must not exist inside harness repo or bound copy' }

foreach ($line in ($manifestText -split "`n")) {
  if ($line -notmatch '^(dir|file)\s+(.+)$') { continue }
  $kind = $Matches[1]
  $rel = $Matches[2].Trim()
  $path = Resolve-HarnessPath $rel
  if ($kind -eq 'dir' -and -not (Test-Path -LiteralPath $path -PathType Container)) { Add-Failure "manifest missing dir: $rel" }
  if ($kind -eq 'file') {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Add-Failure "manifest missing file: $rel" }
    elseif ((Get-Item -LiteralPath $path).Length -eq 0) { Add-Failure "manifest empty file: $rel" }
  }
}

$yamlFiles = @(
  'PROJECT_BINDING.yaml',
  'orquestador/context-budget.yaml',
  'orquestador/memory/memory-registry.yaml',
  'orquestador/sdd/progress/state.yaml',
  'orquestador/sdd/progress/registry.yaml'
)
foreach ($rel in $yamlFiles) { Assert-YamlSubsetHealth $rel }

Assert-TopKeys 'PROJECT_BINDING.yaml' @('schema','version','harness_version','binding_mode','harness_instance_id','project_name','project_root','repo_remote','source_repo','created_at','bound_at','notes')
Assert-TopKeys 'orquestador/context-budget.yaml' @('schema','version','harness_version','objective','default_policy','budgets','deny_by_default','required_context_report')
Assert-TopKeys 'orquestador/memory/memory-registry.yaml' @('schema','version','updated_at','owner_role','binding_mode','active_layers','load_order_default','conflict_resolution')
Assert-TopKeys 'orquestador/sdd/progress/state.yaml' @('schema','version','updated_at','mode','project_binding','session_contract','active_cycle','required_gates','conditional_gates','approvals','verification','open_locks','open_agents','last_final_report')
Assert-TopKeys 'orquestador/sdd/progress/registry.yaml' @('schema','version','updated_at','kanban_statuses','roles','profiles','cycles')

if ((Get-ScalarValue 'PROJECT_BINDING.yaml' 'harness_version') -ne '0.8.10') { Add-Failure 'PROJECT_BINDING.yaml harness_version must be 0.8.10' }
if ((Get-ScalarValue 'orquestador/context-budget.yaml' 'harness_version') -ne '0.8.10') { Add-Failure 'context-budget.yaml harness_version must be 0.8.10' }
if ((Get-ScalarValue 'PROJECT_BINDING.yaml' 'binding_mode') -notin @('source_template','bound')) { Add-Failure 'PROJECT_BINDING.yaml binding_mode invalid' }

Assert-Contains 'orquestador/context-budget.yaml' 'load_infohebri:\s+denied' 'context-budget must deny infoHebri loading'
Assert-Contains 'orquestador/context-budget.yaml' 'full_context_requires_approval:\s+true' 'full context must require approval'
Assert-Contains 'orquestador/memory/memory-registry.yaml' 'complete:\s*\n\s+enabled:\s+false' 'complete memory must be disabled by default'
Assert-Contains 'orquestador/memory/memory-registry.yaml' 'requires_approval:\s+true' 'complete memory must require approval'
Assert-Contains 'orquestador/method/final-report-evidence-policy.md' 'memory-closure-checklist[.]md' 'final report policy must require memory closure evidence'
Assert-Contains 'orquestador/sdd/progress/state.yaml' 'G5I_memory_consistency_complete' 'state must include memory consistency gate'
Assert-Contains 'orquestador/sdd/progress/state.yaml' 'G3A_detractor_senior_pre_implementation' 'state must include detractor senior pre-implementation gate'
Assert-Contains 'orquestador/method/agent-role-taxonomy.md' 'detractor_senior' 'detractor_senior profile missing from taxonomy'
Assert-Contains 'agents/detractor-senior.md' 'Veredicto: aceptar \| simplificar \| bloquear \| pedir evidencia' 'detractor senior output contract missing'
Assert-Contains 'orquestador/method/minimal-implementation-policy.md' 'Escalera Senior' 'minimal implementation policy missing senior ladder'
Assert-Contains 'orquestador/sdd/progress/templates/detractor-senior-checklist.md' 'Dependencia instalada no lo resuelve mejor' 'detractor senior checklist missing dependency check'
Assert-Contains 'prompts/detractor-senior.prompt.md' 'No implementes' 'detractor senior prompt must be read-only'
Assert-Contains 'orquestador/portability/adapter-matrix.yaml' 'generic-ai' 'adapter matrix must include generic-ai fallback'
Assert-Contains 'orquestador/portability/core-skills.yaml' 'detractor_senior' 'core skills must include detractor_senior'
Assert-Contains 'orquestador/policies/schemas/adapter.schema.yaml' 'memory_reliability' 'adapter schema must require memory reliability'
Assert-Contains 'scripts/check-adapter-drift.ps1' 'Adapter portability drift check' 'adapter drift checker missing success marker'
Assert-Contains 'orquestador/runtime/active-session.template.json' 'non_authoritative' 'active-session must declare non_authoritative'
Assert-Contains 'orquestador/runtime/README.md' 'No es autoridad' 'runtime README must state non-authority'
Assert-Contains 'orquestador/runtime/commands.md' '/harness status' 'runtime commands must define status'
Assert-Contains 'orquestador/context-budget.yaml' 'runtime_status' 'context-budget must define runtime_status'
Assert-Contains 'orquestador/context-budget.yaml' 'runtime_reentry' 'context-budget must define runtime_reentry'
Assert-Contains 'orquestador/memory/memory-routing.yaml' 'runtime_status' 'memory routing must define runtime_status'
Assert-Contains 'prompts/harness-runtime.prompt.md' 'active-session es cache' 'runtime prompt must keep active-session non-authoritative'
Assert-Contains 'orquestador/integrations/claude/settings.template.json' 'SessionStart' 'Claude settings must declare SessionStart hook'
Assert-Contains 'orquestador/integrations/claude/settings.template.json' 'UserPromptSubmit' 'Claude settings must declare UserPromptSubmit hook'
Assert-Contains 'orquestador/integrations/claude/CLAUDE.template.md' 'reentry-brief' 'CLAUDE template must point to reentry brief'
Assert-Contains 'orquestador/sdd/progress/templates/claude-reentry-state.yaml' 'non_authoritative: true' 'Claude reentry state must be non-authoritative'
Assert-Contains 'scripts/install-claude-hooks.ps1' 'Preflight only' 'Claude hook installer must be preflight-only'
Assert-Contains 'scripts/claude-reentry.ps1' 'Approvals expired' 'Claude reentry must expire approvals'
Assert-Contains 'orquestador/instruction-builder/instruction-registry.yaml' '0.8.10' 'instruction registry must match harness version'
Assert-Contains 'orquestador/instruction-builder/instruction-registry.yaml' 'generic-ai' 'instruction registry must include generic-ai target'
Assert-Contains 'orquestador/instruction-builder/fragments/denylists.md' 'infoHebri.md' 'instruction denylists must mention infoHebri'
Assert-Contains 'scripts/build-instructions.ps1' 'check-only passed' 'instruction builder must support check-only'
Assert-Contains 'scripts/validate-drift.ps1' 'Strong drift validation passed' 'strong drift validator missing success marker'
Assert-Contains 'scripts/regularize-state.ps1' 'CheckOnly: no files written' 'regularize-state must be check-only by default'
Assert-Contains 'scripts/regularize-registry.ps1' 'CheckOnly: no files written' 'regularize-registry must be check-only by default'
Assert-Contains 'scripts/regularize-state.ps1' 'Copy-Item' 'regularize-state must create backup before write'
Assert-Contains 'scripts/regularize-registry.ps1' 'Copy-Item' 'regularize-registry must create backup before write'
Assert-Contains 'scripts/build-instructions.ps1' 'ComputeHash' 'build-instructions must use PS 5.1 compatible ComputeHash'
Assert-NoContains 'scripts/build-instructions.ps1' 'HashData|ToHexString' 'build-instructions must not use PS 7-only hash APIs'
Assert-NoContains 'orquestador/harness-manifest.txt' 'infoHebri[.]md' 'manifest must exclude infoHebri.md'

Assert-PresetNotHeavyByDefault 'prompts/preset-codex.prompt.md'
Assert-PresetNotHeavyByDefault 'prompts/preset-claude.prompt.md'
Assert-PresetNotHeavyByDefault 'prompts/preset-gemini.prompt.md'

Assert-Budget 'memory_bootstrap' 1700 @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/reentry-light.md')
Assert-Budget 'first_message' 1800 @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/first-message.md')
Assert-Budget 'debug_log_intake' 2000 @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/debug-log-intake.md','orquestador/entrypoints/reentry-light.md')
Assert-Budget 'leader_light' 2600 @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/sdd/progress/state.yaml','orquestador/sdd/progress/registry.yaml','orquestador/method/session-contract.md')

foreach ($jsonRel in @('orquestador/integrations/claude/settings.template.json','orquestador/runtime/active-session.template.json','orquestador/runtime/schemas/active-session.schema.json','orquestador/runtime/schemas/harness-command.schema.json','orquestador/runtime/templates/command-result.template.json','orquestador/runtime/templates/budget-report.template.json','orquestador/runtime/templates/reentry-result.template.json','orquestador/sdd/progress/templates/runtime-audit-report.json')) {
  try { [void](Read-HarnessText $jsonRel | ConvertFrom-Json) }
  catch { Add-Failure "$jsonRel must be valid JSON" }
}
Assert-Budget 'runtime_status' 900 @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/context-budget.yaml','orquestador/runtime/active-session.template.json')
Assert-Budget 'runtime_reentry' 1600 @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/context-budget.yaml','orquestador/runtime/active-session.template.json','orquestador/sdd/progress/state.yaml','orquestador/sdd/progress/registry.yaml')

try { & (Resolve-HarnessPath 'scripts/build-instructions.ps1') -Root $Root | Out-Null } catch { Add-Failure 'build-instructions.ps1 must pass check-only' }
try { & (Resolve-HarnessPath 'scripts/validate-drift.ps1') -Root $Root -RunNegativeTests | Out-Null } catch { Add-Failure 'validate-drift.ps1 must pass negative tests' }
try { & (Resolve-HarnessPath 'scripts/regularize-state.ps1') -Root $Root | Out-Null } catch { Add-Failure 'regularize-state.ps1 must pass on current state' }
try { & (Resolve-HarnessPath 'scripts/regularize-registry.ps1') -Root $Root | Out-Null } catch { Add-Failure 'regularize-registry.ps1 must pass on current registry' }

Test-BoundCopySimulation
if ($RunNegativeTests) { Run-NegativeTests }

if ($script:Warnings.Count -gt 0) {
  Write-Host 'Validation warnings:'
  foreach ($warning in $script:Warnings) { Write-Host "- $warning" }
}

if ($script:Failures.Count -gt 0) {
  Write-Host 'Validation failed:'
  foreach ($failure in $script:Failures) { Write-Host "- $failure" }
  exit 2
}

Write-Host 'OK. Harness validation passed.'
exit 0
