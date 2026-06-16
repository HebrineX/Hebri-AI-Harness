param([switch]$CheckOnly)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$briefDir = Join-Path $Root "orquestador/runtime/claude"
$brief = Join-Path $briefDir "reentry-brief.md"
$binding = Join-Path $Root "PROJECT_BINDING.yaml"
if (-not (Test-Path -LiteralPath $binding)) { Write-Error "PROJECT_BINDING.yaml missing" }
New-Item -ItemType Directory -Force -Path $briefDir | Out-Null
if ($CheckOnly -and -not (Test-Path -LiteralPath $brief)) { Write-Error "Claude reentry brief missing" }
if (-not $CheckOnly) {
  $version = (Get-Content -LiteralPath (Join-Path $Root "HARNESS_VERSION") -TotalCount 1)
  $content = @(' # Claude Reentry Brief', '', "- Harness path: $Root", "- Version: $version", '- Approvals expired: true', '- Actions with effects require preflight + SI')
  [IO.File]::WriteAllText($brief, (($content -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
}
Write-Host "OK. Claude reentry checked."
