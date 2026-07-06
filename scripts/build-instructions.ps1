param([string]$Root = (Split-Path -Parent $PSScriptRoot), [switch]$WriteOutputs)
$ErrorActionPreference = "Stop"

# Instruction builder:
# 1) Verifica fragments y calcula su hash (contrato historico del builder).
# 2) Genera las capas derivadas de roles desde la fuente unica agents/<rol>.md:
#    role-contracts/*.yaml, prompts/roles/*.prompt.md y el bloque role_defaults
#    de capability-registry.yaml. En modo default compara contra disco y falla
#    (exit 2) si un derivado fue editado a mano; con -WriteOutputs regenera.

$registryPath = Join-Path $Root "orquestador/instruction-builder/instruction-registry.yaml"
if (-not (Test-Path -LiteralPath $registryPath)) { Write-Error "instruction registry missing" }
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

# --- Generacion de capas de roles ----------------------------------------------

function Read-Lf([string]$Path) {
  return ([IO.File]::ReadAllText($Path) -replace "`r`n", "`n")
}

function Write-Lf([string]$Path, [string]$Text) {
  [IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), [Text.UTF8Encoding]::new($false))
}

function Get-GeneratedBlock([string]$Text, [string]$Kind, [string]$SourceRel) {
  $pattern = "(?s)<!-- hebrinex:generate " + [regex]::Escape($Kind) + " -->\n(.*?)<!-- hebrinex:end -->"
  $match = [regex]::Match($Text, $pattern)
  if (-not $match.Success) { Write-Error "missing generated block '$Kind' in $SourceRel" }
  return $match.Groups[1].Value
}

$registryText = Read-Lf $registryPath

# Parser generico de secciones "clave: {mapa inline}" del instruction registry.
function Get-RegistrySectionEntries([string]$Text, [string]$Section, [string[]]$Keys) {
  $entries = New-Object System.Collections.Generic.List[object]
  $inside = $false
  foreach ($line in ($Text -split "`n")) {
    if ($line -match ('^' + [regex]::Escape($Section) + ':\s*$')) { $inside = $true; continue }
    if ($inside -and $line -match '^[A-Za-z0-9_.-]+:') { $inside = $false }
    if ($inside -and $line -match '^\s{2}([a-z0-9-]+):\s*\{(.*)\}\s*$') {
      $entry = @{ Id = $Matches[1] }
      $body = $Matches[2]
      foreach ($key in $Keys) {
        $entry[$key] = ''
        if ($body -match ($key.ToLowerInvariant() + ':\s*([^,}]+)')) { $entry[$key] = $Matches[1].Trim() }
      }
      [void]$entries.Add($entry)
    }
  }
  return ,$entries
}

$roleSources = Get-RegistrySectionEntries $registryText 'role_sources' @('Source','Contract','Prompt')
if ($roleSources.Count -eq 0) { Write-Error "instruction registry declares no role_sources" }
$defaultsTarget = ''
if ($registryText -match '(?m)^role_defaults_target:\s*(\S+)\s*$') { $defaultsTarget = $Matches[1] }
if ([string]::IsNullOrWhiteSpace($defaultsTarget)) { Write-Error "instruction registry missing role_defaults_target" }

$expectedOutputs = New-Object System.Collections.Generic.List[object]
$defaultsBlocks = New-Object System.Collections.Generic.List[string]

# Inserta el aviso GENERATED despues del frontmatter YAML (si existe) para no
# romper el parseo de frontmatter del host; sin frontmatter va al inicio.
function Add-GeneratedNotice([string]$Block, [string]$Notice, [string]$SourceRel) {
  $lines = $Block.TrimEnd("`n") -split "`n"
  $output = New-Object System.Collections.Generic.List[string]
  if ($lines.Count -gt 0 -and $lines[0] -eq '---') {
    $closed = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
      [void]$output.Add($lines[$i])
      if ($i -gt 0 -and -not $closed -and $lines[$i] -eq '---') {
        [void]$output.Add($Notice)
        $closed = $true
      }
    }
    if (-not $closed) { Write-Error "block in $SourceRel has unterminated frontmatter" }
  }
  else {
    [void]$output.Add($Notice)
    foreach ($line in $lines) { [void]$output.Add($line) }
  }
  return (($output -join "`n") + "`n")
}

foreach ($entry in $roleSources) {
  $sourcePath = Join-Path $Root $entry.Source
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { Write-Error "missing role source: $($entry.Source)" }
  $sourceText = Read-Lf $sourcePath

  $contractBlock = Get-GeneratedBlock $sourceText 'contract' $entry.Source
  $contractHeader = "# GENERATED - No editar a mano. Fuente unica: $($entry.Source)`n# Regenerar: scripts/build-instructions.ps1 -WriteOutputs`n"
  [void]$expectedOutputs.Add(@{ Path = $entry.Contract; Content = ($contractHeader + $contractBlock) })

  $defaultsBlock = Get-GeneratedBlock $sourceText 'role-defaults' $entry.Source
  [void]$defaultsBlocks.Add("  $($entry.Id):`n" + $defaultsBlock.TrimEnd("`n") + "`n")

  if (-not [string]::IsNullOrWhiteSpace($entry.Prompt)) {
    $promptBlock = Get-GeneratedBlock $sourceText 'prompt' $entry.Source
    $notice = "<!-- GENERATED - No editar a mano. Fuente unica: $($entry.Source) ; regenerar con scripts/build-instructions.ps1 -WriteOutputs -->"
    [void]$expectedOutputs.Add(@{ Path = $entry.Prompt; Content = (Add-GeneratedNotice $promptBlock $notice $entry.Source) })
  }
}

# --- Proyeccion nativa de agentes de rol (subagentes Claude Code) ---------------
# Fuente unica: bloque claude-agent en agents/<rol>.md. La via agnostica es el
# daemon MCP (agent_audit/agent_review); estos templates son opcionales y los
# instala install-host-integrations.ps1 en <proyecto>/.claude/agents/.

$nativeAgents = Get-RegistrySectionEntries $registryText 'native_agents' @('Source','Target')
foreach ($entry in $nativeAgents) {
  $sourcePath = Join-Path $Root $entry.Source
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { Write-Error "missing native agent source: $($entry.Source)" }
  $sourceText = Read-Lf $sourcePath
  $agentBlock = Get-GeneratedBlock $sourceText 'claude-agent' $entry.Source
  $notice = "<!-- GENERATED - No editar a mano. Fuente unica: $($entry.Source) ; regenerar con scripts/build-instructions.ps1 -WriteOutputs -->"
  [void]$expectedOutputs.Add(@{ Path = $entry.Target; Content = (Add-GeneratedNotice $agentBlock.Trim("`n") $notice $entry.Source) })
}

# --- Instrucciones persistentes por host (Cursor / Copilot) ---------------------
# Derivadas de los MISMOS fragments que AGENTS.md: kernel + preflight +
# denylists + roles + puntero al daemon MCP como runtime recomendado.

function Get-FragmentBody([string]$Name) {
  $text = Read-Lf (Join-Path $Root "orquestador/instruction-builder/fragments/$Name.md")
  # Quita el titulo "# Fragment: ..." y deja el cuerpo.
  return ($text -replace '(?s)^# Fragment: [^\n]*\n+', '').TrimEnd("`n")
}

$hostInstructions = Get-RegistrySectionEntries $registryText 'host_instructions' @('Target')
if ($hostInstructions.Count -gt 0) {
  $mcpPointer = @(
    '## Runtime recomendado: daemon MCP hebrinex',
    '',
    'El enforcement real (gateway de comandos, approvals, locks, gates, roles) vive en el',
    'daemon MCP del harness: `mcp/server.mjs` (tools `run_command`, `preflight_approve`,',
    '`session_contract`, `gate_check`, `agent_audit`, `agent_review`, etc.). Conectarlo en',
    'este host es la via recomendada; snippets por host en `orquestador/portability/mcp-hosts.md`.',
    'Sin daemon conectado, operar por prompt es fallback: declarar contrato de sesion y',
    'preflight manualmente segun `AGENTS.md`.'
  ) -join "`n"
  $coreBody = @(
    '## Kernel', '', (Get-FragmentBody 'kernel'), '',
    '## Preflight obligatorio antes de efectos', '', (Get-FragmentBody 'preflight'), '',
    '## Denylists', '', (Get-FragmentBody 'denylists'), '',
    '## Roles', '', (Get-FragmentBody 'roles'), '',
    $mcpPointer
  ) -join "`n"
  foreach ($entry in $hostInstructions) {
    $notice = "<!-- GENERATED - No editar a mano. Fuente unica: orquestador/instruction-builder/fragments/*.md ; regenerar con scripts/build-instructions.ps1 -WriteOutputs -->"
    $header = ''
    if ($entry.Id -eq 'cursor') {
      $header = @('---', 'description: Hebri-AI-Harness - kernel operativo (generado)', 'alwaysApply: true', '---', '') -join "`n"
    }
    $title = "# Hebri-AI-Harness - Reglas operativas ($($entry.Id))"
    $content = $header + $notice + "`n" + $title + "`n`n" + $coreBody + "`n"
    [void]$expectedOutputs.Add(@{ Path = $entry.Target; Content = $content })
  }
}

# role_defaults se regenera como ultimo bloque top-level de capability-registry.
$defaultsPath = Join-Path $Root $defaultsTarget
if (-not (Test-Path -LiteralPath $defaultsPath -PathType Leaf)) { Write-Error "missing role_defaults target: $defaultsTarget" }
$capabilityText = Read-Lf $defaultsPath
$defaultsIndex = $capabilityText.IndexOf("`nrole_defaults:")
if ($defaultsIndex -lt 0) { Write-Error "$defaultsTarget does not contain a role_defaults block" }
$prefix = $capabilityText.Substring(0, $defaultsIndex + 1)
$generatedDefaults = "role_defaults:`n  # GENERATED - No editar a mano. Fuente unica: bloques role-defaults en agents/*.md`n" + ($defaultsBlocks -join '')
[void]$expectedOutputs.Add(@{ Path = $defaultsTarget; Content = ($prefix + $generatedDefaults) })

$drift = New-Object System.Collections.Generic.List[string]
$written = 0
foreach ($output in $expectedOutputs) {
  $targetPath = Join-Path $Root $output.Path
  $current = ''
  if (Test-Path -LiteralPath $targetPath -PathType Leaf) { $current = Read-Lf $targetPath }
  if ($current -ne $output.Content) {
    if ($WriteOutputs) {
      Write-Lf $targetPath $output.Content
      $written++
      Write-Host "regenerated: $($output.Path)"
    }
    else {
      [void]$drift.Add($output.Path)
    }
  }
}

if (-not $WriteOutputs -and $drift.Count -gt 0) {
  Write-Host "Instruction builder DRIFT: derived role layers differ from agents/*.md source."
  foreach ($rel in $drift) { Write-Host " - $rel" }
  Write-Host "Fix: edit the source in agents/<role>.md and run scripts/build-instructions.ps1 -WriteOutputs (never edit derived files by hand)."
  exit 2
}

if ($WriteOutputs) {
  Write-Host "OK. Instruction builder regenerated $written derived file(s). fragments_sha256=$hash"
}
else {
  Write-Host "OK. Instruction builder check-only passed (role layers in sync). fragments_sha256=$hash"
}
exit 0
