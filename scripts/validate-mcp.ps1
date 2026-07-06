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

function Assert-Contains([string]$RelativePath, [string]$Pattern, [string]$Message) {
  $text = Read-HarnessText $RelativePath
  if ($text -notmatch $Pattern) { Add-Failure $Message }
}

Write-Host 'Hebri-AI-Harness MCP validation'
Write-Host "root=$Root"

# --- Estructura (siempre) -----------------------------------------------------

$serverText = Read-HarnessText 'mcp/server.mjs'
$packageText = Read-HarnessText 'mcp/package.json'
Read-HarnessText 'mcp/smoke.mjs' | Out-Null
Read-HarnessText 'mcp/README.md' | Out-Null
$mcpJsonText = Read-HarnessText '.mcp.json'

if ($packageText -notmatch '"@modelcontextprotocol/sdk"') {
  Add-Failure 'mcp/package.json does not declare @modelcontextprotocol/sdk dependency'
}
if ($packageText -notmatch '"type":\s*"module"') {
  Add-Failure 'mcp/package.json must declare type module'
}

if ($mcpJsonText -notmatch '"hebrinex"') {
  Add-Failure '.mcp.json does not register the hebrinex server'
}
if ($mcpJsonText -notmatch 'mcp/server\.mjs') {
  Add-Failure '.mcp.json does not point to mcp/server.mjs'
}

# Las 13 tools comprometidas deben estar registradas en el server.
foreach ($tool in @('run_command','preflight_approve','approval_check','session_contract','gate_check','memory_route','close_cycle_check','session_usage','role_assume','lock_acquire','lock_release','agent_audit','agent_review')) {
  if ($serverText -notmatch ("registerTool\('" + [regex]::Escape($tool) + "'")) {
    Add-Failure "mcp/server.mjs does not register tool: $tool"
  }
}

# Identidad de rol honesta: el rol vive en el estado del daemon y las tools con
# efecto consultan agent-runtime.ps1 con ese rol (no con uno del caller).
if ($serverText -notmatch 'assumedRole') {
  Add-Failure 'mcp/server.mjs must keep the assumed role in daemon process state'
}
if ($serverText -notmatch 'scripts/agent-runtime\.ps1') {
  Add-Failure 'mcp/server.mjs must consult scripts/agent-runtime.ps1 for role capabilities'
}
if ($serverText -notmatch 'role_capability_blocked') {
  Add-Failure 'mcp/server.mjs must block effect tools when the assumed role lacks the capability'
}
# lock_acquire/lock_release deben envolver el comando CLI, no reimplementar locks.
if ($serverText -notmatch "'lock',\s*'-Root'") {
  Add-Failure 'mcp/server.mjs lock tools must wrap the hebrinex lock CLI command'
}

# run_command debe pasar por el command gateway y preflight_approve por approve.
if ($serverText -notmatch 'scripts/command-gateway\.ps1') {
  Add-Failure 'mcp/server.mjs must route execution through scripts/command-gateway.ps1'
}
if ($serverText -notmatch "'approve'") {
  Add-Failure 'mcp/server.mjs must create approvals via hebrinex approve'
}
if ($serverText -match 'child_process.*exec\(|\bexecSync\b|\bexec\(') {
  Add-Failure 'mcp/server.mjs must not use shell exec (spawn only, no shell interpolation)'
}

Assert-Contains 'orquestador/harness-manifest.txt' '(?m)^file mcp/server\.mjs$' 'harness-manifest.txt does not include mcp/server.mjs'
Assert-Contains 'orquestador/harness-manifest.txt' '(?m)^file scripts/validate-mcp\.ps1$' 'harness-manifest.txt does not include validate-mcp.ps1'
Assert-Contains 'orquestador/harness-manifest.txt' '(?m)^file mcp/model-pricing\.yaml$' 'harness-manifest.txt does not include mcp/model-pricing.yaml'

# Agentes de rol: backend configurable fuera del codigo, prompt desde la
# fuente unica agents/<rol>.md, error claro sin backend, y read-only real
# (allowedTools / sandbox restringidos en los comandos fijos de la config).
$agentsBackendText = Read-HarnessText 'mcp/agents-backend.yaml'
$agentBackendsModule = Read-HarnessText 'mcp/agent-backends.mjs'
if ($agentsBackendText -notmatch 'schema:\s*hebrinex\.agents_backend') {
  Add-Failure 'mcp/agents-backend.yaml must declare schema hebrinex.agents_backend'
}
if ($agentsBackendText -notmatch '(?m)^backend:\s*(claude-cli|codex-cli|none)\s*$') {
  Add-Failure 'mcp/agents-backend.yaml must declare backend: claude-cli|codex-cli|none'
}
if ($agentsBackendText -notmatch '--allowedTools "Read,Grep,Glob"') {
  Add-Failure 'agents-backend.yaml claude-cli command must restrict --allowedTools to Read,Grep,Glob'
}
if ($agentsBackendText -notmatch '--sandbox read-only') {
  Add-Failure 'agents-backend.yaml codex-cli command must use --sandbox read-only'
}
if ($serverText -notmatch 'agents_backend_not_configured') {
  Add-Failure 'agent tools must fail with agents_backend_not_configured when no backend is set'
}
if ($serverText -notmatch 'agents/detractor-senior\.md') {
  Add-Failure 'agent_audit must build its prompt from agents/detractor-senior.md (single source)'
}
if ($serverText -notmatch 'agents/reviewer\.md') {
  Add-Failure 'agent_review must build its prompt from agents/reviewer.md (single source)'
}
if ($agentBackendsModule -notmatch 'stdin') {
  Add-Failure 'mcp/agent-backends.mjs must pass the prompt via stdin (never argv interpolation)'
}
Assert-Contains 'orquestador/harness-manifest.txt' '(?m)^file mcp/agent-backends\.mjs$' 'harness-manifest.txt does not include mcp/agent-backends.mjs'
Assert-Contains 'orquestador/harness-manifest.txt' '(?m)^file mcp/agents-backend\.yaml$' 'harness-manifest.txt does not include mcp/agents-backend.yaml'

# session_usage: precios editables fuera del codigo + sin datos inventados.
$pricingText = Read-HarnessText 'mcp/model-pricing.yaml'
if ($pricingText -notmatch 'schema:\s*hebrinex\.model_pricing') {
  Add-Failure 'mcp/model-pricing.yaml must declare schema hebrinex.model_pricing'
}
if ($pricingText -notmatch '(?m)^models:\s*$') {
  Add-Failure 'mcp/model-pricing.yaml must declare a models table'
}
if ($serverText -notmatch 'model-pricing\.yaml') {
  Add-Failure 'mcp/server.mjs must read prices from mcp/model-pricing.yaml (not hardcoded)'
}
if ($serverText -notmatch 'transcripts_dir_not_found') {
  Add-Failure 'session_usage must fail with a clear error when transcripts are missing'
}

# --- Smoke (solo si hay node y dependencias instaladas) ------------------------

$nodeCommand = Get-Command node -ErrorAction SilentlyContinue
$sdkPath = Resolve-HarnessPath 'mcp/node_modules/@modelcontextprotocol/sdk'
$smokeStatus = 'skipped'
if ($null -eq $nodeCommand) {
  Write-Host 'smoke=skipped reason=node_not_available'
}
elseif (-not (Test-Path -LiteralPath $sdkPath -PathType Container)) {
  Write-Host 'smoke=skipped reason=sdk_not_installed (run: cd mcp; npm install)'
}
else {
  $smokePath = Resolve-HarnessPath 'mcp/smoke.mjs'
  $output = & $nodeCommand.Source $smokePath 2>&1
  $smokeExit = $LASTEXITCODE
  if ($smokeExit -ne 0) {
    $smokeStatus = 'failed'
    Add-Failure "mcp smoke test failed (exit $smokeExit): $((($output | Select-Object -Last 5) -join ' | '))"
  }
  else {
    $smokeStatus = 'passed'
  }
  Write-Host "smoke=$smokeStatus"
}

if ($RunNegativeTests) {
  # Negativo estructural: el server no debe ofrecer ninguna via de ejecucion
  # alternativa al gateway (p. ej. una tool que ejecute texto arbitrario).
  if ($serverText -match "registerTool\('(shell|exec|eval|raw_command)'") {
    Add-Failure 'mcp/server.mjs exposes a bypass execution tool'
  }
  Write-Host 'negative_structural=checked'
}

if ($script:Failures.Count -gt 0) {
  Write-Host 'MCP validation FAILED:'
  foreach ($failure in $script:Failures) { Write-Host " - $failure" }
  exit 2
}

Write-Host 'MCP validation OK'
exit 0
