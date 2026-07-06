param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$failures = New-Object System.Collections.Generic.List[string]
function Fail($m){ $failures.Add($m) | Out-Null }
function P($rel){ Join-Path $Root $rel }
function T($rel){ if(!(Test-Path -LiteralPath (P $rel))){ Fail "missing $rel"; return '' }; [IO.File]::ReadAllText((P $rel)) }
$expected = @('claude-code','codex','gemini','cursor','copilot','qwen','deepseek','generic-ai')
$version = (T 'HARNESS_VERSION').Trim()
$matrix = T 'orquestador/portability/adapter-matrix.yaml'
foreach($id in $expected){
  if($matrix -notmatch "adapter_id: $([regex]::Escape($id))"){ Fail "adapter matrix missing $id" }
  $yaml = "orquestador/adapters/$id.yaml"
  $md = "orquestador/adapters/$id.md"
  $yt = T $yaml
  [void](T $md)
  foreach($needle in @("harness_version: `"$version`"",'memory_reliability: untrusted_for_evidence','preflight_enforcement: required_before_effects','detractor_senior','first_message','reentry_light','reentry_full','debug_log_intake','compactation_recovery')){
    if($yt -notmatch [regex]::Escape($needle)){ Fail "$yaml missing $needle" }
  }
  # 0.16.0: vaporware muerto. Cada adapter declara maturity, via de agentes de
  # rol y fecha de investigacion; "unknown" queda prohibido.
  if($yt -notmatch '(?m)^maturity: (production|experimental)$'){ Fail "$yaml missing maturity: production|experimental" }
  if($yt -notmatch '(?m)^role_agents: (native_subagents_or_mcp_daemon|via_mcp_daemon|prompt_simulation)$'){ Fail "$yaml missing role_agents declaration" }
  if($yt -notmatch '(?m)^investigated_at: "\d{4}-\d{2}-\d{2}"$'){ Fail "$yaml missing investigated_at date" }
  if($yt -match '(?m)^(supports_hooks|hook_support): unknown'){ Fail "$yaml still declares unknown hook support" }
}
if($matrix -match '(?m)hook_support: unknown'){ Fail 'adapter matrix still contains hook_support: unknown' }
foreach($needle in @('maturity: production','role_agents: via_mcp_daemon','role_agents: native_subagents_or_mcp_daemon')){
  if($matrix -notmatch [regex]::Escape($needle)){ Fail "adapter matrix missing $needle" }
}
# claude-code es el unico con subagentes reales declarados (roles auditor/reviewer).
$claudeYaml = T 'orquestador/adapters/claude-code.yaml'
if($claudeYaml -notmatch '(?m)^supports_real_subagents: true$'){ Fail 'claude-code.yaml must declare supports_real_subagents: true' }
if($claudeYaml -notmatch 'subagent_roles: \[auditor, reviewer\]'){ Fail 'claude-code.yaml must declare subagent_roles: [auditor, reviewer]' }

# Subagentes nativos generados: frontmatter con tools SOLO read-only.
# Aplica a los templates del harness y, si existen, a los instalados en .claude/agents.
$allowedTools = @('Read','Grep','Glob')
function Test-NativeAgentReadOnly([string]$FilePath, [string]$Label){
  $text = [IO.File]::ReadAllText($FilePath)
  $match = [regex]::Match($text, '(?m)^tools:\s*(.+)$')
  if(-not $match.Success){ Fail "$Label missing tools frontmatter"; return }
  foreach($tool in ($match.Groups[1].Value -split ',')){
    $t = $tool.Trim()
    if($t -and ($allowedTools -notcontains $t)){ Fail "$Label declares non read-only tool: $t" }
  }
}
$nativeAgentDirs = @('orquestador/integrations/claude/agents', '.claude/agents')
foreach($rel in $nativeAgentDirs){
  $dir = P $rel
  if(Test-Path -LiteralPath $dir -PathType Container){
    Get-ChildItem -LiteralPath $dir -Filter '*.md' -File | ForEach-Object {
      Test-NativeAgentReadOnly $_.FullName "$rel/$($_.Name)"
    }
  }
}
if(-not (Test-Path -LiteralPath (P 'orquestador/integrations/claude/agents/auditor-detractor.md'))){ Fail 'missing native agent template auditor-detractor.md' }
if(-not (Test-Path -LiteralPath (P 'orquestador/integrations/claude/agents/reviewer.md'))){ Fail 'missing native agent template reviewer.md' }

# Test negativo: el fixture con tool de escritura DEBE ser detectado.
$negativeFixture = P 'orquestador/testing/fixtures/negative/claude-agent-write-tool.md'
if(Test-Path -LiteralPath $negativeFixture){
  $before = $failures.Count
  Test-NativeAgentReadOnly $negativeFixture 'fixture-negative'
  if($failures.Count -eq $before){ Fail 'negative fixture claude-agent-write-tool.md was NOT detected as unsafe' }
  else { $failures.RemoveAt($failures.Count - 1) }
}
else { Fail 'missing orquestador/testing/fixtures/negative/claude-agent-write-tool.md' }

$badPattern = '\beentry[-_ ]?light\b|\breentry full\b|infoHebri[.]md.*(cargar|load)'
foreach($rel in @('orquestador/adapters','prompts')){
  Get-ChildItem -LiteralPath (P $rel) -Recurse -File | ForEach-Object {
    $txt=[IO.File]::ReadAllText($_.FullName)
    if($txt -match $badPattern){ Fail "adapter/preset drift token in $($_.FullName)" }
  }
}
if($failures.Count){ Write-Host 'Adapter drift failed:'; $failures | ForEach-Object { Write-Host "- $_" }; exit 2 }
Write-Host 'OK. Adapter portability drift check passed.'
exit 0
