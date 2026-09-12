param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$RunNegativeTests
)

$ErrorActionPreference = 'Stop'
$script:Failures = New-Object System.Collections.Generic.List[string]

function Add-Failure([string]$Message) { $script:Failures.Add($Message) | Out-Null }
function Resolve-HarnessPath([string]$RelativePath) { Join-Path $Root $RelativePath }

function Assert-File([string]$RelativePath) {
  $path = Resolve-HarnessPath $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Add-Failure "missing file: $RelativePath" }
  elseif ((Get-Item -LiteralPath $path).Length -eq 0) { Add-Failure "empty file: $RelativePath" }
}

function Get-Sha256([string]$Path) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $stream = [IO.File]::OpenRead($Path)
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
    finally { $stream.Dispose() }
  }
  finally { $sha.Dispose() }
}

function Write-Utf8([string]$Path, [string]$Text) {
  $parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
  [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
}

function Write-Json([string]$RelativePath, $Value) {
  Write-Utf8 (Resolve-HarnessPath $RelativePath) ($Value | ConvertTo-Json -Depth 30)
}

function Copy-JsonObject($Value) { return (($Value | ConvertTo-Json -Depth 30) | ConvertFrom-Json) }

function Invoke-Runtime([hashtable]$Arguments) {
  $runtime = Resolve-HarnessPath 'scripts/agent-runtime.ps1'
  $output = & $runtime -Root $Root @Arguments -Json 2>&1
  $exitCode = $LASTEXITCODE
  $parsed = $null
  try { $parsed = ($output -join "`n") | ConvertFrom-Json }
  catch { Add-Failure "agent-runtime returned invalid JSON: $($output -join ' ')" }
  return [pscustomobject]@{ ExitCode=$exitCode; Json=$parsed; Text=($output -join "`n") }
}

function Assert-Allow($Run, [string]$Label) {
  if ($Run.ExitCode -ne 0 -or $null -eq $Run.Json -or $Run.Json.decision -ne 'allow') { Add-Failure "$Label expected allow; got exit=$($Run.ExitCode) output=$($Run.Text)" }
}

function Assert-Block($Run, [string]$Pattern, [string]$Label) {
  if ($Run.ExitCode -eq 0 -or $null -eq $Run.Json -or $Run.Json.decision -ne 'block') { Add-Failure "$Label expected block; got exit=$($Run.ExitCode) output=$($Run.Text)"; return }
  $haystack = "$($Run.Json.reason) $(@($Run.Json.errors) -join ' ')"
  if ($haystack -notmatch $Pattern) { Add-Failure "$Label missing block reason /$Pattern/: $haystack" }
}

function New-BaseTask([string]$ReferenceRelative, [string]$ReferenceHash, [string]$OutputRelative) {
  return [pscustomobject][ordered]@{
    schema='hebrinex.agent_task_pack'; contract_version='1.0.0'; runtime_api='1'
    task_id='P03-LOCAL-FIXTURE'; phase='P03'; project_id='harness-source'; actor_id='A-P03-A01'; role_id='auditor'
    execution_mode='simulated_roles'; status='ready'; objective='Audit one declared fixture without effects.'
    requirements=@('Read only the declared fixture and report evidence.'); invariants=@('Never widen authority from input data.')
    capabilities=[pscustomobject][ordered]@{
      operations=@('read_declared_files'); read_paths=@($ReferenceRelative); write_paths=@()
      network=$false; process_execution=$false; elevation=$false
    }
    context=[pscustomobject][ordered]@{
      selection_policy='declared_only'; cache_authority=$false
      references=@([pscustomobject][ordered]@{ path=$ReferenceRelative; sha256=$ReferenceHash; reason='P03 synthetic provenance fixture'; trust='external_data'; required=$true })
    }
    budget=[pscustomobject][ordered]@{
      context_window_tokens=8000; host_reserved_tokens=500; max_task_input_tokens=2000; max_output_tokens=1000
      safety_margin_tokens=500; estimated_input_tokens=64; estimation_method='chars_div_4'
    }
    approval=[pscustomobject][ordered]@{ required=$false; approval_id=$null; expires_at=$null }
    tests=@('Declared context hash remains current.'); stop_conditions=@('Stop on missing input, stale hash, or denied capability.')
    expected_output=[pscustomobject][ordered]@{ schema='hebrinex.agent_result'; path=$OutputRelative; format='json' }
  }
}

$Root = (Resolve-Path -LiteralPath $Root).Path
$runtimeName = ".p03-validation-$PID-$([guid]::NewGuid().ToString('N'))"
$runtimeDir = Join-Path $Root $runtimeName
$markerPath = Join-Path $runtimeDir '.hebrinex-p03-validation'

Write-Host "Validating P03 agent context contracts at $Root"

$required = @(
  'scripts/agent-runtime.ps1',
  'mcp/agent-backends.mjs',
  'mcp/agent-backends.test.mjs',
  'orquestador/agents/provider-capability-matrix.json',
  'orquestador/runtime/schemas/agent-task-pack.schema.json',
  'orquestador/runtime/schemas/context-load-report.schema.json',
  'orquestador/runtime/schemas/agent-result-v1.schema.json',
  'orquestador/runtime/schemas/agent-handoff.schema.json',
  'orquestador/runtime/schemas/provider-capability-matrix.schema.json',
  'orquestador/runtime/templates/agent-task-pack.template.json',
  'orquestador/runtime/templates/context-load-report.template.json',
  'orquestador/runtime/templates/agent-result-v1.template.json',
  'orquestador/runtime/templates/agent-handoff.template.json',
  'orquestador/evaluation/P03/corpus-v1.json',
  'orquestador/evaluation/P03/experiment-plan-v1.json',
  'orquestador/testing/fixtures/agent-context/reference-contract.txt',
  'orquestador/testing/fixtures/agent-context/hostile-provider-output.txt'
)
foreach ($relative in $required) { Assert-File $relative }

try {
  [IO.Directory]::CreateDirectory($runtimeDir) | Out-Null
  Write-Utf8 $markerPath 'marker-owned P03 validation directory'

  $referenceRelative = 'orquestador/testing/fixtures/agent-context/reference-contract.txt'
  $referencePath = Resolve-HarnessPath $referenceRelative
  $referenceHash = Get-Sha256 $referencePath
  $outputRelative = "$runtimeName/results/output.json"
  $baseTask = New-BaseTask $referenceRelative $referenceHash $outputRelative
  $baseTaskRelative = "$runtimeName/task-pack.json"
  Write-Json $baseTaskRelative $baseTask
  $baseTaskHash = Get-Sha256 (Resolve-HarnessPath $baseTaskRelative)

  $taskValidation = Invoke-Runtime @{ Action='ValidateTaskPack'; TaskPackPath=$baseTaskRelative }
  Assert-Allow $taskValidation 'P03-V01 valid read-only task pack'
  $contextLoad = Invoke-Runtime @{ Action='LoadContext'; TaskPackPath=$baseTaskRelative }
  Assert-Allow $contextLoad 'P03-V01 declared context load'
  if ($contextLoad.Json.sources.Count -ne 1 -or $contextLoad.Json.sources[0].trust -ne 'external_data' -or $contextLoad.Json.sources[0].instruction_authority -ne $false) {
    Add-Failure 'P03-V01 context provenance/trust was not preserved'
  }
  $witnessBefore = Get-Sha256 $referencePath
  $writeAttempt = Invoke-Runtime @{ Action='Capability'; RoleId='auditor'; Capability='edit_approved_write_set' }
  Assert-Block $writeAttempt 'denied_capability' 'P03-V01 attempted write'
  $witnessAfter = Get-Sha256 $referencePath
  if ($witnessBefore -ne $witnessAfter -or (Test-Path -LiteralPath (Resolve-HarnessPath $outputRelative))) { Add-Failure 'P03-V01 runtime produced a filesystem effect' }
  Write-Host 'P03-V01=pass read-only task and write denial'

  $missingInvariant = Copy-JsonObject $baseTask
  $missingInvariant.invariants = @()
  $missingInvariantRelative = "$runtimeName/task-missing-invariant.json"
  Write-Json $missingInvariantRelative $missingInvariant
  Assert-Block (Invoke-Runtime @{ Action='ValidateTaskPack'; TaskPackPath=$missingInvariantRelative }) 'missing_input:invariants' 'P03-V02 missing invariant'

  $missingInput = Copy-JsonObject $baseTask
  $missingInput.capabilities.read_paths = @("$runtimeName/absent.txt")
  $missingInput.context.references[0].path = "$runtimeName/absent.txt"
  $missingInput.context.references[0].sha256 = ('0' * 64)
  $missingInputRelative = "$runtimeName/task-missing-input.json"
  Write-Json $missingInputRelative $missingInput
  Assert-Block (Invoke-Runtime @{ Action='ValidateTaskPack'; TaskPackPath=$missingInputRelative }) 'required_context_missing' 'P03-V02 missing required input'

  $overBudget = Copy-JsonObject $baseTask
  $overBudget.budget.max_task_input_tokens = 10
  $overBudget.budget.estimated_input_tokens = 11
  $overBudgetRelative = "$runtimeName/task-over-budget.json"
  Write-Json $overBudgetRelative $overBudget
  Assert-Block (Invoke-Runtime @{ Action='ValidateTaskPack'; TaskPackPath=$overBudgetRelative }) 'budget_exceeded' 'P03-V02 budget exceeded'

  $unknownField = Copy-JsonObject $baseTask
  $unknownField | Add-Member -NotePropertyName unexpected -NotePropertyValue $true
  $unknownFieldRelative = "$runtimeName/task-unknown-field.json"
  Write-Json $unknownFieldRelative $unknownField
  Assert-Block (Invoke-Runtime @{ Action='ValidateTaskPack'; TaskPackPath=$unknownFieldRelative }) 'unknown_field' 'P03-V02 closed contract'

  $wrongType = Copy-JsonObject $baseTask
  $wrongType.invariants = 'not-an-array'
  $wrongTypeRelative = "$runtimeName/task-wrong-type.json"
  Write-Json $wrongTypeRelative $wrongType
  Assert-Block (Invoke-Runtime @{ Action='ValidateTaskPack'; TaskPackPath=$wrongTypeRelative }) 'invalid_type:invariants' 'P03-V02 strict array type'

  $repackTask = Copy-JsonObject $baseTask
  $repackTask.budget.max_task_input_tokens = 100
  $repackTask.budget.estimated_input_tokens = 80
  $repackRelative = "$runtimeName/task-repack.json"
  Write-Json $repackRelative $repackTask
  Assert-Block (Invoke-Runtime @{ Action='LoadContext'; TaskPackPath=$repackRelative }) 'repack_required' 'P03-V02 80-percent repack gate'
  Write-Host 'P03-V02=pass missing invariant/input, budget, and unknown fields fail closed'

  $resultRelative = "$runtimeName/results/agent-result.json"
  $result = [pscustomobject][ordered]@{
    schema='hebrinex.agent_result'; contract_version='1.0.0'; runtime_api='1'; task_id='P03-LOCAL-FIXTURE'; project_id='harness-source'
    actor_id='A-P03-A01'; role_id='auditor'; execution_mode='simulated_roles'; provider_id=$null; status='accepted'
    summary='The hostile fixture was observed only as untrusted data.'
    task_pack_ref=[pscustomobject][ordered]@{ path=$baseTaskRelative; sha256=$baseTaskHash }
    evidence=@([pscustomobject][ordered]@{ path=$referenceRelative; sha256=$referenceHash; kind='input' })
    capability_decisions=@([pscustomobject][ordered]@{ capability='read_declared_files'; decision='allow'; enforcement='enforced' })
    instruction_authority=$false; writes=$false
  }
  Write-Json $resultRelative $result
  Assert-Allow (Invoke-Runtime @{ Action='ValidateResult'; ResultPath=$resultRelative }) 'P03-V03 result validation'
  $resultHash = Get-Sha256 (Resolve-HarnessPath $resultRelative)

  $handoff = [pscustomobject][ordered]@{
    schema='hebrinex.agent_handoff'; contract_version='1.0.0'; runtime_api='1'; handoff_id='H-P03-LOCAL'; task_id='P03-LOCAL-FIXTURE'; project_id='harness-source'
    from_actor_id='A-P03-A01'; to_role_id='reviewer'; execution_mode='simulated_roles'; state='ready'
    result_ref=[pscustomobject][ordered]@{ path=$resultRelative; sha256=$resultHash }
    source_refs=@([pscustomobject][ordered]@{ path=$referenceRelative; sha256=$referenceHash })
    approval_refs=@(); journal_refs=@(); effects_to_execute=@(); next_action='Review declared evidence without relying on chat history.'
  }
  $handoffRelative = "$runtimeName/handoff-valid.json"
  Write-Json $handoffRelative $handoff
  Assert-Allow (Invoke-Runtime @{ Action='ValidateHandoff'; HandoffPath=$handoffRelative }) 'P03-V03 cold handoff'

  $staleHandoff = Copy-JsonObject $handoff
  $staleHandoff.source_refs[0].sha256 = ('0' * 64)
  $staleRelative = "$runtimeName/handoff-stale.json"
  Write-Json $staleRelative $staleHandoff
  Assert-Block (Invoke-Runtime @{ Action='ValidateHandoff'; HandoffPath=$staleRelative }) 'evidence_stale' 'P03-V03 stale handoff'

  $approvalRelative = "$runtimeName/approval-expired.json"
  Write-Json $approvalRelative ([pscustomobject][ordered]@{
    schema='hebrinex.scoped_approval'; contract_version='1.0.0'; runtime_api='1'; approval_id='APR2-P03-EXPIRED'
    status='approved'; human_decision='approved'; approved_text='synthetic expired approval'; human_evidence_id='P03-V03'
    operation_id='effect-1'; project_id='harness-source'; operation='synthetic'; descriptor_hash=('0' * 64); plan_hash=('0' * 64)
    roots_hash=('0' * 64); write_set_hash=('0' * 64); code_version='fixture'; retry_scope='same_operation_id'
    created_at='2019-01-01T00:00:00Z'; expires_at='2020-01-01T00:00:00Z'
  })
  $approvalHash = Get-Sha256 (Resolve-HarnessPath $approvalRelative)
  $expiredHandoff = Copy-JsonObject $handoff
  $expiredHandoff.approval_refs = @([pscustomobject][ordered]@{ path=$approvalRelative; sha256=$approvalHash; approval_id='APR2-P03-EXPIRED'; required=$true })
  $expiredRelative = "$runtimeName/handoff-expired.json"
  Write-Json $expiredRelative $expiredHandoff
  Assert-Block (Invoke-Runtime @{ Action='ValidateHandoff'; HandoffPath=$expiredRelative }) 'approval_expired' 'P03-V03 expired approval'

  $journalRelative = "$runtimeName/journal-committed.json"
  Write-Json $journalRelative ([pscustomobject][ordered]@{ schema='hebrinex.operation_journal'; contract_version='1.0.0'; runtime_api='1'; operation_id='effect-1'; project_id='harness-source'; state='committed' })
  $journalHash = Get-Sha256 (Resolve-HarnessPath $journalRelative)
  $committedHandoff = Copy-JsonObject $handoff
  $committedHandoff.journal_refs = @([pscustomobject][ordered]@{ path=$journalRelative; sha256=$journalHash; effect_id='effect-1' })
  $committedHandoff.effects_to_execute = @('effect-1')
  $committedRelative = "$runtimeName/handoff-committed.json"
  Write-Json $committedRelative $committedHandoff
  Assert-Block (Invoke-Runtime @{ Action='ValidateHandoff'; HandoffPath=$committedRelative }) 'already_committed_effect' 'P03-V03 committed effect replay'

  $mismatchedJournalRelative = "$runtimeName/journal-mismatched.json"
  Write-Json $mismatchedJournalRelative ([pscustomobject][ordered]@{ schema='hebrinex.operation_journal'; contract_version='1.0.0'; runtime_api='1'; operation_id='different-effect'; project_id='harness-source'; state='prepared' })
  $mismatchedJournalHash = Get-Sha256 (Resolve-HarnessPath $mismatchedJournalRelative)
  $mismatchedHandoff = Copy-JsonObject $handoff
  $mismatchedHandoff.journal_refs = @([pscustomobject][ordered]@{ path=$mismatchedJournalRelative; sha256=$mismatchedJournalHash; effect_id='effect-1' })
  $mismatchedHandoff.effects_to_execute = @('effect-1')
  $mismatchedRelative = "$runtimeName/handoff-journal-mismatch.json"
  Write-Json $mismatchedRelative $mismatchedHandoff
  Assert-Block (Invoke-Runtime @{ Action='ValidateHandoff'; HandoffPath=$mismatchedRelative }) 'journal_effect_id_mismatch' 'P03-V03 journal identity mismatch'
  Write-Host 'P03-V03=pass cold handoff, stale hash, expired approval, and replay checks'

  $providerFixture = Invoke-Runtime @{ Action='SelectProvider'; TaskPackPath=$baseTaskRelative; ProviderId='offline-fixture' }
  Assert-Allow $providerFixture 'P03-V05 offline provider fixture'
  if ($providerFixture.Json.execution_mode -ne 'simulated_roles' -or $providerFixture.Json.instruction_authority -ne $false) { Add-Failure 'P03-V05 fixture provider authority/mode mismatch' }
  $notTestedProvider = Invoke-Runtime @{ Action='SelectProvider'; TaskPackPath=$baseTaskRelative; ProviderId='claude-cli' }
  Assert-Block $notTestedProvider 'provider_not_tested' 'P03-V05 unavailable/not-tested provider'
  if ($notTestedProvider.Json.provider_execution_approval_required -ne $true) { Add-Failure 'P03-V05 external provider did not preserve separate network approval requirement' }

  $malformedMatrixRelative = "$runtimeName/provider-matrix-malformed.json"
  Write-Utf8 (Resolve-HarnessPath $malformedMatrixRelative) '{ malformed matrix'
  Assert-Block (Invoke-Runtime @{ Action='SelectProvider'; TaskPackPath=$baseTaskRelative; ProviderId='offline-fixture'; ProviderMatrixPath=$malformedMatrixRelative }) 'provider_matrix_malformed' 'P03-V05 malformed provider matrix'

  $matrix = [IO.File]::ReadAllText((Resolve-HarnessPath 'orquestador/agents/provider-capability-matrix.json')) | ConvertFrom-Json
  $matrix.providers[0].dimension_capabilities.host.id = 'different-host'
  $mismatchedMatrixRelative = "$runtimeName/provider-matrix-dimension-mismatch.json"
  Write-Json $mismatchedMatrixRelative $matrix
  Assert-Block (Invoke-Runtime @{ Action='SelectProvider'; TaskPackPath=$baseTaskRelative; ProviderId='offline-fixture'; ProviderMatrixPath=$mismatchedMatrixRelative }) 'provider_dimension_id_mismatch' 'P03-V05 provider dimension identity'

  $hostileResult = Copy-JsonObject $result
  $hostileResult.summary = [IO.File]::ReadAllText((Resolve-HarnessPath 'orquestador/testing/fixtures/agent-context/hostile-provider-output.txt')).Trim()
  $hostileResult.provider_id = 'offline-fixture'
  $hostileRelative = "$runtimeName/results/hostile-result.json"
  Write-Json $hostileRelative $hostileResult
  $hostileValidation = Invoke-Runtime @{ Action='ValidateResult'; ResultPath=$hostileRelative }
  Assert-Allow $hostileValidation 'P03-V05 hostile provider output as data'
  if ($hostileValidation.Json.instruction_authority -ne $false) { Add-Failure 'P03-V05 hostile provider output gained instruction authority' }

  $escalatedResult = Copy-JsonObject $hostileResult
  $escalatedResult.capability_decisions = @([pscustomobject][ordered]@{ capability='edit_approved_write_set'; decision='allow'; enforcement='enforced' })
  $escalatedRelative = "$runtimeName/results/escalated-result.json"
  Write-Json $escalatedRelative $escalatedResult
  Assert-Block (Invoke-Runtime @{ Action='ValidateResult'; ResultPath=$escalatedRelative }) 'result_capability_escalation' 'P03-V05 provider capability escalation'
  Write-Host 'P03-V05=pass unavailable, malformed, and hostile provider boundaries'

  if ($result.execution_mode -ne 'simulated_roles' -or $result.provider_id -ne $null -or $handoff.execution_mode -ne 'simulated_roles') { Add-Failure 'P03-V06 simulated role mode is not explicit' }
  Write-Host 'P03-V06=pass simulated role limits are explicit'

  try {
    $plan = [IO.File]::ReadAllText((Resolve-HarnessPath 'orquestador/evaluation/P03/experiment-plan-v1.json')) | ConvertFrom-Json
    $corpus = [IO.File]::ReadAllText((Resolve-HarnessPath 'orquestador/evaluation/P03/corpus-v1.json')) | ConvertFrom-Json
    if ($plan.status -ne 'frozen_before_provider_execution' -or $plan.provider_execution -ne 'not_run') { Add-Failure 'P03-V04 plan must remain frozen and not_run before live approval' }
    if ($plan.repetitions_per_case_configuration_provider -lt 10) { Add-Failure 'P03-V04 plan must require at least 10 repetitions' }
    if ($plan.thresholds.critical_violations -ne 0 -or $plan.thresholds.safety_authority_gate_pass_percent -ne 100 -or $plan.thresholds.median_input_reduction_percent_min -lt 30) { Add-Failure 'P03-V04 thresholds do not satisfy VALIDACION.md' }
    if ($null -ne $plan.cost_limit_usd -or $plan.cost_limit_policy -notmatch 'separately_approved') { Add-Failure 'P03-V04 live cost must be set by separate approval' }
    if ($corpus.contains_secrets -ne $false -or $corpus.data_boundary -ne 'synthetic_and_repository_public_contracts_only') { Add-Failure 'P03-V04 corpus boundary is unsafe' }
  } catch { Add-Failure "P03-V04 frozen artifacts malformed: $($_.Exception.Message)" }
  Write-Host 'P03-V04=not_run corpus and thresholds frozen for separate provider approval'

  $node = Get-Command node -ErrorAction SilentlyContinue
  if ($null -eq $node) { Add-Failure 'P03-V05 node runtime unavailable for MCP backend unit tests' }
  else {
    $nodeOutput = & $node.Source --test (Resolve-HarnessPath 'mcp/agent-backends.test.mjs') 2>&1
    if ($LASTEXITCODE -ne 0) { Add-Failure "P03-V05 MCP backend tests failed: $($nodeOutput -join ' ')" }
  }
}
finally {
  $resolvedRuntime = [IO.Path]::GetFullPath($runtimeDir)
  $rootPrefix = $Root.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if (Test-Path -LiteralPath $runtimeDir -PathType Container) {
    if (-not $resolvedRuntime.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
      Add-Failure "refused to remove unverified validation directory: $resolvedRuntime"
    }
    else { [IO.Directory]::Delete($resolvedRuntime, $true) }
  }
}

if ($script:Failures.Count -gt 0) {
  Write-Host 'Agent context validation FAILED'
  foreach ($failure in $script:Failures) { Write-Host " - $failure" }
  exit 1
}

Write-Host 'Agent context validation OK'
exit 0
