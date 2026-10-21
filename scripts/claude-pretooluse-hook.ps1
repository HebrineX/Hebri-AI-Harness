# Conservative Claude PreToolUse classifier. Never executes candidate commands.
param(
  [ValidateSet('source_template','legacy_bound','central_instance')][string]$RuntimeMode = 'source_template',
  [string]$InstallRoot = (Split-Path -Parent $PSScriptRoot),
  [string]$ProjectRoot = '',
  [string]$CatalogRoot = ''
)
$ErrorActionPreference = 'Stop'

function Write-HookDecision([string]$Decision, [string]$Reason) {
  @{ hookSpecificOutput = @{
    hookEventName = 'PreToolUse'
    permissionDecision = $Decision
    permissionDecisionReason = $Reason
  } } | ConvertTo-Json -Depth 4 -Compress
}

function Test-PathUnderRoot([string]$FullPath, [string]$RootPath) {
  $comparison = if ([IO.Path]::DirectorySeparatorChar -eq '\') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
  $prefix = $RootPath.TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar
  return $FullPath.Equals($RootPath, $comparison) -or $FullPath.StartsWith($prefix, $comparison)
}

# Inspect ancestors first, never through a junction or symlink.
function Test-ExistingPlainPath([string]$FullPath) {
  try {
    $anchor = [IO.Path]::GetPathRoot($FullPath)
    if ([string]::IsNullOrWhiteSpace($anchor)) { return $false }
    $current = $anchor
    if (([IO.File]::GetAttributes($current) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
    foreach ($part in ($FullPath.Substring($anchor.Length) -split '[\\/]')) {
      if ($part.Length -eq 0) { continue }
      $current = [IO.Path]::Combine($current, $part)
      if (([IO.File]::GetAttributes($current) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
    }
    return $true
  } catch { return $false }
}

function Get-LiteralFullPath([string]$PathText, [string]$BasePath) {
  if ([string]::IsNullOrWhiteSpace($PathText) -or $PathText -match '[*?\[\]~\x00-\x1f]' -or $PathText -match '^[\\/]{2}') { throw 'Unsupported path' }
  # Do not normalize away an uninspected ancestor or a Windows filename alias.
  foreach ($part in ($PathText -split '[\\/]')) {
    if ($part -eq '..') { throw 'Parent traversal' }
    if ([IO.Path]::DirectorySeparatorChar -eq '\' -and $part -ne '.' -and $part -match '[. ]$') { throw 'Ambiguous Windows path' }
  }
  if ([IO.Path]::DirectorySeparatorChar -eq '\') {
    if ($PathText.Contains(':') -and $PathText -notmatch '^[A-Za-z]:[\\/][^:]*$') { throw 'Provider or drive-relative path' }
    if ($PathText -match '^[\\/]' ) { throw 'Drive-relative path' }
  } elseif ($PathText.Contains(':') -or $PathText.Contains('\')) { throw 'Provider or non-native path' }
  if (-not [IO.Path]::IsPathRooted($PathText)) { $PathText = [IO.Path]::Combine($BasePath, $PathText) }
  return [IO.Path]::GetFullPath($PathText)
}

# Parse only the policy's flat quoted lists, rejecting unsupported formats.
function Get-HookPolicyList([string]$Text, [string]$Key) {
  $match = [regex]::Match($Text, '(?m)^' + [regex]::Escape($Key) + ':\s*\r?\n((?:[ \t]+-[^\r\n]*\r?\n?)*)')
  if (-not $match.Success) { throw 'Missing policy list' }
  $items = @()
  foreach ($line in ($match.Groups[1].Value -split '\r?\n')) {
    if (-not $line.Trim()) { continue }
    if ($line -notmatch '^\s+-\s+"([^"]+)"\s*$') { throw 'Unsupported policy list' }
    $items += $Matches[1]
  }
  return $items
}

function Get-HostReadOnlyPolicy([string]$HarnessRoot) {
  $texts = @()
  foreach ($relative in @('orquestador/security/command-risk-registry.yaml','orquestador/security/secrets-policy.yaml')) {
    $path = Get-LiteralFullPath $relative $HarnessRoot
    if (-not (Test-ExistingPlainPath $path)) { throw 'Policy path unavailable' }
    $texts += [IO.File]::ReadAllText($path)
  }
  return @{
    Enabled = $texts[0] -match '(?m)^host_read_only:\s*\r?\n[ \t]+enabled: true\s*$'
    Commands = @(Get-HookPolicyList $texts[0] 'host_read_only_commands')
    BlockedPatterns = @(Get-HookPolicyList $texts[0] 'blocked_patterns')
    SecretGlobs = @(@(Get-HookPolicyList $texts[1] 'secret_bearing_paths') + @(Get-HookPolicyList $texts[0] 'host_read_only_secret_globs'))
  }
}

function Test-SecretPath([string]$FullPath, [string[]]$SecretGlobs) {
  foreach ($part in ($FullPath -split '[\\/]')) {
    foreach ($glob in $SecretGlobs) { if ($part -like $glob) { return $true } }
    if ($part -in @('.ssh','.aws','.azure','.kube','.gnupg','infoHebri.md')) { return $true }
  }
  return $false
}

function Test-HostReadOnlyCommand([string]$CommandText, [string]$Shell, [string]$Cwd, [string]$ProjectRootPath, [hashtable]$Policy) {
  $verdict = @{ ReadOnly = $false; Reason = 'not_proven_read_only'; Summary = '' }
  if ($Shell -cne 'PowerShell' -or -not $Policy.Enabled) { return $verdict }
  try {
    if ($CommandText -match '[\r\n;\x60]' ) { return $verdict }
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($CommandText, [ref]$tokens, [ref]$errors)
    if ($errors.Count -ne 0 -or $ast.ParamBlock -or $ast.BeginBlock -or $ast.ProcessBlock -or -not $ast.EndBlock -or $ast.EndBlock.Statements.Count -ne 1 -or $ast.EndBlock.Traps.Count -ne 0) { return $verdict }
    foreach ($token in $tokens) { if ($token.Kind -eq 'Comment') { return $verdict } }
    $pipeline = $ast.EndBlock.Statements[0]
    if ($pipeline.Extent.Text -cne $CommandText.Trim()) { return $verdict }
    if ($pipeline -isnot [System.Management.Automation.Language.PipelineAst] -or $pipeline.PipelineElements.Count -ne 1 -or $pipeline.Background) { return $verdict }
    $command = $pipeline.PipelineElements[0]
    if ($command -isnot [System.Management.Automation.Language.CommandAst] -or $command.InvocationOperator -ne 'Unknown' -or $command.Redirections.Count -ne 0) { return $verdict }
    $elements = $command.CommandElements
    $name = $command.GetCommandName()
    if ($elements[0] -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -or $elements[0].StringConstantType -ne 'BareWord') { return $verdict }
    # A separate hook process cannot prove command resolution in the host runspace.
    # Require the platform module, never a bare name that a function/alias can shadow.
    $modulePrefix = 'Microsoft.PowerShell.Management\'
    if (-not $name.StartsWith($modulePrefix, [StringComparison]::OrdinalIgnoreCase) -or $name -notin $Policy.Commands) { return $verdict }
    $name = $name.Substring($modulePrefix.Length)
    if ($name -notin @('Get-Content','Get-ChildItem','Test-Path','Get-Item')) { return $verdict }
    $pathText = $null
    $seen = @{}
    for ($i = 1; $i -lt $elements.Count; $i++) {
      $element = $elements[$i]
      if ($element -isnot [System.Management.Automation.Language.CommandParameterAst] -or $element.Argument) { return $verdict }
      $flag = $element.ParameterName
      if ($seen.ContainsKey($flag)) { return $verdict }
      $seen[$flag] = $true
      if ($flag -eq 'Raw' -and $name -eq 'Get-Content') { continue }
      if ($flag -ne 'LiteralPath' -or ++$i -ge $elements.Count) { return $verdict }
      $value = $elements[$i]
      if ($value -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) { return $verdict }
      $pathText = $value.Value
    }
    if ($null -eq $pathText) { return $verdict }
    $root = Get-LiteralFullPath $ProjectRootPath ([Environment]::CurrentDirectory)
    $cwdFull = Get-LiteralFullPath $Cwd ([Environment]::CurrentDirectory)
    if (-not (Test-PathUnderRoot $cwdFull $root)) { return $verdict }
    if (-not (Test-ExistingPlainPath $root) -or -not [IO.Directory]::Exists($root) -or -not (Test-ExistingPlainPath $cwdFull) -or -not [IO.Directory]::Exists($cwdFull)) { return $verdict }
    $target = Get-LiteralFullPath $pathText $cwdFull
    if (-not (Test-PathUnderRoot $target $root) -or (Test-SecretPath $target $Policy.SecretGlobs)) { return $verdict }
    if (-not (Test-ExistingPlainPath $target)) { return $verdict }
    if ($name -eq 'Get-Content' -and -not [IO.File]::Exists($target)) { return $verdict }
    $verdict.ReadOnly = $true
    $verdict.Reason = 'literal_read_only'
    $verdict.Summary = $name
  } catch { $verdict.Reason = 'classifier_error' }
  return $verdict
}

try {
  $raw = [Console]::In.ReadToEnd()
  if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
  $payload = $raw | ConvertFrom-Json
  if ($payload.tool_name -cnotin @('Bash','PowerShell')) { exit 0 }
  $text = [string]$payload.tool_input.command
  if ([string]::IsNullOrWhiteSpace($text)) { exit 0 }
  $harnessRoot = Get-LiteralFullPath $InstallRoot (Get-Location).Path
  $policy = Get-HostReadOnlyPolicy $harnessRoot
  # Ask even for quoted occurrences. Never infer safety by stripping shell quotes.
  foreach ($pattern in $policy.BlockedPatterns) {
    if ($text.IndexOf($pattern, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
      Write-HookDecision 'ask' 'Blocked pattern: explicit operator SI required.'
      exit 0
    }
  }
  # No binding/catalog resolver may silently substitute the caller's root.
  $scopeRoot = $ProjectRoot
  if ([string]::IsNullOrWhiteSpace($scopeRoot)) { $scopeRoot = $env:CLAUDE_PROJECT_DIR }
  if ([string]::IsNullOrWhiteSpace($scopeRoot)) { exit 0 }
  $scopeRoot = Get-LiteralFullPath $scopeRoot (Get-Location).Path
  $cwd = [string]$payload.cwd
  if ([string]::IsNullOrWhiteSpace($cwd)) { exit 0 }
  $verdict = Test-HostReadOnlyCommand $text ([string]$payload.tool_name) $cwd $scopeRoot $policy
  if ($verdict.ReadOnly) { Write-HookDecision 'allow' 'Scoped literal PowerShell read; host perimeter restrictions still apply.' }
} catch {
  # Defer on uncertainty; errors and Gateway results never imply approval.
}
