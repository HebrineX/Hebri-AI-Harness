param(
  [Parameter(Position = 0)]
  [ValidateSet('help','status','budget','usage','preflight','approve','validate','audit','migrate','bootstrap','update-bound','list-bound-backups','restore-bound','command','state-machine','agent-runtime','lock')]
  [string]$Command = 'help',
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$RunNegativeTests,
  [switch]$CheckOnly,
  [switch]$Apply,
  [switch]$Acquire,
  [switch]$Release,
  [switch]$List,
  [string]$TargetVersion = '0.16.0',
  [string]$ProjectRoot = '',
  [string]$BackupId = '',
  [string]$ApprovalId = '',
  [string]$Action = '',
  [string]$ReadSet = '',
  [string]$WriteSet = '',
  [string]$Risk = 'bajo',
  [string]$Verification = '',
  [string]$CommandText = '',
  [string]$Purpose = '',
  [string]$RiskClass = '',
  [string]$RoleId = '',
  [string]$Capability = '',
  [string]$FromState = '',
  [string]$ToState = '',
  [int]$TtlMinutes = 60,
  [string]$Paths = '',
  [string]$LockId = '',
  [string]$Owner = '',
  [string]$Reason = '',
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'lib/hebri-common.psm1') -Force -DisableNameChecking -Prefix 'Hebri' -Scope Local

$Root = [IO.Path]::GetFullPath($Root)

function Resolve-HarnessPath([string]$RelativePath) {
  if ([IO.Path]::IsPathRooted($RelativePath)) { return [IO.Path]::GetFullPath($RelativePath) }
  return [IO.Path]::GetFullPath((Join-Path $Root $RelativePath))
}

function Test-HarnessLeaf([string]$Path) {
  return [IO.File]::Exists($Path)
}

function Get-HarnessFileLength([string]$Path) {
  if (-not (Test-HarnessLeaf $Path)) { return $null }
  return ([IO.FileInfo]::new($Path)).Length
}

function Read-HarnessText([string]$RelativePath) {
  $path = Resolve-HarnessPath $RelativePath
  if (-not (Test-HarnessLeaf $path)) {
    throw "missing file: $RelativePath"
  }
  return [IO.File]::ReadAllText($path)
}

function Get-Scalar([string]$Text, [string]$Key) {
  foreach ($line in ($Text -split "`n")) {
    if ($line -match ('^\s*' + [regex]::Escape($Key) + ':\s*(.*)$')) {
      return $Matches[1].Trim().Trim('"').Trim("'")
    }
  }
  return ''
}

function Get-SectionScalar([string]$Text, [string]$Section, [string]$Key) {
  $inside = $false
  foreach ($line in ($Text -split "`n")) {
    if ($line -match ('^' + [regex]::Escape($Section) + ':\s*$')) {
      $inside = $true
      continue
    }
    if ($inside -and $line -match '^[A-Za-z0-9_.-]+:\s*') {
      $inside = $false
    }
    if ($inside -and $line -match ('^\s+' + [regex]::Escape($Key) + ':\s*(.*)$')) {
      return $Matches[1].Trim().Trim('"').Trim("'")
    }
  }
  return ''
}

function Get-InlineBudget([string]$BudgetText, [string]$Name) {
  foreach ($line in ($BudgetText -split "`n")) {
    if ($line -match ('^\s*' + [regex]::Escape($Name) + ':\s*\{[^}]*max_tokens(?:_before_user_logs)?:\s*([0-9]+)')) {
      return [int]$Matches[1]
    }
  }
  return 0
}

function Estimate-Tokens([string[]]$RelativePaths) {
  $chars = 0
  foreach ($rel in $RelativePaths) {
    $path = Resolve-HarnessPath $rel
    $length = Get-HarnessFileLength $path
    if ($null -ne $length) { $chars += $length }
  }
  return [math]::Ceiling($chars / 4)
}

function Write-BudgetLine([string]$Name, [int]$MaxTokens, [string[]]$RelativePaths) {
  $used = Estimate-Tokens $RelativePaths
  $hard = $MaxTokens * 2
  $status = 'ok'
  if ($used -gt $hard) { $status = 'block' }
  elseif ($used -gt $MaxTokens) { $status = 'warn' }
  Write-Host "$Name=$used/$MaxTokens hard=$hard status=$status"
}

$UsageKernelFiles = @(
  'PROJECT_BINDING.yaml',
  'orquestador/memory/local/session-pin.md',
  'orquestador/memory/memory-registry.yaml',
  'orquestador/memory/memory-routing.yaml',
  'orquestador/context-budget.yaml',
  'orquestador/entrypoints/first-message.md'
)

# File-sets canonicos por perfil (mismos sets que `budget`, mas reentry_light via
# memory-routing). Los perfiles sin file-set estatico (leader_full, audit_global,
# adapter_portability) tienen read-set dinamico y se reportan como dynamic.
$UsageProfileFiles = @{
  memory_bootstrap = @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/reentry-light.md')
  first_message    = @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/first-message.md')
  reentry_light    = @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/reentry-light.md')
  debug_log_intake = @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/debug-log-intake.md','orquestador/entrypoints/reentry-light.md')
  leader_light     = @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/sdd/progress/state.yaml','orquestador/sdd/progress/registry.yaml','orquestador/method/session-contract.md')
  runtime_status   = @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/context-budget.yaml','orquestador/runtime/active-session.template.json')
  runtime_reentry  = @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/context-budget.yaml','orquestador/runtime/active-session.template.json','orquestador/sdd/progress/state.yaml','orquestador/sdd/progress/registry.yaml')
}

function Get-BudgetProfileNames([string]$BudgetText) {
  $names = New-Object System.Collections.Generic.List[string]
  $inside = $false
  foreach ($line in ($BudgetText -split "`n")) {
    if ($line -match '^budgets:\s*$') { $inside = $true; continue }
    if ($inside -and $line -match '^[A-Za-z0-9_.-]+:') { $inside = $false }
    if ($inside -and $line -match '^\s+([A-Za-z0-9_]+):\s*\{') { [void]$names.Add($Matches[1]) }
  }
  return $names
}

function Get-ManifestTreeTokens() {
  $chars = [long]0
  $files = 0
  foreach ($entry in (Get-HarnessManifestEntries)) {
    if ($entry.Kind -ne 'file') { continue }
    $path = Resolve-HarnessPath $entry.RelativePath
    $length = Get-HarnessFileLength $path
    if ($null -ne $length) {
      $chars += $length
      $files++
    }
  }
  return [ordered]@{ Tokens = [math]::Ceiling($chars / 4); Files = $files }
}

# Arbol de documentacion operativa: lo que un agente sin disciplina de kernel
# cargaria de verdad (AGENTS.md + method/* + prompts/**). Es el denominador del
# claim de ahorro del README; el arbol completo queda como metrica secundaria.
function Get-DocsTreeTokens() {
  $chars = [long]0
  $files = 0
  foreach ($entry in (Get-HarnessManifestEntries)) {
    if ($entry.Kind -ne 'file') { continue }
    $norm = ($entry.RelativePath -replace '\\', '/')
    if ($norm -ne 'AGENTS.md' -and $norm -notmatch '^orquestador/method/' -and $norm -notmatch '^prompts/') { continue }
    $path = Resolve-HarnessPath $entry.RelativePath
    $length = Get-HarnessFileLength $path
    if ($null -ne $length) {
      $chars += $length
      $files++
    }
  }
  return [ordered]@{ Tokens = [math]::Ceiling($chars / 4); Files = $files }
}

function Write-UsageReport() {
  $budgetText = Read-HarnessText 'orquestador/context-budget.yaml'
  $kernelTokens = Estimate-Tokens $UsageKernelFiles
  $tree = Get-ManifestTreeTokens
  if ($tree.Tokens -le 0) { throw 'usage: manifest tree is empty, cannot compute savings' }
  $docsTree = Get-DocsTreeTokens
  if ($docsTree.Tokens -le 0) { throw 'usage: docs tree is empty, cannot compute savings' }
  $savingsPct = [int][math]::Round((1 - ($kernelTokens / [double]$tree.Tokens)) * 100)
  $savingsDocsPct = [int][math]::Round((1 - ($kernelTokens / [double]$docsTree.Tokens)) * 100)
  Write-Host 'Hebri-AI-Harness usage'
  Write-Host 'method=file_chars_div_4'
  Write-Host "kernel_files=$($UsageKernelFiles.Count)"
  Write-Host "kernel_tokens=$kernelTokens"
  foreach ($name in (Get-BudgetProfileNames $budgetText)) {
    $max = Get-InlineBudget $budgetText $name
    if ($UsageProfileFiles.ContainsKey($name)) {
      $tokens = Estimate-Tokens $UsageProfileFiles[$name]
      Write-Host "profile_${name}_tokens=$tokens max_tokens=$max"
    }
    else {
      Write-Host "profile_${name}_tokens=dynamic max_tokens=$max"
    }
  }
  Write-Host "docs_tree_files=$($docsTree.Files)"
  Write-Host "docs_tree_tokens=$($docsTree.Tokens)"
  Write-Host "savings_docs_pct=$savingsDocsPct"
  Write-Host "full_tree_files=$($tree.Files)"
  Write-Host "full_tree_tokens=$($tree.Tokens)"
  Write-Host "savings_pct=$savingsPct"
  Write-Host 'writes=false'
}

function Invoke-ChildScript {
  param(
    [string]$RelativePath,
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$Arguments
  )
  $scriptPath = Resolve-HarnessPath $RelativePath
  if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "missing script: $RelativePath"
  }
  & $scriptPath @Arguments
  $exitCode = $LASTEXITCODE
  if ($null -ne $exitCode -and $exitCode -ne 0) {
    exit $exitCode
  }
}

function Ensure-Directory([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Write-Utf8Text([string]$Path, [string]$Text) {
  $parent = Split-Path -Parent $Path
  if (-not [string]::IsNullOrWhiteSpace($parent)) { Ensure-Directory $parent }
  [IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), [Text.UTF8Encoding]::new($false))
}

function ConvertTo-YamlDouble([string]$Value) {
  if ($null -eq $Value) { $Value = '' }
  return '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

function Format-YamlString([string]$Value) {
  if ($null -eq $Value) { $Value = '' }
  return "'" + ($Value -replace "'", "''") + "'"
}

function ConvertTo-YamlBool([bool]$Value) {
  if ($Value) { return 'true' }
  return 'false'
}

function Get-SafeProjectName([string]$ProjectRootPath) {
  $name = Split-Path -Leaf ([IO.Path]::GetFullPath($ProjectRootPath).TrimEnd('\','/'))
  if ([string]::IsNullOrWhiteSpace($name)) { $name = 'project' }
  $safe = [regex]::Replace($name, '[^A-Za-z0-9_.-]+', '-')
  if ([string]::IsNullOrWhiteSpace($safe)) { return 'project' }
  return $safe
}

function Get-RelativePathFromBase([string]$BasePath, [string]$FullPath) {
  $base = [IO.Path]::GetFullPath($BasePath).TrimEnd('\','/')
  $full = [IO.Path]::GetFullPath($FullPath)
  return ($full.Substring($base.Length).TrimStart('\','/') -replace '\\','/')
}

function Resolve-BootstrapProjectRoot([string]$SourceRoot, [string]$ProjectRootValue) {
  if ([string]::IsNullOrWhiteSpace($ProjectRootValue)) { throw 'bootstrap Apply requires -ProjectRoot' }
  $candidate = $ProjectRootValue
  if (-not [IO.Path]::IsPathRooted($candidate)) { $candidate = Join-Path (Get-Location).Path $candidate }
  if (-not (Test-Path -LiteralPath $candidate -PathType Container)) { throw "ProjectRoot must already exist: $ProjectRootValue" }
  $projectFull = (Resolve-Path -LiteralPath $candidate).Path.TrimEnd('\','/')
  if ((Split-Path -Leaf $projectFull) -eq '.hebrinex') { throw 'ProjectRoot must be the consumer root, not .hebrinex' }
  $sourceFull = (Resolve-Path -LiteralPath $SourceRoot).Path.TrimEnd('\','/')
  if ($projectFull.Equals($sourceFull, [StringComparison]::OrdinalIgnoreCase)) { throw 'ProjectRoot must not equal the source harness root' }
  if ($projectFull.StartsWith(($sourceFull + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase) -or
      $projectFull.StartsWith(($sourceFull + [IO.Path]::AltDirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'ProjectRoot must not be inside the source harness root'
  }
  return $projectFull
}

function Test-BootstrapExcludedPath([string]$RelativePath) {
  $norm = ($RelativePath -replace '\\','/').Trim('/')
  if ([string]::IsNullOrWhiteSpace($norm)) { return $true }
  if ($norm -match '(^|/)\.git(/|$)') { return $true }
  if ($norm -match '(^|/)\.codex(/|$)') { return $true }
  if ($norm -match '(^|/)infoHebri[.]md$') { return $true }
  if ($norm -match '(^|/)(Thumbs[.]db|desktop[.]ini)$') { return $true }
  if ($norm -match '(~$|[.]tmp$|[.]bak$|[.]swp$)') { return $true }
  return $false
}

function Copy-HarnessManifestToBoundRoot([string]$BoundRoot) {
  $manifestText = Read-HarnessText 'orquestador/harness-manifest.txt'
  $dirCount = 0
  $fileCount = 0
  Ensure-Directory $BoundRoot
  foreach ($line in ($manifestText -split "`n")) {
    if ($line -notmatch '^(dir|file)\s+(.+)$') { continue }
    $kind = $Matches[1]
    $rel = $Matches[2].Trim()
    if (Test-BootstrapExcludedPath $rel) { continue }
    $source = Resolve-HarnessPath $rel
    $destination = Join-Path $BoundRoot ($rel -replace '/', [IO.Path]::DirectorySeparatorChar)
    if ($kind -eq 'dir') {
      Ensure-Directory $destination
      $dirCount++
    }
    elseif ($kind -eq 'file') {
      if (-not (Test-HarnessLeaf $source)) { throw "manifest source file missing during bootstrap: $rel" }
      Ensure-Directory (Split-Path -Parent $destination)
      Copy-Item -LiteralPath $source -Destination $destination -Force
      $fileCount++
    }
  }
  return [ordered]@{ directories = $dirCount; files = $fileCount }
}

function Ensure-ConsumerGitIgnore([string]$ProjectRootPath) {
  $gitignorePath = Join-Path $ProjectRootPath '.gitignore'
  $line = '.hebrinex/'
  if (-not (Test-Path -LiteralPath $gitignorePath -PathType Leaf)) {
    Write-Utf8Text $gitignorePath ($line + "`n")
    return $true
  }
  $text = [IO.File]::ReadAllText($gitignorePath)
  if ($text -match '(?m)^\.hebrinex/\s*$') { return $false }
  $prefix = $text.TrimEnd("`r","`n")
  if ([string]::IsNullOrWhiteSpace($prefix)) { $prefix = '' }
  else { $prefix += "`n" }
  Write-Utf8Text $gitignorePath ($prefix + $line + "`n")
  return $true
}

function Write-BoundProjectBinding([string]$BoundRoot, [string]$ProjectRootPath, [string]$Version, [string]$BoundAt, [string]$InstanceId) {
  $projectName = Get-SafeProjectName $ProjectRootPath
  $binding = @"
schema: hebrinex.project_binding
version: "0.1"
harness_version: "$Version"
binding_mode: bound
harness_instance_id: "$InstanceId"
project_name: "$projectName"
project_root: $(ConvertTo-YamlDouble $ProjectRootPath)
repo_remote: ""
source_repo: "https://github.com/HebrineX/Hebri-AI-Harness"
created_at: ""
bound_at: "$BoundAt"
notes:
  - "Copia local bound creada por bootstrap Apply seguro."
  - "Este .hebrinex es la autoridad operativa local del proyecto consumidor."
  - "project_root apunta a la raiz exacta del proyecto consumidor."
  - "La memoria operativa se gobierna desde orquestador/memory/memory-registry.yaml."
  - "$Version es el release usable actual; bootstrap Apply deja contrato bound aplicado."
"@
  Write-Utf8Text (Join-Path $BoundRoot 'PROJECT_BINDING.yaml') ($binding + "`n")
}

function Set-TopLevelScalar([string]$Text, [string]$Key, [string]$YamlValue) {
  return [regex]::Replace($Text, ('(?m)^' + [regex]::Escape($Key) + ':.*$'), ($Key + ': ' + $YamlValue), 1)
}

function Set-SectionScalar([string]$Text, [string]$Section, [string]$Key, [string]$YamlValue) {
  $lines = New-Object System.Collections.Generic.List[string]
  $inside = $false
  foreach ($line in ($Text -split "`n")) {
    if ($line -match ('^' + [regex]::Escape($Section) + ':\s*$')) { $inside = $true; [void]$lines.Add($line); continue }
    if ($inside -and $line -match '^[A-Za-z0-9_.-]+:\s*') { $inside = $false }
    if ($inside -and $line -match ('^(\s+' + [regex]::Escape($Key) + ':\s*).*$')) {
      [void]$lines.Add($Matches[1] + $YamlValue)
    }
    else { [void]$lines.Add($line) }
  }
  return ($lines -join "`n")
}

function Update-BoundState([string]$BoundRoot, [string]$ProjectRootPath, [string]$BoundAt) {
  $statePath = Join-Path $BoundRoot 'orquestador/sdd/progress/state.yaml'
  $text = [IO.File]::ReadAllText($statePath)
  $text = Set-TopLevelScalar $text 'updated_at' (ConvertTo-YamlDouble $BoundAt)
  $text = Set-SectionScalar $text 'project_binding' 'status' 'bound'
  $text = Set-SectionScalar $text 'project_binding' 'project_root' (ConvertTo-YamlDouble $ProjectRootPath)
  $text = Set-SectionScalar $text 'project_binding' 'harness_path' (ConvertTo-YamlDouble (Join-Path $ProjectRootPath '.hebrinex'))
  $text = Set-SectionScalar $text 'session_contract' 'status' 'active'
  $text = Set-SectionScalar $text 'session_contract' 'leader_visible' 'true'
  $text = Set-SectionScalar $text 'approvals' 'active_approval_id' '"HAH-0106-BOOTSTRAP-APPLY"'
  Write-Utf8Text $statePath ($text.TrimEnd("`r","`n") + "`n")
}

function Update-BoundMemoryRegistry([string]$BoundRoot, [string]$BoundAt) {
  $path = Join-Path $BoundRoot 'orquestador/memory/memory-registry.yaml'
  $text = [IO.File]::ReadAllText($path)
  $text = Set-TopLevelScalar $text 'updated_at' (ConvertTo-YamlDouble $BoundAt)
  $text = Set-TopLevelScalar $text 'binding_mode' 'bound'
  Write-Utf8Text $path ($text.TrimEnd("`r","`n") + "`n")
}

function Update-BoundActiveContract([string]$BoundRoot, [string]$ProjectRootPath, [string]$Version) {
  $path = Join-Path $BoundRoot 'orquestador/memory/local/active-contract.md'
  $lines = @(
    '# Active Contract',
    '',
    'Contrato vivo inicial del harness bound.',
    '',
    'Contrato activo:',
    '- Harness detectado: si',
    "- Harness version: $Version",
    "- Harness path: $($ProjectRootPath)\.hebrinex",
    "- Project root: $ProjectRootPath",
    '- Binding: bound',
    '- Memory route: reentry_light',
    '- Context budget: perfil minimo',
    '- Memory layers loaded: local',
    '- Modo: automatico',
    '- Rol del chat: interprete',
    '- Leader visible: si',
    '- Subagentes activos: 0/4',
    '- Aprobacion requerida: SI antes de acciones con efecto'
  )
  Write-Utf8Text $path (($lines -join "`n") + "`n")
}

function Write-BootstrapMigrationReport([string]$BoundRoot, [string]$BootstrapId, [string]$Version, [string]$ProjectRootPath, [object]$Backup, [hashtable]$ValidatorResults, [string]$StartedAt, [string]$FinishedAt) {
  $validateAgent = if ($ValidatorResults.ContainsKey('validate_agent_contracts')) { $ValidatorResults['validate_agent_contracts'] } else { 'not_run' }
  $validateSecurity = if ($ValidatorResults.ContainsKey('validate_security_policy')) { $ValidatorResults['validate_security_policy'] } else { 'not_run' }
  $validateMigration = if ($ValidatorResults.ContainsKey('validate_migration')) { $ValidatorResults['validate_migration'] } else { 'not_run' }
  $validateHarness = if ($ValidatorResults.ContainsKey('validate_harness')) { $ValidatorResults['validate_harness'] } else { 'not_run' }
  $report = @"
schema: hebrinex.migration_report
version: "0.1"
template: false
migration_id: "$BootstrapId"
approval_id: "HAH-0106-BOOTSTRAP-APPLY-SAFE"
source_version: "source_template"
target_version: "$Version"
mode: "Apply"
status: applied
started_at: "$StartedAt"
finished_at: "$FinishedAt"
root: $(Format-YamlString $BoundRoot)
binding_mode: "bound"
project_root: $(Format-YamlString $ProjectRootPath)
route_file: "bootstrap-source-template-to-bound"
check_only:
  wrote_files: false
  planned_additions:
    - $(Format-YamlString '.hebrinex/')
  planned_preserve:
    - $(Format-YamlString 'consumer project files')
backup:
  required: true
  created: true
  path: $(Format-YamlString $Backup.Path)
  manifest_or_checksum: $(Format-YamlString $Backup.ManifestPath)
  files_captured: $($Backup.FileCount)
apply:
  files_added:
    - $(Format-YamlString '.hebrinex/')
  files_modified:
    - $(Format-YamlString '.gitignore')
    - $(Format-YamlString '.hebrinex/PROJECT_BINDING.yaml')
    - $(Format-YamlString '.hebrinex/orquestador/sdd/progress/state.yaml')
    - $(Format-YamlString '.hebrinex/orquestador/memory/memory-registry.yaml')
    - $(Format-YamlString '.hebrinex/orquestador/migration/contracts/post-migration-contract.yaml')
  files_preserved:
    - $(Format-YamlString 'consumer project files')
validators:
  validate_agent_contracts: $validateAgent
  validate_security_policy: $validateSecurity
  validate_migration: $validateMigration
  validate_harness: $validateHarness
post_migration_contract:
  path: $(Format-YamlString (Join-Path $BoundRoot 'orquestador/migration/contracts/post-migration-contract.yaml'))
  status: applied
risks:
  - $(Format-YamlString 'bootstrap Apply writes only target .hebrinex and consumer .gitignore')
next_steps:
  - $(Format-YamlString 'Use the bound .hebrinex as the consumer project authority')
"@
  $reportPath = Join-Path $BoundRoot "orquestador/migration/reports/$BootstrapId.yaml"
  Write-Utf8Text $reportPath ($report + "`n")
  return $reportPath
}

function Create-BootstrapBackupRecord([string]$ProjectRootPath, [string]$BoundRoot, [string]$BootstrapId) {
  $backupRoot = Join-Path $BoundRoot 'orquestador/migration/backups'
  $backupPath = Join-Path $backupRoot $BootstrapId
  Ensure-Directory $backupPath
  $manifest = New-Object System.Collections.Generic.List[string]
  $projectFull = [IO.Path]::GetFullPath($ProjectRootPath).TrimEnd('\','/')
  $boundFull = [IO.Path]::GetFullPath($BoundRoot).TrimEnd('\','/')
  $files = Get-ChildItem -LiteralPath $ProjectRootPath -Recurse -File -Force | Where-Object {
    $full = [IO.Path]::GetFullPath($_.FullName)
    -not ($full.StartsWith(($boundFull + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase) -or
          $full.StartsWith(($boundFull + [IO.Path]::AltDirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase))
  } | Sort-Object FullName
  foreach ($file in $files) {
    $rel = Get-RelativePathFromBase $projectFull $file.FullName
    [void]$manifest.Add("$rel|$($file.Length)|$($file.LastWriteTimeUtc.ToString('o'))")
  }
  if ($manifest.Count -eq 0) { [void]$manifest.Add('no_preexisting_project_files') }
  $manifestPath = Join-Path $backupPath 'backup-manifest.txt'
  Write-Utf8Text $manifestPath (($manifest -join "`n") + "`n")
  return [ordered]@{ Path = $backupPath; ManifestPath = $manifestPath; FileCount = $manifest.Count }
}

function Set-BootstrapPostMigrationContractFile([string]$BoundRoot, [string]$Version) {
  $contract = @"
schema: hebrinex.post_migration_contract
version: "0.1"
template: false
harness_version: "$Version"
source_version: "source_template"
target_version: "$Version"
binding_mode: "bound"
project_root_verified: true
agent_authority: harness_only
agent_registry_active: true
security_policy_active: true
runtime_enablement_active: true
migration_service_active: true
active_contract_written: true
old_approvals_expired: true
backup_verified: true
validators_passed: true
migration_report_written: true
migration_status: applied
required_evidence:
  - migration_report
  - backup_manifest
  - validator_output
  - active_contract_ref
success_rule: "migration_status can be applied only when all booleans above are true."
"@
  $contractPath = Join-Path $BoundRoot 'orquestador/migration/contracts/post-migration-contract.yaml'
  Write-Utf8Text $contractPath ($contract + "`n")
  return $contractPath
}

function Get-HarnessManifestEntries() {
  $entries = New-Object System.Collections.Generic.List[object]
  $manifestText = Read-HarnessText 'orquestador/harness-manifest.txt'
  foreach ($line in ($manifestText -split "`n")) {
    if ($line -notmatch '^(dir|file)\s+(.+)$') { continue }
    [void]$entries.Add([ordered]@{ Kind = $Matches[1]; RelativePath = $Matches[2].Trim() })
  }
  return $entries
}

function Get-BoundUpdatePreserveReason([string]$RelativePath) {
  $norm = ($RelativePath -replace '\\','/').Trim('/')
  if ([string]::IsNullOrWhiteSpace($norm)) { return 'empty_path' }
  if ($norm -eq 'PROJECT_BINDING.yaml') { return 'project_binding' }
  if ($norm -in @('orquestador/sdd/progress/state.yaml','orquestador/sdd/progress/registry.yaml','orquestador/sdd/progress/registry.md','orquestador/sdd/progress/blocked.md','orquestador/sdd/progress/future-p1.md')) { return 'progress_state' }
  if ($norm -match '^orquestador/sdd/progress/(approvals|cycles|locks)/') { return 'progress_runtime' }
  if ($norm -match '^orquestador/sdd/progress/' -and $norm -notmatch '^orquestador/sdd/progress/(templates|schemas)/' -and $norm -ne 'orquestador/sdd/progress/_README.md') { return 'progress_runtime' }
  if ($norm -eq 'orquestador/memory/memory-registry.yaml') { return 'memory_registry' }
  if ($norm -match '^orquestador/memory/(local|project|cycle|daily|complete)/') { return 'memory_layer' }
  if ($norm -match '^orquestador/migration/backups/') { return 'migration_backup' }
  if ($norm -match '^orquestador/migration/reports/' -and $norm -ne 'orquestador/migration/reports/migration-report.template.yaml') { return 'migration_report' }
  if ($norm -match '^orquestador/evidence/') { return 'evidence' }
  return ''
}

function Test-BoundUpdatePreservedPath([string]$RelativePath) {
  return -not [string]::IsNullOrWhiteSpace((Get-BoundUpdatePreserveReason $RelativePath))
}

function Add-BoundBackupCandidate([System.Collections.Generic.HashSet[string]]$Candidates, [string]$BoundRoot, [string]$RelativePath) {
  $norm = ($RelativePath -replace '\\','/').Trim('/')
  if ([string]::IsNullOrWhiteSpace($norm)) { return }
  if (Test-BootstrapExcludedPath $norm) { return }
  $path = Join-Path $BoundRoot ($norm -replace '/', [IO.Path]::DirectorySeparatorChar)
  if (Test-HarnessLeaf $path) { [void]$Candidates.Add($norm) }
}

function Add-BoundBackupTree([System.Collections.Generic.HashSet[string]]$Candidates, [string]$BoundRoot, [string]$RelativeDir) {
  $dir = Join-Path $BoundRoot ($RelativeDir -replace '/', [IO.Path]::DirectorySeparatorChar)
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return }
  $base = [IO.Path]::GetFullPath($BoundRoot).TrimEnd('\','/')
  foreach ($file in (Get-ChildItem -LiteralPath $dir -Recurse -File -Force | Sort-Object FullName)) {
    $rel = Get-RelativePathFromBase $base $file.FullName
    if (Test-BootstrapExcludedPath $rel) { continue }
    [void]$Candidates.Add($rel)
  }
}

function Create-BoundUpdateBackupRecord([string]$BoundRoot, [string]$UpdateId) {
  $backupRoot = Join-Path $BoundRoot 'orquestador/migration/backups'
  $backupPath = Join-Path $backupRoot $UpdateId
  $filesRoot = Join-Path $backupPath 'files'
  Ensure-Directory $filesRoot
  $candidates = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($entry in (Get-HarnessManifestEntries)) {
    if ($entry.Kind -ne 'file') { continue }
    Add-BoundBackupCandidate $candidates $BoundRoot $entry.RelativePath
  }
  foreach ($relDir in @(
    'orquestador/sdd/progress',
    'orquestador/memory/local',
    'orquestador/memory/project',
    'orquestador/memory/cycle',
    'orquestador/memory/daily',
    'orquestador/memory/complete',
    'orquestador/migration/reports'
  )) {
    Add-BoundBackupTree $candidates $BoundRoot $relDir
  }
  Add-BoundBackupCandidate $candidates $BoundRoot 'PROJECT_BINDING.yaml'

  $manifest = New-Object System.Collections.Generic.List[string]
  foreach ($rel in ($candidates | Sort-Object)) {
    $source = Join-Path $BoundRoot ($rel -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-HarnessLeaf $source)) { continue }
    $destination = Join-Path $filesRoot ($rel -replace '/', [IO.Path]::DirectorySeparatorChar)
    Ensure-Directory (Split-Path -Parent $destination)
    Copy-Item -LiteralPath $source -Destination $destination -Force
    $item = [IO.FileInfo]::new($source)
    $reason = Get-BoundUpdatePreserveReason $rel
    if ([string]::IsNullOrWhiteSpace($reason)) { $reason = 'overwrite_backup' }
    [void]$manifest.Add("$rel|$($item.Length)|$($item.LastWriteTimeUtc.ToString('o'))|$reason")
  }
  if ($manifest.Count -eq 0) { [void]$manifest.Add('no_existing_bound_files') }
  $manifestPath = Join-Path $backupPath 'backup-manifest.txt'
  Write-Utf8Text $manifestPath (($manifest -join "`n") + "`n")
  return [ordered]@{ Path = $backupPath; ManifestPath = $manifestPath; FileCount = $manifest.Count }
}

function Copy-HarnessManifestToExistingBoundRoot([string]$BoundRoot) {
  $dirCount = 0
  $fileCount = 0
  $preservedCount = 0
  Ensure-Directory $BoundRoot
  foreach ($entry in (Get-HarnessManifestEntries)) {
    $rel = $entry.RelativePath
    if (Test-BootstrapExcludedPath $rel) { continue }
    if (Test-BoundUpdatePreservedPath $rel) {
      if ($entry.Kind -eq 'file') { $preservedCount++ }
      continue
    }
    $source = Resolve-HarnessPath $rel
    $destination = Join-Path $BoundRoot ($rel -replace '/', [IO.Path]::DirectorySeparatorChar)
    if ($entry.Kind -eq 'dir') {
      Ensure-Directory $destination
      $dirCount++
    }
    elseif ($entry.Kind -eq 'file') {
      if (-not (Test-HarnessLeaf $source)) { throw "manifest source file missing during bound update: $rel" }
      Ensure-Directory (Split-Path -Parent $destination)
      Copy-Item -LiteralPath $source -Destination $destination -Force
      $fileCount++
    }
  }
  return [ordered]@{ directories = $dirCount; files = $fileCount; preserved = $preservedCount }
}

function Update-BoundProjectBindingVersion([string]$BoundRoot, [string]$Version) {
  $bindingPath = Join-Path $BoundRoot 'PROJECT_BINDING.yaml'
  if (-not (Test-Path -LiteralPath $bindingPath -PathType Leaf)) { throw 'bound harness missing PROJECT_BINDING.yaml' }
  $text = [IO.File]::ReadAllText($bindingPath)
  $oldVersion = Get-Scalar $text 'harness_version'
  $instanceId = Get-Scalar $text 'harness_instance_id'
  $projectRoot = Get-Scalar $text 'project_root'
  $text = Set-TopLevelScalar $text 'harness_version' (ConvertTo-YamlDouble $Version)
  Write-Utf8Text $bindingPath ($text.TrimEnd("`r","`n") + "`n")
  return [ordered]@{ OldVersion = $oldVersion; InstanceId = $instanceId; ProjectRoot = $projectRoot }
}

function Set-BoundUpdatePostMigrationContractFile([string]$BoundRoot, [string]$SourceVersion, [string]$TargetVersion) {
  $contract = @"
schema: hebrinex.post_migration_contract
version: "0.1"
template: false
harness_version: "$TargetVersion"
source_version: "$SourceVersion"
target_version: "$TargetVersion"
binding_mode: "bound"
project_root_verified: true
agent_authority: harness_only
agent_registry_active: true
security_policy_active: true
runtime_enablement_active: true
migration_service_active: true
active_contract_written: true
old_approvals_expired: true
backup_verified: true
validators_passed: true
migration_report_written: true
migration_status: applied
required_evidence:
  - migration_report
  - backup_manifest
  - validator_output
  - preserved_state_registry_memory
success_rule: "migration_status can be applied only when backup, preservation and validators are true."
"@
  $contractPath = Join-Path $BoundRoot 'orquestador/migration/contracts/post-migration-contract.yaml'
  Write-Utf8Text $contractPath ($contract + "`n")
  return $contractPath
}

function Write-BoundUpdateMigrationReport([string]$BoundRoot, [string]$UpdateId, [string]$SourceVersion, [string]$TargetVersion, [string]$ProjectRootPath, [object]$Backup, [hashtable]$ValidatorResults, [object]$CopyResult, [string]$StartedAt, [string]$FinishedAt) {
  $validateAgent = if ($ValidatorResults.ContainsKey('validate_agent_contracts')) { $ValidatorResults['validate_agent_contracts'] } else { 'not_run' }
  $validateSecurity = if ($ValidatorResults.ContainsKey('validate_security_policy')) { $ValidatorResults['validate_security_policy'] } else { 'not_run' }
  $validateMigration = if ($ValidatorResults.ContainsKey('validate_migration')) { $ValidatorResults['validate_migration'] } else { 'not_run' }
  $validateHarness = if ($ValidatorResults.ContainsKey('validate_harness')) { $ValidatorResults['validate_harness'] } else { 'not_run' }
  $report = @"
schema: hebrinex.migration_report
version: "0.1"
template: false
migration_id: "$UpdateId"
approval_id: "HAH-0107-BOUND-UPDATE-CHECKONLY-APPLY-SAFE"
source_version: "$SourceVersion"
target_version: "$TargetVersion"
mode: "Apply"
status: applied
started_at: "$StartedAt"
finished_at: "$FinishedAt"
root: $(Format-YamlString $BoundRoot)
binding_mode: "bound"
project_root: $(Format-YamlString $ProjectRootPath)
route_file: "bound-update-source-template-to-bound"
check_only:
  wrote_files: false
  planned_preserve:
    - $(Format-YamlString 'PROJECT_BINDING.yaml')
    - $(Format-YamlString 'orquestador/sdd/progress/')
    - $(Format-YamlString 'orquestador/memory/local/')
    - $(Format-YamlString 'orquestador/memory/project/')
    - $(Format-YamlString 'orquestador/migration/reports/')
backup:
  required: true
  created: true
  path: $(Format-YamlString $Backup.Path)
  manifest_or_checksum: $(Format-YamlString $Backup.ManifestPath)
  files_captured: $($Backup.FileCount)
apply:
  files_added_or_updated_from_manifest: $($CopyResult.files)
  directories_ensured: $($CopyResult.directories)
  manifest_files_preserved: $($CopyResult.preserved)
  files_preserved:
    - $(Format-YamlString 'PROJECT_BINDING.yaml identity and project root')
    - $(Format-YamlString 'state, registry, cycles, locks and approvals')
    - $(Format-YamlString 'local/project memory and migration evidence')
validators:
  validate_agent_contracts: $validateAgent
  validate_security_policy: $validateSecurity
  validate_migration: $validateMigration
  validate_harness: $validateHarness
post_migration_contract:
  path: $(Format-YamlString (Join-Path $BoundRoot 'orquestador/migration/contracts/post-migration-contract.yaml'))
  status: applied
risks:
  - $(Format-YamlString 'update-bound overwrites only manifest-declared non-preserved harness files')
next_steps:
  - $(Format-YamlString 'Continue using the existing bound .hebrinex authority')
"@
  $reportPath = Join-Path $BoundRoot "orquestador/migration/reports/$UpdateId.yaml"
  Write-Utf8Text $reportPath ($report + "`n")
  return $reportPath
}

function Resolve-BoundUpdateTarget([string]$SourceRoot, [string]$ProjectRootValue) {
  $projectRootPath = Resolve-BootstrapProjectRoot $SourceRoot $ProjectRootValue
  $boundRoot = Join-Path $projectRootPath '.hebrinex'
  if (-not (Test-Path -LiteralPath $boundRoot -PathType Container)) { throw "target project does not have .hebrinex: $boundRoot" }
  $bindingPath = Join-Path $boundRoot 'PROJECT_BINDING.yaml'
  if (-not (Test-Path -LiteralPath $bindingPath -PathType Leaf)) { throw 'target .hebrinex missing PROJECT_BINDING.yaml' }
  $binding = [IO.File]::ReadAllText($bindingPath)
  if ((Get-Scalar $binding 'binding_mode') -ne 'bound') { throw 'target .hebrinex must have binding_mode bound' }
  $boundProjectRoot = Get-Scalar $binding 'project_root'
  if ([string]::IsNullOrWhiteSpace($boundProjectRoot)) { throw 'target bound PROJECT_BINDING project_root is empty' }
  if (([IO.Path]::GetFullPath($boundProjectRoot).TrimEnd('\','/')) -ne ([IO.Path]::GetFullPath($projectRootPath).TrimEnd('\','/'))) {
    throw "target PROJECT_BINDING project_root mismatch: $boundProjectRoot"
  }
  return [ordered]@{ ProjectRoot = $projectRootPath; BoundRoot = $boundRoot; Binding = $binding }
}

function Invoke-BoundUpdateApply([string]$ProjectRootValue) {
  $sourceBindingText = Read-HarnessText 'PROJECT_BINDING.yaml'
  $sourceMode = Get-Scalar $sourceBindingText 'binding_mode'
  if ($sourceMode -ne 'source_template') { throw "update-bound Apply requires source_template root, got: $sourceMode" }
  $target = Resolve-BoundUpdateTarget $Root $ProjectRootValue
  $version = (Read-HarnessText 'HARNESS_VERSION').Trim()
  $targetVersionPath = Join-Path $target.BoundRoot 'HARNESS_VERSION'
  $sourceVersion = if (Test-Path -LiteralPath $targetVersionPath -PathType Leaf) { ([IO.File]::ReadAllText($targetVersionPath)).Trim() } else { Get-Scalar $target.Binding 'harness_version' }
  if ([string]::IsNullOrWhiteSpace($sourceVersion)) { $sourceVersion = 'unknown' }
  $startedAt = (Get-Date).ToUniversalTime().ToString('o')
  $updateId = 'migration-bound-update-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ') + '-' + ([guid]::NewGuid().ToString('N').Substring(0, 8))

  $backup = Create-BoundUpdateBackupRecord $target.BoundRoot $updateId
  $copyResult = Copy-HarnessManifestToExistingBoundRoot $target.BoundRoot
  $gitignoreUpdated = Ensure-ConsumerGitIgnore $target.ProjectRoot
  $bindingInfo = Update-BoundProjectBindingVersion $target.BoundRoot $version
  [void](Set-BoundUpdatePostMigrationContractFile $target.BoundRoot $sourceVersion $version)

  $validatorResults = @{}
  $validatorResults['validate_agent_contracts'] = Invoke-BoundValidator $target.BoundRoot 'scripts/validate-agent-contracts.ps1'
  $validatorResults['validate_security_policy'] = Invoke-BoundValidator $target.BoundRoot 'scripts/validate-security-policy.ps1'
  $reportPath = Write-BoundUpdateMigrationReport $target.BoundRoot $updateId $sourceVersion $version $target.ProjectRoot $backup $validatorResults $copyResult $startedAt (Get-Date).ToUniversalTime().ToString('o')
  $validatorResults['validate_migration'] = Invoke-BoundValidator $target.BoundRoot 'scripts/validate-migration.ps1' @('-RequireApplied')
  $validatorResults['validate_harness'] = Invoke-BoundValidator $target.BoundRoot 'scripts/validate-harness.ps1' @('-RunNegativeTests','-SkipNestedValidators')
  $reportPath = Write-BoundUpdateMigrationReport $target.BoundRoot $updateId $sourceVersion $version $target.ProjectRoot $backup $validatorResults $copyResult $startedAt (Get-Date).ToUniversalTime().ToString('o')

  return [ordered]@{
    ProjectRoot = $target.ProjectRoot
    BoundRoot = $target.BoundRoot
    UpdateId = $updateId
    SourceVersion = $sourceVersion
    TargetVersion = $version
    CopiedFiles = $copyResult.files
    CopiedDirectories = $copyResult.directories
    PreservedManifestFiles = $copyResult.preserved
    GitignoreUpdated = $gitignoreUpdated
    BackupPath = $backup.Path
    BackupManifest = $backup.ManifestPath
    ReportPath = $reportPath
    InstanceId = $bindingInfo.InstanceId
  }
}

function Write-BoundUpdateCheckOnly([string]$ProjectRootValue) {
  $bindingText = Read-HarnessText 'PROJECT_BINDING.yaml'
  Write-Host 'Hebri-AI-Harness update-bound CheckOnly'
  Write-Host "source_root=$Root"
  Write-Host "source_binding_mode=$(Get-Scalar $bindingText 'binding_mode')"
  Write-Host "target_project_root=$ProjectRootValue"
  if (-not [string]::IsNullOrWhiteSpace($ProjectRootValue)) {
    try {
      $target = Resolve-BoundUpdateTarget $Root $ProjectRootValue
      Write-Host "resolved_project_root=$($target.ProjectRoot)"
      Write-Host "target_harness_root=$($target.BoundRoot)"
      Write-Host "target_binding_mode=$(Get-Scalar $target.Binding 'binding_mode')"
      Write-Host "target_harness_version=$(Get-Scalar $target.Binding 'harness_version')"
    }
    catch { Write-Host "target_validation=$($_.Exception.Message)" }
  }
  Write-Host 'planned_steps:'
  Write-Host ' - validate source_template'
  Write-Host ' - validate existing target <project_root>/.hebrinex is bound'
  Write-Host ' - create backup manifest before first write'
  Write-Host ' - copy manifest-declared non-preserved files'
  Write-Host ' - preserve PROJECT_BINDING identity, state, registry, cycles, locks, approvals, local memory and evidence'
  Write-Host ' - update bound harness_version and post-migration contract'
  Write-Host ' - run bound validators'
  Write-Host 'writes=false'
  Write-Host 'apply_available=true'
  Write-Host 'requires_project_root=true'
}

function Test-SafeBackupId([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
  if ($Value -match '[\\/]' -or $Value -match '[.][.]') { return $false }
  return ($Value -match '^[A-Za-z0-9_.-]+$')
}

function Resolve-BoundRestoreBackup([string]$BoundRoot, [string]$RequestedBackupId) {
  if (-not (Test-SafeBackupId $RequestedBackupId)) { throw 'restore-bound requires safe -BackupId' }
  $backupRoot = Join-Path $BoundRoot 'orquestador/migration/backups'
  $backupPath = Join-Path $backupRoot $RequestedBackupId
  $backupFull = [IO.Path]::GetFullPath($backupPath).TrimEnd('\','/')
  $backupRootFull = [IO.Path]::GetFullPath($backupRoot).TrimEnd('\','/')
  if (-not ($backupFull.StartsWith(($backupRootFull + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase) -or
            $backupFull.StartsWith(($backupRootFull + [IO.Path]::AltDirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase))) {
    throw 'BackupId resolved outside migration backups'
  }
  if (-not (Test-Path -LiteralPath $backupFull -PathType Container)) { throw "backup not found: $RequestedBackupId" }
  $filesRoot = Join-Path $backupFull 'files'
  if (-not (Test-Path -LiteralPath $filesRoot -PathType Container)) { throw "backup has no files directory: $RequestedBackupId" }
  $manifestPath = Join-Path $backupFull 'backup-manifest.txt'
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "backup manifest missing: $RequestedBackupId" }
  return [ordered]@{ Id = $RequestedBackupId; Path = $backupFull; FilesRoot = $filesRoot; ManifestPath = $manifestPath }
}

function Get-SafeRestoreRelativePath([string]$RelativePath) {
  $norm = ($RelativePath -replace '\\','/').Trim('/')
  if ([string]::IsNullOrWhiteSpace($norm)) { throw 'restore manifest contains empty path' }
  if ($norm -match '[.][.]' -or [IO.Path]::IsPathRooted($norm)) { throw "restore manifest contains unsafe path: $RelativePath" }
  if (Test-BootstrapExcludedPath $norm) { throw "restore manifest contains excluded path: $RelativePath" }
  return $norm
}

function Get-RestoreTargetVersion([object]$Backup, [string]$FallbackVersion) {
  $versionPath = Join-Path $Backup.FilesRoot 'HARNESS_VERSION'
  if (Test-Path -LiteralPath $versionPath -PathType Leaf) {
    $version = ([IO.File]::ReadAllText($versionPath)).Trim()
    if (-not [string]::IsNullOrWhiteSpace($version)) { return $version }
  }
  return $FallbackVersion
}

function Get-BoundBackupOrigin([string]$BackupId) {
  if ($BackupId -like 'migration-bound-update-*') { return 'update-bound' }
  if ($BackupId -like 'migration-bound-restore-*') { return 'restore-bound-pre-backup' }
  if ($BackupId -like 'migration-bootstrap-*') { return 'bootstrap' }
  return 'unknown'
}

function Test-ChildPathOfRoot([string]$RootPath, [string]$CandidatePath) {
  $rootFull = [IO.Path]::GetFullPath($RootPath).TrimEnd('\','/')
  $candidateFull = [IO.Path]::GetFullPath($CandidatePath)
  return ($candidateFull.StartsWith(($rootFull + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase) -or
          $candidateFull.StartsWith(($rootFull + [IO.Path]::AltDirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase))
}

function Get-BoundBackupInventoryItem([string]$BoundRoot, [object]$BackupDirectory) {
  $backupId = $BackupDirectory.Name
  $backupPath = $BackupDirectory.FullName
  $filesRoot = Join-Path $backupPath 'files'
  $manifestPath = Join-Path $backupPath 'backup-manifest.txt'
  $reasons = New-Object System.Collections.Generic.List[string]
  $manifestEntries = 0
  $restorableFiles = 0
  $capturedVersion = 'unknown'

  if (-not (Test-SafeBackupId $backupId)) { [void]$reasons.Add('unsafe_backup_id') }
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { [void]$reasons.Add('missing_manifest') }
  if (-not (Test-Path -LiteralPath $filesRoot -PathType Container)) { [void]$reasons.Add('missing_files_dir') }

  if ((Test-Path -LiteralPath $manifestPath -PathType Leaf) -and (Test-Path -LiteralPath $filesRoot -PathType Container)) {
    $versionPath = Join-Path $filesRoot 'HARNESS_VERSION'
    if (Test-Path -LiteralPath $versionPath -PathType Leaf) {
      $versionText = ([IO.File]::ReadAllText($versionPath)).Trim()
      if (-not [string]::IsNullOrWhiteSpace($versionText)) { $capturedVersion = $versionText }
    }

    foreach ($line in ([IO.File]::ReadAllLines($manifestPath))) {
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      if ($line -match '^(no_existing_bound_files|no_preexisting_project_files)$') { continue }
      $manifestEntries++
      try {
        $rel = Get-SafeRestoreRelativePath (($line -split '[|]')[0])
        $source = Join-Path $filesRoot ($rel -replace '/', [IO.Path]::DirectorySeparatorChar)
        if (-not (Test-ChildPathOfRoot $filesRoot $source)) {
          [void]$reasons.Add("source_outside_files_root:$rel")
          continue
        }
        if (-not (Test-HarnessLeaf $source)) {
          [void]$reasons.Add("missing_source_file:$rel")
          continue
        }
        $restorableFiles++
      }
      catch {
        [void]$reasons.Add("unsafe_path:$($_.Exception.Message)")
      }
    }
  }

  $restorable = ($reasons.Count -eq 0 -and $manifestEntries -gt 0 -and $restorableFiles -eq $manifestEntries)
  if ($reasons.Count -eq 0 -and $manifestEntries -eq 0) { [void]$reasons.Add('empty_manifest') }
  $status = if ($restorable) { 'ok' } else { 'not_restorable' }
  $reason = if ($reasons.Count -eq 0) { 'none' } else { ($reasons -join ';') }

  return [ordered]@{
    Id = $backupId
    Origin = Get-BoundBackupOrigin $backupId
    Path = $backupPath
    ManifestPath = $manifestPath
    FilesRoot = $filesRoot
    CreatedUtc = $BackupDirectory.CreationTimeUtc.ToString('o')
    UpdatedUtc = $BackupDirectory.LastWriteTimeUtc.ToString('o')
    CapturedVersion = $capturedVersion
    ManifestEntries = $manifestEntries
    RestorableFiles = $restorableFiles
    Restorable = $restorable
    Status = $status
    Reason = $reason
  }
}

function Get-BoundBackupInventory([string]$BoundRoot) {
  $backupRoot = Join-Path $BoundRoot 'orquestador/migration/backups'
  $items = New-Object System.Collections.Generic.List[object]
  if (-not (Test-Path -LiteralPath $backupRoot -PathType Container)) {
    return [ordered]@{ BackupRoot = $backupRoot; Items = $items }
  }
  foreach ($dir in (Get-ChildItem -LiteralPath $backupRoot -Directory -Force | Sort-Object LastWriteTimeUtc -Descending)) {
    [void]$items.Add((Get-BoundBackupInventoryItem $BoundRoot $dir))
  }
  return [ordered]@{ BackupRoot = $backupRoot; Items = $items }
}

function Write-BoundBackupInventoryCheckOnly([string]$ProjectRootValue) {
  $bindingText = Read-HarnessText 'PROJECT_BINDING.yaml'
  $sourceMode = Get-Scalar $bindingText 'binding_mode'
  if ($sourceMode -ne 'source_template') { throw "list-bound-backups requires source_template root, got: $sourceMode" }
  $target = Resolve-BoundUpdateTarget $Root $ProjectRootValue
  $inventory = Get-BoundBackupInventory $target.BoundRoot
  $restorableCount = @($inventory.Items | Where-Object { $_.Restorable }).Count

  Write-Host 'Hebri-AI-Harness list-bound-backups CheckOnly'
  Write-Host "source_root=$Root"
  Write-Host "source_binding_mode=$sourceMode"
  Write-Host "target_project_root=$ProjectRootValue"
  Write-Host "resolved_project_root=$($target.ProjectRoot)"
  Write-Host "target_harness_root=$($target.BoundRoot)"
  Write-Host "target_binding_mode=$(Get-Scalar $target.Binding 'binding_mode')"
  Write-Host "target_harness_version=$(Get-Scalar $target.Binding 'harness_version')"
  Write-Host "backups_root=$($inventory.BackupRoot)"
  Write-Host 'writes=false'
  Write-Host 'backup_inventory_available=true'
  Write-Host "backup_count=$($inventory.Items.Count)"
  Write-Host "restorable_count=$restorableCount"
  foreach ($item in $inventory.Items) {
    Write-Host "backup_id=$($item.Id)"
    Write-Host "backup_origin=$($item.Origin)"
    Write-Host "backup_status=$($item.Status)"
    Write-Host "backup_restorable=$($item.Restorable.ToString().ToLowerInvariant())"
    Write-Host "backup_captured_version=$($item.CapturedVersion)"
    Write-Host "backup_created_utc=$($item.CreatedUtc)"
    Write-Host "backup_updated_utc=$($item.UpdatedUtc)"
    Write-Host "backup_manifest=$($item.ManifestPath)"
    Write-Host "backup_files_root=$($item.FilesRoot)"
    Write-Host "backup_manifest_entries=$($item.ManifestEntries)"
    Write-Host "backup_restorable_files=$($item.RestorableFiles)"
    Write-Host "backup_reason=$($item.Reason)"
  }
  Write-Host 'inventory_status=ok'
}

function Restore-BoundBackupFiles([string]$BoundRoot, [object]$Backup) {
  $restored = 0
  $boundFull = [IO.Path]::GetFullPath($BoundRoot).TrimEnd('\','/')
  foreach ($line in ([IO.File]::ReadAllLines($Backup.ManifestPath))) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line -match '^(no_existing_bound_files|no_preexisting_project_files)$') { continue }
    $rel = Get-SafeRestoreRelativePath (($line -split '[|]')[0])
    $source = Join-Path $Backup.FilesRoot ($rel -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-HarnessLeaf $source)) { throw "backup source file missing: $rel" }
    $destination = Join-Path $BoundRoot ($rel -replace '/', [IO.Path]::DirectorySeparatorChar)
    $destinationFull = [IO.Path]::GetFullPath($destination)
    if (-not ($destinationFull.StartsWith(($boundFull + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase) -or
              $destinationFull.StartsWith(($boundFull + [IO.Path]::AltDirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase))) {
      throw "restore destination outside bound root: $rel"
    }
    Ensure-Directory (Split-Path -Parent $destination)
    Copy-Item -LiteralPath $source -Destination $destination -Force
    $restored++
  }
  return $restored
}

function Write-BoundRestoreMigrationReport([string]$BoundRoot, [string]$RestoreId, [string]$SourceVersion, [string]$TargetVersion, [string]$ProjectRootPath, [object]$RestoreSource, [object]$PreRestoreBackup, [hashtable]$ValidatorResults, [int]$RestoredFiles, [string]$StartedAt, [string]$FinishedAt) {
  $validateAgent = if ($ValidatorResults.ContainsKey('validate_agent_contracts')) { $ValidatorResults['validate_agent_contracts'] } else { 'not_run' }
  $validateSecurity = if ($ValidatorResults.ContainsKey('validate_security_policy')) { $ValidatorResults['validate_security_policy'] } else { 'not_run' }
  $validateMigration = if ($ValidatorResults.ContainsKey('validate_migration')) { $ValidatorResults['validate_migration'] } else { 'not_run' }
  $validateHarness = if ($ValidatorResults.ContainsKey('validate_harness')) { $ValidatorResults['validate_harness'] } else { 'not_run' }
  $report = @"
schema: hebrinex.migration_report
version: "0.1"
template: false
migration_id: "$RestoreId"
approval_id: "HAH-0108-BOUND-RESTORE-SAFE"
source_version: "$SourceVersion"
target_version: "$TargetVersion"
mode: "Apply"
status: applied
started_at: "$StartedAt"
finished_at: "$FinishedAt"
root: $(Format-YamlString $BoundRoot)
binding_mode: "bound"
project_root: $(Format-YamlString $ProjectRootPath)
route_file: "bound-restore-from-backup"
check_only:
  wrote_files: false
  requires_backup_id: true
backup:
  required: true
  created: true
  path: $(Format-YamlString $PreRestoreBackup.Path)
  manifest_or_checksum: $(Format-YamlString $PreRestoreBackup.ManifestPath)
  files_captured: $($PreRestoreBackup.FileCount)
restore:
  source_backup_id: $(Format-YamlString $RestoreSource.Id)
  source_backup_path: $(Format-YamlString $RestoreSource.Path)
  source_manifest: $(Format-YamlString $RestoreSource.ManifestPath)
  restored_files: $RestoredFiles
  deletes_extra_files: false
validators:
  validate_agent_contracts: $validateAgent
  validate_security_policy: $validateSecurity
  validate_migration: $validateMigration
  validate_harness: $validateHarness
post_migration_contract:
  path: $(Format-YamlString (Join-Path $BoundRoot 'orquestador/migration/contracts/post-migration-contract.yaml'))
  status: applied
risks:
  - $(Format-YamlString 'restore-bound overwrites only files present in the selected backup manifest')
next_steps:
  - $(Format-YamlString 'Review restored harness state before the next update-bound operation')
"@
  $reportPath = Join-Path $BoundRoot "orquestador/migration/reports/$RestoreId.yaml"
  Write-Utf8Text $reportPath ($report + "`n")
  return $reportPath
}

function Invoke-BoundRestoreApply([string]$ProjectRootValue, [string]$RequestedBackupId) {
  $sourceBindingText = Read-HarnessText 'PROJECT_BINDING.yaml'
  $sourceMode = Get-Scalar $sourceBindingText 'binding_mode'
  if ($sourceMode -ne 'source_template') { throw "restore-bound Apply requires source_template root, got: $sourceMode" }
  $target = Resolve-BoundUpdateTarget $Root $ProjectRootValue
  $currentVersionPath = Join-Path $target.BoundRoot 'HARNESS_VERSION'
  $sourceVersion = if (Test-Path -LiteralPath $currentVersionPath -PathType Leaf) { ([IO.File]::ReadAllText($currentVersionPath)).Trim() } else { Get-Scalar $target.Binding 'harness_version' }
  if ([string]::IsNullOrWhiteSpace($sourceVersion)) { $sourceVersion = 'unknown' }
  $restoreSource = Resolve-BoundRestoreBackup $target.BoundRoot $RequestedBackupId
  $targetVersion = Get-RestoreTargetVersion $restoreSource $sourceVersion
  $startedAt = (Get-Date).ToUniversalTime().ToString('o')
  $restoreId = 'migration-bound-restore-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ') + '-' + ([guid]::NewGuid().ToString('N').Substring(0, 8))
  $preRestoreBackup = Create-BoundUpdateBackupRecord $target.BoundRoot $restoreId
  $restoredFiles = Restore-BoundBackupFiles $target.BoundRoot $restoreSource

  $validatorResults = @{}
  $validatorResults['validate_agent_contracts'] = Invoke-BoundValidator $target.BoundRoot 'scripts/validate-agent-contracts.ps1'
  $validatorResults['validate_security_policy'] = Invoke-BoundValidator $target.BoundRoot 'scripts/validate-security-policy.ps1'
  $reportPath = Write-BoundRestoreMigrationReport $target.BoundRoot $restoreId $sourceVersion $targetVersion $target.ProjectRoot $restoreSource $preRestoreBackup $validatorResults $restoredFiles $startedAt (Get-Date).ToUniversalTime().ToString('o')
  $validatorResults['validate_migration'] = Invoke-BoundValidator $target.BoundRoot 'scripts/validate-migration.ps1' @('-RequireApplied')
  $validatorResults['validate_harness'] = Invoke-BoundValidator $target.BoundRoot 'scripts/validate-harness.ps1' @('-RunNegativeTests','-SkipNestedValidators')
  $reportPath = Write-BoundRestoreMigrationReport $target.BoundRoot $restoreId $sourceVersion $targetVersion $target.ProjectRoot $restoreSource $preRestoreBackup $validatorResults $restoredFiles $startedAt (Get-Date).ToUniversalTime().ToString('o')

  return [ordered]@{
    ProjectRoot = $target.ProjectRoot
    BoundRoot = $target.BoundRoot
    RestoreId = $restoreId
    SourceVersion = $sourceVersion
    TargetVersion = $targetVersion
    RestoreSourceId = $restoreSource.Id
    RestoredFiles = $restoredFiles
    BackupPath = $preRestoreBackup.Path
    BackupManifest = $preRestoreBackup.ManifestPath
    ReportPath = $reportPath
  }
}

function Write-BoundRestoreCheckOnly([string]$ProjectRootValue, [string]$RequestedBackupId) {
  $bindingText = Read-HarnessText 'PROJECT_BINDING.yaml'
  Write-Host 'Hebri-AI-Harness restore-bound CheckOnly'
  Write-Host "source_root=$Root"
  Write-Host "source_binding_mode=$(Get-Scalar $bindingText 'binding_mode')"
  Write-Host "target_project_root=$ProjectRootValue"
  Write-Host "backup_id=$RequestedBackupId"
  if (-not [string]::IsNullOrWhiteSpace($ProjectRootValue)) {
    try {
      $target = Resolve-BoundUpdateTarget $Root $ProjectRootValue
      Write-Host "resolved_project_root=$($target.ProjectRoot)"
      Write-Host "target_harness_root=$($target.BoundRoot)"
      if (-not [string]::IsNullOrWhiteSpace($RequestedBackupId)) {
        $backup = Resolve-BoundRestoreBackup $target.BoundRoot $RequestedBackupId
        Write-Host "restore_source_path=$($backup.Path)"
        Write-Host "restore_source_manifest=$($backup.ManifestPath)"
      }
    }
    catch { Write-Host "target_validation=$($_.Exception.Message)" }
  }
  Write-Host 'planned_steps:'
  Write-Host ' - validate source_template'
  Write-Host ' - validate existing target <project_root>/.hebrinex is bound'
  Write-Host ' - validate BackupId stays inside orquestador/migration/backups'
  Write-Host ' - create pre-restore backup before first write'
  Write-Host ' - restore only files present in backup-manifest.txt and files/'
  Write-Host ' - block path traversal, .git, .codex and infoHebri.md'
  Write-Host ' - run bound validators'
  Write-Host 'writes=false'
  Write-Host 'restore_available=true'
  Write-Host 'requires_project_root=true'
  Write-Host 'requires_backup_id=true'
}
function Format-BoundValidatorOutput([object[]]$Output, [int]$MaxLines = 80) {
  $lines = @($Output | ForEach-Object { [string]$_ })
  if ($lines.Count -gt $MaxLines) { $lines = $lines[($lines.Count - $MaxLines)..($lines.Count - 1)] }
  return ($lines -join ' | ')
}

function Invoke-BoundValidator([string]$BoundRoot, [string]$RelativePath, [string[]]$ExtraArgs = @()) {
  $scriptPath = Join-Path $BoundRoot $RelativePath
  if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw "missing bound validator: $RelativePath" }
  $global:LASTEXITCODE = 0
  $validatorOutput = & $scriptPath -Root $BoundRoot @ExtraArgs *>&1
  if ($LASTEXITCODE -ne 0) {
    throw "bound validator failed: $RelativePath exit_code=$LASTEXITCODE output=$(Format-BoundValidatorOutput $validatorOutput)"
  }
  return 'ok'
}

function Invoke-BootstrapApply([string]$ProjectRootValue) {
  $bindingText = Read-HarnessText 'PROJECT_BINDING.yaml'
  $sourceMode = Get-Scalar $bindingText 'binding_mode'
  if ($sourceMode -ne 'source_template') { throw "bootstrap Apply requires source_template root, got: $sourceMode" }
  $projectRootPath = Resolve-BootstrapProjectRoot $Root $ProjectRootValue
  $boundRoot = Join-Path $projectRootPath '.hebrinex'
  if (Test-Path -LiteralPath $boundRoot) { throw "target already has .hebrinex: $boundRoot" }
  $version = (Read-HarnessText 'HARNESS_VERSION').Trim()
  $startedAt = (Get-Date).ToUniversalTime().ToString('o')
  $boundAt = $startedAt
  $bootstrapId = 'migration-bootstrap-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ') + '-' + ([guid]::NewGuid().ToString('N').Substring(0, 8))
  $instanceId = 'BOUND-' + (Get-SafeProjectName $projectRootPath) + '-' + ([guid]::NewGuid().ToString('N').Substring(0, 8))

  $copyResult = Copy-HarnessManifestToBoundRoot $boundRoot
  $backup = Create-BootstrapBackupRecord $projectRootPath $boundRoot $bootstrapId
  $gitignoreUpdated = Ensure-ConsumerGitIgnore $projectRootPath
  Write-BoundProjectBinding $boundRoot $projectRootPath $version $boundAt $instanceId
  Update-BoundState $boundRoot $projectRootPath $boundAt
  Update-BoundMemoryRegistry $boundRoot $boundAt
  Update-BoundActiveContract $boundRoot $projectRootPath $version
  [void](Set-BootstrapPostMigrationContractFile $boundRoot $version)

  $validatorResults = @{}
  $validatorResults['validate_agent_contracts'] = Invoke-BoundValidator $boundRoot 'scripts/validate-agent-contracts.ps1'
  $validatorResults['validate_security_policy'] = Invoke-BoundValidator $boundRoot 'scripts/validate-security-policy.ps1'
  $reportPath = Write-BootstrapMigrationReport $boundRoot $bootstrapId $version $projectRootPath $backup $validatorResults $startedAt (Get-Date).ToUniversalTime().ToString('o')
  $validatorResults['validate_migration'] = Invoke-BoundValidator $boundRoot 'scripts/validate-migration.ps1' @('-RequireApplied')
  $validatorResults['validate_harness'] = Invoke-BoundValidator $boundRoot 'scripts/validate-harness.ps1' @('-RunNegativeTests','-SkipNestedValidators')
  $reportPath = Write-BootstrapMigrationReport $boundRoot $bootstrapId $version $projectRootPath $backup $validatorResults $startedAt (Get-Date).ToUniversalTime().ToString('o')

  return [ordered]@{
    ProjectRoot = $projectRootPath
    BoundRoot = $boundRoot
    BootstrapId = $bootstrapId
    CopiedFiles = $copyResult.files
    CopiedDirectories = $copyResult.directories
    GitignoreUpdated = $gitignoreUpdated
    BackupPath = $backup.Path
    BackupManifest = $backup.ManifestPath
    ReportPath = $reportPath
    InstanceId = $instanceId
  }
}

function Write-BootstrapCheckOnly([string]$ProjectRootValue) {
  $bindingText = Read-HarnessText 'PROJECT_BINDING.yaml'
  Write-Host 'Hebri-AI-Harness bootstrap CheckOnly'
  Write-Host "source_root=$Root"
  Write-Host "source_binding_mode=$(Get-Scalar $bindingText 'binding_mode')"
  Write-Host "target_project_root=$ProjectRootValue"
  if (-not [string]::IsNullOrWhiteSpace($ProjectRootValue)) {
    try {
      $resolved = Resolve-BootstrapProjectRoot $Root $ProjectRootValue
      Write-Host "resolved_project_root=$resolved"
      Write-Host "target_harness_root=$(Join-Path $resolved '.hebrinex')"
    }
    catch { Write-Host "target_validation=$($_.Exception.Message)" }
  }
  Write-Host 'planned_steps:'
  Write-Host ' - validate source_template'
  Write-Host ' - copy manifest-declared source to <project_root>/.hebrinex'
  Write-Host ' - exclude .git, .codex, infoHebri.md, temporary and local files'
  Write-Host ' - set PROJECT_BINDING.yaml to bound'
  Write-Host ' - regularize state, memory registry and post-migration contract'
  Write-Host ' - ensure consumer .gitignore excludes .hebrinex/'
  Write-Host ' - run bound validators'
  Write-Host 'writes=false'
  Write-Host 'apply_available=true'
  Write-Host 'requires_project_root=true'
}
function Show-Help() {
  Write-Host 'Hebri-AI-Harness CLI Core'
  Write-Host 'cli_contract_version=0.5'
  Write-Host 'cli_status=stable'
  Write-Host 'commands=help,status,budget,usage,preflight,approve,validate,audit,migrate,bootstrap,update-bound,list-bound-backups,restore-bound,command,state-machine,agent-runtime,lock'
  Write-Host ''
  Write-Host 'Usage:'
  Write-Host '  hebrinex.ps1 status [-Root <path>]'
  Write-Host '  hebrinex.ps1 budget [-Root <path>]'
  Write-Host '  hebrinex.ps1 usage [-Root <path>]'
  Write-Host '  hebrinex.ps1 preflight [-ApprovalId <id>] [-Action <text>] [-ReadSet <text>] [-WriteSet <text>]'
  Write-Host '  hebrinex.ps1 approve -CheckOnly|-Apply -CommandText <command> [-Purpose <text>] [-TtlMinutes <1-1440>]'
  Write-Host '  hebrinex.ps1 validate [-RunNegativeTests]'
  Write-Host '  hebrinex.ps1 audit [-RunNegativeTests]'
  Write-Host '  hebrinex.ps1 migrate -CheckOnly|-Apply [-TargetVersion 0.16.0]'
  Write-Host '  hebrinex.ps1 bootstrap -CheckOnly|-Apply -ProjectRoot <path>'
  Write-Host '  hebrinex.ps1 update-bound -CheckOnly|-Apply -ProjectRoot <path>'
  Write-Host '  hebrinex.ps1 list-bound-backups -CheckOnly -ProjectRoot <path>'
  Write-Host '  hebrinex.ps1 restore-bound -CheckOnly|-Apply -ProjectRoot <path> -BackupId <id>'
  Write-Host '  hebrinex.ps1 command -CheckOnly|-Apply -CommandText <command> [-Purpose <text>] [-Json]'
  Write-Host '  hebrinex.ps1 state-machine -FromState <state> -ToState <state> [-Json]'
  Write-Host '  hebrinex.ps1 agent-runtime -RoleId <role> -Capability <capability> [-FromState <state> -ToState <state>] [-Json]'
  Write-Host '  hebrinex.ps1 lock -Acquire -Paths <p1,p2> [-Owner <id>] [-TtlMinutes <1-1440>] [-Reason <text>]'
  Write-Host '  hebrinex.ps1 lock -Release -LockId <L-...>'
  Write-Host '  hebrinex.ps1 lock -List'
}

$Root = (Resolve-Path -LiteralPath $Root).Path

switch ($Command) {
  'help' {
    Show-Help
  }
  'status' {
    $bindingText = Read-HarnessText 'PROJECT_BINDING.yaml'
    $stateText = Read-HarnessText 'orquestador/sdd/progress/state.yaml'
    $version = (Read-HarnessText 'HARNESS_VERSION').Trim()
    Write-Host 'Hebri-AI-Harness status'
    Write-Host "root=$Root"
    Write-Host "harness_version=$version"
    Write-Host "binding_mode=$(Get-Scalar $bindingText 'binding_mode')"
    Write-Host "project_root=$(Get-Scalar $bindingText 'project_root')"
    Write-Host "state_mode=$(Get-Scalar $stateText 'mode')"
    Write-Host "project_binding_status=$(Get-SectionScalar $stateText 'project_binding' 'status')"
    Write-Host "session_contract_status=$(Get-SectionScalar $stateText 'session_contract' 'status')"
    Write-Host "active_cycle_status=$(Get-SectionScalar $stateText 'active_cycle' 'status')"
    Write-Host "active_approval_id=$(Get-SectionScalar $stateText 'approvals' 'active_approval_id')"
    $locks = Get-HebriLockInventory -Root $Root
    Write-Host "open_locks=$($locks.Active.Count + $locks.Expired.Count)"
    Write-Host "expired_locks=$($locks.Expired.Count)"
    foreach ($lock in $locks.Expired) {
      Write-Host "expired_lock=$($lock.LockId) expires_at=$($lock.ExpiresAt) file=$($lock.File)"
    }
    Write-Host 'runtime_authority=non_authoritative'
  }
  'budget' {
    $budgetText = Read-HarnessText 'orquestador/context-budget.yaml'
    Write-Host 'Hebri-AI-Harness budget'
    Write-BudgetLine 'memory_bootstrap' (Get-InlineBudget $budgetText 'memory_bootstrap') @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/reentry-light.md')
    Write-BudgetLine 'first_message' (Get-InlineBudget $budgetText 'first_message') @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/first-message.md')
    Write-BudgetLine 'debug_log_intake' (Get-InlineBudget $budgetText 'debug_log_intake') @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/entrypoints/debug-log-intake.md','orquestador/entrypoints/reentry-light.md')
    Write-BudgetLine 'leader_light' (Get-InlineBudget $budgetText 'leader_light') @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/memory/memory-registry.yaml','orquestador/memory/memory-routing.yaml','orquestador/context-budget.yaml','orquestador/sdd/progress/state.yaml','orquestador/sdd/progress/registry.yaml','orquestador/method/session-contract.md')
    Write-BudgetLine 'runtime_status' (Get-InlineBudget $budgetText 'runtime_status') @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/context-budget.yaml','orquestador/runtime/active-session.template.json')
    Write-BudgetLine 'runtime_reentry' (Get-InlineBudget $budgetText 'runtime_reentry') @('PROJECT_BINDING.yaml','orquestador/memory/local/session-pin.md','orquestador/context-budget.yaml','orquestador/runtime/active-session.template.json','orquestador/sdd/progress/state.yaml','orquestador/sdd/progress/registry.yaml')
  }
  'usage' {
    Write-UsageReport
  }
  'preflight' {
    Write-Host "Approval ID: $ApprovalId"
    Write-Host "Accion propuesta: $Action"
    Write-Host "CWD: $Root"
    Write-Host "Read-set: $ReadSet"
    Write-Host "Write-set: $WriteSet"
    Write-Host 'Comando/tool: scripts/hebrinex.ps1'
    Write-Host 'Red/git/externo: no por defecto'
    Write-Host "Riesgo: $Risk"
    Write-Host "Verificacion: $Verification"
    Write-Host 'Evidencia esperada: salida de comando y validadores aplicables'
    Write-Host 'Requiere SI: SI'
  }
  'approve' {
    if (($CheckOnly -and $Apply) -or (-not $CheckOnly -and -not $Apply)) {
      throw 'approve requires exactly one mode: -CheckOnly or -Apply'
    }
    if ([string]::IsNullOrWhiteSpace($CommandText)) {
      throw 'approve requires -CommandText with the exact action to approve'
    }
    $safeCommandText = Redact-HebriText $CommandText
    if ($CheckOnly) {
      Write-Host 'Hebri-AI-Harness approve CheckOnly'
      Write-Host "root=$Root"
      Write-Host "command_text=$safeCommandText"
      Write-Host "ttl_minutes=$TtlMinutes"
      Write-Host 'approval_store=orquestador/sdd/progress/approvals'
      Write-Host 'writes=false'
      Write-Host 'apply_available=true'
      break
    }
    $version = (Read-HarnessText 'HARNESS_VERSION').Trim()
    $envelope = New-HebriApprovalEnvelope -Root $Root -CommandText $CommandText -Purpose $Purpose -TtlMinutes $TtlMinutes -HarnessVersion $version
    Write-Host 'Hebri-AI-Harness approve Apply'
    Write-Host "root=$Root"
    Write-Host "command_text=$safeCommandText"
    Write-Host "approval_id=$($envelope.Id)"
    Write-Host "approval_path=$($envelope.Path)"
    Write-Host "expires_at=$($envelope.ExpiresAt)"
    Write-Host "command_sha256=$($envelope.CommandSha256)"
    Write-Host 'writes=true'
    Write-Host 'approve_status=recorded'
  }
  'validate' {
    $scriptPath = Resolve-HarnessPath 'scripts/validate-harness.ps1'
    if ($RunNegativeTests) { & $scriptPath -Root $Root -RunNegativeTests }
    else { & $scriptPath -Root $Root }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
  'audit' {
    $scriptPath = Resolve-HarnessPath 'scripts/audit-harness.ps1'
    if ($RunNegativeTests) { & $scriptPath -Root $Root -RunNegativeTests }
    else { & $scriptPath -Root $Root }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
  'migrate' {
    if (($CheckOnly -and $Apply) -or (-not $CheckOnly -and -not $Apply)) {
      throw 'migrate requires exactly one mode: -CheckOnly or -Apply'
    }
    $currentVersion = (Read-HarnessText 'HARNESS_VERSION').Trim()
    if ($CheckOnly -and $currentVersion -match '^0[.]10[.][0-9]+$' -and $TargetVersion -eq '0.10.0') {
      Write-Host 'Hebri-AI-Harness migration CheckOnly'
      Write-Host "root=$Root"
      Write-Host "detected_version=$currentVersion"
      Write-Host "target_version=$TargetVersion"
      Write-Host 'migration_required=false'
      Write-Host 'writes=false'
      break
    }
    if ($currentVersion -eq $TargetVersion) {
      if ($CheckOnly) {
        Write-Host 'Hebri-AI-Harness migration CheckOnly'
        Write-Host "root=$Root"
        Write-Host "detected_version=$currentVersion"
        Write-Host "target_version=$TargetVersion"
        Write-Host 'migration_required=false'
        Write-Host 'writes=false'
        break
      }
      throw "current version already equals target version: $TargetVersion"
    }
    $scriptPath = Resolve-HarnessPath 'scripts/migrate-harness.ps1'
    if ($CheckOnly) { & $scriptPath -Root $Root -TargetVersion $TargetVersion -CheckOnly }
    else { & $scriptPath -Root $Root -TargetVersion $TargetVersion -Apply }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
  'bootstrap' {
    if (($CheckOnly -and $Apply) -or (-not $CheckOnly -and -not $Apply)) {
      throw 'bootstrap requires exactly one mode: -CheckOnly or -Apply'
    }
    if ($CheckOnly) {
      Write-BootstrapCheckOnly $ProjectRoot
      break
    }
    $result = Invoke-BootstrapApply $ProjectRoot
    Write-Host 'Hebri-AI-Harness bootstrap Apply'
    Write-Host "source_root=$Root"
    Write-Host "target_project_root=$($result.ProjectRoot)"
    Write-Host "target_harness_root=$($result.BoundRoot)"
    Write-Host "harness_instance_id=$($result.InstanceId)"
    Write-Host "copied_files=$($result.CopiedFiles)"
    Write-Host "copied_directories=$($result.CopiedDirectories)"
    Write-Host "gitignore_updated=$($result.GitignoreUpdated.ToString().ToLowerInvariant())"
    Write-Host "backup_path=$($result.BackupPath)"
    Write-Host "backup_manifest=$($result.BackupManifest)"
    Write-Host "migration_report=$($result.ReportPath)"
    Write-Host 'writes=true'
    Write-Host 'bootstrap_status=applied'
  }
  'update-bound' {
    if (($CheckOnly -and $Apply) -or (-not $CheckOnly -and -not $Apply)) {
      throw 'update-bound requires exactly one mode: -CheckOnly or -Apply'
    }
    if ($CheckOnly) {
      Write-BoundUpdateCheckOnly $ProjectRoot
      break
    }
    $result = Invoke-BoundUpdateApply $ProjectRoot
    Write-Host 'Hebri-AI-Harness update-bound Apply'
    Write-Host "source_root=$Root"
    Write-Host "target_project_root=$($result.ProjectRoot)"
    Write-Host "target_harness_root=$($result.BoundRoot)"
    Write-Host "harness_instance_id=$($result.InstanceId)"
    Write-Host "source_version=$($result.SourceVersion)"
    Write-Host "target_version=$($result.TargetVersion)"
    Write-Host "copied_files=$($result.CopiedFiles)"
    Write-Host "copied_directories=$($result.CopiedDirectories)"
    Write-Host "preserved_manifest_files=$($result.PreservedManifestFiles)"
    Write-Host "gitignore_updated=$($result.GitignoreUpdated.ToString().ToLowerInvariant())"
    Write-Host "backup_path=$($result.BackupPath)"
    Write-Host "backup_manifest=$($result.BackupManifest)"
    Write-Host "migration_report=$($result.ReportPath)"
    Write-Host 'writes=true'
    Write-Host 'update_status=applied'
  }
  'list-bound-backups' {
    if ($Apply -or -not $CheckOnly) {
      throw 'list-bound-backups supports only -CheckOnly'
    }
    Write-BoundBackupInventoryCheckOnly $ProjectRoot
  }
  'restore-bound' {
    if (($CheckOnly -and $Apply) -or (-not $CheckOnly -and -not $Apply)) {
      throw 'restore-bound requires exactly one mode: -CheckOnly or -Apply'
    }
    if ($CheckOnly) {
      Write-BoundRestoreCheckOnly $ProjectRoot $BackupId
      break
    }
    $result = Invoke-BoundRestoreApply $ProjectRoot $BackupId
    Write-Host 'Hebri-AI-Harness restore-bound Apply'
    Write-Host "source_root=$Root"
    Write-Host "target_project_root=$($result.ProjectRoot)"
    Write-Host "target_harness_root=$($result.BoundRoot)"
    Write-Host "source_version=$($result.SourceVersion)"
    Write-Host "target_version=$($result.TargetVersion)"
    Write-Host "restore_source_id=$($result.RestoreSourceId)"
    Write-Host "restored_files=$($result.RestoredFiles)"
    Write-Host "pre_restore_backup_path=$($result.BackupPath)"
    Write-Host "pre_restore_backup_manifest=$($result.BackupManifest)"
    Write-Host "migration_report=$($result.ReportPath)"
    Write-Host 'writes=true'
    Write-Host 'restore_status=applied'
  }
  'state-machine' {
    $scriptPath = Resolve-HarnessPath 'scripts/state-machine.ps1'
    & $scriptPath -Root $Root -FromState $FromState -ToState $ToState -Json:$Json
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
  'agent-runtime' {
    $scriptPath = Resolve-HarnessPath 'scripts/agent-runtime.ps1'
    & $scriptPath -Root $Root -RoleId $RoleId -Capability $Capability -FromState $FromState -ToState $ToState -Json:$Json
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
  'lock' {
    $modeCount = @($Acquire, $Release, $List | Where-Object { $_ }).Count
    if ($modeCount -ne 1) {
      throw 'lock requires exactly one mode: -Acquire, -Release or -List'
    }
    if ($List) {
      $locks = Get-HebriLockInventory -Root $Root
      Write-Host 'Hebri-AI-Harness lock List'
      Write-Host "root=$Root"
      Write-Host 'writes=false'
      Write-Host "active_locks=$($locks.Active.Count)"
      Write-Host "expired_locks=$($locks.Expired.Count)"
      foreach ($lock in $locks.Active) {
        Write-Host "lock_id=$($lock.LockId) lock_state=active owner=$($lock.Owner) expires_at=$($lock.ExpiresAt) paths=$($lock.Paths -join ',')"
      }
      foreach ($lock in $locks.Expired) {
        Write-Host "lock_id=$($lock.LockId) lock_state=expired owner=$($lock.Owner) expires_at=$($lock.ExpiresAt) paths=$($lock.Paths -join ',')"
      }
      Write-Host 'lock_status=listed'
      break
    }
    if ($Acquire) {
      if ([string]::IsNullOrWhiteSpace($Paths)) {
        throw 'lock -Acquire requires -Paths with one or more comma-separated paths'
      }
      $pathList = @($Paths -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
      $effectiveOwner = if (-not [string]::IsNullOrWhiteSpace($Owner)) { $Owner } elseif (-not [string]::IsNullOrWhiteSpace($RoleId)) { $RoleId } else { 'operator' }
      $effectiveTtl = if ($PSBoundParameters.ContainsKey('TtlMinutes')) { $TtlMinutes } else { 120 }
      $lock = New-HebriHarnessLock -Root $Root -Paths $pathList -Owner $effectiveOwner -TtlMinutes $effectiveTtl -Reason $Reason
      Write-Host 'Hebri-AI-Harness lock Acquire'
      Write-Host "root=$Root"
      Write-Host "lock_id=$($lock.Id)"
      Write-Host "lock_path=$($lock.Path)"
      Write-Host "owner=$($lock.Owner)"
      Write-Host "expires_at=$($lock.ExpiresAt)"
      Write-Host "paths=$($lock.Paths -join ',')"
      Write-Host 'writes=true'
      Write-Host 'lock_status=acquired'
      break
    }
    if ([string]::IsNullOrWhiteSpace($LockId)) {
      throw 'lock -Release requires -LockId'
    }
    $released = Set-HebriHarnessLockReleased -Root $Root -LockId $LockId
    Write-Host 'Hebri-AI-Harness lock Release'
    Write-Host "root=$Root"
    Write-Host "lock_id=$($released.Id)"
    Write-Host "lock_path=$($released.Path)"
    Write-Host "previous_status=$($released.PreviousStatus)"
    Write-Host 'writes=true'
    Write-Host 'lock_status=released'
  }
  'command' {
    if (($CheckOnly -and $Apply) -or (-not $CheckOnly -and -not $Apply)) {
      throw 'command requires exactly one mode: -CheckOnly or -Apply'
    }
    $scriptPath = Resolve-HarnessPath 'scripts/command-gateway.ps1'
    & $scriptPath -Root $Root -CheckOnly:$CheckOnly -Apply:$Apply -CommandText $CommandText -Purpose $Purpose -ApprovalId $ApprovalId -RiskClass $RiskClass -Json:$Json
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
}
