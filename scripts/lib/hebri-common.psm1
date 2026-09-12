# hebri-common.psm1 - Shared helpers for Hebri-AI-Harness runtime scripts.
# Compatible with Windows PowerShell 5.1 and PowerShell 7+.

Set-StrictMode -Version 2.0

function Get-HebriInstanceRelativePath {
  param([Parameter(Mandatory = $true)][string]$RelativePath)
  $norm = ($RelativePath -replace '\\', '/').TrimStart('./')
  if ($norm -eq 'PROJECT_BINDING.yaml') { return 'instance/PROJECT_BINDING.yaml' }
  if ($norm -eq 'PROGRESS.md') { return 'instance/PROGRESS.md' }
  if ($norm -eq 'orquestador/context') { return 'instance/context' }
  if ($norm -match '^orquestador/context/(.+)$') { return 'instance/context/' + $Matches[1] }
  if ($norm -eq 'orquestador/memory/memory-registry.yaml') { return 'instance/memory/memory-registry.yaml' }
  if ($norm -match '^orquestador/memory/(local|project|cycle|daily|complete)$') { return 'instance/memory/' + $Matches[1] }
  if ($norm -match '^orquestador/memory/(local|project|cycle|daily|complete)(/.*)?$') { return 'instance/memory/' + $Matches[1] + $Matches[2] }
  if ($norm -eq 'orquestador/sdd/progress') { return 'instance/sdd/progress' }
  if ($norm -match '^orquestador/sdd/progress/(schemas|templates)(/.*)?$' -or $norm -eq 'orquestador/sdd/progress/_README.md') { return $norm }
  if ($norm -match '^orquestador/sdd/progress/(.+)$') { return 'instance/sdd/progress/' + $Matches[1] }
  if ($norm -eq 'orquestador/sdd/specs') { return 'instance/sdd/specs' }
  if ($norm -match '^orquestador/sdd/specs/_template(/.*)?$') { return $norm }
  if ($norm -match '^orquestador/sdd/specs/(.+)$') { return 'instance/sdd/specs/' + $Matches[1] }
  if ($norm -eq 'orquestador/migration/backups') { return 'instance/migration/backups' }
  if ($norm -match '^orquestador/migration/backups(/.*)?$') { return 'instance/migration/backups' + $Matches[1] }
  if ($norm -eq 'orquestador/migration/contracts/post-migration-contract.yaml') { return 'instance/migration/contracts/post-migration-contract.yaml' }
  if ($norm -eq 'orquestador/migration/reports/migration-report.template.yaml') { return $norm }
  if ($norm -eq 'orquestador/migration/reports') { return 'instance/migration/reports' }
  if ($norm -match '^orquestador/migration/reports/(.+)$') { return 'instance/migration/reports/' + $Matches[1] }
  if ($norm -eq 'orquestador/runtime/gateway-rate.json') { return 'instance/runtime/gateway-rate.json' }
  if ($norm -eq 'orquestador/runtime/claude') { return 'instance/runtime/claude' }
  if ($norm -match '^orquestador/runtime/claude(/.*)?$') { return 'instance/runtime/claude' + $Matches[1] }
  if ($norm -eq 'mcp/agents-backend.local.yaml') { return 'instance/mcp/agents-backend.local.yaml' }
  return $norm
}

function Resolve-HarnessPath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )
  $mapped = Get-HebriInstanceRelativePath -RelativePath $RelativePath
  $mappedPath = Join-Path $Root $mapped
  if ($mapped -ne (($RelativePath -replace '\\', '/').TrimStart('./')) -and (Test-Path -LiteralPath $mappedPath)) {
    return $mappedPath
  }
  return (Join-Path $Root $RelativePath)
}

function Read-HarnessText {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )
  $path = Resolve-HarnessPath -Root $Root -RelativePath $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "missing file: $RelativePath"
  }
  return [IO.File]::ReadAllText($path)
}

function Get-Scalar {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
    [Parameter(Mandatory = $true)][string]$Key
  )
  foreach ($line in ($Text -split "`n")) {
    if ($line -match ('^\s*' + [regex]::Escape($Key) + ':\s*(.*)$')) {
      return $Matches[1].Trim().Trim('"').Trim("'")
    }
  }
  return ''
}

function Get-SectionScalar {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
    [Parameter(Mandatory = $true)][string]$Section,
    [Parameter(Mandatory = $true)][string]$Key
  )
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

function Get-YamlList {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
    [Parameter(Mandatory = $true)][string]$Key
  )
  $items = New-Object System.Collections.Generic.List[string]
  $inside = $false
  foreach ($line in ($Text -split "`n")) {
    if ($line -match ('^' + [regex]::Escape($Key) + ':\s*$')) {
      $inside = $true
      continue
    }
    if ($inside -and $line -match '^[A-Za-z0-9_.-]+:\s*') { break }
    if ($inside -and $line -match '^\s*-\s*(.+?)\s*$') {
      $value = $Matches[1].Trim().Trim('"').Trim("'")
      if (-not [string]::IsNullOrWhiteSpace($value)) { [void]$items.Add($value) }
    }
  }
  return $items
}

function Redact-Text {
  param([AllowEmptyString()][AllowNull()][string]$Text)
  if ($null -eq $Text) { return '' }
  $redacted = [regex]::Replace($Text, '(?i)(api[_-]?key|token|secret|password)\s*[:=]\s*\S+', '$1=[REDACTED]')
  return [regex]::Replace($redacted, '(?i)bearer\s+[a-z0-9._\-]+', 'Bearer [REDACTED]')
}

function Limit-Text {
  param(
    [AllowEmptyString()][AllowNull()][string]$Text,
    [int]$MaxLength = 4000
  )
  if ($null -eq $Text) { return '' }
  if ($Text.Length -le $MaxLength) { return $Text }
  return ($Text.Substring(0, $MaxLength) + '[TRUNCATED]')
}

function Ensure-Directory {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Write-Utf8Text {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text
  )
  $parent = Split-Path -Parent $Path
  if (-not [string]::IsNullOrWhiteSpace($parent)) { Ensure-Directory $parent }
  [IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), [Text.UTF8Encoding]::new($false))
}

function Get-Sha256Hex {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))
    $builder = New-Object System.Text.StringBuilder
    foreach ($byte in $bytes) { [void]$builder.Append($byte.ToString('x2')) }
    return $builder.ToString()
  }
  finally { $sha.Dispose() }
}

# --- Portable runtime resolver ------------------------------------------------
# This API is parallel to Resolve-HarnessPath so existing bound consumers keep
# their stable behavior until P03/P04 migrate them explicitly.

$script:HebriRuntimeContractVersion = '1.0.0'
$script:HebriRuntimeApi = '1'
$script:HebriRuntimeLayoutRelativePath = 'packaging/runtime-layout.json'

function Throw-HebriRuntimeError {
  param(
    [Parameter(Mandatory = $true)][string]$Code,
    [Parameter(Mandatory = $true)][string]$Message
  )
  throw ($Code + ': ' + $Message)
}

function Get-HebriFullPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) {
    Throw-HebriRuntimeError 'PATH_OUTSIDE_ROOT' 'empty filesystem path'
  }
  try { $full = [IO.Path]::GetFullPath($Path) }
  catch { Throw-HebriRuntimeError 'PATH_OUTSIDE_ROOT' ('invalid filesystem path: ' + $_.Exception.Message) }
  $volumeRoot = [IO.Path]::GetPathRoot($full)
  if ($full -eq $volumeRoot) { return $full }
  return $full.TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
}

function Test-HebriPathContained {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Candidate
  )
  $rootFull = Get-HebriFullPath $Root
  $candidateFull = Get-HebriFullPath $Candidate
  if ($candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase)) { return $true }
  $prefix = $rootFull + [IO.Path]::DirectorySeparatorChar
  return $candidateFull.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-HebriPathContained {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Candidate
  )
  if (-not (Test-HebriPathContained -Root $Root -Candidate $Candidate)) {
    Throw-HebriRuntimeError 'PATH_OUTSIDE_ROOT' 'resolved path is outside its declared root'
  }
}

function Assert-HebriNoReparsePath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Candidate
  )
  $rootFull = Get-HebriFullPath $Root
  $candidateFull = Get-HebriFullPath $Candidate
  Assert-HebriPathContained -Root $rootFull -Candidate $candidateFull

  $current = $rootFull
  $relative = $candidateFull.Substring($rootFull.Length).TrimStart([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
  $components = @()
  if (-not [string]::IsNullOrWhiteSpace($relative)) {
    $components = @($relative -split '[\\/]')
  }
  $toInspect = @($current)
  foreach ($component in $components) {
    $current = Join-Path $current $component
    $toInspect += $current
  }
  foreach ($path in $toInspect) {
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $item = Get-Item -LiteralPath $path -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      Throw-HebriRuntimeError 'REPARSE_POINT_UNSUPPORTED' 'a resolved path component is a junction or symbolic link'
    }
  }
}

function ConvertTo-HebriLogicalPath {
  param([Parameter(Mandatory = $true)][string]$LogicalPath)
  if ([string]::IsNullOrWhiteSpace($LogicalPath) -or $LogicalPath -ne $LogicalPath.Trim()) {
    Throw-HebriRuntimeError 'RESOURCE_UNKNOWN' 'logical path is empty or has surrounding whitespace'
  }
  foreach ($character in $LogicalPath.ToCharArray()) {
    if ([char]::IsControl($character)) {
      Throw-HebriRuntimeError 'RESOURCE_UNKNOWN' 'logical path contains a control character'
    }
  }
  if ($LogicalPath.Contains('::') -or [IO.Path]::IsPathRooted($LogicalPath) -or $LogicalPath.Contains(':')) {
    Throw-HebriRuntimeError 'PATH_OUTSIDE_ROOT' 'rooted paths, providers and alternate data streams are forbidden'
  }
  $normalized = $LogicalPath -replace '\\', '/'
  if ($normalized.StartsWith('/') -or $normalized.EndsWith('/') -or $normalized.Contains('//')) {
    Throw-HebriRuntimeError 'PATH_OUTSIDE_ROOT' 'logical path has an invalid separator boundary'
  }
  foreach ($segment in ($normalized -split '/')) {
    if ([string]::IsNullOrWhiteSpace($segment) -or $segment -eq '.' -or $segment -eq '..') {
      Throw-HebriRuntimeError 'PATH_OUTSIDE_ROOT' 'logical path contains traversal or an empty segment'
    }
  }
  return $normalized
}

function Get-HebriRuntimeLayout {
  param([Parameter(Mandatory = $true)][string]$InstallRoot)
  $installFull = Get-HebriFullPath $InstallRoot
  $layoutPath = Join-Path $installFull ($script:HebriRuntimeLayoutRelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
  Assert-HebriPathContained -Root $installFull -Candidate $layoutPath
  if (-not (Test-Path -LiteralPath $layoutPath -PathType Leaf)) {
    Throw-HebriRuntimeError 'RUNTIME_NOT_INSTALLED' 'packaging/runtime-layout.json is missing'
  }
  Assert-HebriNoReparsePath -Root $installFull -Candidate $layoutPath
  try {
    $layout = [IO.File]::ReadAllText($layoutPath) | ConvertFrom-Json
  }
  catch { Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' ('runtime layout is not valid JSON: ' + $_.Exception.Message) }

  if ($layout.schema -ne 'hebrinex.runtime.layout' -or
      [int]$layout.schema_version -ne 1 -or
      [string]$layout.contract_version -ne $script:HebriRuntimeContractVersion -or
      [string]$layout.runtime_api -ne $script:HebriRuntimeApi -or
      [string]$layout.default_class -ne 'denied' -or
      $null -eq $layout.roots -or $null -eq $layout.integrity -or $null -eq $layout.rules) {
    Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' 'runtime layout header is incompatible or incomplete'
  }

  $allowedClasses = @('product', 'template', 'instance', 'integration', 'catalog', 'denied')
  $allowedRoots = @('InstallRoot', 'ProjectRoot', 'InstanceRoot', 'CatalogRoot', 'none')
  $seenIds = @{}
  $seenSelectors = @{}
  foreach ($rule in @($layout.rules)) {
    $id = [string]$rule.id
    $match = [string]$rule.match
    $logical = [string]$rule.logical_path
    if ([string]::IsNullOrWhiteSpace($id) -or $seenIds.ContainsKey($id)) {
      Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' 'runtime layout has an empty or duplicate rule id'
    }
    $seenIds[$id] = $true
    try { $normalizedLogical = ConvertTo-HebriLogicalPath $logical }
    catch { Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' ('invalid rule ' + $id + ': ' + $_.Exception.Message) }
    if ($normalizedLogical -ne $logical -or $match -notin @('exact', 'prefix') -or
        [string]$rule.class -notin $allowedClasses -or [string]$rule.root -notin $allowedRoots -or
        [string]::IsNullOrWhiteSpace([string]$rule.purpose)) {
      Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' ('runtime layout rule is invalid: ' + $id)
    }
    $selector = $match + '|' + $logical.ToLowerInvariant()
    if ($seenSelectors.ContainsKey($selector)) {
      Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' ('runtime layout has an ambiguous selector: ' + $logical)
    }
    $seenSelectors[$selector] = $true
    if ([string]$rule.class -eq 'denied') {
      if ([string]$rule.root -ne 'none' -or [bool]$rule.read -or [bool]$rule.write) {
        Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' ('denied rule grants access: ' + $id)
      }
    }
    else {
      if ([string]$rule.root -eq 'none' -or [string]::IsNullOrWhiteSpace([string]$rule.target_path)) {
        Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' ('accessible rule has no target root/path: ' + $id)
      }
      if ([string]$rule.target_path -ne '.') {
        try { [void](ConvertTo-HebriLogicalPath ([string]$rule.target_path)) }
        catch { Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' ('invalid target path in rule ' + $id + ': ' + $_.Exception.Message) }
      }
      if ([string]$rule.class -in @('product', 'template') -and ([string]$rule.root -ne 'InstallRoot' -or [bool]$rule.write)) {
        Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' ('immutable rule is writable or outside InstallRoot: ' + $id)
      }
    }
  }
  if (@($layout.rules).Count -eq 0 -or @($layout.integrity.required_files).Count -eq 0) {
    Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' 'runtime layout rules or integrity set is empty'
  }
  return $layout
}

function Test-HebriRuntimeInstallation {
  param([Parameter(Mandatory = $true)][string]$InstallRoot)
  $installFull = Get-HebriFullPath $InstallRoot
  if (-not (Test-Path -LiteralPath $installFull -PathType Container)) {
    Throw-HebriRuntimeError 'RUNTIME_NOT_INSTALLED' 'trusted InstallRoot does not exist'
  }
  $layout = Get-HebriRuntimeLayout -InstallRoot $installFull
  $versionPath = Join-Path $installFull 'HARNESS_VERSION'
  if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
    Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' 'HARNESS_VERSION is missing'
  }
  $version = [IO.File]::ReadAllText($versionPath).Trim()
  if ($version -ne [string]$layout.harness_version) {
    Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' 'HARNESS_VERSION disagrees with runtime layout'
  }
  foreach ($relative in @($layout.integrity.required_files)) {
    try { $logical = ConvertTo-HebriLogicalPath ([string]$relative) }
    catch { Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' ('invalid integrity path: ' + $_.Exception.Message) }
    $path = Join-Path $installFull ($logical -replace '/', [IO.Path]::DirectorySeparatorChar)
    Assert-HebriPathContained -Root $installFull -Candidate $path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' ('required runtime file is missing: ' + $logical)
    }
    Assert-HebriNoReparsePath -Root $installFull -Candidate $path
  }
  return [pscustomobject]@{
    InstallRoot = $installFull
    Layout = $layout
    HarnessVersion = $version
  }
}

function Find-HebriForbiddenBindingField {
  param([AllowNull()]$Value)
  if ($null -eq $Value) { return $null }
  if ($Value -is [string] -or $Value.GetType().IsValueType) { return $null }
  if ($Value -is [System.Collections.IDictionary]) {
    foreach ($key in $Value.Keys) {
      if ([string]$key -match '(?i)^(install_root|engine_path|executable_path|script_path|command)$') { return [string]$key }
      $nested = Find-HebriForbiddenBindingField $Value[$key]
      if ($null -ne $nested) { return $nested }
    }
    return $null
  }
  if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
    foreach ($item in $Value) {
      $nested = Find-HebriForbiddenBindingField $item
      if ($null -ne $nested) { return $nested }
    }
    return $null
  }
  if ($Value -is [System.Management.Automation.PSCustomObject]) {
    foreach ($property in $Value.PSObject.Properties) {
      if ($property.Name -match '(?i)^(install_root|engine_path|executable_path|script_path|command)$') { return $property.Name }
      $nested = Find-HebriForbiddenBindingField $property.Value
      if ($null -ne $nested) { return $nested }
    }
  }
  return $null
}

function Resolve-HebriRuntimeContext {
  param(
    [Parameter(Mandatory = $true)][string]$InstallRoot,
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][ValidateSet('source_template', 'legacy_bound', 'central_instance')][string]$DeploymentMode,
    [string]$CatalogRoot = ''
  )
  $runtime = Test-HebriRuntimeInstallation -InstallRoot $InstallRoot
  $installFull = $runtime.InstallRoot
  $projectFull = Get-HebriFullPath $ProjectRoot
  if (-not (Test-Path -LiteralPath $projectFull -PathType Container)) {
    Throw-HebriRuntimeError 'BINDING_CONFLICT' 'explicit ProjectRoot does not exist'
  }
  Assert-HebriNoReparsePath -Root $projectFull -Candidate $projectFull
  if ([string]::IsNullOrWhiteSpace($CatalogRoot)) {
    $localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    if ([string]::IsNullOrWhiteSpace($localAppData)) {
      Throw-HebriRuntimeError 'BINDING_CONFLICT' 'CatalogRoot was not supplied and LocalApplicationData is unavailable'
    }
    $CatalogRoot = Join-Path $localAppData 'Hebri-AI-Harness'
  }
  $catalogFull = Get-HebriFullPath $CatalogRoot
  $centralBinding = Join-Path $projectFull '.hebrinex\binding.json'
  $projectLegacyRootBinding = Join-Path $projectFull '.hebrinex\PROJECT_BINDING.yaml'
  $projectLegacyInstanceBinding = Join-Path $projectFull '.hebrinex\instance\PROJECT_BINDING.yaml'
  $legacyRootBinding = Join-Path $installFull 'PROJECT_BINDING.yaml'
  $legacyInstanceBinding = Join-Path $installFull 'instance\PROJECT_BINDING.yaml'
  $bindingPath = $null
  $projectId = ''
  $instanceRoot = ''

  if ($DeploymentMode -eq 'central_instance') {
    if ((Test-Path -LiteralPath $projectLegacyRootBinding -PathType Leaf) -or (Test-Path -LiteralPath $projectLegacyInstanceBinding -PathType Leaf)) {
      Throw-HebriRuntimeError 'BINDING_CONFLICT' 'central and legacy bindings coexist'
    }
    if (-not (Test-Path -LiteralPath $centralBinding -PathType Leaf)) {
      Throw-HebriRuntimeError 'BINDING_CONFLICT' 'central binding is missing'
    }
    Assert-HebriNoReparsePath -Root $projectFull -Candidate $centralBinding
    try { $binding = [IO.File]::ReadAllText($centralBinding) | ConvertFrom-Json }
    catch { Throw-HebriRuntimeError 'BINDING_CONFLICT' ('central binding is not valid JSON: ' + $_.Exception.Message) }
    $allowedBindingFields = @('schema', 'schema_version', 'project_id', 'instance_id', 'project_root', 'layout', 'instance_relative_path', 'required_engine', 'state_schema_version', 'last_verified_engine_version', 'created_at', 'updated_at')
    $unknownBindingFields = @($binding.PSObject.Properties.Name | Where-Object { $_ -notin $allowedBindingFields })
    if ($unknownBindingFields.Count -gt 0) {
      Throw-HebriRuntimeError 'BINDING_CONFLICT' ('central binding contains unsupported fields: ' + ($unknownBindingFields -join ', '))
    }
    if ($null -ne $binding.required_engine) {
      $unknownEngineFields = @($binding.required_engine.PSObject.Properties.Name | Where-Object { $_ -notin @('api_line', 'minimum_engine_version') })
      if ($unknownEngineFields.Count -gt 0) {
        Throw-HebriRuntimeError 'BINDING_CONFLICT' ('required_engine contains unsupported fields: ' + ($unknownEngineFields -join ', '))
      }
    }
    $forbidden = Find-HebriForbiddenBindingField $binding
    if ($null -ne $forbidden) {
      Throw-HebriRuntimeError 'BINDING_CONFLICT' ('binding cannot select executable code through field ' + $forbidden)
    }
    if ([string]$binding.schema -ne 'hebrinex.binding' -or [int]$binding.schema_version -ne 1 -or
        [string]$binding.layout -ne 'central_instance' -or [string]::IsNullOrWhiteSpace([string]$binding.project_id) -or
        [string]::IsNullOrWhiteSpace([string]$binding.instance_id) -or $null -eq $binding.required_engine -or
        [string]$binding.required_engine.api_line -ne $script:HebriRuntimeApi -or
        (($binding.instance_relative_path -replace '\\', '/') -ne '.hebrinex/instance')) {
      Throw-HebriRuntimeError 'BINDING_CONFLICT' 'central binding schema, identity, layout or API line is incompatible'
    }
    $bindingProject = Get-HebriFullPath ([string]$binding.project_root)
    if (-not $bindingProject.Equals($projectFull, [StringComparison]::OrdinalIgnoreCase)) {
      Throw-HebriRuntimeError 'BINDING_CONFLICT' 'binding project_root disagrees with explicit ProjectRoot'
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$binding.required_engine.minimum_engine_version)) {
      try {
        if ([version]$runtime.HarnessVersion -lt [version][string]$binding.required_engine.minimum_engine_version) {
          Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' 'installed engine is older than the binding minimum'
        }
      }
      catch {
        if ($_.Exception.Message -match '^RUNTIME_INTEGRITY_FAILED:') { throw }
        Throw-HebriRuntimeError 'BINDING_CONFLICT' 'binding minimum_engine_version is invalid'
      }
    }
    $bindingPath = $centralBinding
    $projectId = [string]$binding.project_id
    $instanceRoot = Join-Path $projectFull '.hebrinex\instance'
  }
  elseif ($DeploymentMode -eq 'legacy_bound') {
    if (Test-Path -LiteralPath $centralBinding -PathType Leaf) {
      Throw-HebriRuntimeError 'BINDING_CONFLICT' 'central and legacy bindings coexist'
    }
    $expectedInstall = Get-HebriFullPath (Join-Path $projectFull '.hebrinex')
    if (-not $installFull.Equals($expectedInstall, [StringComparison]::OrdinalIgnoreCase)) {
      Throw-HebriRuntimeError 'BINDING_CONFLICT' 'legacy InstallRoot must be ProjectRoot/.hebrinex'
    }
    $rootExists = Test-Path -LiteralPath $legacyRootBinding -PathType Leaf
    $instanceExists = Test-Path -LiteralPath $legacyInstanceBinding -PathType Leaf
    if (-not $rootExists -and -not $instanceExists) {
      Throw-HebriRuntimeError 'BINDING_CONFLICT' 'legacy PROJECT_BINDING.yaml is missing'
    }
    if ($rootExists -and $instanceExists -and
        [IO.File]::ReadAllText($legacyRootBinding).Trim() -ne [IO.File]::ReadAllText($legacyInstanceBinding).Trim()) {
      Throw-HebriRuntimeError 'BINDING_CONFLICT' 'legacy root and instance bindings disagree'
    }
    if ($instanceExists) { $bindingPath = $legacyInstanceBinding } else { $bindingPath = $legacyRootBinding }
    Assert-HebriNoReparsePath -Root $installFull -Candidate $bindingPath
    $bindingText = [IO.File]::ReadAllText($bindingPath)
    if ((Get-Scalar -Text $bindingText -Key 'binding_mode') -ne 'bound' -or
        (Get-Scalar -Text $bindingText -Key 'harness_version') -ne $runtime.HarnessVersion) {
      Throw-HebriRuntimeError 'BINDING_CONFLICT' 'legacy binding mode or harness version is incompatible'
    }
    $bindingProject = Get-HebriFullPath (Get-Scalar -Text $bindingText -Key 'project_root')
    if (-not $bindingProject.Equals($projectFull, [StringComparison]::OrdinalIgnoreCase)) {
      Throw-HebriRuntimeError 'BINDING_CONFLICT' 'legacy binding project_root disagrees with explicit ProjectRoot'
    }
    $projectId = Get-Scalar -Text $bindingText -Key 'harness_instance_id'
    if ([string]::IsNullOrWhiteSpace($projectId)) { Throw-HebriRuntimeError 'BINDING_CONFLICT' 'legacy binding identity is missing' }
    $instanceRoot = Join-Path $installFull 'instance'
  }
  else {
    if (-not $projectFull.Equals($installFull, [StringComparison]::OrdinalIgnoreCase)) {
      Throw-HebriRuntimeError 'BINDING_CONFLICT' 'source_template requires ProjectRoot equal to InstallRoot'
    }
    if (Test-Path -LiteralPath $centralBinding -PathType Leaf) {
      Throw-HebriRuntimeError 'BINDING_CONFLICT' 'source template cannot contain a central binding'
    }
    if (-not (Test-Path -LiteralPath $legacyRootBinding -PathType Leaf)) {
      Throw-HebriRuntimeError 'BINDING_CONFLICT' 'source PROJECT_BINDING.yaml is missing'
    }
    $bindingText = [IO.File]::ReadAllText($legacyRootBinding)
    if ((Get-Scalar -Text $bindingText -Key 'binding_mode') -ne 'source_template' -or
        (Get-Scalar -Text $bindingText -Key 'harness_version') -ne $runtime.HarnessVersion) {
      Throw-HebriRuntimeError 'BINDING_CONFLICT' 'source binding mode or harness version is incompatible'
    }
    $bindingPath = $legacyRootBinding
    $projectId = Get-Scalar -Text $bindingText -Key 'harness_instance_id'
    $instanceRoot = Join-Path $installFull 'instance'
  }

  $layoutPath = Join-Path $installFull ($script:HebriRuntimeLayoutRelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
  $layoutText = [IO.File]::ReadAllText($layoutPath)
  return [pscustomobject]@{
    schema = 'hebrinex.runtime.context'
    contract_version = $script:HebriRuntimeContractVersion
    runtime_api = $script:HebriRuntimeApi
    install_root = $installFull
    project_root = $projectFull
    instance_root = Get-HebriFullPath $instanceRoot
    catalog_root = $catalogFull
    project_id = $projectId
    deployment_mode = $DeploymentMode
    binding_path = $bindingPath
    harness_version = $runtime.HarnessVersion
    layout_sha256 = Get-Sha256Hex $layoutText
    trusted_install_source = 'launcher_input'
  }
}

function Get-HebriContextRoot {
  param(
    [Parameter(Mandatory = $true)]$Context,
    [Parameter(Mandatory = $true)][string]$RootKind
  )
  switch ($RootKind) {
    'InstallRoot' { return [string]$Context.install_root }
    'ProjectRoot' { return [string]$Context.project_root }
    'InstanceRoot' { return [string]$Context.instance_root }
    'CatalogRoot' { return [string]$Context.catalog_root }
    default { Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' ('unsupported root kind: ' + $RootKind) }
  }
}

function Resolve-HebriResourcePath {
  param(
    [Parameter(Mandatory = $true)]$Context,
    [Parameter(Mandatory = $true)][string]$LogicalPath,
    [Parameter(Mandatory = $true)][ValidateSet('read', 'write')][string]$Access,
    [switch]$AllowMissing
  )
  if ([string]$Context.schema -ne 'hebrinex.runtime.context' -or
      [string]$Context.contract_version -ne $script:HebriRuntimeContractVersion -or
      [string]$Context.runtime_api -ne $script:HebriRuntimeApi) {
    Throw-HebriRuntimeError 'BINDING_CONFLICT' 'runtime context contract is incompatible'
  }
  $verifiedContext = Resolve-HebriRuntimeContext `
    -InstallRoot ([string]$Context.install_root) `
    -ProjectRoot ([string]$Context.project_root) `
    -DeploymentMode ([string]$Context.deployment_mode) `
    -CatalogRoot ([string]$Context.catalog_root)
  foreach ($field in @('instance_root', 'project_id', 'binding_path', 'harness_version', 'layout_sha256', 'trusted_install_source')) {
    if ([string]$Context.$field -ne [string]$verifiedContext.$field) {
      Throw-HebriRuntimeError 'BINDING_CONFLICT' ('runtime context field was modified after verification: ' + $field)
    }
  }
  $Context = $verifiedContext
  $resource = ConvertTo-HebriLogicalPath $LogicalPath
  $layout = Get-HebriRuntimeLayout -InstallRoot ([string]$Context.install_root)
  $layoutPath = Join-Path ([string]$Context.install_root) ($script:HebriRuntimeLayoutRelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
  if ((Get-Sha256Hex ([IO.File]::ReadAllText($layoutPath))) -ne [string]$Context.layout_sha256) {
    Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' 'runtime layout changed after context resolution'
  }

  $matches = New-Object System.Collections.Generic.List[object]
  foreach ($candidate in @($layout.rules)) {
    $base = [string]$candidate.logical_path
    $matched = $false
    if ([string]$candidate.match -eq 'exact') {
      $matched = $resource.Equals($base, [StringComparison]::OrdinalIgnoreCase)
    }
    elseif ($resource.Equals($base, [StringComparison]::OrdinalIgnoreCase) -or
            $resource.StartsWith($base + '/', [StringComparison]::OrdinalIgnoreCase)) {
      $matched = $true
    }
    if ($matched) {
      [void]$matches.Add([pscustomobject]@{
        Rule = $candidate
        Exact = [int]([string]$candidate.match -eq 'exact')
        Length = $base.Length
      })
    }
  }
  if ($matches.Count -eq 0) { Throw-HebriRuntimeError 'RESOURCE_UNKNOWN' 'logical resource is not classified' }
  $ordered = @($matches | Sort-Object @{Expression = 'Exact'; Descending = $true}, @{Expression = 'Length'; Descending = $true})
  $winner = $ordered[0]
  $ties = @($ordered | Where-Object { $_.Exact -eq $winner.Exact -and $_.Length -eq $winner.Length })
  if ($ties.Count -gt 1) {
    $signatures = @($ties | ForEach-Object { [string]$_.Rule.class + '|' + [string]$_.Rule.root + '|' + [string]$_.Rule.target_path } | Select-Object -Unique)
    if ($signatures.Count -gt 1) { Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' 'equally specific layout rules disagree' }
  }
  $rule = $winner.Rule
  if ([string]$rule.class -eq 'denied') { Throw-HebriRuntimeError 'RESOURCE_UNKNOWN' 'logical resource is denied by runtime layout' }
  if ($Access -eq 'read' -and -not [bool]$rule.read) { Throw-HebriRuntimeError 'RESOURCE_UNKNOWN' 'resource is not readable' }
  if ($Access -eq 'write' -and -not [bool]$rule.write) {
    Throw-HebriRuntimeError 'RESOURCE_WRITE_FORBIDDEN' 'resource classification is immutable'
  }

  $rootKind = [string]$rule.root
  $rootPath = Get-HebriFullPath (Get-HebriContextRoot -Context $Context -RootKind $rootKind)
  $targetRelative = ([string]$rule.target_path -replace '\\', '/')
  if ([string]$rule.match -eq 'prefix' -and $resource.Length -gt ([string]$rule.logical_path).Length) {
    $suffix = $resource.Substring(([string]$rule.logical_path).Length).TrimStart('/')
    if ($targetRelative -eq '.') { $targetRelative = $suffix }
    else { $targetRelative = $targetRelative.TrimEnd('/') + '/' + $suffix }
  }
  if ($targetRelative -eq '.') { $resolved = $rootPath }
  else { $resolved = Join-Path $rootPath ($targetRelative -replace '/', [IO.Path]::DirectorySeparatorChar) }
  $resolved = Get-HebriFullPath $resolved
  Assert-HebriPathContained -Root $rootPath -Candidate $resolved
  Assert-HebriNoReparsePath -Root $rootPath -Candidate $resolved

  $legacyFallback = $false
  if ([string]$rule.legacy_projection -eq 'instance' -and
      [string]$Context.deployment_mode -in @('legacy_bound', 'source_template') -and
      -not (Test-Path -LiteralPath $resolved)) {
    $legacyCandidate = Get-HebriFullPath (Join-Path ([string]$Context.install_root) ($resource -replace '/', [IO.Path]::DirectorySeparatorChar))
    Assert-HebriPathContained -Root ([string]$Context.install_root) -Candidate $legacyCandidate
    Assert-HebriNoReparsePath -Root ([string]$Context.install_root) -Candidate $legacyCandidate
    $rootKind = 'InstallRoot'
    $rootPath = Get-HebriFullPath ([string]$Context.install_root)
    $resolved = $legacyCandidate
    $targetRelative = $resource
    $legacyFallback = $true
  }

  $exists = Test-Path -LiteralPath $resolved
  if ($Access -eq 'read' -and -not $exists -and -not $AllowMissing) {
    if ([string]$rule.class -in @('product', 'template')) {
      Throw-HebriRuntimeError 'RUNTIME_INTEGRITY_FAILED' ('required product resource is missing: ' + $resource)
    }
    Throw-HebriRuntimeError 'LOCAL_STATE_MISSING' ('required local resource is missing: ' + $resource)
  }
  return [pscustomobject]@{
    schema = 'hebrinex.runtime.path_result'
    contract_version = $script:HebriRuntimeContractVersion
    runtime_api = $script:HebriRuntimeApi
    resource = $resource
    rule_id = [string]$rule.id
    classification = [string]$rule.class
    purpose = [string]$rule.purpose
    root_kind = $rootKind
    root_path = $rootPath
    path = $resolved
    relative_path = $targetRelative
    access = $Access
    exists = [bool]$exists
    writable = [bool]$rule.write
    deployment_mode = [string]$Context.deployment_mode
    legacy_fallback_used = [bool]$legacyFallback
  }
}

# --- Approval store -----------------------------------------------------------
# Envelopes live in orquestador/sdd/progress/approvals/APR-*.yaml.
# The operator SI is materialized as an envelope file with expiry and an exact
# action hash. A gateway call with -ApprovalId is only valid when the envelope
# exists, is approved, is not expired and matches the exact command text.

$script:ApprovalsRelativeDir = 'orquestador/sdd/progress/approvals'

function Get-ApprovalPath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$ApprovalId
  )
  if ($ApprovalId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$') {
    throw 'approval_id_invalid_format'
  }
  $dir = Resolve-HarnessPath -Root $Root -RelativePath $script:ApprovalsRelativeDir
  return (Join-Path $dir ($ApprovalId + '.yaml'))
}

function New-ApprovalEnvelope {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$CommandText,
    [string]$Purpose = '',
    [int]$TtlMinutes = 60,
    [string]$ActionType = 'run_command',
    [string]$Risk = 'low',
    [string]$HarnessVersion = ''
  )
  if ([string]::IsNullOrWhiteSpace($CommandText)) { throw 'approval_requires_command_text' }
  if ($TtlMinutes -lt 1 -or $TtlMinutes -gt 1440) { throw 'approval_ttl_out_of_range' }

  $now = (Get-Date).ToUniversalTime()
  $stamp = $now.ToString('yyyyMMddTHHmmssZ')
  $suffix = ([guid]::NewGuid().ToString('N')).Substring(0, 6)
  $approvalId = "APR-$stamp-$suffix"
  $expiresAt = $now.AddMinutes($TtlMinutes).ToString('o')
  $createdAt = $now.ToString('o')
  $commandTrimmed = $CommandText.Trim()
  $commandHash = Get-Sha256Hex $commandTrimmed
  $safePurpose = (Redact-Text $Purpose).Replace('"', "'")
  $safeCommand = (Redact-Text $commandTrimmed).Replace('"', "'")

  $lines = @(
    'schema: hebrinex.approval_envelope',
    'version: "0.1"',
    "approval_id: $approvalId",
    'status: approved',
    'human_decision: approved',
    'approved_text: "SI"',
    "action_type: $ActionType",
    ('exact_action: "' + $safeCommand + '"'),
    ('command: "' + $safeCommand + '"'),
    "command_sha256: $commandHash",
    ('purpose: "' + $safePurpose + '"'),
    "risk: $Risk",
    "created_at: $createdAt",
    "expires_at: $expiresAt",
    ('harness_version: "' + $HarnessVersion + '"')
  )
  $path = Get-ApprovalPath -Root $Root -ApprovalId $approvalId
  Write-Utf8Text -Path $path -Text (($lines -join "`n") + "`n")
  return @{
    Id = $approvalId
    Path = $path
    ExpiresAt = $expiresAt
    CommandSha256 = $commandHash
  }
}

function Test-ApprovalEnvelope {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$ApprovalId,
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$CommandText
  )
  $result = @{ Valid = $false; Reason = ''; ExpiresAt = '' }
  $path = ''
  try { $path = Get-ApprovalPath -Root $Root -ApprovalId $ApprovalId }
  catch {
    $result.Reason = 'approval_id_invalid_format'
    return $result
  }
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    $result.Reason = 'approval_not_found'
    return $result
  }
  $text = [IO.File]::ReadAllText($path)
  $status = Get-Scalar -Text $text -Key 'status'
  $humanDecision = Get-Scalar -Text $text -Key 'human_decision'
  $expiresAt = Get-Scalar -Text $text -Key 'expires_at'
  $storedHash = Get-Scalar -Text $text -Key 'command_sha256'
  $result.ExpiresAt = $expiresAt

  if ($status -ne 'approved' -or $humanDecision -ne 'approved') {
    $result.Reason = 'approval_not_approved'
    return $result
  }
  $expiresParsed = [datetime]::MinValue
  if ([string]::IsNullOrWhiteSpace($expiresAt) -or -not [datetime]::TryParse($expiresAt, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$expiresParsed)) {
    $result.Reason = 'approval_expiry_invalid'
    return $result
  }
  if ($expiresParsed -le (Get-Date).ToUniversalTime()) {
    $result.Reason = 'approval_expired'
    return $result
  }
  if ([string]::IsNullOrWhiteSpace($storedHash) -or $storedHash -ne (Get-Sha256Hex $CommandText.Trim())) {
    $result.Reason = 'approval_command_mismatch'
    return $result
  }
  $result.Valid = $true
  $result.Reason = 'approval_valid'
  return $result
}

# --- Locks --------------------------------------------------------------------
# Lock files live in orquestador/sdd/progress/locks/L-*.lock.md with the format
# documented in that directory's _README.md. A lock is exclusive over its paths
# while status=active and expires_at is in the future.

$script:LocksRelativeDir = 'orquestador/sdd/progress/locks'

function Get-NormalizedLockPath {
  param([AllowEmptyString()][AllowNull()][string]$Path)
  if ($null -eq $Path) { return '' }
  $norm = ($Path -replace '\\', '/').Trim()
  $norm = $norm.TrimStart('.', '/')
  return $norm.TrimEnd('/').ToLowerInvariant()
}

# Overlap = equal path, or one path is a directory prefix of the other.
function Test-LockPathOverlap {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$PathA,
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$PathB
  )
  $a = Get-NormalizedLockPath $PathA
  $b = Get-NormalizedLockPath $PathB
  if ([string]::IsNullOrWhiteSpace($a) -or [string]::IsNullOrWhiteSpace($b)) { return $false }
  if ($a -eq $b) { return $true }
  return $a.StartsWith($b + '/') -or $b.StartsWith($a + '/')
}

function Get-LockInventory {
  param([Parameter(Mandatory = $true)][string]$Root)
  $locksDir = Resolve-HarnessPath -Root $Root -RelativePath $script:LocksRelativeDir
  $active = New-Object System.Collections.Generic.List[object]
  $expired = New-Object System.Collections.Generic.List[object]
  if (-not (Test-Path -LiteralPath $locksDir -PathType Container)) {
    return @{ Active = $active; Expired = $expired }
  }
  $now = (Get-Date).ToUniversalTime()
  foreach ($file in (Get-ChildItem -LiteralPath $locksDir -File -Filter '*.lock.md' -ErrorAction SilentlyContinue)) {
    $text = [IO.File]::ReadAllText($file.FullName)
    $status = Get-Scalar -Text $text -Key 'status'
    if ($status -ne 'active') { continue }
    $lockId = Get-Scalar -Text $text -Key 'lock_id'
    if ([string]::IsNullOrWhiteSpace($lockId)) { $lockId = $file.BaseName }
    $expiresAt = Get-Scalar -Text $text -Key 'expires_at'
    $owner = Get-Scalar -Text $text -Key 'owner_agent_id'
    $paths = @(Get-YamlList -Text $text -Key 'paths')
    $entry = @{ LockId = $lockId; ExpiresAt = $expiresAt; File = $file.Name; Owner = $owner; Paths = $paths }
    $expiresParsed = [datetime]::MinValue
    $hasExpiry = -not [string]::IsNullOrWhiteSpace($expiresAt) -and [datetime]::TryParse($expiresAt, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$expiresParsed)
    if ($hasExpiry -and $expiresParsed -le $now) {
      [void]$expired.Add($entry)
    }
    else {
      [void]$active.Add($entry)
    }
  }
  return @{ Active = $active; Expired = $expired }
}

# Returns the first active (non-expired) lock whose paths overlap $Path, or $null.
function Find-LockForPath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Path
  )
  $inventory = Get-LockInventory -Root $Root
  foreach ($lock in $inventory.Active) {
    foreach ($lockPath in $lock.Paths) {
      if (Test-LockPathOverlap -PathA $Path -PathB $lockPath) { return $lock }
    }
  }
  return $null
}

function New-HarnessLock {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string[]]$Paths,
    [string]$Owner = 'operator',
    [int]$TtlMinutes = 120,
    [string]$Reason = '',
    [string]$CycleId = '',
    [string]$SliceId = ''
  )
  $cleanPaths = @($Paths | ForEach-Object { ([string]$_).Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($cleanPaths.Count -eq 0) { throw 'lock_requires_paths' }
  if ($TtlMinutes -lt 1 -or $TtlMinutes -gt 1440) { throw 'lock_ttl_out_of_range' }
  if ([string]::IsNullOrWhiteSpace($Owner)) { $Owner = 'operator' }

  # Exclusive mode: any overlap with an active, non-expired lock is a conflict.
  $inventory = Get-LockInventory -Root $Root
  foreach ($lock in $inventory.Active) {
    foreach ($lockPath in $lock.Paths) {
      foreach ($requested in $cleanPaths) {
        if (Test-LockPathOverlap -PathA $requested -PathB $lockPath) {
          throw "lock_conflict: path '$requested' is locked by $($lock.LockId) (owner=$($lock.Owner), expires_at=$($lock.ExpiresAt))"
        }
      }
    }
  }

  $now = (Get-Date).ToUniversalTime()
  $stamp = $now.ToString('yyyyMMddTHHmmssZ')
  $suffix = ([guid]::NewGuid().ToString('N')).Substring(0, 6)
  $lockId = "L-$stamp-$suffix"
  $expiresAt = $now.AddMinutes($TtlMinutes).ToString('o')
  $safeReason = (Redact-Text $Reason).Replace('"', "'")

  $lines = New-Object System.Collections.Generic.List[string]
  [void]$lines.Add("lock_id: $lockId")
  [void]$lines.Add("cycle_id: $CycleId")
  [void]$lines.Add("slice_id: $SliceId")
  [void]$lines.Add("owner_agent_id: $Owner")
  [void]$lines.Add('role: operator_declared')
  [void]$lines.Add('paths:')
  foreach ($path in $cleanPaths) { [void]$lines.Add("  - $path") }
  [void]$lines.Add('mode: exclusive')
  [void]$lines.Add("created_at: $($now.ToString('o'))")
  [void]$lines.Add("expires_at: $expiresAt")
  [void]$lines.Add("reason: $safeReason")
  [void]$lines.Add('status: active')

  $lockPathFull = Join-Path (Resolve-HarnessPath -Root $Root -RelativePath $script:LocksRelativeDir) ($lockId + '.lock.md')
  Write-Utf8Text -Path $lockPathFull -Text (($lines -join "`n") + "`n")
  return @{
    Id = $lockId
    Path = $lockPathFull
    ExpiresAt = $expiresAt
    Paths = $cleanPaths
    Owner = $Owner
  }
}

function Set-HarnessLockReleased {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$LockId
  )
  if ($LockId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$') { throw 'lock_id_invalid_format' }
  $locksDir = Resolve-HarnessPath -Root $Root -RelativePath $script:LocksRelativeDir
  if (-not (Test-Path -LiteralPath $locksDir -PathType Container)) { throw 'lock_not_found' }
  foreach ($file in (Get-ChildItem -LiteralPath $locksDir -File -Filter '*.lock.md' -ErrorAction SilentlyContinue)) {
    $text = [IO.File]::ReadAllText($file.FullName)
    $fileLockId = Get-Scalar -Text $text -Key 'lock_id'
    if ([string]::IsNullOrWhiteSpace($fileLockId)) { $fileLockId = $file.BaseName }
    if ($fileLockId -ne $LockId) { continue }
    $previousStatus = Get-Scalar -Text $text -Key 'status'
    $updated = [regex]::Replace($text, '(?m)^status:.*$', 'status: released', 1)
    if ($updated -notmatch '(?m)^released_at:') {
      $updated = $updated.TrimEnd("`r", "`n") + "`nreleased_at: $((Get-Date).ToUniversalTime().ToString('o'))`n"
    }
    Write-Utf8Text -Path $file.FullName -Text $updated
    return @{ Id = $LockId; Path = $file.FullName; PreviousStatus = $previousStatus }
  }
  throw 'lock_not_found'
}

# --- Operation safety contract -----------------------------------------------
# Version 1 is additive. The legacy approval and Markdown lock APIs above stay
# available until their callers migrate explicitly.

$script:HebriOperationContractVersion = '1.0.0'
$script:HebriOperationApi = '1'
$script:HebriMissingHash = '__MISSING__'

function Get-HebriMemberValue {
  param(
    [AllowNull()][object]$Object,
    [Parameter(Mandatory = $true)][string]$Name,
    [AllowNull()][object]$Default = $null
  )
  if ($null -eq $Object) { return $Default }
  if ($Object -is [Collections.IDictionary]) {
    if ($Object.Contains($Name)) { return $Object[$Name] }
    return $Default
  }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -ne $property) { return $property.Value }
  return $Default
}

function ConvertTo-HebriCanonicalNode {
  param([AllowNull()][object]$Value)
  if ($null -eq $Value) { return $null }
  if ($Value -is [string] -or $Value -is [char] -or $Value -is [bool] -or
      $Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or
      $Value -is [int64] -or $Value -is [single] -or $Value -is [double] -or
      $Value -is [decimal] -or $Value -is [datetime]) {
    return $Value
  }
  if ($Value -is [Collections.IDictionary]) {
    $ordered = [ordered]@{}
    foreach ($key in @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object)) {
      $ordered[$key] = ConvertTo-HebriCanonicalNode $Value[$key]
    }
    return $ordered
  }
  if ($Value -is [Collections.IEnumerable]) {
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($item in $Value) { [void]$items.Add((ConvertTo-HebriCanonicalNode $item)) }
    return $items.ToArray()
  }
  $objectMap = [ordered]@{}
  foreach ($property in @($Value.PSObject.Properties | Sort-Object Name)) {
    $objectMap[$property.Name] = ConvertTo-HebriCanonicalNode $property.Value
  }
  return $objectMap
}

function ConvertTo-HebriCanonicalJson {
  param([Parameter(Mandatory = $true)][AllowNull()][object]$Value)
  return ((ConvertTo-HebriCanonicalNode $Value) | ConvertTo-Json -Depth 32 -Compress)
}

function Get-HebriFileSha256 {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $script:HebriMissingHash }
  $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = $sha.ComputeHash($stream)
    return (($bytes | ForEach-Object { $_.ToString('x2') }) -join '')
  }
  finally {
    $sha.Dispose()
    $stream.Dispose()
  }
}

function Get-HebriOperationDescriptorBody {
  param([Parameter(Mandatory = $true)][object]$Descriptor)
  return [ordered]@{
    schema = [string](Get-HebriMemberValue $Descriptor 'schema')
    contract_version = [string](Get-HebriMemberValue $Descriptor 'contract_version')
    runtime_api = [string](Get-HebriMemberValue $Descriptor 'runtime_api')
    operation_id = [string](Get-HebriMemberValue $Descriptor 'operation_id')
    project_id = [string](Get-HebriMemberValue $Descriptor 'project_id')
    operation = [string](Get-HebriMemberValue $Descriptor 'operation')
    roots = ConvertTo-HebriCanonicalNode (Get-HebriMemberValue $Descriptor 'roots')
    write_set = @((Get-HebriMemberValue $Descriptor 'write_set' @()) | ForEach-Object { [string]$_ } | Sort-Object -Unique)
    code_version = [string](Get-HebriMemberValue $Descriptor 'code_version')
    plan = ConvertTo-HebriCanonicalNode (Get-HebriMemberValue $Descriptor 'plan' ([ordered]@{}))
    plan_hash = [string](Get-HebriMemberValue $Descriptor 'plan_hash')
    preconditions = @((Get-HebriMemberValue $Descriptor 'preconditions' @()) | Sort-Object path | ForEach-Object {
      [ordered]@{ path = [string](Get-HebriMemberValue $_ 'path'); sha256 = [string](Get-HebriMemberValue $_ 'sha256') }
    })
  }
}

function Get-HebriOperationDescriptorHash {
  param([Parameter(Mandatory = $true)][object]$Descriptor)
  return Get-Sha256Hex (ConvertTo-HebriCanonicalJson (Get-HebriOperationDescriptorBody $Descriptor))
}

function Test-HebriOperationDescriptor {
  param([Parameter(Mandatory = $true)][object]$Descriptor)
  $result = [ordered]@{ Valid = $false; Reason = 'OPERATION_DESCRIPTOR_INVALID' }
  if ([string](Get-HebriMemberValue $Descriptor 'schema') -ne 'hebrinex.operation_descriptor') { return $result }
  if ([string](Get-HebriMemberValue $Descriptor 'contract_version') -ne $script:HebriOperationContractVersion) { $result.Reason = 'OPERATION_VERSION_MISMATCH'; return $result }
  if ([string](Get-HebriMemberValue $Descriptor 'runtime_api') -ne $script:HebriOperationApi) { $result.Reason = 'OPERATION_VERSION_MISMATCH'; return $result }
  foreach ($name in @('operation_id','project_id','operation','code_version','plan_hash','descriptor_hash')) {
    if ([string]::IsNullOrWhiteSpace([string](Get-HebriMemberValue $Descriptor $name))) { $result.Reason = 'OPERATION_DESCRIPTOR_INVALID'; return $result }
  }
  $operationId = [string](Get-HebriMemberValue $Descriptor 'operation_id')
  if ($operationId -notmatch '^OP-[A-Za-z0-9][A-Za-z0-9._-]{0,127}$') { $result.Reason = 'OPERATION_DESCRIPTOR_INVALID'; return $result }
  $writeSet = @((Get-HebriMemberValue $Descriptor 'write_set' @()) | ForEach-Object { [string]$_ })
  if ($writeSet.Count -eq 0) { $result.Reason = 'OPERATION_WRITE_SET_REQUIRED'; return $result }
  $roots = Get-HebriMemberValue $Descriptor 'roots'
  $projectRoot = [string](Get-HebriMemberValue $roots 'project_root')
  $instanceRoot = [string](Get-HebriMemberValue $roots 'instance_root')
  $catalogRoot = [string](Get-HebriMemberValue $roots 'catalog_root')
  if ([string]::IsNullOrWhiteSpace($projectRoot) -or [string]::IsNullOrWhiteSpace($instanceRoot) -or [string]::IsNullOrWhiteSpace($catalogRoot)) {
    $result.Reason = 'OPERATION_ROOTS_REQUIRED'; return $result
  }
  foreach ($path in $writeSet) {
    $full = ''
    try { $full = Get-HebriFullPath $path }
    catch { $result.Reason = 'OPERATION_WRITE_SET_INVALID'; return $result }
    if (-not ((Test-HebriPathContained -Root $projectRoot -Candidate $full) -or
              (Test-HebriPathContained -Root $instanceRoot -Candidate $full) -or
              (Test-HebriPathContained -Root $catalogRoot -Candidate $full))) {
      $result.Reason = 'OPERATION_WRITE_OUTSIDE_ROOTS'; return $result
    }
  }
  $preconditions = @(Get-HebriMemberValue $Descriptor 'preconditions' @())
  if ($preconditions.Count -ne $writeSet.Count) { $result.Reason = 'OPERATION_PRECONDITIONS_INVALID'; return $result }
  $pathComparison = if ($env:OS -eq 'Windows_NT') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
  foreach ($path in $writeSet) {
    $matches = @($preconditions | Where-Object {
      try { [string]::Equals((Get-HebriFullPath ([string](Get-HebriMemberValue $_ 'path'))), (Get-HebriFullPath $path), $pathComparison) }
      catch { $false }
    })
    if ($matches.Count -ne 1 -or [string](Get-HebriMemberValue $matches[0] 'sha256') -notmatch '^(__MISSING__|[a-f0-9]{64})$') {
      $result.Reason = 'OPERATION_PRECONDITIONS_INVALID'; return $result
    }
  }
  $plan = Get-HebriMemberValue $Descriptor 'plan' ([ordered]@{})
  if ([string](Get-HebriMemberValue $Descriptor 'plan_hash') -ne (Get-Sha256Hex (ConvertTo-HebriCanonicalJson $plan))) {
    $result.Reason = 'OPERATION_PLAN_HASH_MISMATCH'; return $result
  }
  if ([string](Get-HebriMemberValue $Descriptor 'descriptor_hash') -ne (Get-HebriOperationDescriptorHash $Descriptor)) {
    $result.Reason = 'OPERATION_DESCRIPTOR_HASH_MISMATCH'; return $result
  }
  $result.Valid = $true
  $result.Reason = 'OPERATION_DESCRIPTOR_VALID'
  return $result
}

function New-HebriOperationDescriptor {
  param(
    [Parameter(Mandatory = $true)][object]$Context,
    [Parameter(Mandatory = $true)][string]$Operation,
    [Parameter(Mandatory = $true)][string[]]$WriteSet,
    [Parameter(Mandatory = $true)][string]$CodeVersion,
    [object]$Plan = $null,
    [string]$OperationId = ''
  )
  if ([string]::IsNullOrWhiteSpace($OperationId)) { $OperationId = 'OP-' + [guid]::NewGuid().ToString('N') }
  $normalizedWriteSet = @($WriteSet | ForEach-Object { Get-HebriFullPath ([string]$_) } | Sort-Object -Unique)
  if ($null -eq $Plan) { $Plan = [ordered]@{} }
  $preconditions = @($normalizedWriteSet | ForEach-Object {
    [ordered]@{ path = $_; sha256 = Get-HebriFileSha256 $_ }
  })
  $descriptor = [ordered]@{
    schema = 'hebrinex.operation_descriptor'
    contract_version = $script:HebriOperationContractVersion
    runtime_api = $script:HebriOperationApi
    operation_id = $OperationId
    project_id = [string](Get-HebriMemberValue $Context 'project_id')
    operation = $Operation.Trim()
    roots = [ordered]@{
      install_root = Get-HebriFullPath ([string](Get-HebriMemberValue $Context 'install_root'))
      project_root = Get-HebriFullPath ([string](Get-HebriMemberValue $Context 'project_root'))
      instance_root = Get-HebriFullPath ([string](Get-HebriMemberValue $Context 'instance_root'))
      catalog_root = Get-HebriFullPath ([string](Get-HebriMemberValue $Context 'catalog_root'))
    }
    write_set = $normalizedWriteSet
    code_version = $CodeVersion.Trim()
    plan = ConvertTo-HebriCanonicalNode $Plan
    plan_hash = Get-Sha256Hex (ConvertTo-HebriCanonicalJson $Plan)
    preconditions = $preconditions
    descriptor_hash = ''
  }
  $descriptor.descriptor_hash = Get-HebriOperationDescriptorHash $descriptor
  $check = Test-HebriOperationDescriptor $descriptor
  if (-not $check.Valid) { Throw-HebriRuntimeError $check.Reason 'operation descriptor rejected' }
  return [pscustomobject]$descriptor
}

function Write-HebriAtomicJsonDocument {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][object]$Value,
    [switch]$CreateOnly
  )
  $parent = Split-Path -Parent $Path
  if ([string]::IsNullOrWhiteSpace($parent)) { Throw-HebriRuntimeError 'FILESYSTEM_UNSUPPORTED' 'document path has no parent' }
  [void][IO.Directory]::CreateDirectory($parent)
  $json = (ConvertTo-HebriCanonicalJson $Value) + "`n"
  if ($CreateOnly) {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) }
    finally { $stream.Dispose() }
    return
  }
  $temp = Join-Path $parent ('.' + [IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
  try {
    [IO.File]::WriteAllText($temp, $json, [Text.UTF8Encoding]::new($false))
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
      $replaceBackup = Join-Path $parent ('.replace-' + [guid]::NewGuid().ToString('N') + '.bak')
      [IO.File]::Replace($temp, $Path, $replaceBackup)
      if (Test-Path -LiteralPath $replaceBackup -PathType Leaf) { [IO.File]::Delete($replaceBackup) }
    }
    else { [IO.File]::Move($temp, $Path) }
  }
  catch {
    if (Test-Path -LiteralPath $temp -PathType Leaf) { [IO.File]::Delete($temp) }
    Throw-HebriRuntimeError 'FILESYSTEM_UNSUPPORTED' ('atomic JSON publication failed: ' + $_.Exception.Message)
  }
}

function Read-HebriJsonDocument {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { Throw-HebriRuntimeError 'RUNTIME_STATE_MISSING' 'JSON document is missing' }
  try { return ([IO.File]::ReadAllText($Path) | ConvertFrom-Json) }
  catch { Throw-HebriRuntimeError 'RUNTIME_STATE_INVALID' ('invalid JSON document: ' + $_.Exception.Message) }
}

function Get-HebriApprovalStoreRoot {
  param([Parameter(Mandatory = $true)][object]$Descriptor)
  return (Join-Path ([string](Get-HebriMemberValue (Get-HebriMemberValue $Descriptor 'roots') 'instance_root')) 'runtime/approvals')
}

function New-HebriScopedApprovalEnvelope {
  param(
    [Parameter(Mandatory = $true)][object]$Descriptor,
    [string]$StoreRoot = '',
    [int]$TtlMinutes = 60,
    [Parameter(Mandatory = $true)][string]$HumanEvidenceId,
    [ValidateSet('approved','rejected')][string]$HumanDecision = 'approved',
    [string]$ApprovedText = 'SI',
    [string]$ApprovalId = ''
  )
  $descriptorCheck = Test-HebriOperationDescriptor $Descriptor
  if (-not $descriptorCheck.Valid) { Throw-HebriRuntimeError $descriptorCheck.Reason 'approval descriptor rejected' }
  if ($TtlMinutes -lt 1 -or $TtlMinutes -gt 1440) { Throw-HebriRuntimeError 'APPROVAL_SCOPE_MISMATCH' 'approval TTL is outside 1..1440 minutes' }
  if ([string]::IsNullOrWhiteSpace($StoreRoot)) { $StoreRoot = Get-HebriApprovalStoreRoot $Descriptor }
  $instanceRoot = [string](Get-HebriMemberValue (Get-HebriMemberValue $Descriptor 'roots') 'instance_root')
  if (-not (Test-HebriPathContained -Root $instanceRoot -Candidate $StoreRoot)) { Throw-HebriRuntimeError 'APPROVAL_SCOPE_MISMATCH' 'approval store is outside InstanceRoot' }
  if ([string]::IsNullOrWhiteSpace($ApprovalId)) { $ApprovalId = 'APR2-' + [guid]::NewGuid().ToString('N') }
  if ($ApprovalId -notmatch '^APR2-[A-Za-z0-9][A-Za-z0-9._-]{0,127}$') { Throw-HebriRuntimeError 'APPROVAL_SCOPE_MISMATCH' 'invalid scoped approval id' }
  $now = (Get-Date).ToUniversalTime()
  $roots = Get-HebriMemberValue $Descriptor 'roots'
  $writeSet = @(Get-HebriMemberValue $Descriptor 'write_set')
  $approval = [ordered]@{
    schema = 'hebrinex.scoped_approval'
    contract_version = $script:HebriOperationContractVersion
    runtime_api = $script:HebriOperationApi
    approval_id = $ApprovalId
    status = if ($HumanDecision -eq 'approved') { 'approved' } else { 'rejected' }
    human_decision = $HumanDecision
    approved_text = $ApprovedText
    human_evidence_id = $HumanEvidenceId
    operation_id = [string](Get-HebriMemberValue $Descriptor 'operation_id')
    project_id = [string](Get-HebriMemberValue $Descriptor 'project_id')
    operation = [string](Get-HebriMemberValue $Descriptor 'operation')
    descriptor_hash = [string](Get-HebriMemberValue $Descriptor 'descriptor_hash')
    plan_hash = [string](Get-HebriMemberValue $Descriptor 'plan_hash')
    roots_hash = Get-Sha256Hex (ConvertTo-HebriCanonicalJson $roots)
    write_set_hash = Get-Sha256Hex (ConvertTo-HebriCanonicalJson $writeSet)
    code_version = [string](Get-HebriMemberValue $Descriptor 'code_version')
    retry_scope = 'same_operation_id'
    created_at = $now.ToString('o')
    expires_at = $now.AddMinutes($TtlMinutes).ToString('o')
  }
  $path = Join-Path $StoreRoot ($ApprovalId + '.json')
  Write-HebriAtomicJsonDocument -Path $path -Value $approval -CreateOnly
  return [pscustomobject]@{ Id = $ApprovalId; Path = $path; ExpiresAt = $approval.expires_at }
}

function Test-HebriScopedApproval {
  param(
    [Parameter(Mandatory = $true)][object]$Descriptor,
    [Parameter(Mandatory = $true)][string]$ApprovalId,
    [string]$StoreRoot = '',
    [switch]$AllowConsumed
  )
  $result = [ordered]@{ Valid = $false; Reason = 'APPROVAL_REQUIRED'; Path = ''; ExpiresAt = ''; Status = '' }
  $descriptorCheck = Test-HebriOperationDescriptor $Descriptor
  if (-not $descriptorCheck.Valid) { $result.Reason = $descriptorCheck.Reason; return $result }
  if ($ApprovalId -notmatch '^APR2-[A-Za-z0-9][A-Za-z0-9._-]{0,127}$') { $result.Reason = 'APPROVAL_REQUIRED'; return $result }
  if ([string]::IsNullOrWhiteSpace($StoreRoot)) { $StoreRoot = Get-HebriApprovalStoreRoot $Descriptor }
  $path = Join-Path $StoreRoot ($ApprovalId + '.json')
  $result.Path = $path
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $result }
  try { $approval = Read-HebriJsonDocument $path }
  catch { $result.Reason = 'APPROVAL_SCOPE_MISMATCH'; return $result }
  if ([string](Get-HebriMemberValue $approval 'schema') -ne 'hebrinex.scoped_approval' -or
      [string](Get-HebriMemberValue $approval 'contract_version') -ne $script:HebriOperationContractVersion -or
      [string](Get-HebriMemberValue $approval 'runtime_api') -ne $script:HebriOperationApi) {
    $result.Reason = 'APPROVAL_SCOPE_MISMATCH'; return $result
  }
  $status = [string](Get-HebriMemberValue $approval 'status')
  $result.Status = $status
  if ([string](Get-HebriMemberValue $approval 'approval_id') -ne $ApprovalId -or
      [string](Get-HebriMemberValue $approval 'human_decision') -ne 'approved' -or
      [string](Get-HebriMemberValue $approval 'approved_text') -notmatch '^(?i:si|sí)$') {
    $result.Reason = 'APPROVAL_REQUIRED'; return $result
  }
  if ($status -eq 'consumed' -and -not $AllowConsumed) { $result.Reason = 'APPROVAL_SCOPE_MISMATCH'; return $result }
  if ($status -notin @('approved','consumed') -or ($status -eq 'consumed' -and -not $AllowConsumed)) {
    $result.Reason = if ($status -eq 'expired') { 'APPROVAL_EXPIRED' } else { 'APPROVAL_REQUIRED' }
    return $result
  }
  $expiresAt = [string](Get-HebriMemberValue $approval 'expires_at')
  $result.ExpiresAt = $expiresAt
  $expiresParsed = [datetime]::MinValue
  if (-not [datetime]::TryParse($expiresAt, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$expiresParsed) -or $expiresParsed -le (Get-Date).ToUniversalTime()) {
    $result.Reason = 'APPROVAL_EXPIRED'; return $result
  }
  $expected = [ordered]@{
    operation_id = [string](Get-HebriMemberValue $Descriptor 'operation_id')
    project_id = [string](Get-HebriMemberValue $Descriptor 'project_id')
    operation = [string](Get-HebriMemberValue $Descriptor 'operation')
    descriptor_hash = [string](Get-HebriMemberValue $Descriptor 'descriptor_hash')
    plan_hash = [string](Get-HebriMemberValue $Descriptor 'plan_hash')
    roots_hash = Get-Sha256Hex (ConvertTo-HebriCanonicalJson (Get-HebriMemberValue $Descriptor 'roots'))
    write_set_hash = Get-Sha256Hex (ConvertTo-HebriCanonicalJson @(Get-HebriMemberValue $Descriptor 'write_set'))
    code_version = [string](Get-HebriMemberValue $Descriptor 'code_version')
    retry_scope = 'same_operation_id'
  }
  foreach ($name in $expected.Keys) {
    if ([string](Get-HebriMemberValue $approval $name) -ne [string]$expected[$name]) { $result.Reason = 'APPROVAL_SCOPE_MISMATCH'; return $result }
  }
  $result.Valid = $true
  $result.Reason = 'APPROVAL_VALID'
  return $result
}

function Set-HebriScopedApprovalConsumed {
  param(
    [Parameter(Mandatory = $true)][object]$Descriptor,
    [Parameter(Mandatory = $true)][string]$ApprovalId,
    [string]$StoreRoot = ''
  )
  $check = Test-HebriScopedApproval -Descriptor $Descriptor -ApprovalId $ApprovalId -StoreRoot $StoreRoot
  if (-not $check.Valid) { Throw-HebriRuntimeError $check.Reason 'only a valid active approval can be consumed' }
  $approval = Read-HebriJsonDocument $check.Path
  $approval.status = 'consumed'
  $approval | Add-Member -NotePropertyName consumed_at -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('o')) -Force
  Write-HebriAtomicJsonDocument -Path $check.Path -Value $approval
  return $approval
}

function Get-HebriOperationLockRoot {
  param([Parameter(Mandatory = $true)][object]$Descriptor)
  return (Join-Path ([string](Get-HebriMemberValue (Get-HebriMemberValue $Descriptor 'roots') 'instance_root')) 'runtime/locks')
}

function Get-HebriCurrentProcessIdentity {
  $process = Get-Process -Id $PID
  return [ordered]@{
    pid = $PID
    process_start_utc = $process.StartTime.ToUniversalTime().ToString('o')
    process_name = $process.ProcessName
    machine_name = [Environment]::MachineName
  }
}

function Get-HebriLockOwnerStatus {
  param([Parameter(Mandatory = $true)][object]$Lock)
  $owner = Get-HebriMemberValue $Lock 'owner'
  $ownerPid = 0
  if (-not [int]::TryParse([string](Get-HebriMemberValue $owner 'pid'), [ref]$ownerPid) -or $ownerPid -le 0) { return 'unverifiable' }
  $recordedStart = [datetime]::MinValue
  $recordedStartValue = Get-HebriMemberValue $owner 'process_start_utc'
  if ($recordedStartValue -is [datetime]) { $recordedStart = [datetime]$recordedStartValue }
  elseif (-not [datetime]::TryParse([string]$recordedStartValue, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$recordedStart)) { return 'unverifiable' }
  try { $process = Get-Process -Id $ownerPid -ErrorAction Stop }
  catch { return 'dead' }
  try { $actualStart = $process.StartTime.ToUniversalTime() }
  catch { return 'unverifiable' }
  if ($actualStart.Ticks -ne $recordedStart.ToUniversalTime().Ticks) { return 'reused' }
  if ([string](Get-HebriMemberValue $owner 'machine_name') -ne [Environment]::MachineName) { return 'unverifiable' }
  return 'live'
}

function Test-HebriAbsolutePathOverlap {
  param([Parameter(Mandatory = $true)][string]$PathA, [Parameter(Mandatory = $true)][string]$PathB)
  $a = (Get-HebriFullPath $PathA).TrimEnd('\','/').ToLowerInvariant()
  $b = (Get-HebriFullPath $PathB).TrimEnd('\','/').ToLowerInvariant()
  if ($a -eq $b) { return $true }
  return $a.StartsWith($b + [IO.Path]::DirectorySeparatorChar) -or $b.StartsWith($a + [IO.Path]::DirectorySeparatorChar)
}

function Invoke-WithHebriLockGuard {
  param(
    [Parameter(Mandatory = $true)][string]$LockRoot,
    [Parameter(Mandatory = $true)][scriptblock]$Action,
    [int]$TimeoutMilliseconds = 5000
  )
  [void][IO.Directory]::CreateDirectory($LockRoot)
  $name = 'HebriOperation-' + (Get-Sha256Hex (Get-HebriFullPath $LockRoot)).Substring(0, 24)
  if ($env:OS -eq 'Windows_NT') { $name = 'Local\' + $name }
  $mutex = New-Object Threading.Mutex($false, $name)
  $acquired = $false
  try {
    try { $acquired = $mutex.WaitOne($TimeoutMilliseconds) }
    catch [Threading.AbandonedMutexException] { $acquired = $true }
    if (-not $acquired) { Throw-HebriRuntimeError 'LOCK_BUSY' 'timed out waiting for the instance lock guard' }
    return (& $Action)
  }
  finally {
    if ($acquired) { try { $mutex.ReleaseMutex() } catch {} }
    $mutex.Dispose()
  }
}

function Enter-HebriOperationLock {
  param(
    [Parameter(Mandatory = $true)][object]$Descriptor,
    [Parameter(Mandatory = $true)][string]$ApprovalId,
    [string]$ApprovalStoreRoot = '',
    [int]$TtlMinutes = 120
  )
  $approval = Test-HebriScopedApproval -Descriptor $Descriptor -ApprovalId $ApprovalId -StoreRoot $ApprovalStoreRoot
  if (-not $approval.Valid) { Throw-HebriRuntimeError $approval.Reason 'operation lock requires a valid scoped approval' }
  if ($TtlMinutes -lt 1 -or $TtlMinutes -gt 1440) { Throw-HebriRuntimeError 'LOCK_BUSY' 'lock TTL is outside 1..1440 minutes' }
  $lockRoot = Get-HebriOperationLockRoot $Descriptor
  return Invoke-WithHebriLockGuard -LockRoot $lockRoot -Action {
    foreach ($file in @(Get-ChildItem -LiteralPath $lockRoot -Filter 'OPLOCK-*.json' -File -ErrorAction SilentlyContinue)) {
      $existing = $null
      try { $existing = Read-HebriJsonDocument $file.FullName } catch { Throw-HebriRuntimeError 'LOCK_OWNER_UNVERIFIED' 'an existing lock is unreadable' }
      if ([string](Get-HebriMemberValue $existing 'status') -ne 'active') { continue }
      $overlaps = $false
      foreach ($held in @(Get-HebriMemberValue $existing 'resources' @())) {
        foreach ($requested in @(Get-HebriMemberValue $Descriptor 'write_set' @())) {
          if (Test-HebriAbsolutePathOverlap -PathA ([string]$held) -PathB ([string]$requested)) { $overlaps = $true; break }
        }
        if ($overlaps) { break }
      }
      if (-not $overlaps) { continue }
      $ownerStatus = Get-HebriLockOwnerStatus $existing
      if ($ownerStatus -eq 'live') { Throw-HebriRuntimeError 'LOCK_BUSY' 'an overlapping operation lock is active' }
      Throw-HebriRuntimeError 'LOCK_OWNER_UNVERIFIED' ('overlapping lock owner status is ' + $ownerStatus + '; approved recovery is required')
    }
    $now = (Get-Date).ToUniversalTime()
    $lockId = 'OPLOCK-' + [guid]::NewGuid().ToString('N')
    $lock = [ordered]@{
      schema = 'hebrinex.operation_lock'
      contract_version = $script:HebriOperationContractVersion
      runtime_api = $script:HebriOperationApi
      lock_id = $lockId
      operation_id = [string](Get-HebriMemberValue $Descriptor 'operation_id')
      project_id = [string](Get-HebriMemberValue $Descriptor 'project_id')
      approval_id = $ApprovalId
      descriptor_hash = [string](Get-HebriMemberValue $Descriptor 'descriptor_hash')
      resources = @(Get-HebriMemberValue $Descriptor 'write_set')
      owner = Get-HebriCurrentProcessIdentity
      created_at = $now.ToString('o')
      expires_at = $now.AddMinutes($TtlMinutes).ToString('o')
      status = 'active'
    }
    $path = Join-Path $lockRoot ($lockId + '.json')
    Write-HebriAtomicJsonDocument -Path $path -Value $lock -CreateOnly
    return [pscustomobject]@{ Id = $lockId; Path = $path; Owner = $lock.owner; Resources = $lock.resources }
  }
}

function Test-HebriOperationLock {
  param(
    [Parameter(Mandatory = $true)][object]$Descriptor,
    [Parameter(Mandatory = $true)][string]$LockPath,
    [string]$ApprovalId = '',
    [switch]$AllowDifferentOwner
  )
  $result = [ordered]@{ Valid = $false; Reason = 'LOCK_BUSY'; OwnerStatus = 'unverifiable' }
  try { $lock = Read-HebriJsonDocument $LockPath } catch { $result.Reason = 'LOCK_OWNER_UNVERIFIED'; return $result }
  if ([string](Get-HebriMemberValue $lock 'schema') -ne 'hebrinex.operation_lock' -or
      [string](Get-HebriMemberValue $lock 'contract_version') -ne $script:HebriOperationContractVersion -or
      [string](Get-HebriMemberValue $lock 'runtime_api') -ne $script:HebriOperationApi -or
      [string](Get-HebriMemberValue $lock 'status') -ne 'active') { return $result }
  if ([string](Get-HebriMemberValue $lock 'operation_id') -ne [string](Get-HebriMemberValue $Descriptor 'operation_id') -or
      [string](Get-HebriMemberValue $lock 'project_id') -ne [string](Get-HebriMemberValue $Descriptor 'project_id') -or
      [string](Get-HebriMemberValue $lock 'descriptor_hash') -ne [string](Get-HebriMemberValue $Descriptor 'descriptor_hash')) {
    $result.Reason = 'LOCK_BUSY'; return $result
  }
  if (-not [string]::IsNullOrWhiteSpace($ApprovalId) -and [string](Get-HebriMemberValue $lock 'approval_id') -ne $ApprovalId) {
    $result.Reason = 'APPROVAL_SCOPE_MISMATCH'; return $result
  }
  foreach ($requested in @(Get-HebriMemberValue $Descriptor 'write_set')) {
    $covered = $false
    foreach ($held in @(Get-HebriMemberValue $lock 'resources')) {
      if (Test-HebriAbsolutePathOverlap -PathA ([string]$held) -PathB ([string]$requested)) { $covered = $true; break }
    }
    if (-not $covered) { $result.Reason = 'LOCK_BUSY'; return $result }
  }
  $ownerStatus = Get-HebriLockOwnerStatus $lock
  $result.OwnerStatus = $ownerStatus
  if (-not $AllowDifferentOwner -and $ownerStatus -ne 'live') { $result.Reason = 'LOCK_OWNER_UNVERIFIED'; return $result }
  if (-not $AllowDifferentOwner) {
    $identity = Get-HebriCurrentProcessIdentity
    $owner = Get-HebriMemberValue $lock 'owner'
    if ([int](Get-HebriMemberValue $owner 'pid') -ne [int]$identity.pid) {
      $result.Reason = 'LOCK_OWNER_UNVERIFIED'; return $result
    }
  }
  $result.Valid = $true
  $result.Reason = 'LOCK_VALID'
  return $result
}

function Set-HebriOperationLockStatus {
  param(
    [Parameter(Mandatory = $true)][string]$LockPath,
    [Parameter(Mandatory = $true)][ValidateSet('released','recovered')][string]$Status,
    [switch]$RecoveryAuthorized
  )
  $lock = Read-HebriJsonDocument $LockPath
  if ([string](Get-HebriMemberValue $lock 'status') -ne 'active') { Throw-HebriRuntimeError 'LOCK_BUSY' 'lock is not active' }
  $ownerStatus = Get-HebriLockOwnerStatus $lock
  if ($Status -eq 'released') {
    if ($ownerStatus -ne 'live') { Throw-HebriRuntimeError 'LOCK_OWNER_UNVERIFIED' 'only the verified live owner can release a lock' }
    $identity = Get-HebriCurrentProcessIdentity
    $owner = Get-HebriMemberValue $lock 'owner'
    if ([int](Get-HebriMemberValue $owner 'pid') -ne [int]$identity.pid) {
      Throw-HebriRuntimeError 'LOCK_OWNER_UNVERIFIED' 'current process is not the lock owner'
    }
  }
  elseif (-not $RecoveryAuthorized) { Throw-HebriRuntimeError 'APPROVAL_REQUIRED' 'orphan lock recovery requires approval' }
  $lock.status = $Status
  $lock | Add-Member -NotePropertyName ($Status + '_at') -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('o')) -Force
  Write-HebriAtomicJsonDocument -Path $LockPath -Value $lock
  return $lock
}

function Exit-HebriOperationLock {
  param([Parameter(Mandatory = $true)][string]$LockPath)
  return Set-HebriOperationLockStatus -LockPath $LockPath -Status released
}

function Get-HebriOperationJournalRoot {
  param([Parameter(Mandatory = $true)][object]$Descriptor)
  return (Join-Path ([string](Get-HebriMemberValue (Get-HebriMemberValue $Descriptor 'roots') 'instance_root')) 'runtime/journals')
}

function New-HebriOperationJournal {
  param(
    [Parameter(Mandatory = $true)][object]$Descriptor,
    [Parameter(Mandatory = $true)][string]$ApprovalId,
    [Parameter(Mandatory = $true)][string]$LockPath
  )
  $lockCheck = Test-HebriOperationLock -Descriptor $Descriptor -LockPath $LockPath -ApprovalId $ApprovalId
  if (-not $lockCheck.Valid) { Throw-HebriRuntimeError $lockCheck.Reason 'journal requires the current operation lock' }
  $now = (Get-Date).ToUniversalTime().ToString('o')
  $journal = [ordered]@{
    schema = 'hebrinex.operation_journal'
    contract_version = $script:HebriOperationContractVersion
    runtime_api = $script:HebriOperationApi
    operation_id = [string](Get-HebriMemberValue $Descriptor 'operation_id')
    project_id = [string](Get-HebriMemberValue $Descriptor 'project_id')
    descriptor_hash = [string](Get-HebriMemberValue $Descriptor 'descriptor_hash')
    approval_id = $ApprovalId
    lock_path = Get-HebriFullPath $LockPath
    state = 'prepared'
    stage = 'prepared'
    resources = @()
    history = @([ordered]@{ state = 'prepared'; at = $now; evidence = 'descriptor, approval and lock validated' })
    updated_at = $now
  }
  $path = Join-Path (Get-HebriOperationJournalRoot $Descriptor) ([string](Get-HebriMemberValue $Descriptor 'operation_id') + '.json')
  Write-HebriAtomicJsonDocument -Path $path -Value $journal -CreateOnly
  return [pscustomobject]@{ Path = $path; State = 'prepared' }
}

function Set-HebriOperationJournalState {
  param(
    [Parameter(Mandatory = $true)][string]$JournalPath,
    [Parameter(Mandatory = $true)][ValidateSet('prepared','applying','committed','rolling_back','rolled_back','recovery_required')][string]$State,
    [string]$Evidence = ''
  )
  $journal = Read-HebriJsonDocument $JournalPath
  $current = [string](Get-HebriMemberValue $journal 'state')
  $allowed = @{
    prepared = @('applying','recovery_required','rolling_back')
    applying = @('committed','recovery_required','rolling_back')
    recovery_required = @('rolling_back','applying')
    rolling_back = @('rolled_back','recovery_required')
    committed = @()
    rolled_back = @()
  }
  if ($current -eq $State) { return $journal }
  if (-not $allowed.ContainsKey($current) -or $allowed[$current] -notcontains $State) { Throw-HebriRuntimeError 'RECOVERY_REQUIRED' ("invalid journal transition $current -> $State") }
  $now = (Get-Date).ToUniversalTime().ToString('o')
  $journal.state = $State
  $journal.updated_at = $now
  $journal.history = @($journal.history) + @([pscustomobject]@{ state = $State; at = $now; evidence = (Limit-Text (Redact-Text $Evidence) 512) })
  Write-HebriAtomicJsonDocument -Path $JournalPath -Value $journal
  return $journal
}

function Invoke-HebriFixtureTermination {
  param([Parameter(Mandatory = $true)][object]$Descriptor, [string]$FailurePoint, [string]$CurrentPoint)
  if ([string]::IsNullOrWhiteSpace($FailurePoint) -or $FailurePoint -ne $CurrentPoint) { return }
  $plan = Get-HebriMemberValue $Descriptor 'plan'
  if (-not [bool](Get-HebriMemberValue $plan 'fixture_mode' $false)) { Throw-HebriRuntimeError 'RECOVERY_REQUIRED' 'failure injection is restricted to fixture mode' }
  $projectRoot = [string](Get-HebriMemberValue (Get-HebriMemberValue $Descriptor 'roots') 'project_root')
  if (-not (Test-Path -LiteralPath (Join-Path $projectRoot '.hebrinex-operation-fixture') -PathType Leaf)) { Throw-HebriRuntimeError 'RECOVERY_REQUIRED' 'fixture marker is missing' }
  [Environment]::Exit(91)
}

function Publish-HebriAtomicFile {
  param(
    [Parameter(Mandatory = $true)][object]$Descriptor,
    [Parameter(Mandatory = $true)][string]$ApprovalId,
    [string]$ApprovalStoreRoot = '',
    [Parameter(Mandatory = $true)][string]$LockPath,
    [Parameter(Mandatory = $true)][string]$JournalPath,
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content,
    [Parameter(Mandatory = $true)][string]$ExpectedSha256,
    [ValidateSet('','after_prepared','after_backup','after_publish','before_commit','after_approval_consumed')][string]$FailurePoint = ''
  )
  $approval = Test-HebriScopedApproval -Descriptor $Descriptor -ApprovalId $ApprovalId -StoreRoot $ApprovalStoreRoot
  if (-not $approval.Valid) { Throw-HebriRuntimeError $approval.Reason 'publication approval rejected' }
  $lockCheck = Test-HebriOperationLock -Descriptor $Descriptor -LockPath $LockPath -ApprovalId $ApprovalId
  if (-not $lockCheck.Valid) { Throw-HebriRuntimeError $lockCheck.Reason 'publication lock rejected' }
  $target = Get-HebriFullPath $Path
  $pathComparison = if ($env:OS -eq 'Windows_NT') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
  $covered = $false
  foreach ($declared in @(Get-HebriMemberValue $Descriptor 'write_set')) {
    if ([string]::Equals((Get-HebriFullPath ([string]$declared)), $target, $pathComparison)) { $covered = $true; break }
  }
  if (-not $covered) { Throw-HebriRuntimeError 'APPROVAL_SCOPE_MISMATCH' 'single-file target is not an exact descriptor resource' }
  $approvedPreconditions = @((Get-HebriMemberValue $Descriptor 'preconditions' @()) | Where-Object {
    try { [string]::Equals((Get-HebriFullPath ([string](Get-HebriMemberValue $_ 'path'))), $target, $pathComparison) }
    catch { $false }
  })
  if ($approvedPreconditions.Count -ne 1 -or $ExpectedSha256 -ne [string](Get-HebriMemberValue $approvedPreconditions[0] 'sha256')) {
    Throw-HebriRuntimeError 'APPROVAL_SCOPE_MISMATCH' 'caller precondition differs from the approved descriptor'
  }
  $journal = Read-HebriJsonDocument $JournalPath
  $journalLockPath = [string](Get-HebriMemberValue $journal 'lock_path')
  if ([string](Get-HebriMemberValue $journal 'operation_id') -ne [string](Get-HebriMemberValue $Descriptor 'operation_id') -or
      [string](Get-HebriMemberValue $journal 'project_id') -ne [string](Get-HebriMemberValue $Descriptor 'project_id') -or
      [string](Get-HebriMemberValue $journal 'descriptor_hash') -ne [string](Get-HebriMemberValue $Descriptor 'descriptor_hash') -or
      [string](Get-HebriMemberValue $journal 'approval_id') -ne $ApprovalId -or
      -not [string]::Equals((Get-HebriFullPath $journalLockPath), (Get-HebriFullPath $LockPath), $pathComparison)) {
    Throw-HebriRuntimeError 'APPROVAL_SCOPE_MISMATCH' 'publication journal is not bound to descriptor, approval and lock'
  }
  if ([string](Get-HebriMemberValue $journal 'state') -ne 'prepared') { Throw-HebriRuntimeError 'RECOVERY_REQUIRED' 'publication requires a prepared journal' }
  Invoke-HebriFixtureTermination -Descriptor $Descriptor -FailurePoint $FailurePoint -CurrentPoint 'after_prepared'
  [void](Set-HebriOperationJournalState -JournalPath $JournalPath -State applying -Evidence 'publication started')

  $actualBefore = Get-HebriFileSha256 $target
  if ($actualBefore -ne $ExpectedSha256) {
    [void](Set-HebriOperationJournalState -JournalPath $JournalPath -State rolling_back -Evidence 'precondition changed before backup')
    [void](Set-HebriOperationJournalState -JournalPath $JournalPath -State rolled_back -Evidence 'no business write occurred')
    Throw-HebriRuntimeError 'PRECONDITION_CHANGED' 'target hash changed before publication'
  }
  $journal = Read-HebriJsonDocument $JournalPath
  $backupRoot = Join-Path (Split-Path -Parent $JournalPath) ('backups/' + [string](Get-HebriMemberValue $Descriptor 'operation_id'))
  [void][IO.Directory]::CreateDirectory($backupRoot)
  $backupPath = Join-Path $backupRoot ([IO.Path]::GetFileName($target) + '.bak')
  $originalExisted = $actualBefore -ne $script:HebriMissingHash
  if ($originalExisted) { [IO.File]::Copy($target, $backupPath, $true) }
  $journal.resources = @([pscustomobject]@{
    path = $target
    expected_before_sha256 = $ExpectedSha256
    original_existed = $originalExisted
    backup_path = if ($originalExisted) { $backupPath } else { '' }
    published_sha256 = ''
  })
  $journal.stage = 'backup_confirmed'
  Write-HebriAtomicJsonDocument -Path $JournalPath -Value $journal
  Invoke-HebriFixtureTermination -Descriptor $Descriptor -FailurePoint $FailurePoint -CurrentPoint 'after_backup'

  $parent = Split-Path -Parent $target
  [void][IO.Directory]::CreateDirectory($parent)
  $temp = Join-Path $parent ('.' + [IO.Path]::GetFileName($target) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
  try {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($Content -replace "`r`n", "`n"))
    $stream = [IO.File]::Open($temp, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) }
    finally { $stream.Dispose() }
    if ((Get-HebriFileSha256 $target) -ne $ExpectedSha256) { Throw-HebriRuntimeError 'PRECONDITION_CHANGED' 'target hash changed immediately before commit' }
    if ($originalExisted) {
      $replaceBackup = Join-Path $parent ('.replace-' + [guid]::NewGuid().ToString('N') + '.bak')
      [IO.File]::Replace($temp, $target, $replaceBackup)
      if (Test-Path -LiteralPath $replaceBackup -PathType Leaf) { [IO.File]::Delete($replaceBackup) }
    }
    else { [IO.File]::Move($temp, $target) }
  }
  catch {
    if (Test-Path -LiteralPath $temp -PathType Leaf) { [IO.File]::Delete($temp) }
    $currentJournal = Read-HebriJsonDocument $JournalPath
    if ([string](Get-HebriMemberValue $currentJournal 'state') -eq 'applying') { [void](Set-HebriOperationJournalState -JournalPath $JournalPath -State recovery_required -Evidence $_.Exception.Message) }
    if ($_.Exception.Message -match '^PRECONDITION_CHANGED:') { throw }
    Throw-HebriRuntimeError 'RECOVERY_REQUIRED' ('publication failed after preparation: ' + $_.Exception.Message)
  }
  $journal = Read-HebriJsonDocument $JournalPath
  $journal.resources[0].published_sha256 = Get-HebriFileSha256 $target
  $journal.stage = 'published'
  Write-HebriAtomicJsonDocument -Path $JournalPath -Value $journal
  Invoke-HebriFixtureTermination -Descriptor $Descriptor -FailurePoint $FailurePoint -CurrentPoint 'after_publish'
  Invoke-HebriFixtureTermination -Descriptor $Descriptor -FailurePoint $FailurePoint -CurrentPoint 'before_commit'
  try {
    [void](Set-HebriScopedApprovalConsumed -Descriptor $Descriptor -ApprovalId $ApprovalId -StoreRoot $ApprovalStoreRoot)
    Invoke-HebriFixtureTermination -Descriptor $Descriptor -FailurePoint $FailurePoint -CurrentPoint 'after_approval_consumed'
    [void](Set-HebriOperationJournalState -JournalPath $JournalPath -State committed -Evidence 'target publication, hash and approval consumption confirmed')
  }
  catch {
    $commitError = $_
    try {
      $currentJournal = Read-HebriJsonDocument $JournalPath
      if ([string](Get-HebriMemberValue $currentJournal 'state') -eq 'applying') {
        [void](Set-HebriOperationJournalState -JournalPath $JournalPath -State recovery_required -Evidence $commitError.Exception.Message)
      }
    }
    catch { }
    Throw-HebriRuntimeError 'RECOVERY_REQUIRED' ('publication could not complete durable approval consumption: ' + $commitError.Exception.Message)
  }
  return [pscustomobject]@{
    schema = 'hebrinex.operation_result'
    contract_version = $script:HebriOperationContractVersion
    runtime_api = $script:HebriOperationApi
    operation_id = [string](Get-HebriMemberValue $Descriptor 'operation_id')
    final_state = 'committed'
    changed_resources = @($target)
    evidence_path = $JournalPath
    recovery_required = $false
  }
}

function Get-HebriOperationStatus {
  param([Parameter(Mandatory = $true)][string]$JournalPath)
  $journal = Read-HebriJsonDocument $JournalPath
  $state = [string](Get-HebriMemberValue $journal 'state')
  $effective = $state
  $ownerStatus = 'not_applicable'
  if ($state -in @('prepared','applying','rolling_back')) {
    $lockPath = [string](Get-HebriMemberValue $journal 'lock_path')
    if (Test-Path -LiteralPath $lockPath -PathType Leaf) {
      $lock = Read-HebriJsonDocument $lockPath
      $ownerStatus = Get-HebriLockOwnerStatus $lock
      if ($ownerStatus -ne 'live') { $effective = 'recovery_required' }
    }
    else { $ownerStatus = 'missing'; $effective = 'recovery_required' }
  }
  return [pscustomobject]@{
    operation_id = [string](Get-HebriMemberValue $journal 'operation_id')
    stored_state = $state
    effective_state = $effective
    owner_status = $ownerStatus
    writes = $false
  }
}

function Invoke-HebriOperationRecovery {
  param(
    [Parameter(Mandatory = $true)][object]$RecoveryDescriptor,
    [Parameter(Mandatory = $true)][string]$ApprovalId,
    [string]$ApprovalStoreRoot = '',
    [Parameter(Mandatory = $true)][string]$JournalPath
  )
  $approval = Test-HebriScopedApproval -Descriptor $RecoveryDescriptor -ApprovalId $ApprovalId -StoreRoot $ApprovalStoreRoot -AllowConsumed
  if (-not $approval.Valid) { Throw-HebriRuntimeError $approval.Reason 'recovery approval rejected' }
  $journal = Read-HebriJsonDocument $JournalPath
  $originalOperationId = [string](Get-HebriMemberValue $journal 'operation_id')
  if ([string](Get-HebriMemberValue $RecoveryDescriptor 'operation') -ne ('recover:' + $originalOperationId)) { Throw-HebriRuntimeError 'APPROVAL_SCOPE_MISMATCH' 'recovery descriptor targets another operation' }
  $initialState = [string](Get-HebriMemberValue $journal 'state')
  if ($initialState -in @('committed','rolled_back')) {
    return [pscustomobject]@{
      schema = 'hebrinex.operation_result'
      contract_version = $script:HebriOperationContractVersion
      runtime_api = $script:HebriOperationApi
      operation_id = $originalOperationId
      final_state = $initialState
      changed_resources = @()
      evidence_path = $JournalPath
      recovery_required = $false
    }
  }
  if ($approval.Status -eq 'consumed') { Throw-HebriRuntimeError 'APPROVAL_SCOPE_MISMATCH' 'consumed recovery approval cannot mutate a non-terminal operation' }
  $originalLockPath = [string](Get-HebriMemberValue $journal 'lock_path')
  if (Test-Path -LiteralPath $originalLockPath -PathType Leaf) {
    $originalLock = Read-HebriJsonDocument $originalLockPath
    if ([string](Get-HebriMemberValue $originalLock 'status') -eq 'active') {
      $ownerStatus = Get-HebriLockOwnerStatus $originalLock
      if ($ownerStatus -eq 'live') { Throw-HebriRuntimeError 'LOCK_BUSY' 'original operation owner is still live' }
      [void](Set-HebriOperationLockStatus -LockPath $originalLockPath -Status recovered -RecoveryAuthorized)
    }
  }
  $recoveryLock = Enter-HebriOperationLock -Descriptor $RecoveryDescriptor -ApprovalId $ApprovalId -ApprovalStoreRoot $ApprovalStoreRoot
  try {
    $state = [string](Get-HebriMemberValue $journal 'state')
    if ($state -notin @('committed','rolled_back','recovery_required')) {
      [void](Set-HebriOperationJournalState -JournalPath $JournalPath -State recovery_required -Evidence 'orphaned process detected by approved recovery')
    }
    $journal = Read-HebriJsonDocument $JournalPath
    [void](Set-HebriOperationJournalState -JournalPath $JournalPath -State rolling_back -Evidence 'approved deterministic rollback started')
    $journal = Read-HebriJsonDocument $JournalPath
    $changed = New-Object System.Collections.Generic.List[string]
    foreach ($resource in @(Get-HebriMemberValue $journal 'resources' @()) | Where-Object { $null -ne $_ }) {
      $target = [string](Get-HebriMemberValue $resource 'path')
      $expectedBefore = [string](Get-HebriMemberValue $resource 'expected_before_sha256')
      $published = [string](Get-HebriMemberValue $resource 'published_sha256')
      $current = Get-HebriFileSha256 $target
      if ($current -ne $expectedBefore -and ([string]::IsNullOrWhiteSpace($published) -or $current -ne $published)) {
        [void](Set-HebriOperationJournalState -JournalPath $JournalPath -State recovery_required -Evidence 'target changed after interruption')
        Throw-HebriRuntimeError 'PRECONDITION_CHANGED' 'recovery target changed after interruption'
      }
      if ([bool](Get-HebriMemberValue $resource 'original_existed' $false)) {
        $backup = [string](Get-HebriMemberValue $resource 'backup_path')
        if (-not (Test-Path -LiteralPath $backup -PathType Leaf)) { Throw-HebriRuntimeError 'RECOVERY_REQUIRED' 'required backup is missing' }
        $temp = Join-Path (Split-Path -Parent $target) ('.recovery-' + [guid]::NewGuid().ToString('N') + '.tmp')
        [IO.File]::Copy($backup, $temp, $false)
        if (Test-Path -LiteralPath $target -PathType Leaf) {
          $replaceBackup = Join-Path (Split-Path -Parent $target) ('.replace-' + [guid]::NewGuid().ToString('N') + '.bak')
          [IO.File]::Replace($temp, $target, $replaceBackup)
          if (Test-Path -LiteralPath $replaceBackup -PathType Leaf) { [IO.File]::Delete($replaceBackup) }
        }
        else { [IO.File]::Move($temp, $target) }
      }
      elseif (Test-Path -LiteralPath $target -PathType Leaf) { [IO.File]::Delete($target) }
      [void]$changed.Add($target)
    }
    [void](Set-HebriScopedApprovalConsumed -Descriptor $RecoveryDescriptor -ApprovalId $ApprovalId -StoreRoot $ApprovalStoreRoot)
    [void](Set-HebriOperationJournalState -JournalPath $JournalPath -State rolled_back -Evidence 'backup or original absence restored and recovery approval consumed')
    return [pscustomobject]@{
      schema = 'hebrinex.operation_result'
      contract_version = $script:HebriOperationContractVersion
      runtime_api = $script:HebriOperationApi
      operation_id = $originalOperationId
      final_state = 'rolled_back'
      changed_resources = @($changed)
      evidence_path = $JournalPath
      recovery_required = $false
    }
  }
  catch {
    $recoveryError = $_
    try {
      $currentJournal = Read-HebriJsonDocument $JournalPath
      if ([string](Get-HebriMemberValue $currentJournal 'state') -eq 'rolling_back') {
        [void](Set-HebriOperationJournalState -JournalPath $JournalPath -State recovery_required -Evidence $recoveryError.Exception.Message)
      }
    }
    catch { }
    throw $recoveryError.Exception
  }
  finally { [void](Exit-HebriOperationLock -LockPath $recoveryLock.Path) }
}

function Assert-OperationMutationAuthorized {
  param(
    [Parameter(Mandatory = $true)][ValidateSet('source_template','legacy_bound','central_instance')][string]$RuntimeMode,
    [Parameter(Mandatory = $true)][string]$ExpectedOperation,
    [string[]]$WritePaths = @(),
    [string]$DescriptorPath = '',
    [string]$ApprovalStoreRoot = '',
    [string]$ApprovalId = '',
    [string]$LockPath = '',
    [string]$JournalPath = ''
  )
  if ($RuntimeMode -ne 'central_instance') {
    return [pscustomobject]@{ Authorized = $true; Mode = $RuntimeMode; Reason = 'SOURCE_OR_LEGACY_MODE_EXPLICIT_EXCEPTION' }
  }
  foreach ($value in @($DescriptorPath,$ApprovalId,$LockPath,$JournalPath)) {
    if ([string]::IsNullOrWhiteSpace($value)) { Throw-HebriRuntimeError 'APPROVAL_REQUIRED' 'central mutation requires descriptor, approval, lock and journal' }
  }
  $descriptor = Read-HebriJsonDocument $DescriptorPath
  $descriptorCheck = Test-HebriOperationDescriptor $descriptor
  if (-not $descriptorCheck.Valid) { Throw-HebriRuntimeError $descriptorCheck.Reason 'central mutation descriptor rejected' }
  if ([string](Get-HebriMemberValue $descriptor 'operation') -ne $ExpectedOperation) { Throw-HebriRuntimeError 'APPROVAL_SCOPE_MISMATCH' 'operation name does not match writer' }
  $approval = Test-HebriScopedApproval -Descriptor $descriptor -ApprovalId $ApprovalId -StoreRoot $ApprovalStoreRoot
  if (-not $approval.Valid) { Throw-HebriRuntimeError $approval.Reason 'central mutation approval rejected' }
  $lock = Test-HebriOperationLock -Descriptor $descriptor -LockPath $LockPath -ApprovalId $ApprovalId
  if (-not $lock.Valid) { Throw-HebriRuntimeError $lock.Reason 'central mutation lock rejected' }
  foreach ($path in $WritePaths) {
    $covered = $false
    foreach ($declared in @(Get-HebriMemberValue $descriptor 'write_set')) {
      if (Test-HebriAbsolutePathOverlap -PathA ([string]$declared) -PathB ([string]$path)) { $covered = $true; break }
    }
    if (-not $covered) { Throw-HebriRuntimeError 'APPROVAL_SCOPE_MISMATCH' 'writer target is outside approved write-set' }
  }
  $journal = Read-HebriJsonDocument $JournalPath
  $pathComparison = if ($env:OS -eq 'Windows_NT') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
  if ([string](Get-HebriMemberValue $journal 'operation_id') -ne [string](Get-HebriMemberValue $descriptor 'operation_id') -or
      [string](Get-HebriMemberValue $journal 'project_id') -ne [string](Get-HebriMemberValue $descriptor 'project_id') -or
      [string](Get-HebriMemberValue $journal 'descriptor_hash') -ne [string](Get-HebriMemberValue $descriptor 'descriptor_hash') -or
      [string](Get-HebriMemberValue $journal 'approval_id') -ne $ApprovalId -or
      -not [string]::Equals((Get-HebriFullPath ([string](Get-HebriMemberValue $journal 'lock_path'))), (Get-HebriFullPath $LockPath), $pathComparison) -or
      [string](Get-HebriMemberValue $journal 'state') -ne 'applying') {
    Throw-HebriRuntimeError 'RECOVERY_REQUIRED' 'central writer requires its operation journal in applying state'
  }
  return [pscustomobject]@{ Authorized = $true; Mode = $RuntimeMode; Reason = 'CENTRAL_OPERATION_AUTHORIZED'; Descriptor = $descriptor }
}

Export-ModuleMember -Function @(
  'Resolve-HarnessPath',
  'Get-HebriInstanceRelativePath',
  'Read-HarnessText',
  'Get-Scalar',
  'Get-SectionScalar',
  'Get-YamlList',
  'Redact-Text',
  'Limit-Text',
  'Ensure-Directory',
  'Write-Utf8Text',
  'Get-Sha256Hex',
  'Get-HebriRuntimeLayout',
  'Test-HebriRuntimeInstallation',
  'Resolve-HebriRuntimeContext',
  'Resolve-HebriResourcePath',
  'Test-HebriPathContained',
  'Get-ApprovalPath',
  'New-ApprovalEnvelope',
  'Test-ApprovalEnvelope',
  'Get-LockInventory',
  'Get-NormalizedLockPath',
  'Test-LockPathOverlap',
  'Find-LockForPath',
  'New-HarnessLock',
  'Set-HarnessLockReleased',
  'ConvertTo-HebriCanonicalJson',
  'Get-HebriFileSha256',
  'New-HebriOperationDescriptor',
  'Test-HebriOperationDescriptor',
  'Get-HebriOperationDescriptorHash',
  'Write-HebriAtomicJsonDocument',
  'Read-HebriJsonDocument',
  'New-HebriScopedApprovalEnvelope',
  'Test-HebriScopedApproval',
  'Enter-HebriOperationLock',
  'Test-HebriOperationLock',
  'Get-HebriLockOwnerStatus',
  'Exit-HebriOperationLock',
  'New-HebriOperationJournal',
  'Set-HebriOperationJournalState',
  'Publish-HebriAtomicFile',
  'Get-HebriOperationStatus',
  'Invoke-HebriOperationRecovery',
  'Assert-OperationMutationAuthorized'
)
