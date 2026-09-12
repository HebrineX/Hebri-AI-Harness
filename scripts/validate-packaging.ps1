param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/hebri-common.psm1') -Force -DisableNameChecking

$script:Checks = 0
$script:Failures = New-Object Collections.Generic.List[string]

function Assert-P06([bool]$Condition, [string]$Message) {
  $script:Checks++
  if (-not $Condition) { [void]$script:Failures.Add($Message) }
}

function Invoke-P06Launcher([string]$Launcher, [string[]]$Arguments, [string]$WorkingDirectory) {
  $start = [Diagnostics.ProcessStartInfo]::new()
  $start.FileName = $Launcher
  $start.WorkingDirectory = $WorkingDirectory
  $start.UseShellExecute = $false
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
  $process = [Diagnostics.Process]::Start($start)
  $stdoutTask = $process.StandardOutput.ReadToEndAsync()
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $process.WaitForExit()
  return [pscustomobject]@{ ExitCode = $process.ExitCode; Stdout = $stdoutTask.GetAwaiter().GetResult(); Stderr = $stderrTask.GetAwaiter().GetResult() }
}

function Get-P06PeMachine([string]$Path) {
  $stream = [IO.File]::OpenRead($Path)
  $reader = [IO.BinaryReader]::new($stream)
  try {
    if ($reader.ReadUInt16() -ne 0x5a4d) { return 0 }
    $stream.Position = 0x3c
    $peOffset = $reader.ReadInt32()
    $stream.Position = $peOffset
    if ($reader.ReadUInt32() -ne 0x00004550) { return 0 }
    return $reader.ReadUInt16()
  }
  finally { $reader.Dispose(); $stream.Dispose() }
}

function Get-P06PayloadInventory([object]$Manifest) {
  return @($Manifest.files | Sort-Object path | ForEach-Object {
    [ordered]@{ path = [string]$_.path; source_path = [string]$_.source_path; class = [string]$_.class; size = [int64]$_.size; sha256 = [string]$_.sha256 }
  })
}

$Root = [IO.Path]::GetFullPath($Root)
$artifactRoot = Join-Path $Root 'artifacts/p06'
[void][IO.Directory]::CreateDirectory($artifactRoot)

$jsonInputs = @(
  'packaging/runtime-layout.json',
  'packaging/release.json',
  'packaging/toolchain-lock.json',
  'orquestador/runtime/schemas/payload-manifest.schema.json',
  'orquestador/runtime/schemas/release-metadata.schema.json',
  'orquestador/runtime/schemas/toolchain-lock.schema.json',
  'orquestador/runtime/templates/payload-manifest.template.json',
  'orquestador/runtime/templates/release-metadata.template.json',
  'orquestador/runtime/templates/toolchain-lock.template.json',
  'orquestador/migration/baselines/0.10.11.json',
  'orquestador/migration/baselines/0.16.0.json'
)
foreach ($relative in $jsonInputs) {
  try { [void](Read-HebriJsonDocument (Join-Path $Root $relative)); Assert-P06 $true "JSON rejected: $relative" }
  catch { Assert-P06 $false "JSON rejected: $relative - $($_.Exception.Message)" }
}

$layout = Read-HebriJsonDocument (Join-Path $Root 'packaging/runtime-layout.json')
$release = Read-HebriJsonDocument (Join-Path $Root 'packaging/release.json')
$toolchain = Read-HebriJsonDocument (Join-Path $Root 'packaging/toolchain-lock.json')
Assert-P06 ($layout.schema -eq 'hebrinex.runtime.layout' -and $layout.default_class -eq 'denied') 'runtime layout is not closed by default'
Assert-P06 ($release.product_version -eq '0.17.1' -and $release.install_scope -eq 'perMachine' -and $release.features.mcp -eq 'optional_feature_missing') 'release metadata is incompatible'
Assert-P06 (@($toolchain.components | Where-Object { $_.id -eq 'wix' -and $_.version -eq '5.0.2' }).Count -eq 1) 'WiX toolchain is not pinned'
Assert-P06 (@($toolchain.components | Where-Object { $_.id -eq 'roslyn' -and $_.version -eq '5.3.0-2.26230.114' }).Count -eq 1) 'Roslyn toolchain is not pinned'
Assert-P06 ($toolchain.release_decision -eq 'local_build_only_network_review_pending') 'toolchain release limitation is missing'

foreach ($version in @('0.10.11','0.16.0')) {
  $baseline = Read-HebriJsonDocument (Join-Path $Root "orquestador/migration/baselines/$version.json")
  Assert-P06 ($baseline.inventory_scope -eq 'release_manifest' -and $baseline.source_manifest_sha256 -match '^[a-f0-9]{64}$') "baseline $version lacks manifest authority"
  Assert-P06 (@($baseline.files | Where-Object { $_.path -eq 'infoHebriHarness.md' }).Count -eq 0) "baseline $version leaks personal metadata"
}

$package = Read-HebriJsonDocument (Join-Path $Root 'mcp/package.json')
$packageLock = [IO.File]::ReadAllText((Join-Path $Root 'mcp/package-lock.json')) | ConvertFrom-Json -AsHashtable
Assert-P06 ($package.dependencies.zod -eq '4.4.3') 'MCP direct zod dependency is not pinned'
Assert-P06 ($packageLock['packages']['']['dependencies']['zod'] -eq '4.4.3') 'MCP lockfile root lacks direct zod dependency'

$payloadA = Join-Path $artifactRoot 'repro-payload-a'
$payloadB = Join-Path $artifactRoot 'repro-payload-b'
$finalPayload = Join-Path $artifactRoot 'payload-core'
$buildA = & (Join-Path $Root 'scripts/build-payload.ps1') -Root $Root -OutputPath $payloadA -Apply
$buildB = & (Join-Path $Root 'scripts/build-payload.ps1') -Root $Root -OutputPath $payloadB -Apply
$buildFinal = & (Join-Path $Root 'scripts/build-payload.ps1') -Root $Root -OutputPath $finalPayload -Apply
$manifestA = Read-HebriJsonDocument (Join-Path $payloadA 'payload-manifest.json')
$manifestB = Read-HebriJsonDocument (Join-Path $payloadB 'payload-manifest.json')
$inventoryA = ConvertTo-HebriCanonicalJson (Get-P06PayloadInventory $manifestA)
$inventoryB = ConvertTo-HebriCanonicalJson (Get-P06PayloadInventory $manifestB)
Assert-P06 ($buildA.writes_performed -and $buildB.writes_performed -and $buildFinal.writes_performed) 'payload build did not publish all three targets'
Assert-P06 ($manifestA.tree_sha256 -eq $manifestB.tree_sha256 -and $inventoryA -eq $inventoryB) 'P06-V05 payload inventories are not reproducible'
Assert-P06 (@($manifestA.files).Count -gt 400) 'payload inventory is unexpectedly small'
Assert-P06 ($manifestA.features.core -eq $true -and $manifestA.features.mcp -eq $false) 'payload feature state is incorrect'

$forbidden = @($manifestA.files | Where-Object {
  $p = ([string]$_.path).ToLowerInvariant()
  $p -in @('project_binding.yaml','progress.md','infohebri.md','infohebriharness.md') -or
  $p.StartsWith('.git/') -or $p.StartsWith('.codex/') -or $p.StartsWith('artifacts/') -or $p.StartsWith('migracion/') -or
  $p.StartsWith('mcp/node_modules/') -or $p.StartsWith('orquestador/memory/local/') -or $p.StartsWith('orquestador/memory/project/') -or
  $p.StartsWith('orquestador/memory/cycle/') -or $p.StartsWith('orquestador/memory/daily/') -or $p.StartsWith('orquestador/memory/complete/') -or
  $p.StartsWith('orquestador/sdd/progress/approvals/') -or $p.StartsWith('orquestador/sdd/progress/cycles/') -or
  $p.StartsWith('orquestador/sdd/progress/evidence/') -or $p.StartsWith('orquestador/sdd/progress/locks/') -or
  $p.StartsWith('orquestador/migration/backups/') -or
  ($p.StartsWith('orquestador/migration/reports/') -and $p -ne 'orquestador/migration/reports/migration-report.template.yaml')
})
Assert-P06 ($forbidden.Count -eq 0) ('P06-V07 payload contains forbidden paths: ' + (($forbidden.path | Select-Object -First 10) -join ', '))
Assert-P06 (@($manifestA.files | Where-Object { $_.path -eq 'packaging/runtime-layout.json' }).Count -eq 1) 'payload omits runtime layout authority'
Assert-P06 (@($manifestA.files | Where-Object { $_.path -eq 'release.json' }).Count -eq 1) 'payload omits release metadata'

$integrityFailures = New-Object Collections.Generic.List[string]
foreach ($entry in $manifestA.files) {
  $path = Join-Path $payloadA (([string]$entry.path) -replace '/', [IO.Path]::DirectorySeparatorChar)
  if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-HebriFileSha256 $path) -ne [string]$entry.sha256 -or (Get-Item -LiteralPath $path).Length -ne [int64]$entry.size) { [void]$integrityFailures.Add([string]$entry.path) }
}
Assert-P06 ($integrityFailures.Count -eq 0) ('payload file integrity mismatch: ' + (($integrityFailures | Select-Object -First 10) -join ', '))

$launcher = Join-Path $payloadA 'bin/hebrinex.exe'
Assert-P06 ((Get-P06PeMachine $launcher) -eq 0x8664) 'launcher is not a PE32+ AMD64 executable'
$help = Invoke-P06Launcher $launcher @('help') $artifactRoot
Assert-P06 ($help.ExitCode -eq 0 -and $help.Stdout -match '(?m)^reason=HELP\r?$' -and [string]::IsNullOrWhiteSpace($help.Stderr)) 'launcher help did not preserve stdout/stderr/exit code'

$argumentRoot = Join-Path $artifactRoot ('argument fixture ' + [char]0x03a9 + ' & ; [x]')
[void][IO.Directory]::CreateDirectory($argumentRoot)
$argumentResult = Invoke-P06Launcher $launcher @('status','-ProjectRoot',$argumentRoot,'-Json') $artifactRoot
$argumentJson = $null
try { $argumentJson = $argumentResult.Stdout | ConvertFrom-Json } catch {}
$expectedBinding = Join-Path $argumentRoot '.hebrinex/binding.json'
Assert-P06 ($argumentResult.ExitCode -eq 3 -and $null -ne $argumentJson -and [string]::Equals([string]$argumentJson.details.binding_path, [IO.Path]::GetFullPath($expectedBinding), [StringComparison]::OrdinalIgnoreCase)) 'P06-V03 launcher altered Unicode, spaces or metacharacters'

$witnessRoot = Join-Path $artifactRoot 'cwd-witness'
[void][IO.Directory]::CreateDirectory($witnessRoot)
[IO.File]::WriteAllText((Join-Path $witnessRoot 'powershell.exe'), 'not an executable', [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $witnessRoot 'System.Web.Extensions.dll'), 'not a library', [Text.UTF8Encoding]::new($false))
$cwdResult = Invoke-P06Launcher $launcher @('help') $witnessRoot
Assert-P06 ($cwdResult.ExitCode -eq 0 -and $cwdResult.Stdout -match '(?m)^reason=HELP\r?$') 'P06-V04 launcher searched executable or library content in CWD'

$tampered = Join-Path $artifactRoot 'tampered-payload'
if (Test-Path -LiteralPath $tampered -PathType Container) { Remove-Item -LiteralPath $tampered -Recurse -Force }
Copy-Item -LiteralPath $payloadA -Destination $tampered -Recurse
[IO.File]::AppendAllText((Join-Path $tampered 'scripts/hebrinex-central.ps1'), "`n# controlled P06 tamper`n", [Text.UTF8Encoding]::new($false))
$tamperResult = Invoke-P06Launcher (Join-Path $tampered 'bin/hebrinex.exe') @('help') $witnessRoot
Assert-P06 ($tamperResult.ExitCode -eq 12 -and $tamperResult.Stderr -match 'PAYLOAD_INTEGRITY_FAILED' -and $tamperResult.Stderr -match '(size|hash) mismatch') 'P06-V04 tampered product was not rejected before dispatch'

$mcpResult = Invoke-P06Launcher $launcher @('mcp') $artifactRoot
Assert-P06 ($mcpResult.ExitCode -eq 4 -and $mcpResult.Stderr -match 'OPTIONAL_FEATURE_MISSING') 'P06-V06 absent MCP feature did not fail closed'

$msiA = Join-Path $artifactRoot 'repro-a.msi'
$msiB = Join-Path $artifactRoot 'repro-b.msi'
$finalMsi = Join-Path $artifactRoot 'Hebri-AI-Harness-0.17.1-x64.msi'
$msiBuildA = & (Join-Path $Root 'scripts/build-msi.ps1') -Root $Root -PayloadPath $payloadA -OutputPath $msiA -Apply
$msiBuildB = & (Join-Path $Root 'scripts/build-msi.ps1') -Root $Root -PayloadPath $payloadB -OutputPath $msiB -Apply
$msiBuildFinal = & (Join-Path $Root 'scripts/build-msi.ps1') -Root $Root -PayloadPath $finalPayload -OutputPath $finalMsi -Apply
Assert-P06 ($msiBuildA.writes_performed -and $msiBuildB.writes_performed -and $msiBuildFinal.writes_performed) 'MSI build or ICE validation failed'

$wix = (Get-Command wix).Source
$decompiled = Join-Path $artifactRoot 'repro-a.decompiled.wxs'
$extractRoot = Join-Path $artifactRoot 'repro-a.extracted'
$intermediate = Join-Path $artifactRoot 'repro-a.decompile-temp'
foreach ($path in @($extractRoot,$intermediate)) { if (Test-Path -LiteralPath $path -PathType Container) { Remove-Item -LiteralPath $path -Recurse -Force } }
if (Test-Path -LiteralPath $decompiled -PathType Leaf) { [IO.File]::Delete($decompiled) }
$decompileOutput = @(& $wix msi decompile $msiA -o $decompiled -x $extractRoot -intermediateFolder $intermediate 2>&1)
Assert-P06 ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $decompiled -PathType Leaf)) ('MSI decompile failed: ' + (($decompileOutput | Select-Object -First 5) -join ' '))
$decompiledText = if (Test-Path -LiteralPath $decompiled -PathType Leaf) { [IO.File]::ReadAllText($decompiled) } else { '' }
$decompiledXml = if (-not [string]::IsNullOrWhiteSpace($decompiledText)) { [xml]$decompiledText } else { $null }
$namespace = [Xml.XmlNamespaceManager]::new($decompiledXml.NameTable)
$namespace.AddNamespace('w', 'http://wixtoolset.org/schemas/v4/wxs')
$fileCount = @($decompiledXml.SelectNodes('//w:File', $namespace)).Count
$componentCount = @($decompiledXml.SelectNodes('//w:Component', $namespace)).Count
Assert-P06 ($decompiledText -match 'ProductCode="[{]E6639B49-CC2C-5B2C-BE31-5225B7A7852A[}]"' -and $decompiledText -match 'UpgradeCode="[{]5E6C72A1-831B-49CE-B25F-21D930A77101[}]"') 'compiled MSI identity is incorrect'
Assert-P06 ($null -ne $decompiledXml.SelectSingleNode('//w:StandardDirectory[@Id="ProgramFiles64Folder"]', $namespace) -and $null -ne $decompiledXml.SelectSingleNode('//w:Environment[@Name="PATH" and @System="yes" and @Value="[INSTALLFOLDER]bin"]', $namespace)) 'compiled MSI lacks x64 per-machine PATH integration'
Assert-P06 ($null -ne $decompiledXml.SelectSingleNode('//w:RegistryValue[@Root="HKLM" and @Key="Software\Hebri-AI-Harness" and @Name="InstallRoot"]', $namespace)) 'compiled MSI lacks machine InstallRoot registration'
Assert-P06 (@($decompiledXml.SelectNodes('//w:CustomAction', $namespace)).Count -eq 0 -and $decompiledText -notmatch [regex]::Escape($Root)) 'compiled MSI contains a custom action or source-tree path'
Assert-P06 ($fileCount -eq (@($manifestA.files).Count + 1) -and $componentCount -eq ($fileCount + 1)) 'compiled MSI file/component inventory is incomplete'

$report = [ordered]@{
  schema = 'hebrinex.p06_validation_report'
  schema_version = 1
  observed_at = (Get-Date).ToUniversalTime().ToString('o')
  checks = $script:Checks
  failures = @($script:Failures | ForEach-Object { $_ })
  payload = [ordered]@{
    file_count = @($manifestA.files).Count
    tree_sha256 = $manifestA.tree_sha256
    manifest_sha256 = Get-HebriFileSha256 (Join-Path $finalPayload 'payload-manifest.json')
    reproducible = ($manifestA.tree_sha256 -eq $manifestB.tree_sha256 -and $inventoryA -eq $inventoryB)
  }
  launcher = [ordered]@{ sha256 = Get-HebriFileSha256 (Join-Path $finalPayload 'bin/hebrinex.exe'); pe_machine = '0x8664'; core = 'pass'; mcp = 'optional_feature_missing' }
  msi = [ordered]@{
    path = $finalMsi
    sha256 = Get-HebriFileSha256 $finalMsi
    size = (Get-Item -LiteralPath $finalMsi).Length
    wix_version = $msiBuildFinal.wix_version
    ice_validation = 'pass'
    reproducible_binary = ($msiBuildA.msi_sha256 -eq $msiBuildB.msi_sha256)
    first_sha256 = $msiBuildA.msi_sha256
    second_sha256 = $msiBuildB.msi_sha256
  }
  matrix = [ordered]@{
    'P06-V01' = 'blocked_clean_offline_vm_not_authorized'
    'P06-V02' = 'blocked_install_and_standard_user_session_not_authorized'
    'P06-V03' = 'pass'
    'P06-V04' = 'pass'
    'P06-V05' = 'pass'
    'P06-V06' = 'partial_core_pass_mcp_absent_fail_closed_mcp_present_not_run'
    'P06-V07' = 'pass'
  }
}
Write-HebriAtomicJsonDocument -Path (Join-Path $artifactRoot 'validation-report.json') -Value $report

if ($script:Failures.Count -gt 0) {
  Write-Host "P06 packaging validation checks=$($script:Checks) failures=$($script:Failures.Count)"
  $script:Failures | ForEach-Object { Write-Host "FAIL: $_" }
  exit 1
}
Write-Host "P06 packaging validation checks=$($script:Checks)"
Write-Host "P06 payload files=$(@($manifestA.files).Count) tree_sha256=$($manifestA.tree_sha256) reproducible=pass"
Write-Host "P06 MSI sha256=$($report.msi.sha256) ICE=pass binary_reproducible=$($report.msi.reproducible_binary)"
Write-Host 'P06-V03,V04,V05,V07=pass; P06-V06=partial; P06-V01,V02=blocked'
Write-Host 'P06 packaging validation OK'
