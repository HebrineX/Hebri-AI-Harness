param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [ValidateSet('Capability', 'ValidateTaskPack', 'LoadContext', 'SelectProvider', 'ValidateResult', 'ValidateHandoff')]
  [string]$Action = 'Capability',
  [string]$RoleId = '',
  [string]$Capability = '',
  [string]$FromState = '',
  [string]$ToState = '',
  [string]$TaskPackPath = '',
  [string]$ProviderMatrixPath = 'orquestador/agents/provider-capability-matrix.json',
  [string]$ProviderId = '',
  [string]$ResultPath = '',
  [string]$HandoffPath = '',
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$script:RootPath = (Resolve-Path -LiteralPath $Root).Path

function Resolve-HarnessPath([string]$RelativePath) { Join-Path $script:RootPath $RelativePath }

function Read-HarnessText([string]$RelativePath) {
  $path = Resolve-HarnessPath $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "missing file: $RelativePath" }
  return [IO.File]::ReadAllText($path)
}

function Resolve-DeclaredPath([string]$RelativePath) {
  if ([string]::IsNullOrWhiteSpace($RelativePath) -or [IO.Path]::IsPathRooted($RelativePath)) { throw "path_not_relative:$RelativePath" }
  $normalized = $RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar)
  $full = [IO.Path]::GetFullPath((Join-Path $script:RootPath $normalized))
  $prefix = $script:RootPath.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "path_escape:$RelativePath" }
  $probe = $full
  while (-not (Test-Path -LiteralPath $probe)) {
    $parent = Split-Path -Parent $probe
    if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $probe) { break }
    $probe = $parent
  }
  while (-not [string]::IsNullOrWhiteSpace($probe) -and $probe.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    $item = Get-Item -LiteralPath $probe -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "reparse_point_unsupported:$RelativePath" }
    $parent = Split-Path -Parent $probe
    if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $probe) { break }
    $probe = $parent
  }
  return $full
}

function Read-JsonFile([string]$Path, [string]$Label) {
  $resolved = Resolve-DeclaredPath $Path
  if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "${Label}_missing:$Path" }
  try { return ([IO.File]::ReadAllText($resolved) | ConvertFrom-Json) }
  catch { throw "${Label}_malformed:$Path" }
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

function Get-Sha256Bytes([byte[]]$Bytes) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
  finally { $sha.Dispose() }
}

function Get-PropertyNames($Object) {
  if ($null -eq $Object) { return @() }
  return @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

function Test-ClosedObject($Object, [string[]]$Allowed, [string[]]$Required, [string]$Label, $Errors) {
  if ($null -eq $Object) { $Errors.Add("missing_object:$Label") | Out-Null; return }
  $names = @(Get-PropertyNames $Object)
  foreach ($name in $names) { if ($Allowed -notcontains $name) { $Errors.Add("unknown_field:$Label.$name") | Out-Null } }
  foreach ($name in $Required) { if ($names -notcontains $name) { $Errors.Add("missing_field:$Label.$name") | Out-Null } }
}

function Test-StringArray($Value, [string]$Label, [bool]$RequireNonEmpty, $Errors) {
  if ($Value -isnot [System.Array]) { $Errors.Add("invalid_type:$Label") | Out-Null; return }
  $items = @($Value)
  if ($RequireNonEmpty -and $items.Count -eq 0) { $Errors.Add("missing_input:$Label") | Out-Null; return }
  foreach ($item in $items) {
    if (-not ($item -is [string]) -or [string]::IsNullOrWhiteSpace([string]$item)) { $Errors.Add("invalid_input:$Label") | Out-Null; return }
  }
}

function Test-Boolean($Value, [string]$Label, $Errors) {
  if ($Value -isnot [bool]) { $Errors.Add("invalid_type:$Label") | Out-Null }
}

function Test-NonNegativeInteger($Value, [string]$Label, [bool]$AllowZero, $Errors) {
  if ($Value -isnot [int] -and $Value -isnot [long]) { $Errors.Add("invalid_type:$Label") | Out-Null; return }
  if ([int64]$Value -lt 0 -or (-not $AllowZero -and [int64]$Value -eq 0)) { $Errors.Add("invalid_budget:$Label") | Out-Null }
}

function Test-CapabilityDefined([string]$RegistryText, [string]$Name) {
  $inside = $false
  foreach ($line in ($RegistryText -split "`n")) {
    if ($line -match '^capabilities:\s*$') { $inside = $true; continue }
    if ($inside -and $line -match '^role_defaults:\s*$') { return $false }
    if ($inside -and $line -match ('^\s{2}' + [regex]::Escape($Name) + ':\s*$')) { return $true }
  }
  return $false
}

function Get-InlineList([string]$Text, [string]$Key) {
  if ($Text -match ([regex]::Escape($Key) + ':\s*\[([^\]]*)\]')) {
    return @($Matches[1].Split(',') | ForEach-Object { $_.Trim().Trim('"').Trim("'") } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  }
  return @()
}

function Get-RoleDefaultsBlock([string]$RegistryText, [string]$Role) {
  $lines = New-Object System.Collections.Generic.List[string]
  $insideDefaults = $false
  $insideRole = $false
  foreach ($line in ($RegistryText -split "`n")) {
    if ($line -match '^role_defaults:\s*$') { $insideDefaults = $true; continue }
    if (-not $insideDefaults) { continue }
    if ($line -match ('^\s{2}' + [regex]::Escape($Role) + ':\s*$')) { $insideRole = $true; continue }
    if ($insideRole -and $line -match '^\s{2}[A-Za-z0-9_.-]+:\s*$') { break }
    if ($insideRole) { [void]$lines.Add($line) }
  }
  return ($lines -join "`n")
}

function Get-CapabilityDecision([string]$RequestedRole, [string]$RequestedCapability) {
  $agentRegistry = Read-HarnessText 'orquestador/agents/agent-registry.yaml'
  $capabilityRegistry = Read-HarnessText 'orquestador/agents/capability-registry.yaml'
  $decision = 'allow'; $reason = 'capability_allowed'; $contractRef = ''
  if ([string]::IsNullOrWhiteSpace($RequestedRole) -or [string]::IsNullOrWhiteSpace($RequestedCapability)) {
    $decision = 'block'; $reason = 'missing_role_or_capability'
  }
  elseif ($agentRegistry -notmatch ('(?m)^\s*-\s*id:\s*' + [regex]::Escape($RequestedRole) + '\s*$')) {
    $decision = 'block'; $reason = 'unknown_role'
  }
  else {
    $contractRef = "orquestador/agents/role-contracts/$RequestedRole.yaml"
    $contractPath = Resolve-HarnessPath $contractRef
    if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) { $decision = 'block'; $reason = 'missing_role_contract' }
    elseif (-not (Test-CapabilityDefined $capabilityRegistry $RequestedCapability)) { $decision = 'block'; $reason = 'unknown_capability' }
    else {
      $roleDefaults = Get-RoleDefaultsBlock $capabilityRegistry $RequestedRole
      $contractText = [IO.File]::ReadAllText($contractPath)
      $defaultAllow = @(Get-InlineList $roleDefaults 'allow'); $defaultDeny = @(Get-InlineList $roleDefaults 'deny')
      $contractAllow = @(Get-InlineList $contractText 'allow'); $contractDeny = @(Get-InlineList $contractText 'deny')
      if (($defaultDeny + $contractDeny) -contains $RequestedCapability) { $decision = 'block'; $reason = 'denied_capability' }
      elseif (-not (($defaultAllow + $contractAllow) -contains $RequestedCapability)) { $decision = 'block'; $reason = 'missing_capability' }
    }
  }
  return [pscustomobject]@{ capability=$RequestedCapability; decision=$decision; reason=$reason; contract_ref=$contractRef }
}

function Test-HashReference($Reference, [string]$Label, $Errors) {
  Test-ClosedObject $Reference @('path','sha256') @('path','sha256') $Label $Errors
  if ($null -eq $Reference -or [string]::IsNullOrWhiteSpace([string]$Reference.path)) { return }
  try { $full = Resolve-DeclaredPath ([string]$Reference.path) } catch { $Errors.Add($_.Exception.Message) | Out-Null; return }
  if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { $Errors.Add("evidence_missing:$($Reference.path)") | Out-Null; return }
  if ((Get-Sha256 $full) -ne ([string]$Reference.sha256).ToLowerInvariant()) { $Errors.Add("evidence_stale:$($Reference.path)") | Out-Null }
}

function Test-AgentTaskPack($Pack) {
  $errors = New-Object System.Collections.Generic.List[string]
  $decisions = New-Object System.Collections.Generic.List[object]
  $top = @('schema','contract_version','runtime_api','task_id','phase','project_id','actor_id','role_id','execution_mode','status','objective','requirements','invariants','capabilities','context','budget','approval','tests','stop_conditions','expected_output')
  Test-ClosedObject $Pack $top $top 'task_pack' $errors
  if ($null -eq $Pack) { return [pscustomobject]@{ Errors=$errors.ToArray(); CapabilityDecisions=@() } }
  if ($Pack.schema -ne 'hebrinex.agent_task_pack') { $errors.Add('invalid_contract:task_pack.schema') | Out-Null }
  if ($Pack.contract_version -ne '1.0.0' -or $Pack.runtime_api -ne '1') { $errors.Add('invalid_contract:task_pack.version') | Out-Null }
  if ($Pack.status -ne 'ready') { $errors.Add('invalid_state:task_pack.status') | Out-Null }
  if (@('real_agent','simulated_roles') -notcontains [string]$Pack.execution_mode) { $errors.Add('invalid_execution_mode') | Out-Null }
  foreach ($field in @('task_id','phase','project_id','actor_id','role_id','objective')) { if ([string]::IsNullOrWhiteSpace([string]$Pack.$field)) { $errors.Add("missing_input:$field") | Out-Null } }
  Test-StringArray $Pack.requirements 'requirements' $true $errors
  Test-StringArray $Pack.invariants 'invariants' $true $errors
  Test-StringArray $Pack.tests 'tests' $true $errors
  Test-StringArray $Pack.stop_conditions 'stop_conditions' $true $errors

  $capFields = @('operations','read_paths','write_paths','network','process_execution','elevation')
  Test-ClosedObject $Pack.capabilities $capFields $capFields 'task_pack.capabilities' $errors
  if ($null -ne $Pack.capabilities) {
    Test-StringArray $Pack.capabilities.operations 'capabilities.operations' $true $errors
    Test-StringArray $Pack.capabilities.read_paths 'capabilities.read_paths' $false $errors
    Test-StringArray $Pack.capabilities.write_paths 'capabilities.write_paths' $false $errors
    Test-Boolean $Pack.capabilities.network 'capabilities.network' $errors
    Test-Boolean $Pack.capabilities.process_execution 'capabilities.process_execution' $errors
    Test-Boolean $Pack.capabilities.elevation 'capabilities.elevation' $errors
    foreach ($operation in @($Pack.capabilities.operations)) {
      $capDecision = Get-CapabilityDecision ([string]$Pack.role_id) ([string]$operation)
      $decisions.Add($capDecision) | Out-Null
      if ($capDecision.decision -ne 'allow') { $errors.Add("capability_blocked:$operation`:$($capDecision.reason)") | Out-Null }
    }
    foreach ($path in @($Pack.capabilities.read_paths) + @($Pack.capabilities.write_paths)) { try { [void](Resolve-DeclaredPath ([string]$path)) } catch { $errors.Add($_.Exception.Message) | Out-Null } }
    if (@($Pack.capabilities.write_paths).Count -gt 0) {
      if (@($Pack.capabilities.operations) -notcontains 'edit_approved_write_set') { $errors.Add('write_without_capability') | Out-Null }
      if ($null -eq $Pack.approval -or $Pack.approval.required -ne $true -or [string]::IsNullOrWhiteSpace([string]$Pack.approval.approval_id)) { $errors.Add('write_without_approval') | Out-Null }
    }
    elseif (@($Pack.capabilities.operations) -contains 'edit_approved_write_set') { $errors.Add('write_capability_without_write_set') | Out-Null }
    if ($Pack.capabilities.network -eq $true -and @($Pack.capabilities.operations) -notcontains 'use_network') { $errors.Add('network_without_capability') | Out-Null }
    if ($Pack.capabilities.network -ne $true -and @($Pack.capabilities.operations) -contains 'use_network') { $errors.Add('network_capability_without_flag') | Out-Null }
    $processCapabilities = @('run_local_validation','run_readonly_audit')
    $declaresProcessCapability = @($Pack.capabilities.operations | Where-Object { $processCapabilities -contains $_ }).Count -gt 0
    if ($Pack.capabilities.process_execution -eq $true -and -not $declaresProcessCapability) { $errors.Add('process_without_capability') | Out-Null }
    if ($Pack.capabilities.process_execution -ne $true -and $declaresProcessCapability) { $errors.Add('process_capability_without_flag') | Out-Null }
    if ($Pack.capabilities.elevation -eq $true -and @($Pack.capabilities.operations) -notcontains 'privileged_execution') { $errors.Add('elevation_without_capability') | Out-Null }
    if ($Pack.capabilities.elevation -ne $true -and @($Pack.capabilities.operations) -contains 'privileged_execution') { $errors.Add('elevation_capability_without_flag') | Out-Null }
  }

  Test-ClosedObject $Pack.context @('selection_policy','cache_authority','references') @('selection_policy','cache_authority','references') 'task_pack.context' $errors
  if ($null -ne $Pack.context) {
    if ($Pack.context.selection_policy -ne 'declared_only') { $errors.Add('invalid_context_selection_policy') | Out-Null }
    if ($Pack.context.cache_authority -ne $false) { $errors.Add('cache_cannot_be_authority') | Out-Null }
    if ($Pack.context.references -isnot [System.Array]) { $errors.Add('invalid_type:context.references') | Out-Null }
    $index = 0
    foreach ($reference in @($Pack.context.references)) {
      Test-ClosedObject $reference @('path','sha256','reason','trust','required') @('path','sha256','reason','trust','required') "task_pack.context.references[$index]" $errors
      if (@('harness_authority','project_declared','external_data','provider_output') -notcontains [string]$reference.trust) { $errors.Add("invalid_trust:$($reference.path)") | Out-Null }
      if ([string]::IsNullOrWhiteSpace([string]$reference.reason)) { $errors.Add("missing_reason:$($reference.path)") | Out-Null }
      if (@($Pack.capabilities.read_paths) -notcontains [string]$reference.path) { $errors.Add("context_outside_read_set:$($reference.path)") | Out-Null }
      try { $full = Resolve-DeclaredPath ([string]$reference.path) } catch { $errors.Add($_.Exception.Message) | Out-Null; $index++; continue }
      if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { if ($reference.required -eq $true) { $errors.Add("required_context_missing:$($reference.path)") | Out-Null } }
      elseif ((Get-Sha256 $full) -ne ([string]$reference.sha256).ToLowerInvariant()) { $errors.Add("context_stale:$($reference.path)") | Out-Null }
      $index++
    }
  }

  $budgetFields = @('context_window_tokens','host_reserved_tokens','max_task_input_tokens','max_output_tokens','safety_margin_tokens','estimated_input_tokens','estimation_method')
  Test-ClosedObject $Pack.budget $budgetFields $budgetFields 'task_pack.budget' $errors
  if ($null -ne $Pack.budget) {
    Test-NonNegativeInteger $Pack.budget.host_reserved_tokens 'host_reserved_tokens' $true $errors
    Test-NonNegativeInteger $Pack.budget.max_task_input_tokens 'max_task_input_tokens' $false $errors
    Test-NonNegativeInteger $Pack.budget.max_output_tokens 'max_output_tokens' $false $errors
    Test-NonNegativeInteger $Pack.budget.safety_margin_tokens 'safety_margin_tokens' $true $errors
    Test-NonNegativeInteger $Pack.budget.estimated_input_tokens 'estimated_input_tokens' $true $errors
    if ($null -ne $Pack.budget.context_window_tokens) { Test-NonNegativeInteger $Pack.budget.context_window_tokens 'context_window_tokens' $false $errors }
    if (@('measured','chars_div_4','unknown') -notcontains [string]$Pack.budget.estimation_method) { $errors.Add('invalid_budget:estimation_method') | Out-Null }
    if ([int64]$Pack.budget.estimated_input_tokens -gt [int64]$Pack.budget.max_task_input_tokens) { $errors.Add('budget_exceeded:estimated_input_tokens') | Out-Null }
    if ($null -ne $Pack.budget.context_window_tokens) {
      $allocated = [int64]$Pack.budget.host_reserved_tokens + [int64]$Pack.budget.max_task_input_tokens + [int64]$Pack.budget.max_output_tokens + [int64]$Pack.budget.safety_margin_tokens
      if ($allocated -gt [int64]$Pack.budget.context_window_tokens) { $errors.Add('budget_exceeded:context_window_tokens') | Out-Null }
    }
  }

  Test-ClosedObject $Pack.approval @('required','approval_id','expires_at') @('required','approval_id','expires_at') 'task_pack.approval' $errors
  if ($null -ne $Pack.approval) { Test-Boolean $Pack.approval.required 'approval.required' $errors }
  if ($null -ne $Pack.approval -and $Pack.approval.required -eq $true) {
    if ([string]::IsNullOrWhiteSpace([string]$Pack.approval.approval_id)) { $errors.Add('approval_missing') | Out-Null }
    if (-not [string]::IsNullOrWhiteSpace([string]$Pack.approval.expires_at)) {
      try { if ([DateTimeOffset]::Parse([string]$Pack.approval.expires_at) -le [DateTimeOffset]::UtcNow) { $errors.Add('approval_expired') | Out-Null } } catch { $errors.Add('approval_expiry_invalid') | Out-Null }
    }
  }
  Test-ClosedObject $Pack.expected_output @('schema','path','format') @('schema','path','format') 'task_pack.expected_output' $errors
  if ($null -ne $Pack.expected_output) {
    if ($Pack.expected_output.schema -ne 'hebrinex.agent_result' -or $Pack.expected_output.format -ne 'json') { $errors.Add('invalid_expected_output') | Out-Null }
    try { [void](Resolve-DeclaredPath ([string]$Pack.expected_output.path)) } catch { $errors.Add($_.Exception.Message) | Out-Null }
  }
  return [pscustomobject]@{ Errors=$errors.ToArray(); CapabilityDecisions=$decisions.ToArray() }
}

function Get-Reason($Validation, [string]$AllowedReason) {
  if (@($Validation.Errors).Count -eq 0) { return $AllowedReason }
  return [string]$Validation.Errors[0]
}

function Test-AgentResult($Result) {
  $errors = New-Object System.Collections.Generic.List[string]
  $top = @('schema','contract_version','runtime_api','task_id','project_id','actor_id','role_id','execution_mode','provider_id','status','summary','task_pack_ref','evidence','capability_decisions','instruction_authority','writes')
  Test-ClosedObject $Result $top $top 'agent_result' $errors
  if ($null -eq $Result) { return [pscustomobject]@{ Errors=$errors.ToArray() } }
  if ($Result.schema -ne 'hebrinex.agent_result' -or $Result.contract_version -ne '1.0.0' -or $Result.runtime_api -ne '1') { $errors.Add('invalid_contract:agent_result') | Out-Null }
  if (@('accepted','blocked','failed') -notcontains [string]$Result.status) { $errors.Add('invalid_result_status') | Out-Null }
  if (@('real_agent','simulated_roles') -notcontains [string]$Result.execution_mode) { $errors.Add('invalid_execution_mode') | Out-Null }
  foreach ($field in @('task_id','project_id','actor_id','role_id','summary')) { if ([string]::IsNullOrWhiteSpace([string]$Result.$field)) { $errors.Add("missing_input:agent_result.$field") | Out-Null } }
  if ($Result.execution_mode -eq 'real_agent' -and [string]::IsNullOrWhiteSpace([string]$Result.provider_id)) { $errors.Add('real_agent_missing_provider') | Out-Null }
  $roleProbe = Get-CapabilityDecision ([string]$Result.role_id) 'read_declared_files'
  if ($roleProbe.reason -eq 'unknown_role') { $errors.Add('unknown_role') | Out-Null }
  Test-Boolean $Result.instruction_authority 'agent_result.instruction_authority' $errors
  Test-Boolean $Result.writes 'agent_result.writes' $errors
  if ($Result.instruction_authority -ne $false) { $errors.Add('provider_output_cannot_be_authority') | Out-Null }
  Test-HashReference $Result.task_pack_ref 'agent_result.task_pack_ref' $errors
  $linkedTaskPack = $null
  if ($null -ne $Result.task_pack_ref) {
    try {
      $linkedTaskPack = Read-JsonFile ([string]$Result.task_pack_ref.path) 'task_pack'
      $taskValidation = Test-AgentTaskPack $linkedTaskPack
      foreach ($error in @($taskValidation.Errors)) { $errors.Add("linked_task_pack_invalid:$error") | Out-Null }
      if ($linkedTaskPack.task_id -ne $Result.task_id) { $errors.Add('result_task_mismatch') | Out-Null }
      if ($linkedTaskPack.project_id -ne $Result.project_id) { $errors.Add('result_project_mismatch') | Out-Null }
      if ($linkedTaskPack.actor_id -ne $Result.actor_id) { $errors.Add('result_actor_mismatch') | Out-Null }
      if ($linkedTaskPack.role_id -ne $Result.role_id) { $errors.Add('result_role_mismatch') | Out-Null }
      if ($linkedTaskPack.execution_mode -ne $Result.execution_mode) { $errors.Add('result_execution_mode_mismatch') | Out-Null }
    } catch { $errors.Add($_.Exception.Message) | Out-Null }
  }
  if ($Result.evidence -isnot [System.Array]) { $errors.Add('invalid_type:agent_result.evidence') | Out-Null }
  foreach ($evidence in @($Result.evidence)) {
    Test-ClosedObject $evidence @('path','sha256','kind') @('path','sha256','kind') 'agent_result.evidence' $errors
    if (@('input','test','output','decision') -notcontains [string]$evidence.kind) { $errors.Add('invalid_evidence_kind') | Out-Null }
    $hashRef = [pscustomobject]@{ path=[string]$evidence.path; sha256=[string]$evidence.sha256 }
    Test-HashReference $hashRef 'agent_result.evidence_hash' $errors
  }
  if ($Result.capability_decisions -isnot [System.Array]) { $errors.Add('invalid_type:agent_result.capability_decisions') | Out-Null }
  $hasEnforcedWrite = $false
  foreach ($item in @($Result.capability_decisions)) {
    Test-ClosedObject $item @('capability','decision','enforcement') @('capability','decision','enforcement') 'agent_result.capability_decision' $errors
    if (@('allow','block') -notcontains [string]$item.decision) { $errors.Add('invalid_capability_decision') | Out-Null }
    if (@('enforced','advisory','unsupported','not_tested') -notcontains [string]$item.enforcement) { $errors.Add('invalid_enforcement_status') | Out-Null }
    $roleDecision = Get-CapabilityDecision ([string]$Result.role_id) ([string]$item.capability)
    if ($null -ne $linkedTaskPack -and @($linkedTaskPack.capabilities.operations) -notcontains [string]$item.capability) { $errors.Add("result_capability_outside_task_pack:$($item.capability)") | Out-Null }
    if ($item.decision -eq 'allow' -and ($roleDecision.decision -ne 'allow' -or $item.enforcement -ne 'enforced')) { $errors.Add("result_capability_escalation:$($item.capability)") | Out-Null }
    if ($item.capability -eq 'edit_approved_write_set' -and $item.decision -eq 'allow' -and $item.enforcement -eq 'enforced' -and $roleDecision.decision -eq 'allow') { $hasEnforcedWrite = $true }
  }
  if ($Result.writes -eq $true -and -not $hasEnforcedWrite) { $errors.Add('result_write_without_enforced_capability') | Out-Null }
  if ($Result.writes -eq $true -and ($null -eq $linkedTaskPack -or @($linkedTaskPack.capabilities.write_paths).Count -eq 0)) { $errors.Add('result_write_outside_task_pack') | Out-Null }
  return [pscustomobject]@{ Errors=$errors.ToArray() }
}

function Write-ResultAndExit($Result, [bool]$Success) {
  if ($Json) { $Result | ConvertTo-Json -Depth 30 }
  else {
    Write-Output "Hebri-AI-Harness Agent Runtime $Action"
    foreach ($property in $Result.PSObject.Properties) { if ($property.Value -isnot [System.Collections.IEnumerable] -or $property.Value -is [string]) { Write-Output "$($property.Name)=$($property.Value)" } }
    if ($Success) { Write-Output 'Agent runtime enforcement OK' } else { Write-Output 'Agent runtime enforcement BLOCKED' }
  }
  if ($Success) { exit 0 }
  exit 1
}

if ($Action -eq 'Capability') {
  $capDecision = Get-CapabilityDecision $RoleId $Capability
  $transitionDecision = $null
  if ($capDecision.decision -eq 'allow' -and -not [string]::IsNullOrWhiteSpace($FromState) -and -not [string]::IsNullOrWhiteSpace($ToState)) {
    $stateOutput = & (Resolve-HarnessPath 'scripts/state-machine.ps1') -Root $script:RootPath -FromState $FromState -ToState $ToState -Json 2>&1
    $stateExit = $LASTEXITCODE
    try { $transitionDecision = ($stateOutput -join "`n") | ConvertFrom-Json } catch { $transitionDecision = $null }
    if ($stateExit -ne 0) {
      $capDecision.decision = 'block'
      if ($null -ne $transitionDecision -and -not [string]::IsNullOrWhiteSpace($transitionDecision.reason)) { $capDecision.reason = $transitionDecision.reason } else { $capDecision.reason = 'invalid_transition' }
    }
  }
  $result = [pscustomobject][ordered]@{ schema='hebrinex.runtime.agent_enforcement.decision'; version='0.1'; root=$script:RootPath; role_id=$RoleId; capability=$Capability; contract_ref=$capDecision.contract_ref; from_state=$FromState; to_state=$ToState; decision=$capDecision.decision; reason=$capDecision.reason; writes=$false; transition=$transitionDecision }
  Write-ResultAndExit $result ($capDecision.decision -eq 'allow')
}

if ($Action -in @('ValidateTaskPack','LoadContext','SelectProvider')) {
  try { $pack = Read-JsonFile $TaskPackPath 'task_pack' }
  catch {
    $result = [pscustomobject][ordered]@{ schema='hebrinex.runtime.agent_task_pack.decision'; contract_version='1.0.0'; runtime_api='1'; task_id=''; decision='block'; reason=$_.Exception.Message; errors=@($_.Exception.Message); capability_decisions=@(); writes=$false }
    Write-ResultAndExit $result $false
  }
  $validation = Test-AgentTaskPack $pack
  if ($Action -eq 'ValidateTaskPack') {
    $allowed = @($validation.Errors).Count -eq 0
    $result = [pscustomobject][ordered]@{ schema='hebrinex.runtime.agent_task_pack.decision'; contract_version='1.0.0'; runtime_api='1'; task_id=[string]$pack.task_id; decision=$(if($allowed){'allow'}else{'block'}); reason=(Get-Reason $validation 'task_pack_valid'); errors=@($validation.Errors); capability_decisions=@($validation.CapabilityDecisions); writes=$false }
    Write-ResultAndExit $result $allowed
  }
  if ($Action -eq 'LoadContext') {
    $sources = New-Object System.Collections.Generic.List[object]; $loadErrors = New-Object System.Collections.Generic.List[string]; $actualTokens = 0
    if (@($validation.Errors).Count -eq 0) {
      foreach ($reference in @($pack.context.references)) {
        $full = Resolve-DeclaredPath ([string]$reference.path)
        if (Test-Path -LiteralPath $full -PathType Leaf) {
          $bytes = [IO.File]::ReadAllBytes($full)
          $actualHash = Get-Sha256Bytes $bytes
          if ($actualHash -ne ([string]$reference.sha256).ToLowerInvariant()) { $loadErrors.Add("context_stale_after_load:$($reference.path)") | Out-Null }
          $chars = [Text.Encoding]::UTF8.GetString($bytes).Length; $tokens = [int][Math]::Ceiling($chars / 4.0); $actualTokens += $tokens
          $sources.Add([pscustomobject][ordered]@{ path=[string]$reference.path; sha256=$actualHash; reason=[string]$reference.reason; trust=[string]$reference.trust; required=[bool]$reference.required; chars=$chars; estimated_tokens=$tokens; instruction_authority=([string]$reference.trust -eq 'harness_authority') }) | Out-Null
        }
      }
    }
    $effectiveTokens = [int64][Math]::Max([int64]$actualTokens, [int64]$pack.budget.estimated_input_tokens)
    $threshold = [int][Math]::Floor(([int64]$pack.budget.max_task_input_tokens) * 0.8)
    $decision='allow'; $reason='declared_context_loaded'; $budgetStatus='known_within_budget'
    if (@($validation.Errors).Count -gt 0) { $decision='block'; $reason=(Get-Reason $validation ''); $budgetStatus='exceeded' }
    elseif ($loadErrors.Count -gt 0) { $decision='block'; $reason=[string]$loadErrors[0]; $budgetStatus='exceeded' }
    elseif ($effectiveTokens -gt [int64]$pack.budget.max_task_input_tokens) { $decision='block'; $reason='budget_exceeded:loaded_context'; $budgetStatus='exceeded' }
    elseif ($effectiveTokens -ge $threshold) { $decision='block'; $reason='repack_required:input_at_or_above_80_percent'; $budgetStatus='repack_required' }
    elseif ($null -eq $pack.budget.context_window_tokens) { $budgetStatus='unknown' }
    $result = [pscustomobject][ordered]@{ schema='hebrinex.context_load_report'; contract_version='1.0.0'; runtime_api='1'; task_id=[string]$pack.task_id; decision=$decision; reason=$reason; budget_status=$budgetStatus; estimated_input_tokens=$effectiveTokens; repack_threshold_tokens=$threshold; sources=$sources.ToArray(); cache_authority=$false; writes=$false }
    Write-ResultAndExit $result ($decision -eq 'allow')
  }
  if ($Action -eq 'SelectProvider') {
    $errors = New-Object System.Collections.Generic.List[string]
    foreach ($error in @($validation.Errors)) { $errors.Add($error) | Out-Null }
    try { $matrix = Read-JsonFile $ProviderMatrixPath 'provider_matrix' } catch { $errors.Add($_.Exception.Message) | Out-Null; $matrix = $null }
    if ($null -ne $matrix) {
      Test-ClosedObject $matrix @('schema','contract_version','runtime_api','harness_version','default_policy','allowed_statuses','providers') @('schema','contract_version','runtime_api','harness_version','default_policy','allowed_statuses','providers') 'provider_matrix' $errors
      if ($matrix.schema -ne 'hebrinex.provider_capability_matrix' -or $matrix.contract_version -ne '1.0.0' -or $matrix.runtime_api -ne '1' -or $matrix.default_policy -ne 'deny') { $errors.Add('invalid_contract:provider_matrix') | Out-Null }
      if ($matrix.providers -isnot [System.Array]) { $errors.Add('invalid_type:provider_matrix.providers') | Out-Null }
    }
    $provider = $null
    if ($null -ne $matrix) { $provider = @($matrix.providers | Where-Object { $_.id -eq $ProviderId }) | Select-Object -First 1 }
    if ($null -eq $provider) { $errors.Add("provider_unknown:$ProviderId") | Out-Null }
    else {
      Test-ClosedObject $provider @('id','host','adapter','model','execution_mode','network_required','availability','dimension_capabilities','capabilities','enforcement','evidence') @('id','host','adapter','model','execution_mode','network_required','availability','dimension_capabilities','capabilities','enforcement','evidence') 'provider' $errors
      Test-ClosedObject $provider.dimension_capabilities @('host','adapter','model') @('host','adapter','model') 'provider.dimension_capabilities' $errors
      Test-Boolean $provider.network_required 'provider.network_required' $errors
      if (@('real_agent','simulated_roles') -notcontains [string]$provider.execution_mode) { $errors.Add('invalid_execution_mode:provider') | Out-Null }
      if (@('available','unavailable','not_tested') -notcontains [string]$provider.availability) { $errors.Add('invalid_provider_availability') | Out-Null }
      Test-ClosedObject $provider.enforcement @('filesystem','network','process','provider_output_authority') @('filesystem','network','process','provider_output_authority') 'provider.enforcement' $errors
      foreach ($field in @('filesystem','network','process')) { if (@('enforced','advisory','unsupported','not_tested') -notcontains [string]$provider.enforcement.$field) { $errors.Add("invalid_enforcement_status:provider.$field") | Out-Null } }
      Test-Boolean $provider.enforcement.provider_output_authority 'provider.enforcement.provider_output_authority' $errors
      Test-ClosedObject $provider.evidence @('status','validated_at','source') @('status','validated_at','source') 'provider.evidence' $errors
      if (@('local_fixture','not_run') -notcontains [string]$provider.evidence.status) { $errors.Add('invalid_provider_evidence_status') | Out-Null }
      if ($provider.availability -ne 'available') { $errors.Add("provider_$($provider.availability):$ProviderId") | Out-Null }
      if ($provider.execution_mode -ne $pack.execution_mode) { $errors.Add("provider_execution_mode_mismatch:$($provider.execution_mode):$($pack.execution_mode)") | Out-Null }
      foreach ($operation in @($pack.capabilities.operations)) {
        $property = $provider.capabilities.PSObject.Properties[$operation]
        $status = if ($null -eq $property) { 'unsupported' } else { [string]$property.Value }
        if ($status -ne 'enforced') { $errors.Add("provider_capability_not_enforced:$operation`:$status") | Out-Null }
        foreach ($dimensionName in @('host','adapter','model')) {
          $dimension = $provider.dimension_capabilities.$dimensionName
          Test-ClosedObject $dimension @('id','capabilities') @('id','capabilities') "provider.dimension_capabilities.$dimensionName" $errors
          if ($null -ne $dimension -and [string]$dimension.id -ne [string]$provider.$dimensionName) { $errors.Add("provider_dimension_id_mismatch:$dimensionName") | Out-Null }
          $dimensionProperty = if ($null -ne $dimension) { $dimension.capabilities.PSObject.Properties[$operation] } else { $null }
          $dimensionStatus = if ($null -eq $dimensionProperty) { 'unsupported' } else { [string]$dimensionProperty.Value }
          foreach ($capabilityProperty in @($dimension.capabilities.PSObject.Properties)) { if (@('enforced','advisory','unsupported','not_tested') -notcontains [string]$capabilityProperty.Value) { $errors.Add("invalid_enforcement_status:$dimensionName`:$($capabilityProperty.Name)") | Out-Null } }
          if ($dimensionStatus -ne 'enforced') { $errors.Add("provider_dimension_not_enforced:$dimensionName`:$operation`:$dimensionStatus") | Out-Null }
        }
      }
      if ($provider.enforcement.provider_output_authority -ne $false) { $errors.Add('provider_output_cannot_be_authority') | Out-Null }
    }
    $allowed = $errors.Count -eq 0
    $result = [pscustomobject][ordered]@{ schema='hebrinex.runtime.provider_selection.decision'; contract_version='1.0.0'; runtime_api='1'; task_id=[string]$pack.task_id; provider_id=$ProviderId; decision=$(if($allowed){'allow'}else{'block'}); reason=$(if($allowed){'provider_capabilities_enforced'}else{[string]$errors[0]}); errors=$errors.ToArray(); execution_mode=$(if($null -ne $provider){[string]$provider.execution_mode}else{$null}); host=$(if($null -ne $provider){[string]$provider.host}else{$null}); adapter=$(if($null -ne $provider){[string]$provider.adapter}else{$null}); model=$(if($null -ne $provider){[string]$provider.model}else{$null}); provider_execution_approval_required=$(if($null -ne $provider){[bool]$provider.network_required}else{$false}); instruction_authority=$false; writes=$false }
    Write-ResultAndExit $result $allowed
  }
}

if ($Action -eq 'ValidateResult') {
  try { $agentResult = Read-JsonFile $ResultPath 'agent_result'; $validation = Test-AgentResult $agentResult }
  catch { $agentResult=$null; $validation=[pscustomobject]@{ Errors=@($_.Exception.Message) } }
  $allowed = @($validation.Errors).Count -eq 0
  $result = [pscustomobject][ordered]@{ schema='hebrinex.runtime.agent_result.decision'; contract_version='1.0.0'; runtime_api='1'; task_id=$(if($null -ne $agentResult){[string]$agentResult.task_id}else{''}); decision=$(if($allowed){'allow'}else{'block'}); reason=(Get-Reason $validation 'agent_result_valid'); errors=@($validation.Errors); instruction_authority=$false; writes=$false }
  Write-ResultAndExit $result $allowed
}

if ($Action -eq 'ValidateHandoff') {
  $errors = New-Object System.Collections.Generic.List[string]
  try { $handoff = Read-JsonFile $HandoffPath 'handoff' } catch { $handoff=$null; $errors.Add($_.Exception.Message) | Out-Null }
  if ($null -ne $handoff) {
    $top = @('schema','contract_version','runtime_api','handoff_id','task_id','project_id','from_actor_id','to_role_id','execution_mode','state','result_ref','source_refs','approval_refs','journal_refs','effects_to_execute','next_action')
    Test-ClosedObject $handoff $top $top 'handoff' $errors
    if ($handoff.schema -ne 'hebrinex.agent_handoff' -or $handoff.contract_version -ne '1.0.0' -or $handoff.runtime_api -ne '1') { $errors.Add('invalid_contract:handoff') | Out-Null }
    if ($handoff.state -ne 'ready') { $errors.Add('handoff_not_ready') | Out-Null }
    if (@('real_agent','simulated_roles') -notcontains [string]$handoff.execution_mode) { $errors.Add('invalid_execution_mode') | Out-Null }
    $handoffRoleProbe = Get-CapabilityDecision ([string]$handoff.to_role_id) 'read_declared_files'
    if ($handoffRoleProbe.reason -eq 'unknown_role') { $errors.Add('unknown_handoff_role') | Out-Null }
    foreach ($arrayField in @('source_refs','approval_refs','journal_refs','effects_to_execute')) { if ($handoff.$arrayField -isnot [System.Array]) { $errors.Add("invalid_type:handoff.$arrayField") | Out-Null } }
    Test-HashReference $handoff.result_ref 'handoff.result_ref' $errors
    foreach ($reference in @($handoff.source_refs)) { Test-HashReference $reference 'handoff.source_ref' $errors }
    if ($errors.Count -eq 0) {
      try {
        $linkedResult = Read-JsonFile ([string]$handoff.result_ref.path) 'agent_result'
        $resultValidation = Test-AgentResult $linkedResult
        foreach ($error in @($resultValidation.Errors)) { $errors.Add($error) | Out-Null }
        if ($linkedResult.task_id -ne $handoff.task_id) { $errors.Add('handoff_task_mismatch') | Out-Null }
        if ($linkedResult.project_id -ne $handoff.project_id) { $errors.Add('handoff_project_mismatch') | Out-Null }
        if ($linkedResult.execution_mode -ne $handoff.execution_mode) { $errors.Add('handoff_execution_mode_mismatch') | Out-Null }
      } catch { $errors.Add($_.Exception.Message) | Out-Null }
    }
    foreach ($reference in @($handoff.approval_refs)) {
      Test-ClosedObject $reference @('path','sha256','approval_id','required') @('path','sha256','approval_id','required') 'handoff.approval_ref' $errors
      Test-HashReference ([pscustomobject]@{ path=$reference.path; sha256=$reference.sha256 }) 'handoff.approval_hash' $errors
      try {
        $approval = Read-JsonFile ([string]$reference.path) 'approval'
        if ($approval.schema -ne 'hebrinex.scoped_approval' -or $approval.contract_version -ne '1.0.0' -or $approval.runtime_api -ne '1') { $errors.Add('invalid_contract:approval') | Out-Null }
        if ($approval.approval_id -ne $reference.approval_id) { $errors.Add('approval_id_mismatch') | Out-Null }
        if ($approval.project_id -ne $handoff.project_id) { $errors.Add('approval_project_mismatch') | Out-Null }
        if ($reference.required -eq $true -and $approval.status -ne 'approved') { $errors.Add("approval_not_active:$($approval.status)") | Out-Null }
        try { if ([DateTimeOffset]::Parse([string]$approval.expires_at) -le [DateTimeOffset]::UtcNow) { $errors.Add('approval_expired') | Out-Null } } catch { $errors.Add('approval_expiry_invalid') | Out-Null }
      } catch { $errors.Add($_.Exception.Message) | Out-Null }
    }
    foreach ($reference in @($handoff.journal_refs)) {
      Test-ClosedObject $reference @('path','sha256','effect_id') @('path','sha256','effect_id') 'handoff.journal_ref' $errors
      Test-HashReference ([pscustomobject]@{ path=$reference.path; sha256=$reference.sha256 }) 'handoff.journal_hash' $errors
      try {
        $journal = Read-JsonFile ([string]$reference.path) 'journal'
        if ($journal.schema -ne 'hebrinex.operation_journal' -or $journal.contract_version -ne '1.0.0' -or $journal.runtime_api -ne '1') { $errors.Add('invalid_contract:journal') | Out-Null }
        if ($journal.project_id -ne $handoff.project_id) { $errors.Add('journal_project_mismatch') | Out-Null }
        if (-not [string]::IsNullOrWhiteSpace([string]$journal.operation_id) -and $journal.operation_id -ne $reference.effect_id) { $errors.Add("journal_effect_id_mismatch:$($reference.effect_id)") | Out-Null }
        if (@($handoff.effects_to_execute) -contains [string]$reference.effect_id) {
          if ($journal.state -eq 'committed') { $errors.Add("already_committed_effect:$($reference.effect_id)") | Out-Null }
          elseif (@('applying','recovery_required') -contains [string]$journal.state) { $errors.Add("journal_requires_recovery:$($reference.effect_id)") | Out-Null }
        }
      } catch { $errors.Add($_.Exception.Message) | Out-Null }
    }
  }
  $allowed = $errors.Count -eq 0
  $result = [pscustomobject][ordered]@{ schema='hebrinex.runtime.agent_handoff.decision'; contract_version='1.0.0'; runtime_api='1'; handoff_id=$(if($null -ne $handoff){[string]$handoff.handoff_id}else{''}); task_id=$(if($null -ne $handoff){[string]$handoff.task_id}else{''}); decision=$(if($allowed){'allow'}else{'block'}); reason=$(if($allowed){'handoff_revalidated'}else{[string]$errors[0]}); errors=$errors.ToArray(); writes=$false }
  Write-ResultAndExit $result $allowed
}
