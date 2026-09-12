param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$RunNegativeTests
)

$ErrorActionPreference = 'Stop'
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Results = New-Object System.Collections.Generic.List[object]

function Add-Failure([string]$Message) { [void]$script:Failures.Add($Message) }
function Add-Result([string]$Id, [string]$Result, [string]$Evidence) {
  [void]$script:Results.Add([pscustomobject]@{ id = $Id; result = $Result; evidence = $Evidence })
  Write-Host "$Id=$Result $Evidence"
}
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { Add-Failure $Message } }
function Assert-ThrowsCode([scriptblock]$Action, [string]$Code, [string]$Message) {
  try { & $Action; Add-Failure "$Message (no exception)" }
  catch { if ($_.Exception.Message -notmatch ('^' + [regex]::Escape($Code) + ':')) { Add-Failure "$Message ($($_.Exception.Message))" } }
}
function Write-TestText([string]$Path, [string]$Text) {
  $parent = Split-Path -Parent $Path
  if (-not [string]::IsNullOrWhiteSpace($parent)) { [void][IO.Directory]::CreateDirectory($parent) }
  [IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), [Text.UTF8Encoding]::new($false))
}
function Get-PowerShellPath {
  $path = (Get-Process -Id $PID).Path
  if (-not [string]::IsNullOrWhiteSpace($path)) { return $path }
  $command = Get-Command pwsh -ErrorAction SilentlyContinue
  if ($null -eq $command) { $command = Get-Command powershell -ErrorAction Stop }
  return $command.Source
}
function New-TestContext([string]$Name, [string]$ProjectId) {
  $projectRoot = Join-Path $script:RuntimeRoot $Name
  $instanceRoot = Join-Path $projectRoot '.hebrinex/instance'
  $catalogRoot = Join-Path $script:RuntimeRoot ('catalog/' + $Name)
  [void][IO.Directory]::CreateDirectory($instanceRoot)
  [void][IO.Directory]::CreateDirectory($catalogRoot)
  Write-TestText (Join-Path $projectRoot '.hebrinex-operation-fixture') "owned-by=validate-operation-safety`n"
  return [pscustomobject]@{
    project_id = $ProjectId
    install_root = $Root
    project_root = $projectRoot
    instance_root = $instanceRoot
    catalog_root = $catalogRoot
  }
}
function Save-Descriptor([object]$Context, [object]$Descriptor) {
  $path = Join-Path $Context.instance_root ('runtime/descriptors/' + $Descriptor.operation_id + '.json')
  Write-HebriAtomicJsonDocument -Path $path -Value $Descriptor -CreateOnly
  return $path
}
function New-TestApproval([object]$Descriptor, [int]$TtlMinutes = 5) {
  return New-HebriScopedApprovalEnvelope -Descriptor $Descriptor -TtlMinutes $TtlMinutes -HumanEvidenceId 'FIXTURE-SI-P02'
}
function Start-OperationWorker {
  param(
    [string]$Mode,
    [string]$DescriptorPath,
    [string]$ApprovalId,
    [string]$ApprovalStoreRoot,
    [string]$BarrierPath = '',
    [string]$ResultPath = '',
    [string]$TargetPath = '',
    [string]$Content = '',
    [string]$ExpectedSha256 = '',
    [string]$FailurePoint = '',
    [int]$HoldMilliseconds = 700
  )
  $arguments = @(
    '-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$script:WorkerPath,
    '-Mode',$Mode,'-ModulePath',$script:ModulePath,'-DescriptorPath',$DescriptorPath,
    '-ApprovalId',$ApprovalId,'-ApprovalStoreRoot',$ApprovalStoreRoot,
    '-HoldMilliseconds',[string]$HoldMilliseconds
  )
  foreach ($pair in @(
    @('BarrierPath',$BarrierPath), @('ResultPath',$ResultPath), @('TargetPath',$TargetPath),
    @('Content',$Content), @('ExpectedSha256',$ExpectedSha256), @('FailurePoint',$FailurePoint)
  )) {
    if (-not [string]::IsNullOrWhiteSpace([string]$pair[1])) { $arguments += @('-' + $pair[0], [string]$pair[1]) }
  }
  return Start-Process -FilePath $script:PowerShellPath -ArgumentList $arguments -PassThru -NoNewWindow
}
function Wait-Workers([Diagnostics.Process[]]$Processes, [int]$TimeoutSeconds = 20) {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  foreach ($process in $Processes) {
    $remaining = [math]::Max(1, [int](($deadline - (Get-Date)).TotalMilliseconds))
    if (-not $process.WaitForExit($remaining)) {
      try { $process.Kill() } catch {}
      Add-Failure "worker $($process.Id) timed out"
    }
    try { $process.Refresh() } catch {}
  }
}
function Read-Result([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  return Read-HebriJsonDocument $Path
}
function Get-TreeInventory([string[]]$Paths) {
  $items = New-Object System.Collections.Generic.List[string]
  foreach ($path in $Paths) {
    if (-not (Test-Path -LiteralPath $path)) { [void]$items.Add("MISSING|$path"); continue }
    $rootItem = Get-Item -LiteralPath $path -Force
    [void]$items.Add("ROOT|$($rootItem.FullName)|$($rootItem.PSIsContainer)")
    if ($rootItem.PSIsContainer) {
      foreach ($item in @(Get-ChildItem -LiteralPath $path -Force -Recurse | Sort-Object FullName)) {
        if ($item.PSIsContainer) { [void]$items.Add("DIR|$($item.FullName)") }
        else { [void]$items.Add("FILE|$($item.FullName)|$($item.Length)|$($item.LastWriteTimeUtc.Ticks)|$(Get-HebriFileSha256 $item.FullName)") }
      }
    }
  }
  return ($items -join "`n")
}
function Assert-NoActiveOperationLocks([object]$Context, [string]$Message) {
  $lockRoot = Join-Path $Context.instance_root 'runtime/locks'
  if (-not (Test-Path -LiteralPath $lockRoot -PathType Container)) { return }
  foreach ($file in @(Get-ChildItem -LiteralPath $lockRoot -Filter 'OPLOCK-*.json' -File)) {
    $lock = Read-HebriJsonDocument $file.FullName
    if ($lock.status -eq 'active') { Add-Failure "$Message ($($file.Name))" }
  }
}

$Root = (Resolve-Path -LiteralPath $Root).Path
$script:ModulePath = Join-Path $Root 'scripts/lib/hebri-common.psm1'
$script:WorkerPath = Join-Path $Root 'orquestador/testing/fixtures/operation-safety/operation-worker.ps1'
$fixtureBase = Join-Path $Root 'orquestador/testing/fixtures/operation-safety'
$script:RuntimeRoot = Join-Path $fixtureBase ('.runtime-' + $PID + '-' + [guid]::NewGuid().ToString('N'))
$runtimeMarker = Join-Path $script:RuntimeRoot '.validator-owned'
[void][IO.Directory]::CreateDirectory($script:RuntimeRoot)
Write-TestText $runtimeMarker "owned-by=validate-operation-safety`n"
$script:PowerShellPath = Get-PowerShellPath
Import-Module $script:ModulePath -Force -DisableNameChecking -Scope Local

try {
  # V01: real-process exclusion for overlapping resources.
  $context = New-TestContext 'v01-project' 'P02-V01'
  $target = Join-Path $context.project_root 'state/value.txt'
  Write-TestText $target "initial`n"
  $descriptorA = New-HebriOperationDescriptor -Context $context -Operation 'fixture:lock-a' -WriteSet @($target) -CodeVersion '0.17.1' -Plan ([ordered]@{ fixture_mode = $true })
  $descriptorB = New-HebriOperationDescriptor -Context $context -Operation 'fixture:lock-b' -WriteSet @($target) -CodeVersion '0.17.1' -Plan ([ordered]@{ fixture_mode = $true })
  $descriptorAPath = Save-Descriptor $context $descriptorA
  $descriptorBPath = Save-Descriptor $context $descriptorB
  $approvalA = New-TestApproval $descriptorA
  $approvalB = New-TestApproval $descriptorB
  $barrier = Join-Path $context.project_root 'barrier.go'
  $resultAPath = Join-Path $context.project_root 'worker-a.json'
  $resultBPath = Join-Path $context.project_root 'worker-b.json'
  $processA = Start-OperationWorker -Mode lock -DescriptorPath $descriptorAPath -ApprovalId $approvalA.Id -ApprovalStoreRoot (Split-Path -Parent $approvalA.Path) -BarrierPath $barrier -ResultPath $resultAPath
  $processB = Start-OperationWorker -Mode lock -DescriptorPath $descriptorBPath -ApprovalId $approvalB.Id -ApprovalStoreRoot (Split-Path -Parent $approvalB.Path) -BarrierPath $barrier -ResultPath $resultBPath
  Start-Sleep -Milliseconds 150
  Write-TestText $barrier "go`n"
  Wait-Workers @($processA,$processB)
  $workerResults = @((Read-Result $resultAPath),(Read-Result $resultBPath))
  $acquired = @($workerResults | Where-Object { $null -ne $_ -and $_.result -eq 'acquired' }).Count
  $blocked = @($workerResults | Where-Object { $null -ne $_ -and $_.result -eq 'blocked' -and $_.reason -match '^LOCK_BUSY:' }).Count
  Assert-True ($acquired -eq 1 -and $blocked -eq 1) 'P02-V01 expected exactly one acquired and one LOCK_BUSY result'
  Assert-NoActiveOperationLocks $context 'P02-V01 left an active lock'
  Add-Result 'P02-V01' 'pass' "acquired=$acquired blocked=$blocked"

  # V02: separate InstanceRoots do not serialize one another.
  $contextA = New-TestContext 'v02-project-a' 'P02-V02-A'
  $contextB = New-TestContext 'v02-project-b' 'P02-V02-B'
  $targetA = Join-Path $contextA.project_root 'state/value.txt'
  $targetB = Join-Path $contextB.project_root 'state/value.txt'
  Write-TestText $targetA "a`n"; Write-TestText $targetB "b`n"
  $descriptorA = New-HebriOperationDescriptor -Context $contextA -Operation 'fixture:isolated-a' -WriteSet @($targetA) -CodeVersion '0.17.1' -Plan ([ordered]@{ fixture_mode = $true })
  $descriptorB = New-HebriOperationDescriptor -Context $contextB -Operation 'fixture:isolated-b' -WriteSet @($targetB) -CodeVersion '0.17.1' -Plan ([ordered]@{ fixture_mode = $true })
  $descriptorAPath = Save-Descriptor $contextA $descriptorA; $descriptorBPath = Save-Descriptor $contextB $descriptorB
  $approvalA = New-TestApproval $descriptorA; $approvalB = New-TestApproval $descriptorB
  $barrier = Join-Path $script:RuntimeRoot 'v02-barrier.go'
  $resultAPath = Join-Path $contextA.project_root 'worker.json'; $resultBPath = Join-Path $contextB.project_root 'worker.json'
  $processA = Start-OperationWorker -Mode lock -DescriptorPath $descriptorAPath -ApprovalId $approvalA.Id -ApprovalStoreRoot (Split-Path -Parent $approvalA.Path) -BarrierPath $barrier -ResultPath $resultAPath
  $processB = Start-OperationWorker -Mode lock -DescriptorPath $descriptorBPath -ApprovalId $approvalB.Id -ApprovalStoreRoot (Split-Path -Parent $approvalB.Path) -BarrierPath $barrier -ResultPath $resultBPath
  Start-Sleep -Milliseconds 150; Write-TestText $barrier "go`n"; Wait-Workers @($processA,$processB)
  $both = @((Read-Result $resultAPath),(Read-Result $resultBPath))
  Assert-True (@($both | Where-Object { $null -ne $_ -and $_.result -eq 'acquired' }).Count -eq 2) 'P02-V02 expected both isolated projects to acquire'
  Assert-True ((Get-HebriFileSha256 $targetA) -ne '__MISSING__' -and (Get-HebriFileSha256 $targetB) -ne '__MISSING__') 'P02-V02 target inventory was crossed or lost'
  Assert-NoActiveOperationLocks $contextA 'P02-V02 project A left an active lock'; Assert-NoActiveOperationLocks $contextB 'P02-V02 project B left an active lock'
  Add-Result 'P02-V02' 'pass' 'both projects acquired independent InstanceRoot guards'

  # V03: fake, expired, foreign and changed approvals cannot reach business writes.
  $context = New-TestContext 'v03-project' 'P02-V03'
  $target = Join-Path $context.project_root 'state/witness.txt'; Write-TestText $target "original`n"
  $before = Get-HebriFileSha256 $target
  foreach ($case in @('fake','expired','consumed','foreign','changed')) {
    $descriptor = New-HebriOperationDescriptor -Context $context -Operation ('fixture:approval-' + $case) -WriteSet @($target) -CodeVersion '0.17.1' -Plan ([ordered]@{ fixture_mode = $true; case = $case })
    $approval = New-TestApproval $descriptor
    $lock = Enter-HebriOperationLock -Descriptor $descriptor -ApprovalId $approval.Id -ApprovalStoreRoot (Split-Path -Parent $approval.Path)
    $journal = New-HebriOperationJournal -Descriptor $descriptor -ApprovalId $approval.Id -LockPath $lock.Path
    $candidateDescriptor = $descriptor; $candidateApproval = $approval.Id
    if ($case -eq 'fake') { $candidateApproval = 'APR2-DOES-NOT-EXIST' }
    elseif ($case -eq 'expired') {
      $expired = Read-HebriJsonDocument $approval.Path; $expired.expires_at = (Get-Date).ToUniversalTime().AddMinutes(-1).ToString('o'); Write-HebriAtomicJsonDocument -Path $approval.Path -Value $expired
    }
    elseif ($case -eq 'consumed') {
      $consumed = Read-HebriJsonDocument $approval.Path; $consumed.status = 'consumed'; $consumed | Add-Member -NotePropertyName consumed_at -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('o')) -Force; Write-HebriAtomicJsonDocument -Path $approval.Path -Value $consumed
    }
    elseif ($case -eq 'foreign') {
      $foreign = New-HebriOperationDescriptor -Context $context -Operation 'fixture:foreign' -WriteSet @($target) -CodeVersion '0.17.1' -Plan ([ordered]@{ fixture_mode = $true })
      $foreignApproval = New-TestApproval $foreign; $candidateApproval = $foreignApproval.Id
    }
    elseif ($case -eq 'changed') {
      $candidateDescriptor = ([string](ConvertTo-HebriCanonicalJson $descriptor) | ConvertFrom-Json); $candidateDescriptor.plan.case = 'tampered'
    }
    $expectedCode = if ($case -eq 'expired') { 'APPROVAL_EXPIRED' } elseif ($case -eq 'changed') { 'OPERATION_PLAN_HASH_MISMATCH' } else { if ($case -eq 'fake') { 'APPROVAL_REQUIRED' } else { 'APPROVAL_SCOPE_MISMATCH' } }
    Assert-ThrowsCode { Publish-HebriAtomicFile -Descriptor $candidateDescriptor -ApprovalId $candidateApproval -ApprovalStoreRoot (Split-Path -Parent $approval.Path) -LockPath $lock.Path -JournalPath $journal.Path -Path $target -Content "forbidden`n" -ExpectedSha256 $before } $expectedCode "P02-V03 $case approval should reject"
    [void](Exit-HebriOperationLock -LockPath $lock.Path)
    Assert-True ((Get-HebriFileSha256 $target) -eq $before) "P02-V03 $case approval changed business data"
  }
  $bindingDescriptor = New-HebriOperationDescriptor -Context $context -Operation 'fixture:approval-binding' -WriteSet @($target) -CodeVersion '0.17.1' -Plan ([ordered]@{ fixture_mode = $true })
  $bindingApproval = New-TestApproval $bindingDescriptor
  $otherApproval = New-TestApproval $bindingDescriptor
  $bindingLock = Enter-HebriOperationLock -Descriptor $bindingDescriptor -ApprovalId $bindingApproval.Id -ApprovalStoreRoot (Split-Path -Parent $bindingApproval.Path)
  Assert-ThrowsCode { New-HebriOperationJournal -Descriptor $bindingDescriptor -ApprovalId $otherApproval.Id -LockPath $bindingLock.Path } 'APPROVAL_SCOPE_MISMATCH' 'P02-V03 journal must use the approval bound to its lock'
  $bindingJournal = New-HebriOperationJournal -Descriptor $bindingDescriptor -ApprovalId $bindingApproval.Id -LockPath $bindingLock.Path
  $tamperedJournal = Read-HebriJsonDocument $bindingJournal.Path; $tamperedJournal.approval_id = $otherApproval.Id; Write-HebriAtomicJsonDocument -Path $bindingJournal.Path -Value $tamperedJournal
  Assert-ThrowsCode { Publish-HebriAtomicFile -Descriptor $bindingDescriptor -ApprovalId $bindingApproval.Id -ApprovalStoreRoot (Split-Path -Parent $bindingApproval.Path) -LockPath $bindingLock.Path -JournalPath $bindingJournal.Path -Path $target -Content "forbidden`n" -ExpectedSha256 $before } 'APPROVAL_SCOPE_MISMATCH' 'P02-V03 publication must reject a journal bound to another approval'
  [void](Exit-HebriOperationLock -LockPath $bindingLock.Path)
  Assert-True ((Get-HebriFileSha256 $target) -eq $before) 'P02-V03 approval-lock-journal mismatch changed business data'
  Add-Result 'P02-V03' 'pass' 'fake, expired, consumed, foreign, changed and cross-bound approvals rejected with witness unchanged'

  # V04: terminate child processes at every publication boundary and recover.
  $terminationCodes = New-Object System.Collections.Generic.List[int]
  foreach ($point in @('after_prepared','after_backup','after_publish','before_commit','after_approval_consumed')) {
    $context = New-TestContext ('v04-' + $point) ('P02-V04-' + $point)
    $target = Join-Path $context.project_root 'state/value.txt'; Write-TestText $target "original-$point`n"
    $originalHash = Get-HebriFileSha256 $target
    $descriptor = New-HebriOperationDescriptor -Context $context -Operation ('fixture:publish-' + $point) -WriteSet @($target) -CodeVersion '0.17.1' -Plan ([ordered]@{ fixture_mode = $true; failure_point = $point })
    $descriptorPath = Save-Descriptor $context $descriptor; $approval = New-TestApproval $descriptor
    $process = Start-OperationWorker -Mode publish -DescriptorPath $descriptorPath -ApprovalId $approval.Id -ApprovalStoreRoot (Split-Path -Parent $approval.Path) -TargetPath $target -Content "new-$point`n" -ExpectedSha256 $originalHash -FailurePoint $point
    Wait-Workers @($process)
    [void]$terminationCodes.Add([int]$process.ExitCode)
    Assert-True $process.HasExited "P02-V04 $point child process did not terminate"
    $journalPath = Join-Path $context.instance_root ('runtime/journals/' + $descriptor.operation_id + '.json')
    $status = Get-HebriOperationStatus -JournalPath $journalPath
    Assert-True ($status.effective_state -eq 'recovery_required') "P02-V04 $point did not report recovery_required"
    $recovery = New-HebriOperationDescriptor -Context $context -Operation ('recover:' + $descriptor.operation_id) -WriteSet @($target) -CodeVersion '0.17.1' -Plan ([ordered]@{ fixture_mode = $true; original_operation_id = $descriptor.operation_id })
    $recoveryApproval = New-TestApproval $recovery
    $recovered = Invoke-HebriOperationRecovery -RecoveryDescriptor $recovery -ApprovalId $recoveryApproval.Id -ApprovalStoreRoot (Split-Path -Parent $recoveryApproval.Path) -JournalPath $journalPath
    Assert-True ($recovered.final_state -eq 'rolled_back') "P02-V04 $point recovery did not roll back"
    Assert-True ($recovered.schema -eq 'hebrinex.operation_result' -and $recovered.evidence_path -eq $journalPath) "P02-V04 $point recovery result did not satisfy its contract"
    $idempotent = Invoke-HebriOperationRecovery -RecoveryDescriptor $recovery -ApprovalId $recoveryApproval.Id -ApprovalStoreRoot (Split-Path -Parent $recoveryApproval.Path) -JournalPath $journalPath
    Assert-True ($idempotent.schema -eq 'hebrinex.operation_result' -and $idempotent.final_state -eq 'rolled_back' -and $idempotent.evidence_path -eq $journalPath) "P02-V04 $point idempotent recovery result did not satisfy its contract"
    Assert-True ((Get-HebriFileSha256 $target) -eq $originalHash) "P02-V04 $point did not restore the original hash"
    Assert-NoActiveOperationLocks $context "P02-V04 $point left an active lock"
  }
  Add-Result 'P02-V04' 'pass' ("five real child terminations recovered to original hashes; exit_codes=" + ($terminationCodes -join ','))

  # V05: a reused PID identity blocks normal acquisition until approved recovery.
  $context = New-TestContext 'v05-project' 'P02-V05'
  $target = Join-Path $context.project_root 'state/value.txt'; Write-TestText $target "original`n"
  $descriptor = New-HebriOperationDescriptor -Context $context -Operation 'fixture:owner-a' -WriteSet @($target) -CodeVersion '0.17.1' -Plan ([ordered]@{ fixture_mode = $true })
  $approval = New-TestApproval $descriptor
  $lock = Enter-HebriOperationLock -Descriptor $descriptor -ApprovalId $approval.Id -ApprovalStoreRoot (Split-Path -Parent $approval.Path)
  $journal = New-HebriOperationJournal -Descriptor $descriptor -ApprovalId $approval.Id -LockPath $lock.Path
  $forged = Read-HebriJsonDocument $lock.Path; $forged.owner.process_start_utc = (Get-Date).ToUniversalTime().AddHours(-1).ToString('o'); Write-HebriAtomicJsonDocument -Path $lock.Path -Value $forged
  $contender = New-HebriOperationDescriptor -Context $context -Operation 'fixture:owner-b' -WriteSet @($target) -CodeVersion '0.17.1' -Plan ([ordered]@{ fixture_mode = $true })
  $contenderApproval = New-TestApproval $contender
  Assert-ThrowsCode { Enter-HebriOperationLock -Descriptor $contender -ApprovalId $contenderApproval.Id -ApprovalStoreRoot (Split-Path -Parent $contenderApproval.Path) } 'LOCK_OWNER_UNVERIFIED' 'P02-V05 reused PID lock should not be stolen'
  $stillActive = Read-HebriJsonDocument $lock.Path
  Assert-True ($stillActive.status -eq 'active') 'P02-V05 normal acquisition changed the reused-PID lock'
  $recovery = New-HebriOperationDescriptor -Context $context -Operation ('recover:' + $descriptor.operation_id) -WriteSet @($target) -CodeVersion '0.17.1' -Plan ([ordered]@{ fixture_mode = $true; original_operation_id = $descriptor.operation_id })
  $recoveryApproval = New-TestApproval $recovery
  [void](Invoke-HebriOperationRecovery -RecoveryDescriptor $recovery -ApprovalId $recoveryApproval.Id -ApprovalStoreRoot (Split-Path -Parent $recoveryApproval.Path) -JournalPath $journal.Path)
  Assert-NoActiveOperationLocks $context 'P02-V05 approved recovery left an active lock'
  Add-Result 'P02-V05' 'pass' 'reused PID blocked; explicit scoped recovery resolved the lock'

  # V06: revalidate immediately before publish and preserve a concurrent edit.
  $context = New-TestContext 'v06-project' 'P02-V06'
  $target = Join-Path $context.project_root 'state/value.txt'; Write-TestText $target "planned`n"
  $plannedHash = Get-HebriFileSha256 $target
  $descriptor = New-HebriOperationDescriptor -Context $context -Operation 'fixture:precondition' -WriteSet @($target) -CodeVersion '0.17.1' -Plan ([ordered]@{ fixture_mode = $true })
  $approval = New-TestApproval $descriptor; $lock = Enter-HebriOperationLock -Descriptor $descriptor -ApprovalId $approval.Id -ApprovalStoreRoot (Split-Path -Parent $approval.Path); $journal = New-HebriOperationJournal -Descriptor $descriptor -ApprovalId $approval.Id -LockPath $lock.Path
  Write-TestText $target "concurrent-edit`n"; $concurrentHash = Get-HebriFileSha256 $target
  Assert-ThrowsCode { Publish-HebriAtomicFile -Descriptor $descriptor -ApprovalId $approval.Id -ApprovalStoreRoot (Split-Path -Parent $approval.Path) -LockPath $lock.Path -JournalPath $journal.Path -Path $target -Content "forbidden-overwrite`n" -ExpectedSha256 $plannedHash } 'PRECONDITION_CHANGED' 'P02-V06 concurrent change should reject'
  Assert-True ((Get-HebriFileSha256 $target) -eq $concurrentHash) 'P02-V06 overwrote the concurrent edit'
  [void](Exit-HebriOperationLock -LockPath $lock.Path)
  $bypassContext = New-TestContext 'v06-caller-bypass' 'P02-V06-BYPASS'
  $bypassTarget = Join-Path $bypassContext.project_root 'state/value.txt'; Write-TestText $bypassTarget "planned`n"
  $bypassDescriptor = New-HebriOperationDescriptor -Context $bypassContext -Operation 'fixture:precondition-bypass' -WriteSet @($bypassTarget) -CodeVersion '0.17.1' -Plan ([ordered]@{ fixture_mode = $true })
  $bypassApproval = New-TestApproval $bypassDescriptor
  $bypassLock = Enter-HebriOperationLock -Descriptor $bypassDescriptor -ApprovalId $bypassApproval.Id -ApprovalStoreRoot (Split-Path -Parent $bypassApproval.Path)
  $bypassJournal = New-HebriOperationJournal -Descriptor $bypassDescriptor -ApprovalId $bypassApproval.Id -LockPath $bypassLock.Path
  Write-TestText $bypassTarget "concurrent-edit`n"; $bypassHash = Get-HebriFileSha256 $bypassTarget
  Assert-ThrowsCode { Publish-HebriAtomicFile -Descriptor $bypassDescriptor -ApprovalId $bypassApproval.Id -ApprovalStoreRoot (Split-Path -Parent $bypassApproval.Path) -LockPath $bypassLock.Path -JournalPath $bypassJournal.Path -Path $bypassTarget -Content "forbidden-overwrite`n" -ExpectedSha256 $bypassHash } 'APPROVAL_SCOPE_MISMATCH' 'P02-V06 caller-supplied precondition should not replace the approved hash'
  Assert-True ((Get-HebriFileSha256 $bypassTarget) -eq $bypassHash) 'P02-V06 caller precondition bypass overwrote the concurrent edit'
  [void](Exit-HebriOperationLock -LockPath $bypassLock.Path)
  Add-Result 'P02-V06' 'pass' 'PRECONDITION_CHANGED preserved concurrent content and caller hash substitution was rejected'

  # T06: central writers block before creating their business targets.
  $blockedConsumer = Join-Path $script:RuntimeRoot 'central-blocked-consumer'
  $cli = Join-Path $Root 'scripts/hebrinex.ps1'
  $blockedMessage = ''
  try { & $cli bootstrap -Root $Root -Apply -ProjectRoot $blockedConsumer -RuntimeMode central_instance; Add-Failure 'P02-T06 central bootstrap did not block without operation context' }
  catch { $blockedMessage = $_.Exception.Message }
  Assert-True ($blockedMessage -match '^APPROVAL_REQUIRED:') 'P02-T06 central bootstrap returned the wrong block reason'
  Assert-True (-not (Test-Path -LiteralPath $blockedConsumer)) 'P02-T06 central bootstrap created a target before authorization'
  Add-Result 'P02-T06' 'pass' 'central bootstrap blocked before target creation'
  Import-Module $script:ModulePath -Force -DisableNameChecking -Scope Local

  # V07: repeated status and approval validation calls are filesystem-pure.
  $readContext = New-TestContext 'v07-project' 'P02-V07'
  $readTarget = Join-Path $readContext.project_root 'state/value.txt'; Write-TestText $readTarget "read-only`n"
  $readDescriptor = New-HebriOperationDescriptor -Context $readContext -Operation 'fixture:read-status' -WriteSet @($readTarget) -CodeVersion '0.17.1' -Plan ([ordered]@{ fixture_mode = $true })
  $readApproval = New-TestApproval $readDescriptor
  $readLock = Enter-HebriOperationLock -Descriptor $readDescriptor -ApprovalId $readApproval.Id -ApprovalStoreRoot (Split-Path -Parent $readApproval.Path)
  $readJournal = New-HebriOperationJournal -Descriptor $readDescriptor -ApprovalId $readApproval.Id -LockPath $readLock.Path
  [void](Set-HebriOperationJournalState -JournalPath $readJournal.Path -State applying -Evidence 'fixture setup')
  [void](Set-HebriOperationJournalState -JournalPath $readJournal.Path -State committed -Evidence 'fixture setup complete')
  [void](Exit-HebriOperationLock -LockPath $readLock.Path)
  Start-Sleep -Milliseconds 750
  $readPaths = @($readContext.instance_root, (Join-Path $Root 'orquestador/runtime/claude'))
  $inventoryBefore = Get-TreeInventory $readPaths
  [void](Get-HebriOperationStatus -JournalPath $readJournal.Path)
  [void](Get-HebriOperationStatus -JournalPath $readJournal.Path)
  [void](Test-HebriScopedApproval -Descriptor $readDescriptor -ApprovalId $readApproval.Id -StoreRoot (Split-Path -Parent $readApproval.Path))
  [void](Test-HebriScopedApproval -Descriptor $readDescriptor -ApprovalId $readApproval.Id -StoreRoot (Split-Path -Parent $readApproval.Path))
  $reentry = Join-Path $Root 'scripts/claude-reentry.ps1'
  @(& $script:PowerShellPath -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $reentry -CheckOnly 2>&1) | Out-Null
  @(& $script:PowerShellPath -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $reentry -CheckOnly 2>&1) | Out-Null
  $inventoryAfter = Get-TreeInventory $readPaths
  if ($inventoryBefore -ne $inventoryAfter) {
    $difference = @(Compare-Object ($inventoryBefore -split "`n") ($inventoryAfter -split "`n") | Select-Object -First 12 | ForEach-Object { $_.SideIndicator + ' ' + $_.InputObject })
    Add-Failure ("P02-V07 read-only calls changed files or directories: " + ($difference -join ' || '))
  }
  else { Add-Result 'P02-V07' 'pass' 'two status, approval and reentry checks preserved inventories' }

  # Static writer coverage and machine-readable contracts.
  $writers = @(
    'scripts/command-gateway.ps1','scripts/hebrinex.ps1','scripts/migrate-harness.ps1','scripts/build-instructions.ps1',
    'scripts/claude-reentry.ps1','scripts/install-claude-hooks.ps1','scripts/install-host-integrations.ps1',
    'scripts/regularize-state.ps1','scripts/regularize-registry.ps1'
  )
  foreach ($writer in $writers) {
    $text = [IO.File]::ReadAllText((Join-Path $Root $writer))
    if ($text -notmatch 'OperationMutationAuthorized') { Add-Failure "P02-T06 missing central operation guard: $writer" }
  }
  foreach ($schema in @('operation-descriptor','scoped-approval','operation-lock','operation-journal','operation-result')) {
    $path = Join-Path $Root ('orquestador/runtime/schemas/' + $schema + '.schema.json')
    try { [void]([IO.File]::ReadAllText($path) | ConvertFrom-Json) } catch { Add-Failure "invalid operation schema JSON: $schema" }
  }
  Add-Result 'P02-CONTRACTS' 'pass' 'writer guards and five JSON contracts present'
}
catch { Add-Failure ('validator aborted: ' + $_.Exception.Message + "`n" + $_.ScriptStackTrace) }
finally {
  if (Test-Path -LiteralPath $script:RuntimeRoot) {
    if (Test-Path -LiteralPath $runtimeMarker -PathType Leaf) { Remove-Item -LiteralPath $script:RuntimeRoot -Recurse -Force }
    else { Add-Failure 'cleanup refused: runtime ownership marker disappeared' }
  }
}

if ($script:Failures.Count -gt 0) {
  Write-Host 'Operation safety validation FAILED'
  foreach ($failure in $script:Failures) { Write-Host " - $failure" }
  exit 1
}

Write-Host "Operation safety validation OK ($($script:Results.Count) checks)"
exit 0
