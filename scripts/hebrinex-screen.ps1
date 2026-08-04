param(
  [Parameter(Position = 0)]
  [ValidateSet('menu','providers','provider','doctor','guide')]
  [string]$Command = 'menu',
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [string]$Provider = '',
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Resolve-HarnessPath([string]$RelativePath) {
  if ([IO.Path]::IsPathRooted($RelativePath)) { return [IO.Path]::GetFullPath($RelativePath) }
  $norm = ($RelativePath -replace '\\','/').TrimStart('./')
  $mapped = switch -Regex ($norm) {
    '^PROJECT_BINDING[.]yaml$' { 'instance/PROJECT_BINDING.yaml'; break }
    '^orquestador/memory/local/(.+)$' { 'instance/memory/local/' + $Matches[1]; break }
    '^mcp/agents-backend[.]local[.]yaml$' { 'instance/mcp/agents-backend.local.yaml'; break }
    default { $norm }
  }
  $mappedPath = Join-Path $Root $mapped
  if ($mapped -ne $norm -and (Test-Path -LiteralPath $mappedPath)) {
    return [IO.Path]::GetFullPath($mappedPath)
  }
  return [IO.Path]::GetFullPath((Join-Path $Root $RelativePath))
}

function Read-HarnessText([string]$RelativePath) {
  $path = Resolve-HarnessPath $RelativePath
  if (-not [IO.File]::Exists($path)) { throw "missing file: $RelativePath" }
  return [IO.File]::ReadAllText($path)
}

function Get-Scalar([string]$Text, [string]$Key) {
  foreach ($line in ($Text -split "`n")) {
    if ($line -match ('^\s*' + [regex]::Escape($Key) + ':\s*(.*)\s*$')) {
      return $Matches[1].Trim().Trim('"').Trim("'")
    }
  }
  return ''
}

function Get-AdapterIds() {
  $registry = Read-HarnessText 'orquestador/adapter-registry.yaml'
  $ids = New-Object System.Collections.Generic.List[string]
  foreach ($line in ($registry -split "`n")) {
    if ($line -match '^\s*-\s+id:\s*([A-Za-z0-9_.-]+)\s*$') {
      [void]$ids.Add($Matches[1])
    }
  }
  return $ids
}

function Get-AdapterPath([string]$AdapterId) {
  return "orquestador/adapters/$AdapterId.yaml"
}

function Get-AdapterInfo([string]$AdapterId) {
  $path = Get-AdapterPath $AdapterId
  $text = Read-HarnessText $path
  $info = [ordered]@{
    provider_id = $AdapterId
    path = $path
    host = Get-Scalar $text 'host'
    maturity = Get-Scalar $text 'maturity'
    persistent_instruction_file = Get-Scalar $text 'persistent_instruction_file'
    context_entry_file = Get-Scalar $text 'context_entry_file'
    role_agents = Get-Scalar $text 'role_agents'
    mcp_config_file = Get-Scalar $text 'mcp_config_file'
    supports_real_subagents = Get-Scalar $text 'supports_real_subagents'
    supports_hooks = Get-Scalar $text 'supports_hooks'
    install_mechanism = Get-Scalar $text 'install_mechanism'
    memory_reliability = Get-Scalar $text 'memory_reliability'
    preflight_enforcement = Get-Scalar $text 'preflight_enforcement'
    evidence_policy = Get-Scalar $text 'evidence_policy'
  }
  if ([string]::IsNullOrWhiteSpace($info.host)) { $info.host = $AdapterId }
  return $info
}

function Get-ProviderCliCommand([string]$AdapterId) {
  switch ($AdapterId) {
    'claude-code' { return 'claude' }
    'codex' { return 'codex' }
    'gemini' { return 'gemini' }
    'qwen' { return 'qwen' }
    default { return '' }
  }
}

function Get-CommandStatus([string]$CommandName) {
  if ([string]::IsNullOrWhiteSpace($CommandName)) { return 'not_applicable' }
  $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
  if ($null -eq $cmd) { return 'not_found_in_path' }
  return 'found_in_path'
}

function Get-HarnessSummary() {
  $binding = Read-HarnessText 'PROJECT_BINDING.yaml'
  $sessionPin = Read-HarnessText 'orquestador/memory/local/session-pin.md'
  return [ordered]@{
    harness_version = (Read-HarnessText 'HARNESS_VERSION').Trim()
    binding_mode = Get-Scalar $binding 'binding_mode'
    project_root = Get-Scalar $binding 'project_root'
    stable_cli_contract = '0.5'
    screen_contract = '0.1'
    screen_status = 'experimental'
    chat_role = Get-Scalar $sessionPin 'chat_role'
    leader_required = Get-Scalar $sessionPin 'leader_required'
    writes = 'false'
  }
}

function Get-McpBackendSummary() {
  $text = Read-HarnessText 'mcp/agents-backend.yaml'
  $localOverride = Resolve-HarnessPath 'mcp/agents-backend.local.yaml'
  $localStatus = 'absent'
  if ([IO.File]::Exists($localOverride)) { $localStatus = 'present' }
  return [ordered]@{
    backend = Get-Scalar $text 'backend'
    timeout_seconds = Get-Scalar $text 'timeout_seconds'
    local_override = 'mcp/agents-backend.local.yaml'
    local_override_status = $localStatus
  }
}

function Write-KeyValueObject([hashtable]$Object) {
  foreach ($key in $Object.Keys) {
    $value = $Object[$key]
    if ($null -eq $value) { $value = '' }
    Write-Host "$key=$value"
  }
}

function Write-Menu() {
  $summary = Get-HarnessSummary
  Write-Host 'Hebri-AI-Harness Provider Screen'
  Write-KeyValueObject $summary
  Write-Host 'commands=menu,providers,provider,doctor,guide'
  Write-Host ''
  Write-Host 'Uso:'
  Write-Host '  .\scripts\hebrinex-screen.ps1 providers'
  Write-Host '  .\scripts\hebrinex-screen.ps1 provider -Provider codex'
  Write-Host '  .\scripts\hebrinex-screen.ps1 provider -Provider claude-code'
  Write-Host '  .\scripts\hebrinex-screen.ps1 guide -Provider qwen'
  Write-Host '  .\scripts\hebrinex-screen.ps1 doctor'
  Write-Host ''
  Write-Host 'Esta pantalla no guarda suscripciones ni secretos. La autenticacion queda en el CLI/API oficial de cada proveedor.'
}

function Write-Providers() {
  Write-Host 'providers:'
  foreach ($id in (Get-AdapterIds)) {
    $info = Get-AdapterInfo $id
    $cli = Get-ProviderCliCommand $id
    $cliStatus = Get-CommandStatus $cli
    Write-Host "- provider_id=$($info.provider_id) host=$($info.host) maturity=$($info.maturity) role_agents=$($info.role_agents) cli=$cli cli_status=$cliStatus"
  }
  Write-Host 'writes=false'
}

function Write-Provider([string]$AdapterId) {
  if ([string]::IsNullOrWhiteSpace($AdapterId)) { throw 'provider command requires -Provider <adapter_id>' }
  $ids = @(Get-AdapterIds)
  if ($ids -notcontains $AdapterId) { throw "unknown provider: $AdapterId" }
  $info = Get-AdapterInfo $AdapterId
  $cli = Get-ProviderCliCommand $AdapterId
  $cliStatus = Get-CommandStatus $cli
  $mcp = Get-McpBackendSummary

  if ($Json) {
    $out = [ordered]@{
      schema = 'hebrinex.provider_screen.provider'
      version = '0.1'
      writes = $false
      provider = $info
      cli_command = $cli
      cli_status = $cliStatus
      mcp_backend = $mcp
      auth_boundary = 'external_provider_cli_or_api'
      secrets_policy = 'do_not_store_subscriptions_or_api_keys_in_harness'
    }
    $out | ConvertTo-Json -Depth 5
    return
  }

  Write-Host "provider_id=$($info.provider_id)"
  Write-Host "host=$($info.host)"
  Write-Host "maturity=$($info.maturity)"
  Write-Host "persistent_instruction_file=$($info.persistent_instruction_file)"
  Write-Host "context_entry_file=$($info.context_entry_file)"
  Write-Host "role_agents=$($info.role_agents)"
  Write-Host "supports_real_subagents=$($info.supports_real_subagents)"
  Write-Host "supports_hooks=$($info.supports_hooks)"
  Write-Host "mcp_config_file=$($info.mcp_config_file)"
  Write-Host "install_mechanism=$($info.install_mechanism)"
  Write-Host "provider_cli=$cli"
  Write-Host "provider_cli_status=$cliStatus"
  Write-Host "mcp_default_backend=$($mcp.backend)"
  Write-Host "mcp_local_override=$($mcp.local_override)"
  Write-Host "mcp_local_override_status=$($mcp.local_override_status)"
  Write-Host 'auth_boundary=external_provider_cli_or_api'
  Write-Host 'secrets_policy=do_not_store_subscriptions_or_api_keys_in_harness'
  Write-Host 'writes=false'
  Write-Host ''
  Write-Host 'Como usarlo:'
  Write-Host '  1. Autentica el proveedor con su CLI/API oficial fuera del harness.'
  Write-Host '  2. Instala o copia la superficie persistente indicada para ese host.'
  Write-Host '  3. Si queres MCP, registra mcp/server.mjs en el archivo indicado por mcp_config_file.'
  Write-Host '  4. Si MCP no esta conectado, usa el adapter/prompt y roles simulados trazables.'
  Write-Host '  5. Para cualquier efecto, volve al preflight + SI del harness.'
}

function Write-Guide([string]$AdapterId) {
  if ([string]::IsNullOrWhiteSpace($AdapterId)) { throw 'guide command requires -Provider <adapter_id>' }
  Write-Provider $AdapterId
  Write-Host ''
  Write-Host 'Guia de vinculacion:'
  Write-Host '  - La suscripcion vive en el proveedor, no en el harness.'
  Write-Host '  - El harness solo declara contrato, rutas de instrucciones, MCP opcional y reglas de evidencia.'
  Write-Host '  - No asumas que MCP esta conectado: primero verifica registro y tools disponibles en el host.'
  Write-Host '  - Si el host no soporta subagentes reales, simula leader/worker/reviewer en el chat y registralo.'
}

function Write-Doctor() {
  $summary = Get-HarnessSummary
  $mcp = Get-McpBackendSummary
  Write-Host 'doctor=hebrinex_provider_screen'
  Write-KeyValueObject $summary
  Write-Host "adapters_count=$((Get-AdapterIds).Count)"
  Write-Host "mcp_default_backend=$($mcp.backend)"
  Write-Host "mcp_timeout_seconds=$($mcp.timeout_seconds)"
  Write-Host "mcp_local_override_status=$($mcp.local_override_status)"
  foreach ($id in (Get-AdapterIds)) {
    $cli = Get-ProviderCliCommand $id
    $cliStatus = Get-CommandStatus $cli
    Write-Host "provider=$id cli=$cli cli_status=$cliStatus"
  }
  Write-Host 'writes=false'
}

$Root = (Resolve-Path -LiteralPath $Root).Path

switch ($Command) {
  'menu' { Write-Menu }
  'providers' { Write-Providers }
  'provider' { Write-Provider $Provider }
  'guide' { Write-Guide $Provider }
  'doctor' { Write-Doctor }
}
