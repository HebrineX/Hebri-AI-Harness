param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [string]$OutputPath = '',
  [switch]$Apply
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/hebri-common.psm1') -Force -DisableNameChecking

function Get-P06FullPath([string]$Path) { return [IO.Path]::GetFullPath($Path) }

function Test-P06SafeRelativePath([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path) -or $Path -ne $Path.Trim() -or [IO.Path]::IsPathRooted($Path) -or $Path.Contains('\') -or $Path.Contains(':')) { return $false }
  foreach ($segment in ($Path -split '/')) { if ([string]::IsNullOrWhiteSpace($segment) -or $segment -in @('.','..')) { return $false } }
  return $true
}

function Test-P06PersonalPath([string]$Path) {
  $normalized = $Path.ToLowerInvariant()
  $name = [IO.Path]::GetFileName($normalized)
  return ($normalized -in @('infohebri.md','infohebriharness.md') -or $name -eq '.env' -or
    $name -match '(credential|secret|token|password)' -or $name -match '[.](pem|key|pfx|p12)$' -or
    $name -match '^id_(rsa|ed25519)')
}

function Assert-P06RegularPath([string]$SourceRoot, [string]$Path) {
  $source = Get-P06FullPath $SourceRoot
  $full = Get-P06FullPath $Path
  $prefix = $source.TrimEnd('\') + '\'
  if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "SOURCE_PATH_OUTSIDE_ROOT: $full" }
  $item = Get-Item -LiteralPath $full -Force
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "REPARSE_POINT_UNSUPPORTED: $($item.FullName)" }
  $parent = $item.Directory
  while ($null -ne $parent -and -not [string]::Equals($parent.FullName.TrimEnd('\'), $source.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
    if (($parent.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "REPARSE_POINT_UNSUPPORTED: $($parent.FullName)" }
    $parent = $parent.Parent
  }
}

function Get-P06Rule([object]$Layout, [string]$LogicalPath) {
  $matches = @($Layout.rules | Where-Object {
    ($_.match -eq 'exact' -and [string]::Equals([string]$_.logical_path, $LogicalPath, [StringComparison]::OrdinalIgnoreCase)) -or
    ($_.match -eq 'prefix' -and ([string]::Equals([string]$_.logical_path, $LogicalPath, [StringComparison]::OrdinalIgnoreCase) -or
      $LogicalPath.StartsWith(([string]$_.logical_path).TrimEnd('/') + '/', [StringComparison]::OrdinalIgnoreCase)))
  } | Sort-Object @{Expression={ if ($_.match -eq 'exact') { 1 } else { 0 } };Descending=$true}, @{Expression={ ([string]$_.logical_path).Length };Descending=$true})
  if ($matches.Count -eq 0) { return [pscustomobject]@{ id = 'DEFAULT-DENY'; class = [string]$Layout.default_class; root = 'none'; target_path = '' } }
  return $matches[0]
}

function Get-P06TargetPath([object]$Rule, [string]$LogicalPath) {
  if ($Rule.match -eq 'exact') { return [string]$Rule.target_path }
  $base = ([string]$Rule.logical_path).TrimEnd('/')
  $suffix = $LogicalPath.Substring($base.Length).TrimStart('/')
  if ([string]::IsNullOrWhiteSpace($suffix)) { return [string]$Rule.target_path }
  return (([string]$Rule.target_path).TrimEnd('/') + '/' + $suffix)
}

function Get-P06ManifestPaths([string]$ManifestPath) {
  $paths = New-Object Collections.Generic.List[string]
  $seen = @{}
  foreach ($line in [IO.File]::ReadAllLines($ManifestPath)) {
    if ($line -notmatch '^file\s+(.+?)\s*$') { continue }
    $path = ($Matches[1] -replace '\\','/').Trim()
    if (-not (Test-P06SafeRelativePath $path)) { throw "STRUCTURAL_MANIFEST_UNSAFE_PATH: $path" }
    $key = $path.ToLowerInvariant()
    if ($seen.ContainsKey($key)) { throw "STRUCTURAL_MANIFEST_DUPLICATE: $path" }
    $seen[$key] = $true
    [void]$paths.Add($path)
  }
  if ($paths.Count -eq 0) { throw 'STRUCTURAL_MANIFEST_EMPTY' }
  return @($paths)
}

function Get-P06TreeHash([object[]]$Files) {
  $canonical = @($Files | Sort-Object path | ForEach-Object {
    [ordered]@{ path = [string]$_.path; class = [string]$_.class; size = [int64]$_.size; sha256 = [string]$_.sha256 }
  })
  $bytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-HebriCanonicalJson $canonical))
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '') }
  finally { $sha.Dispose() }
}

$Root = Get-P06FullPath $Root
$artifactRoot = Get-P06FullPath (Join-Path $Root 'artifacts/p06')
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $artifactRoot 'payload-core' }
$OutputPath = Get-P06FullPath $OutputPath
$artifactPrefix = $artifactRoot.TrimEnd('\') + '\'
if (-not $OutputPath.StartsWith($artifactPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'OUTPUT_OUTSIDE_ARTIFACT_ROOT' }

$manifestPath = Join-Path $Root 'orquestador/harness-manifest.txt'
$layoutPath = Join-Path $Root 'packaging/runtime-layout.json'
$releasePath = Join-Path $Root 'packaging/release.json'
foreach ($required in @($manifestPath,$layoutPath,$releasePath)) { if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "PACKAGING_INPUT_MISSING: $required" } }
$layout = Get-HebriRuntimeLayout -InstallRoot $Root
$manifestPaths = @(Get-P06ManifestPaths $manifestPath)
$manifestSet = @{}
foreach ($path in $manifestPaths) { $manifestSet[$path.ToLowerInvariant()] = $true }

$sourceFiles = @()
$excludedPersonal = New-Object Collections.Generic.List[string]
foreach ($file in @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force)) {
  $relative = $file.FullName.Substring($Root.TrimEnd('\').Length + 1).Replace('\','/')
  if ($relative -eq 'artifacts' -or $relative.StartsWith('artifacts/') -or
      $relative -eq '.git' -or $relative.StartsWith('.git/') -or
      $relative -eq '.codex' -or $relative.StartsWith('.codex/') -or
      $relative -eq 'mcp/node_modules' -or $relative.StartsWith('mcp/node_modules/')) { continue }
  $rule = Get-P06Rule -Layout $layout -LogicalPath $relative
  if ($rule.class -in @('product','template')) {
    if (-not $manifestSet.ContainsKey($relative.ToLowerInvariant())) { $sourceFiles += $relative }
  }
  elseif (Test-P06PersonalPath $relative) {
    if ($manifestSet.ContainsKey($relative.ToLowerInvariant())) { throw "DECLARED_PERSONAL_PATH: $relative" }
    [void]$excludedPersonal.Add($relative)
  }
}
if ($sourceFiles.Count -gt 0) { throw ('STRUCTURAL_MANIFEST_INCOMPLETE: ' + (($sourceFiles | Sort-Object) -join ', ')) }

$copyPlan = New-Object Collections.Generic.List[object]
$targets = @{}
foreach ($logicalPath in $manifestPaths) {
  $sourcePath = Join-Path $Root ($logicalPath -replace '/', [IO.Path]::DirectorySeparatorChar)
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "STRUCTURAL_MANIFEST_SOURCE_MISSING: $logicalPath" }
  Assert-P06RegularPath -SourceRoot $Root -Path $sourcePath
  $rule = Get-P06Rule -Layout $layout -LogicalPath $logicalPath
  if ($rule.class -notin @('product','template')) { continue }
  $target = Get-P06TargetPath -Rule $rule -LogicalPath $logicalPath
  if (-not (Test-P06SafeRelativePath $target)) { throw "PAYLOAD_TARGET_UNSAFE: $target" }
  $key = $target.ToLowerInvariant()
  if ($targets.ContainsKey($key)) { throw "PAYLOAD_TARGET_DUPLICATE: $target" }
  $targets[$key] = $true
  [void]$copyPlan.Add([pscustomobject]@{ source_path = $logicalPath; path = $target; class = [string]$rule.class; full_path = $sourcePath })
}
foreach ($requiredLogical in @('packaging/runtime-layout.json','packaging/release.json','scripts/hebrinex-central.ps1')) {
  if (-not @($copyPlan | Where-Object { $_.source_path -eq $requiredLogical }).Count) { throw "REQUIRED_PRODUCT_NOT_SELECTED: $requiredLogical" }
}

$plan = [ordered]@{
  output = $OutputPath
  source_manifest = $manifestPath
  source_manifest_sha256 = Get-HebriFileSha256 $manifestPath
  layout_sha256 = Get-HebriFileSha256 $layoutPath
  selected_files = $copyPlan.Count
  generated_files = 2
  excluded_personal_paths = $excludedPersonal.Count
  writes_performed = $false
}
if (-not $Apply) { return [pscustomobject]$plan }

[void][IO.Directory]::CreateDirectory($artifactRoot)
$stage = Join-Path $artifactRoot ('.stage-payload-' + [guid]::NewGuid().ToString('N'))
$backup = $OutputPath + '.old-' + [guid]::NewGuid().ToString('N')
try {
  [void][IO.Directory]::CreateDirectory($stage)
  foreach ($item in $copyPlan) {
    $destination = Join-Path $stage ($item.path -replace '/', [IO.Path]::DirectorySeparatorChar)
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
    [IO.File]::Copy($item.full_path, $destination, $false)
    if ((Get-HebriFileSha256 $destination) -ne (Get-HebriFileSha256 $item.full_path)) { throw "PAYLOAD_COPY_HASH_MISMATCH: $($item.source_path)" }
  }

  $launcherPath = Join-Path $stage 'bin/hebrinex.exe'
  $launcher = & (Join-Path $Root 'scripts/build-launcher.ps1') -Root $Root -OutputPath $launcherPath -Apply
  if (-not $launcher.writes_performed) { throw 'LAUNCHER_BUILD_FAILED' }

  $entries = New-Object Collections.Generic.List[object]
  foreach ($item in $copyPlan) {
    $destination = Join-Path $stage ($item.path -replace '/', [IO.Path]::DirectorySeparatorChar)
    $file = Get-Item -LiteralPath $destination
    [void]$entries.Add([pscustomobject][ordered]@{
      path = $item.path
      source_path = $item.source_path
      class = $item.class
      size = [int64]$file.Length
      sha256 = Get-HebriFileSha256 $destination
    })
  }
  $launcherFile = Get-Item -LiteralPath $launcherPath
  [void]$entries.Add([pscustomobject][ordered]@{
    path = 'bin/hebrinex.exe'
    source_path = '@generated/launcher'
    class = 'generated'
    size = [int64]$launcherFile.Length
    sha256 = Get-HebriFileSha256 $launcherPath
  })
  $entries = @($entries | Sort-Object path)
  $payloadManifest = [ordered]@{
    schema = 'hebrinex.payload_manifest'
    schema_version = 1
    harness_version = [IO.File]::ReadAllText((Join-Path $Root 'HARNESS_VERSION')).Trim()
    runtime_api = [string]$layout.runtime_api
    architecture = 'x64'
    source_manifest_sha256 = Get-HebriFileSha256 $manifestPath
    layout_sha256 = Get-HebriFileSha256 $layoutPath
    tree_sha256 = Get-P06TreeHash $entries
    features = [ordered]@{ core = $true; mcp = $false }
    files = $entries
  }
  Write-HebriAtomicJsonDocument -Path (Join-Path $stage 'payload-manifest.json') -Value $payloadManifest

  if (Test-Path -LiteralPath $OutputPath -PathType Container) { [IO.Directory]::Move($OutputPath, $backup) }
  try { [IO.Directory]::Move($stage, $OutputPath) }
  catch {
    if (Test-Path -LiteralPath $backup -PathType Container) { [IO.Directory]::Move($backup, $OutputPath) }
    throw
  }
  if (Test-Path -LiteralPath $backup -PathType Container) { Remove-Item -LiteralPath $backup -Recurse -Force }
}
finally {
  if (Test-Path -LiteralPath $stage -PathType Container) { Remove-Item -LiteralPath $stage -Recurse -Force }
}

$plan.writes_performed = $true
$plan.payload_tree_sha256 = $payloadManifest.tree_sha256
$plan.file_count = @($payloadManifest.files).Count
$plan.payload_manifest_sha256 = Get-HebriFileSha256 (Join-Path $OutputPath 'payload-manifest.json')
return [pscustomobject]$plan
