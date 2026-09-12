$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'hebri-common.psm1') -Force -DisableNameChecking -Scope Local

$script:LegacyContractVersion = '1.0.0'
$script:LegacyApi = 'central1'
$script:LegacyCodeVersion = 'central1-p05'
$script:LegacyMinimumEngine = '0.17.1'

function Get-LegacyValue {
  param([object]$Value, [string]$Name, [object]$Default = $null)
  if ($null -eq $Value) { return $Default }
  if ($Value -is [Collections.IDictionary]) {
    if ($Value.Contains($Name)) { return $Value[$Name] }
    return $Default
  }
  $property = $Value.PSObject.Properties[$Name]
  if ($null -eq $property) { return $Default }
  return $property.Value
}

function Get-LegacyFullPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  return [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

function Test-LegacyPathEqual {
  param([string]$Left, [string]$Right)
  try { return [string]::Equals((Get-LegacyFullPath $Left), (Get-LegacyFullPath $Right), [StringComparison]::OrdinalIgnoreCase) }
  catch { return $false }
}

function Get-LegacyRelativePath {
  param([string]$Root, [string]$Path)
  $rootFull = (Get-LegacyFullPath $Root)
  $pathFull = [IO.Path]::GetFullPath($Path)
  if (-not (Test-HebriPathContained -Root $rootFull -Candidate $pathFull)) { throw 'PATH_OUTSIDE_ROOT: path escaped the legacy root' }
  return ($pathFull.Substring($rootFull.Length).TrimStart('\','/') -replace '\\','/')
}

function Test-LegacySafeRelativePath {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path) -or [IO.Path]::IsPathRooted($Path)) { return $false }
  $inputNormalized = $Path -replace '\\','/'
  $normalized = $inputNormalized.Trim('/')
  if ($normalized -ne $inputNormalized) { return $false }
  foreach ($part in $normalized.Split('/')) {
    if ($part -in @('', '.', '..') -or $part.Contains(':')) { return $false }
  }
  return $true
}

function Get-LegacyInventory {
  param([Parameter(Mandatory = $true)][string]$Root)
  $rootFull = Get-LegacyFullPath $Root
  if (-not (Test-Path -LiteralPath $rootFull -PathType Container)) { throw 'PROJECT_NOT_FOUND: legacy root is missing' }
  $pending = New-Object 'System.Collections.Generic.Stack[string]'
  $pending.Push($rootFull)
  $entries = New-Object System.Collections.Generic.List[object]
  while ($pending.Count -gt 0) {
    $directory = $pending.Pop()
    foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop)) {
      if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'REPARSE_POINT_UNSUPPORTED: legacy tree contains a reparse point' }
      if ($item.PSIsContainer) { $pending.Push($item.FullName); continue }
      $relative = Get-LegacyRelativePath -Root $rootFull -Path $item.FullName
      if (-not (Test-LegacySafeRelativePath $relative)) { throw 'PATH_OUTSIDE_ROOT: unsafe legacy relative path' }
      [void]$entries.Add([pscustomobject][ordered]@{
        path = $relative
        sha256 = Get-HebriFileSha256 $item.FullName
        size = [int64]$item.Length
      })
    }
  }
  return @($entries | Sort-Object path)
}

function Get-LegacyTreeHash {
  param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Entries)
  $canonical = @($Entries | Sort-Object path | ForEach-Object {
    [ordered]@{ path = [string](Get-LegacyValue $_ 'path'); sha256 = [string](Get-LegacyValue $_ 'sha256'); size = [int64](Get-LegacyValue $_ 'size' 0) }
  })
  return Get-Sha256Hex (ConvertTo-HebriCanonicalJson $canonical)
}

function Test-LegacyPrivatePath {
  param([string]$Path)
  $p = ($Path -replace '\\','/').ToLowerInvariant()
  $name = [IO.Path]::GetFileName($p)
  return ($p -eq 'infohebri.md' -or $p.StartsWith('.git/') -or $p.StartsWith('.codex/') -or
    $name -eq '.env' -or $name -match '(credential|secret|token|password)' -or
    $name -match '[.](pem|key|pfx|p12)$' -or $name -match '^id_(rsa|ed25519)')
}

function Test-LegacyPriorBackupPath {
  param([string]$Path)
  $p = ($Path -replace '\\','/').TrimStart('/').ToLowerInvariant()
  return ($p.StartsWith('orquestador/migration/backups/') -or $p.StartsWith('instance/migration/backups/'))
}

function Get-LegacyBaselineClass {
  param([string]$Path, [switch]$ManifestDeclared)
  $p = ($Path -replace '\\','/').TrimStart('/')
  if ($p -match '(^|/)(node_modules|__pycache__|[.]pytest_cache|[.]tmp)(/|$)' -or [IO.Path]::GetFileName($p) -in @('Thumbs.db','.DS_Store')) { return 'generated' }
  if ($p -eq 'PROJECT_BINDING.yaml' -or $p -eq 'PROGRESS.md' -or
      $p.StartsWith('orquestador/context/') -or $p.StartsWith('orquestador/memory/') -or
      $p.StartsWith('orquestador/sdd/progress/') -or $p.StartsWith('orquestador/sdd/specs/') -or
      $p.StartsWith('orquestador/migration/backups/') -or $p.StartsWith('orquestador/migration/reports/') -or
      $p -eq 'orquestador/migration/contracts/post-migration-contract.yaml' -or
      $p -eq 'orquestador/runtime/gateway-rate.json' -or $p.StartsWith('orquestador/runtime/claude/') -or
      $p -eq 'mcp/agents-backend.local.yaml' -or $p.StartsWith('instance/')) { return 'instance' }
  if ($ManifestDeclared) { return 'product' }
  if (Test-LegacyPrivatePath $p) { return 'personal' }
  return 'product'
}

function Get-LegacyManifestPaths {
  param([string]$SourceRoot)
  $manifestPath = Join-Path $SourceRoot 'orquestador/harness-manifest.txt'
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { return $null }
  $paths = New-Object Collections.Generic.List[string]
  $seen = @{}
  foreach ($line in [IO.File]::ReadAllLines($manifestPath)) {
    if ($line -notmatch '^file\s+(.+?)\s*$') { continue }
    $path = ($Matches[1] -replace '\\','/').Trim()
    if (-not (Test-LegacySafeRelativePath $path)) { throw "BASELINE_UNVERIFIED: unsafe manifest path: $path" }
    $key = $path.ToLowerInvariant()
    if ($seen.ContainsKey($key)) { throw "BASELINE_UNVERIFIED: duplicate manifest path: $path" }
    $seen[$key] = $true
    [void]$paths.Add($path)
  }
  if ($paths.Count -eq 0) { throw 'BASELINE_UNVERIFIED: release manifest declares no files' }
  return [pscustomobject]@{ Path = $manifestPath; Paths = @($paths) }
}

function Test-LegacyClosedProperties {
  param([object]$Value, [string[]]$Allowed, [string[]]$Required)
  if ($null -eq $Value) { return $false }
  $names = if ($Value -is [Collections.IDictionary]) { @($Value.Keys | ForEach-Object { [string]$_ }) } else { @($Value.PSObject.Properties.Name) }
  foreach ($name in $names) { if ($Allowed -notcontains $name) { return $false } }
  foreach ($name in $Required) { if ($names -notcontains $name) { return $false } }
  return $true
}

function Test-HebriLegacyBaseline {
  param([Parameter(Mandatory = $true)][object]$Baseline)
  $result = [ordered]@{ Valid = $false; Reason = 'BASELINE_UNVERIFIED' }
  if (-not (Test-LegacyClosedProperties -Value $Baseline -Allowed @('schema','schema_version','source_version','source_ref','generated_at','inventory_scope','source_manifest_sha256','tree_sha256','files') -Required @('schema','schema_version','source_version','source_ref','generated_at','inventory_scope','source_manifest_sha256','tree_sha256','files'))) { return [pscustomobject]$result }
  if ([string](Get-LegacyValue $Baseline 'schema') -ne 'hebrinex.legacy_migration_baseline' -or [int](Get-LegacyValue $Baseline 'schema_version' 0) -ne 1 -or
      [string](Get-LegacyValue $Baseline 'source_version') -notmatch '^[0-9]+[.][0-9]+[.][0-9]+$' -or
      [string]::IsNullOrWhiteSpace([string](Get-LegacyValue $Baseline 'source_ref')) -or
      [string](Get-LegacyValue $Baseline 'tree_sha256') -notmatch '^[a-f0-9]{64}$') { return [pscustomobject]$result }
  $scope = [string](Get-LegacyValue $Baseline 'inventory_scope')
  $sourceManifestHash = Get-LegacyValue $Baseline 'source_manifest_sha256'
  if ($scope -notin @('release_manifest','all_files') -or
      ($scope -eq 'release_manifest' -and [string]$sourceManifestHash -notmatch '^[a-f0-9]{64}$') -or
      ($scope -eq 'all_files' -and $null -ne $sourceManifestHash)) { return [pscustomobject]$result }
  $files = @(Get-LegacyValue $Baseline 'files' @())
  $seen = @{}
  foreach ($file in $files) {
    if (-not (Test-LegacyClosedProperties -Value $file -Allowed @('path','sha256','size','class') -Required @('path','sha256','size','class'))) { return [pscustomobject]$result }
    $path = [string](Get-LegacyValue $file 'path')
    if (-not (Test-LegacySafeRelativePath $path) -or $seen.ContainsKey($path.ToLowerInvariant()) -or
        [string](Get-LegacyValue $file 'sha256') -notmatch '^[a-f0-9]{64}$' -or [int64](Get-LegacyValue $file 'size' -1) -lt 0 -or
        [string](Get-LegacyValue $file 'class') -notin @('product','instance','personal','generated')) { return [pscustomobject]$result }
    $seen[$path.ToLowerInvariant()] = $true
  }
  if ([string](Get-LegacyValue $Baseline 'tree_sha256') -ne (Get-LegacyTreeHash -Entries $files)) { return [pscustomobject]$result }
  $result.Valid = $true
  $result.Reason = 'BASELINE_VALID'
  return [pscustomobject]$result
}

function New-HebriLegacyBaseline {
  param(
    [Parameter(Mandatory = $true)][string]$SourceRoot,
    [Parameter(Mandatory = $true)][string]$SourceVersion,
    [Parameter(Mandatory = $true)][string]$SourceRef,
    [string]$OutputPath = '',
    [string]$GeneratedAt = ''
  )
  if ($SourceVersion -notmatch '^[0-9]+[.][0-9]+[.][0-9]+$' -or [string]::IsNullOrWhiteSpace($SourceRef)) { throw 'BASELINE_UNVERIFIED: invalid baseline identity' }
  $inventory = @(Get-LegacyInventory -Root $SourceRoot)
  if ($inventory.Count -eq 0) { throw 'BASELINE_UNVERIFIED: baseline is empty' }
  $inventoryMap = @{}
  foreach ($item in $inventory) { $inventoryMap[$item.path.ToLowerInvariant()] = $item }
  $manifest = Get-LegacyManifestPaths -SourceRoot $SourceRoot
  if ($null -ne $manifest) {
    $files = @($manifest.Paths | Sort-Object | ForEach-Object {
      $key = $_.ToLowerInvariant()
      if (-not $inventoryMap.ContainsKey($key)) { throw "BASELINE_UNVERIFIED: manifest file missing: $_" }
      $item = $inventoryMap[$key]
      [pscustomobject][ordered]@{ path = $item.path; sha256 = $item.sha256; size = $item.size; class = Get-LegacyBaselineClass $item.path -ManifestDeclared }
    })
    $inventoryScope = 'release_manifest'
    $sourceManifestSha256 = Get-HebriFileSha256 $manifest.Path
  }
  else {
    $files = @($inventory | ForEach-Object {
      [pscustomobject][ordered]@{ path = $_.path; sha256 = $_.sha256; size = $_.size; class = Get-LegacyBaselineClass $_.path }
    })
    $inventoryScope = 'all_files'
    $sourceManifestSha256 = $null
  }
  if ([string]::IsNullOrWhiteSpace($GeneratedAt)) { $GeneratedAt = (Get-Date).ToUniversalTime().ToString('o') }
  else {
    $parsedGeneratedAt = [datetimeoffset]::MinValue
    if (-not [datetimeoffset]::TryParse($GeneratedAt, [ref]$parsedGeneratedAt)) { throw 'BASELINE_UNVERIFIED: invalid generated_at' }
    $GeneratedAt = $parsedGeneratedAt.ToUniversalTime().ToString('o')
  }
  $baseline = [pscustomobject][ordered]@{
    schema = 'hebrinex.legacy_migration_baseline'
    schema_version = 1
    source_version = $SourceVersion
    source_ref = $SourceRef
    generated_at = $GeneratedAt
    inventory_scope = $inventoryScope
    source_manifest_sha256 = $sourceManifestSha256
    tree_sha256 = Get-LegacyTreeHash -Entries $files
    files = $files
  }
  $check = Test-HebriLegacyBaseline -Baseline $baseline
  if (-not $check.Valid) { throw ($check.Reason + ': generated baseline rejected') }
  if (-not [string]::IsNullOrWhiteSpace($OutputPath)) { Write-HebriAtomicJsonDocument -Path (Get-LegacyFullPath $OutputPath) -Value $baseline }
  return $baseline
}

function Read-LegacyBaseline {
  param([string]$Path)
  $full = Get-LegacyFullPath $Path
  if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw 'LEGACY_VERSION_UNSUPPORTED: baseline file is missing' }
  $baseline = Read-HebriJsonDocument $full
  $check = Test-HebriLegacyBaseline -Baseline $baseline
  if (-not $check.Valid) { throw ($check.Reason + ': baseline document rejected') }
  return [pscustomobject]@{ Path = $full; Hash = Get-HebriFileSha256 $full; Value = $baseline }
}

function Get-LegacyDecisionMap {
  param([string]$Path)
  $map = @{}
  $hash = ''
  if ([string]::IsNullOrWhiteSpace($Path)) { return [pscustomobject]@{ Map = $map; Hash = $hash; Path = '' } }
  $full = Get-LegacyFullPath $Path
  if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw 'CONFLICT_DECISION_REQUIRED: decisions file is missing' }
  $value = Read-HebriJsonDocument $full
  if (-not (Test-LegacyClosedProperties -Value $value -Allowed @('schema','schema_version','decisions') -Required @('schema','schema_version','decisions')) -or
      [string](Get-LegacyValue $value 'schema') -ne 'hebrinex.legacy_migration_decisions' -or [int](Get-LegacyValue $value 'schema_version' 0) -ne 1) { throw 'CONFLICT_DECISION_REQUIRED: decisions document rejected' }
  foreach ($decision in @(Get-LegacyValue $value 'decisions' @())) {
    if (-not (Test-LegacyClosedProperties -Value $decision -Allowed @('path','action') -Required @('path','action'))) { throw 'CONFLICT_DECISION_REQUIRED: decision shape rejected' }
    $relative = [string](Get-LegacyValue $decision 'path')
    $action = [string](Get-LegacyValue $decision 'action')
    if (-not (Test-LegacySafeRelativePath $relative) -or $action -ne 'preserve' -or $map.ContainsKey($relative.ToLowerInvariant())) { throw 'CONFLICT_DECISION_REQUIRED: only one explicit preserve decision per safe path is accepted' }
    $map[$relative.ToLowerInvariant()] = $action
  }
  return [pscustomobject]@{ Map = $map; Hash = Get-HebriFileSha256 $full; Path = $full }
}

function New-LegacyResult {
  param([string]$Status, [string]$Reason, [int]$ExitCode, [bool]$Writes, [object]$Details, [string]$NextStep, [string]$ProjectId = '')
  if ($null -eq $Details) { $Details = [ordered]@{} }
  $value = [ordered]@{
    schema = 'hebrinex.project_service.result'; contract_version = $script:LegacyContractVersion; cli_api = $script:LegacyApi
    command = 'migrate'; status = $Status; reason = $Reason; exit_code = $ExitCode; writes_performed = $Writes
    observed_at = (Get-Date).ToUniversalTime().ToString('o'); details = $Details; next_step = $NextStep
  }
  if (-not [string]::IsNullOrWhiteSpace($ProjectId)) { $value.project_id = $ProjectId }
  return [pscustomobject]$value
}

function Get-LegacyStableId {
  param([string]$Prefix, [string]$Seed)
  return $Prefix + (Get-Sha256Hex $Seed).Substring(0, 32)
}

function Get-LegacyRuntimeVersion {
  param([string]$InstallRoot)
  $versionPath = Join-Path (Get-LegacyFullPath $InstallRoot) 'HARNESS_VERSION'
  if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) { throw 'RUNTIME_NOT_INSTALLED: HARNESS_VERSION is missing' }
  $version = [IO.File]::ReadAllText($versionPath).Trim()
  if ($version -ne $script:LegacyMinimumEngine) { throw 'RUNTIME_NOT_INSTALLED: P05 requires engine 0.17.1' }
  return $version
}

function Get-LegacyAvailableBytes {
  param([string]$Path)
  try { return [int64]([IO.DriveInfo]::new([IO.Path]::GetPathRoot((Get-LegacyFullPath $Path))).AvailableFreeSpace) }
  catch { throw 'INSUFFICIENT_SPACE: available space could not be verified' }
}

function Test-LegacyGitIgnore {
  param([string]$ProjectRoot)
  if (Test-Path -LiteralPath (Join-Path $ProjectRoot '.hebrinex-migration-fixture') -PathType Leaf) { return $true }
  $gitRoot = Join-Path $ProjectRoot '.git'
  if (-not (Test-Path -LiteralPath $gitRoot)) { return $true }
  $ignore = Join-Path $ProjectRoot '.gitignore'
  if (-not (Test-Path -LiteralPath $ignore -PathType Leaf)) { return $false }
  foreach ($line in [IO.File]::ReadAllLines($ignore)) {
    if ($line.Trim() -in @('.hebrinex-migration/','/.hebrinex-migration/','.hebrinex-migration','/.hebrinex-migration')) { return $true }
  }
  return $false
}

function Get-LegacyDocuments {
  param([string]$ProjectId, [string]$InstanceId, [string]$LegacyId, [string]$ProjectRoot, [string]$TargetVersion, [string]$SourceVersion, [string]$BaselineHash, [string]$SourceTreeHash, [string]$SnapshotPath, [string]$Timestamp)
  return [pscustomobject][ordered]@{
    binding = [ordered]@{
      schema = 'hebrinex.binding'; schema_version = 1; project_id = $ProjectId; instance_id = $InstanceId; project_root = $ProjectRoot
      layout = 'central_instance'; instance_relative_path = '.hebrinex/instance'; required_engine = [ordered]@{ api_line = '1'; minimum_engine_version = $script:LegacyMinimumEngine }
      state_schema_version = 1; last_verified_engine_version = $TargetVersion; created_at = $Timestamp; updated_at = $Timestamp
    }
    instance = [ordered]@{
      schema = 'hebrinex.project_instance'; schema_version = 1; project_id = $ProjectId; instance_id = $InstanceId
      lifecycle_state = 'pending'; state_schema_version = 1; created_at = $Timestamp; updated_at = $Timestamp
    }
    registration = [ordered]@{
      schema = 'hebrinex.project_registration'; schema_version = 1; project_id = $ProjectId; status = 'pending'
      catalog_entry_relative_path = "projects/$ProjectId.json"; updated_at = $Timestamp
    }
    catalog = [ordered]@{
      schema = 'hebrinex.project_catalog_entry'; schema_version = 1; project_id = $ProjectId; instance_id = $InstanceId
      project_root = $ProjectRoot; binding_schema_version = 1; state = 'active'; observed_at = $Timestamp; source = 'validated_binding'
    }
    origin = [ordered]@{
      schema = 'hebrinex.legacy_migration_origin'; schema_version = 1; project_id = $ProjectId; legacy_instance_id = $LegacyId
      source_version = $SourceVersion; target_version = $TargetVersion; baseline_sha256 = $BaselineHash; source_tree_sha256 = $SourceTreeHash
      snapshot_path = $SnapshotPath; migrated_at = $Timestamp
    }
  }
}

function Get-LegacyDestination {
  param([string]$Path, [string]$BaselineClass, [string]$Disposition)
  if ($Disposition -eq 'preserve') { return 'instance/legacy-preserved/' + ($Path -replace '\\','/') }
  if ($Disposition -ne 'instance_copy') { return '' }
  if ($Path -eq 'PROJECT_BINDING.yaml') { return '' }
  if (($Path -replace '\\','/').StartsWith('instance/')) { return ($Path -replace '\\','/') }
  $mapped = Get-HebriInstanceRelativePath -RelativePath $Path
  if ($mapped -eq ($Path -replace '\\','/')) { return 'instance/legacy-preserved/' + ($Path -replace '\\','/') }
  return $mapped
}

function New-HebriLegacyMigrationPlan {
  param(
    [Parameter(Mandatory = $true)][string]$InstallRoot,
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$CatalogRoot,
    [Parameter(Mandatory = $true)][string]$BaselinePath,
    [string]$DecisionsPath = '',
    [string]$SnapshotBase = '',
    [long]$AvailableBytesOverride = -1,
    [string]$FailurePoint = ''
  )
  $install = Get-LegacyFullPath $InstallRoot
  $project = Get-LegacyFullPath $ProjectRoot
  $catalog = Get-LegacyFullPath $CatalogRoot
  $targetVersion = Get-LegacyRuntimeVersion $install
  if (-not (Test-Path -LiteralPath $project -PathType Container)) { return New-LegacyResult blocked PROJECT_NOT_FOUND 3 $false ([ordered]@{ project_root = $project }) 'Corregir ProjectRoot y generar un plan nuevo.' }
  if ((Test-HebriPathContained -Root $install -Candidate $project) -or (Test-HebriPathContained -Root $project -Candidate $install) -or
      (Test-HebriPathContained -Root $catalog -Candidate $project) -or (Test-HebriPathContained -Root $project -Candidate $catalog)) { return New-LegacyResult blocked PATH_OUTSIDE_ROOT 3 $false ([ordered]@{}) 'InstallRoot, ProjectRoot y CatalogRoot no pueden solaparse.' }
  $legacyRoot = Join-Path $project '.hebrinex'
  if (-not (Test-Path -LiteralPath $legacyRoot -PathType Container)) { return New-LegacyResult blocked PROJECT_NOT_FOUND 3 $false ([ordered]@{ legacy_root = $legacyRoot }) 'No existe una copia legacy para migrar.' }
  if (Test-Path -LiteralPath (Join-Path $legacyRoot 'binding.json') -PathType Leaf) { return New-LegacyResult blocked PROJECT_ALREADY_BOUND 3 $false ([ordered]@{}) 'El proyecto ya contiene binding central.' }
  $legacyBindingPath = Join-Path $legacyRoot 'PROJECT_BINDING.yaml'
  if (-not (Test-Path -LiteralPath $legacyBindingPath -PathType Leaf)) { return New-LegacyResult blocked BINDING_SCHEMA_UNSUPPORTED 3 $false ([ordered]@{}) 'Falta PROJECT_BINDING.yaml legacy.' }
  $bindingText = [IO.File]::ReadAllText($legacyBindingPath)
  $sourceVersion = Get-Scalar -Text $bindingText -Key 'harness_version'
  $bindingMode = Get-Scalar -Text $bindingText -Key 'binding_mode'
  $boundRoot = Get-Scalar -Text $bindingText -Key 'project_root'
  $legacyId = Get-Scalar -Text $bindingText -Key 'harness_instance_id'
  if ($bindingMode -ne 'bound' -or [string]::IsNullOrWhiteSpace($legacyId) -or [string]::IsNullOrWhiteSpace($boundRoot) -or -not (Test-LegacyPathEqual $boundRoot $project)) { return New-LegacyResult blocked BINDING_SCHEMA_UNSUPPORTED 3 $false ([ordered]@{ source_version = $sourceVersion }) 'El binding legacy no coincide con el proyecto explicito.' }
  try { $baselineRecord = Read-LegacyBaseline $BaselinePath } catch { return New-LegacyResult blocked LEGACY_VERSION_UNSUPPORTED 3 $false ([ordered]@{ error = $_.Exception.Message; source_version = $sourceVersion }) 'Proveer un baseline local verificable para esta version.' }
  $baseline = $baselineRecord.Value
  if ([string]$baseline.source_version -ne $sourceVersion) { return New-LegacyResult blocked LEGACY_VERSION_UNSUPPORTED 3 $false ([ordered]@{ source_version = $sourceVersion; baseline_version = [string]$baseline.source_version }) 'El baseline no corresponde a la version legacy.' }
  try { $decisionRecord = Get-LegacyDecisionMap $DecisionsPath } catch { return New-LegacyResult blocked CONFLICT_DECISION_REQUIRED 3 $false ([ordered]@{ error = $_.Exception.Message }) 'Corregir las decisiones y generar un plan nuevo.' }
  try { $inventory = @(Get-LegacyInventory $legacyRoot) } catch { return New-LegacyResult blocked REPARSE_POINT_UNSUPPORTED 3 $false ([ordered]@{ error = $_.Exception.Message }) 'Retirar el reparse point mediante una operacion separada.' }
  if ($inventory.Count -eq 0) { return New-LegacyResult blocked BASELINE_UNVERIFIED 3 $false ([ordered]@{}) 'El consumidor legacy esta vacio.' }
  $baselineMap = @{}
  foreach ($item in @($baseline.files)) { $baselineMap[[string]$item.path.ToLowerInvariant()] = $item }
  $conflicts = New-Object System.Collections.Generic.List[object]
  $files = New-Object System.Collections.Generic.List[object]
  $destinations = @{}
  [int64]$requiredBytes = 131072
  foreach ($item in $inventory) {
    $path = [string]$item.path
    $key = $path.ToLowerInvariant()
    $baselineItem = if ($baselineMap.ContainsKey($key)) { $baselineMap[$key] } else { $null }
    $baseClass = if ($null -ne $baselineItem) { [string]$baselineItem.class } elseif (Test-LegacyPrivatePath $path) { 'personal' } else { 'unknown' }
    $classification = $baseClass
    $disposition = ''
    $baselineHash = if ($null -ne $baselineItem) { [string]$baselineItem.sha256 } else { '' }
    if (Test-LegacyPriorBackupPath $path) { $classification = 'generated'; $disposition = 'external_backup' }
    elseif ($baseClass -eq 'product') {
      if ($baselineHash -eq [string]$item.sha256) { $classification = 'intact'; $disposition = 'central_reference' }
      else {
        $classification = 'modified'
        if ($decisionRecord.Map.ContainsKey($key)) { $disposition = 'preserve' }
        else { [void]$conflicts.Add([pscustomobject][ordered]@{ path = $path; kind = 'modified_product'; legacy_sha256 = $item.sha256; baseline_sha256 = $baselineHash }); continue }
      }
    }
    elseif ($baseClass -eq 'instance') { $classification = 'local'; $disposition = if ($path -eq 'PROJECT_BINDING.yaml') { 'identity_record' } else { 'instance_copy' } }
    elseif ($baseClass -in @('personal','generated')) { $disposition = 'snapshot_only' }
    else { $classification = 'unknown'; $disposition = 'preserve' }
    $destination = Get-LegacyDestination -Path $path -BaselineClass $baseClass -Disposition $disposition
    if (-not [string]::IsNullOrWhiteSpace($destination)) {
      if (-not (Test-LegacySafeRelativePath $destination)) { [void]$conflicts.Add([pscustomobject][ordered]@{ path = $path; kind = 'unsafe_destination' }); continue }
      $destKey = $destination.ToLowerInvariant()
      if ($destinations.ContainsKey($destKey)) {
        if ([string]$destinations[$destKey].sha256 -ne [string]$item.sha256) { [void]$conflicts.Add([pscustomobject][ordered]@{ path = $path; kind = 'legacy_canonical_conflict'; destination = $destination }); continue }
        $disposition = 'deduplicated'
        $destination = ''
      }
      else {
        $destinations[$destKey] = $item
        $requiredBytes += [int64]$item.size
      }
    }
    $displayPath = if ($baseClass -eq 'personal' -or $disposition -eq 'external_backup') { '' } else { $path }
    [void]$files.Add([pscustomobject][ordered]@{
      path = $displayPath; path_token = if ([string]::IsNullOrWhiteSpace($displayPath)) { Get-Sha256Hex $path } else { '' }
      sha256 = [string]$item.sha256; size = [int64]$item.size; baseline_sha256 = $baselineHash
      classification = $classification; disposition = $disposition; destination = $destination
    })
  }
  if ($conflicts.Count -gt 0) {
    $reason = if (@($conflicts | Where-Object { $_.kind -eq 'legacy_canonical_conflict' }).Count -gt 0) { 'LEGACY_CANONICAL_CONFLICT' } else { 'CONFLICT_DECISION_REQUIRED' }
    return New-LegacyResult blocked $reason 3 $false ([ordered]@{ conflicts = $conflicts.ToArray(); source_tree_sha256 = Get-LegacyTreeHash $inventory }) 'Registrar decisiones preserve explicitas y generar un plan nuevo.'
  }
  if ([string]::IsNullOrWhiteSpace($SnapshotBase)) { $SnapshotBase = Join-Path $project '.hebrinex-migration' }
  $snapshotBaseFull = Get-LegacyFullPath $SnapshotBase
  if (-not (Test-HebriPathContained -Root $project -Candidate $snapshotBaseFull) -or (Test-HebriPathContained -Root $legacyRoot -Candidate $snapshotBaseFull) -or (Test-HebriPathContained -Root $snapshotBaseFull -Candidate $legacyRoot)) { return New-LegacyResult blocked PATH_OUTSIDE_ROOT 3 $false ([ordered]@{}) 'SnapshotBase debe estar dentro del proyecto y fuera de .hebrinex.' }
  $fixtureMode = Test-Path -LiteralPath (Join-Path $project '.hebrinex-migration-fixture') -PathType Leaf
  if (($AvailableBytesOverride -ge 0 -or -not [string]::IsNullOrWhiteSpace($FailurePoint)) -and -not $fixtureMode) { return New-LegacyResult blocked OPERATION_DESCRIPTOR_INVALID 3 $false ([ordered]@{}) 'Overrides de espacio y fallos estan reservados a fixtures aislados.' }
  if (-not (Test-LegacyGitIgnore $project)) { return New-LegacyResult blocked GITIGNORE_APPROVAL_REQUIRED 3 $false ([ordered]@{ snapshot_base = $snapshotBaseFull }) 'Autorizar primero la exclusion de .hebrinex-migration o elegir un fixture aislado.' }
  try { $availableBytes = if ($AvailableBytesOverride -ge 0) { $AvailableBytesOverride } else { Get-LegacyAvailableBytes $project } }
  catch { return New-LegacyResult blocked INSUFFICIENT_SPACE 3 $false ([ordered]@{ error = $_.Exception.Message; required_bytes = $requiredBytes }) 'Verificar permisos y espacio del volumen antes de generar otro plan.' }
  if ($availableBytes -lt $requiredBytes) { return New-LegacyResult blocked INSUFFICIENT_SPACE 3 $false ([ordered]@{ required_bytes = $requiredBytes; available_bytes = $availableBytes }) 'Liberar espacio y generar un plan nuevo.' }
  $operationId = 'OP-' + [guid]::NewGuid().ToString('N')
  $projectId = Get-LegacyStableId 'PRJ-' ('legacy-project:' + $legacyId)
  $instanceId = Get-LegacyStableId 'INST-' ('legacy-instance:' + $legacyId)
  $operationRoot = Join-Path $snapshotBaseFull $operationId
  $snapshotPath = Join-Path $operationRoot 'snapshot'
  $manifestPath = Join-Path $operationRoot 'snapshot-manifest.json'
  $priorBackupsPath = Join-Path $operationRoot 'prior-backups'
  $priorBackupsManifestPath = Join-Path $operationRoot 'prior-backups-manifest.json'
  $controlRoot = Join-Path $operationRoot 'control'
  $stageRoot = Join-Path $project ('.hebrinex-stage-' + $operationId)
  $catalogPath = Join-Path (Join-Path $catalog 'projects') ($projectId + '.json')
  $timestamp = (Get-Date).ToUniversalTime().ToString('o')
  $sourceTree = Get-LegacyTreeHash $inventory
  $snapshotInventory = @($inventory | Where-Object { -not (Test-LegacyPriorBackupPath ([string]$_.path)) })
  $priorBackupInventory = @($inventory | Where-Object { Test-LegacyPriorBackupPath ([string]$_.path) })
  $documents = Get-LegacyDocuments -ProjectId $projectId -InstanceId $instanceId -LegacyId $legacyId -ProjectRoot $project -TargetVersion $targetVersion -SourceVersion $sourceVersion -BaselineHash $baselineRecord.Hash -SourceTreeHash $sourceTree -SnapshotPath $snapshotPath -Timestamp $timestamp
  $plan = [pscustomobject][ordered]@{
    schema = 'hebrinex.legacy_migration_plan'; schema_version = 1; action = 'migrate'; project_id = $projectId; instance_id = $instanceId
    legacy_instance_id = $legacyId; source_version = $sourceVersion; target_version = $targetVersion; baseline_path = $baselineRecord.Path
    baseline_sha256 = $baselineRecord.Hash; baseline_source_ref = [string]$baseline.source_ref
    paths = [ordered]@{ legacy_root = $legacyRoot; stage_root = $stageRoot; operation_root = $operationRoot; control_root = $controlRoot; snapshot_path = $snapshotPath; snapshot_manifest_path = $manifestPath; prior_backups_path = $priorBackupsPath; prior_backups_manifest_path = $priorBackupsManifestPath; catalog_path = $catalogPath }
    source_tree_sha256 = $sourceTree; source_file_count = $inventory.Count
    snapshot_tree_sha256 = Get-LegacyTreeHash $snapshotInventory; snapshot_file_count = $snapshotInventory.Count
    prior_backup_tree_sha256 = Get-LegacyTreeHash $priorBackupInventory; prior_backup_file_count = $priorBackupInventory.Count
    space = [ordered]@{ required_bytes = $requiredBytes; available_bytes = $availableBytes }
    decisions_hash = $decisionRecord.Hash; files = $files.ToArray(); documents = $documents
    stages = @('validate_preconditions','acquire_lock','stage_instance','relocate_legacy_snapshot','separate_prior_backups','verify_snapshots','publish_instance','register_catalog','commit_journal')
    rollback = [ordered]@{ before_publication = 'restore_prior_backups_then_legacy_snapshot_and_remove_owned_stage'; after_publication = 'recovery_required_preserve_instance_and_snapshots'; deletes_backups = $false }
    approval = [ordered]@{ required = $true; type = 'APR2'; bound_to = 'descriptor_hash'; single_use = $true }
    fixture_mode = $fixtureMode; failure_point = $FailurePoint
  }
  $context = [pscustomobject]@{ install_root = $install; project_root = $project; instance_root = $controlRoot; catalog_root = $catalog; project_id = $projectId }
  $writeSet = @($legacyRoot,$stageRoot,$snapshotPath,$manifestPath,$priorBackupsPath,$priorBackupsManifestPath,$catalogPath)
  $descriptor = New-HebriOperationDescriptor -Context $context -Operation 'project:migrate' -WriteSet $writeSet -CodeVersion $script:LegacyCodeVersion -Plan $plan -OperationId $operationId
  $check = Test-HebriLegacyMigrationDescriptor $descriptor
  if (-not $check.Valid) { return New-LegacyResult blocked $check.Reason 3 $false ([ordered]@{}) 'Corregir el plan rechazado.' }
  return New-LegacyResult planned MIGRATION_PLAN_READY 0 $false ([ordered]@{ descriptor = $descriptor; classifications = [ordered]@{ intact = @($files | Where-Object classification -eq 'intact').Count; modified = @($files | Where-Object classification -eq 'modified').Count; local = @($files | Where-Object classification -eq 'local').Count; unknown = @($files | Where-Object classification -eq 'unknown').Count; personal = @($files | Where-Object classification -eq 'personal').Count; generated = @($files | Where-Object classification -eq 'generated').Count }; baseline_source_ref = [string]$baseline.source_ref }) 'Revisar descriptor, obtener SI y materializar una aprobacion APR2.' $projectId
}

function Test-LegacyExactPaths {
  param([object[]]$Actual, [object[]]$Expected)
  $a = @($Actual | ForEach-Object { (Get-LegacyFullPath ([string]$_)).ToLowerInvariant() } | Sort-Object -Unique)
  $e = @($Expected | ForEach-Object { (Get-LegacyFullPath ([string]$_)).ToLowerInvariant() } | Sort-Object -Unique)
  if ($a.Count -ne $e.Count) { return $false }
  for ($i = 0; $i -lt $a.Count; $i++) { if ($a[$i] -ne $e[$i]) { return $false } }
  return $true
}

function Test-LegacyCatalogDocument {
  param([object]$Document, [string]$ProjectId, [string]$InstanceId, [string]$ProjectRoot, [string]$ExpectedState)
  $properties = @('schema','schema_version','project_id','instance_id','project_root','binding_schema_version','state','observed_at','source')
  return ((Test-LegacyClosedProperties -Value $Document -Allowed $properties -Required $properties) -and
    [string](Get-LegacyValue $Document 'schema') -eq 'hebrinex.project_catalog_entry' -and [int](Get-LegacyValue $Document 'schema_version' 0) -eq 1 -and
    [string](Get-LegacyValue $Document 'project_id') -eq $ProjectId -and [string](Get-LegacyValue $Document 'instance_id') -eq $InstanceId -and
    (Test-LegacyPathEqual ([string](Get-LegacyValue $Document 'project_root')) $ProjectRoot) -and [int](Get-LegacyValue $Document 'binding_schema_version' 0) -eq 1 -and
    [string](Get-LegacyValue $Document 'state') -eq $ExpectedState -and [string](Get-LegacyValue $Document 'source') -eq 'validated_binding')
}

function Test-LegacyMigrationDocuments {
  param([object]$Documents, [string]$ProjectId, [string]$InstanceId, [string]$LegacyId, [string]$ProjectRoot, [string]$SourceVersion, [string]$TargetVersion, [string]$BaselineHash, [string]$SourceTreeHash, [string]$SnapshotPath)
  if (-not (Test-LegacyClosedProperties -Value $Documents -Allowed @('binding','instance','registration','catalog','origin') -Required @('binding','instance','registration','catalog','origin'))) { return $false }
  $binding = Get-LegacyValue $Documents 'binding'
  $bindingProperties = @('schema','schema_version','project_id','instance_id','project_root','layout','instance_relative_path','required_engine','state_schema_version','last_verified_engine_version','created_at','updated_at')
  if (-not (Test-LegacyClosedProperties -Value $binding -Allowed $bindingProperties -Required $bindingProperties) -or
      [string](Get-LegacyValue $binding 'schema') -ne 'hebrinex.binding' -or [int](Get-LegacyValue $binding 'schema_version' 0) -ne 1 -or
      [string](Get-LegacyValue $binding 'project_id') -ne $ProjectId -or [string](Get-LegacyValue $binding 'instance_id') -ne $InstanceId -or
      -not (Test-LegacyPathEqual ([string](Get-LegacyValue $binding 'project_root')) $ProjectRoot) -or [string](Get-LegacyValue $binding 'layout') -ne 'central_instance' -or
      [string](Get-LegacyValue $binding 'instance_relative_path') -ne '.hebrinex/instance' -or [int](Get-LegacyValue $binding 'state_schema_version' 0) -ne 1 -or
      [string](Get-LegacyValue $binding 'last_verified_engine_version') -ne $TargetVersion) { return $false }
  $engine = Get-LegacyValue $binding 'required_engine'
  if (-not (Test-LegacyClosedProperties -Value $engine -Allowed @('api_line','minimum_engine_version') -Required @('api_line','minimum_engine_version')) -or
      [string](Get-LegacyValue $engine 'api_line') -ne '1' -or [string](Get-LegacyValue $engine 'minimum_engine_version') -ne $script:LegacyMinimumEngine) { return $false }
  $instance = Get-LegacyValue $Documents 'instance'
  $instanceProperties = @('schema','schema_version','project_id','instance_id','lifecycle_state','state_schema_version','created_at','updated_at')
  if (-not (Test-LegacyClosedProperties -Value $instance -Allowed $instanceProperties -Required $instanceProperties) -or
      [string](Get-LegacyValue $instance 'schema') -ne 'hebrinex.project_instance' -or [string](Get-LegacyValue $instance 'project_id') -ne $ProjectId -or
      [string](Get-LegacyValue $instance 'instance_id') -ne $InstanceId -or [string](Get-LegacyValue $instance 'lifecycle_state') -ne 'pending') { return $false }
  $registration = Get-LegacyValue $Documents 'registration'
  $registrationProperties = @('schema','schema_version','project_id','status','catalog_entry_relative_path','updated_at')
  if (-not (Test-LegacyClosedProperties -Value $registration -Allowed $registrationProperties -Required $registrationProperties) -or
      [string](Get-LegacyValue $registration 'schema') -ne 'hebrinex.project_registration' -or [string](Get-LegacyValue $registration 'project_id') -ne $ProjectId -or
      [string](Get-LegacyValue $registration 'status') -ne 'pending' -or [string](Get-LegacyValue $registration 'catalog_entry_relative_path') -ne "projects/$ProjectId.json") { return $false }
  if (-not (Test-LegacyCatalogDocument -Document (Get-LegacyValue $Documents 'catalog') -ProjectId $ProjectId -InstanceId $InstanceId -ProjectRoot $ProjectRoot -ExpectedState active)) { return $false }
  $origin = Get-LegacyValue $Documents 'origin'
  $originProperties = @('schema','schema_version','project_id','legacy_instance_id','source_version','target_version','baseline_sha256','source_tree_sha256','snapshot_path','migrated_at')
  return ((Test-LegacyClosedProperties -Value $origin -Allowed $originProperties -Required $originProperties) -and
    [string](Get-LegacyValue $origin 'schema') -eq 'hebrinex.legacy_migration_origin' -and [string](Get-LegacyValue $origin 'project_id') -eq $ProjectId -and
    [string](Get-LegacyValue $origin 'legacy_instance_id') -eq $LegacyId -and [string](Get-LegacyValue $origin 'source_version') -eq $SourceVersion -and
    [string](Get-LegacyValue $origin 'target_version') -eq $TargetVersion -and [string](Get-LegacyValue $origin 'baseline_sha256') -eq $BaselineHash -and
    [string](Get-LegacyValue $origin 'source_tree_sha256') -eq $SourceTreeHash -and (Test-LegacyPathEqual ([string](Get-LegacyValue $origin 'snapshot_path')) $SnapshotPath))
}

function Test-HebriLegacyMigrationDescriptor {
  param([Parameter(Mandatory = $true)][object]$Descriptor)
  $result = [ordered]@{ Valid = $false; Reason = 'OPERATION_DESCRIPTOR_INVALID' }
  $common = Test-HebriOperationDescriptor $Descriptor
  if (-not $common.Valid) { $result.Reason = $common.Reason; return [pscustomobject]$result }
  if ([string]$Descriptor.code_version -ne $script:LegacyCodeVersion) { $result.Reason = 'APPROVAL_SCOPE_MISMATCH'; return [pscustomobject]$result }
  $plan = $Descriptor.plan
  $action = [string](Get-LegacyValue $plan 'action')
  if ([string](Get-LegacyValue $plan 'schema') -ne 'hebrinex.legacy_migration_plan' -or [int](Get-LegacyValue $plan 'schema_version' 0) -ne 1 -or $action -notin @('migrate','restore')) { return [pscustomobject]$result }
  $migrateProperties = @('schema','schema_version','action','project_id','instance_id','legacy_instance_id','source_version','target_version','baseline_path','baseline_sha256','baseline_source_ref','paths','source_tree_sha256','source_file_count','snapshot_tree_sha256','snapshot_file_count','prior_backup_tree_sha256','prior_backup_file_count','space','decisions_hash','files','documents','stages','rollback','approval','fixture_mode','failure_point')
  $restoreProperties = @('schema','schema_version','action','project_id','instance_id','source_version','target_version','snapshot_manifest_sha256','paths','source_tree_sha256','source_file_count','space','files','documents','preserve_post_migration_changes','stages','rollback','approval','fixture_mode','failure_point')
  $planProperties = if ($action -eq 'migrate') { $migrateProperties } else { $restoreProperties }
  if (-not (Test-LegacyClosedProperties -Value $plan -Allowed $planProperties -Required $planProperties)) { return [pscustomobject]$result }
  $projectId = [string](Get-LegacyValue $plan 'project_id')
  $instanceId = [string](Get-LegacyValue $plan 'instance_id')
  if ($projectId -ne [string]$Descriptor.project_id -or $projectId -notmatch '^PRJ-[a-f0-9]{32}$' -or $instanceId -notmatch '^INST-[a-f0-9]{32}$') { $result.Reason = 'BINDING_SCHEMA_UNSUPPORTED'; return [pscustomobject]$result }
  if ([string](Get-LegacyValue $plan 'source_version') -notmatch '^[0-9]+[.][0-9]+[.][0-9]+$' -or [string](Get-LegacyValue $plan 'target_version') -notmatch '^[0-9]+[.][0-9]+[.][0-9]+$' -or
      (Get-LegacyValue $plan 'fixture_mode') -isnot [bool] -or (Get-LegacyValue $plan 'failure_point') -isnot [string] -or [string]$Descriptor.operation_id -notmatch '^OP-[a-f0-9]{32}$') { return [pscustomobject]$result }
  $expectedOperation = if ($action -eq 'migrate') { 'project:migrate' } else { 'project:restore-legacy' }
  if ([string]$Descriptor.operation -ne $expectedOperation) { $result.Reason = 'APPROVAL_SCOPE_MISMATCH'; return [pscustomobject]$result }
  $paths = Get-LegacyValue $plan 'paths'
  $requiredPaths = if ($action -eq 'migrate') { @('legacy_root','stage_root','operation_root','control_root','snapshot_path','snapshot_manifest_path','prior_backups_path','prior_backups_manifest_path','catalog_path') } else { @('legacy_root','stage_root','operation_root','control_root','snapshot_path','snapshot_manifest_path','preserved_root','catalog_path') }
  if (-not (Test-LegacyClosedProperties -Value $paths -Allowed $requiredPaths -Required $requiredPaths)) { return [pscustomobject]$result }
  foreach ($name in $requiredPaths) { if ([string]::IsNullOrWhiteSpace([string](Get-LegacyValue $paths $name))) { return [pscustomobject]$result } }
  $projectRoot = [string]$Descriptor.roots.project_root
  $catalogRoot = [string]$Descriptor.roots.catalog_root
  $expectedLegacyRoot = Join-Path $projectRoot '.hebrinex'
  $expectedStageRoot = Join-Path $projectRoot $(if ($action -eq 'migrate') { '.hebrinex-stage-' + [string]$Descriptor.operation_id } else { '.hebrinex-restore-stage-' + [string]$Descriptor.operation_id })
  $expectedCatalogPath = Join-Path (Join-Path $catalogRoot 'projects') ($projectId + '.json')
  if (-not (Test-LegacyPathEqual ([string]$paths.legacy_root) $expectedLegacyRoot) -or -not (Test-LegacyPathEqual ([string]$paths.stage_root) $expectedStageRoot) -or
      -not (Test-LegacyPathEqual ([string]$paths.control_root) (Join-Path ([string]$paths.operation_root) 'control')) -or
      -not (Test-LegacyPathEqual ([string]$paths.catalog_path) $expectedCatalogPath) -or
      -not (Test-LegacyPathEqual ([string]$Descriptor.roots.project_root) (Split-Path -Parent ([string]$paths.legacy_root))) -or
      -not (Test-LegacyPathEqual ([string]$Descriptor.roots.instance_root) ([string]$paths.control_root)) -or
      -not (Test-HebriPathContained -Root ([string]$Descriptor.roots.project_root) -Candidate ([string]$paths.stage_root)) -or
      -not (Test-HebriPathContained -Root ([string]$Descriptor.roots.project_root) -Candidate ([string]$paths.operation_root)) -or
      -not (Test-HebriPathContained -Root ([string]$Descriptor.roots.catalog_root) -Candidate ([string]$paths.catalog_path))) { $result.Reason = 'PATH_OUTSIDE_ROOT'; return [pscustomobject]$result }
  if ($action -eq 'migrate') {
    if (-not (Test-LegacyPathEqual ([string]$paths.snapshot_path) (Join-Path ([string]$paths.operation_root) 'snapshot')) -or
        -not (Test-LegacyPathEqual ([string]$paths.snapshot_manifest_path) (Join-Path ([string]$paths.operation_root) 'snapshot-manifest.json')) -or
        -not (Test-LegacyPathEqual ([string]$paths.prior_backups_path) (Join-Path ([string]$paths.operation_root) 'prior-backups')) -or
        -not (Test-LegacyPathEqual ([string]$paths.prior_backups_manifest_path) (Join-Path ([string]$paths.operation_root) 'prior-backups-manifest.json'))) { $result.Reason = 'PATH_OUTSIDE_ROOT'; return [pscustomobject]$result }
  }
  else {
    if (-not (Test-LegacyPathEqual ([string]$paths.snapshot_manifest_path) (Join-Path (Split-Path -Parent ([string]$paths.snapshot_path)) 'snapshot-manifest.json')) -or
        -not (Test-LegacyPathEqual ([string]$paths.preserved_root) (Join-Path ([string]$paths.operation_root) 'post-migration-preserved'))) { $result.Reason = 'PATH_OUTSIDE_ROOT'; return [pscustomobject]$result }
  }
  $expectedWrites = if ($action -eq 'migrate') { @($paths.legacy_root,$paths.stage_root,$paths.snapshot_path,$paths.snapshot_manifest_path,$paths.prior_backups_path,$paths.prior_backups_manifest_path,$paths.catalog_path) } else { @($paths.legacy_root,$paths.stage_root,$paths.preserved_root,$paths.catalog_path) }
  if (-not (Test-LegacyExactPaths -Actual @($Descriptor.write_set) -Expected $expectedWrites)) { $result.Reason = 'APPROVAL_SCOPE_MISMATCH'; return [pscustomobject]$result }
  $fixtureMode = [bool](Get-LegacyValue $plan 'fixture_mode')
  $failurePoint = [string](Get-LegacyValue $plan 'failure_point')
  $actualFixtureMode = Test-Path -LiteralPath (Join-Path $projectRoot '.hebrinex-migration-fixture') -PathType Leaf
  $allowedFailures = if ($action -eq 'migrate') { @('','during_staging','after_snapshot','before_publish','after_publish','catalog') } else { @('','before_publish','after_preserve','after_publish') }
  if ($fixtureMode -ne $actualFixtureMode -or $allowedFailures -notcontains $failurePoint -or (-not $fixtureMode -and -not [string]::IsNullOrWhiteSpace($failurePoint))) { return [pscustomobject]$result }
  $space = Get-LegacyValue $plan 'space'
  if (-not (Test-LegacyClosedProperties -Value $space -Allowed @('required_bytes','available_bytes') -Required @('required_bytes','available_bytes')) -or
      [int64](Get-LegacyValue $space 'required_bytes' -1) -lt 0 -or [int64](Get-LegacyValue $space 'available_bytes' -1) -lt [int64](Get-LegacyValue $space 'required_bytes' 0)) { return [pscustomobject]$result }
  $expectedStages = if ($action -eq 'migrate') { @('validate_preconditions','acquire_lock','stage_instance','relocate_legacy_snapshot','separate_prior_backups','verify_snapshots','publish_instance','register_catalog','commit_journal') } else { @('validate_preconditions','acquire_lock','stage_snapshot','preserve_current_instance','publish_legacy_snapshot','update_catalog','commit_journal') }
  $actualStages = @(Get-LegacyValue $plan 'stages' @())
  if ($actualStages.Count -ne $expectedStages.Count) { return [pscustomobject]$result }
  for ($stageIndex = 0; $stageIndex -lt $expectedStages.Count; $stageIndex++) { if ([string]$actualStages[$stageIndex] -ne $expectedStages[$stageIndex]) { return [pscustomobject]$result } }
  $rollback = Get-LegacyValue $plan 'rollback'
  $approval = Get-LegacyValue $plan 'approval'
  if (-not (Test-LegacyClosedProperties -Value $rollback -Allowed @('before_publication','after_publication','deletes_backups') -Required @('before_publication','after_publication','deletes_backups')) -or
      [string]::IsNullOrWhiteSpace([string](Get-LegacyValue $rollback 'before_publication')) -or [string]::IsNullOrWhiteSpace([string](Get-LegacyValue $rollback 'after_publication')) -or (Get-LegacyValue $rollback 'deletes_backups') -ne $false -or
      -not (Test-LegacyClosedProperties -Value $approval -Allowed @('required','type','bound_to','single_use') -Required @('required','type','bound_to','single_use')) -or
      (Get-LegacyValue $approval 'required') -ne $true -or [string](Get-LegacyValue $approval 'type') -ne 'APR2' -or [string](Get-LegacyValue $approval 'bound_to') -ne 'descriptor_hash' -or (Get-LegacyValue $approval 'single_use') -ne $true) { return [pscustomobject]$result }
  $files = @(Get-LegacyValue $plan 'files' @())
  $seenFiles = @{}
  foreach ($file in $files) {
    $allowedFileProperties = if ($action -eq 'migrate') { @('path','path_token','sha256','size','baseline_sha256','classification','disposition','destination') } else { @('path','sha256','size') }
    if (-not (Test-LegacyClosedProperties -Value $file -Allowed $allowedFileProperties -Required $allowedFileProperties)) { return [pscustomobject]$result }
    $filePath = [string](Get-LegacyValue $file 'path')
    $fileHash = [string](Get-LegacyValue $file 'sha256')
    if ($fileHash -notmatch '^[a-f0-9]{64}$' -or [int64](Get-LegacyValue $file 'size' -1) -lt 0) { return [pscustomobject]$result }
    if ($action -eq 'migrate') {
      $classification = [string](Get-LegacyValue $file 'classification')
      $disposition = [string](Get-LegacyValue $file 'disposition')
      $destination = [string](Get-LegacyValue $file 'destination')
      $token = [string](Get-LegacyValue $file 'path_token')
      $baselineHash = [string](Get-LegacyValue $file 'baseline_sha256')
      if ($classification -notin @('intact','modified','local','unknown','personal','generated') -or $disposition -notin @('central_reference','identity_record','instance_copy','preserve','snapshot_only','deduplicated','external_backup') -or
          ($baselineHash -ne '' -and $baselineHash -notmatch '^[a-f0-9]{64}$') -or ($destination -ne '' -and -not (Test-LegacySafeRelativePath $destination))) { return [pscustomobject]$result }
      if ($classification -eq 'personal') {
        if ($filePath -ne '' -or $token -notmatch '^[a-f0-9]{64}$' -or $disposition -ne 'snapshot_only' -or $destination -ne '') { return [pscustomobject]$result }
      }
      elseif ($classification -eq 'generated' -and $disposition -eq 'external_backup') {
        if ($filePath -ne '' -or $token -notmatch '^[a-f0-9]{64}$' -or $destination -ne '') { return [pscustomobject]$result }
      }
      elseif (-not (Test-LegacySafeRelativePath $filePath) -or $token -ne '') { return [pscustomobject]$result }
      if (($disposition -in @('instance_copy','preserve')) -ne (-not [string]::IsNullOrWhiteSpace($destination))) { return [pscustomobject]$result }
      $classificationValid = switch ($classification) {
        'intact' { $disposition -eq 'central_reference' -and $destination -eq '' -and $baselineHash -match '^[a-f0-9]{64}$' }
        'modified' { $disposition -eq 'preserve' -and $baselineHash -match '^[a-f0-9]{64}$' }
        'local' { ($disposition -in @('identity_record','instance_copy','deduplicated')) -and $baselineHash -match '^[a-f0-9]{64}$' }
        'unknown' { $disposition -eq 'preserve' -and $baselineHash -eq '' }
        'personal' { $disposition -eq 'snapshot_only' }
        'generated' { $disposition -in @('snapshot_only','external_backup') -and $destination -eq '' }
        default { $false }
      }
      if (-not $classificationValid) { return [pscustomobject]$result }
      if ($classification -eq 'local' -and $disposition -eq 'identity_record' -and ($filePath -ne 'PROJECT_BINDING.yaml' -or $destination -ne '')) { return [pscustomobject]$result }
    }
    elseif (-not (Test-LegacySafeRelativePath $filePath)) { return [pscustomobject]$result }
    $identity = if ([string]::IsNullOrWhiteSpace($filePath)) { 'private:' + [string](Get-LegacyValue $file 'path_token') } else { $filePath.ToLowerInvariant() }
    if ($seenFiles.ContainsKey($identity)) { return [pscustomobject]$result }
    $seenFiles[$identity] = $true
  }
  if ($files.Count -lt 1 -or $files.Count -ne [int](Get-LegacyValue $plan 'source_file_count' 0) -or [string](Get-LegacyValue $plan 'source_tree_sha256') -notmatch '^[a-f0-9]{64}$') { return [pscustomobject]$result }
  $documents = Get-LegacyValue $plan 'documents'
  if ($action -eq 'migrate') {
    if ([string](Get-LegacyValue $plan 'legacy_instance_id') -eq '' -or [string](Get-LegacyValue $plan 'baseline_sha256') -notmatch '^[a-f0-9]{64}$' -or
        [string](Get-LegacyValue $plan 'snapshot_tree_sha256') -notmatch '^[a-f0-9]{64}$' -or [int](Get-LegacyValue $plan 'snapshot_file_count' -1) -lt 1 -or
        [string](Get-LegacyValue $plan 'prior_backup_tree_sha256') -notmatch '^[a-f0-9]{64}$' -or [int](Get-LegacyValue $plan 'prior_backup_file_count' -1) -lt 0 -or
        ([int](Get-LegacyValue $plan 'snapshot_file_count' 0) + [int](Get-LegacyValue $plan 'prior_backup_file_count' 0)) -ne [int](Get-LegacyValue $plan 'source_file_count' 0) -or
        ([string](Get-LegacyValue $plan 'decisions_hash') -ne '' -and [string](Get-LegacyValue $plan 'decisions_hash') -notmatch '^[a-f0-9]{64}$') -or
        -not (Test-LegacyMigrationDocuments -Documents $documents -ProjectId $projectId -InstanceId $instanceId -LegacyId ([string](Get-LegacyValue $plan 'legacy_instance_id')) -ProjectRoot $projectRoot -SourceVersion ([string](Get-LegacyValue $plan 'source_version')) -TargetVersion ([string](Get-LegacyValue $plan 'target_version')) -BaselineHash ([string](Get-LegacyValue $plan 'baseline_sha256')) -SourceTreeHash ([string](Get-LegacyValue $plan 'source_tree_sha256')) -SnapshotPath ([string]$paths.snapshot_path))) { $result.Reason = 'BASELINE_UNVERIFIED'; return [pscustomobject]$result }
    try {
      $baselinePath = Get-LegacyFullPath ([string](Get-LegacyValue $plan 'baseline_path'))
      if ((Get-HebriFileSha256 $baselinePath) -ne [string](Get-LegacyValue $plan 'baseline_sha256')) { $result.Reason = 'BASELINE_UNVERIFIED'; return [pscustomobject]$result }
    }
    catch { $result.Reason = 'BASELINE_UNVERIFIED'; return [pscustomobject]$result }
  }
  else {
    if ([string](Get-LegacyValue $plan 'snapshot_manifest_sha256') -notmatch '^[a-f0-9]{64}$' -or (Get-LegacyValue $plan 'preserve_post_migration_changes') -isnot [bool] -or
        -not (Test-LegacyClosedProperties -Value $documents -Allowed @('catalog') -Required @('catalog')) -or
        -not (Test-LegacyCatalogDocument -Document (Get-LegacyValue $documents 'catalog') -ProjectId $projectId -InstanceId $instanceId -ProjectRoot $projectRoot -ExpectedState unbound)) { $result.Reason = 'BACKUP_INTEGRITY_FAILED'; return [pscustomobject]$result }
  }
  $result.Valid = $true
  $result.Reason = 'MIGRATION_DESCRIPTOR_VALID'
  return [pscustomobject]$result
}

function Test-LegacyPreconditions {
  param([object]$Descriptor)
  foreach ($precondition in @($Descriptor.preconditions)) {
    if ([string]$precondition.sha256 -ne (Get-HebriFileSha256 ([string]$precondition.path))) { throw 'DRIFT_AFTER_PLAN: write target changed after planning' }
  }
}

function Set-LegacyApprovalConsumed {
  param([object]$Descriptor, [string]$ApprovalId, [string]$ApprovalStoreRoot = '')
  $check = Test-HebriScopedApproval -Descriptor $Descriptor -ApprovalId $ApprovalId -StoreRoot $ApprovalStoreRoot
  if (-not $check.Valid) { throw ($check.Reason + ': only a valid approval can be consumed') }
  $approval = Read-HebriJsonDocument $check.Path
  $approval.status = 'consumed'
  $approval | Add-Member -NotePropertyName consumed_at -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('o')) -Force
  Write-HebriAtomicJsonDocument -Path $check.Path -Value $approval
}

function Write-LegacyJson {
  param([string]$Path, [object]$Value)
  Write-HebriAtomicJsonDocument -Path $Path -Value $Value
}

function Copy-LegacyFile {
  param([string]$SourceRoot, [string]$RelativePath, [string]$DestinationRoot, [string]$DestinationRelative, [string]$ExpectedHash)
  if (-not (Test-LegacySafeRelativePath $RelativePath) -or -not (Test-LegacySafeRelativePath $DestinationRelative)) { throw 'PATH_OUTSIDE_ROOT: unsafe copy path' }
  $source = [IO.Path]::GetFullPath((Join-Path $SourceRoot ($RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)))
  $destination = [IO.Path]::GetFullPath((Join-Path $DestinationRoot ($DestinationRelative -replace '/', [IO.Path]::DirectorySeparatorChar)))
  if (-not (Test-HebriPathContained -Root $SourceRoot -Candidate $source) -or -not (Test-HebriPathContained -Root $DestinationRoot -Candidate $destination)) { throw 'PATH_OUTSIDE_ROOT: copy escaped declared roots' }
  if ((Get-HebriFileSha256 $source) -ne $ExpectedHash) { throw 'DRIFT_AFTER_PLAN: source file changed during staging' }
  [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
  if (Test-Path -LiteralPath $destination) { throw 'LEGACY_CANONICAL_CONFLICT: duplicate stage destination' }
  [IO.File]::Copy($source, $destination, $false)
  if ((Get-HebriFileSha256 $destination) -ne $ExpectedHash) { throw 'BACKUP_INTEGRITY_FAILED: staged copy hash mismatch' }
}

function New-LegacyMigrationStage {
  param([object]$Plan)
  $paths = $Plan.paths
  $stage = [string]$paths.stage_root
  if (Test-Path -LiteralPath $stage) { throw 'DRIFT_AFTER_PLAN: stage path already exists' }
  [void][IO.Directory]::CreateDirectory((Join-Path $stage 'instance/migration'))
  Write-LegacyJson (Join-Path $stage 'binding.json') $Plan.documents.binding
  Write-LegacyJson (Join-Path $stage 'instance/project-instance.json') $Plan.documents.instance
  Write-LegacyJson (Join-Path $stage 'instance/registration.json') $Plan.documents.registration
  Write-LegacyJson (Join-Path $stage 'instance/migration/legacy-origin.json') $Plan.documents.origin
  foreach ($item in @($Plan.files)) {
    if ([string]$item.disposition -notin @('instance_copy','preserve') -or [string]::IsNullOrWhiteSpace([string]$item.destination)) { continue }
    Copy-LegacyFile -SourceRoot ([string]$paths.legacy_root) -RelativePath ([string]$item.path) -DestinationRoot $stage -DestinationRelative ([string]$item.destination) -ExpectedHash ([string]$item.sha256)
  }
  $inventory = @(Get-LegacyInventory $stage)
  return [pscustomobject]@{ Hash = Get-LegacyTreeHash $inventory; Inventory = $inventory }
}

function Move-LegacyPriorBackupTrees {
  param([string]$SnapshotRoot, [string]$PriorBackupsRoot)
  $moved = 0
  foreach ($relative in @('orquestador/migration/backups','instance/migration/backups')) {
    $source = Join-Path $SnapshotRoot ($relative -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $source -PathType Container)) { continue }
    $destination = Join-Path $PriorBackupsRoot ($relative -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (Test-Path -LiteralPath $destination) { throw 'DRIFT_AFTER_PLAN: prior backup destination already exists' }
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
    [IO.Directory]::Move($source, $destination)
    $moved++
  }
  return $moved
}

function Restore-LegacyPriorBackupTrees {
  param([string]$SnapshotRoot, [string]$PriorBackupsRoot)
  foreach ($relative in @('orquestador/migration/backups','instance/migration/backups')) {
    $source = Join-Path $PriorBackupsRoot ($relative -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $source -PathType Container)) { continue }
    $destination = Join-Path $SnapshotRoot ($relative -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (Test-Path -LiteralPath $destination) { throw 'MIGRATION_RECOVERY_REQUIRED: backup rollback destination already exists' }
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
    [IO.Directory]::Move($source, $destination)
  }
}

function Invoke-LegacyFailurePoint {
  param([object]$Plan, [string]$Point)
  if ([string](Get-LegacyValue $Plan 'failure_point') -ne $Point) { return }
  if (-not [bool](Get-LegacyValue $Plan 'fixture_mode' $false) -or -not (Test-Path -LiteralPath (Join-Path (Split-Path -Parent ([string]$Plan.paths.legacy_root)) '.hebrinex-migration-fixture') -PathType Leaf)) { throw 'RECOVERY_REQUIRED: failure injection is restricted to fixtures' }
  throw ('MIGRATION_FIXTURE_FAILURE: ' + $Point)
}

function Remove-LegacyOwnedStage {
  param([string]$Path, [string]$ExpectedHash)
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $true }
  if ([string]::IsNullOrWhiteSpace($ExpectedHash)) { return $false }
  $inventory = @(Get-LegacyInventory $Path)
  if ((Get-LegacyTreeHash $inventory) -ne $ExpectedHash) { return $false }
  [IO.Directory]::Delete($Path, $true)
  return $true
}

function Invoke-HebriLegacyMigrationOperation {
  param([Parameter(Mandatory = $true)][object]$Descriptor, [Parameter(Mandatory = $true)][string]$ApprovalId, [string]$ApprovalStoreRoot = '')
  $check = Test-HebriLegacyMigrationDescriptor $Descriptor
  if (-not $check.Valid) { return New-LegacyResult blocked $check.Reason 3 $false ([ordered]@{}) 'Generar un descriptor nuevo.' ([string]$Descriptor.project_id) }
  if ([string]$Descriptor.plan.action -eq 'restore') { return Invoke-HebriLegacyRestoreOperation -Descriptor $Descriptor -ApprovalId $ApprovalId -ApprovalStoreRoot $ApprovalStoreRoot }
  $plan = $Descriptor.plan
  $paths = $plan.paths
  $lock = $null
  $journal = $null
  $stageHash = ''
  $writes = $false
  $snapshotMoved = $false
  $published = $false
  try {
    $approval = Test-HebriScopedApproval -Descriptor $Descriptor -ApprovalId $ApprovalId -StoreRoot $ApprovalStoreRoot
    if (-not $approval.Valid) { throw ($approval.Reason + ': scoped approval rejected') }
    $baseline = Read-LegacyBaseline ([string]$plan.baseline_path)
    if ($baseline.Hash -ne [string]$plan.baseline_sha256 -or [string]$baseline.Value.source_version -ne [string]$plan.source_version) { throw 'BASELINE_UNVERIFIED: baseline changed after planning' }
    Test-LegacyPreconditions $Descriptor
    $sourceInventory = @(Get-LegacyInventory ([string]$paths.legacy_root))
    if ($sourceInventory.Count -ne [int]$plan.source_file_count -or (Get-LegacyTreeHash $sourceInventory) -ne [string]$plan.source_tree_sha256) { throw 'DRIFT_AFTER_PLAN: legacy inventory changed after planning' }
    $lock = Enter-HebriOperationLock -Descriptor $Descriptor -ApprovalId $ApprovalId -ApprovalStoreRoot $ApprovalStoreRoot
    $journal = New-HebriOperationJournal -Descriptor $Descriptor -ApprovalId $ApprovalId -LockPath $lock.Path
    [void](Set-HebriOperationJournalState -JournalPath $journal.Path -State applying -Evidence 'P05 migration apply started')
    Set-LegacyApprovalConsumed -Descriptor $Descriptor -ApprovalId $ApprovalId -ApprovalStoreRoot $ApprovalStoreRoot
    $stage = New-LegacyMigrationStage $plan
    $stageHash = $stage.Hash
    $writes = $true
    Invoke-LegacyFailurePoint $plan 'during_staging'
    [void][IO.Directory]::CreateDirectory([string]$paths.operation_root)
    if (Test-Path -LiteralPath ([string]$paths.snapshot_path)) { throw 'DRIFT_AFTER_PLAN: snapshot path already exists' }
    [IO.Directory]::Move([string]$paths.legacy_root, [string]$paths.snapshot_path)
    $snapshotMoved = $true
    $snapshotInventory = @(Get-LegacyInventory ([string]$paths.snapshot_path))
    if ((Get-LegacyTreeHash $snapshotInventory) -ne [string]$plan.source_tree_sha256) { throw 'BACKUP_INTEGRITY_FAILED: moved snapshot hash mismatch' }
    [void](Move-LegacyPriorBackupTrees -SnapshotRoot ([string]$paths.snapshot_path) -PriorBackupsRoot ([string]$paths.prior_backups_path))
    $snapshotInventory = @(Get-LegacyInventory ([string]$paths.snapshot_path))
    if ($snapshotInventory.Count -ne [int]$plan.snapshot_file_count -or (Get-LegacyTreeHash $snapshotInventory) -ne [string]$plan.snapshot_tree_sha256) { throw 'BACKUP_INTEGRITY_FAILED: backup-excluded snapshot hash mismatch' }
    $priorBackupInventory = @()
    if (Test-Path -LiteralPath ([string]$paths.prior_backups_path) -PathType Container) { $priorBackupInventory = @(Get-LegacyInventory ([string]$paths.prior_backups_path)) }
    if ($priorBackupInventory.Count -ne [int]$plan.prior_backup_file_count -or (Get-LegacyTreeHash $priorBackupInventory) -ne [string]$plan.prior_backup_tree_sha256) { throw 'BACKUP_INTEGRITY_FAILED: relocated prior backup hash mismatch' }
    $snapshot = [pscustomobject][ordered]@{
      schema = 'hebrinex.legacy_migration_snapshot'; schema_version = 1; operation_id = [string]$Descriptor.operation_id
      project_id = [string]$Descriptor.project_id; source_version = [string]$plan.source_version; source_tree_sha256 = [string]$plan.snapshot_tree_sha256
      created_at = (Get-Date).ToUniversalTime().ToString('o'); files = $snapshotInventory
    }
    Write-LegacyJson ([string]$paths.snapshot_manifest_path) $snapshot
    if ($priorBackupInventory.Count -gt 0) {
      $priorBackups = [pscustomobject][ordered]@{
        schema = 'hebrinex.legacy_migration_snapshot'; schema_version = 1; operation_id = [string]$Descriptor.operation_id
        project_id = [string]$Descriptor.project_id; source_version = [string]$plan.source_version; source_tree_sha256 = [string]$plan.prior_backup_tree_sha256
        created_at = (Get-Date).ToUniversalTime().ToString('o'); files = $priorBackupInventory
      }
      Write-LegacyJson ([string]$paths.prior_backups_manifest_path) $priorBackups
    }
    Invoke-LegacyFailurePoint $plan 'after_snapshot'
    Invoke-LegacyFailurePoint $plan 'before_publish'
    [IO.Directory]::Move([string]$paths.stage_root, [string]$paths.legacy_root)
    $published = $true
    Invoke-LegacyFailurePoint $plan 'after_publish'
    if ([string]$plan.failure_point -eq 'catalog') { throw 'REGISTRATION_PENDING: fixture catalog failure' }
    Write-LegacyJson ([string]$paths.catalog_path) $plan.documents.catalog
    $registrationPath = Join-Path ([string]$paths.legacy_root) 'instance/registration.json'
    $registration = Read-HebriJsonDocument $registrationPath
    $registration.status = 'registered'
    $registration.updated_at = (Get-Date).ToUniversalTime().ToString('o')
    Write-LegacyJson $registrationPath $registration
    $snapshotDoc = Read-HebriJsonDocument ([string]$paths.snapshot_manifest_path)
    $snapshotDoc | Add-Member -NotePropertyName post_migration_tree_sha256 -NotePropertyValue (Get-LegacyTreeHash @(Get-LegacyInventory ([string]$paths.legacy_root))) -Force
    Write-LegacyJson ([string]$paths.snapshot_manifest_path) $snapshotDoc
    [void](Set-HebriOperationJournalState -JournalPath $journal.Path -State committed -Evidence 'legacy snapshot verified, lightweight instance published and catalog registered')
    return New-LegacyResult applied MIGRATION_APPLIED 0 $true ([ordered]@{ snapshot_path = [string]$paths.snapshot_path; snapshot_manifest_path = [string]$paths.snapshot_manifest_path; prior_backups_path = if ($priorBackupInventory.Count -gt 0) { [string]$paths.prior_backups_path } else { '' }; prior_backups_manifest_path = if ($priorBackupInventory.Count -gt 0) { [string]$paths.prior_backups_manifest_path } else { '' }; journal_path = $journal.Path; source_version = [string]$plan.source_version; target_version = [string]$plan.target_version }) 'Conservar el snapshot y los backups previos; validar el proyecto antes de considerar un restore.' ([string]$Descriptor.project_id)
  }
  catch {
    $message = $_.Exception.Message
    $reason = if ($message -match '^([A-Z0-9_]+):') { $Matches[1] } else { 'MIGRATION_RECOVERY_REQUIRED' }
    if ($published) {
      if ($null -ne $journal) { try { [void](Set-HebriOperationJournalState -JournalPath $journal.Path -State recovery_required -Evidence $message) } catch { } }
      if ($reason -ne 'REGISTRATION_PENDING') { $reason = 'MIGRATION_RECOVERY_REQUIRED' }
      return New-LegacyResult failed $reason 8 $true ([ordered]@{ error = $message; snapshot_path = [string]$paths.snapshot_path; journal_path = if ($null -ne $journal) { $journal.Path } else { '' } }) 'La instancia publicada se conserva; inspeccionar journal y snapshot antes de reconciliar.' ([string]$Descriptor.project_id)
    }
    $rolledBack = $true
    if ($null -ne $journal) { try { [void](Set-HebriOperationJournalState -JournalPath $journal.Path -State rolling_back -Evidence $message) } catch { } }
    try {
      if (-not (Test-Path -LiteralPath ([string]$paths.legacy_root)) -and (Test-Path -LiteralPath ([string]$paths.snapshot_path) -PathType Container)) {
        Restore-LegacyPriorBackupTrees -SnapshotRoot ([string]$paths.snapshot_path) -PriorBackupsRoot ([string]$paths.prior_backups_path)
        $snapshotInventory = @(Get-LegacyInventory ([string]$paths.snapshot_path))
        if ((Get-LegacyTreeHash $snapshotInventory) -ne [string]$plan.source_tree_sha256) { $rolledBack = $false }
        else { [IO.Directory]::Move([string]$paths.snapshot_path, [string]$paths.legacy_root) }
      }
      if (-not (Remove-LegacyOwnedStage -Path ([string]$paths.stage_root) -ExpectedHash $stageHash)) { $rolledBack = $false }
    }
    catch { $rolledBack = $false }
    if ($null -ne $journal) {
      try { [void](Set-HebriOperationJournalState -JournalPath $journal.Path -State $(if ($rolledBack) { 'rolled_back' } else { 'recovery_required' }) -Evidence $(if ($rolledBack) { 'source restored and owned stage removed' } else { 'automatic rollback could not prove ownership' })) } catch { }
    }
    if (-not $rolledBack) { $reason = 'MIGRATION_RECOVERY_REQUIRED' }
    return New-LegacyResult failed $reason $(if ($rolledBack) { 3 } else { 8 }) $writes ([ordered]@{ error = $message; rolled_back = $rolledBack; journal_path = if ($null -ne $journal) { $journal.Path } else { '' } }) 'Revisar evidencia y generar un plan nuevo; no reutilizar la aprobacion consumida.' ([string]$Descriptor.project_id)
  }
  finally { if ($null -ne $lock) { try { [void](Exit-HebriOperationLock -LockPath $lock.Path) } catch { } } }
}

function Copy-LegacySnapshotToStage {
  param([string]$SnapshotRoot, [object[]]$ManifestFiles, [string]$StageRoot)
  if (Test-Path -LiteralPath $StageRoot) { throw 'DRIFT_AFTER_PLAN: restore stage already exists' }
  [void][IO.Directory]::CreateDirectory($StageRoot)
  foreach ($item in $ManifestFiles) { Copy-LegacyFile -SourceRoot $SnapshotRoot -RelativePath ([string]$item.path) -DestinationRoot $StageRoot -DestinationRelative ([string]$item.path) -ExpectedHash ([string]$item.sha256) }
  $inventory = @(Get-LegacyInventory $StageRoot)
  return [pscustomobject]@{ Hash = Get-LegacyTreeHash $inventory; Inventory = $inventory }
}

function New-HebriLegacyRestorePlan {
  param(
    [Parameter(Mandatory = $true)][string]$InstallRoot,
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$CatalogRoot,
    [Parameter(Mandatory = $true)][string]$SnapshotPath,
    [switch]$PreservePostMigrationChanges,
    [long]$AvailableBytesOverride = -1,
    [string]$FailurePoint = ''
  )
  $install = Get-LegacyFullPath $InstallRoot
  $project = Get-LegacyFullPath $ProjectRoot
  $catalog = Get-LegacyFullPath $CatalogRoot
  $targetVersion = Get-LegacyRuntimeVersion $install
  $legacyRoot = Join-Path $project '.hebrinex'
  $bindingPath = Join-Path $legacyRoot 'binding.json'
  if (-not (Test-Path -LiteralPath $bindingPath -PathType Leaf)) { return New-LegacyResult blocked BINDING_SCHEMA_UNSUPPORTED 3 $false ([ordered]@{}) 'Restore requiere una instancia central migrada.' }
  try { $binding = Read-HebriJsonDocument $bindingPath } catch { return New-LegacyResult blocked BINDING_SCHEMA_UNSUPPORTED 3 $false ([ordered]@{}) 'Binding central invalido.' }
  $projectId = [string]$binding.project_id
  $instanceId = [string]$binding.instance_id
  if ($projectId -notmatch '^PRJ-[a-f0-9]{32}$' -or $instanceId -notmatch '^INST-[a-f0-9]{32}$' -or -not (Test-LegacyPathEqual ([string]$binding.project_root) $project)) { return New-LegacyResult blocked BINDING_SCHEMA_UNSUPPORTED 3 $false ([ordered]@{}) 'Binding central no coincide con ProjectRoot.' }
  $fixtureMode = Test-Path -LiteralPath (Join-Path $project '.hebrinex-migration-fixture') -PathType Leaf
  if (($AvailableBytesOverride -ge 0 -or -not [string]::IsNullOrWhiteSpace($FailurePoint)) -and -not $fixtureMode) { return New-LegacyResult blocked OPERATION_DESCRIPTOR_INVALID 3 $false ([ordered]@{}) 'Overrides de espacio y fallos estan reservados a fixtures aislados.' $projectId }
  $snapshot = Get-LegacyFullPath $SnapshotPath
  $operationRootOriginal = Split-Path -Parent $snapshot
  $manifestPath = Join-Path $operationRootOriginal 'snapshot-manifest.json'
  if (-not (Test-Path -LiteralPath $snapshot -PathType Container) -or -not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { return New-LegacyResult blocked BACKUP_INTEGRITY_FAILED 3 $false ([ordered]@{}) 'Snapshot o manifest ausente.' }
  try { $manifest = Read-HebriJsonDocument $manifestPath } catch { return New-LegacyResult blocked BACKUP_INTEGRITY_FAILED 3 $false ([ordered]@{}) 'Manifest JSON invalido.' }
  $manifestFiles = @(Get-LegacyValue $manifest 'files' @())
  $snapshotInventory = @(Get-LegacyInventory $snapshot)
  if ([string](Get-LegacyValue $manifest 'schema') -ne 'hebrinex.legacy_migration_snapshot' -or [string](Get-LegacyValue $manifest 'project_id') -ne $projectId -or
      $manifestFiles.Count -ne $snapshotInventory.Count -or (Get-LegacyTreeHash $snapshotInventory) -ne [string](Get-LegacyValue $manifest 'source_tree_sha256') -or
      (Get-LegacyTreeHash $manifestFiles) -ne [string](Get-LegacyValue $manifest 'source_tree_sha256')) { return New-LegacyResult blocked BACKUP_INTEGRITY_FAILED 3 $false ([ordered]@{}) 'El snapshot no coincide con su manifest.' }
  $currentInventory = @(Get-LegacyInventory $legacyRoot)
  $currentHash = Get-LegacyTreeHash $currentInventory
  $expectedCurrent = [string](Get-LegacyValue $manifest 'post_migration_tree_sha256')
  if ($expectedCurrent -notmatch '^[a-f0-9]{64}$') { return New-LegacyResult blocked BACKUP_INTEGRITY_FAILED 3 $false ([ordered]@{}) 'El snapshot no registra el estado post-migracion.' }
  if ($currentHash -ne $expectedCurrent -and -not $PreservePostMigrationChanges) { return New-LegacyResult blocked POST_MIGRATION_CHANGES 3 $false ([ordered]@{ expected_tree_sha256 = $expectedCurrent; observed_tree_sha256 = $currentHash }) 'Revisar cambios y generar un plan con preservacion explicita.' $projectId }
  [int64]$requiredBytes = 131072
  foreach ($item in $manifestFiles) { $requiredBytes += [int64]$item.size }
  try { $availableBytes = if ($AvailableBytesOverride -ge 0) { $AvailableBytesOverride } else { Get-LegacyAvailableBytes $project } }
  catch { return New-LegacyResult blocked INSUFFICIENT_SPACE 3 $false ([ordered]@{ error = $_.Exception.Message; required_bytes = $requiredBytes }) 'Verificar permisos y espacio del volumen antes de generar otro plan.' $projectId }
  if ($availableBytes -lt $requiredBytes) { return New-LegacyResult blocked INSUFFICIENT_SPACE 3 $false ([ordered]@{ required_bytes = $requiredBytes; available_bytes = $availableBytes }) 'Liberar espacio y generar un plan nuevo.' $projectId }
  $operationId = 'OP-' + [guid]::NewGuid().ToString('N')
  $restoreRoot = Join-Path (Split-Path -Parent $operationRootOriginal) ('restore-' + $operationId)
  $controlRoot = Join-Path $restoreRoot 'control'
  $stageRoot = Join-Path $project ('.hebrinex-restore-stage-' + $operationId)
  $preservedRoot = Join-Path $restoreRoot 'post-migration-preserved'
  $catalogPath = Join-Path (Join-Path $catalog 'projects') ($projectId + '.json')
  $catalogDocument = [ordered]@{ schema = 'hebrinex.project_catalog_entry'; schema_version = 1; project_id = $projectId; instance_id = $instanceId; project_root = $project; binding_schema_version = 1; state = 'unbound'; observed_at = (Get-Date).ToUniversalTime().ToString('o'); source = 'validated_binding' }
  $plan = [pscustomobject][ordered]@{
    schema = 'hebrinex.legacy_migration_plan'; schema_version = 1; action = 'restore'; project_id = $projectId; instance_id = $instanceId
    source_version = $targetVersion; target_version = [string]$manifest.source_version; snapshot_manifest_sha256 = Get-HebriFileSha256 $manifestPath
    paths = [ordered]@{ legacy_root = $legacyRoot; stage_root = $stageRoot; operation_root = $restoreRoot; control_root = $controlRoot; snapshot_path = $snapshot; snapshot_manifest_path = $manifestPath; preserved_root = $preservedRoot; catalog_path = $catalogPath }
    source_tree_sha256 = $currentHash; source_file_count = $currentInventory.Count; space = [ordered]@{ required_bytes = $requiredBytes; available_bytes = $availableBytes }
    files = $manifestFiles; documents = [ordered]@{ catalog = $catalogDocument }; preserve_post_migration_changes = [bool]$PreservePostMigrationChanges
    stages = @('validate_preconditions','acquire_lock','stage_snapshot','preserve_current_instance','publish_legacy_snapshot','update_catalog','commit_journal')
    rollback = [ordered]@{ before_publication = 'restore_current_instance_and_remove_owned_stage'; after_publication = 'recovery_required_preserve_restored_and_current_snapshots'; deletes_backups = $false }
    approval = [ordered]@{ required = $true; type = 'APR2'; bound_to = 'descriptor_hash'; single_use = $true }
    fixture_mode = $fixtureMode; failure_point = $FailurePoint
  }
  $context = [pscustomobject]@{ install_root = $install; project_root = $project; instance_root = $controlRoot; catalog_root = $catalog; project_id = $projectId }
  $descriptor = New-HebriOperationDescriptor -Context $context -Operation 'project:restore-legacy' -WriteSet @($legacyRoot,$stageRoot,$preservedRoot,$catalogPath) -CodeVersion $script:LegacyCodeVersion -Plan $plan -OperationId $operationId
  $check = Test-HebriLegacyMigrationDescriptor $descriptor
  if (-not $check.Valid) { return New-LegacyResult blocked $check.Reason 3 $false ([ordered]@{}) 'Corregir el plan restore rechazado.' $projectId }
  return New-LegacyResult planned RESTORE_PLAN_READY 0 $false ([ordered]@{ descriptor = $descriptor; snapshot_path = $snapshot; post_migration_changes = ($currentHash -ne $expectedCurrent) }) 'Revisar descriptor, obtener SI y materializar una aprobacion APR2.' $projectId
}

function Invoke-HebriLegacyRestoreOperation {
  param([object]$Descriptor, [string]$ApprovalId, [string]$ApprovalStoreRoot = '')
  $plan = $Descriptor.plan
  $paths = $plan.paths
  $lock = $null
  $journal = $null
  $stageHash = ''
  $writes = $false
  $currentMoved = $false
  $published = $false
  try {
    $approval = Test-HebriScopedApproval -Descriptor $Descriptor -ApprovalId $ApprovalId -StoreRoot $ApprovalStoreRoot
    if (-not $approval.Valid) { throw ($approval.Reason + ': scoped approval rejected') }
    if ((Get-HebriFileSha256 ([string]$paths.snapshot_manifest_path)) -ne [string]$plan.snapshot_manifest_sha256) { throw 'BACKUP_INTEGRITY_FAILED: snapshot manifest changed after planning' }
    $manifest = Read-HebriJsonDocument ([string]$paths.snapshot_manifest_path)
    $snapshotInventory = @(Get-LegacyInventory ([string]$paths.snapshot_path))
    if ((Get-LegacyTreeHash $snapshotInventory) -ne [string]$manifest.source_tree_sha256 -or (Get-LegacyTreeHash @($manifest.files)) -ne [string]$manifest.source_tree_sha256) { throw 'BACKUP_INTEGRITY_FAILED: snapshot changed after planning' }
    $currentInventory = @(Get-LegacyInventory ([string]$paths.legacy_root))
    $currentHash = Get-LegacyTreeHash $currentInventory
    if ($currentHash -ne [string]$plan.source_tree_sha256) { throw 'DRIFT_AFTER_PLAN: central instance changed after restore plan' }
    if ($currentHash -ne [string]$manifest.post_migration_tree_sha256 -and -not [bool]$plan.preserve_post_migration_changes) { throw 'POST_MIGRATION_CHANGES: restore would overwrite later changes' }
    Test-LegacyPreconditions $Descriptor
    $lock = Enter-HebriOperationLock -Descriptor $Descriptor -ApprovalId $ApprovalId -ApprovalStoreRoot $ApprovalStoreRoot
    $journal = New-HebriOperationJournal -Descriptor $Descriptor -ApprovalId $ApprovalId -LockPath $lock.Path
    [void](Set-HebriOperationJournalState -JournalPath $journal.Path -State applying -Evidence 'P05 restore apply started')
    Set-LegacyApprovalConsumed -Descriptor $Descriptor -ApprovalId $ApprovalId -ApprovalStoreRoot $ApprovalStoreRoot
    $stage = Copy-LegacySnapshotToStage -SnapshotRoot ([string]$paths.snapshot_path) -ManifestFiles @($manifest.files) -StageRoot ([string]$paths.stage_root)
    $stageHash = $stage.Hash
    $writes = $true
    Invoke-LegacyFailurePoint $plan 'before_publish'
    [void][IO.Directory]::CreateDirectory([string]$paths.operation_root)
    [IO.Directory]::Move([string]$paths.legacy_root, [string]$paths.preserved_root)
    $currentMoved = $true
    Invoke-LegacyFailurePoint $plan 'after_preserve'
    [IO.Directory]::Move([string]$paths.stage_root, [string]$paths.legacy_root)
    $published = $true
    Invoke-LegacyFailurePoint $plan 'after_publish'
    Write-LegacyJson ([string]$paths.catalog_path) $plan.documents.catalog
    [void](Set-HebriOperationJournalState -JournalPath $journal.Path -State committed -Evidence 'snapshot restored and post-migration instance preserved')
    return New-LegacyResult applied LEGACY_RESTORED 0 $true ([ordered]@{ snapshot_path = [string]$paths.snapshot_path; preserved_post_migration_path = [string]$paths.preserved_root; journal_path = $journal.Path }) 'Conservar ambos snapshots hasta completar la revision.' ([string]$Descriptor.project_id)
  }
  catch {
    $message = $_.Exception.Message
    $reason = if ($message -match '^([A-Z0-9_]+):') { $Matches[1] } else { 'MIGRATION_RECOVERY_REQUIRED' }
    if ($published) {
      if ($null -ne $journal) { try { [void](Set-HebriOperationJournalState -JournalPath $journal.Path -State recovery_required -Evidence $message) } catch { } }
      return New-LegacyResult failed MIGRATION_RECOVERY_REQUIRED 8 $true ([ordered]@{ error = $message; preserved_post_migration_path = [string]$paths.preserved_root }) 'Inspeccionar snapshot, estado restaurado y copia post-migracion.' ([string]$Descriptor.project_id)
    }
    $rolledBack = $true
    if ($null -ne $journal) { try { [void](Set-HebriOperationJournalState -JournalPath $journal.Path -State rolling_back -Evidence $message) } catch { } }
    try {
      if ($currentMoved -and -not (Test-Path -LiteralPath ([string]$paths.legacy_root)) -and (Test-Path -LiteralPath ([string]$paths.preserved_root) -PathType Container)) { [IO.Directory]::Move([string]$paths.preserved_root, [string]$paths.legacy_root) }
      if (-not (Remove-LegacyOwnedStage -Path ([string]$paths.stage_root) -ExpectedHash $stageHash)) { $rolledBack = $false }
    }
    catch { $rolledBack = $false }
    if ($null -ne $journal) { try { [void](Set-HebriOperationJournalState -JournalPath $journal.Path -State $(if ($rolledBack) { 'rolled_back' } else { 'recovery_required' }) -Evidence 'restore rollback result') } catch { } }
    if (-not $rolledBack) { $reason = 'MIGRATION_RECOVERY_REQUIRED' }
    return New-LegacyResult failed $reason $(if ($rolledBack) { 3 } else { 8 }) $writes ([ordered]@{ error = $message; rolled_back = $rolledBack }) 'Generar un plan restore nuevo despues de revisar la evidencia.' ([string]$Descriptor.project_id)
  }
  finally { if ($null -ne $lock) { try { [void](Exit-HebriOperationLock -LockPath $lock.Path) } catch { } } }
}

Export-ModuleMember -Function @(
  'New-HebriLegacyBaseline',
  'Test-HebriLegacyBaseline',
  'New-HebriLegacyMigrationPlan',
  'New-HebriLegacyRestorePlan',
  'Test-HebriLegacyMigrationDescriptor',
  'Invoke-HebriLegacyMigrationOperation'
)
