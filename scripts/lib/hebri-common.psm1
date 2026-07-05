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

function Get-LockInventory {
  param([Parameter(Mandatory = $true)][string]$Root)
  $locksDir = Join-Path $Root 'orquestador/sdd/progress/locks'
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
    $entry = @{ LockId = $lockId; ExpiresAt = $expiresAt; File = $file.Name }
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
  'Get-LockInventory'
)
