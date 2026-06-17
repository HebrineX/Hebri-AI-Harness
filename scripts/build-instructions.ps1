param([string]$Root = (Split-Path -Parent $PSScriptRoot), [switch]$WriteOutputs)
$ErrorActionPreference = "Stop"
$registry = Join-Path $Root "orquestador/instruction-builder/instruction-registry.yaml"
if (-not (Test-Path -LiteralPath $registry)) { Write-Error "instruction registry missing" }
$fragments = @("kernel","preflight","memory-routing","roles","claude-hooks","denylists")
foreach ($f in $fragments) {
  $path = Join-Path $Root "orquestador/instruction-builder/fragments/$f.md"
  if (-not (Test-Path -LiteralPath $path)) { Write-Error "missing fragment $f" }
}
$hashInput = ($fragments | ForEach-Object { Get-Content -Raw -LiteralPath (Join-Path $Root "orquestador/instruction-builder/fragments/$_.md") }) -join "`n---`n"
$sha256 = [System.Security.Cryptography.SHA256]::Create()
try {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($hashInput)
  $hashBytes = $sha256.ComputeHash($bytes)
  $hash = ([System.BitConverter]::ToString($hashBytes) -replace "-", "").ToLowerInvariant()
}
finally {
  if ($sha256) { $sha256.Dispose() }
}
if ($WriteOutputs) { Write-Error "Writing generated instructions requires explicit implementation in a bound project" }
Write-Host "OK. Instruction builder check-only passed. fragments_sha256=$hash"
