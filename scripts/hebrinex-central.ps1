param(
  [Parameter(Position = 0)]
  [ValidateSet('help','approve','init','bind','status','list','doctor','validate','reconcile','unbind','migrate','upgrade')]
  [string]$Command = 'help',
  [string]$InstallRoot = (Split-Path -Parent $PSScriptRoot),
  [string]$ProjectRoot = '',
  [string]$CatalogRoot = '',
  [string[]]$SearchRoots = @(),
  [string]$BaselinePath = '',
  [string]$DecisionsPath = '',
  [string]$SnapshotBase = '',
  [string]$SnapshotPath = '',
  [switch]$IncludeGitIgnore,
  [switch]$CopyAsNew,
  [switch]$Restore,
  [switch]$PreservePostMigrationChanges,
  [switch]$CheckOnly,
  [switch]$Apply,
  [string]$OperationDescriptorPath = '',
  [string]$OperationDescriptorJson = '',
  [string]$ScopedApprovalStoreRoot = '',
  [string]$ScopedApprovalId = '',
  [string]$HumanEvidenceId = '',
  [int]$TtlMinutes = 60,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'lib/project-service.psm1') -Force -DisableNameChecking -Scope Local
Import-Module (Join-Path $PSScriptRoot 'lib/legacy-migration-service.psm1') -Force -DisableNameChecking -Scope Local
Import-Module (Join-Path $PSScriptRoot 'lib/hebri-common.psm1') -Force -DisableNameChecking -Prefix 'Core' -Scope Local

function New-CliResult {
  param([string]$CommandName, [string]$Status, [string]$Reason, [int]$ExitCode, [bool]$Writes, [object]$Details, [string]$NextStep, [string]$ProjectId = '')
  if ($null -eq $Details) { $Details = [ordered]@{} }
  $result = [ordered]@{
    schema = 'hebrinex.project_service.result'
    contract_version = '1.0.0'
    cli_api = 'central1'
    command = $CommandName
    status = $Status
    reason = $Reason
    exit_code = $ExitCode
    writes_performed = $Writes
    observed_at = (Get-Date).ToUniversalTime().ToString('o')
    details = $Details
    next_step = $NextStep
  }
  if (-not [string]::IsNullOrWhiteSpace($ProjectId)) { $result.project_id = $ProjectId }
  return [pscustomobject]$result
}

function Write-CliResult {
  param([Parameter(Mandatory = $true)]$Result)
  if ($Json) {
    Write-Output ($Result | ConvertTo-Json -Depth 40 -Compress)
  }
  else {
    Write-Output "command=$($Result.command)"
    Write-Output "status=$($Result.status)"
    Write-Output "reason=$($Result.reason)"
    Write-Output "exit_code=$($Result.exit_code)"
    Write-Output "writes_performed=$($Result.writes_performed.ToString().ToLowerInvariant())"
    if ($null -ne $Result.PSObject.Properties['project_id']) { Write-Output "project_id=$($Result.project_id)" }
    if (-not [string]::IsNullOrWhiteSpace([string]$Result.next_step)) { Write-Output "next_step=$($Result.next_step)" }
    if ($Result.status -eq 'planned') {
      Write-Output 'descriptor_json:'
      Write-Output ($Result.details.descriptor | ConvertTo-Json -Depth 40)
    }
  }
  exit ([int]$Result.exit_code)
}

function Read-OperationDescriptor {
  if (-not [string]::IsNullOrWhiteSpace($OperationDescriptorPath) -and -not [string]::IsNullOrWhiteSpace($OperationDescriptorJson)) {
    throw 'APPROVAL_SCOPE_MISMATCH: provide descriptor path or JSON, not both'
  }
  if (-not [string]::IsNullOrWhiteSpace($OperationDescriptorPath)) {
    return Read-CoreHebriJsonDocument -Path ([IO.Path]::GetFullPath($OperationDescriptorPath))
  }
  if (-not [string]::IsNullOrWhiteSpace($OperationDescriptorJson)) {
    try { return ($OperationDescriptorJson | ConvertFrom-Json) }
    catch { throw ('OPERATION_DESCRIPTOR_INVALID: ' + $_.Exception.Message) }
  }
  throw 'APPROVAL_REQUIRED: an operation descriptor is required'
}

function Test-CliPathEqual([string]$Left, [string]$Right) {
  return [string]::Equals([IO.Path]::GetFullPath($Left).TrimEnd('\','/'), [IO.Path]::GetFullPath($Right).TrimEnd('\','/'), [StringComparison]::OrdinalIgnoreCase)
}

try {
  $InstallRoot = [IO.Path]::GetFullPath($InstallRoot)
  if (-not [string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot) }
  if (-not [string]::IsNullOrWhiteSpace($CatalogRoot)) { $CatalogRoot = [IO.Path]::GetFullPath($CatalogRoot) }

  if ($Command -eq 'help') {
    $help = [ordered]@{
      interface = 'central1'
      legacy_interface = 'stable0.5 (scripts/hebrinex.ps1, unchanged)'
      commands = [ordered]@{
        init = 'Plan or apply a new lightweight central binding; bind is an alias.'
        approve = 'After human SI, materialize one APR2 envelope for an exact descriptor.'
        status = 'Pure project query; never creates or updates files.'
        list = 'Pure catalog query; catalog is a recoverable non-authoritative index.'
        doctor = 'Pure runtime and optional project health query; validate is an alias.'
        reconcile = 'Plan or apply registration repair, move, or approved copy-as-new.'
        unbind = 'Plan or apply conservative unbind; archives binding and preserves instance data.'
        migrate = 'Plan or apply reversible legacy migration; -Restore plans or applies a verified snapshot restore.'
        upgrade = 'Unavailable until P07.'
      }
      mutation_flow = @(
        'Run <command> -CheckOnly -Json and retain details.descriptor.',
        'Review exact roots, write_set, plan hashes and preconditions; obtain human SI.',
        'Run approve -Apply with the exact descriptor and HumanEvidenceId.',
        'Run <command> -Apply with the same descriptor and returned ScopedApprovalId.'
      )
      guarantees = @('binding cannot select executable code','no runtime is copied into a project','status/list/doctor perform no writes','catalog failure preserves valid local binding as registration_pending')
    }
    Write-CliResult (New-CliResult -CommandName help -Status ok -Reason HELP -ExitCode 0 -Writes $false -Details $help -NextStep 'Elegir un comando; para mutaciones comenzar siempre con -CheckOnly.')
  }

  if ($Command -eq 'upgrade') {
    Write-CliResult (New-CliResult -CommandName $Command -Status unavailable -Reason PHASE_NOT_IMPLEMENTED -ExitCode 4 -Writes $false -Details ([ordered]@{ owning_phase = 'P07' }) -NextStep 'Completar P07; central1 no declara exito ficticio.')
  }

  if ($Command -eq 'status') {
    Write-CliResult (Get-HebriProjectStatus -InstallRoot $InstallRoot -ProjectRoot $ProjectRoot -CatalogRoot $CatalogRoot)
  }
  if ($Command -eq 'list') {
    Write-CliResult (Get-HebriProjectCatalog -CatalogRoot $CatalogRoot)
  }
  if ($Command -in @('doctor','validate')) {
    $result = Invoke-HebriProjectDoctor -InstallRoot $InstallRoot -ProjectRoot $ProjectRoot -CatalogRoot $CatalogRoot
    if ($Command -eq 'validate') { $result.command = 'validate' }
    Write-CliResult $result
  }

  if ($Command -eq 'approve') {
    if (-not $Apply -or $CheckOnly) { throw 'APPROVAL_REQUIRED: approve requires -Apply after human SI' }
    if ([string]::IsNullOrWhiteSpace($HumanEvidenceId)) { throw 'APPROVAL_REQUIRED: HumanEvidenceId is required' }
    $descriptor = Read-OperationDescriptor
    $descriptorCheck = Test-HebriProjectServiceDescriptor -Descriptor $descriptor
    if (-not $descriptorCheck.Valid) { $descriptorCheck = Test-HebriLegacyMigrationDescriptor -Descriptor $descriptor }
    if (-not $descriptorCheck.Valid) { throw ($descriptorCheck.Reason + ': descriptor rejected') }
    $canonicalApprovalStore = Join-Path ([string]$descriptor.roots.instance_root) 'runtime/approvals'
    if (-not [string]::IsNullOrWhiteSpace($ScopedApprovalStoreRoot) -and -not (Test-CliPathEqual -Left $ScopedApprovalStoreRoot -Right $canonicalApprovalStore)) {
      throw 'APPROVAL_SCOPE_MISMATCH: central1 approval store must be InstanceRoot/runtime/approvals'
    }
    $approval = New-CoreHebriScopedApprovalEnvelope -Descriptor $descriptor -StoreRoot $ScopedApprovalStoreRoot -TtlMinutes $TtlMinutes -HumanEvidenceId $HumanEvidenceId -HumanDecision approved -ApprovedText 'SI'
    Write-CliResult (New-CliResult -CommandName approve -Status applied -Reason APPROVAL_MATERIALIZED -ExitCode 0 -Writes $true -ProjectId ([string]$descriptor.project_id) -Details ([ordered]@{ approval_id = $approval.Id; approval_path = $approval.Path; expires_at = $approval.ExpiresAt; descriptor_hash = [string]$descriptor.descriptor_hash }) -NextStep 'Ejecutar el comando mutante con el mismo descriptor y este ScopedApprovalId.')
  }

  if ($Command -eq 'migrate') {
    if (($CheckOnly -and $Apply) -or (-not $CheckOnly -and -not $Apply)) { throw 'APPROVAL_REQUIRED: migrate requires exactly one mode, -CheckOnly or -Apply' }
    if ($CheckOnly) {
      if ($Restore) {
        if ([string]::IsNullOrWhiteSpace($SnapshotPath)) { throw 'BACKUP_INTEGRITY_FAILED: -SnapshotPath is required with -Restore' }
        Write-CliResult (New-HebriLegacyRestorePlan -InstallRoot $InstallRoot -ProjectRoot $ProjectRoot -CatalogRoot $CatalogRoot -SnapshotPath $SnapshotPath -PreservePostMigrationChanges:$PreservePostMigrationChanges)
      }
      if ([string]::IsNullOrWhiteSpace($BaselinePath)) { throw 'LEGACY_VERSION_UNSUPPORTED: -BaselinePath is required for migration planning' }
      Write-CliResult (New-HebriLegacyMigrationPlan -InstallRoot $InstallRoot -ProjectRoot $ProjectRoot -CatalogRoot $CatalogRoot -BaselinePath $BaselinePath -DecisionsPath $DecisionsPath -SnapshotBase $SnapshotBase)
    }
    if ([string]::IsNullOrWhiteSpace($ScopedApprovalId)) { throw 'APPROVAL_REQUIRED: ScopedApprovalId is required for -Apply' }
    $descriptor = Read-OperationDescriptor
    $descriptorCheck = Test-HebriLegacyMigrationDescriptor -Descriptor $descriptor
    if (-not $descriptorCheck.Valid) { throw ($descriptorCheck.Reason + ': migration descriptor rejected') }
    if ([string]::IsNullOrWhiteSpace($ProjectRoot) -or [string]::IsNullOrWhiteSpace($CatalogRoot)) { throw 'APPROVAL_SCOPE_MISMATCH: Apply requires explicit ProjectRoot and CatalogRoot' }
    if (-not (Test-CliPathEqual -Left $InstallRoot -Right ([string]$descriptor.roots.install_root)) -or
        -not (Test-CliPathEqual -Left $ProjectRoot -Right ([string]$descriptor.roots.project_root)) -or
        -not (Test-CliPathEqual -Left $CatalogRoot -Right ([string]$descriptor.roots.catalog_root))) {
      throw 'APPROVAL_SCOPE_MISMATCH: CLI roots differ from the approved migration descriptor'
    }
    Write-CliResult (Invoke-HebriLegacyMigrationOperation -Descriptor $descriptor -ApprovalId $ScopedApprovalId -ApprovalStoreRoot $ScopedApprovalStoreRoot)
  }

  if ($Command -in @('init','bind','reconcile','unbind')) {
    if (($CheckOnly -and $Apply) -or (-not $CheckOnly -and -not $Apply)) { throw 'APPROVAL_REQUIRED: mutation commands require exactly one mode, -CheckOnly or -Apply' }
    if ($CheckOnly) {
      $planCommand = if ($Command -eq 'bind') { 'bind' } else { $Command }
      $expandedSearchRoots = New-Object System.Collections.Generic.List[string]
      foreach ($searchRoot in @($SearchRoots)) {
        foreach ($part in @(([string]$searchRoot) -split ';')) {
          if (-not [string]::IsNullOrWhiteSpace($part)) { [void]$expandedSearchRoots.Add($part.Trim()) }
        }
      }
      Write-CliResult (New-HebriProjectOperationPlan -Command $planCommand -InstallRoot $InstallRoot -ProjectRoot $ProjectRoot -CatalogRoot $CatalogRoot -SearchRoots @($expandedSearchRoots) -IncludeGitIgnore:$IncludeGitIgnore -CopyAsNew:$CopyAsNew)
    }
    if ([string]::IsNullOrWhiteSpace($ScopedApprovalId)) { throw 'APPROVAL_REQUIRED: ScopedApprovalId is required for -Apply' }
    $descriptor = Read-OperationDescriptor
    if ([string]::IsNullOrWhiteSpace($ProjectRoot) -or [string]::IsNullOrWhiteSpace($CatalogRoot)) { throw 'APPROVAL_SCOPE_MISMATCH: Apply requires explicit ProjectRoot and CatalogRoot' }
    if (-not (Test-CliPathEqual -Left $InstallRoot -Right ([string]$descriptor.roots.install_root)) -or
        -not (Test-CliPathEqual -Left $ProjectRoot -Right ([string]$descriptor.roots.project_root)) -or
        -not (Test-CliPathEqual -Left $CatalogRoot -Right ([string]$descriptor.roots.catalog_root))) {
      throw 'APPROVAL_SCOPE_MISMATCH: CLI roots differ from the approved descriptor'
    }
    $result = Invoke-HebriProjectOperation -Descriptor $descriptor -ApprovalId $ScopedApprovalId -ApprovalStoreRoot $ScopedApprovalStoreRoot
    if ($Command -eq 'bind' -and $result.command -eq 'init') { $result.command = 'bind' }
    Write-CliResult $result
  }
}
catch {
  $message = $_.Exception.Message
  $reason = if ($message -match '^([A-Z0-9_]+):') { $Matches[1] } else { 'PROJECT_SERVICE_ERROR' }
  $exitCode = if ($reason -in @('RECOVERY_REQUIRED','REGISTRATION_PENDING')) { 8 } else { 3 }
  Write-CliResult (New-CliResult -CommandName $Command -Status failed -Reason $reason -ExitCode $exitCode -Writes $false -Details ([ordered]@{ error = $message }) -NextStep 'Corregir el error y generar un plan nuevo; no reutilizar un descriptor obsoleto.')
}
