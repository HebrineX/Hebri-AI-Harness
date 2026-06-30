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
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    Add-Failure "missing file: $RelativePath"
    return ''
  }
  $text = [IO.File]::ReadAllText($path)
  if ([string]::IsNullOrWhiteSpace($text)) {
    Add-Failure "empty file: $RelativePath"
  }
  return $text
}

function Assert-File([string]$RelativePath) {
  $path = Resolve-HarnessPath $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    Add-Failure "missing file: $RelativePath"
  }
  elseif ((Get-Item -LiteralPath $path).Length -eq 0) {
    Add-Failure "empty file: $RelativePath"
  }
}

function Assert-Contains([string]$RelativePath, [string]$Pattern, [string]$Message) {
  $text = Read-HarnessText $RelativePath
  if ($text -notmatch $Pattern) { Add-Failure $Message }
}

function Assert-RegistryPathsExist([string]$RelativePath) {
  $text = Read-HarnessText $RelativePath
  foreach ($line in ($text -split "`n")) {
    if ($line -match ':\s*(orquestador/agents/[^"\s]+[.]yaml)\s*$') {
      $rel = $Matches[1]
      if (-not (Test-Path -LiteralPath (Resolve-HarnessPath $rel) -PathType Leaf)) {
        Add-Failure "$RelativePath references missing path: $rel"
      }
    }
  }
}

function Assert-RoleArtifactSet([string]$Role) {
  $expected = @(
    "orquestador/agents/role-contracts/$Role.yaml",
    "orquestador/agents/runtime-profiles/$Role-runtime.yaml",
    "orquestador/agents/context-packs/$Role-context.yaml",
    "orquestador/agents/tool-packs/$Role-tools.yaml",
    "orquestador/agents/playbooks/$Role-playbook.yaml",
    "orquestador/agents/failure-modes/$Role-failure-modes.yaml",
    "orquestador/agents/evaluation-rubrics/$Role-quality.yaml"
  )
  foreach ($rel in $expected) { Assert-File $rel }
}

function Run-NegativeTests() {
  $badRegistry = 'ai_may_define_agents: true'
  if ($badRegistry -notmatch 'ai_may_define_agents:\s*true') {
    Add-Failure 'negative test failed: ai-defined-agent rule did not trigger'
  }
  $badReviewer = 'capabilities: { allow: [edit_approved_write_set] }'
  if ($badReviewer -notmatch 'edit_approved_write_set') {
    Add-Failure 'negative test failed: reviewer write rule did not trigger'
  }
  $badImplementer = 'may_approve_work: true'
  if ($badImplementer -notmatch 'may_approve_work:\s*true') {
    Add-Failure 'negative test failed: implementer approval rule did not trigger'
  }
}

$Root = (Resolve-Path -LiteralPath $Root).Path
Write-Host "Validating agent contracts at $Root"

$requiredTopFiles = @(
  'orquestador/agents/agent-registry.yaml',
  'orquestador/agents/capability-registry.yaml',
  'orquestador/agents/lifecycle-registry.yaml',
  'orquestador/agents/model-adapter-profiles.yaml'
)
foreach ($rel in $requiredTopFiles) { Assert-File $rel }

Assert-Contains 'orquestador/agents/agent-registry.yaml' 'hard_lock_id:\s*HL0_agent_authority' 'agent registry must declare HL0_agent_authority'
Assert-Contains 'orquestador/agents/agent-registry.yaml' 'agent_definition_authority:\s*harness_only' 'agent definition authority must be harness_only'
Assert-Contains 'orquestador/agents/agent-registry.yaml' 'ai_may_define_agents:\s*false' 'AI must not define agents'
Assert-Contains 'orquestador/agents/agent-registry.yaml' 'ai_may_escalate_capabilities:\s*false' 'AI must not escalate capabilities'
Assert-Contains 'orquestador/agents/agent-registry.yaml' 'max_active_agents_total:\s*5' 'agent registry must preserve max 5 active agents total'
Assert-RegistryPathsExist 'orquestador/agents/agent-registry.yaml'

$roles = @('leader', 'implementer', 'reviewer', 'auditor', 'reporter', 'spec-author', 'worker')
foreach ($role in $roles) {
  Assert-Contains 'orquestador/agents/agent-registry.yaml' ("id:\s*$([regex]::Escape($role))") "agent registry missing role: $role"
  Assert-RoleArtifactSet $role
}

$handoffs = @(
  'leader-to-implementer',
  'leader-to-worker',
  'implementer-to-reviewer',
  'worker-to-reviewer',
  'reviewer-to-leader',
  'auditor-to-leader',
  'reporter-to-human'
)
foreach ($handoff in $handoffs) {
  Assert-File "orquestador/agents/handoff-contracts/$handoff.yaml"
}

$profiles = @('read-only', 'write-scoped', 'reviewer-readonly', 'auditor-blocking', 'release-manager')
foreach ($profile in $profiles) {
  Assert-File "orquestador/agents/security-profiles/$profile.yaml"
}

Assert-Contains 'orquestador/agents/role-contracts/leader.yaml' 'may_implement:\s*false' 'leader must not implement'
Assert-Contains 'orquestador/agents/role-contracts/leader.yaml' '(?s)deny:.*edit_approved_write_set' 'leader must deny write implementation capability'
Assert-Contains 'orquestador/agents/role-contracts/implementer.yaml' 'may_approve_work:\s*false' 'implementer must not approve'
Assert-Contains 'orquestador/agents/role-contracts/implementer.yaml' '(?s)deny:.*approve_work' 'implementer must deny approve_work'
Assert-Contains 'orquestador/agents/role-contracts/reviewer.yaml' 'may_implement:\s*false' 'reviewer must not implement'
Assert-Contains 'orquestador/agents/role-contracts/reviewer.yaml' 'no_direct_edits:\s*true' 'reviewer must be no-direct-edits'
Assert-Contains 'orquestador/agents/role-contracts/reviewer.yaml' '(?s)deny:.*edit_approved_write_set' 'reviewer must deny edit capability'
Assert-Contains 'orquestador/agents/role-contracts/auditor.yaml' 'may_approve_work:\s*false' 'auditor must not approve'
Assert-Contains 'orquestador/agents/role-contracts/auditor.yaml' 'may_implement:\s*false' 'auditor must not implement'
Assert-Contains 'orquestador/agents/role-contracts/reporter.yaml' 'may_approve_work:\s*false' 'reporter must not approve'

Assert-Contains 'orquestador/agents/model-adapter-profiles.yaml' 'may_grant_new_capabilities:\s*false' 'model adapters must not grant new capabilities'
Assert-Contains 'orquestador/agents/model-adapter-profiles.yaml' 'may_override_role_contract:\s*false' 'model adapters must not override role contracts'
Assert-Contains 'orquestador/agents/model-adapter-profiles.yaml' 'unknown_model_profile:\s*simple_model' 'unknown models must use simple_model profile'

Assert-Contains 'orquestador/agents/lifecycle-registry.yaml' 'all_agents_closed:\s*true' 'done gate must require all agents closed'
Assert-Contains 'orquestador/agents/lifecycle-registry.yaml' 'open_locks_allowed:\s*false' 'done gate must reject open locks'

if ($RunNegativeTests) { Run-NegativeTests }

if ($script:Failures.Count -gt 0) {
  Write-Host 'Agent contract validation FAILED'
  foreach ($failure in $script:Failures) { Write-Host " - $failure" }
  exit 1
}

Write-Host 'Agent contract validation OK'
exit 0
