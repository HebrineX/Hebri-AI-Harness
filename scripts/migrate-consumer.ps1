param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [switch]$CheckOnly, [switch]$Apply,
  [string]$Snapshot = '', [string]$ApprovalId = '',
  [string]$AcceptOverwritePathsJson = '[]'
)
$ErrorActionPreference = 'Stop'
$stage = 'path_preflight'
$verifiedDirectoryAncestors = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
trap { throw "consumer_migration stage=$stage : $($_.Exception.Message)" }
Set-StrictMode -Version 2
if ($env:OS -ne 'Windows_NT') { throw 'Windows-only migration boundary' }
if ($CheckOnly.IsPresent -eq $Apply.IsPresent) { throw 'Select exactly one of CheckOnly or Apply' }

function Assert-PathComponent([string]$Name) {
  if (-not $Name -or $Name -match '[:*?"<>|/\\\x00-\x1f]|[. ]$|^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])([.]|$)' -or $Name -in @('.','..')) { throw 'Ambiguous or reserved path component' }
}
function Assert-LocalPath([string]$Path) {
  if ($Path -notmatch '^[A-Za-z]:[\\/]' -or $Path.Substring(2) -match '[:*?"<>|\x00-\x1f]') { throw 'Only absolute local drive paths are supported' }
  $parts = @($Path.Substring(3).Split([char[]]@('\','/'), [StringSplitOptions]::RemoveEmptyEntries))
  if (-not $parts.Count) { throw 'Drive root is not an allowed scope' }
  foreach ($part in $parts) {
    Assert-PathComponent $part
  }
  $full = [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
  $drive = [IO.DriveInfo]::new($full.Substring(0,3))
  if ($drive.DriveType -ne [IO.DriveType]::Fixed) { throw 'Only fixed local drives are supported' }
  $cursor = $full.Substring(0,3)
  $walk = @($cursor)
  foreach ($part in $parts) { $cursor = Join-Path $cursor $part; $walk += $cursor }
  foreach ($cursor in $walk) {
    # Per invocation only: cache verified existing directory ancestors, never the leaf.
    if ($cursor -ne $full -and $verifiedDirectoryAncestors.Contains($cursor)) { continue }
    if (Test-Path -LiteralPath $cursor) {
      $item = Get-Item -LiteralPath $cursor -Force
      if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse path rejected: $cursor" }
      if ($cursor -ne $full -and -not $item.PSIsContainer) { throw "Non-directory ancestor: $cursor" }
      if ($cursor -ne $full -and $item.PSIsContainer) { [void]$verifiedDirectoryAncestors.Add($cursor) }
    }
  }
  return $full
}
function Assert-Relative([string]$Path) {
  if ($Path -notmatch '^[A-Za-z0-9_.@/-]+$' -or $Path -match '(^|/)(\.|\.\.)(/|$)|//|(^|/)[^/]*[.](/|$)' -or $Path.StartsWith('/')) { throw "Unsafe manifest path: $Path" }
  foreach ($part in $Path.Split('/')) {
    if ($part -match '^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])([.]|$)') { throw 'Reserved device path' }
  }
}
function Get-Digest([string]$Path) {
  if ([IO.Directory]::Exists($Path)) { return 'directory' }
  if (-not [IO.File]::Exists($Path)) { return 'missing' }
  $stream = [IO.File]::OpenRead($Path)
  try {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
  } finally { $stream.Dispose() }
}
function Get-Tree([string]$Base, [string]$Relative = '', [int]$Depth = 0) {
  if ($Depth -gt 32) { throw 'Target inventory exceeds depth 32; use a separately reviewed scope' }
  foreach ($item in (Get-ChildItem -LiteralPath (Join-Path $Base $Relative) -Force | Sort-Object Name)) {
    $script:InventoryCount++
    if ($script:InventoryCount -gt 10000) { throw 'Target inventory exceeds 10000 entries; use a separately reviewed scope' }
    $rel = ($Relative + '/' + $item.Name).TrimStart('/')
    # The parent was checked before enumeration; validate only this immediate child.
    Assert-PathComponent $item.Name
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse descendant rejected: $rel" }
    if ($item.Name -in @('.git','.codex')) {
      if ($Relative) { throw 'Nested .git/.codex inside engine state trees requires separate review' }
      continue
    }
    if ($rel -match '(^|/)(credentials|secrets?)([./]|$)|(^|/)\.env($|\.)|\.(pfx|pem|key)$') { throw "Credential path requires separate migration: $rel" }
    if ($item.PSIsContainer) { Get-Tree $Base $rel ($Depth + 1) }
    else {
      $script:InventoryBytes += $item.Length
      if ($script:InventoryBytes -gt 128MB) { throw 'Target inventory exceeds 128 MiB; use a separately reviewed scope' }
      [pscustomobject]@{ path = $rel; full = $item.FullName }
    }
  }
}
function Quote-Argument([string]$Value) { return "'" + $Value.Replace("'", "''") + "'" }

$Root = Assert-LocalPath $Root
$ProjectRoot = Assert-LocalPath $ProjectRoot
$bound = Assert-LocalPath (Join-Path $ProjectRoot '.hebrinex')
if (-not (Test-Path -LiteralPath $bound -PathType Container)) { throw 'Missing local .hebrinex authority' }
if ($Root -eq $ProjectRoot -or $ProjectRoot.StartsWith($Root + '\', 'OrdinalIgnoreCase') -or $Root.StartsWith($ProjectRoot + '\', 'OrdinalIgnoreCase')) { throw 'Source and project must be disjoint' }
if ((Assert-LocalPath (Split-Path -Parent $PSScriptRoot)) -ne $Root) { throw 'Execute the entrypoint belonging to Root' }
$cli = Join-Path $Root 'scripts/hebrinex.ps1'
$module = Join-Path $Root 'scripts/lib/hebri-common.psm1'
[void](Assert-LocalPath $cli)
[void](Assert-LocalPath $module)
Import-Module $module -Force -DisableNameChecking -Scope Local

# Reuse the engine's pure policy functions, without executing its command dispatch.
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($cli, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Source engine parse failure' }
foreach ($name in @('Get-BoundUpdatePreserveReason','Test-BootstrapExcludedPath','Get-BoundLegacyInstanceMappings','Convert-BoundSessionPinVersion','Get-ConsumerHarnessIgnoreState')) {
  $definition = @($ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $false))
  if ($definition.Count -ne 1) { throw "Missing unique engine policy: $name" }
  . ([scriptblock]::Create($definition[0].Extent.Text))
}
function Read-Binding([string]$Path) {
  [void](Assert-LocalPath $Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing binding: $Path" }
  $text = [IO.File]::ReadAllText($Path)
  $result = @{}
  foreach ($key in @('binding_mode','project_root','harness_instance_id','harness_version')) {
    if (@([regex]::Matches($text, '(?m)^' + $key + ':')).Count -ne 1) { throw "Ambiguous binding field: $key" }
    $result[$key] = Get-Scalar -Text $text -Key $key
  }
  return $result
}
function Assert-Bound($Binding) {
  if ($Binding.binding_mode -ne 'bound' -or -not $Binding.harness_instance_id -or (Assert-LocalPath $Binding.project_root) -ne $ProjectRoot) { throw 'Binding identity/root mismatch' }
}
$script:InventoryCount = 0; $script:InventoryBytes = 0L
$stage = 'target_inventory'
$targetFiles = @(Get-Tree $bound)
if (@($targetFiles | Where-Object { $_.path -match '/infoHebri[.]md$' }).Count) { throw 'Nested infoHebri.md requires separate review; engine state traversal could read it' }
if (Test-Path -LiteralPath (Join-Path $bound 'binding.json')) { throw 'Central-runtime layout unsupported' }
foreach ($file in $targetFiles) {
  # Match Get-LockInventory's record format; _README.md is documentation, not a lock.
  if ($file.path -match '^(instance/sdd/progress|orquestador/sdd/progress)/locks/[^/]+\.lock\.md$') {
    $lockStatus = Get-Scalar -Text ([IO.File]::ReadAllText($file.full)) -Key 'status'
    if ($lockStatus -eq 'active') { throw "Active lock rejected: $($file.path) (including expired active records); resolve it through the authority before replanning" }
  }
}
$stage = 'binding_versions'
$sourceBinding = Read-Binding (Join-Path $Root 'PROJECT_BINDING.yaml')
if ($sourceBinding.binding_mode -ne 'source_template') { throw 'Root must be a source_template distribution' }
$sourceCanonical = Assert-LocalPath (Join-Path $Root 'instance/PROJECT_BINDING.yaml')
if (Test-Path -LiteralPath $sourceCanonical) {
  if ((Read-Binding $sourceCanonical).binding_mode -ne 'source_template') { throw 'Source canonical binding must be source_template' }
}
$rootBinding = Read-Binding (Join-Path $bound 'PROJECT_BINDING.yaml')
$canonicalPath = Join-Path $bound 'instance/PROJECT_BINDING.yaml'
$binding = $rootBinding
if (Test-Path -LiteralPath $canonicalPath) { $binding = Read-Binding $canonicalPath }
Assert-Bound $binding
if ($rootBinding.binding_mode -eq 'bound') {
  Assert-Bound $rootBinding
  if ($rootBinding.harness_instance_id -ne $binding.harness_instance_id) { throw 'Ambiguous bound identity' }
} elseif ($rootBinding.binding_mode -ne 'source_template') { throw 'Unsupported root binding' }
$version = ([IO.File]::ReadAllText((Assert-LocalPath (Join-Path $bound 'HARNESS_VERSION')))).Trim()
$sourceVersion = ([IO.File]::ReadAllText((Assert-LocalPath (Join-Path $Root 'HARNESS_VERSION')))).Trim()
if ($sourceVersion -ne '0.17.3' -or $sourceBinding.harness_version -ne $sourceVersion) { throw 'Source must be final 0.17.3' }
if ((Test-Path -LiteralPath $sourceCanonical) -and (Read-Binding $sourceCanonical).harness_version -ne $sourceVersion) { throw 'Ambiguous source canonical version' }
if ($version -notmatch '^0\.(16|17)\.[0-9]+$' -or [version]$version -lt [version]'0.16.0' -or [version]$version -gt [version]'0.17.3' -or $binding.harness_version -ne $version) { throw 'Unsupported, ambiguous or downgrade target version' }

$manifest = Join-Path $Root 'orquestador/harness-manifest.txt'
[void](Assert-LocalPath $manifest)
$records = [Collections.Generic.List[object]]::new()
$overwrites = [Collections.Generic.List[string]]::new()
$adds = [Collections.Generic.List[string]]::new()
$preserved = [Collections.Generic.List[string]]::new()
$pendingDirs = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$plannedParents = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$imports = [Collections.Generic.List[object]]::new()
$approvalImports = [Collections.Generic.List[object]]::new()
$stage = 'distribution_plan'
function Add-PendingParents([string]$Path) {
  $parent = Split-Path -Parent $Path
  while ($parent -and $parent -ne $bound) {
    # Parents already planned include their ancestors; scope is one immutable plan.
    if (-not $plannedParents.Add($parent)) { break }
    [void](Assert-LocalPath $parent)
    if (Test-Path -LiteralPath $parent) {
      if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "Canonical directory type conflict: $parent" }
    } else { [void]$pendingDirs.Add(($parent.Substring($bound.Length).TrimStart('\') -replace '\\','/')) }
    $parent = Split-Path -Parent $parent
  }
}
$seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($line in [IO.File]::ReadAllLines($manifest)) {
  if ($line -notmatch '^(file|dir)\s+(.+)$') { continue }
  $kind = $Matches[1]; $rel = $Matches[2].Trim()
  Assert-Relative $rel
  if (-not $seen.Add($rel)) { throw "Duplicate manifest path: $rel" }
  $src = Assert-LocalPath (Join-Path $Root $rel)
  $dst = Assert-LocalPath (Join-Path $bound $rel)
  if (Test-BootstrapExcludedPath $rel) { continue }
  if ($rel -match '(^|/)(credentials|secrets?)([./]|$)|(^|/)\.env($|\.)|\.(pfx|pem|key)$') { throw 'Credential manifest entry rejected' }
  $reason = Get-BoundUpdatePreserveReason $rel $bound
  if ($reason) { $preserved.Add($rel); continue }
  if ($kind -eq 'dir') {
    if ((Test-Path -LiteralPath $dst) -and -not (Test-Path -LiteralPath $dst -PathType Container)) { throw "Directory type conflict: $rel" }
    if (-not (Test-Path -LiteralPath $dst)) { [void]$pendingDirs.Add($rel); Add-PendingParents $dst }
    continue
  }
  if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { throw "Missing source file: $rel" }
  $before = Get-Digest $dst; $after = Get-Digest $src
  if ($before -eq 'directory') { throw "File type conflict: $rel" }
  $records.Add([ordered]@{ path = $rel; source = $after; target = $before })
  Add-PendingParents $dst
  if ($before -eq 'missing') { $adds.Add($rel) } elseif ($before -ne $after) { $overwrites.Add($rel) }
}
$stage = 'legacy_import_plan'
foreach ($mapping in (Get-BoundLegacyInstanceMappings)) {
  Assert-Relative $mapping.Source
  Assert-Relative $mapping.Destination
  $legacyPath = Assert-LocalPath (Join-Path $bound $mapping.Source)
  $canonicalBase = Assert-LocalPath (Join-Path $bound $mapping.Destination)
  if (-not (Test-Path -LiteralPath $legacyPath)) { continue }
  if ($mapping.Kind -eq 'dir') {
    if (-not (Test-Path -LiteralPath $legacyPath -PathType Container)) { throw "Legacy directory type conflict: $($mapping.Source)" }
    if ((Test-Path -LiteralPath $canonicalBase) -and -not (Test-Path -LiteralPath $canonicalBase -PathType Container)) { throw "Canonical directory type conflict: $($mapping.Destination)" }
    $candidates = @($targetFiles | Where-Object { $_.path.StartsWith($mapping.Source + '/', [StringComparison]::OrdinalIgnoreCase) })
  } elseif ($mapping.Kind -eq 'file') {
    if (-not (Test-Path -LiteralPath $legacyPath -PathType Leaf)) { throw "Legacy file type conflict: $($mapping.Source)" }
    $candidates = @($targetFiles | Where-Object { $_.path -eq $mapping.Source })
  } else { throw 'Unknown legacy mapping kind' }
  foreach ($candidate in $candidates) {
    $suffix = if ($mapping.Kind -eq 'dir') { $candidate.path.Substring($mapping.Source.Length + 1) } else { '' }
    $excluded = $false
    foreach ($pattern in $mapping.ExcludeRegex) { if ($suffix -match $pattern) { $excluded = $true; break } }
    if ($excluded) { continue }
    $isApproval = $candidate.path -match '^orquestador/sdd/progress/approvals/'
    $destination = $mapping.Destination
    if ($suffix) { $destination += '/' + $suffix }
    $destinationPath = Assert-LocalPath (Join-Path $bound $destination)
    if (Test-Path -LiteralPath $destinationPath) {
      if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf)) { throw "Canonical file type conflict: $destination" }
      if (-not $preserved.Contains($destination)) { $preserved.Add($destination) }
      continue
    }
    $import = [ordered]@{ source = $candidate.path; destination = $destination; sha256 = Get-Digest $candidate.full }
    if ($isApproval) {
      # Issuing the execution approval must not invalidate the content snapshot.
      # Disclose these variable imports separately and verify their Apply-time hashes.
      $approvalImports.Add($import)
    } else {
      Add-PendingParents $destinationPath
      $imports.Add($import)
    }
  }
}
$importPlan = @($imports.ToArray() | Sort-Object destination,source)
$stage = 'session_pin_metadata'
$pinDestination = 'instance/memory/local/session-pin.md'
$pinSource = $pinDestination
$pinDestinationPath = Assert-LocalPath (Join-Path $bound $pinDestination)
if (-not (Test-Path -LiteralPath $pinDestinationPath)) { $pinSource = 'orquestador/memory/local/session-pin.md' }
$pinSourcePath = Assert-LocalPath (Join-Path $bound $pinSource)
if (-not (Test-Path -LiteralPath $pinSourcePath -PathType Leaf)) { throw 'Migration requires an existing session pin file' }
$pinEncoding = [Text.UTF8Encoding]::new($false, $true)
$pinUpdate = Convert-BoundSessionPinVersion ($pinEncoding.GetString([IO.File]::ReadAllBytes($pinSourcePath))) $version $sourceVersion
$pinSha = [Security.Cryptography.SHA256]::Create()
try { $pinAfterHash = ([BitConverter]::ToString($pinSha.ComputeHash($pinEncoding.GetBytes($pinUpdate.Text)))).Replace('-', '').ToLowerInvariant() }
finally { $pinSha.Dispose() }
$metadataUpdates = @()
if ($pinUpdate.Changed -or $pinSource -ne $pinDestination) {
  $metadataUpdates = @([ordered]@{ source = $pinSource; destination = $pinDestination; before_sha256 = Get-Digest $pinSourcePath; after_sha256 = $pinAfterHash })
  Add-PendingParents $pinDestinationPath
  [void]$preserved.Remove($pinDestination)
}
$directoryPlan = @($pendingDirs | Sort-Object)
$stage = 'snapshot_approval'
$parsedAcceptance = ConvertFrom-Json -InputObject $AcceptOverwritePathsJson
$accepted = @($parsedAcceptance)
if ($AcceptOverwritePathsJson.Trim() -notmatch '^\[.*\]$') { throw 'Acceptance must be a JSON array' }
foreach ($path in $accepted) { if ($path -isnot [string]) { throw 'Acceptance paths must be strings' }; Assert-Relative $path }
$expected = @($overwrites | Sort-Object)
$actual = @($accepted | Sort-Object)
$acceptanceMatches = ($actual.Count -eq $expected.Count -and ($actual -join "`n") -ceq ($expected -join "`n"))
$snapshotState = @($targetFiles | Where-Object { $_.path -notmatch '^(instance/sdd/progress|orquestador/sdd/progress)/approvals(/|$)' -and $_.path -notmatch '(^|/)infoHebri[.]md$' } | ForEach-Object { [ordered]@{ path = $_.path; hash = Get-Digest $_.full } })
$gitignore = Assert-LocalPath (Join-Path $ProjectRoot '.gitignore')
if ((Get-Digest $gitignore) -eq 'directory') { throw 'Project gitignore is not a file' }
$ignoreState = if ([IO.File]::Exists($gitignore)) { Get-ConsumerHarnessIgnoreState ([IO.File]::ReadAllText($gitignore)) } else { 'missing' }
if ($ignoreState -eq 'contradictory') { throw 'Contradictory gitignore negation after harness exclusion; review rules before migration' }
$gitParent = $ProjectRoot
$gitRepository = $false
while ($gitParent) {
  if (Test-Path -LiteralPath (Join-Path $gitParent '.git')) { $gitRepository = $true; break }
  $gitParent = Split-Path -Parent $gitParent
}
if ($gitRepository) {
  # ls-files reads the index only; disable optional locks and filesystem monitors.
  if (@(Get-ChildItem Env: | Where-Object { $_.Name -match '^GIT_(DIR|WORK_TREE|INDEX_FILE|COMMON_DIR|CONFIG.*)$' }).Count) { throw 'Git environment overrides require separate review' }
  $tracked = @(& git --no-optional-locks -C $ProjectRoot -c core.fsmonitor=false ls-files -- .hebrinex 2>&1)
  if ($LASTEXITCODE -ne 0) { throw 'Cannot verify consumer Git index' }
  if ($tracked.Count) { throw 'Consumer .hebrinex contains tracked files; untracking requires a separate reviewed Git action' }
}
$material = [ordered]@{
  root = $Root; project = $ProjectRoot; version = $version
  engine = Get-Digest $cli; common = Get-Digest $module
  entrypoint = Get-Digest $PSCommandPath; manifest = Get-Digest $manifest
  source_binding = Get-Digest (Join-Path $Root 'PROJECT_BINDING.yaml')
  source_canonical = Get-Digest $sourceCanonical
  distribution = $records.ToArray(); target = $snapshotState; gitignore = Get-Digest $gitignore
  imports = $importPlan; pending_directories = $directoryPlan
  metadata_updates = $metadataUpdates
}
$digest = Get-Sha256Hex ($material | ConvertTo-Json -Depth 12 -Compress)
$command = '& ' + (Quote-Argument $PSCommandPath) + ' -Root ' + (Quote-Argument $Root) + ' -ProjectRoot ' + (Quote-Argument $ProjectRoot) + ' -Apply -Snapshot ' + (Quote-Argument $digest) + ' -AcceptOverwritePathsJson ' + (Quote-Argument $AcceptOverwritePathsJson)
$ignored = $ignoreState -eq 'ignored'
$noop = $adds.Count -eq 0 -and $overwrites.Count -eq 0 -and $imports.Count -eq 0 -and $approvalImports.Count -eq 0 -and $pendingDirs.Count -eq 0 -and $metadataUpdates.Count -eq 0 -and $version -eq $sourceVersion -and $ignored -and (Test-Path -LiteralPath $canonicalPath -PathType Leaf)
$plan = [ordered]@{
  schema = 'hebrinex.consumer_migration.v1'; status = 'planned'; writes_possible = $false
  root = $Root; project_root = $ProjectRoot; authority = $bound
  from_version = $version; to_version = $sourceVersion; snapshot = $digest
  command_text = $command; noop = $noop; overwrites = @($overwrites); adds = @($adds)
  preserved = @($preserved); conflicts = $(if ($acceptanceMatches) { @() } else { @($overwrites) })
  acceptance_matches = $acceptanceMatches
  imports = $importPlan; pending_directories = $directoryPlan
  approval_imports = @($approvalImports.ToArray() | Sort-Object destination)
  approval_import_policy = 'Copy missing legacy approvals to instance/sdd/progress/approvals; canonical files win. Approval issuance is outside the snapshot; Apply replans and verifies these imports.'
  metadata_updates = $metadataUpdates
  preservation = 'Canonical instance wins; legacy state fills missing canonical files. Runtime/local configuration follows engine preserve policy.'
  engine_effects = @('backup and migration report','canonical binding/version and post-migration contract','missing canonical legacy state','project .gitignore')
  recovery = 'Explicit restore-bound backup overlay only; additions and project .gitignore are not reverted.'
}
if ($CheckOnly) { $plan | ConvertTo-Json -Depth 12; return }
if (-not $Snapshot -or $Snapshot -cne $digest) { throw 'Stale or missing snapshot; repeat CheckOnly' }
if (-not $acceptanceMatches) { throw 'Exact reviewed overwrite list required' }
if (-not $ApprovalId) { throw 'ApprovalId required' }
if ($ApprovalId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$') { throw 'Invalid ApprovalId' }
foreach ($approvalDir in @('instance/sdd/progress/approvals','orquestador/sdd/progress/approvals')) {
  [void](Assert-LocalPath (Join-Path $bound ($approvalDir + '/' + $ApprovalId + '.yaml')))
}
$approval = Test-ApprovalEnvelope -Root $bound -ApprovalId $ApprovalId -CommandText $command
if (-not $approval.Valid) { throw "Approval rejected: $($approval.Reason)" }
if ($noop) { $plan.status = 'noop'; $plan | ConvertTo-Json -Depth 12; return }
$plan.writes_possible = $true
$canonicalApprovalHashes = @($targetFiles | Where-Object { $_.path -match '^instance/sdd/progress/approvals/' } | ForEach-Object { [pscustomobject]@{ path = $_.path; hash = Get-Digest $_.full } })
try {
  $stage = 'engine_apply'
  $global:LASTEXITCODE = 0
  $engineOutput = @(& $cli update-bound -Root $Root -ProjectRoot $ProjectRoot -Apply *>&1)
  $engineExitCode = $LASTEXITCODE
  if ($engineExitCode -ne 0) { throw "update-bound returned failure: exit_code=$engineExitCode" }
  $stage = 'post_apply_verification'
  $verifiedDirectoryAncestors.Clear()
  Import-Module $module -Force -DisableNameChecking -Scope Local
  foreach ($record in $records) {
    if ((Get-Digest (Join-Path $bound $record.path)) -ne $record.source) { throw "Distribution verification failed: $($record.path)" }
  }
  $afterBinding = Read-Binding $canonicalPath
  Assert-Bound $afterBinding
  if ($afterBinding.harness_instance_id -cne $binding.harness_instance_id) { throw 'Canonical identity verification failed' }
  if ($afterBinding.harness_version -ne $sourceVersion) { throw 'Canonical version verification failed' }
  if ((Get-Digest $pinDestinationPath) -cne $pinAfterHash) { throw 'Canonical session pin metadata verification failed' }
  foreach ($import in @($importPlan) + @($approvalImports.ToArray())) {
    $expectedHash = if ($import.destination -eq $pinDestination) { $pinAfterHash } else { $import.sha256 }
    if ((Get-Digest (Assert-LocalPath (Join-Path $bound $import.destination))) -cne $expectedHash) { throw "Canonical import verification failed: $($import.destination)" }
  }
  foreach ($file in $snapshotState) {
    if ($file.path -notmatch '^instance/' -or $file.path -in @('instance/PROJECT_BINDING.yaml','instance/memory/local/session-pin.md','instance/migration/contracts/post-migration-contract.yaml')) { continue }
    if ((Get-Digest (Assert-LocalPath (Join-Path $bound $file.path))) -cne $file.hash) { throw "Canonical preservation verification failed: $($file.path)" }
  }
  foreach ($file in $canonicalApprovalHashes) {
    if ((Get-Digest (Assert-LocalPath (Join-Path $bound $file.path))) -cne $file.hash) { throw "Canonical approval preservation failed: $($file.path)" }
  }
  if (-not (Test-Path -LiteralPath $gitignore -PathType Leaf) -or (Get-ConsumerHarnessIgnoreState ([IO.File]::ReadAllText($gitignore))) -ne 'ignored') { throw 'Project gitignore verification failed' }
  $plan.status = 'applied'
  $plan['engine_output'] = @($engineOutput | ForEach-Object { $_.ToString() })
  $plan | ConvertTo-Json -Depth 12
} catch {
  $plan.status = 'failed_writes_possible'
  $plan['error'] = $_.Exception.Message
  $plan['error_stage'] = $stage
  $plan | ConvertTo-Json -Depth 12
  throw
}
