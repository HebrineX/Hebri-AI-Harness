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

function Assert-FixtureRejected([string]$RelativePath, [string]$Pattern, [string]$Message) {
  $text = Read-HarnessText $RelativePath
  if ($text -notmatch $Pattern) {
    Add-Failure "fixture did not trigger expected rejection: $RelativePath ($Message)"
  }
}

$Root = (Resolve-Path -LiteralPath $Root).Path
Write-Host "Validating harness fixtures at $Root"

$schemas = @(
  'orquestador/policies/schemas/agent-registry.schema.yaml',
  'orquestador/policies/schemas/agent-role-contract.schema.yaml',
  'orquestador/policies/schemas/security-policy.schema.yaml',
  'orquestador/policies/schemas/migration-registry.schema.yaml'
)
foreach ($rel in $schemas) { Assert-File $rel }

Assert-Contains 'orquestador/policies/schemas/agent-registry.schema.yaml' 'agent_definition_authority:\s*harness_only' 'agent registry schema must require harness_only authority'
Assert-Contains 'orquestador/policies/schemas/agent-role-contract.schema.yaml' 'Implementer may not approve work' 'role contract schema must encode implementer approval deny'
Assert-Contains 'orquestador/policies/schemas/security-policy.schema.yaml' 'Network defaults to deny' 'security schema must encode network default deny'
Assert-Contains 'orquestador/policies/schemas/migration-registry.schema.yaml' 'CheckOnly writes false' 'migration schema must encode CheckOnly no-write'

$fixtures = @(
  'orquestador/testing/fixtures/README.md',
  'orquestador/testing/fixtures/positive/agent-registry-minimal.yaml',
  'orquestador/testing/fixtures/negative/agent-ai-defined-agent.yaml',
  'orquestador/testing/fixtures/negative/agent-reviewer-write.yaml',
  'orquestador/testing/fixtures/negative/agent-implementer-approve.yaml',
  'orquestador/testing/fixtures/negative/security-network-default-allow.yaml',
  'orquestador/testing/fixtures/negative/security-path-traversal.yaml',
  'orquestador/testing/fixtures/negative/migration-checkonly-writes.yaml',
  'orquestador/testing/fixtures/positive/command-readonly-safe.txt',
  'orquestador/testing/fixtures/positive/runtime-implementer-write.yaml',
  'orquestador/testing/fixtures/negative/command-invoke-expression.txt',
  'orquestador/testing/fixtures/negative/command-curl-pipe.txt',
  'orquestador/testing/fixtures/negative/command-git-push.txt',
  'orquestador/testing/fixtures/negative/command-remove-recurse-force.txt',
  'orquestador/testing/fixtures/negative/command-unknown.txt',
  'orquestador/testing/fixtures/negative/command-secret-bearing.txt',
  'orquestador/testing/fixtures/negative/command-risk-mismatch.txt',
  'orquestador/testing/fixtures/negative/runtime-reviewer-write.yaml',
  'orquestador/testing/fixtures/negative/state-active-to-closed.yaml'
)
foreach ($rel in $fixtures) { Assert-File $rel }

Assert-Contains 'orquestador/testing/fixtures/positive/agent-registry-minimal.yaml' 'agent_definition_authority:\s*harness_only' 'positive agent fixture must keep harness_only'
Assert-Contains 'orquestador/testing/fixtures/positive/agent-registry-minimal.yaml' 'ai_may_define_agents:\s*false' 'positive agent fixture must deny AI-defined agents'
Assert-Contains 'orquestador/testing/fixtures/positive/runtime-implementer-write.yaml' 'expected_decision:\s*allow' 'positive runtime fixture must allow implementer write capability'

Assert-FixtureRejected 'orquestador/testing/fixtures/negative/agent-ai-defined-agent.yaml' 'ai_may_define_agents:\s*true|agent_definition_authority:\s*prompt' 'AI-defined agents must reject'
Assert-FixtureRejected 'orquestador/testing/fixtures/negative/agent-reviewer-write.yaml' 'id:\s*reviewer[\s\S]*edit_approved_write_set|no_direct_edits:\s*false' 'reviewer write must reject'
Assert-FixtureRejected 'orquestador/testing/fixtures/negative/agent-implementer-approve.yaml' 'id:\s*implementer[\s\S]*may_approve_work:\s*true|allow:\s*\[[^\]]*approve_work' 'implementer approval must reject'
Assert-FixtureRejected 'orquestador/testing/fixtures/negative/security-network-default-allow.yaml' 'default:\s*allow' 'network default allow must reject'
Assert-FixtureRejected 'orquestador/testing/fixtures/negative/security-path-traversal.yaml' '[.][.]/|reject_dotdot_segments:\s*false' 'path traversal must reject'
Assert-FixtureRejected 'orquestador/testing/fixtures/negative/migration-checkonly-writes.yaml' 'check_only_writes:\s*true|apply_requires_backup:\s*false' 'CheckOnly writes must reject'
Assert-FixtureRejected 'orquestador/testing/fixtures/negative/command-invoke-expression.txt' 'Invoke-Expression|iex' 'Invoke-Expression command must reject'
Assert-FixtureRejected 'orquestador/testing/fixtures/negative/command-curl-pipe.txt' 'curl[\s\S]*[|]' 'curl pipe command must reject'
Assert-FixtureRejected 'orquestador/testing/fixtures/negative/command-git-push.txt' 'git push' 'git push command must reject'
Assert-FixtureRejected 'orquestador/testing/fixtures/negative/command-remove-recurse-force.txt' 'Remove-Item[\s\S]*-Recurse[\s\S]*-Force|rm -rf' 'force recursive delete command must reject'
Assert-FixtureRejected 'orquestador/testing/fixtures/negative/command-unknown.txt' 'whoami' 'unknown command must reject'
Assert-FixtureRejected 'orquestador/testing/fixtures/negative/command-secret-bearing.txt' '[.]env|token|secret|password|credential' 'secret-bearing command must reject'
Assert-FixtureRejected 'orquestador/testing/fixtures/negative/command-risk-mismatch.txt' 'Get-Content' 'declared risk mismatch fixture must start from safe command'
Assert-FixtureRejected 'orquestador/testing/fixtures/negative/runtime-reviewer-write.yaml' 'role_id:\s*reviewer[\s\S]*capability:\s*edit_approved_write_set[\s\S]*expected_decision:\s*block' 'reviewer runtime write must reject'
Assert-FixtureRejected 'orquestador/testing/fixtures/negative/state-active-to-closed.yaml' 'from_state:\s*active[\s\S]*to_state:\s*closed[\s\S]*expected_decision:\s*block' 'active to closed transition must reject'

if ($RunNegativeTests) {
  $bad = 'id: reviewer capabilities: { allow: [edit_approved_write_set] }'
  if ($bad -notmatch 'reviewer[\s\S]*edit_approved_write_set') {
    Add-Failure 'negative test failed: reviewer edit pattern did not trigger'
  }
}

if ($script:Failures.Count -gt 0) {
  Write-Host 'Fixture validation FAILED'
  foreach ($failure in $script:Failures) { Write-Host " - $failure" }
  exit 1
}

Write-Host 'Fixture validation OK'
exit 0
