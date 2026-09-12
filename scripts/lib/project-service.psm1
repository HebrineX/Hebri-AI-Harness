# project-service.psm1 - Central project binding and recoverable catalog service.
# Compatible with Windows PowerShell 5.1 and PowerShell 7+.

Set-StrictMode -Version 2.0

Import-Module (Join-Path $PSScriptRoot 'hebri-common.psm1') -Force -DisableNameChecking -Scope Local

$script:ProjectServiceContract = '1.0.0'
$script:ProjectServiceApi = 'central1'
$script:ProjectServiceCodeVersion = 'central1'
$script:MinimumEngineVersion = '0.17.1'

function Get-ProjectMemberValue {
  param([AllowNull()]$Object, [Parameter(Mandatory = $true)][string]$Name, [AllowNull()]$Default = $null)
  if ($null -eq $Object) { return $Default }
  if ($Object -is [System.Collections.IDictionary]) {
    if ($Object.Contains($Name)) { return $Object[$Name] }
    return $Default
  }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $Default }
  return $property.Value
}

function Get-ProjectFullPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { throw 'PROJECT_NOT_FOUND: empty path' }
  $full = [IO.Path]::GetFullPath($Path)
  $root = [IO.Path]::GetPathRoot($full)
  if ($full -eq $root) { return $full }
  return $full.TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
}

function Test-ProjectPathEqual {
  param([Parameter(Mandatory = $true)][string]$Left, [Parameter(Mandatory = $true)][string]$Right)
  return [string]::Equals((Get-ProjectFullPath $Left), (Get-ProjectFullPath $Right), [StringComparison]::OrdinalIgnoreCase)
}

function Assert-ProjectNoReparsePath {
  param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Candidate)
  $rootFull = Get-ProjectFullPath $Root
  $candidateFull = Get-ProjectFullPath $Candidate
  if (-not (Test-HebriPathContained -Root $rootFull -Candidate $candidateFull)) { throw 'PATH_OUTSIDE_ROOT: candidate is outside declared root' }
  $relative = $candidateFull.Substring($rootFull.Length).TrimStart('\','/')
  $current = $rootFull
  $parts = if ([string]::IsNullOrWhiteSpace($relative)) { @() } else { @($relative -split '[\\/]') }
  foreach ($part in @('') + $parts) {
    if (-not [string]::IsNullOrWhiteSpace($part)) { $current = Join-Path $current $part }
    if (-not (Test-Path -LiteralPath $current)) { continue }
    $item = Get-Item -LiteralPath $current -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'REPARSE_POINT_UNSUPPORTED: project service paths cannot traverse reparse points' }
  }
}

function Get-ProjectDefaultCatalogRoot {
  $local = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
  if ([string]::IsNullOrWhiteSpace($local)) { throw 'PROJECT_NOT_FOUND: LocalApplicationData is unavailable; supply CatalogRoot' }
  return (Join-Path $local 'Hebri-AI-Harness')
}

function Resolve-ProjectRoots {
  param(
    [Parameter(Mandatory = $true)][string]$InstallRoot,
    [string]$ProjectRoot = '',
    [string]$CatalogRoot = ''
  )
  $runtime = Test-HebriRuntimeInstallation -InstallRoot $InstallRoot
  if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot = (Get-Location).Path }
  if ([string]::IsNullOrWhiteSpace($CatalogRoot)) { $CatalogRoot = Get-ProjectDefaultCatalogRoot }
  $projectFull = Get-ProjectFullPath $ProjectRoot
  $catalogFull = Get-ProjectFullPath $CatalogRoot
  if (-not (Test-Path -LiteralPath $projectFull -PathType Container)) { throw 'PROJECT_NOT_FOUND: explicit ProjectRoot does not exist' }
  if ((Test-HebriPathContained -Root $runtime.InstallRoot -Candidate $projectFull) -or
      (Test-HebriPathContained -Root $projectFull -Candidate $runtime.InstallRoot)) {
    throw 'PROJECT_NOT_FOUND: ProjectRoot must not overlap trusted InstallRoot'
  }
  if ((Test-HebriPathContained -Root $catalogFull -Candidate $projectFull) -or
      (Test-HebriPathContained -Root $projectFull -Candidate $catalogFull) -or
      (Test-HebriPathContained -Root $catalogFull -Candidate $runtime.InstallRoot) -or
      (Test-HebriPathContained -Root $runtime.InstallRoot -Candidate $catalogFull)) {
    throw 'PROJECT_NOT_FOUND: CatalogRoot must not overlap ProjectRoot or InstallRoot'
  }
  $projectItem = Get-Item -LiteralPath $projectFull -Force
  if (($projectItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'PROJECT_NOT_FOUND: ProjectRoot cannot be a reparse point' }
  Assert-ProjectNoReparsePath -Root $projectFull -Candidate (Join-Path $projectFull '.hebrinex\instance\runtime')
  Assert-ProjectNoReparsePath -Root $catalogFull -Candidate (Join-Path $catalogFull 'projects')
  return [pscustomobject]@{
    InstallRoot = Get-ProjectFullPath $runtime.InstallRoot
    ProjectRoot = $projectFull
    InstanceRoot = Join-Path $projectFull '.hebrinex\instance'
    CatalogRoot = $catalogFull
    HarnessVersion = [string]$runtime.HarnessVersion
  }
}

function Get-ProjectPaths {
  param([Parameter(Mandatory = $true)]$Roots, [string]$ProjectId = '')
  $paths = [ordered]@{
    Binding = Join-Path $Roots.ProjectRoot '.hebrinex\binding.json'
    LegacyRootBinding = Join-Path $Roots.ProjectRoot '.hebrinex\PROJECT_BINDING.yaml'
    LegacyInstanceBinding = Join-Path $Roots.ProjectRoot '.hebrinex\instance\PROJECT_BINDING.yaml'
    Instance = Join-Path $Roots.InstanceRoot 'instance.json'
    Registration = Join-Path $Roots.InstanceRoot 'registration.json'
    GitIgnore = Join-Path $Roots.ProjectRoot '.gitignore'
  }
  if (-not [string]::IsNullOrWhiteSpace($ProjectId)) {
    $paths.Catalog = Join-Path $Roots.CatalogRoot ("projects\$ProjectId.json")
  }
  return [pscustomobject]$paths
}

function Test-ClosedProperties {
  param([AllowNull()]$Value, [string[]]$Allowed, [string[]]$Required)
  if ($null -eq $Value) { return $false }
  $names = if ($Value -is [System.Collections.IDictionary]) { @($Value.Keys) } else { @($Value.PSObject.Properties.Name) }
  foreach ($name in $names) { if ($name -notin $Allowed) { return $false } }
  foreach ($name in $Required) { if ($name -notin $names) { return $false } }
  return $true
}

function Read-ProjectJson {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  try { return ([IO.File]::ReadAllText($Path) | ConvertFrom-Json) }
  catch { return $null }
}

function Test-ProjectBindingDocument {
  param([AllowNull()]$Binding, [Parameter(Mandatory = $true)][string]$ExpectedRoot, [string]$HarnessVersion = '', [switch]$AllowMoved)
  $result = [ordered]@{ Valid = $false; Reason = 'BINDING_SCHEMA_UNSUPPORTED'; Moved = $false; Binding = $Binding }
  $allowed = @('schema','schema_version','project_id','instance_id','project_root','layout','instance_relative_path','required_engine','state_schema_version','last_verified_engine_version','created_at','updated_at')
  $required = @('schema','schema_version','project_id','instance_id','project_root','layout','instance_relative_path','required_engine','state_schema_version','created_at','updated_at')
  if (-not (Test-ClosedProperties -Value $Binding -Allowed $allowed -Required $required)) { return [pscustomobject]$result }
  $engine = Get-ProjectMemberValue $Binding 'required_engine'
  if (-not (Test-ClosedProperties -Value $engine -Allowed @('api_line','minimum_engine_version') -Required @('api_line','minimum_engine_version'))) { return [pscustomobject]$result }
  if ([string](Get-ProjectMemberValue $Binding 'schema') -ne 'hebrinex.binding' -or
      [int](Get-ProjectMemberValue $Binding 'schema_version' 0) -ne 1 -or
      [string](Get-ProjectMemberValue $Binding 'project_id') -notmatch '^PRJ-[a-f0-9]{32}$' -or
      [string](Get-ProjectMemberValue $Binding 'instance_id') -notmatch '^INST-[a-f0-9]{32}$' -or
      [string](Get-ProjectMemberValue $Binding 'layout') -ne 'central_instance' -or
      (([string](Get-ProjectMemberValue $Binding 'instance_relative_path')) -replace '\\','/') -ne '.hebrinex/instance' -or
      [string](Get-ProjectMemberValue $engine 'api_line') -ne '1' -or
      [string](Get-ProjectMemberValue $engine 'minimum_engine_version') -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$' -or
      [int](Get-ProjectMemberValue $Binding 'state_schema_version' 0) -ne 1) { return [pscustomobject]$result }
  if (-not [IO.Path]::IsPathRooted([string](Get-ProjectMemberValue $Binding 'project_root'))) { return [pscustomobject]$result }
  if (-not [string]::IsNullOrWhiteSpace($HarnessVersion)) {
    try { if ([version]$HarnessVersion -lt [version][string](Get-ProjectMemberValue $engine 'minimum_engine_version')) { return [pscustomobject]$result } }
    catch { return [pscustomobject]$result }
  }
  try { $bindingRoot = Get-ProjectFullPath ([string](Get-ProjectMemberValue $Binding 'project_root')) }
  catch { return [pscustomobject]$result }
  if (-not (Test-ProjectPathEqual -Left $bindingRoot -Right $ExpectedRoot)) {
    $result.Moved = $true
    $result.Reason = 'PROJECT_MOVED'
    if (-not $AllowMoved) { return [pscustomobject]$result }
  }
  $result.Valid = $true
  $result.Reason = if ($result.Moved) { 'PROJECT_MOVED' } else { 'BINDING_VALID' }
  return [pscustomobject]$result
}

function Test-ProjectInstanceDocument {
  param([AllowNull()]$Value, [string]$ProjectId, [string]$InstanceId)
  if (-not (Test-ClosedProperties -Value $Value -Allowed @('schema','schema_version','project_id','instance_id','lifecycle_state','state_schema_version','created_at','updated_at') -Required @('schema','schema_version','project_id','instance_id','lifecycle_state','state_schema_version','created_at','updated_at'))) { return $false }
  return [string](Get-ProjectMemberValue $Value 'schema') -eq 'hebrinex.project_instance' -and
    [int](Get-ProjectMemberValue $Value 'schema_version' 0) -eq 1 -and
    [string](Get-ProjectMemberValue $Value 'project_id') -eq $ProjectId -and
    [string](Get-ProjectMemberValue $Value 'instance_id') -eq $InstanceId -and
    [string](Get-ProjectMemberValue $Value 'lifecycle_state') -in @('pending','active','unbound') -and
    [int](Get-ProjectMemberValue $Value 'state_schema_version' 0) -eq 1
}

function Test-ProjectRegistrationDocument {
  param([AllowNull()]$Value, [string]$ProjectId)
  if (-not (Test-ClosedProperties -Value $Value -Allowed @('schema','schema_version','project_id','status','catalog_entry_relative_path','last_error','updated_at') -Required @('schema','schema_version','project_id','status','catalog_entry_relative_path','updated_at'))) { return $false }
  return [string](Get-ProjectMemberValue $Value 'schema') -eq 'hebrinex.project_registration' -and
    [int](Get-ProjectMemberValue $Value 'schema_version' 0) -eq 1 -and
    [string](Get-ProjectMemberValue $Value 'project_id') -eq $ProjectId -and
    [string](Get-ProjectMemberValue $Value 'status') -in @('pending','registered','unbinding','unbound') -and
    [string](Get-ProjectMemberValue $Value 'catalog_entry_relative_path') -eq "projects/$ProjectId.json"
}

function Test-ProjectCatalogDocument {
  param([AllowNull()]$Value, [string]$ProjectId = '')
  if (-not (Test-ClosedProperties -Value $Value -Allowed @('schema','schema_version','project_id','instance_id','project_root','binding_schema_version','state','observed_at','source') -Required @('schema','schema_version','project_id','instance_id','project_root','binding_schema_version','state','observed_at','source'))) { return $false }
  if ([string](Get-ProjectMemberValue $Value 'schema') -ne 'hebrinex.project_catalog_entry' -or
      [int](Get-ProjectMemberValue $Value 'schema_version' 0) -ne 1 -or
      [string](Get-ProjectMemberValue $Value 'project_id') -notmatch '^PRJ-[a-f0-9]{32}$' -or
      [string](Get-ProjectMemberValue $Value 'instance_id') -notmatch '^INST-[a-f0-9]{32}$' -or
      [int](Get-ProjectMemberValue $Value 'binding_schema_version' 0) -ne 1 -or
      [string](Get-ProjectMemberValue $Value 'state') -notin @('active','unbound') -or
      [string](Get-ProjectMemberValue $Value 'source') -ne 'validated_binding') { return $false }
  if (-not [IO.Path]::IsPathRooted([string](Get-ProjectMemberValue $Value 'project_root'))) { return $false }
  return [string]::IsNullOrWhiteSpace($ProjectId) -or [string](Get-ProjectMemberValue $Value 'project_id') -eq $ProjectId
}

function New-ProjectResult {
  param(
    [Parameter(Mandatory = $true)][string]$Command,
    [Parameter(Mandatory = $true)][string]$Status,
    [Parameter(Mandatory = $true)][string]$Reason,
    [int]$ExitCode = 0,
    [bool]$WritesPerformed = $false,
    [string]$ProjectId = '',
    [object]$Details = $null,
    [string]$NextStep = ''
  )
  if ($null -eq $Details) { $Details = [ordered]@{} }
  $result = [ordered]@{
    schema = 'hebrinex.project_service.result'
    contract_version = $script:ProjectServiceContract
    cli_api = $script:ProjectServiceApi
    command = $Command
    status = $Status
    reason = $Reason
    exit_code = $ExitCode
    writes_performed = $WritesPerformed
    observed_at = (Get-Date).ToUniversalTime().ToString('o')
    details = $Details
    next_step = $NextStep
  }
  if (-not [string]::IsNullOrWhiteSpace($ProjectId)) { $result.project_id = $ProjectId }
  return [pscustomobject]$result
}

function New-ProjectIdentityDocuments {
  param([string]$ProjectId, [string]$InstanceId, [string]$ProjectRoot, [string]$HarnessVersion, [string]$Timestamp)
  $binding = [ordered]@{
    schema = 'hebrinex.binding'; schema_version = 1; project_id = $ProjectId; instance_id = $InstanceId
    project_root = $ProjectRoot; layout = 'central_instance'; instance_relative_path = '.hebrinex/instance'
    required_engine = [ordered]@{ api_line = '1'; minimum_engine_version = $script:MinimumEngineVersion }
    state_schema_version = 1; last_verified_engine_version = $HarnessVersion; created_at = $Timestamp; updated_at = $Timestamp
  }
  $instance = [ordered]@{
    schema = 'hebrinex.project_instance'; schema_version = 1; project_id = $ProjectId; instance_id = $InstanceId
    lifecycle_state = 'pending'; state_schema_version = 1; created_at = $Timestamp; updated_at = $Timestamp
  }
  $registration = [ordered]@{
    schema = 'hebrinex.project_registration'; schema_version = 1; project_id = $ProjectId; status = 'pending'
    catalog_entry_relative_path = "projects/$ProjectId.json"; updated_at = $Timestamp
  }
  $catalog = [ordered]@{
    schema = 'hebrinex.project_catalog_entry'; schema_version = 1; project_id = $ProjectId; instance_id = $InstanceId
    project_root = $ProjectRoot; binding_schema_version = 1; state = 'active'; observed_at = $Timestamp; source = 'validated_binding'
  }
  return [pscustomobject]@{ Binding = $binding; Instance = $instance; Registration = $registration; Catalog = $catalog }
}

function Test-GitIgnoreContainsInstanceRule {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
  foreach ($line in ([IO.File]::ReadAllLines($Path))) {
    $trimmed = $line.Trim()
    if ($trimmed -in @('.hebrinex','.hebrinex/','/.hebrinex','/.hebrinex/')) { return $true }
  }
  return $false
}

function Get-GitIgnoreContent {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return ".hebrinex/`n" }
  $content = [IO.File]::ReadAllText($Path) -replace "`r`n", "`n"
  if (-not $content.EndsWith("`n")) { $content += "`n" }
  return $content + ".hebrinex/`n"
}

function New-ProjectOperationDescriptor {
  param($Roots, [string]$ProjectId, [string]$Operation, [string[]]$WriteSet, [object]$Plan)
  $context = [pscustomobject]@{
    install_root = $Roots.InstallRoot; project_root = $Roots.ProjectRoot; instance_root = $Roots.InstanceRoot
    catalog_root = $Roots.CatalogRoot; project_id = $ProjectId
  }
  return New-HebriOperationDescriptor -Context $context -Operation $Operation -WriteSet $WriteSet -CodeVersion $script:ProjectServiceCodeVersion -Plan $Plan
}

function Test-ProjectExactPathSet {
  param([string[]]$Actual, [string[]]$Expected)
  $actualNormalized = @($Actual | ForEach-Object { (Get-ProjectFullPath ([string]$_)).ToLowerInvariant() } | Sort-Object -Unique)
  $expectedNormalized = @($Expected | ForEach-Object { (Get-ProjectFullPath ([string]$_)).ToLowerInvariant() } | Sort-Object -Unique)
  if ($actualNormalized.Count -ne $expectedNormalized.Count) { return $false }
  for ($index = 0; $index -lt $actualNormalized.Count; $index++) {
    if ($actualNormalized[$index] -ne $expectedNormalized[$index]) { return $false }
  }
  return $true
}

function Test-HebriProjectServiceDescriptor {
  param([Parameter(Mandatory = $true)]$Descriptor)
  $result = [ordered]@{ Valid = $false; Reason = 'OPERATION_DESCRIPTOR_INVALID'; Roots = $null }
  $commonCheck = Test-HebriOperationDescriptor -Descriptor $Descriptor
  if (-not $commonCheck.Valid) { $result.Reason = $commonCheck.Reason; return [pscustomobject]$result }
  $plan = Get-ProjectMemberValue $Descriptor 'plan'
  $command = [string](Get-ProjectMemberValue $plan 'command')
  $action = [string](Get-ProjectMemberValue $plan 'action')
  if ($command -notin @('init','reconcile','unbind') -or [string]$Descriptor.operation -ne "project:$command" -or [string]$Descriptor.code_version -ne $script:ProjectServiceCodeVersion) {
    $result.Reason = 'APPROVAL_SCOPE_MISMATCH'; return [pscustomobject]$result
  }
  try { $roots = Resolve-ProjectRoots -InstallRoot ([string]$Descriptor.roots.install_root) -ProjectRoot ([string]$Descriptor.roots.project_root) -CatalogRoot ([string]$Descriptor.roots.catalog_root) }
  catch { $result.Reason = 'RUNTIME_NOT_INSTALLED'; return [pscustomobject]$result }
  $result.Roots = $roots
  $projectId = [string]$Descriptor.project_id
  if ([string](Get-ProjectMemberValue $plan 'project_id') -ne $projectId) { $result.Reason = 'APPROVAL_SCOPE_MISMATCH'; return [pscustomobject]$result }
  $documents = Get-ProjectMemberValue $plan 'documents'
  $paths = Get-ProjectPaths -Roots $roots -ProjectId $projectId
  $expectedWriteSet = @()

  if ($command -in @('init','reconcile')) {
    $allowedPlan = if ($command -eq 'init') { @('command','action','project_id','instance_id','include_gitignore','gitignore_content','documents') } else { @('command','action','project_id','instance_id','roots_checked','documents') }
    if (-not (Test-ClosedProperties -Value $plan -Allowed $allowedPlan -Required $allowedPlan)) { $result.Reason = 'OPERATION_DESCRIPTOR_INVALID'; return [pscustomobject]$result }
    if (($command -eq 'init' -and $action -ne 'create') -or ($command -eq 'reconcile' -and $action -notin @('register','move','copy_as_new'))) { $result.Reason = 'OPERATION_DESCRIPTOR_INVALID'; return [pscustomobject]$result }
    if (-not (Test-ClosedProperties -Value $documents -Allowed @('binding','instance','registration','catalog') -Required @('binding','instance','registration','catalog'))) { $result.Reason = 'OPERATION_DESCRIPTOR_INVALID'; return [pscustomobject]$result }
    $instanceId = [string](Get-ProjectMemberValue $plan 'instance_id')
    $binding = Get-ProjectMemberValue $documents 'binding'
    $instance = Get-ProjectMemberValue $documents 'instance'
    $registration = Get-ProjectMemberValue $documents 'registration'
    $catalog = Get-ProjectMemberValue $documents 'catalog'
    if ([string](Get-ProjectMemberValue $binding 'project_id') -ne $projectId -or [string](Get-ProjectMemberValue $binding 'instance_id') -ne $instanceId -or
        [string](Get-ProjectMemberValue $catalog 'instance_id') -ne $instanceId -or
        [string](Get-ProjectMemberValue $instance 'lifecycle_state') -ne 'pending' -or
        [string](Get-ProjectMemberValue $registration 'status') -ne 'pending' -or
        [string](Get-ProjectMemberValue $catalog 'state') -ne 'active' -or
        -not (Test-ProjectCatalogDocument -Value $catalog -ProjectId $projectId) -or
        -not (Test-ProjectPathEqual -Left ([string](Get-ProjectMemberValue $catalog 'project_root')) -Right $roots.ProjectRoot) -or
        -not (Test-ProjectBindingDocument -Binding $binding -ExpectedRoot $roots.ProjectRoot -HarnessVersion $roots.HarnessVersion -AllowMoved).Valid -or
        -not (Test-ProjectInstanceDocument -Value $instance -ProjectId $projectId -InstanceId $instanceId) -or
        -not (Test-ProjectRegistrationDocument -Value $registration -ProjectId $projectId)) { $result.Reason = 'BINDING_SCHEMA_UNSUPPORTED'; return [pscustomobject]$result }
    $expectedWriteSet = @($paths.Binding,$paths.Instance,$paths.Registration,$paths.Catalog)
    if ($command -eq 'init') {
      $includeGitIgnore = [bool](Get-ProjectMemberValue $plan 'include_gitignore' $false)
      $gitIgnoreContent = [string](Get-ProjectMemberValue $plan 'gitignore_content' '')
      if ($includeGitIgnore) {
        if ([string]::IsNullOrWhiteSpace($gitIgnoreContent) -or $gitIgnoreContent -notmatch '(?m)^/?[.]hebrinex/?\s*$') { $result.Reason = 'GITIGNORE_APPROVAL_REQUIRED'; return [pscustomobject]$result }
        $expectedWriteSet += $paths.GitIgnore
      }
      elseif (-not [string]::IsNullOrWhiteSpace($gitIgnoreContent)) { $result.Reason = 'APPROVAL_SCOPE_MISMATCH'; return [pscustomobject]$result }
    }
  }
  else {
    if (-not (Test-ClosedProperties -Value $plan -Allowed @('command','action','project_id','archive_path','documents') -Required @('command','action','project_id','archive_path','documents')) -or $action -ne 'conservative') { $result.Reason = 'OPERATION_DESCRIPTOR_INVALID'; return [pscustomobject]$result }
    if (-not (Test-ClosedProperties -Value $documents -Allowed @('archive_binding','instance','registration','catalog') -Required @('archive_binding','instance','registration','catalog'))) { $result.Reason = 'OPERATION_DESCRIPTOR_INVALID'; return [pscustomobject]$result }
    $archivePath = [string](Get-ProjectMemberValue $plan 'archive_path')
    if (-not (Test-HebriPathContained -Root $roots.InstanceRoot -Candidate $archivePath) -or [IO.Path]::GetFileName($archivePath) -notmatch '^binding[.]PRJ-[a-f0-9]{32}[.][0-9]{8}T[0-9]{6}Z[.]json$') { $result.Reason = 'APPROVAL_SCOPE_MISMATCH'; return [pscustomobject]$result }
    $archiveBinding = Get-ProjectMemberValue $documents 'archive_binding'
    $instanceId = [string](Get-ProjectMemberValue $archiveBinding 'instance_id')
    $currentBinding = Read-ProjectJson $paths.Binding
    if ([string](Get-ProjectMemberValue $archiveBinding 'project_id') -ne $projectId -or
        $null -eq $currentBinding -or (ConvertTo-HebriCanonicalJson $archiveBinding) -ne (ConvertTo-HebriCanonicalJson $currentBinding) -or
        [string](Get-ProjectMemberValue (Get-ProjectMemberValue $documents 'instance') 'lifecycle_state') -ne 'unbound' -or
        [string](Get-ProjectMemberValue (Get-ProjectMemberValue $documents 'registration') 'status') -ne 'unbound' -or
        [string](Get-ProjectMemberValue (Get-ProjectMemberValue $documents 'catalog') 'state') -ne 'unbound' -or
        [string](Get-ProjectMemberValue (Get-ProjectMemberValue $documents 'catalog') 'instance_id') -ne $instanceId -or
        -not (Test-ProjectCatalogDocument -Value (Get-ProjectMemberValue $documents 'catalog') -ProjectId $projectId) -or
        -not (Test-ProjectPathEqual -Left ([string](Get-ProjectMemberValue (Get-ProjectMemberValue $documents 'catalog') 'project_root')) -Right $roots.ProjectRoot) -or
        -not (Test-ProjectBindingDocument -Binding $archiveBinding -ExpectedRoot $roots.ProjectRoot -HarnessVersion $roots.HarnessVersion).Valid -or
        -not (Test-ProjectInstanceDocument -Value (Get-ProjectMemberValue $documents 'instance') -ProjectId $projectId -InstanceId $instanceId) -or
        -not (Test-ProjectRegistrationDocument -Value (Get-ProjectMemberValue $documents 'registration') -ProjectId $projectId)) { $result.Reason = 'BINDING_SCHEMA_UNSUPPORTED'; return [pscustomobject]$result }
    $expectedWriteSet = @($archivePath,$paths.Instance,$paths.Registration,$paths.Catalog,$paths.Binding)
  }
  if (-not (Test-ProjectExactPathSet -Actual @($Descriptor.write_set) -Expected $expectedWriteSet)) { $result.Reason = 'APPROVAL_SCOPE_MISMATCH'; return [pscustomobject]$result }
  try {
    foreach ($path in $expectedWriteSet) {
      $rootForPath = if (Test-HebriPathContained -Root $roots.CatalogRoot -Candidate $path) { $roots.CatalogRoot } else { $roots.ProjectRoot }
      Assert-ProjectNoReparsePath -Root $rootForPath -Candidate $path
    }
  }
  catch { $result.Reason = 'REPARSE_POINT_UNSUPPORTED'; return [pscustomobject]$result }
  $result.Valid = $true
  $result.Reason = 'PROJECT_DESCRIPTOR_VALID'
  return [pscustomobject]$result
}

function New-HebriProjectOperationPlan {
  param(
    [Parameter(Mandatory = $true)][ValidateSet('init','bind','reconcile','unbind')][string]$Command,
    [Parameter(Mandatory = $true)][string]$InstallRoot,
    [string]$ProjectRoot = '',
    [string]$CatalogRoot = '',
    [string[]]$SearchRoots = @(),
    [switch]$IncludeGitIgnore,
    [switch]$CopyAsNew
  )
  try { $roots = Resolve-ProjectRoots -InstallRoot $InstallRoot -ProjectRoot $ProjectRoot -CatalogRoot $CatalogRoot }
  catch {
    $reason = if ($_.Exception.Message -match '^([A-Z0-9_]+):') { $Matches[1] } else { 'PROJECT_NOT_FOUND' }
    return New-ProjectResult -Command $Command -Status blocked -Reason $reason -ExitCode 3 -Details ([ordered]@{ error = $_.Exception.Message }) -NextStep 'Corregir las raices explicitas y repetir el plan.'
  }
  $paths = Get-ProjectPaths -Roots $roots
  if ($Command -eq 'bind') { $Command = 'init' }

  if ($Command -eq 'init') {
    if ((Test-Path -LiteralPath $paths.LegacyRootBinding -PathType Leaf) -or (Test-Path -LiteralPath $paths.LegacyInstanceBinding -PathType Leaf)) {
      return New-ProjectResult -Command init -Status blocked -Reason PROJECT_ALREADY_BOUND -ExitCode 3 -Details ([ordered]@{ mode = 'legacy'; project_root = $roots.ProjectRoot }) -NextStep 'Usar migrate en P05; no crear una segunda autoridad.'
    }
    if (Test-Path -LiteralPath $paths.Binding -PathType Leaf) {
      $check = Test-ProjectBindingDocument -Binding (Read-ProjectJson $paths.Binding) -ExpectedRoot $roots.ProjectRoot -HarnessVersion $roots.HarnessVersion
      if (-not $check.Valid) {
        return New-ProjectResult -Command init -Status blocked -Reason $check.Reason -ExitCode 3 -Details ([ordered]@{ binding_path = $paths.Binding }) -NextStep 'Ejecutar reconcile con las raices explicitas; el binding existente no se sobrescribe.'
      }
      $status = Get-HebriProjectStatus -InstallRoot $roots.InstallRoot -ProjectRoot $roots.ProjectRoot -CatalogRoot $roots.CatalogRoot
      if ($status.status -eq 'healthy') {
        return New-ProjectResult -Command init -Status unchanged -Reason PROJECT_ALREADY_BOUND -ProjectId ([string]$check.Binding.project_id) -Details ([ordered]@{ idempotent = $true; binding_path = $paths.Binding }) -NextStep 'No se requieren escrituras.'
      }
      return New-ProjectResult -Command init -Status blocked -Reason REGISTRATION_PENDING -ExitCode 3 -ProjectId ([string]$check.Binding.project_id) -Details ([ordered]@{ status = $status }) -NextStep 'Ejecutar reconcile con plan y aprobacion nuevos.'
    }
    if ((Test-Path -LiteralPath (Join-Path $roots.ProjectRoot '.hebrinex') -PathType Container)) {
      return New-ProjectResult -Command init -Status blocked -Reason PROJECT_ALREADY_BOUND -ExitCode 3 -Details ([ordered]@{ incompatible_instance = Join-Path $roots.ProjectRoot '.hebrinex' }) -NextStep 'Revisar o migrar la instancia preexistente; init no la sobrescribe.'
    }
    if (-not (Test-GitIgnoreContainsInstanceRule -Path $paths.GitIgnore) -and -not $IncludeGitIgnore) {
      return New-ProjectResult -Command init -Status blocked -Reason GITIGNORE_APPROVAL_REQUIRED -ExitCode 3 -Details ([ordered]@{ gitignore_path = $paths.GitIgnore; required_rule = '.hebrinex/' }) -NextStep 'Repetir el plan con -IncludeGitIgnore para incluir esa escritura en el descriptor.'
    }
    $projectId = 'PRJ-' + [guid]::NewGuid().ToString('N')
    $instanceId = 'INST-' + [guid]::NewGuid().ToString('N')
    $now = (Get-Date).ToUniversalTime().ToString('o')
    $documents = New-ProjectIdentityDocuments -ProjectId $projectId -InstanceId $instanceId -ProjectRoot $roots.ProjectRoot -HarnessVersion $roots.HarnessVersion -Timestamp $now
    $paths = Get-ProjectPaths -Roots $roots -ProjectId $projectId
    $writeSet = @($paths.Binding,$paths.Instance,$paths.Registration,$paths.Catalog)
    $gitIgnoreContent = ''
    if (-not (Test-GitIgnoreContainsInstanceRule -Path $paths.GitIgnore)) {
      $writeSet += $paths.GitIgnore
      $gitIgnoreContent = Get-GitIgnoreContent -Path $paths.GitIgnore
    }
    $plan = [ordered]@{
      command = 'init'; action = 'create'; project_id = $projectId; instance_id = $instanceId
      include_gitignore = -not [string]::IsNullOrWhiteSpace($gitIgnoreContent); gitignore_content = $gitIgnoreContent
      documents = [ordered]@{ binding = $documents.Binding; instance = $documents.Instance; registration = $documents.Registration; catalog = $documents.Catalog }
    }
    $descriptor = New-ProjectOperationDescriptor -Roots $roots -ProjectId $projectId -Operation 'project:init' -WriteSet $writeSet -Plan $plan
    return New-ProjectResult -Command init -Status planned -Reason PLAN_READY -ProjectId $projectId -Details ([ordered]@{ descriptor = $descriptor; write_set = $writeSet; runtime_copied = $false }) -NextStep 'Revisar el descriptor, dar SI, materializar APR2 y ejecutar init -Apply con el mismo descriptor.'
  }

  $looseBinding = Read-ProjectJson $paths.Binding
  if ($null -eq $looseBinding) {
    return New-ProjectResult -Command $Command -Status $(if ($Command -eq 'unbind') { 'unchanged' } else { 'blocked' }) -Reason PROJECT_NOT_FOUND -ExitCode $(if ($Command -eq 'unbind') { 0 } else { 3 }) -Details ([ordered]@{ binding_path = $paths.Binding }) -NextStep $(if ($Command -eq 'unbind') { 'No habia binding activo.' } else { 'Indicar una raiz que contenga .hebrinex/binding.json.' })
  }
  $bindingCheck = Test-ProjectBindingDocument -Binding $looseBinding -ExpectedRoot $roots.ProjectRoot -HarnessVersion $roots.HarnessVersion -AllowMoved
  if (-not $bindingCheck.Valid) {
    return New-ProjectResult -Command $Command -Status blocked -Reason BINDING_SCHEMA_UNSUPPORTED -ExitCode 3 -Details ([ordered]@{ binding_path = $paths.Binding }) -NextStep 'Reparar o migrar el binding; no se sobrescribe un schema desconocido.'
  }
  $projectId = [string]$looseBinding.project_id
  $instanceId = [string]$looseBinding.instance_id
  $paths = Get-ProjectPaths -Roots $roots -ProjectId $projectId

  if ($Command -eq 'unbind') {
    if ($bindingCheck.Moved) {
      return New-ProjectResult -Command unbind -Status blocked -Reason PROJECT_MOVED -ExitCode 3 -ProjectId $projectId -Details ([ordered]@{ recorded_root = [string]$looseBinding.project_root; current_root = $roots.ProjectRoot }) -NextStep 'Reconciliar primero el traslado.'
    }
    $now = (Get-Date).ToUniversalTime().ToString('o')
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $archivePath = Join-Path $roots.InstanceRoot ("archive\binding.$projectId.$stamp.json")
    $instance = Read-ProjectJson $paths.Instance
    if (-not (Test-ProjectInstanceDocument -Value $instance -ProjectId $projectId -InstanceId $instanceId)) {
      return New-ProjectResult -Command unbind -Status blocked -Reason BINDING_SCHEMA_UNSUPPORTED -ExitCode 3 -ProjectId $projectId -Details ([ordered]@{ instance_path = $paths.Instance }) -NextStep 'Reparar la identidad local antes de desvincular.'
    }
    $instance.lifecycle_state = 'unbound'; $instance.updated_at = $now
    $registration = [ordered]@{ schema = 'hebrinex.project_registration'; schema_version = 1; project_id = $projectId; status = 'unbound'; catalog_entry_relative_path = "projects/$projectId.json"; updated_at = $now }
    $catalog = [ordered]@{ schema = 'hebrinex.project_catalog_entry'; schema_version = 1; project_id = $projectId; instance_id = $instanceId; project_root = $roots.ProjectRoot; binding_schema_version = 1; state = 'unbound'; observed_at = $now; source = 'validated_binding' }
    $plan = [ordered]@{ command = 'unbind'; action = 'conservative'; project_id = $projectId; archive_path = $archivePath; documents = [ordered]@{ archive_binding = $looseBinding; instance = $instance; registration = $registration; catalog = $catalog } }
    $writeSet = @($archivePath,$paths.Instance,$paths.Registration,$paths.Catalog,$paths.Binding)
    $descriptor = New-ProjectOperationDescriptor -Roots $roots -ProjectId $projectId -Operation 'project:unbind' -WriteSet $writeSet -Plan $plan
    return New-ProjectResult -Command unbind -Status planned -Reason PLAN_READY -ProjectId $projectId -Details ([ordered]@{ descriptor = $descriptor; write_set = $writeSet; preserves_instance = $true }) -NextStep 'Revisar el descriptor, dar SI, materializar APR2 y ejecutar unbind -Apply.'
  }

  $candidateRoots = New-Object System.Collections.Generic.List[string]
  [void]$candidateRoots.Add($roots.ProjectRoot)
  foreach ($candidate in @($SearchRoots)) {
    if ([string]::IsNullOrWhiteSpace([string]$candidate)) { continue }
    $candidateFull = Get-ProjectFullPath ([string]$candidate)
    if (-not ($candidateRoots | Where-Object { Test-ProjectPathEqual -Left $_ -Right $candidateFull })) { [void]$candidateRoots.Add($candidateFull) }
  }
  $matches = New-Object System.Collections.Generic.List[object]
  foreach ($candidateRoot in $candidateRoots) {
    if (-not (Test-Path -LiteralPath $candidateRoot -PathType Container)) { continue }
    $candidatePath = Join-Path $candidateRoot '.hebrinex\binding.json'
    $candidateBinding = Read-ProjectJson $candidatePath
    if ($null -eq $candidateBinding -or [string](Get-ProjectMemberValue $candidateBinding 'project_id') -ne $projectId) { continue }
    $candidateCheck = Test-ProjectBindingDocument -Binding $candidateBinding -ExpectedRoot $candidateRoot -HarnessVersion $roots.HarnessVersion -AllowMoved
    if ($candidateCheck.Valid) { [void]$matches.Add([pscustomobject]@{ Root = $candidateRoot; Binding = $candidateBinding }) }
  }
  $recordedRoot = Get-ProjectFullPath ([string]$looseBinding.project_root)
  if (-not (Test-ProjectPathEqual -Left $recordedRoot -Right $roots.ProjectRoot) -and (Test-Path -LiteralPath $recordedRoot -PathType Container)) {
    if (-not ($candidateRoots | Where-Object { Test-ProjectPathEqual -Left $_ -Right $recordedRoot })) {
      return New-ProjectResult -Command reconcile -Status blocked -Reason PROJECT_MOVED -ExitCode 3 -ProjectId $projectId -Details ([ordered]@{ recorded_root = $recordedRoot; current_root = $roots.ProjectRoot; unapproved_existing_root = $recordedRoot }) -NextStep 'Repetir con la raiz anterior incluida explicitamente en -SearchRoots.'
    }
  }
  if ($matches.Count -gt 1 -and -not $CopyAsNew) {
    return New-ProjectResult -Command reconcile -Status blocked -Reason PROJECT_ID_DUPLICATE -ExitCode 3 -ProjectId $projectId -Details ([ordered]@{ roots = @($matches | ForEach-Object { $_.Root }) }) -NextStep 'Elegir la copia actual y repetir con -CopyAsNew bajo aprobacion.'
  }

  $action = 'register'
  $now = (Get-Date).ToUniversalTime().ToString('o')
  if ($matches.Count -gt 1 -and $CopyAsNew) {
    $action = 'copy_as_new'
    $projectId = 'PRJ-' + [guid]::NewGuid().ToString('N')
    $instanceId = 'INST-' + [guid]::NewGuid().ToString('N')
    $documents = New-ProjectIdentityDocuments -ProjectId $projectId -InstanceId $instanceId -ProjectRoot $roots.ProjectRoot -HarnessVersion $roots.HarnessVersion -Timestamp $now
  }
  else {
    if ($bindingCheck.Moved) { $action = 'move' }
    $createdAt = [string]$looseBinding.created_at
    $documents = New-ProjectIdentityDocuments -ProjectId $projectId -InstanceId $instanceId -ProjectRoot $roots.ProjectRoot -HarnessVersion $roots.HarnessVersion -Timestamp $now
    $documents.Binding.created_at = $createdAt
    $existingInstance = Read-ProjectJson $paths.Instance
    if (Test-ProjectInstanceDocument -Value $existingInstance -ProjectId ([string]$looseBinding.project_id) -InstanceId ([string]$looseBinding.instance_id)) {
      $documents.Instance.created_at = [string]$existingInstance.created_at
    }
  }
  $paths = Get-ProjectPaths -Roots $roots -ProjectId $projectId
  if ($action -eq 'register') {
    $registration = Read-ProjectJson $paths.Registration
    $instance = Read-ProjectJson $paths.Instance
    $catalog = Read-ProjectJson $paths.Catalog
    if ((Test-ProjectRegistrationDocument -Value $registration -ProjectId $projectId) -and [string]$registration.status -eq 'registered' -and
        (Test-ProjectInstanceDocument -Value $instance -ProjectId $projectId -InstanceId $instanceId) -and [string]$instance.lifecycle_state -eq 'active' -and
        (Test-ProjectCatalogDocument -Value $catalog -ProjectId $projectId) -and [string]$catalog.state -eq 'active' -and
        (Test-ProjectPathEqual -Left ([string]$catalog.project_root) -Right $roots.ProjectRoot)) {
      return New-ProjectResult -Command reconcile -Status unchanged -Reason CATALOG_ALREADY_CONSISTENT -ProjectId $projectId -Details ([ordered]@{ roots_checked = @($candidateRoots) }) -NextStep 'No se requieren escrituras.'
    }
  }
  $writeSet = @($paths.Binding,$paths.Instance,$paths.Registration,$paths.Catalog)
  $plan = [ordered]@{
    command = 'reconcile'; action = $action; project_id = $projectId; instance_id = $instanceId
    roots_checked = @($candidateRoots); documents = [ordered]@{ binding = $documents.Binding; instance = $documents.Instance; registration = $documents.Registration; catalog = $documents.Catalog }
  }
  $descriptor = New-ProjectOperationDescriptor -Roots $roots -ProjectId $projectId -Operation 'project:reconcile' -WriteSet $writeSet -Plan $plan
  return New-ProjectResult -Command reconcile -Status planned -Reason PLAN_READY -ProjectId $projectId -Details ([ordered]@{ descriptor = $descriptor; write_set = $writeSet; action = $action }) -NextStep 'Revisar el descriptor, dar SI, materializar APR2 y ejecutar reconcile -Apply.'
}

function Get-HebriProjectStatus {
  param([Parameter(Mandatory = $true)][string]$InstallRoot, [string]$ProjectRoot = '', [string]$CatalogRoot = '')
  try { $roots = Resolve-ProjectRoots -InstallRoot $InstallRoot -ProjectRoot $ProjectRoot -CatalogRoot $CatalogRoot }
  catch {
    $reason = if ($_.Exception.Message -match '^([A-Z0-9_]+):') { $Matches[1] } else { 'RUNTIME_NOT_INSTALLED' }
    return New-ProjectResult -Command status -Status blocked -Reason $reason -ExitCode 3 -Details ([ordered]@{ error = $_.Exception.Message }) -NextStep 'Corregir InstallRoot/ProjectRoot y repetir.'
  }
  $paths = Get-ProjectPaths -Roots $roots
  if (-not (Test-Path -LiteralPath $paths.Binding -PathType Leaf)) {
    $legacy = (Test-Path -LiteralPath $paths.LegacyRootBinding -PathType Leaf) -or (Test-Path -LiteralPath $paths.LegacyInstanceBinding -PathType Leaf)
    return New-ProjectResult -Command status -Status $(if ($legacy) { 'blocked' } else { 'degraded' }) -Reason $(if ($legacy) { 'PROJECT_ALREADY_BOUND' } else { 'PROJECT_NOT_FOUND' }) -ExitCode 3 -Details ([ordered]@{ binding_path = $paths.Binding; legacy_binding = $legacy }) -NextStep $(if ($legacy) { 'La conversion pertenece a P05.' } else { 'Ejecutar init -CheckOnly.' })
  }
  $binding = Read-ProjectJson $paths.Binding
  $check = Test-ProjectBindingDocument -Binding $binding -ExpectedRoot $roots.ProjectRoot -HarnessVersion $roots.HarnessVersion
  if (-not $check.Valid) {
    return New-ProjectResult -Command status -Status blocked -Reason $check.Reason -ExitCode 3 -ProjectId ([string](Get-ProjectMemberValue $binding 'project_id' '')) -Details ([ordered]@{ binding_path = $paths.Binding; recorded_root = [string](Get-ProjectMemberValue $binding 'project_root' '') }) -NextStep 'Ejecutar reconcile con raices explicitas o migrar el schema.'
  }
  $projectId = [string]$binding.project_id
  $instanceId = [string]$binding.instance_id
  $paths = Get-ProjectPaths -Roots $roots -ProjectId $projectId
  $instance = Read-ProjectJson $paths.Instance
  $registration = Read-ProjectJson $paths.Registration
  $catalog = Read-ProjectJson $paths.Catalog
  $instanceValid = Test-ProjectInstanceDocument -Value $instance -ProjectId $projectId -InstanceId $instanceId
  $registrationValid = Test-ProjectRegistrationDocument -Value $registration -ProjectId $projectId
  $catalogValid = Test-ProjectCatalogDocument -Value $catalog -ProjectId $projectId
  $healthy = $instanceValid -and [string]$instance.lifecycle_state -eq 'active' -and $registrationValid -and [string]$registration.status -eq 'registered' -and $catalogValid -and [string]$catalog.state -eq 'active' -and (Test-ProjectPathEqual -Left ([string]$catalog.project_root) -Right $roots.ProjectRoot)
  $details = [ordered]@{
    project_root = $roots.ProjectRoot; instance_root = $roots.InstanceRoot; binding_path = $paths.Binding; catalog_path = $paths.Catalog
    harness_version = $roots.HarnessVersion; effective_runtime_api = '1'; binding_valid = $true
    instance_valid = $instanceValid; registration_valid = $registrationValid; catalog_valid = $catalogValid
    registration_status = if ($registrationValid) { [string]$registration.status } else { 'invalid_or_missing' }
  }
  if ($healthy) { return New-ProjectResult -Command status -Status healthy -Reason PROJECT_HEALTHY -ProjectId $projectId -Details $details -NextStep 'Ninguna reparacion requerida.' }
  return New-ProjectResult -Command status -Status degraded -Reason REGISTRATION_PENDING -ExitCode 8 -ProjectId $projectId -Details $details -NextStep 'Ejecutar reconcile -CheckOnly y aprobar el plan de reparacion.'
}

function Get-HebriProjectCatalog {
  param([string]$CatalogRoot = '')
  if ([string]::IsNullOrWhiteSpace($CatalogRoot)) { $CatalogRoot = Get-ProjectDefaultCatalogRoot }
  $catalogFull = Get-ProjectFullPath $CatalogRoot
  $projectsRoot = Join-Path $catalogFull 'projects'
  $entries = New-Object System.Collections.Generic.List[object]
  $corrupt = New-Object System.Collections.Generic.List[string]
  if (Test-Path -LiteralPath $projectsRoot -PathType Leaf) {
    return New-ProjectResult -Command list -Status degraded -Reason CATALOG_CORRUPT -ExitCode 3 -Details ([ordered]@{ catalog_root = $catalogFull; projects = @(); corrupt_entries = @($projectsRoot) }) -NextStep 'Reparar el contenedor y reconstruir desde raices aprobadas.'
  }
  if (Test-Path -LiteralPath $projectsRoot -PathType Container) {
    foreach ($file in @(Get-ChildItem -LiteralPath $projectsRoot -File -Filter 'PRJ-*.json' -ErrorAction SilentlyContinue | Sort-Object Name)) {
      $entry = Read-ProjectJson $file.FullName
      if (-not (Test-ProjectCatalogDocument -Value $entry)) { [void]$corrupt.Add($file.FullName); continue }
      $rootExists = Test-Path -LiteralPath ([string]$entry.project_root) -PathType Container
      [void]$entries.Add([pscustomobject]@{
        project_id = [string]$entry.project_id; instance_id = [string]$entry.instance_id; project_root = [string]$entry.project_root
        catalog_state = [string]$entry.state; location_state = if ($rootExists) { 'present' } else { 'missing' }; observed_at = [string]$entry.observed_at
      })
    }
  }
  $status = if ($corrupt.Count -gt 0) { 'degraded' } else { 'ok' }
  $reason = if ($corrupt.Count -gt 0) { 'CATALOG_CORRUPT' } else { 'CATALOG_READ' }
  return New-ProjectResult -Command list -Status $status -Reason $reason -ExitCode $(if ($corrupt.Count -gt 0) { 3 } else { 0 }) -Details ([ordered]@{ catalog_root = $catalogFull; projects = $entries.ToArray(); corrupt_entries = $corrupt.ToArray() }) -NextStep $(if ($corrupt.Count -gt 0) { 'Reconstruir solo desde raices aprobadas mediante reconcile.' } else { 'Consulta completada sin escrituras.' })
}

function Invoke-HebriProjectDoctor {
  param([Parameter(Mandatory = $true)][string]$InstallRoot, [string]$ProjectRoot = '', [string]$CatalogRoot = '')
  try {
    $runtime = Test-HebriRuntimeInstallation -InstallRoot $InstallRoot
    $runtimeCheck = [ordered]@{ valid = $true; harness_version = [string]$runtime.HarnessVersion; runtime_api = '1'; install_root = Get-ProjectFullPath $runtime.InstallRoot }
  }
  catch {
    return New-ProjectResult -Command doctor -Status blocked -Reason RUNTIME_NOT_INSTALLED -ExitCode 3 -Details ([ordered]@{ runtime = [ordered]@{ valid = $false; error = $_.Exception.Message } }) -NextStep 'Reparar o instalar el producto central antes de operar proyectos.'
  }
  if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    return New-ProjectResult -Command doctor -Status healthy -Reason RUNTIME_HEALTHY -Details ([ordered]@{ runtime = $runtimeCheck }) -NextStep 'Producto central valido; no se consulto un proyecto.'
  }
  $project = Get-HebriProjectStatus -InstallRoot $InstallRoot -ProjectRoot $ProjectRoot -CatalogRoot $CatalogRoot
  $status = if ($project.status -eq 'healthy') { 'healthy' } else { 'degraded' }
  return New-ProjectResult -Command doctor -Status $status -Reason $(if ($status -eq 'healthy') { 'DOCTOR_HEALTHY' } else { [string]$project.reason }) -ExitCode ([int]$project.exit_code) -ProjectId ([string](Get-ProjectMemberValue $project 'project_id' '')) -Details ([ordered]@{ runtime = $runtimeCheck; project = $project }) -NextStep ([string]$project.next_step)
}

function Test-ProjectDescriptorPreconditions {
  param([Parameter(Mandatory = $true)]$Descriptor)
  foreach ($precondition in @($Descriptor.preconditions)) {
    $actual = Get-HebriFileSha256 -Path ([string]$precondition.path)
    if ($actual -ne [string]$precondition.sha256) { throw "OPERATION_PRECONDITION_FAILED: $([string]$precondition.path)" }
  }
}

function Set-ProjectApprovalConsumed {
  param($Descriptor, [string]$ApprovalId, [string]$ApprovalStoreRoot)
  $check = Test-HebriScopedApproval -Descriptor $Descriptor -ApprovalId $ApprovalId -StoreRoot $ApprovalStoreRoot
  if (-not $check.Valid) { throw ($check.Reason + ': approval cannot be consumed') }
  $approval = Read-HebriJsonDocument -Path $check.Path
  $approval.status = 'consumed'
  $approval | Add-Member -NotePropertyName consumed_at -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('o')) -Force
  Write-HebriAtomicJsonDocument -Path $check.Path -Value $approval
}

function Get-ProjectSnapshots {
  param([string[]]$Paths)
  $snapshots = @{}
  foreach ($path in $Paths) {
    $full = Get-ProjectFullPath $path
    if (Test-Path -LiteralPath $full -PathType Leaf) { $snapshots[$full] = [pscustomobject]@{ Exists = $true; Bytes = [IO.File]::ReadAllBytes($full) } }
    else { $snapshots[$full] = [pscustomobject]@{ Exists = $false; Bytes = $null } }
  }
  return $snapshots
}

function Assert-ProjectDescriptorTargetCurrent {
  param($Descriptor, [string]$Path, $OwnedWrites)
  $full = Get-ProjectFullPath $Path
  if ($OwnedWrites.ContainsKey($full)) { return }
  $matches = @($Descriptor.preconditions | Where-Object { Test-ProjectPathEqual -Left ([string]$_.path) -Right $full })
  if ($matches.Count -ne 1 -or (Get-HebriFileSha256 -Path $full) -ne [string]$matches[0].sha256) { throw "OPERATION_PRECONDITION_FAILED: $full changed before commit" }
}

function Write-ProjectOwnedJson {
  param($Descriptor, [string]$Path, [object]$Value, $OwnedWrites)
  $full = Get-ProjectFullPath $Path
  Assert-ProjectDescriptorTargetCurrent -Descriptor $Descriptor -Path $full -OwnedWrites $OwnedWrites
  Write-HebriAtomicJsonDocument -Path $full -Value $Value
  $OwnedWrites[$full] = Get-HebriFileSha256 -Path $full
}

function Write-ProjectOwnedText {
  param($Descriptor, [string]$Path, [string]$Value, $OwnedWrites)
  $full = Get-ProjectFullPath $Path
  Assert-ProjectDescriptorTargetCurrent -Descriptor $Descriptor -Path $full -OwnedWrites $OwnedWrites
  [void][IO.Directory]::CreateDirectory((Split-Path -Parent $full))
  [IO.File]::WriteAllText($full, $Value, [Text.UTF8Encoding]::new($false))
  $OwnedWrites[$full] = Get-HebriFileSha256 -Path $full
}

function Remove-ProjectOwnedFile {
  param($Descriptor, [string]$Path, $OwnedWrites)
  $full = Get-ProjectFullPath $Path
  Assert-ProjectDescriptorTargetCurrent -Descriptor $Descriptor -Path $full -OwnedWrites $OwnedWrites
  [IO.File]::Delete($full)
  $OwnedWrites[$full] = '__MISSING__'
}

function Restore-ProjectSnapshots {
  param($Snapshots, $OwnedWrites)
  foreach ($path in @($OwnedWrites.Keys)) {
    $current = Get-HebriFileSha256 -Path $path
    if ($current -ne [string]$OwnedWrites[$path]) { throw "RECOVERY_REQUIRED: concurrent content preserved at $path" }
    $snapshot = $Snapshots[$path]
    if ($null -eq $snapshot) { throw "RECOVERY_REQUIRED: snapshot missing for $path" }
    if ($snapshot.Exists) {
      [void][IO.Directory]::CreateDirectory((Split-Path -Parent $path))
      [IO.File]::WriteAllBytes($path, $snapshot.Bytes)
    }
    elseif (Test-Path -LiteralPath $path -PathType Leaf) { [IO.File]::Delete($path) }
  }
}

function New-ProjectStagingRoot {
  param($Descriptor)
  $instanceRoot = [string]$Descriptor.roots.instance_root
  $stage = Join-Path $instanceRoot ("runtime\staging\$([string]$Descriptor.operation_id)")
  if (Test-Path -LiteralPath $stage) { throw 'RECOVERY_REQUIRED: operation staging path already exists' }
  [void][IO.Directory]::CreateDirectory($stage)
  [IO.File]::WriteAllText((Join-Path $stage '.hebrinex-staging'), [string]$Descriptor.operation_id, [Text.UTF8Encoding]::new($false))
  return $stage
}

function Remove-ProjectStagingRoot {
  param([string]$Path, [string]$OperationId)
  if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Container)) { return }
  $marker = Join-Path $Path '.hebrinex-staging'
  if (-not (Test-Path -LiteralPath $marker -PathType Leaf) -or [IO.File]::ReadAllText($marker) -ne $OperationId) { return }
  [IO.Directory]::Delete($Path, $true)
}

function Write-ProjectStagedJson {
  param([string]$StageRoot, [string]$Name, [object]$Value)
  $path = Join-Path $StageRoot ($Name + '.json')
  Write-HebriAtomicJsonDocument -Path $path -Value $Value
  $roundTrip = Read-HebriJsonDocument -Path $path
  if ($null -eq $roundTrip) { throw 'RECOVERY_REQUIRED: staged JSON did not round-trip' }
  return $roundTrip
}

function Invoke-HebriProjectOperation {
  param(
    [Parameter(Mandatory = $true)]$Descriptor,
    [Parameter(Mandatory = $true)][string]$ApprovalId,
    [string]$ApprovalStoreRoot = ''
  )
  $descriptorCheck = Test-HebriProjectServiceDescriptor -Descriptor $Descriptor
  if (-not $descriptorCheck.Valid) { return New-ProjectResult -Command init -Status blocked -Reason $descriptorCheck.Reason -ExitCode 3 -Details ([ordered]@{}) -NextStep 'Generar un plan nuevo.' }
  $plan = $Descriptor.plan
  $command = [string](Get-ProjectMemberValue $plan 'command')
  if ($command -notin @('init','reconcile','unbind') -or [string]$Descriptor.operation -ne "project:$command" -or [string]$Descriptor.code_version -ne $script:ProjectServiceCodeVersion) {
    return New-ProjectResult -Command $(if ($command -in @('init','reconcile','unbind')) { $command } else { 'init' }) -Status blocked -Reason APPROVAL_SCOPE_MISMATCH -ExitCode 3 -Details ([ordered]@{}) -NextStep 'El descriptor no pertenece a project-service central1.'
  }
  $applyRoots = $descriptorCheck.Roots
  $canonicalApprovalStore = Join-Path ([string]$Descriptor.roots.instance_root) 'runtime/approvals'
  if (-not [string]::IsNullOrWhiteSpace($ApprovalStoreRoot) -and -not (Test-ProjectPathEqual -Left $ApprovalStoreRoot -Right $canonicalApprovalStore)) {
    return New-ProjectResult -Command $command -Status blocked -Reason APPROVAL_SCOPE_MISMATCH -ExitCode 3 -ProjectId ([string]$Descriptor.project_id) -Details ([ordered]@{}) -NextStep 'Usar el approval store canonico de InstanceRoot/runtime/approvals.'
  }
  $approval = Test-HebriScopedApproval -Descriptor $Descriptor -ApprovalId $ApprovalId -StoreRoot $ApprovalStoreRoot
  if (-not $approval.Valid) { return New-ProjectResult -Command $command -Status blocked -Reason $approval.Reason -ExitCode 3 -ProjectId ([string]$Descriptor.project_id) -Details ([ordered]@{}) -NextStep 'Materializar un APR2 para este descriptor exacto.' }
  try { Test-ProjectDescriptorPreconditions -Descriptor $Descriptor }
  catch { return New-ProjectResult -Command $command -Status blocked -Reason OPERATION_PRECONDITION_FAILED -ExitCode 3 -ProjectId ([string]$Descriptor.project_id) -Details ([ordered]@{ error = $_.Exception.Message }) -NextStep 'Descartar el plan y generar uno nuevo sobre el estado actual.' }

  $lock = $null
  $journal = $null
  $stageRoot = ''
  $snapshots = $null
  $ownedWrites = @{}
  $writes = $false
  $localCommitted = $false
  $result = $null
  try {
    $lock = Enter-HebriOperationLock -Descriptor $Descriptor -ApprovalId $ApprovalId -ApprovalStoreRoot $ApprovalStoreRoot
    $journal = New-HebriOperationJournal -Descriptor $Descriptor -ApprovalId $ApprovalId -LockPath $lock.Path
    [void](Set-HebriOperationJournalState -JournalPath $journal.Path -State applying -Evidence 'project-service central1 apply started')
    $stageRoot = New-ProjectStagingRoot -Descriptor $Descriptor
    $snapshots = Get-ProjectSnapshots -Paths @($Descriptor.write_set)
    $documents = $plan.documents

    if ($command -in @('init','reconcile')) {
      $binding = Write-ProjectStagedJson -StageRoot $stageRoot -Name binding -Value $documents.binding
      $instance = Write-ProjectStagedJson -StageRoot $stageRoot -Name instance -Value $documents.instance
      $registration = Write-ProjectStagedJson -StageRoot $stageRoot -Name registration -Value $documents.registration
      $catalog = Write-ProjectStagedJson -StageRoot $stageRoot -Name catalog -Value $documents.catalog
      $projectId = [string]$Descriptor.project_id
      $instanceId = [string]$plan.instance_id
      if (-not (Test-ProjectBindingDocument -Binding $binding -ExpectedRoot ([string]$Descriptor.roots.project_root) -HarnessVersion $applyRoots.HarnessVersion -AllowMoved).Valid -or
          -not (Test-ProjectInstanceDocument -Value $instance -ProjectId $projectId -InstanceId $instanceId) -or
          -not (Test-ProjectRegistrationDocument -Value $registration -ProjectId $projectId) -or
          -not (Test-ProjectCatalogDocument -Value $catalog -ProjectId $projectId)) { throw 'BINDING_SCHEMA_UNSUPPORTED: staged project documents failed validation' }
      $paths = Get-ProjectPaths -Roots ([pscustomobject]@{ ProjectRoot = [string]$Descriptor.roots.project_root; InstanceRoot = [string]$Descriptor.roots.instance_root; CatalogRoot = [string]$Descriptor.roots.catalog_root }) -ProjectId $projectId
      Write-ProjectOwnedJson -Descriptor $Descriptor -Path $paths.Binding -Value $binding -OwnedWrites $ownedWrites; $writes = $true
      Write-ProjectOwnedJson -Descriptor $Descriptor -Path $paths.Instance -Value $instance -OwnedWrites $ownedWrites; $writes = $true
      Write-ProjectOwnedJson -Descriptor $Descriptor -Path $paths.Registration -Value $registration -OwnedWrites $ownedWrites; $writes = $true
      if ($command -eq 'init' -and [bool]$plan.include_gitignore) {
        Write-ProjectOwnedText -Descriptor $Descriptor -Path $paths.GitIgnore -Value ([string]$plan.gitignore_content) -OwnedWrites $ownedWrites; $writes = $true
      }
      $localCommitted = $true
      Write-ProjectOwnedJson -Descriptor $Descriptor -Path $paths.Catalog -Value $catalog -OwnedWrites $ownedWrites; $writes = $true
      $now = (Get-Date).ToUniversalTime().ToString('o')
      $registration.status = 'registered'; $registration.updated_at = $now
      $instance.lifecycle_state = 'active'; $instance.updated_at = $now
      Write-ProjectOwnedJson -Descriptor $Descriptor -Path $paths.Registration -Value $registration -OwnedWrites $ownedWrites
      Write-ProjectOwnedJson -Descriptor $Descriptor -Path $paths.Instance -Value $instance -OwnedWrites $ownedWrites
      [void](Set-ProjectApprovalConsumed -Descriptor $Descriptor -ApprovalId $ApprovalId -ApprovalStoreRoot $ApprovalStoreRoot)
      [void](Set-HebriOperationJournalState -JournalPath $journal.Path -State committed -Evidence 'local identity and recoverable catalog committed')
      $result = New-ProjectResult -Command $command -Status applied -Reason PROJECT_REGISTERED -WritesPerformed $true -ProjectId $projectId -Details ([ordered]@{ binding_path = $paths.Binding; instance_root = [string]$Descriptor.roots.instance_root; catalog_path = $paths.Catalog; action = [string]$plan.action; runtime_copied = $false; journal_path = $journal.Path }) -NextStep 'Ejecutar status y doctor; ambas consultas son read-only.'
    }
    else {
      $projectId = [string]$Descriptor.project_id
      $paths = Get-ProjectPaths -Roots ([pscustomobject]@{ ProjectRoot = [string]$Descriptor.roots.project_root; InstanceRoot = [string]$Descriptor.roots.instance_root; CatalogRoot = [string]$Descriptor.roots.catalog_root }) -ProjectId $projectId
      $archive = Write-ProjectStagedJson -StageRoot $stageRoot -Name archive-binding -Value $documents.archive_binding
      $instance = Write-ProjectStagedJson -StageRoot $stageRoot -Name instance -Value $documents.instance
      $registration = Write-ProjectStagedJson -StageRoot $stageRoot -Name registration -Value $documents.registration
      $catalog = Write-ProjectStagedJson -StageRoot $stageRoot -Name catalog -Value $documents.catalog
      Write-ProjectOwnedJson -Descriptor $Descriptor -Path ([string]$plan.archive_path) -Value $archive -OwnedWrites $ownedWrites; $writes = $true
      Write-ProjectOwnedJson -Descriptor $Descriptor -Path $paths.Catalog -Value $catalog -OwnedWrites $ownedWrites
      Write-ProjectOwnedJson -Descriptor $Descriptor -Path $paths.Instance -Value $instance -OwnedWrites $ownedWrites
      Write-ProjectOwnedJson -Descriptor $Descriptor -Path $paths.Registration -Value $registration -OwnedWrites $ownedWrites
      if (-not (Test-Path -LiteralPath $paths.Binding -PathType Leaf)) { throw 'RECOVERY_REQUIRED: binding disappeared during unbind' }
      Remove-ProjectOwnedFile -Descriptor $Descriptor -Path $paths.Binding -OwnedWrites $ownedWrites
      $localCommitted = $true
      [void](Set-ProjectApprovalConsumed -Descriptor $Descriptor -ApprovalId $ApprovalId -ApprovalStoreRoot $ApprovalStoreRoot)
      [void](Set-HebriOperationJournalState -JournalPath $journal.Path -State committed -Evidence 'binding archived and removed; instance preserved')
      $result = New-ProjectResult -Command unbind -Status applied -Reason PROJECT_UNBOUND -WritesPerformed $true -ProjectId $projectId -Details ([ordered]@{ archive_path = [string]$plan.archive_path; instance_root = [string]$Descriptor.roots.instance_root; catalog_path = $paths.Catalog; data_preserved = $true; journal_path = $journal.Path }) -NextStep 'El proyecto ya no tiene binding activo; init puede crear una identidad nueva si se aprueba.'
    }
  }
  catch {
    $errorMessage = $_.Exception.Message
    if ($command -in @('init','reconcile') -and $localCommitted) {
      try {
        $registrationPath = Join-Path ([string]$Descriptor.roots.instance_root) 'registration.json'
        $pending = Read-ProjectJson $registrationPath
        if ($null -ne $pending) {
          $registrationFull = Get-ProjectFullPath $registrationPath
          if ($ownedWrites.ContainsKey($registrationFull) -and (Get-HebriFileSha256 -Path $registrationFull) -ne [string]$ownedWrites[$registrationFull]) { throw "RECOVERY_REQUIRED: concurrent registration content preserved at $registrationFull" }
          $pending.status = 'pending'; $pending.updated_at = (Get-Date).ToUniversalTime().ToString('o')
          $pending | Add-Member -NotePropertyName last_error -NotePropertyValue (($errorMessage -replace '[\r\n]+',' ').Substring(0, [Math]::Min(512, ($errorMessage -replace '[\r\n]+',' ').Length))) -Force
          Write-HebriAtomicJsonDocument -Path $registrationPath -Value $pending
          $ownedWrites[$registrationFull] = Get-HebriFileSha256 -Path $registrationFull
        }
        [void](Set-HebriOperationJournalState -JournalPath $journal.Path -State recovery_required -Evidence $errorMessage)
        try { [void](Set-ProjectApprovalConsumed -Descriptor $Descriptor -ApprovalId $ApprovalId -ApprovalStoreRoot $ApprovalStoreRoot) } catch { }
      }
      catch { $errorMessage += '; recovery marker failed: ' + $_.Exception.Message }
      $result = New-ProjectResult -Command $command -Status failed -Reason REGISTRATION_PENDING -ExitCode 8 -WritesPerformed $true -ProjectId ([string]$Descriptor.project_id) -Details ([ordered]@{ error = $errorMessage; confirmed_effects = @('binding','instance','registration_pending'); journal_path = if ($null -ne $journal) { $journal.Path } else { '' } }) -NextStep 'Corregir CatalogRoot, generar un descriptor reconcile nuevo y aprobarlo.'
    }
    else {
      $rollbackOk = $true
      try {
        if ($null -ne $journal) { [void](Set-HebriOperationJournalState -JournalPath $journal.Path -State rolling_back -Evidence $errorMessage) }
        if ($null -ne $snapshots) { Restore-ProjectSnapshots -Snapshots $snapshots -OwnedWrites $ownedWrites }
        if ($null -ne $journal) { [void](Set-HebriOperationJournalState -JournalPath $journal.Path -State rolled_back -Evidence 'approved target preimages restored') }
        try { [void](Set-ProjectApprovalConsumed -Descriptor $Descriptor -ApprovalId $ApprovalId -ApprovalStoreRoot $ApprovalStoreRoot) } catch { }
      }
      catch { $rollbackOk = $false; $errorMessage += '; rollback failed: ' + $_.Exception.Message; try { if ($null -ne $journal) { [void](Set-HebriOperationJournalState -JournalPath $journal.Path -State recovery_required -Evidence $errorMessage) } } catch { } }
      $reason = if ($rollbackOk) { if ($errorMessage -match '^([A-Z0-9_]+):') { $Matches[1] } else { 'OPERATION_FAILED' } } else { 'RECOVERY_REQUIRED' }
      $result = New-ProjectResult -Command $command -Status failed -Reason $reason -ExitCode $(if ($rollbackOk) { 3 } else { 8 }) -WritesPerformed $writes -ProjectId ([string]$Descriptor.project_id) -Details ([ordered]@{ error = $errorMessage; rolled_back = $rollbackOk; journal_path = if ($null -ne $journal) { $journal.Path } else { '' } }) -NextStep $(if ($rollbackOk) { 'Generar un plan nuevo despues de corregir la causa.' } else { 'Inspeccionar el journal y ejecutar recuperacion aprobada.' })
    }
  }
  finally {
    try { Remove-ProjectStagingRoot -Path $stageRoot -OperationId ([string]$Descriptor.operation_id) } catch { }
    if ($null -ne $lock) { try { [void](Exit-HebriOperationLock -LockPath $lock.Path) } catch { } }
  }
  return $result
}

function Resolve-HebriCentralHookContext {
  param([Parameter(Mandatory = $true)][string]$InstallRoot, [Parameter(Mandatory = $true)][string]$ProjectRoot, [string]$CatalogRoot = '')
  return Resolve-HebriRuntimeContext -InstallRoot $InstallRoot -ProjectRoot $ProjectRoot -DeploymentMode central_instance -CatalogRoot $CatalogRoot
}

Export-ModuleMember -Function @(
  'New-HebriProjectOperationPlan',
  'Test-HebriProjectServiceDescriptor',
  'Invoke-HebriProjectOperation',
  'Get-HebriProjectStatus',
  'Get-HebriProjectCatalog',
  'Invoke-HebriProjectDoctor',
  'Resolve-HebriCentralHookContext'
)
