param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [string]$PayloadPath = '',
  [string]$OutputPath = '',
  [switch]$Apply
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/hebri-common.psm1') -Force -DisableNameChecking

function Get-P06MsiFullPath([string]$Path) { return [IO.Path]::GetFullPath($Path) }

function Get-P06StableBytes([string]$Value) {
  $inputBytes = [Text.Encoding]::UTF8.GetBytes('hebrinex-p06:' + $Value.ToLowerInvariant())
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return $sha.ComputeHash($inputBytes) }
  finally { $sha.Dispose() }
}

function Get-P06StableId([string]$Prefix, [string]$Value) {
  $bytes = Get-P06StableBytes $Value
  return $Prefix + (($bytes[0..11] | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Get-P06StableGuid([string]$Value) {
  $hash = Get-P06StableBytes $Value
  $bytes = New-Object byte[] 16
  [Array]::Copy($hash, $bytes, 16)
  $bytes[7] = ($bytes[7] -band 0x0f) -bor 0x50
  $bytes[8] = ($bytes[8] -band 0x3f) -bor 0x80
  return '{' + ([guid]::new($bytes)).ToString().ToUpperInvariant() + '}'
}

function Add-P06XmlElement([xml]$Document, [Xml.XmlElement]$Parent, [string]$Name, [hashtable]$Attributes) {
  $element = $Document.CreateElement($Name, 'http://wixtoolset.org/schemas/v4/wxs')
  foreach ($key in $Attributes.Keys) { $element.SetAttribute([string]$key, [string]$Attributes[$key]) }
  [void]$Parent.AppendChild($element)
  return $element
}

function New-P06PayloadWxs([string]$PayloadRoot, [object]$Manifest, [string]$Destination) {
  [xml]$document = '<?xml version="1.0" encoding="utf-8"?><Wix xmlns="http://wixtoolset.org/schemas/v4/wxs" />'
  $wix = $document.DocumentElement
  $directoryFragment = Add-P06XmlElement $document $wix 'Fragment' @{}
  $directoryRef = Add-P06XmlElement $document $directoryFragment 'DirectoryRef' @{ Id = 'INSTALLFOLDER' }
  $groupFragment = Add-P06XmlElement $document $wix 'Fragment' @{}
  $componentGroup = Add-P06XmlElement $document $groupFragment 'ComponentGroup' @{ Id = 'PayloadComponents' }

  $directoryNodes = @{ '' = $directoryRef }
  $componentIds = New-Object Collections.Generic.List[string]
  $files = @($Manifest.files | ForEach-Object { [string]$_.path }) + @('payload-manifest.json')
  foreach ($path in @($files | Sort-Object -Unique)) {
    $segments = $path -split '/'
    $directoryPath = if ($segments.Count -gt 1) { ($segments[0..($segments.Count - 2)] -join '/') } else { '' }
    $parentPath = ''
    if (-not [string]::IsNullOrWhiteSpace($directoryPath)) {
      foreach ($segment in ($directoryPath -split '/')) {
        $currentPath = if ([string]::IsNullOrWhiteSpace($parentPath)) { $segment } else { $parentPath + '/' + $segment }
        if (-not $directoryNodes.ContainsKey($currentPath)) {
          $directoryNodes[$currentPath] = Add-P06XmlElement $document $directoryNodes[$parentPath] 'Directory' @{ Id = Get-P06StableId 'D_' $currentPath; Name = $segment }
        }
        $parentPath = $currentPath
      }
    }
    $componentId = Get-P06StableId 'C_' $path
    $fileId = Get-P06StableId 'F_' $path
    $component = Add-P06XmlElement $document $directoryNodes[$directoryPath] 'Component' @{ Id = $componentId; Guid = Get-P06StableGuid $path; Bitness = 'always64' }
    $source = Join-Path $PayloadRoot ($path -replace '/', [IO.Path]::DirectorySeparatorChar)
    [void](Add-P06XmlElement $document $component 'File' @{ Id = $fileId; Source = $source; Name = [IO.Path]::GetFileName($path); KeyPath = 'yes'; ReadOnly = 'yes' })
    [void](Add-P06XmlElement $document $componentGroup 'ComponentRef' @{ Id = $componentId })
    [void]$componentIds.Add($componentId)
  }
  $settings = New-Object Xml.XmlWriterSettings
  $settings.Indent = $true
  $settings.IndentChars = '  '
  $settings.NewLineChars = "`n"
  $settings.Encoding = New-Object Text.UTF8Encoding($false)
  $writer = [Xml.XmlWriter]::Create($Destination, $settings)
  try { $document.Save($writer) }
  finally { $writer.Dispose() }
  return $componentIds.Count
}

$Root = Get-P06MsiFullPath $Root
$artifactRoot = Get-P06MsiFullPath (Join-Path $Root 'artifacts/p06')
if ([string]::IsNullOrWhiteSpace($PayloadPath)) { $PayloadPath = Join-Path $artifactRoot 'payload-core' }
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $artifactRoot 'Hebri-AI-Harness-0.17.1-x64.msi' }
$PayloadPath = Get-P06MsiFullPath $PayloadPath
$OutputPath = Get-P06MsiFullPath $OutputPath
$artifactPrefix = $artifactRoot.TrimEnd('\') + '\'
foreach ($candidate in @($PayloadPath,$OutputPath)) { if (-not $candidate.StartsWith($artifactPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'OUTPUT_OUTSIDE_ARTIFACT_ROOT' } }

$packageSource = Join-Path $Root 'packaging/msi/Package.wxs'
$manifestPath = Join-Path $PayloadPath 'payload-manifest.json'
foreach ($required in @($packageSource,$manifestPath)) { if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "MSI_INPUT_MISSING: $required" } }
$manifest = Read-HebriJsonDocument $manifestPath
if ($manifest.schema -ne 'hebrinex.payload_manifest' -or $manifest.harness_version -ne '0.17.1' -or $manifest.architecture -ne 'x64') { throw 'PAYLOAD_MANIFEST_INCOMPATIBLE' }

$declared = @($manifest.files | ForEach-Object { [string]$_.path }) + @('payload-manifest.json')
$actual = @(Get-ChildItem -LiteralPath $PayloadPath -Recurse -File | ForEach-Object { $_.FullName.Substring($PayloadPath.TrimEnd('\').Length + 1).Replace('\','/') })
$difference = @(Compare-Object -ReferenceObject @($declared | Sort-Object) -DifferenceObject @($actual | Sort-Object))
if ($difference.Count -ne 0) { throw ('PAYLOAD_FILE_SET_MISMATCH: ' + (($difference | ForEach-Object { $_.SideIndicator + $_.InputObject }) -join ', ')) }

$wix = Get-Command wix -ErrorAction SilentlyContinue
if ($null -eq $wix) { throw 'WIX_TOOLCHAIN_MISSING' }
$wixVersion = (& $wix.Source --version).Trim()
if ($LASTEXITCODE -ne 0 -or $wixVersion -notmatch '^5[.]0[.]2(?:[+]|$)') { throw "WIX_TOOLCHAIN_MISMATCH: $wixVersion" }

$plan = [ordered]@{
  payload = $PayloadPath
  payload_manifest_sha256 = Get-HebriFileSha256 $manifestPath
  output = $OutputPath
  wix_version = $wixVersion
  architecture = 'x64'
  scope = 'perMachine'
  component_count = $declared.Count
  writes_performed = $false
}
if (-not $Apply) { return [pscustomobject]$plan }

$objectRoot = Join-Path $artifactRoot 'obj'
[void][IO.Directory]::CreateDirectory($objectRoot)
$generatedWxs = Join-Path $objectRoot 'GeneratedPayload.wxs'
$buildLog = [IO.Path]::ChangeExtension($OutputPath, '.build.log')
$validationLog = [IO.Path]::ChangeExtension($OutputPath, '.validate.log')
$actualComponents = New-P06PayloadWxs -PayloadRoot $PayloadPath -Manifest $manifest -Destination $generatedWxs
if ($actualComponents -ne $declared.Count) { throw 'MSI_COMPONENT_COUNT_MISMATCH' }

$buildOutput = @(& $wix.Source build $packageSource $generatedWxs -arch x64 -o $OutputPath 2>&1)
[IO.File]::WriteAllLines($buildLog, @($buildOutput | ForEach-Object { [string]$_ }), [Text.UTF8Encoding]::new($false))
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) { throw "MSI_BUILD_FAILED: exit=$LASTEXITCODE log=$buildLog" }
$validationOutput = @(& $wix.Source msi validate $OutputPath 2>&1)
[IO.File]::WriteAllLines($validationLog, @($validationOutput | ForEach-Object { [string]$_ }), [Text.UTF8Encoding]::new($false))
if ($LASTEXITCODE -ne 0) { throw "MSI_VALIDATION_FAILED: exit=$LASTEXITCODE log=$validationLog" }

$plan.writes_performed = $true
$plan.msi_sha256 = Get-HebriFileSha256 $OutputPath
$plan.msi_size = (Get-Item -LiteralPath $OutputPath).Length
$plan.build_log = $buildLog
$plan.validation_log = $validationLog
$plan.generated_authoring = $generatedWxs
return [pscustomobject]$plan
