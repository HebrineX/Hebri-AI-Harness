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

function Invoke-Validator([string]$Name, [string]$RelativePath) {
  $path = Resolve-HarnessPath $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    Add-Failure "missing validator: $Name ($RelativePath)"
    return
  }

  Write-Host "validator ${Name}"
  if ($RunNegativeTests) {
    & $path -Root $Root -RunNegativeTests
  }
  else {
    & $path -Root $Root
  }
  if ($LASTEXITCODE -ne 0) {
    Add-Failure "$Name failed with exit code $LASTEXITCODE"
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


function Get-RegistryReferencedPaths([string]$RelativePath) {
  $text = Read-HarnessText $RelativePath
  $paths = New-Object System.Collections.Generic.List[string]
  foreach ($line in ($text -split "`n")) {
    $candidate = $null
    if ($line -match '^\s*path:\s*"?([^"#]+)"?\s*$') { $candidate = $Matches[1].Trim() }
    elseif ($line -match '^\s*-\s+((agents|orquestador|prompts|scripts)/[^"#]+|README[.]md|CHANGELOG[.]md|HARNESS_VERSION|PROGRESS[.]md|PROJECT_BINDING[.]yaml|init[.]sh)\s*$') { $candidate = $Matches[1].Trim() }
    if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
    $candidate = $candidate.Trim().Trim('"').Trim("'")
    if ($candidate -match '[*]') { continue }
    [void]$paths.Add($candidate)
  }
  return $paths
}

function Assert-RegistryReferencedPathsExist([string]$RelativePath) {
  foreach ($rel in (Get-RegistryReferencedPaths $RelativePath)) {
    $path = Resolve-HarnessPath $rel
    if (-not (Test-Path -LiteralPath $path)) { Add-Failure "$RelativePath references missing path: $rel" }
  }
}

function Assert-GateRegistryMatchesState() {
  $gateRegistry = Read-HarnessText 'orquestador/gate-registry.yaml'
  $state = Read-HarnessText 'orquestador/sdd/progress/state.yaml'
  foreach ($line in ($gateRegistry -split "`n")) {
    if ($line -match '^\s*-\s+id:\s*([A-Z0-9_]+)') {
      $gateId = $Matches[1]
      if ($state -notmatch [regex]::Escape($gateId)) { Add-Failure "gate-registry declares $gateId but state.yaml does not contain it" }
    }
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
$currentHarnessVersion = (Read-HarnessText 'HARNESS_VERSION').Trim()
if ($currentHarnessVersion -notmatch '^0[.][0-9]+[.][0-9]+$') { Add-Failure 'HARNESS_VERSION must be SemVer 0.x.y' }

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
  'orquestador/registry-index.yaml',
  'orquestador/prompt-registry.yaml',
  'orquestador/adapter-registry.yaml',
  'orquestador/context-profile-registry.yaml',
  'orquestador/gate-registry.yaml',
  'orquestador/policy-registry.yaml',
  'orquestador/template-registry.yaml',
  'orquestador/agents/agent-registry.yaml',
  'orquestador/agents/capability-registry.yaml',
  'orquestador/agents/lifecycle-registry.yaml',
  'orquestador/agents/model-adapter-profiles.yaml',
  'orquestador/security/permission-registry.yaml',
  'orquestador/security/command-risk-registry.yaml',
  'orquestador/security/write-scope-registry.yaml',
  'orquestador/security/network-policy.yaml',
  'orquestador/security/secrets-policy.yaml',
  'orquestador/security/escalation-policy.yaml',
  'orquestador/security/logging-policy.yaml',
  'orquestador/security/supply-chain-policy.yaml',
  'orquestador/security/threat-model.yaml',
  'orquestador/migration/migration-registry.yaml',
  'orquestador/migration/versions/0.9.0-to-0.10.0.yaml',
  'orquestador/migration/versions/0.8.10-to-0.10.0.yaml',
  'orquestador/migration/contracts/post-migration-contract.yaml',
  'orquestador/migration/reports/migration-report.template.yaml',
  'orquestador/policies/schemas/agent-registry.schema.yaml',
  'orquestador/policies/schemas/agent-role-contract.schema.yaml',
  'orquestador/policies/schemas/security-policy.schema.yaml',
  'orquestador/policies/schemas/migration-registry.schema.yaml',
  'orquestador/testing/fixtures/positive/agent-registry-minimal.yaml',
  'orquestador/testing/fixtures/negative/agent-ai-defined-agent.yaml',
  'orquestador/testing/fixtures/negative/agent-reviewer-write.yaml',
  'orquestador/testing/fixtures/negative/agent-implementer-approve.yaml',
  'orquestador/testing/fixtures/negative/security-network-default-allow.yaml',
  'orquestador/testing/fixtures/negative/security-path-traversal.yaml',
  'orquestador/testing/fixtures/negative/migration-checkonly-writes.yaml',
  'orquestador/sdd/progress/state.yaml',
  'orquestador/sdd/progress/registry.yaml'
)
foreach ($rel in $yamlFiles) { Assert-YamlSubsetHealth $rel }

Assert-TopKeys 'PROJECT_BINDING.yaml' @('schema','version','harness_version','binding_mode','harness_instance_id','project_name','project_root','repo_remote','source_repo','created_at','bound_at','notes')
Assert-TopKeys 'orquestador/context-budget.yaml' @('schema','version','harness_version','objective','default_policy','budgets','deny_by_default','required_context_report')
Assert-TopKeys 'orquestador/registry-index.yaml' @('schema','version','harness_version','registries','rules')
Assert-TopKeys 'orquestador/prompt-registry.yaml' @('schema','version','harness_version','root','categories','rules')
Assert-TopKeys 'orquestador/adapter-registry.yaml' @('schema','version','harness_version','canonical_sources','adapters','rules')
Assert-TopKeys 'orquestador/context-profile-registry.yaml' @('schema','version','harness_version','source','profiles','special_profiles','rules')
Assert-TopKeys 'orquestador/gate-registry.yaml' @('schema','version','harness_version','state_source','registry_source','required_gates','conditional_gates','rules')
Assert-TopKeys 'orquestador/policy-registry.yaml' @('schema','version','harness_version','categories','rules')
Assert-TopKeys 'orquestador/template-registry.yaml' @('schema','version','harness_version','categories','rules')
Assert-TopKeys 'orquestador/agents/agent-registry.yaml' @('schema','version','harness_version','status','authority','resolution','roles','limits')
Assert-TopKeys 'orquestador/agents/capability-registry.yaml' @('schema','version','harness_version','defaults','capabilities','role_defaults')
Assert-TopKeys 'orquestador/agents/lifecycle-registry.yaml' @('schema','version','harness_version','states','transitions','rules')
Assert-TopKeys 'orquestador/security/permission-registry.yaml' @('schema','version','harness_version','precedence','defaults','permissions','role_denies')
Assert-TopKeys 'orquestador/security/threat-model.yaml' @('schema','version','harness_version','scope','actors','attack_surfaces','threats','defaults')
Assert-TopKeys 'orquestador/migration/migration-registry.yaml' @('schema','version','harness_version','status','authority','supported_targets','routes','required_contracts','required_report_template','required_validators','preserve_by_default','rules')
Assert-TopKeys 'orquestador/memory/memory-registry.yaml' @('schema','version','updated_at','owner_role','binding_mode','active_layers','load_order_default','conflict_resolution')
Assert-TopKeys 'orquestador/sdd/progress/state.yaml' @('schema','version','updated_at','mode','project_binding','session_contract','active_cycle','required_gates','conditional_gates','approvals','verification','open_locks','open_agents','last_final_report')
Assert-TopKeys 'orquestador/sdd/progress/registry.yaml' @('schema','version','updated_at','kanban_statuses','roles','profiles','cycles')

if ((Get-ScalarValue 'PROJECT_BINDING.yaml' 'harness_version') -ne $currentHarnessVersion) { Add-Failure "PROJECT_BINDING.yaml harness_version must be $currentHarnessVersion" }
if ((Get-ScalarValue 'orquestador/context-budget.yaml' 'harness_version') -ne $currentHarnessVersion) { Add-Failure "context-budget.yaml harness_version must be $currentHarnessVersion" }
if ((Get-ScalarValue 'PROJECT_BINDING.yaml' 'binding_mode') -notin @('source_template','bound')) { Add-Failure 'PROJECT_BINDING.yaml binding_mode invalid' }

foreach ($registryRel in @(
  'orquestador/registry-index.yaml',
  'orquestador/prompt-registry.yaml',
  'orquestador/adapter-registry.yaml',
  'orquestador/context-profile-registry.yaml',
  'orquestador/gate-registry.yaml',
  'orquestador/policy-registry.yaml',
  'orquestador/template-registry.yaml'
)) { Assert-RegistryReferencedPathsExist $registryRel }
Assert-GateRegistryMatchesState
Assert-Contains 'orquestador/context-budget.yaml' 'load_infohebri:\s+denied' 'context-budget must deny infoHebri loading'
Assert-Contains 'orquestador/prompt-registry.yaml' 'prompts/roles' 'prompt registry must declare role prompts'
Assert-Contains 'orquestador/prompt-registry.yaml' 'prompts/migration' 'prompt registry must declare migration prompts'
Assert-Contains 'orquestador/prompt-registry.yaml' 'prompts/adapters' 'prompt registry must declare adapter prompts'
Assert-Contains 'orquestador/registry-index.yaml' 'orquestador/prompt-registry.yaml' 'registry-index must include prompt registry'
Assert-Contains 'orquestador/registry-index.yaml' 'orquestador/adapter-registry.yaml' 'registry-index must include adapter registry'
Assert-Contains 'orquestador/registry-index.yaml' 'orquestador/agents/agent-registry.yaml' 'registry-index must include agent registry'
Assert-Contains 'orquestador/registry-index.yaml' 'orquestador/security/permission-registry.yaml' 'registry-index must include security permission registry'
Assert-Contains 'orquestador/registry-index.yaml' 'orquestador/migration/migration-registry.yaml' 'registry-index must include migration registry'
Assert-Contains 'orquestador/context-profile-registry.yaml' 'leader_light' 'context profile registry must declare leader_light'
Assert-Contains 'orquestador/gate-registry.yaml' 'G3A_detractor_senior_pre_implementation' 'gate registry must declare detractor gate'
Assert-Contains 'orquestador/policy-registry.yaml' 'orquestador/policies/permissions.md' 'policy registry must include permissions policy'
Assert-Contains 'orquestador/policy-registry.yaml' 'orquestador/agents/agent-registry.yaml' 'policy registry must include agent contract system'
Assert-Contains 'orquestador/policy-registry.yaml' 'orquestador/security/threat-model.yaml' 'policy registry must include AppSec threat model'
Assert-Contains 'orquestador/policy-registry.yaml' 'orquestador/migration/migration-registry.yaml' 'policy registry must include migration service'
Assert-Contains 'orquestador/template-registry.yaml' 'verification-matrix.yaml' 'template registry must include verification matrix'
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
Assert-Contains 'prompts/audit/detractor-senior.prompt.md' 'No implementes' 'detractor senior prompt must be read-only'
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
Assert-Contains 'prompts/runtime/harness-runtime.prompt.md' 'active-session es cache' 'runtime prompt must keep active-session non-authoritative'
Assert-Contains 'orquestador/integrations/claude/settings.template.json' 'SessionStart' 'Claude settings must declare SessionStart hook'
Assert-Contains 'orquestador/integrations/claude/settings.template.json' 'UserPromptSubmit' 'Claude settings must declare UserPromptSubmit hook'
Assert-Contains 'orquestador/integrations/claude/CLAUDE.template.md' 'reentry-brief' 'CLAUDE template must point to reentry brief'
Assert-Contains 'orquestador/sdd/progress/templates/claude-reentry-state.yaml' 'non_authoritative: true' 'Claude reentry state must be non-authoritative'
Assert-Contains 'scripts/install-claude-hooks.ps1' 'Preflight only' 'Claude hook installer must be preflight-only'
Assert-Contains 'scripts/claude-reentry.ps1' 'Approvals expired' 'Claude reentry must expire approvals'
Assert-Contains 'orquestador/instruction-builder/instruction-registry.yaml' ([regex]::Escape($currentHarnessVersion)) 'instruction registry must match harness version'
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
Assert-Contains 'orquestador/harness-manifest.txt' 'orquestador/agents/agent-registry.yaml' 'agent registry must be in manifest'
Assert-Contains 'orquestador/harness-manifest.txt' 'orquestador/security/permission-registry.yaml' 'security permission registry must be in manifest'
Assert-Contains 'orquestador/harness-manifest.txt' 'orquestador/migration/migration-registry.yaml' 'migration registry must be in manifest'
Assert-Contains 'orquestador/harness-manifest.txt' 'scripts/validate-agent-contracts.ps1' 'validate-agent-contracts.ps1 must be in manifest'
Assert-Contains 'orquestador/harness-manifest.txt' 'scripts/validate-security-policy.ps1' 'validate-security-policy.ps1 must be in manifest'
Assert-Contains 'orquestador/harness-manifest.txt' 'scripts/validate-migration.ps1' 'validate-migration.ps1 must be in manifest'
Assert-Contains 'orquestador/harness-manifest.txt' 'scripts/audit-harness.ps1' 'audit-harness.ps1 must be in manifest'
Assert-Contains 'orquestador/harness-manifest.txt' 'scripts/hebrinex.ps1' 'hebrinex.ps1 must be in manifest'
Assert-Contains 'orquestador/harness-manifest.txt' 'scripts/validate-fixtures.ps1' 'validate-fixtures.ps1 must be in manifest'
Assert-Contains 'orquestador/harness-manifest.txt' 'scripts/command-gateway.ps1' 'command-gateway.ps1 must be in manifest'
Assert-Contains 'orquestador/harness-manifest.txt' 'scripts/validate-command-gateway.ps1' 'validate-command-gateway.ps1 must be in manifest'
Assert-Contains 'orquestador/harness-manifest.txt' 'scripts/validate-release.ps1' 'validate-release.ps1 must be in manifest'
Assert-Contains 'scripts/hebrinex.ps1' 'Hebri-AI-Harness CLI Core' 'hebrinex.ps1 must expose CLI Core marker'
Assert-Contains 'scripts/validate-fixtures.ps1' 'Fixture validation OK' 'validate-fixtures.ps1 must expose success marker'
Assert-Contains 'scripts/command-gateway.ps1' 'Command Gateway' 'command-gateway.ps1 must expose gateway marker'
Assert-Contains 'scripts/validate-command-gateway.ps1' 'Command gateway validation OK' 'validate-command-gateway.ps1 must expose success marker'
Assert-Contains 'scripts/command-gateway.ps1' 'hebrinex.command_gateway.result' 'command-gateway.ps1 must expose structured result schema'
Assert-Contains 'orquestador/harness-manifest.txt' 'orquestador/runtime/schemas/command-gateway-result.schema.json' 'command gateway result schema must be in manifest'
Assert-Contains 'orquestador/harness-manifest.txt' 'orquestador/runtime/templates/command-gateway-result.template.json' 'command gateway result template must be in manifest'
Assert-Contains 'orquestador/policy-registry.yaml' 'validator_fixtures' 'policy registry must include validator fixtures'
Assert-Contains 'orquestador/agents/agent-registry.yaml' 'HL0_agent_authority' 'agent registry must declare HL0 agent authority'
Assert-Contains 'orquestador/agents/agent-registry.yaml' 'agent_definition_authority:\s*harness_only' 'agent registry must be harness-only'
Assert-Contains 'orquestador/agents/agent-registry.yaml' 'ai_may_define_agents:\s*false' 'agent registry must deny AI-defined agents'
Assert-Contains 'orquestador/agents/capability-registry.yaml' 'missing_capability: block' 'capability registry must fail closed on missing capability'
Assert-Contains 'orquestador/security/threat-model.yaml' 'command_injection' 'threat model must include command injection'
Assert-Contains 'orquestador/security/threat-model.yaml' 'path_traversal' 'threat model must include path traversal'
Assert-Contains 'orquestador/security/secrets-policy.yaml' 'default' 'secrets policy must define a default posture'
Assert-Contains 'orquestador/migration/migration-registry.yaml' 'check_only_writes:\s*false' 'migration registry must keep CheckOnly no-write'
Assert-Contains 'orquestador/migration/migration-registry.yaml' 'apply_requires_backup:\s*true' 'migration registry must require backup for Apply'
if ((Get-ScalarValue 'PROJECT_BINDING.yaml' 'binding_mode') -eq 'source_template') { Assert-Contains 'orquestador/migration/contracts/post-migration-contract.yaml' 'migration_status:\s*not_applied' 'source template post-migration contract must remain not_applied' } else { Assert-Contains 'orquestador/migration/contracts/post-migration-contract.yaml' 'migration_status:\s*applied' 'bound post-migration contract must be applied' }

Assert-PresetNotHeavyByDefault 'prompts/adapters/preset-codex.prompt.md'
Assert-PresetNotHeavyByDefault 'prompts/adapters/preset-claude.prompt.md'
Assert-PresetNotHeavyByDefault 'prompts/adapters/preset-gemini.prompt.md'

Assert-Budget 'memory_bootstrap' 1700 @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/reentry-light.md')
Assert-Budget 'first_message' 1800 @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/first-message.md')
Assert-Budget 'debug_log_intake' 2000 @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/debug-log-intake.md','orquestador/entrypoints/reentry-light.md')
Assert-Budget 'leader_light' 2600 @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/sdd/progress/state.yaml','orquestador/sdd/progress/registry.yaml','orquestador/method/session-contract.md')

foreach ($jsonRel in @('orquestador/integrations/claude/settings.template.json','orquestador/runtime/active-session.template.json','orquestador/runtime/schemas/active-session.schema.json','orquestador/runtime/schemas/harness-command.schema.json','orquestador/runtime/schemas/command-gateway-result.schema.json','orquestador/runtime/templates/command-result.template.json','orquestador/runtime/templates/command-gateway-result.template.json','orquestador/runtime/templates/budget-report.template.json','orquestador/runtime/templates/reentry-result.template.json','orquestador/sdd/progress/templates/runtime-audit-report.json')) {
  try { [void](Read-HarnessText $jsonRel | ConvertFrom-Json) }
  catch { Add-Failure "$jsonRel must be valid JSON" }
}
Assert-Budget 'runtime_status' 900 @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/context-budget.yaml','orquestador/runtime/active-session.template.json')
Assert-Budget 'runtime_reentry' 1600 @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/context-budget.yaml','orquestador/runtime/active-session.template.json','orquestador/sdd/progress/state.yaml','orquestador/sdd/progress/registry.yaml')

try { & (Resolve-HarnessPath 'scripts/build-instructions.ps1') -Root $Root | Out-Null } catch { Add-Failure 'build-instructions.ps1 must pass check-only' }
try { & (Resolve-HarnessPath 'scripts/validate-drift.ps1') -Root $Root -RunNegativeTests | Out-Null } catch { Add-Failure 'validate-drift.ps1 must pass negative tests' }
try { & (Resolve-HarnessPath 'scripts/regularize-state.ps1') -Root $Root | Out-Null } catch { Add-Failure 'regularize-state.ps1 must pass on current state' }
try { & (Resolve-HarnessPath 'scripts/regularize-registry.ps1') -Root $Root | Out-Null } catch { Add-Failure 'regularize-registry.ps1 must pass on current registry' }
try { & (Resolve-HarnessPath 'scripts/hebrinex.ps1') status -Root $Root *> $null } catch { Add-Failure 'hebrinex.ps1 status must pass read-only' }
try { & (Resolve-HarnessPath 'scripts/hebrinex.ps1') budget -Root $Root *> $null } catch { Add-Failure 'hebrinex.ps1 budget must pass read-only' }
try { & (Resolve-HarnessPath 'scripts/hebrinex.ps1') preflight -Root $Root -ApprovalId 'VALIDATE-HARNESS-CHECK' -Action 'check CLI preflight output' *> $null } catch { Add-Failure 'hebrinex.ps1 preflight must pass read-only' }
try { & (Resolve-HarnessPath 'scripts/hebrinex.ps1') command -Root $Root -CheckOnly -CommandText 'Get-Content README.md' *> $null } catch { Add-Failure 'hebrinex.ps1 command must pass read-only CheckOnly' }

Invoke-Validator 'validate-release' 'scripts/validate-release.ps1'
Invoke-Validator 'validate-agent-contracts' 'scripts/validate-agent-contracts.ps1'
Invoke-Validator 'validate-security-policy' 'scripts/validate-security-policy.ps1'
Invoke-Validator 'validate-migration' 'scripts/validate-migration.ps1'
Invoke-Validator 'validate-fixtures' 'scripts/validate-fixtures.ps1'
Invoke-Validator 'validate-command-gateway' 'scripts/validate-command-gateway.ps1'
Invoke-Validator 'audit-harness' 'scripts/audit-harness.ps1'

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
