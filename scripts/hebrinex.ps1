param(
  [Parameter(Position = 0)]
  [ValidateSet('help','status','budget','preflight','validate','audit','migrate','bootstrap','command')]
  [string]$Command = 'help',
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$RunNegativeTests,
  [switch]$CheckOnly,
  [switch]$Apply,
  [string]$TargetVersion = '0.10.0',
  [string]$ProjectRoot = '',
  [string]$ApprovalId = '',
  [string]$Action = '',
  [string]$ReadSet = '',
  [string]$WriteSet = '',
  [string]$Risk = 'bajo',
  [string]$Verification = '',
  [string]$CommandText = '',
  [string]$Purpose = '',
  [string]$RiskClass = '',
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Resolve-HarnessPath([string]$RelativePath) {
  Join-Path $Root $RelativePath
}

function Read-HarnessText([string]$RelativePath) {
  $path = Resolve-HarnessPath $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
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
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      $chars += (Get-Item -LiteralPath $path).Length
    }
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
      if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "manifest source file missing during bootstrap: $rel" }
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
function Invoke-BoundValidator([string]$BoundRoot, [string]$RelativePath, [string[]]$ExtraArgs = @()) {
  $scriptPath = Join-Path $BoundRoot $RelativePath
  if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw "missing bound validator: $RelativePath" }
  & $scriptPath -Root $BoundRoot @ExtraArgs *> $null
  if ($LASTEXITCODE -ne 0) { throw "bound validator failed: $RelativePath exit_code=$LASTEXITCODE" }
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
  $validatorResults['validate_harness'] = Invoke-BoundValidator $boundRoot 'scripts/validate-harness.ps1' @('-RunNegativeTests')
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
  Write-Host ''
  Write-Host 'Usage:'
  Write-Host '  hebrinex.ps1 status [-Root <path>]'
  Write-Host '  hebrinex.ps1 budget [-Root <path>]'
  Write-Host '  hebrinex.ps1 preflight [-ApprovalId <id>] [-Action <text>] [-ReadSet <text>] [-WriteSet <text>]'
  Write-Host '  hebrinex.ps1 validate [-RunNegativeTests]'
  Write-Host '  hebrinex.ps1 audit [-RunNegativeTests]'
  Write-Host '  hebrinex.ps1 migrate -CheckOnly|-Apply [-TargetVersion 0.10.0]'
  Write-Host '  hebrinex.ps1 bootstrap -CheckOnly|-Apply -ProjectRoot <path>'
  Write-Host '  hebrinex.ps1 command -CheckOnly|-Apply -CommandText <command> [-Purpose <text>] [-Json]'
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
  'command' {
    if (($CheckOnly -and $Apply) -or (-not $CheckOnly -and -not $Apply)) {
      throw 'command requires exactly one mode: -CheckOnly or -Apply'
    }
    $scriptPath = Resolve-HarnessPath 'scripts/command-gateway.ps1'
    & $scriptPath -Root $Root -CheckOnly:$CheckOnly -Apply:$Apply -CommandText $CommandText -Purpose $Purpose -ApprovalId $ApprovalId -RiskClass $RiskClass -Json:$Json
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
}
