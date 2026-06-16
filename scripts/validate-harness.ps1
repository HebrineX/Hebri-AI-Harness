param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$RunNegativeTests
)

$ErrorActionPreference = 'Stop'
$script:Failures = New-Object System.Collections.Generic.List[string]

function Add-Failure([string]$Message) {
  $script:Failures.Add($Message) | Out-Null
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
  if ($used -gt $MaxTokens) { Add-Failure "context budget exceeded: $Name uses $used > $MaxTokens estimated tokens" }
  else { Write-Host "budget ${Name}: $used/$MaxTokens" }
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

if ((Get-ScalarValue 'PROJECT_BINDING.yaml' 'harness_version') -ne '0.8.4') { Add-Failure 'PROJECT_BINDING.yaml harness_version must be 0.8.4' }
if ((Get-ScalarValue 'orquestador/context-budget.yaml' 'harness_version') -ne '0.8.4') { Add-Failure 'context-budget.yaml harness_version must be 0.8.4' }
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
Assert-NoContains 'orquestador/harness-manifest.txt' 'infoHebri[.]md' 'manifest must exclude infoHebri.md'

Assert-PresetNotHeavyByDefault 'prompts/preset-codex.prompt.md'
Assert-PresetNotHeavyByDefault 'prompts/preset-claude.prompt.md'
Assert-PresetNotHeavyByDefault 'prompts/preset-gemini.prompt.md'

Assert-Budget 'memory_bootstrap' 1500 @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/reentry-light.md')
Assert-Budget 'first_message' 1800 @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/first-message.md')
Assert-Budget 'debug_log_intake' 2000 @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/debug-log-intake.md','orquestador/entrypoints/reentry-light.md')
Assert-Budget 'leader_light' 2400 @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/sdd/progress/state.yaml','orquestador/sdd/progress/registry.yaml','orquestador/method/session-contract.md')

Test-BoundCopySimulation
if ($RunNegativeTests) { Run-NegativeTests }

if ($script:Failures.Count -gt 0) {
  Write-Host 'Validation failed:'
  foreach ($failure in $script:Failures) { Write-Host "- $failure" }
  exit 2
}

Write-Host 'OK. Harness validation passed.'
exit 0