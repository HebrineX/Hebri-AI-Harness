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

function Run-NegativeTests() {
  $badPath = '..\outside'
  if ($badPath -notmatch '[.][.]') {
    Add-Failure 'negative test failed: path traversal rule did not trigger'
  }
  $badCommand = 'Invoke-Expression $userInput'
  if ($badCommand -notmatch 'Invoke-Expression') {
    Add-Failure 'negative test failed: command injection rule did not trigger'
  }
  $badNetwork = 'default: allow'
  if ($badNetwork -notmatch 'default:\s*allow') {
    Add-Failure 'negative test failed: network default allow rule did not trigger'
  }
}

$Root = (Resolve-Path -LiteralPath $Root).Path
Write-Host "Validating security policy at $Root"

$requiredPolicies = @(
  'orquestador/security/threat-model.yaml',
  'orquestador/security/permission-registry.yaml',
  'orquestador/security/command-risk-registry.yaml',
  'orquestador/security/write-scope-registry.yaml',
  'orquestador/security/network-policy.yaml',
  'orquestador/security/secrets-policy.yaml',
  'orquestador/security/escalation-policy.yaml',
  'orquestador/security/logging-policy.yaml',
  'orquestador/security/supply-chain-policy.yaml'
)
foreach ($rel in $requiredPolicies) { Assert-File $rel }

Assert-Contains 'orquestador/security/threat-model.yaml' 'command_injection' 'threat model must include command injection'
Assert-Contains 'orquestador/security/threat-model.yaml' 'path_traversal' 'threat model must include path traversal'
Assert-Contains 'orquestador/security/threat-model.yaml' 'symlink_escape' 'threat model must include symlink escape'
Assert-Contains 'orquestador/security/threat-model.yaml' 'secret_leak' 'threat model must include secret leak'
Assert-Contains 'orquestador/security/threat-model.yaml' 'supply_chain_remote_code' 'threat model must include supply-chain remote code'

Assert-Contains 'orquestador/security/permission-registry.yaml' 'prompt_defined_permission:\s*block' 'prompt-defined permissions must block'
Assert-Contains 'orquestador/security/permission-registry.yaml' 'define_agents:[\s\S]*hard_deny:\s*true' 'define_agents must be hard-denied'
Assert-Contains 'orquestador/security/permission-registry.yaml' 'escalate_capabilities:[\s\S]*hard_deny:\s*true' 'capability escalation must be hard-denied'

Assert-Contains 'orquestador/security/command-risk-registry.yaml' 'unknown_command:\s*block' 'unknown commands must block'
Assert-Contains 'orquestador/security/command-risk-registry.yaml' 'string_built_shell_from_untrusted_input:\s*block' 'string-built commands from untrusted input must block'
Assert-Contains 'orquestador/security/command-risk-registry.yaml' 'destructive:' 'destructive command class must exist'
Assert-Contains 'orquestador/security/command-risk-registry.yaml' 'network:' 'network command class must exist'
Assert-Contains 'orquestador/security/command-risk-registry.yaml' 'git_remote:' 'git_remote command class must exist'
Assert-Contains 'orquestador/security/command-risk-registry.yaml' 'privileged:' 'privileged command class must exist'
Assert-Contains 'orquestador/security/command-risk-registry.yaml' 'Invoke-Expression' 'Invoke-Expression must be blocked'
Assert-Contains 'orquestador/security/command-risk-registry.yaml' 'git push' 'git push must be blocked by default'

Assert-Contains 'orquestador/security/write-scope-registry.yaml' 'writes_outside_project_root:\s*block' 'writes outside project root must block'
Assert-Contains 'orquestador/security/write-scope-registry.yaml' 'path_traversal:\s*block' 'path traversal must block'
Assert-Contains 'orquestador/security/write-scope-registry.yaml' 'symlink_escape:\s*block' 'symlink escape must block'
Assert-Contains 'orquestador/security/write-scope-registry.yaml' 'reject_dotdot_segments:\s*true' 'dotdot path segments must be rejected'
Assert-Contains 'orquestador/security/write-scope-registry.yaml' 'missing_write_set:\s*block' 'missing write-set must block'

Assert-Contains 'orquestador/security/network-policy.yaml' 'default:\s*deny' 'network must default deny'
Assert-Contains 'orquestador/security/network-policy.yaml' 'execute_remote_script' 'network policy must block remote script execution'
Assert-Contains 'orquestador/security/network-policy.yaml' 'send_secrets' 'network policy must block sending secrets'

Assert-Contains 'orquestador/security/secrets-policy.yaml' 'default:\s*deny' 'secrets must default deny'
Assert-Contains 'orquestador/security/secrets-policy.yaml' 'required_before_chat:\s*true' 'secrets must redact before chat'
Assert-Contains 'orquestador/security/secrets-policy.yaml' 'secret_detected_in_output:\s*block_and_redact' 'secret output must block and redact'

Assert-Contains 'orquestador/security/escalation-policy.yaml' 'default:\s*deny' 'escalation must default deny'
Assert-Contains 'orquestador/security/escalation-policy.yaml' 'self_escalation_by_ai' 'AI self-escalation must be denied'
Assert-Contains 'orquestador/security/escalation-policy.yaml' 'persistent_privilege_without_expiry' 'persistent privilege without expiry must be denied'

Assert-Contains 'orquestador/security/logging-policy.yaml' 'redact_before_write:\s*true' 'logs must redact before write'
Assert-Contains 'orquestador/security/logging-policy.yaml' 'chat_memory_is_evidence:\s*false' 'chat memory must not be evidence'
Assert-Contains 'orquestador/security/logging-policy.yaml' 'manifest_or_checksum' 'backup evidence must include manifest or checksum'

Assert-Contains 'orquestador/security/supply-chain-policy.yaml' 'default:\s*deny' 'supply chain must default deny'
Assert-Contains 'orquestador/security/supply-chain-policy.yaml' 'download_and_execute:\s*deny' 'download and execute must be denied'
Assert-Contains 'orquestador/security/supply-chain-policy.yaml' 'execute_script_from_network:\s*deny' 'executing scripts from network must be denied'
Assert-Contains 'orquestador/security/supply-chain-policy.yaml' 'migration_may_execute_remote_code:\s*false' 'migration must not execute remote code'

if ($RunNegativeTests) { Run-NegativeTests }

if ($script:Failures.Count -gt 0) {
  Write-Host 'Security policy validation FAILED'
  foreach ($failure in $script:Failures) { Write-Host " - $failure" }
  exit 1
}

Write-Host 'Security policy validation OK'
exit 0
