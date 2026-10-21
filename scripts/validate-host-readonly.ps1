# Focused hook tests: trusted function ASTs plus actual stdin JSON roundtrips.
param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
$hookPath = Join-Path $Root 'scripts/claude-pretooluse-hook.ps1'
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($hookPath, [ref]$null, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'Hook parse errors' }
foreach ($definition in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
  . ([scriptblock]::Create($definition.Extent.Text))
}
$policy = Get-HostReadOnlyPolicy $Root
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('hebrinex-hook-' + [guid]::NewGuid().ToString('N'))
$project = Join-Path $fixture 'project'
$link = Join-Path $project 'linked'
$count = 0
$linkCreated = $false

function Assert-Read([string]$Command, [bool]$Expected, [string]$Shell = 'PowerShell', [string]$Cwd = $project, [string]$Scope = $project) {
  $actual = Test-HostReadOnlyCommand $Command $Shell $Cwd $Scope $policy
  if ($actual.ReadOnly -ne $Expected) { throw "Unexpected classification ($($actual.Reason)): $Command" }
  $script:count++
}

function Invoke-HookPayload([string]$Payload, [string]$Scope = $project) {
  $exe = (Get-Process -Id $PID).Path
  $start = New-Object System.Diagnostics.ProcessStartInfo
  $start.FileName = $exe
  $start.Arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $hookPath + '" -InstallRoot "' + $Root + '" -ProjectRoot "' + $Scope + '"'
  $start.UseShellExecute = $false
  $start.CreateNoWindow = $true
  $start.RedirectStandardInput = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $start
  try {
    [void]$process.Start()
    $process.StandardInput.Write($Payload)
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(15000)) { $process.Kill(); throw 'Hook timed out' }
    $result = $stdout.GetAwaiter().GetResult()
    $errorText = $stderr.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0 -or $errorText) { throw "Hook process failed: $errorText" }
    return $result.Trim()
  } finally { $process.Dispose() }
}

try {
  [void](New-Item -ItemType Directory -Path $project)
  [IO.File]::WriteAllText((Join-Path $project 'sample.txt'), 'fixture')
  [IO.File]::WriteAllText((Join-Path $project 'space name.txt'), 'fixture')
  [IO.File]::WriteAllText((Join-Path $fixture 'outside.txt'), 'outside fixture')
  [IO.File]::WriteAllText((Join-Path $project '.env'), 'synthetic fixture')
  [void](New-Item -ItemType Directory -Path (Join-Path $project 'credentials'))
  [IO.File]::WriteAllText((Join-Path $project 'credentials/data.txt'), 'synthetic fixture')
  foreach ($command in @(
    "Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath 'sample.txt'",
    "Microsoft.PowerShell.Management\Get-Content -LiteralPath 'space name.txt' -Raw",
    'Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath .',
    'Microsoft.PowerShell.Management\Test-Path -LiteralPath sample.txt',
    'Microsoft.PowerShell.Management\Get-Item -LiteralPath sample.txt',
    'Microsoft.PowerShell.Management\get-content -literalpath sample.txt'
  )) { Assert-Read $command $true }
  foreach ($command in @(
    'Get-Content -Raw -LiteralPath sample.txt',
    'Get-ChildItem -LiteralPath .',
    'Test-Path -LiteralPath sample.txt',
    'Get-Item -LiteralPath sample.txt',
    'Microsoft.PowerShell.Management\Get-Content sample.txt',
    'gc -LiteralPath sample.txt',
    'Microsoft.PowerShell.Management\Get-Content -Path sample.txt',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt -Wait',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt -Stream data',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt -OutVariable leak',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt -ErrorAction Ignore',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt -TotalCount 1',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt -UnknownFlag',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt -Raw -Raw',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt -LiteralPath sample.txt',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath:sample.txt',
    'Microsoft.PowerShell.Management\Get-Content -Lit sample.txt',
    'Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath . -Recurse',
    'Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath . -Force',
    'Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath . -Raw',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt > output.txt',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt 2>$null',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt | Out-Null',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt; Microsoft.PowerShell.Management\Get-Item -LiteralPath sample.txt',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt && Microsoft.PowerShell.Management\Get-Item -LiteralPath sample.txt',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt &',
    '& Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt',
    '. Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt',
    '{ Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt }',
    '$(Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt)',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath $env:HOME',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath "$(Get-Location)/sample.txt"',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath @("sample.txt")',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt,outside.txt',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath *.txt',
    "Microsoft.PowerShell.Management\Get-Content -LiteralPath '[sample].txt'",
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath env:',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath env:HOME',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath FileSystem::sample.txt',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath C:sample.txt',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt:stream',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath ../outside.txt',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath linked/../sample.txt',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath missing.txt',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath .env',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath credentials/data.txt',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath .',
    'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt # comment',
    'git status --short',
    'Get-FileHash -LiteralPath sample.txt'
  )) { Assert-Read $command $false }
  Assert-Read 'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt' $false 'Bash'
  Assert-Read 'cat sample.txt' $false 'Bash'
  Assert-Read 'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt' $false 'PowerShell' $fixture
  Assert-Read ("Microsoft.PowerShell.Management\Get-Content -LiteralPath '" + (Join-Path $fixture 'outside.txt') + "'") $false
  Assert-Read ("Microsoft.PowerShell.Management\Get-Content -LiteralPath '" + (Join-Path $project 'sample.txt') + "'") $true
  $policy.Enabled = $false
  Assert-Read 'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt' $false
  $policy.Enabled = $true

  # Case is a containment boundary on Unix; Windows uses case-insensitive paths.
  $upper = $project.ToUpperInvariant()
  if ([IO.Path]::DirectorySeparatorChar -eq '\') {
    Assert-Read 'Microsoft.PowerShell.Management\Test-Path -LiteralPath sample.txt' $true 'PowerShell' $upper $project
  } else {
    if (Test-PathUnderRoot $upper $project) { throw 'Unix containment must be case-sensitive' }
    $count++
  }
  try {
    $kind = if ([IO.Path]::DirectorySeparatorChar -eq '\') { 'Junction' } else { 'SymbolicLink' }
    [void](New-Item -ItemType $kind -Path $link -Target $fixture)
    $linkCreated = $true
  } catch { Write-Warning ('SKIP: host could not create link fixture; link coverage pending: ' + $_.Exception.Message) }
  if ($linkCreated) {
    Assert-Read 'Microsoft.PowerShell.Management\Get-Content -LiteralPath linked/outside.txt' $false
    Assert-Read 'Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath linked' $false
    Assert-Read 'Microsoft.PowerShell.Management\Test-Path -LiteralPath outside.txt' $false 'PowerShell' $link $link
  }

  foreach ($case in @(
    @('PowerShell', 'Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath sample.txt', 'allow'),
    @('PowerShell', 'Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath .', 'allow'),
    @('PowerShell', 'Microsoft.PowerShell.Management\Get-Content -LiteralPath sample.txt > out.txt', ''),
    @('Bash', 'git status --short', ''),
    @('Bash', 'git push origin main', 'ask'),
    @('PowerShell', 'Microsoft.PowerShell.Management\Get-Content -LiteralPath "git push"', 'ask')
  )) {
    $payload = @{ tool_name = $case[0]; cwd = $project; tool_input = @{ command = $case[1] } } | ConvertTo-Json -Compress -Depth 4
    $output = Invoke-HookPayload $payload
    $decision = if ($output) { ($output | ConvertFrom-Json).hookSpecificOutput.permissionDecision } else { '' }
    if ($decision -ne $case[2]) { throw "stdin roundtrip mismatch: $($case[1]) -> $decision" }
    $count++
  }
  if (Invoke-HookPayload '{malformed') { throw 'Malformed payload must defer' }
  $count++
  $payload = @{ tool_name = 'PowerShell'; cwd = $fixture; tool_input = @{ command = 'Microsoft.PowerShell.Management\Get-Content -LiteralPath outside.txt' } } | ConvertTo-Json -Compress -Depth 4
  if (Invoke-HookPayload $payload) { throw 'Explicit root must not be replaced by payload cwd' }
  $count++
  Write-Output "Host readonly validation OK: $count checks; PS $($PSVersionTable.PSVersion); link=$linkCreated"
} finally {
  # Remove the link itself first; never recursively traverse its target.
  if ($linkCreated) { [IO.Directory]::Delete($link) }
  $expectedParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char[]]'\/')
  $resolvedFixture = [IO.Path]::GetFullPath($fixture)
  if ([IO.Path]::GetDirectoryName($resolvedFixture) -ne $expectedParent -or [IO.Path]::GetFileName($resolvedFixture) -notmatch '^hebrinex-hook-[a-f0-9]{32}$') { throw 'Unsafe fixture cleanup path' }
  if ([IO.Directory]::Exists($resolvedFixture)) { Remove-Item -LiteralPath $resolvedFixture -Recurse -Force }
}
