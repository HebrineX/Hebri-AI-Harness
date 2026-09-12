param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$RunNegativeTests
)

$ErrorActionPreference = 'Stop'
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]
$script:Checks = New-Object System.Collections.Generic.List[object]
$script:ReparsePaths = New-Object System.Collections.Generic.List[string]

function Add-Check {
  param([string]$Id, [string]$Status, [string]$Detail)
  [void]$script:Checks.Add([pscustomobject]@{ id = $Id; status = $Status; detail = $Detail })
  if ($Status -eq 'fail') { [void]$script:Failures.Add($Id + ': ' + $Detail) }
  if ($Status -eq 'blocked') { [void]$script:Warnings.Add($Id + ': ' + $Detail) }
}

function Assert-Check {
  param([string]$Id, [bool]$Condition, [string]$Detail)
  if ($Condition) { Add-Check $Id 'pass' $Detail } else { Add-Check $Id 'fail' $Detail }
}

function Assert-ThrowsCode {
  param([string]$Id, [string]$Code, [scriptblock]$Action)
  try {
    & $Action | Out-Null
    Add-Check $Id 'fail' ('expected ' + $Code + ' but the call succeeded')
  }
  catch {
    if ($_.Exception.Message -like ($Code + ':*')) {
      Add-Check $Id 'pass' ('rejected with ' + $Code)
    }
    else {
      Add-Check $Id 'fail' ('expected ' + $Code + '; received ' + $_.Exception.Message)
    }
  }
}

function Write-TestText {
  param([string]$Path, [string]$Text)
  $parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    [void][IO.Directory]::CreateDirectory($parent)
  }
  [IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), [Text.UTF8Encoding]::new($false))
}

function Copy-TestFile {
  param([string]$Source, [string]$Destination)
  $parent = Split-Path -Parent $Destination
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    [void][IO.Directory]::CreateDirectory($parent)
  }
  [IO.File]::Copy($Source, $Destination, $true)
}

function Copy-RuntimeFixture {
  param([string]$Destination)
  [void][IO.Directory]::CreateDirectory($Destination)
  foreach ($relative in @(
    'HARNESS_VERSION',
    'SHARED_MANIFEST.yaml',
    'scripts/lib/hebri-common.psm1',
    'packaging/runtime-layout.json'
  )) {
    $source = Join-Path $Root ($relative -replace '/', [IO.Path]::DirectorySeparatorChar)
    $target = Join-Path $Destination ($relative -replace '/', [IO.Path]::DirectorySeparatorChar)
    Copy-TestFile $source $target
  }
}

function Write-CentralBinding {
  param(
    [string]$ProjectRoot,
    [string]$ProjectId,
    [string]$InstanceId,
    [switch]$Injected,
    [string]$WitnessPath = ''
  )
  $name = if ($Injected) { 'binding.injected.template.json' } else { 'binding.central.template.json' }
  $templatePath = Join-Path $Root ('orquestador/testing/fixtures/root-resolver/' + $name)
  $binding = [IO.File]::ReadAllText($templatePath) | ConvertFrom-Json
  $binding.project_root = [IO.Path]::GetFullPath($ProjectRoot)
  $binding.project_id = $ProjectId
  $binding.instance_id = $InstanceId
  if ($Injected) { $binding.script_path = $WitnessPath }
  Write-TestText (Join-Path $ProjectRoot '.hebrinex\binding.json') ($binding | ConvertTo-Json -Depth 8)
}

function Write-LegacyBinding {
  param([string]$HarnessRoot, [string]$ProjectRoot, [string]$ProjectId, [string]$InstanceId)
  $templatePath = Join-Path $Root 'orquestador/testing/fixtures/root-resolver/binding.legacy.template.yaml'
  $text = [IO.File]::ReadAllText($templatePath)
  $text = $text.Replace('{{PROJECT_ROOT}}', ([IO.Path]::GetFullPath($ProjectRoot) -replace '\\', '/'))
  $text = $text.Replace('{{PROJECT_ID}}', $ProjectId).Replace('{{INSTANCE_ID}}', $InstanceId)
  Write-TestText (Join-Path $HarnessRoot 'PROJECT_BINDING.yaml') $text
}

function Get-TreeFingerprint {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return 'missing' }
  $rootFull = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($item in @(Get-ChildItem -LiteralPath $rootFull -Force -Recurse | Sort-Object FullName)) {
    $relative = $item.FullName.Substring($rootFull.Length).TrimStart('\', '/') -replace '\\', '/'
    if ($item.PSIsContainer) {
      [void]$lines.Add('D|' + $relative + '|' + [string]$item.Attributes)
    }
    else {
      $hash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
      [void]$lines.Add('F|' + $relative + '|' + $item.Length + '|' + [string]$item.Attributes + '|' + $hash)
    }
  }
  return Get-Sha256Hex ($lines -join "`n")
}

function Compare-StringSets {
  param([string[]]$Left, [string[]]$Right)
  return @(Compare-Object @($Left | Sort-Object -Unique) @($Right | Sort-Object -Unique)).Count -eq 0
}

function Remove-TestReparsePath {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return }
  $item = Get-Item -LiteralPath $Path -Force
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
    throw ('cleanup refused non-reparse path: ' + $Path)
  }
  if ($item.PSIsContainer) { [IO.Directory]::Delete($Path) }
  else { [IO.File]::Delete($Path) }
}

$Root = [IO.Path]::GetFullPath($Root)
$modulePath = Join-Path $Root 'scripts/lib/hebri-common.psm1'
Import-Module $modulePath -Force -DisableNameChecking

$fixtureParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$fixtureRoot = Join-Path $fixtureParent ('hebrinex-root-resolver-' + [guid]::NewGuid().ToString('N'))
$marker = Join-Path $fixtureRoot '.hebrinex-root-resolver-fixture'

try {
  [void][IO.Directory]::CreateDirectory($fixtureRoot)
  Write-TestText $marker 'owned temporary fixture'

  # Contract and projection validation.
  $schemaFiles = @(
    'orquestador/runtime/schemas/runtime-layout.schema.json',
    'orquestador/runtime/schemas/harness-runtime-context.schema.json',
    'orquestador/runtime/schemas/harness-path-request.schema.json',
    'orquestador/runtime/schemas/harness-path-result.schema.json',
    'orquestador/testing/fixtures/root-resolver/binding.central.template.json',
    'orquestador/testing/fixtures/root-resolver/binding.injected.template.json',
    'orquestador/testing/fixtures/root-resolver/resolver-cases.json'
  )
  foreach ($relative in $schemaFiles) {
    try {
      [void]([IO.File]::ReadAllText((Join-Path $Root ($relative -replace '/', [IO.Path]::DirectorySeparatorChar))) | ConvertFrom-Json)
      Add-Check ('JSON-' + ($relative -replace '[^A-Za-z0-9]', '-')) 'pass' 'valid JSON'
    }
    catch { Add-Check ('JSON-' + ($relative -replace '[^A-Za-z0-9]', '-')) 'fail' $_.Exception.Message }
  }

  $layout = Get-HebriRuntimeLayout -InstallRoot $Root
  Assert-Check 'LAYOUT-HEADER' ($layout.contract_version -eq '1.0.0' -and $layout.runtime_api -eq '1' -and $layout.default_class -eq 'denied') 'versioned layout uses deny-by-default'
  $ids = @($layout.rules | ForEach-Object { [string]$_.id })
  Assert-Check 'LAYOUT-IDS' ((@($ids | Select-Object -Unique).Count -eq $ids.Count)) 'rule ids are unique'

  $manifestText = [IO.File]::ReadAllText((Join-Path $Root 'SHARED_MANIFEST.yaml'))
  Assert-Check 'MANIFEST-AUTHORITY' ($manifestText -match '(?m)^\s+runtime_layout:\s+"packaging/runtime-layout.json"\s*$' -and $manifestText -match '(?m)^\s+central_authority:\s+runtime_layout\s*$') 'legacy manifest points to the executable layout'
  $manifestShared = @(Get-YamlList -Text $manifestText -Key 'shared_dirs')
  $manifestExcluded = @(Get-YamlList -Text $manifestText -Key 'excluded_from_sharing')
  $manifestInstance = New-Object System.Collections.Generic.List[string]
  $manifestInstanceMap = @{}
  $pendingLegacy = ''
  foreach ($line in ($manifestText -split "`n")) {
    if ($line -match '^\s{2}- legacy_path:\s*(.+?)\s*$') {
      $pendingLegacy = $Matches[1].Trim().Trim('"').Trim("'")
      [void]$manifestInstance.Add($pendingLegacy)
    }
    elseif (-not [string]::IsNullOrWhiteSpace($pendingLegacy) -and $line -match '^\s{4}instance_path:\s*(.+?)\s*$') {
      $manifestInstanceMap[$pendingLegacy] = $Matches[1].Trim().Trim('"').Trim("'")
      $pendingLegacy = ''
    }
  }
  $layoutShared = @($layout.rules | Where-Object legacy_projection -eq 'shared' | ForEach-Object { [string]$_.logical_path })
  $layoutExcluded = @($layout.rules | Where-Object legacy_projection -eq 'excluded' | ForEach-Object { [string]$_.logical_path })
  $layoutInstance = @($layout.rules | Where-Object legacy_projection -eq 'instance' | ForEach-Object { [string]$_.logical_path })
  Assert-Check 'PROJECTION-SHARED' (Compare-StringSets $manifestShared $layoutShared) '21 shared selectors match runtime layout'
  Assert-Check 'PROJECTION-EXCLUDED' (Compare-StringSets $manifestExcluded $layoutExcluded) '6 exclusions match runtime layout'
  Assert-Check 'PROJECTION-INSTANCE' (Compare-StringSets $manifestInstance $layoutInstance) '17 mutable mappings match runtime layout'
  foreach ($rule in @($layout.rules | Where-Object legacy_projection -eq 'instance')) {
    $expected = 'instance/' + (([string]$rule.target_path -replace '\\', '/').TrimStart('./'))
    Assert-Check ('PROJECTION-MAP-' + $rule.id) ($manifestInstanceMap[[string]$rule.logical_path] -eq $expected) ('legacy map targets ' + $expected)
  }

  $casesPath = Join-Path $Root 'orquestador/testing/fixtures/root-resolver/resolver-cases.json'
  $cases = [IO.File]::ReadAllText($casesPath) | ConvertFrom-Json
  $installRoot = Join-Path $fixtureRoot 'install-root'
  $catalogRoot = Join-Path $fixtureRoot 'catalog-root'
  $projectA = Join-Path $fixtureRoot 'project-a'
  $projectB = Join-Path $fixtureRoot 'project-b'
  $externalRoot = Join-Path $fixtureRoot 'external-target'
  Copy-RuntimeFixture $installRoot
  foreach ($path in @($catalogRoot, $projectA, $projectB, $externalRoot)) { [void][IO.Directory]::CreateDirectory($path) }
  Write-CentralBinding $projectA 'project-a' 'instance-a'
  Write-CentralBinding $projectB 'project-b' 'instance-b'
  [void][IO.Directory]::CreateDirectory((Join-Path $projectA '.hebrinex\instance'))
  [void][IO.Directory]::CreateDirectory((Join-Path $projectB '.hebrinex\instance'))
  Write-TestText (Join-Path $installRoot 'PROGRESS.md') 'legacy decoy must not be selected in central mode'
  foreach ($file in @(Get-ChildItem -LiteralPath $installRoot -File -Recurse)) { $file.IsReadOnly = $true }

  $contextA = Resolve-HebriRuntimeContext -InstallRoot $installRoot -ProjectRoot $projectA -DeploymentMode central_instance -CatalogRoot $catalogRoot
  $contextB = Resolve-HebriRuntimeContext -InstallRoot $installRoot -ProjectRoot $projectB -DeploymentMode central_instance -CatalogRoot $catalogRoot
  Assert-Check 'P01-V01-CONTEXT-A' ($contextA.project_id -eq 'project-a' -and $contextA.trusted_install_source -eq 'launcher_input') 'project A context preserves trusted root source'
  Assert-Check 'P01-V01-CONTEXT-B' ($contextB.project_id -eq 'project-b' -and $contextB.instance_root -ne $contextA.instance_root) 'project contexts are isolated'
  $coverageFailures = New-Object System.Collections.Generic.List[string]
  foreach ($rule in @($layout.rules)) {
    try {
      if ([string]$rule.class -eq 'denied') {
        try {
          Resolve-HebriResourcePath -Context $contextA -LogicalPath ([string]$rule.logical_path) -Access read -AllowMissing | Out-Null
          [void]$coverageFailures.Add(([string]$rule.id + ' accepted a denied resource'))
        }
        catch {
          if ($_.Exception.Message -notlike 'RESOURCE_UNKNOWN:*') { [void]$coverageFailures.Add(([string]$rule.id + ' returned ' + $_.Exception.Message)) }
        }
      }
      else {
        $covered = Resolve-HebriResourcePath -Context $contextA -LogicalPath ([string]$rule.logical_path) -Access read -AllowMissing
        if ($covered.rule_id -ne [string]$rule.id -or $covered.classification -ne [string]$rule.class -or $covered.root_kind -ne [string]$rule.root) {
          [void]$coverageFailures.Add(([string]$rule.id + ' resolved through ' + $covered.rule_id + '/' + $covered.classification + '/' + $covered.root_kind))
        }
      }
    }
    catch { [void]$coverageFailures.Add(([string]$rule.id + ' failed: ' + $_.Exception.Message)) }
  }
  Assert-Check 'P01-V01-ALL-RULES' ($coverageFailures.Count -eq 0) ((@($layout.rules).Count).ToString() + ' rules exercised; mismatches=' + ($coverageFailures -join '; '))
  $installBefore = Get-TreeFingerprint $installRoot
  foreach ($case in @($cases.positive)) {
    $result = Resolve-HebriResourcePath -Context $contextA -LogicalPath ([string]$case.resource) -Access ([string]$case.access) -AllowMissing
    Assert-Check ('P01-V01-' + $case.id + '-CLASS') ($result.classification -eq [string]$case.class) ('classified as ' + $result.classification)
    Assert-Check ('P01-V01-' + $case.id + '-ROOT') ($result.root_kind -eq [string]$case.root) ('resolved from ' + $result.root_kind)
    Assert-Check ('P01-V01-' + $case.id + '-CONTAINED') (Test-HebriPathContained -Root $result.root_path -Candidate $result.path) 'result remains inside declared root'
  }
  $aWrite = Resolve-HebriResourcePath -Context $contextA -LogicalPath 'orquestador/context/session.md' -Access write
  $bWrite = Resolve-HebriResourcePath -Context $contextB -LogicalPath 'orquestador/context/session.md' -Access write
  Assert-Check 'P01-V01-PROJECT-SEPARATION' ($aWrite.path -ne $bWrite.path -and $aWrite.path.StartsWith($contextA.instance_root) -and $bWrite.path.StartsWith($contextB.instance_root)) 'same resource resolves to each project instance only'
  Assert-ThrowsCode 'P01-V01-PRODUCT-WRITE' 'RESOURCE_WRITE_FORBIDDEN' { Resolve-HebriResourcePath -Context $contextA -LogicalPath 'scripts/lib/hebri-common.psm1' -Access write }
  Assert-Check 'P01-V01-INSTALL-UNCHANGED' ((Get-TreeFingerprint $installRoot) -eq $installBefore) 'resolver performed zero product writes'

  Assert-ThrowsCode 'P01-V02-MISSING-READ' 'LOCAL_STATE_MISSING' { Resolve-HebriResourcePath -Context $contextA -LogicalPath 'PROGRESS.md' -Access read }
  $prepare = Resolve-HebriResourcePath -Context $contextA -LogicalPath 'PROGRESS.md' -Access write
  Assert-Check 'P01-V02-PREPARE-PATH' ($prepare.path -eq (Join-Path $contextA.instance_root 'PROGRESS.md') -and -not $prepare.exists) 'write resolution returns only the canonical destination'
  Assert-Check 'P01-V02-NO-CREATE' (-not (Test-Path -LiteralPath $prepare.path)) 'prepare-create did not create a file'
  $optional = Resolve-HebriResourcePath -Context $contextA -LogicalPath 'PROGRESS.md' -Access read -AllowMissing
  Assert-Check 'P01-V02-OPTIONAL' (-not $optional.exists -and -not $optional.legacy_fallback_used) 'optional absence is explicit and central mode does not fall back'
  Assert-Check 'P01-V02-INSTALL-UNCHANGED' ((Get-TreeFingerprint $installRoot) -eq $installBefore) 'missing-state queries performed zero product writes'

  $externalWitness = Join-Path $externalRoot 'unchanged.txt'
  Write-TestText $externalWitness 'unchanged'
  $outsideBefore = Get-TreeFingerprint $externalRoot
  foreach ($case in @($cases.negative)) {
    Assert-ThrowsCode ('P01-V03-' + $case.id) ([string]$case.error) { Resolve-HebriResourcePath -Context $contextA -LogicalPath ([string]$case.resource) -Access write }
  }
  $tamperedContext = $contextA | ConvertTo-Json -Depth 8 | ConvertFrom-Json
  $tamperedContext.instance_root = $projectA + '-similar-prefix'
  Assert-ThrowsCode 'P01-V03-SIMILAR-ROOT' 'BINDING_CONFLICT' { Resolve-HebriResourcePath -Context $tamperedContext -LogicalPath 'PROGRESS.md' -Access write }
  Assert-Check 'P01-V03-OUTSIDE-UNCHANGED' ((Get-TreeFingerprint $externalRoot) -eq $outsideBefore) 'escape attempts left external fixture untouched'

  $contextDirectory = Join-Path $contextA.instance_root 'context'
  [void][IO.Directory]::CreateDirectory($contextDirectory)
  $junctionPath = Join-Path $contextDirectory 'junction-out'
  try {
    [void](New-Item -ItemType Junction -Path $junctionPath -Target $externalRoot -ErrorAction Stop)
    [void]$script:ReparsePaths.Add($junctionPath)
    Assert-ThrowsCode 'P01-V04-JUNCTION' 'REPARSE_POINT_UNSUPPORTED' { Resolve-HebriResourcePath -Context $contextA -LogicalPath 'orquestador/context/junction-out/file.txt' -Access write }
  }
  catch {
    Add-Check 'P01-V04-JUNCTION' 'blocked' ('host could not create junction: ' + $_.Exception.Message)
  }
  if (Test-Path -LiteralPath $junctionPath) {
    Remove-TestReparsePath $junctionPath
    [void]$script:ReparsePaths.Remove($junctionPath)
  }
  $symlinkPath = Join-Path $contextDirectory 'symlink-out'
  try {
    [void](New-Item -ItemType SymbolicLink -Path $symlinkPath -Target $externalRoot -ErrorAction Stop)
    [void]$script:ReparsePaths.Add($symlinkPath)
    Assert-ThrowsCode 'P01-V04-SYMLINK' 'REPARSE_POINT_UNSUPPORTED' { Resolve-HebriResourcePath -Context $contextA -LogicalPath 'orquestador/context/symlink-out/file.txt' -Access write }
  }
  catch {
    Add-Check 'P01-V04-SYMLINK' 'blocked' ('host lacks symbolic-link capability: ' + $_.Exception.Message)
  }
  if (Test-Path -LiteralPath $symlinkPath) {
    Remove-TestReparsePath $symlinkPath
    [void]$script:ReparsePaths.Remove($symlinkPath)
  }

  $legacyProject = Join-Path $fixtureRoot 'legacy-project'
  $legacyInstall = Join-Path $legacyProject '.hebrinex'
  [void][IO.Directory]::CreateDirectory($legacyProject)
  Copy-RuntimeFixture $legacyInstall
  Write-LegacyBinding $legacyInstall $legacyProject 'legacy-project' 'legacy-instance'
  Write-TestText (Join-Path $legacyInstall 'PROGRESS.md') 'legacy progress'
  $legacyContext = Resolve-HebriRuntimeContext -InstallRoot $legacyInstall -ProjectRoot $legacyProject -DeploymentMode legacy_bound -CatalogRoot $catalogRoot
  $oldLegacy = hebri-common\Resolve-HarnessPath -Root $legacyInstall -RelativePath 'PROGRESS.md'
  $newLegacy = Resolve-HebriResourcePath -Context $legacyContext -LogicalPath 'PROGRESS.md' -Access read
  Assert-Check 'P01-V05-ROOT-FALLBACK' ($oldLegacy -eq $newLegacy.path -and $newLegacy.legacy_fallback_used) 'explicit legacy mode matches prior root fallback'
  Write-TestText (Join-Path $legacyInstall 'instance\PROGRESS.md') 'canonical progress'
  $oldCanonical = hebri-common\Resolve-HarnessPath -Root $legacyInstall -RelativePath 'PROGRESS.md'
  $newCanonical = Resolve-HebriResourcePath -Context $legacyContext -LogicalPath 'PROGRESS.md' -Access read
  Assert-Check 'P01-V05-CANONICAL-PREFERRED' ($oldCanonical -eq $newCanonical.path -and -not $newCanonical.legacy_fallback_used) 'explicit legacy mode prefers existing canonical instance state'
  Assert-ThrowsCode 'P01-V05-CENTRAL-NO-FALLBACK' 'LOCAL_STATE_MISSING' { Resolve-HebriResourcePath -Context $contextA -LogicalPath 'PROGRESS.md' -Access read }

  $corruptInstall = Join-Path $fixtureRoot 'corrupt-install'
  Copy-RuntimeFixture $corruptInstall
  $corruptLayoutPath = Join-Path $corruptInstall 'packaging\runtime-layout.json'
  $corruptLayout = [IO.File]::ReadAllText($corruptLayoutPath) | ConvertFrom-Json
  $corruptLayout.rules = @()
  Write-TestText $corruptLayoutPath ($corruptLayout | ConvertTo-Json -Depth 12)
  Assert-ThrowsCode 'P01-V06-CORRUPT-LAYOUT' 'RUNTIME_INTEGRITY_FAILED' { Resolve-HebriRuntimeContext -InstallRoot $corruptInstall -ProjectRoot $projectA -DeploymentMode central_instance -CatalogRoot $catalogRoot }

  $injectedProject = Join-Path $fixtureRoot 'injected-project'
  [void][IO.Directory]::CreateDirectory($injectedProject)
  $witnessScript = Join-Path $externalRoot 'witness.ps1'
  $witnessMarker = Join-Path $externalRoot 'witness-executed.txt'
  Write-TestText $witnessScript ("[IO.File]::WriteAllText('" + $witnessMarker.Replace("'", "''") + "','executed')")
  Write-CentralBinding $injectedProject 'injected-project' 'injected-instance' -Injected -WitnessPath $witnessScript
  Assert-ThrowsCode 'P01-V06-BINDING-INJECTION' 'BINDING_CONFLICT' { Resolve-HebriRuntimeContext -InstallRoot $installRoot -ProjectRoot $injectedProject -DeploymentMode central_instance -CatalogRoot $catalogRoot }
  Assert-Check 'P01-V06-WITNESS-NOT-RUN' (-not (Test-Path -LiteralPath $witnessMarker)) 'binding path was treated as data and never executed'

  $conflictProject = Join-Path $fixtureRoot 'conflict-project'
  [void][IO.Directory]::CreateDirectory($conflictProject)
  Write-CentralBinding $conflictProject 'conflict-project' 'conflict-instance'
  Write-TestText (Join-Path $conflictProject '.hebrinex\instance\PROJECT_BINDING.yaml') 'binding_mode: bound'
  Assert-ThrowsCode 'P01-V06-DUAL-BINDING' 'BINDING_CONFLICT' { Resolve-HebriRuntimeContext -InstallRoot $installRoot -ProjectRoot $conflictProject -DeploymentMode central_instance -CatalogRoot $catalogRoot }

  if ($RunNegativeTests) {
    $conflictRuleInstall = Join-Path $fixtureRoot 'conflicting-rule-install'
    Copy-RuntimeFixture $conflictRuleInstall
    $conflictLayoutPath = Join-Path $conflictRuleInstall 'packaging\runtime-layout.json'
    $conflictLayout = [IO.File]::ReadAllText($conflictLayoutPath) | ConvertFrom-Json
    $duplicate = $conflictLayout.rules[0] | ConvertTo-Json | ConvertFrom-Json
    $duplicate.id = 'DENY-GIT-CONFLICT'
    $duplicate.class = 'product'
    $duplicate.root = 'InstallRoot'
    $duplicate.target_path = 'escape'
    $duplicate.read = $true
    $conflictLayout.rules = @($conflictLayout.rules) + @($duplicate)
    Write-TestText $conflictLayoutPath ($conflictLayout | ConvertTo-Json -Depth 12)
    Assert-ThrowsCode 'P01-NEGATIVE-AMBIGUOUS-RULE' 'RUNTIME_INTEGRITY_FAILED' { Get-HebriRuntimeLayout -InstallRoot $conflictRuleInstall }
  }

  $installAfter = Get-TreeFingerprint $installRoot
  Assert-Check 'PRODUCT-FINAL-UNCHANGED' ($installAfter -eq $installBefore) 'all resolver calls preserved the simulated read-only product'
}
finally {
  foreach ($path in @($script:ReparsePaths)) {
    try { Remove-TestReparsePath $path } catch { [void]$script:Warnings.Add('cleanup reparse failed: ' + $_.Exception.Message) }
  }
  if (Test-Path -LiteralPath $fixtureRoot -PathType Container) {
    $fixtureFull = [IO.Path]::GetFullPath($fixtureRoot)
    $safePrefix = $fixtureParent + [IO.Path]::DirectorySeparatorChar
    if (-not $fixtureFull.StartsWith($safePrefix, [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $marker -PathType Leaf)) {
      [void]$script:Failures.Add('cleanup refused: fixture ownership or containment could not be verified')
    }
    else {
      Get-ChildItem -LiteralPath $fixtureFull -File -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.IsReadOnly = $false }
      Remove-Item -LiteralPath $fixtureFull -Recurse -Force
    }
  }
}

$summary = [pscustomobject]@{
  schema = 'hebrinex.root_resolver.validation'
  schema_version = 1
  contract_version = '1.0.0'
  runtime_api = '1'
  platform = [Environment]::OSVersion.VersionString
  powershell = $PSVersionTable.PSVersion.ToString()
  checks = $script:Checks.ToArray()
  failures = $script:Failures.ToArray()
  warnings = $script:Warnings.ToArray()
}
$summary | ConvertTo-Json -Depth 8

if ($script:Failures.Count -gt 0) { exit 2 }
exit 0
