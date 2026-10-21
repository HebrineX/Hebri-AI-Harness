param(
  [Parameter(Mandatory = $true)][string]$Root,
  [Parameter(Mandatory = $true)][string]$RootsJson,
  [switch]$CheckOnly,
  [switch]$Apply,
  [string]$ApprovalId = '',
  [ValidateRange(0,16)][int]$MaxDepth = 8,
  [ValidateRange(1,10000)][int]$MaxEntries = 5000,
  [ValidateRange(1,1000)][int]$MaxResults = 500,
  [ValidateRange(1,120)][int]$TimeoutSeconds = 30
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/hebri-common.psm1') -Force -DisableNameChecking -Scope Local

function Get-LocalAbsolutePath([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path) -or $Path -notmatch '^[A-Za-z]:[\\/]' -or
      $Path.Substring(2) -match '[:*?\[\]]') { throw 'explicit_local_absolute_path_required' }
  foreach ($part in ($Path.Substring(3) -split '[\\/]')) {
    if ($part -match '[. ]$') { throw 'noncanonical_path_component' }
  }
  $full = [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
  if ($full.Length -le 3 -or $full.Length -gt 1024) { throw 'root_too_broad_or_long' }
  $drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($full))
  if ($drive.DriveType -ne [IO.DriveType]::Fixed) { throw 'fixed_local_drive_required' }
  return $full
}

function Assert-NoLinks([string]$Path, [switch]$AllowMissing) {
  # Check each parent before touching a child; never resolve through a link first.
  $driveRoot = [IO.Path]::GetPathRoot($Path)
  $current = $driveRoot
  $parts = @('') + @($Path.Substring($driveRoot.Length) -split '[\\/]' | Where-Object { $_ -ne '' })
  foreach ($part in $parts) {
    if ($part -match '[. ]$') { throw 'noncanonical_path_component' }
    if ($part -ne '') { $current = Join-Path $current $part }
    try { $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop }
    catch [System.Management.Automation.ItemNotFoundException] {
      if ($AllowMissing) { return }
      throw
    }
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'reparse_point_not_followed' }
  }
}

$result = [ordered]@{
  schema = 'hebrinex.harness_discovery'; version = '1'
  mode = 'CheckOnly'; writes = $false; executed = $false
  command_text = ''; plan = $null; records = @()
  coverage = 'not_scanned'; limit = ''; reason = ''
}
try {
  if ($CheckOnly -eq $Apply) { throw 'choose_exactly_one_mode' }
  if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'windows_local_discovery_only' }
  $Root = Get-LocalAbsolutePath $Root
  if (-not $RootsJson.Trim().StartsWith('[')) { throw 'roots_must_be_json_array_of_1_to_16_paths' }
  # A property preserves singleton arrays consistently in Windows PS5.1 and PS7.
  $document = ConvertFrom-Json -InputObject ('{"roots":' + $RootsJson + '}')
  $requested = $document.roots
  if (@($document.PSObject.Properties).Count -ne 1 -or $requested -isnot [array] -or
      $requested.Count -lt 1 -or $requested.Count -gt 16) { throw 'roots_must_be_json_array_of_1_to_16_paths' }
  $roots = New-Object 'System.Collections.Generic.List[string]'
  foreach ($path in $requested) {
    if ($path -isnot [string]) { throw 'root_must_be_string' }
    $canonical = Get-LocalAbsolutePath $path
    if (-not $roots.Contains($canonical)) { [void]$roots.Add($canonical) }
  }
  $excluded = @('.git','node_modules','artifacts','backups','backup','snapshots','snapshot','staging','bin','obj','.venv','venv')
  foreach ($path in $roots) {
    $components = @($path.Substring(3) -split '[\\/]')
    for ($index = 0; $index -lt $components.Count; $index++) {
      if ($components[$index].ToLowerInvariant() -in $excluded -or
          ($components[$index] -ieq '.hebrinex' -and $index -lt $components.Count - 1)) {
        throw 'root_inside_excluded_tree'
      }
    }
  }
  $plan = [ordered]@{
    schema = 'hebrinex.harness_discovery.plan'; version = '1'; authority_root = $Root
    roots = @($roots.ToArray()); max_depth = $MaxDepth; max_entries = $MaxEntries
    max_results = $MaxResults; timeout_seconds = $TimeoutSeconds; max_path_chars = 1024
    excluded_names = $excluded; follow_links = $false; consumer_file_content_reads = $false
  }
  $result.plan = $plan
  $result.command_text = 'harness-discovery-v1 ' + ($plan | ConvertTo-Json -Depth 5 -Compress)
  if ($CheckOnly) {
    $result.reason = 'approve_exact_command_text_then_apply_same_arguments'
    $result | ConvertTo-Json -Depth 8
    exit 0
  }
  $result.mode = 'Apply'
  Assert-NoLinks $Root
  if ([string]::IsNullOrWhiteSpace($ApprovalId)) { throw 'approval_required' }
  if ($ApprovalId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$') { throw 'approval_id_invalid_format' }
  # The existing resolver may choose either canonical or legacy approval store.
  foreach ($relative in @('instance/sdd/progress/approvals','orquestador/sdd/progress/approvals')) {
    Assert-NoLinks (Join-Path (Join-Path $Root $relative) ($ApprovalId + '.yaml')) -AllowMissing
  }
  $approval = Test-ApprovalEnvelope -Root $Root -ApprovalId $ApprovalId -CommandText $result.command_text
  if (-not $approval.Valid) { throw $approval.Reason }
  $result.executed = $true
  $records = New-Object System.Collections.Generic.List[object]
  $queue = New-Object 'System.Collections.Generic.Queue[object]'
  $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach ($path in $roots) { $queue.Enqueue(@{ path = $path; depth = 0 }) }
  $clock = [Diagnostics.Stopwatch]::StartNew()
  $entries = 0
  $partial = $false
  while ($queue.Count -gt 0) {
    if ($clock.Elapsed.TotalSeconds -ge $TimeoutSeconds) { $result.limit = 'timeout'; break }
    if ($entries -ge $MaxEntries) { $result.limit = 'max_entries'; break }
    if ($records.Count -ge $MaxResults) { $result.limit = 'max_results'; break }
    $node = $queue.Dequeue()
    $path = [string]$node.path
    if (-not $seen.Add($path)) { continue }
    $entries++
    try {
      if ($path.Length -gt 1024) { throw 'path_too_long' }
      Assert-NoLinks $path
      $name = [IO.Path]::GetFileName($path).ToLowerInvariant()
      if ($name -eq '.hebrinex') {
        [void]$records.Add(@{ path = $path; kind = 'candidate'; detail = 'contents_and_binding_not_inspected' })
        continue
      }
      if ($name -in $excluded) {
        $partial = $true
        [void]$records.Add(@{ path = $path; kind = 'excluded'; detail = 'excluded_name' })
        continue
      }
      if ($node.depth -ge $MaxDepth) {
        $partial = $true
        [void]$records.Add(@{ path = $path; kind = 'excluded'; detail = 'max_depth' })
        continue
      }
      if ($result.limit -eq 'max_entries') { continue }
      # Lazy enumeration, bounded queue; never materialize an entire recursive tree.
      foreach ($child in [IO.Directory]::EnumerateDirectories($path)) {
        if ($clock.Elapsed.TotalSeconds -ge $TimeoutSeconds) { $result.limit = 'timeout'; break }
        if (($entries + $queue.Count) -ge $MaxEntries) { $result.limit = 'max_entries'; break }
        $queue.Enqueue(@{ path = $child; depth = ($node.depth + 1) })
      }
      if ($result.limit -eq 'timeout') { break }
    }
    catch {
      $partial = $true
      $detail = if ($_.Exception.Message -in @('reparse_point_not_followed','path_too_long','noncanonical_path_component')) { $_.Exception.Message } else { 'unavailable_or_access_denied' }
      [void]$records.Add(@{ path = $path.Substring(0, [Math]::Min(1024,$path.Length)); kind = 'not_inspected'; detail = $detail })
    }
  }
  $result.records = @($records.ToArray())
  $result.coverage = if ($partial -or $result.limit) { 'partial' } else { 'complete_within_discovery_scope' }
  $result.reason = 'discovery_only_not_migration_inventory'
  $result | ConvertTo-Json -Depth 8
  if ($result.coverage -eq 'partial') { exit 3 }
  exit 0
}
catch {
  $result.reason = $_.Exception.Message
  $result | ConvertTo-Json -Depth 8
  exit 2
}
