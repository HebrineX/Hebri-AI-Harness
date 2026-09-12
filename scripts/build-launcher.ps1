param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [string]$OutputPath = '',
  [switch]$Apply
)

$ErrorActionPreference = 'Stop'

function Get-FullPath([string]$Path) { return [IO.Path]::GetFullPath($Path) }

$Root = Get-FullPath $Root
$source = Join-Path $Root 'packaging/launcher/HebrinexLauncher.cs'
$artifactRoot = Get-FullPath (Join-Path $Root 'artifacts/p06')
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $artifactRoot 'launcher/hebrinex.exe' }
$OutputPath = Get-FullPath $OutputPath
$artifactPrefix = $artifactRoot.TrimEnd('\') + '\'
if (-not $OutputPath.StartsWith($artifactPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'OUTPUT_OUTSIDE_ARTIFACT_ROOT' }
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw 'LAUNCHER_SOURCE_MISSING' }

$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
if ($null -eq $dotnet) { throw 'DOTNET_SDK_10_0_204_MISSING' }
$sdkLine = @(& $dotnet.Source --list-sdks | Where-Object { $_ -match '^10[.]0[.]204\s+\[' } | Select-Object -First 1)
if ($sdkLine.Count -ne 1 -or $sdkLine[0] -notmatch '^10[.]0[.]204\s+\[(.+)\]$') { throw 'DOTNET_SDK_10_0_204_MISSING' }
$roslyn = Join-Path $Matches[1] '10.0.204/Roslyn/bincore/csc.dll'
$frameworkRoot = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319'
$csc = Join-Path $frameworkRoot 'csc.exe'
$webExtensions = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/System.Web.Extensions.dll'
if (-not (Test-Path -LiteralPath $roslyn -PathType Leaf) -or -not (Test-Path -LiteralPath $csc -PathType Leaf) -or -not (Test-Path -LiteralPath $webExtensions -PathType Leaf)) { throw 'DOTNET_FRAMEWORK_48_TOOLCHAIN_MISSING' }
$compilerVersion = (Get-Item -LiteralPath $csc).VersionInfo.FileVersion
if ($compilerVersion -notmatch '^4[.]8[.]') { throw "DOTNET_FRAMEWORK_48_TOOLCHAIN_MISMATCH: $compilerVersion" }
$roslynVersion = (& $dotnet.Source $roslyn /version).Trim()
if ($LASTEXITCODE -ne 0 -or $roslynVersion -ne '5.3.0-2.26230.114 (e7aa4b537d95ae955b5c98c25fa9b9220e7eb71e)') { throw "ROSLYN_TOOLCHAIN_MISMATCH: $roslynVersion" }

$plan = [ordered]@{
  source = $source
  output = $OutputPath
  compiler = 'Roslyn csc via .NET SDK 10.0.204'
  compiler_version = $roslynVersion
  target_reference_version = $compilerVersion
  platform = 'x64'
  target_framework = '.NET Framework 4.8'
  writes_performed = $false
}
if (-not $Apply) { return [pscustomobject]$plan }

[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($OutputPath))
$stageDirectory = Join-Path ([IO.Path]::GetDirectoryName($OutputPath)) ('.launcher-stage-' + [guid]::NewGuid().ToString('N'))
$stage = Join-Path $stageDirectory 'hebrinex.exe'
try {
  [void][IO.Directory]::CreateDirectory($stageDirectory)
  $arguments = @(
    '/nologo', '/noconfig', '/nostdlib+', '/target:exe', '/platform:x64', '/optimize+', '/deterministic+', '/utf8output',
    ('/out:' + $stage),
    ('/reference:' + (Join-Path $frameworkRoot 'mscorlib.dll')),
    ('/reference:' + (Join-Path $frameworkRoot 'System.dll')),
    ('/reference:' + (Join-Path $frameworkRoot 'System.Core.dll')),
    ('/reference:' + $webExtensions),
    $source
  )
  & $dotnet.Source $roslyn @arguments
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $stage -PathType Leaf)) { throw "LAUNCHER_BUILD_FAILED: exit=$LASTEXITCODE" }
  if (Test-Path -LiteralPath $OutputPath -PathType Leaf) { [IO.File]::Delete($OutputPath) }
  [IO.File]::Move($stage, $OutputPath)
}
finally {
  if (Test-Path -LiteralPath $stageDirectory -PathType Container) { Remove-Item -LiteralPath $stageDirectory -Recurse -Force }
}

$plan.writes_performed = $true
$plan.sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $OutputPath).Hash.ToLowerInvariant()
$plan.size = (Get-Item -LiteralPath $OutputPath).Length
return [pscustomobject]$plan
