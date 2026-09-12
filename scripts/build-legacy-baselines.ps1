param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$Apply
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/legacy-migration-service.psm1') -Force -DisableNameChecking

$Root = [IO.Path]::GetFullPath($Root)
$artifactRoot = Join-Path $Root 'artifacts/p06/baseline-build'
$outputRoot = Join-Path $Root 'orquestador/migration/baselines'
$tags = @('v0.10.11','v0.16.0')
$plan = [ordered]@{
  source = 'local_git_tags'
  tags = $tags
  output = $outputRoot
  inventory_scope = 'release_manifest'
  writes_performed = $false
}
if (-not $Apply) { return [pscustomobject]$plan }

if (-not (Test-Path -LiteralPath (Join-Path $Root '.git') -PathType Container)) { throw 'BASELINE_SOURCE_GIT_MISSING' }
[void][IO.Directory]::CreateDirectory($artifactRoot)
[void][IO.Directory]::CreateDirectory($outputRoot)
$results = New-Object Collections.Generic.List[object]
foreach ($tag in $tags) {
  $version = $tag.TrimStart('v')
  $tagCheck = (& git -C $Root rev-parse --verify ($tag + '^{commit}')).Trim()
  if ($LASTEXITCODE -ne 0 -or $tagCheck -notmatch '^[a-f0-9]{40,64}$') { throw "BASELINE_TAG_MISSING: $tag" }
  $generatedAt = (& git -C $Root show -s --format=%cI ($tag + '^{commit}')).Trim()
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($generatedAt)) { throw "BASELINE_TAG_DATE_MISSING: $tag" }
  $zip = Join-Path $artifactRoot ($version + '.zip')
  $source = Join-Path $artifactRoot ($version + '-source')
  if (Test-Path -LiteralPath $zip -PathType Leaf) { [IO.File]::Delete($zip) }
  if (Test-Path -LiteralPath $source -PathType Container) { Remove-Item -LiteralPath $source -Recurse -Force }
  & git -C $Root archive --format=zip --output=$zip $tag
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $zip -PathType Leaf)) { throw "BASELINE_TAG_ARCHIVE_FAILED: $tag" }
  Expand-Archive -LiteralPath $zip -DestinationPath $source
  $output = Join-Path $outputRoot ($version + '.json')
  $baseline = New-HebriLegacyBaseline -SourceRoot $source -SourceVersion $version -SourceRef $tag -GeneratedAt $generatedAt -OutputPath $output
  if ($baseline.inventory_scope -ne 'release_manifest' -or @($baseline.files | Where-Object { $_.path -eq 'infoHebriHarness.md' }).Count -ne 0) { throw "BASELINE_MANIFEST_AUTHORITY_FAILED: $tag" }
  [void]$results.Add([pscustomobject][ordered]@{
    tag = $tag
    commit = $tagCheck
    generated_at = $baseline.generated_at
    files = @($baseline.files).Count
    tree_sha256 = $baseline.tree_sha256
    source_manifest_sha256 = $baseline.source_manifest_sha256
    output = $output
  })
}

$plan.writes_performed = $true
$plan.results = @($results | ForEach-Object { $_ })
return [pscustomobject]$plan
