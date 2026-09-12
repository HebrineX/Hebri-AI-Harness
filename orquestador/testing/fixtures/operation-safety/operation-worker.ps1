param(
  [Parameter(Mandatory = $true)][ValidateSet('lock','publish')][string]$Mode,
  [Parameter(Mandatory = $true)][string]$ModulePath,
  [Parameter(Mandatory = $true)][string]$DescriptorPath,
  [Parameter(Mandatory = $true)][string]$ApprovalId,
  [Parameter(Mandatory = $true)][string]$ApprovalStoreRoot,
  [string]$BarrierPath = '',
  [string]$ResultPath = '',
  [string]$TargetPath = '',
  [string]$Content = '',
  [string]$ExpectedSha256 = '',
  [string]$FailurePoint = '',
  [int]$HoldMilliseconds = 700
)

$ErrorActionPreference = 'Stop'
Import-Module $ModulePath -Force -DisableNameChecking -Scope Local

function Write-WorkerResult([object]$Value) {
  if ([string]::IsNullOrWhiteSpace($ResultPath)) { return }
  Write-HebriAtomicJsonDocument -Path $ResultPath -Value $Value
}

if (-not [string]::IsNullOrWhiteSpace($BarrierPath)) {
  $deadline = (Get-Date).AddSeconds(15)
  while (-not (Test-Path -LiteralPath $BarrierPath -PathType Leaf)) {
    if ((Get-Date) -ge $deadline) { throw 'worker barrier timeout' }
    Start-Sleep -Milliseconds 20
  }
}

$descriptor = Read-HebriJsonDocument $DescriptorPath
try {
  $lock = Enter-HebriOperationLock -Descriptor $descriptor -ApprovalId $ApprovalId -ApprovalStoreRoot $ApprovalStoreRoot
  if ($Mode -eq 'lock') {
    Write-WorkerResult ([ordered]@{ result = 'acquired'; lock_path = $lock.Path; pid = $PID; at = (Get-Date).ToUniversalTime().ToString('o') })
    Start-Sleep -Milliseconds $HoldMilliseconds
    [void](Exit-HebriOperationLock -LockPath $lock.Path)
    exit 0
  }

  $journal = New-HebriOperationJournal -Descriptor $descriptor -ApprovalId $ApprovalId -LockPath $lock.Path
  $result = Publish-HebriAtomicFile -Descriptor $descriptor -ApprovalId $ApprovalId -ApprovalStoreRoot $ApprovalStoreRoot -LockPath $lock.Path -JournalPath $journal.Path -Path $TargetPath -Content $Content -ExpectedSha256 $ExpectedSha256 -FailurePoint $FailurePoint
  [void](Exit-HebriOperationLock -LockPath $lock.Path)
  Write-WorkerResult ([ordered]@{ result = 'committed'; operation_id = $result.operation_id; journal_path = $journal.Path })
  exit 0
}
catch {
  Write-WorkerResult ([ordered]@{ result = 'blocked'; reason = $_.Exception.Message; pid = $PID; at = (Get-Date).ToUniversalTime().ToString('o') })
  exit 2
}
