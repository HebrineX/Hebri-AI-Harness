# hebri-common.psm1 - Shared helpers for Hebri-AI-Harness runtime scripts.
# Compatible with Windows PowerShell 5.1 and PowerShell 7+.

Set-StrictMode -Version 2.0

function Resolve-HarnessPath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )
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
  return (Join-Path (Join-Path $Root $script:ApprovalsRelativeDir) ($ApprovalId + '.yaml'))
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
  $locksDir = Join-Path $Root $script:LocksRelativeDir
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

  $lockPathFull = Join-Path (Join-Path $Root $script:LocksRelativeDir) ($lockId + '.lock.md')
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
  $locksDir = Join-Path $Root $script:LocksRelativeDir
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

Export-ModuleMember -Function @(
  'Resolve-HarnessPath',
  'Read-HarnessText',
  'Get-Scalar',
  'Get-SectionScalar',
  'Get-YamlList',
  'Redact-Text',
  'Limit-Text',
  'Ensure-Directory',
  'Write-Utf8Text',
  'Get-Sha256Hex',
  'Get-ApprovalPath',
  'New-ApprovalEnvelope',
  'Test-ApprovalEnvelope',
  'Get-LockInventory',
  'Get-NormalizedLockPath',
  'Test-LockPathOverlap',
  'Find-LockForPath',
  'New-HarnessLock',
  'Set-HarnessLockReleased'
)
