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

# Las 7 tools comprometidas deben estar registradas en el server.
foreach ($tool in @('run_command','preflight_approve','approval_check','session_contract','gate_check','memory_route','close_cycle_check')) {
  if ($serverText -notmatch ("registerTool\('" + [regex]::Escape($tool) + "'")) {
    Add-Failure "mcp/server.mjs does not register tool: $tool"
  }
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
