param([string]$Root = (Split-Path -Parent $PSScriptRoot), [switch]$RunNegativeTests)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath $Root).Path
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
  Write-Host 'Harness inventory validation not applicable: Windows-local entrypoint'
  exit 0
}
Import-Module (Join-Path $Root 'scripts/lib/hebri-common.psm1') -Force -DisableNameChecking -Prefix Inv -Scope Local
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('harness-inventory-' + [guid]::NewGuid().ToString('N'))
$scriptPath = Join-Path $Root 'scripts/inventory-harness.ps1'
$authority = Join-Path $fixture 'authority'
$search = Join-Path $fixture 'projects'
$links = New-Object 'System.Collections.Generic.List[string]'
$failures = New-Object 'System.Collections.Generic.List[string]'
function Assert-Inventory([bool]$Condition, [string]$Message) {
  if (-not $Condition) { [void]$failures.Add($Message) }
}
function New-TestApproval([string]$Text, [string]$Purpose) {
  Import-Module (Join-Path $Root 'scripts/lib/hebri-common.psm1') -Force -DisableNameChecking -Prefix Inv -Scope Local
  return New-InvApprovalEnvelope -Root $authority -CommandText $Text -Purpose $Purpose -TtlMinutes 5
}
function Invoke-Inventory([string]$Json, [string]$Id = '', [int]$Depth = 8, [int]$Entries = 5000, [int]$Results = 500) {
  if ($Id -eq '') {
    $output = & $scriptPath -Root $authority -RootsJson $Json -CheckOnly -MaxDepth $Depth -MaxEntries $Entries -MaxResults $Results
  } else {
    $output = & $scriptPath -Root $authority -RootsJson $Json -Apply -ApprovalId $Id -MaxDepth $Depth -MaxEntries $Entries -MaxResults $Results
  }
  return ($output | ConvertFrom-Json)
}
try {
  [void][IO.Directory]::CreateDirectory($authority)
  [void][IO.Directory]::CreateDirectory((Join-Path $search 'one/.hebrinex'))
  [void][IO.Directory]::CreateDirectory((Join-Path $search 'two/.hebrinex'))
  [IO.File]::WriteAllText((Join-Path $authority 'HARNESS_VERSION'),'0.17.2')
  $json = ConvertTo-Json -InputObject @($search) -Compress
  $before = @(Get-ChildItem -LiteralPath $fixture -Force -Recurse | ForEach-Object FullName)
  $plan = Invoke-Inventory $json
  Assert-Inventory ($plan.coverage -eq 'not_scanned' -and -not $plan.writes -and -not $plan.executed) 'CheckOnly must only emit a plan'
  $after = @(Get-ChildItem -LiteralPath $fixture -Force -Recurse | ForEach-Object FullName)
  Assert-Inventory (@(Compare-Object $before $after).Count -eq 0) 'CheckOnly changed filesystem'
  $fake = Invoke-Inventory $json 'APR-FAKE'
  Assert-Inventory (-not $fake.executed) 'fake approval must not scan'
  $noApproval = & $scriptPath -Root $authority -RootsJson $json -Apply | ConvertFrom-Json
  Assert-Inventory ($noApproval.reason -eq 'approval_required' -and -not $noApproval.executed) 'missing approval must not scan'
  $approval = New-TestApproval $plan.command_text 'inventory fixture'
  $scan = Invoke-Inventory $json $approval.Id
  Assert-Inventory ($scan.coverage -eq 'complete_within_discovery_scope' -and @($scan.records).Count -eq 2 -and -not $scan.writes) 'approved exact plan must discover two candidates'
  $changed = Invoke-Inventory $json $approval.Id 1
  Assert-Inventory ($changed.reason -eq 'approval_command_mismatch' -and -not $changed.executed) 'changed limits must invalidate approval'
  $otherJson = ConvertTo-Json -InputObject @($authority) -Compress
  $changedRoot = Invoke-Inventory $otherJson $approval.Id
  Assert-Inventory ($changedRoot.reason -eq 'approval_command_mismatch' -and -not $changedRoot.executed) 'changed roots must invalidate approval'
  $changedTime = & $scriptPath -Root $authority -RootsJson $json -Apply -ApprovalId $approval.Id -TimeoutSeconds 1 | ConvertFrom-Json
  Assert-Inventory ($changedTime.reason -eq 'approval_command_mismatch' -and -not $changedTime.executed) 'changed timeout must invalidate approval'
  foreach ($limits in @(@(0,5000,500),@(8,1,500),@(8,5000,1))) {
    $p = Invoke-Inventory $json '' $limits[0] $limits[1] $limits[2]
    $a = New-TestApproval $p.command_text 'inventory cap fixture'
    $s = Invoke-Inventory $json $a.Id $limits[0] $limits[1] $limits[2]
    Assert-Inventory ($s.coverage -eq 'partial') 'depth/entry/result cap must report partial'
  }
  $missingJson = ConvertTo-Json -InputObject @((Join-Path $fixture 'missing')) -Compress
  $p = Invoke-Inventory $missingJson
  $a = New-TestApproval $p.command_text 'missing root fixture'
  $s = Invoke-Inventory $missingJson $a.Id
  Assert-Inventory ($s.coverage -eq 'partial' -and $s.records[0].kind -eq 'not_inspected') 'missing root must not report absence'
  [void][IO.Directory]::CreateDirectory((Join-Path $search 'backups/old/.hebrinex'))
  $s = Invoke-Inventory $json $approval.Id
  Assert-Inventory ($s.coverage -eq 'partial' -and @($s.records | Where-Object kind -eq 'candidate').Count -eq 2) 'backups must not be traversed'
  $excludedRoot = Invoke-Inventory (ConvertTo-Json -InputObject @((Join-Path $search 'backups/old')) -Compress)
  Assert-Inventory ($excludedRoot.reason -eq 'root_inside_excluded_tree' -and $excludedRoot.command_text -eq '') 'root cannot enter an excluded subtree'
  $wide = Join-Path $fixture 'wide'
  [void][IO.Directory]::CreateDirectory((Join-Path $wide '.hebrinex'))
  [void][IO.Directory]::CreateDirectory((Join-Path $wide 'other'))
  $wideJson = ConvertTo-Json -InputObject @($wide,(Join-Path $wide '.hebrinex')) -Compress
  $p = Invoke-Inventory $wideJson '' 8 2 500
  $a = New-TestApproval $p.command_text 'queued candidate fixture'
  $s = Invoke-Inventory $wideJson $a.Id 8 2 500
  Assert-Inventory ($s.coverage -eq 'partial' -and @($s.records | Where-Object kind -eq 'candidate').Count -eq 1) 'entry cap must retain already queued candidate'
  foreach ($invalid in @('["C:\\"]','["\\\\server\\share"]','["relative"]','[]','{}')) {
    $p = Invoke-Inventory $invalid
    Assert-Inventory ($p.command_text -eq '' -and -not $p.executed) 'invalid or broad root must not produce executable plan'
  }
  foreach ($suffix in @('backups.','backups /child','.hebrinex./instance')) {
    $invalid = ConvertTo-Json -InputObject @((Join-Path $search $suffix)) -Compress
    $p = Invoke-Inventory $invalid
    Assert-Inventory ($p.reason -eq 'noncanonical_path_component' -and $p.command_text -eq '') 'Windows path aliases must be rejected before planning'
  }
  $link = Join-Path $search 'linked'
  try {
    [void](New-Item -ItemType Junction -Path $link -Target (Join-Path $search 'one') -ErrorAction Stop)
    [void]$links.Add($link)
    $s = Invoke-Inventory $json $approval.Id
    Assert-Inventory (@($s.records | Where-Object detail -eq 'reparse_point_not_followed').Count -eq 1) 'child junction must not be followed'
    $linkedJson = ConvertTo-Json -InputObject @((Join-Path $link '.hebrinex')) -Compress
    $p = Invoke-Inventory $linkedJson
    $a = New-TestApproval $p.command_text 'linked ancestor fixture'
    $s = Invoke-Inventory $linkedJson $a.Id
    Assert-Inventory ($s.coverage -eq 'partial' -and $s.records[0].detail -eq 'reparse_point_not_followed') 'linked ancestor must not be followed'
  } catch { throw "Junction regression requires a host capable of creating junctions: $($_.Exception.Message)" }
  $storeLink = Join-Path $authority 'instance'
  [void](New-Item -ItemType Junction -Path $storeLink -Target (Join-Path $search 'one') -ErrorAction Stop)
  [void]$links.Add($storeLink)
  $s = Invoke-Inventory $json $approval.Id
  Assert-Inventory ($s.reason -eq 'reparse_point_not_followed' -and -not $s.executed) 'linked approval-store ancestor must block before envelope access'
  [IO.Directory]::Delete($storeLink)
  [void]$links.Remove($storeLink)
  $text = [IO.File]::ReadAllText($approval.Path)
  $text = [regex]::Replace($text, '(?m)^expires_at:.*$', 'expires_at: "2000-01-01T00:00:00Z"')
  [IO.File]::WriteAllText($approval.Path,$text)
  $expired = Invoke-Inventory $json $approval.Id
  Assert-Inventory ($expired.reason -eq 'approval_expired' -and -not $expired.executed) 'expired approval must not scan'
} finally {
  foreach ($link in $links) { [IO.Directory]::Delete($link) }
  $full = [IO.Path]::GetFullPath($fixture)
  $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($full) -notlike 'harness-inventory-*') { throw 'fixture cleanup containment failed' }
  Remove-Item -LiteralPath $full -Recurse -Force
}
if ($failures.Count) { $failures | ForEach-Object { Write-Host "FAIL: $_" }; exit 1 }
Write-Host 'Harness inventory validation OK'
exit 0
