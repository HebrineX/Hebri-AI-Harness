param([string]$ProjectRoot = (Resolve-Path .).Path)

$ErrorActionPreference = "Stop"
$harness = Join-Path $ProjectRoot ".hebrinex"
$settings = Join-Path $harness "orquestador/integrations/claude/settings.template.json"
if (-not (Test-Path -LiteralPath $settings)) { Write-Error "Claude settings template missing" }
Write-Host "Preflight only: copy settings.template.json into Claude settings after operator SI."
