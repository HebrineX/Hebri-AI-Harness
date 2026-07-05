param(
  [string]$ProjectRoot = (Resolve-Path .).Path,
  [switch]$CheckOnly,
  [switch]$Apply
)

$ErrorActionPreference = "Stop"

if (($CheckOnly -and $Apply) -or (-not $CheckOnly -and -not $Apply)) {
  throw 'install-claude-hooks requires exactly one mode: -CheckOnly or -Apply'
}

$harnessRoot = Split-Path -Parent $PSScriptRoot
# In a bound project the harness lives under <project_root>/.hebrinex; in the
# source template repo the scripts live directly under <root>/scripts.
$isBound = (Split-Path -Leaf $harnessRoot) -eq '.hebrinex'
$scriptPrefix = if ($isBound) { '.hebrinex/scripts' } else { 'scripts' }

$reentryScript = Join-Path $harnessRoot 'scripts/claude-reentry.ps1'
$hookScript = Join-Path $harnessRoot 'scripts/claude-pretooluse-hook.ps1'
foreach ($required in @($reentryScript, $hookScript)) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
    throw "missing harness script: $required"
  }
}

$settingsDir = Join-Path $ProjectRoot '.claude'
$settingsPath = Join-Path $settingsDir 'settings.json'

$sessionStartCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPrefix/claude-reentry.ps1"
$preToolUseCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPrefix/claude-pretooluse-hook.ps1"

Write-Host 'Hebri-AI-Harness Claude hooks installer'
Write-Host "project_root=$ProjectRoot"
Write-Host "harness_root=$harnessRoot"
Write-Host "settings_path=$settingsPath"
Write-Host "session_start_hook=$sessionStartCommand"
Write-Host "pre_tool_use_hook=$preToolUseCommand"

if ($CheckOnly) {
  Write-Host 'planned_steps:'
  Write-Host ' - merge SessionStart hook (reentry brief) into .claude/settings.json'
  Write-Host ' - merge PreToolUse hook (command gateway) into .claude/settings.json'
  Write-Host 'writes=false'
  Write-Host 'apply_available=true'
  exit 0
}

$settings = [ordered]@{}
if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
  $existing = [IO.File]::ReadAllText($settingsPath)
  if (-not [string]::IsNullOrWhiteSpace($existing)) {
    $settings = $existing | ConvertFrom-Json
  }
}

if ($null -eq $settings.PSObject.Properties['hooks']) {
  $settings | Add-Member -MemberType NoteProperty -Name 'hooks' -Value ([pscustomobject]@{}) -Force
}

$sessionStartEntry = [pscustomobject]@{
  hooks = @([pscustomobject]@{ type = 'command'; command = $sessionStartCommand })
}
$preToolUseEntry = [pscustomobject]@{
  matcher = 'Bash|PowerShell'
  hooks = @([pscustomobject]@{ type = 'command'; command = $preToolUseCommand })
}

$settings.hooks | Add-Member -MemberType NoteProperty -Name 'SessionStart' -Value @($sessionStartEntry) -Force
$settings.hooks | Add-Member -MemberType NoteProperty -Name 'PreToolUse' -Value @($preToolUseEntry) -Force

if (-not (Test-Path -LiteralPath $settingsDir -PathType Container)) {
  New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
}
$json = $settings | ConvertTo-Json -Depth 10
[IO.File]::WriteAllText($settingsPath, ($json -replace "`r`n", "`n") + "`n", [Text.UTF8Encoding]::new($false))

Write-Host 'writes=true'
Write-Host 'install_status=applied'
