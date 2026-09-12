param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$RunNegativeTests
)

$ErrorActionPreference = 'Stop'
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Checks = 0

function Assert-P04([bool]$Condition, [string]$Message) {
  $script:Checks++
  if (-not $Condition) { [void]$script:Failures.Add($Message) }
}

function Get-TreeFingerprint([string[]]$Roots) {
  $records = New-Object System.Collections.Generic.List[string]
  foreach ($rootPath in $Roots) {
    $fullRoot = [IO.Path]::GetFullPath($rootPath)
    if (-not (Test-Path -LiteralPath $fullRoot)) { [void]$records.Add("MISSING|$fullRoot"); continue }
    foreach ($item in @(Get-ChildItem -LiteralPath $fullRoot -Force -Recurse | Sort-Object FullName)) {
      $kind = if ($item.PSIsContainer) { 'D' } else { 'F' }
      $hash = if ($item.PSIsContainer) { '' } else { (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
      [void]$records.Add("$kind|$($item.FullName)|$hash")
    }
  }
  return (Get-CoreSha256Hex (($records -join "`n")))
}

function New-TestProject([string]$Path) {
  [void][IO.Directory]::CreateDirectory($Path)
  return [IO.Path]::GetFullPath($Path)
}

function Invoke-ApprovedPlan($Plan, [string]$EvidenceId) {
  Assert-P04 ($Plan.status -eq 'planned') "$EvidenceId did not produce a planned descriptor"
  if ($Plan.status -ne 'planned') { return $Plan }
  $approval = New-CoreHebriScopedApprovalEnvelope -Descriptor $Plan.details.descriptor -HumanEvidenceId $EvidenceId -ApprovedText 'SI'
  return Invoke-HebriProjectOperation -Descriptor $Plan.details.descriptor -ApprovalId $approval.Id
}

function Invoke-CentralCli([string[]]$Arguments) {
  $exe = Get-Command pwsh -ErrorAction SilentlyContinue
  if ($null -eq $exe) { $exe = Get-Command powershell -ErrorAction SilentlyContinue }
  if ($null -eq $exe) { throw 'PowerShell executable unavailable for CLI roundtrip' }
  $scriptPath = Join-Path $Root 'scripts/hebrinex-central.ps1'
  $output = @(& $exe.Source -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $scriptPath @Arguments 2>&1)
  return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Text = ($output -join "`n") }
}

$Root = [IO.Path]::GetFullPath($Root)
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('hebrinex-p04-' + [guid]::NewGuid().ToString('N'))
$markerPath = Join-Path $fixtureRoot '.hebrinex-p04-fixture'
$legacyCliHashBefore = (Get-FileHash -LiteralPath (Join-Path $Root 'scripts/hebrinex.ps1') -Algorithm SHA256).Hash

Import-Module (Join-Path $Root 'scripts/lib/project-service.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $Root 'scripts/lib/hebri-common.psm1') -Force -DisableNameChecking -Prefix Core

try {
  [void][IO.Directory]::CreateDirectory($fixtureRoot)
  [IO.File]::WriteAllText($markerPath, 'P04 fixture owned by validate-project-service.ps1', [Text.UTF8Encoding]::new($false))
  $catalog = Join-Path $fixtureRoot 'catalog'
  $projectA = New-TestProject (Join-Path $fixtureRoot 'project-a')
  $projectB = New-TestProject (Join-Path $fixtureRoot 'project-b')

  # V01: two isolated projects through the public CLI, then the module.
  $cliPlanRun = Invoke-CentralCli @('init','-InstallRoot',$Root,'-ProjectRoot',$projectA,'-CatalogRoot',$catalog,'-IncludeGitIgnore','-CheckOnly','-Json')
  Assert-P04 ($cliPlanRun.ExitCode -eq 0) 'V01 public CLI init plan failed'
  $cliPlan = $cliPlanRun.Text | ConvertFrom-Json
  Assert-P04 ($cliPlan.status -eq 'planned' -and $cliPlan.details.runtime_copied -eq $false) 'V01 CLI plan is not lightweight'
  $descriptorJson = $cliPlan.details.descriptor | ConvertTo-Json -Depth 40 -Compress
  $descriptorPath = Join-Path $fixtureRoot 'project-a-operation-descriptor.json'
  [IO.File]::WriteAllText($descriptorPath, $descriptorJson + "`n", [Text.UTF8Encoding]::new($false))
  $cliApproveRun = Invoke-CentralCli @('approve','-InstallRoot',$Root,'-OperationDescriptorPath',$descriptorPath,'-HumanEvidenceId','P04-V01-CLI','-Apply','-Json')
  Assert-P04 ($cliApproveRun.ExitCode -eq 0) ("V01 public CLI scoped approval failed: " + $cliApproveRun.Text)
  $cliApproval = $cliApproveRun.Text | ConvertFrom-Json
  $cliApplyRun = Invoke-CentralCli @('init','-InstallRoot',$Root,'-ProjectRoot',$projectA,'-CatalogRoot',$catalog,'-OperationDescriptorPath',$descriptorPath,'-ScopedApprovalId',([string]$cliApproval.details.approval_id),'-Apply','-Json')
  Assert-P04 ($cliApplyRun.ExitCode -eq 0) ("V01 public CLI init apply failed: " + $cliApplyRun.Text)
  $resultA = $cliApplyRun.Text | ConvertFrom-Json

  $planB = New-HebriProjectOperationPlan -Command init -InstallRoot $Root -ProjectRoot $projectB -CatalogRoot $catalog -IncludeGitIgnore
  $resultB = Invoke-ApprovedPlan -Plan $planB -EvidenceId 'P04-V01-B'
  Assert-P04 ($resultA.status -eq 'applied' -and $resultB.status -eq 'applied') 'V01 both project initializations must apply'
  Assert-P04 ([string]$resultA.project_id -ne [string]$resultB.project_id) 'V01 project IDs must be distinct'
  foreach ($project in @($projectA,$projectB)) {
    Assert-P04 (Test-Path -LiteralPath (Join-Path $project '.hebrinex/binding.json') -PathType Leaf) "V01 binding missing in $project"
    foreach ($runtimeDir in @('scripts','prompts','agents','orquestador/policies')) {
      Assert-P04 (-not (Test-Path -LiteralPath (Join-Path $project ('.hebrinex/' + $runtimeDir)))) "V01 copied product runtime into $project ($runtimeDir)"
    }
  }

  # V02: repeated init is a no-op; contradictory binding is never overwritten.
  $fingerprintBeforeRepeat = Get-TreeFingerprint @($projectA,$catalog)
  $repeat = New-HebriProjectOperationPlan -Command init -InstallRoot $Root -ProjectRoot $projectA -CatalogRoot $catalog -IncludeGitIgnore
  $fingerprintAfterRepeat = Get-TreeFingerprint @($projectA,$catalog)
  Assert-P04 ($repeat.status -eq 'unchanged' -and $repeat.reason -eq 'PROJECT_ALREADY_BOUND') 'V02 repeated init is not idempotent'
  Assert-P04 ($fingerprintBeforeRepeat -eq $fingerprintAfterRepeat) 'V02 repeated init mutated project or catalog'
  $bindingAPath = Join-Path $projectA '.hebrinex/binding.json'
  $bindingAOriginal = [IO.File]::ReadAllText($bindingAPath)
  $contradictory = $bindingAOriginal | ConvertFrom-Json
  $contradictory.project_root = Join-Path $fixtureRoot 'other-root'
  [IO.File]::WriteAllText($bindingAPath, (($contradictory | ConvertTo-Json -Depth 12) + "`n"), [Text.UTF8Encoding]::new($false))
  $contradictoryHash = (Get-FileHash -LiteralPath $bindingAPath -Algorithm SHA256).Hash
  $blockedContradiction = New-HebriProjectOperationPlan -Command init -InstallRoot $Root -ProjectRoot $projectA -CatalogRoot $catalog -IncludeGitIgnore
  Assert-P04 ($blockedContradiction.status -eq 'blocked' -and $blockedContradiction.reason -eq 'PROJECT_MOVED') 'V02 contradictory binding was not blocked'
  Assert-P04 ($contradictoryHash -eq (Get-FileHash -LiteralPath $bindingAPath -Algorithm SHA256).Hash) 'V02 contradictory binding was overwritten'
  [IO.File]::WriteAllText($bindingAPath, $bindingAOriginal, [Text.UTF8Encoding]::new($false))

  # V03: catalog failure after local commit preserves registration_pending.
  $projectC = New-TestProject (Join-Path $fixtureRoot 'project-c')
  $catalogFailure = Join-Path $fixtureRoot 'catalog-failure'
  $planC = New-HebriProjectOperationPlan -Command init -InstallRoot $Root -ProjectRoot $projectC -CatalogRoot $catalogFailure -IncludeGitIgnore
  Assert-P04 ($planC.status -eq 'planned') 'V03 init plan failed'
  $approvalC = New-CoreHebriScopedApprovalEnvelope -Descriptor $planC.details.descriptor -HumanEvidenceId 'P04-V03' -ApprovedText 'SI'
  [void][IO.Directory]::CreateDirectory($catalogFailure)
  [IO.File]::WriteAllText((Join-Path $catalogFailure 'projects'), 'catalog writes denied by fixture shape', [Text.UTF8Encoding]::new($false))
  $resultC = Invoke-HebriProjectOperation -Descriptor $planC.details.descriptor -ApprovalId $approvalC.Id
  Assert-P04 ($resultC.status -eq 'failed' -and $resultC.exit_code -eq 8 -and $resultC.reason -eq 'REGISTRATION_PENDING' -and $resultC.writes_performed) 'V03 catalog failure contract is incorrect'
  Assert-P04 (Test-Path -LiteralPath (Join-Path $projectC '.hebrinex/binding.json') -PathType Leaf) 'V03 valid local binding was rolled back'
  $registrationC = [IO.File]::ReadAllText((Join-Path $projectC '.hebrinex/instance/registration.json')) | ConvertFrom-Json
  Assert-P04 ([string]$registrationC.status -eq 'pending') 'V03 registration_pending is not detectable'
  $journalC = [IO.File]::ReadAllText([string]$resultC.details.journal_path) | ConvertFrom-Json
  Assert-P04 ([string]$journalC.state -eq 'recovery_required') 'V03 journal does not require recovery'
  [IO.File]::Delete((Join-Path $catalogFailure 'projects'))
  $reconcileC = New-HebriProjectOperationPlan -Command reconcile -InstallRoot $Root -ProjectRoot $projectC -CatalogRoot $catalogFailure -SearchRoots @($projectC)
  $reconciledC = Invoke-ApprovedPlan -Plan $reconcileC -EvidenceId 'P04-V03-RECOVER'
  Assert-P04 ($reconciledC.status -eq 'applied' -and (Get-HebriProjectStatus -InstallRoot $Root -ProjectRoot $projectC -CatalogRoot $catalogFailure).status -eq 'healthy') 'V03 reconcile did not recover registration'
  Assert-P04 (@(Get-ChildItem -LiteralPath (Join-Path $catalogFailure 'projects') -File -Filter '*.json').Count -eq 1) 'V03 reconcile created duplicate catalog entries'

  # V04: move is repairable; simultaneous duplicate needs a new identity.
  $moveSource = New-TestProject (Join-Path $fixtureRoot 'move-source')
  $moveCatalog = Join-Path $fixtureRoot 'move-catalog'
  $moveInit = Invoke-ApprovedPlan -Plan (New-HebriProjectOperationPlan -Command init -InstallRoot $Root -ProjectRoot $moveSource -CatalogRoot $moveCatalog -IncludeGitIgnore) -EvidenceId 'P04-V04-INIT'
  $oldMoveId = [string]$moveInit.project_id
  $moveTarget = Join-Path $fixtureRoot 'move-target'
  [IO.Directory]::Move($moveSource,$moveTarget)
  $movePlan = New-HebriProjectOperationPlan -Command reconcile -InstallRoot $Root -ProjectRoot $moveTarget -CatalogRoot $moveCatalog -SearchRoots @($moveSource,$moveTarget)
  Assert-P04 ($movePlan.status -eq 'planned' -and $movePlan.details.action -eq 'move') 'V04 moved project did not produce move plan'
  $moveResult = Invoke-ApprovedPlan -Plan $movePlan -EvidenceId 'P04-V04-MOVE'
  Assert-P04 ($moveResult.status -eq 'applied' -and [string]$moveResult.project_id -eq $oldMoveId) 'V04 move changed project identity'
  $duplicate = Join-Path $fixtureRoot 'move-duplicate'
  Copy-Item -LiteralPath $moveTarget -Destination $duplicate -Recurse
  $duplicatePlan = New-HebriProjectOperationPlan -Command reconcile -InstallRoot $Root -ProjectRoot $duplicate -CatalogRoot $moveCatalog -SearchRoots @($moveTarget,$duplicate)
  Assert-P04 ($duplicatePlan.status -eq 'blocked' -and $duplicatePlan.reason -eq 'PROJECT_ID_DUPLICATE') 'V04 duplicate identity was not blocked'
  $copyPlan = New-HebriProjectOperationPlan -Command reconcile -InstallRoot $Root -ProjectRoot $duplicate -CatalogRoot $moveCatalog -SearchRoots @($moveTarget,$duplicate) -CopyAsNew
  $copyResult = Invoke-ApprovedPlan -Plan $copyPlan -EvidenceId 'P04-V04-COPY'
  Assert-P04 ($copyResult.status -eq 'applied' -and [string]$copyResult.project_id -ne $oldMoveId) 'V04 copy-as-new did not assign a new identity'

  # V05: corrupt/deleted catalog queries do not mutate; approved reconcile rebuilds.
  $catalogAPath = Join-Path $catalog ("projects\$([string]$resultA.project_id).json")
  [IO.File]::WriteAllText($catalogAPath, '{broken-json', [Text.UTF8Encoding]::new($false))
  $queryHashBefore = Get-TreeFingerprint @($projectA,$catalog)
  $corruptList = Get-HebriProjectCatalog -CatalogRoot $catalog
  $corruptStatus = Get-HebriProjectStatus -InstallRoot $Root -ProjectRoot $projectA -CatalogRoot $catalog
  $queryHashAfter = Get-TreeFingerprint @($projectA,$catalog)
  Assert-P04 ($corruptList.status -eq 'degraded' -and $corruptStatus.reason -eq 'REGISTRATION_PENDING') 'V05 corrupt catalog is not distinguished'
  Assert-P04 ($queryHashBefore -eq $queryHashAfter) 'V05 queries mutated corrupt catalog or project'
  [IO.File]::Delete($catalogAPath)
  $deleteHashBefore = Get-TreeFingerprint @($projectA,$catalog)
  [void](Get-HebriProjectCatalog -CatalogRoot $catalog)
  [void](Get-HebriProjectStatus -InstallRoot $Root -ProjectRoot $projectA -CatalogRoot $catalog)
  Assert-P04 ($deleteHashBefore -eq (Get-TreeFingerprint @($projectA,$catalog))) 'V05 queries recreated a deleted catalog entry'
  $repairA = Invoke-ApprovedPlan -Plan (New-HebriProjectOperationPlan -Command reconcile -InstallRoot $Root -ProjectRoot $projectA -CatalogRoot $catalog -SearchRoots @($projectA)) -EvidenceId 'P04-V05-REBUILD'
  Assert-P04 ($repairA.status -eq 'applied' -and (Test-Path -LiteralPath $catalogAPath -PathType Leaf)) 'V05 approved-root reconstruction failed'

  # V06: absent/valid status, list and doctor are pure reads.
  $missingProject = New-TestProject (Join-Path $fixtureRoot 'missing-project')
  $queryInventoryBefore = Get-TreeFingerprint @($fixtureRoot)
  $missingStatus = Get-HebriProjectStatus -InstallRoot $Root -ProjectRoot $missingProject -CatalogRoot $catalog
  $validStatus = Get-HebriProjectStatus -InstallRoot $Root -ProjectRoot $projectA -CatalogRoot $catalog
  $validList = Get-HebriProjectCatalog -CatalogRoot $catalog
  $validDoctor = Invoke-HebriProjectDoctor -InstallRoot $Root -ProjectRoot $projectA -CatalogRoot $catalog
  $queryInventoryAfter = Get-TreeFingerprint @($fixtureRoot)
  Assert-P04 ($missingStatus.reason -eq 'PROJECT_NOT_FOUND' -and $validStatus.status -eq 'healthy' -and $validList.status -eq 'ok' -and $validDoctor.status -eq 'healthy') 'V06 query semantics are incorrect'
  Assert-P04 ($queryInventoryBefore -eq $queryInventoryAfter) 'V06 status/list/doctor changed the fixture inventory'

  # V07: central hook resolves a valid project; unbind preserves data and then fails with repair guidance.
  $hookValid = Invoke-CentralCli @('status','-InstallRoot',$Root,'-ProjectRoot',$projectB,'-CatalogRoot',$catalog,'-Json')
  Assert-P04 ($hookValid.ExitCode -eq 0) 'V07 valid project is not discoverable before hook test'
  $hookExe = Get-Command pwsh -ErrorAction SilentlyContinue
  if ($null -eq $hookExe) { $hookExe = Get-Command powershell -ErrorAction SilentlyContinue }
  $reentryPath = Join-Path $Root 'scripts/claude-reentry.ps1'
  $hookBeforeOutput = @(& $hookExe.Source -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $reentryPath -CheckOnly -RuntimeMode central_instance -InstallRoot $Root -ProjectRoot $projectB -CatalogRoot $catalog 2>&1)
  Assert-P04 ($LASTEXITCODE -eq 0) 'V07 central reentry hook did not resolve valid installation/binding'
  $hookInstallPath = Join-Path $Root 'scripts/install-claude-hooks.ps1'
  $hookPlanOutput = @(& $hookExe.Source -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $hookInstallPath -CheckOnly -RuntimeMode central_instance -ProjectRoot $projectB -CatalogRoot $catalog 2>&1)
  $hookPlanText = $hookPlanOutput -join "`n"
  Assert-P04 ($LASTEXITCODE -eq 0 -and $hookPlanText -match [regex]::Escape((Join-Path $Root 'scripts\claude-reentry.ps1')) -and $hookPlanText -notmatch '\.hebrinex/scripts/claude-reentry') 'V07 hook plan does not target trusted central scripts'
  $dataSentinel = Join-Path $projectB '.hebrinex/instance/user-data.txt'
  [IO.File]::WriteAllText($dataSentinel, 'preserve-me', [Text.UTF8Encoding]::new($false))
  $unbindB = Invoke-ApprovedPlan -Plan (New-HebriProjectOperationPlan -Command unbind -InstallRoot $Root -ProjectRoot $projectB -CatalogRoot $catalog) -EvidenceId 'P04-V07-UNBIND'
  Assert-P04 ($unbindB.status -eq 'applied' -and -not (Test-Path -LiteralPath (Join-Path $projectB '.hebrinex/binding.json')) -and (Test-Path -LiteralPath $dataSentinel -PathType Leaf)) 'V07 unbind did not preserve instance data'
  $previousErrorPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $hookAfterOutput = @(& $hookExe.Source -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $reentryPath -CheckOnly -RuntimeMode central_instance -InstallRoot $Root -ProjectRoot $projectB -CatalogRoot $catalog 2>&1)
  $hookAfterExitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorPreference
  Assert-P04 ($hookAfterExitCode -ne 0 -and (($hookAfterOutput -join "`n") -match 'PROJECT_NOT_FOUND|status/reconcile')) 'V07 unbound hook did not fail with repair guidance'

  # Contracts and legacy oracle.
  foreach ($jsonPath in @(
    'orquestador/runtime/schemas/project-binding.schema.json','orquestador/runtime/schemas/project-instance.schema.json',
    'orquestador/runtime/schemas/project-registration.schema.json','orquestador/runtime/schemas/project-catalog-entry.schema.json',
    'orquestador/runtime/schemas/project-service-result.schema.json','orquestador/runtime/templates/project-binding.template.json',
    'orquestador/runtime/templates/project-instance.template.json','orquestador/runtime/templates/project-registration.template.json',
    'orquestador/runtime/templates/project-catalog-entry.template.json'
  )) {
    try { [void]([IO.File]::ReadAllText((Join-Path $Root $jsonPath)) | ConvertFrom-Json); Assert-P04 $true "$jsonPath parses" }
    catch { Assert-P04 $false "$jsonPath is invalid JSON: $($_.Exception.Message)" }
  }
  $legacyCliHashAfter = (Get-FileHash -LiteralPath (Join-Path $Root 'scripts/hebrinex.ps1') -Algorithm SHA256).Hash
  Assert-P04 ($legacyCliHashBefore -eq $legacyCliHashAfter) 'P04 modified the stable0.5 CLI oracle'

  if ($RunNegativeTests) {
    $badSchemaProject = New-TestProject (Join-Path $fixtureRoot 'bad-schema')
    [void][IO.Directory]::CreateDirectory((Join-Path $badSchemaProject '.hebrinex'))
    [IO.File]::WriteAllText((Join-Path $badSchemaProject '.hebrinex/binding.json'), '{"schema":"foreign.binding","schema_version":99}', [Text.UTF8Encoding]::new($false))
    $badSchemaStatus = Get-HebriProjectStatus -InstallRoot $Root -ProjectRoot $badSchemaProject -CatalogRoot $catalog
    Assert-P04 ($badSchemaStatus.reason -eq 'BINDING_SCHEMA_UNSUPPORTED') 'negative: foreign binding schema was not blocked'

    $craftedProject = New-TestProject (Join-Path $fixtureRoot 'crafted-plan')
    $validCraftedPlan = New-HebriProjectOperationPlan -Command init -InstallRoot $Root -ProjectRoot $craftedProject -CatalogRoot $catalog -IncludeGitIgnore
    $context = [pscustomobject]@{
      install_root = [string]$validCraftedPlan.details.descriptor.roots.install_root
      project_root = [string]$validCraftedPlan.details.descriptor.roots.project_root
      instance_root = [string]$validCraftedPlan.details.descriptor.roots.instance_root
      catalog_root = [string]$validCraftedPlan.details.descriptor.roots.catalog_root
      project_id = [string]$validCraftedPlan.project_id
    }
    $unsupportedPlan = ($validCraftedPlan.details.descriptor.plan | ConvertTo-Json -Depth 40 | ConvertFrom-Json)
    $unsupportedPlan.action = 'invented_action'
    $unsupportedDescriptor = New-CoreHebriOperationDescriptor -Context $context -Operation 'project:init' -WriteSet @($validCraftedPlan.details.descriptor.write_set) -CodeVersion central1 -Plan $unsupportedPlan
    $unsupportedCheck = Test-HebriProjectServiceDescriptor -Descriptor $unsupportedDescriptor
    Assert-P04 (-not $unsupportedCheck.Valid -and $unsupportedCheck.Reason -eq 'OPERATION_DESCRIPTOR_INVALID') 'negative: handcrafted unsupported action passed the closed plan grammar'

    $mixedIdentityPlan = ($validCraftedPlan.details.descriptor.plan | ConvertTo-Json -Depth 40 | ConvertFrom-Json)
    $mixedIdentityPlan.documents.binding.project_id = 'PRJ-' + [guid]::NewGuid().ToString('N')
    $mixedIdentityDescriptor = New-CoreHebriOperationDescriptor -Context $context -Operation 'project:init' -WriteSet @($validCraftedPlan.details.descriptor.write_set) -CodeVersion central1 -Plan $mixedIdentityPlan
    $mixedIdentityCheck = Test-HebriProjectServiceDescriptor -Descriptor $mixedIdentityDescriptor
    Assert-P04 (-not $mixedIdentityCheck.Valid -and $mixedIdentityCheck.Reason -eq 'BINDING_SCHEMA_UNSUPPORTED') 'negative: mixed project identities passed descriptor validation'

    $concurrentProject = New-TestProject (Join-Path $fixtureRoot 'concurrent-gitignore')
    $concurrentPlan = New-HebriProjectOperationPlan -Command init -InstallRoot $Root -ProjectRoot $concurrentProject -CatalogRoot $catalog -IncludeGitIgnore
    $concurrentApproval = New-CoreHebriScopedApprovalEnvelope -Descriptor $concurrentPlan.details.descriptor -HumanEvidenceId 'P04-NEG-CONCURRENT' -ApprovedText 'SI'
    $concurrentGitIgnore = Join-Path $concurrentProject '.gitignore'
    [IO.File]::WriteAllText($concurrentGitIgnore, "user-change`n", [Text.UTF8Encoding]::new($false))
    $concurrentApply = Invoke-HebriProjectOperation -Descriptor $concurrentPlan.details.descriptor -ApprovalId $concurrentApproval.Id
    Assert-P04 ($concurrentApply.reason -eq 'OPERATION_PRECONDITION_FAILED' -and [IO.File]::ReadAllText($concurrentGitIgnore) -eq "user-change`n" -and -not (Test-Path -LiteralPath (Join-Path $concurrentProject '.hebrinex/binding.json'))) 'negative: concurrent .gitignore edit was overwritten or partially applied'
  }
}
catch {
  [void]$script:Failures.Add("validator exception: $($_.Exception.Message)`n$($_.ScriptStackTrace)")
}
finally {
  try {
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')
    $fixtureFull = [IO.Path]::GetFullPath($fixtureRoot)
    $insideTemp = $fixtureFull.StartsWith($tempRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
    if ($insideTemp -and (Test-Path -LiteralPath $markerPath -PathType Leaf)) { [IO.Directory]::Delete($fixtureFull,$true) }
    else { [void]$script:Failures.Add('fixture cleanup refused: target or marker validation failed') }
  }
  catch { [void]$script:Failures.Add('fixture cleanup failed: ' + $_.Exception.Message) }
}

Write-Host "P04 project service validation checks=$script:Checks"
if ($script:Failures.Count -gt 0) {
  Write-Host 'P04 project service validation FAILED:'
  foreach ($failure in $script:Failures) { Write-Host " - $failure" }
  exit 2
}
Write-Host 'P04 project service validation OK'
exit 0
