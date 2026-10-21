param([string]$Root = (Split-Path -Parent $PSScriptRoot), [switch]$RunNegativeTests)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { Write-Output 'SKIP: Windows-only consumer migration'; return }
$Root = [IO.Path]::GetFullPath($Root)
$temp = Join-Path ([IO.Path]::GetTempPath()) ('hebrinex-consumer-migration-' + [guid]::NewGuid().ToString('N'))
$source = Join-Path $temp 'source'
function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Write-Fixture([string]$Path, [string]$Text) {
  [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
  [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}
function Tree-Hash([string]$Path) {
  $rows = @(Get-ChildItem -LiteralPath $Path -Recurse -Force -File | Sort-Object FullName | ForEach-Object { $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash })
  return ($rows -join "`n")
}
function Reject([scriptblock]$Action, [string]$Pattern, [string]$Context = '') {
  $caught = $false
  $diagnostic = "expected=[$Pattern]; context=[$Context]; action=[$($Action.ToString().Trim())]"
  try { & $Action | Out-Null } catch {
    $caught = $true
    Assert ($_.Exception.Message -match $Pattern) "Unexpected rejection: $($_.Exception.Message); $diagnostic; at=[$($_.ScriptStackTrace)]"
  }
  Assert $caught "Expected rejection did not occur; $diagnostic"
}
function Plan([string]$Project, [string]$Accept = '[]') {
  $timer = [Diagnostics.Stopwatch]::StartNew()
  Write-Host "consumer-migration: project=$(Split-Path -Leaf $Project) stage=checkonly start"
  try { return (& $entry -Root $source -ProjectRoot $Project -CheckOnly -AcceptOverwritePathsJson $Accept | ConvertFrom-Json) }
  finally {
    $timer.Stop()
    Write-Host "consumer-migration: project=$(Split-Path -Leaf $Project) stage=checkonly elapsed_ms=$($timer.ElapsedMilliseconds)"
  }
}
function Approve($Plan, [string]$Authority, [string]$Command = '') {
  if (-not $Command) { $Command = $Plan.command_text }
  # This is a synthetic approval in a disposable bootstrap fixture only.
  $output = @(& $cli approve -Root $Authority -Apply -CommandText $Command *>&1)
  $match = [regex]::Match(($output -join "`n"), 'APR-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{6}')
  Assert $match.Success 'Fixture approval issuance failed'
  return $match.Value
}
try {
  [void][IO.Directory]::CreateDirectory($source)
  # Copy only distribution entries from the clean release fixture provided by the caller.
  foreach ($line in [IO.File]::ReadAllLines((Join-Path $Root 'orquestador/harness-manifest.txt'))) {
    if ($line -notmatch '^file\s+(.+)$') { continue }
    $rel = $Matches[1].Trim()
    Assert ($rel -notmatch '(^|/)\.\.(/|$)|:|^[/\\]' -and $rel -notmatch '(^|/)infoHebri[.]md$') 'Unsafe fixture manifest'
    $from = Join-Path $Root $rel
    if (-not (Test-Path -LiteralPath $from -PathType Leaf)) { continue }
    $to = Join-Path $source $rel
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $to))
    Copy-Item -LiteralPath $from -Destination $to
  }
  foreach ($rel in @('scripts/migrate-consumer.ps1','scripts/validate-consumer-migration.ps1','orquestador/method/consumer-migration.md','orquestador/harness-manifest.txt')) {
    $to = Join-Path $source $rel
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $to))
    Copy-Item -LiteralPath (Join-Path $Root $rel) -Destination $to -Force
  }
  $cli = Join-Path $source 'scripts/hebrinex.ps1'
  $entry = Join-Path $source 'scripts/migrate-consumer.ps1'
  $engineAst = [Management.Automation.Language.Parser]::ParseFile($cli, [ref]$null, [ref]$null)
  $ignoreFunction = $engineAst.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-ConsumerHarnessIgnoreState' }, $false)
  . ([scriptblock]::Create($ignoreFunction.Extent.Text))
  Assert ((Get-ConsumerHarnessIgnoreState ".hebrinex/`n!.hebrinex/`n") -eq 'contradictory') 'Negated exclusion accepted'
  Assert ((Get-ConsumerHarnessIgnoreState ".hebrinex/`n!*`n") -eq 'contradictory') 'Wildcard negation accepted'
  Assert ((Get-ConsumerHarnessIgnoreState "!*`n/.hebrinex/`n") -eq 'ignored') 'Final rooted exclusion rejected'
  Assert ((Get-ConsumerHarnessIgnoreState " .hebrinex/`n") -eq 'missing') 'Leading-space pattern falsely accepted'
  Assert ((Get-ConsumerHarnessIgnoreState ".HEBRINEX/`n") -eq 'missing') 'Case-mismatched Git pattern falsely accepted'
  foreach ($layout in @('canonical','legacy')) {
    Write-Host "consumer-migration: layout=$layout stage=bootstrap"
    $project = Join-Path $temp $layout
    [void][IO.Directory]::CreateDirectory($project)
    $global:LASTEXITCODE = 0
    $bootstrap = @(& $cli bootstrap -Root $source -ProjectRoot $project -Apply *>&1)
    Assert ($LASTEXITCODE -eq 0) ('Bootstrap failed: ' + ($bootstrap -join ' '))
    $authority = Join-Path $project '.hebrinex'
    $bindingFile = Join-Path $authority 'instance/PROJECT_BINDING.yaml'
    Assert (Test-Path -LiteralPath $bindingFile) 'Bootstrap did not create canonical authority'
    $oldVersion = if ($layout -eq 'legacy') { '0.16.0' } else { '0.17.2' }
    $bindingText = [IO.File]::ReadAllText($bindingFile).Replace('0.17.3', $oldVersion)
    Write-Fixture $bindingFile $bindingText
    $versionFile = Join-Path $authority 'HARNESS_VERSION'
    Write-Fixture $versionFile "$oldVersion`n"
    # Keep the synthetic old release metadata coherent for backup restoration.
    foreach ($metadata in @('SHARED_MANIFEST.yaml','orquestador/context-budget.yaml','orquestador/instruction-builder/instruction-registry.yaml','orquestador/migration/contracts/post-migration-contract.yaml','instance/migration/contracts/post-migration-contract.yaml')) {
      $metadataPath = Join-Path $authority $metadata
      if (Test-Path -LiteralPath $metadataPath -PathType Leaf) {
        Write-Fixture $metadataPath ([IO.File]::ReadAllText($metadataPath).Replace('0.17.3', $oldVersion))
      }
    }
    foreach ($pinRelative in @('orquestador/memory/local/session-pin.md','instance/memory/local/session-pin.md')) {
      $pinPath = Join-Path $authority $pinRelative
      if (Test-Path -LiteralPath $pinPath -PathType Leaf) {
        $pinText = [IO.File]::ReadAllText($pinPath)
        Assert ($pinText -match '(?m)^harness_version:') "Fixture pin missing version: $pinRelative"
        $pinText = $pinText -replace '(?m)^harness_version:[^\r\n]*', ('harness_version: "' + $oldVersion + '"')
        $pinText = ($pinText -replace '\r?\n', "`r`n") + "`r`n# fixture custom tail: preserve exactly  `r`n"
        [IO.File]::WriteAllText($pinPath, $pinText, [Text.UTF8Encoding]::new($true, $true))
      }
    }
    Write-Fixture (Join-Path $authority 'orquestador/context/migration-marker.txt') 'legacy value'
    if ($layout -eq 'legacy') {
      Write-Fixture (Join-Path $authority 'PROJECT_BINDING.yaml') $bindingText
      # Verified disposable subtree; no real consumer is removed or migrated.
      Remove-Item -LiteralPath (Join-Path $authority 'instance') -Recurse -Force
    } else {
      $canonicalPin = Join-Path $authority 'instance/memory/local/session-pin.md'
      if (-not (Test-Path -LiteralPath $canonicalPin -PathType Leaf)) {
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $canonicalPin))
        Copy-Item -LiteralPath (Join-Path $authority 'orquestador/memory/local/session-pin.md') -Destination $canonicalPin
      }
      Write-Fixture (Join-Path $authority 'instance/context/migration-marker.txt') 'canonical value'
      Write-Fixture (Join-Path $authority 'instance/README.md') 'custom instance readme'
      Write-Fixture (Join-Path $authority 'instance/mcp/agents-backend.local.yaml') 'local: preserved'
    }
    $effectivePinRelative = if ($layout -eq 'legacy') { 'orquestador/memory/local/session-pin.md' } else { 'instance/memory/local/session-pin.md' }
    $effectivePin = Join-Path $authority $effectivePinRelative
    $oldPinBytes = [IO.File]::ReadAllBytes($effectivePin)
    $strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
    $oldPinText = $strictUtf8.GetString($oldPinBytes)
    $expectedPinBytes = $strictUtf8.GetBytes($oldPinText.Replace(('harness_version: "' + $oldVersion + '"'), 'harness_version: "0.17.3"'))
    Write-Fixture (Join-Path $authority 'orquestador/sdd/progress/approvals/fixture-historical.yaml') "approval_id: fixture-historical`nstatus: expired`n"
    $before = Tree-Hash $project
    $plan = Plan $project
    Assert ((Tree-Hash $project) -ceq $before) 'CheckOnly wrote files'
    $readmePath = Join-Path $authority 'instance/README.md'
    if ($layout -eq 'legacy') {
      Assert (@($plan.adds) -contains 'instance/README.md') 'Missing instance README must be planned'
      try {
        [void][IO.Directory]::CreateDirectory($readmePath)
        Reject { Plan $project } 'Instance README type conflict' 'README directory must block migration'
      } finally {
        Remove-Item -LiteralPath $readmePath
        Remove-Item -LiteralPath (Split-Path -Parent $readmePath)
      }
    } else {
      Assert (@($plan.preserved) -contains 'instance/README.md') 'Existing instance README must be preserved'
    }
    Assert ($plan.from_version -eq $oldVersion -and $plan.to_version -eq '0.17.3') 'Unexpected synthetic migration range'
    Assert (@($plan.metadata_updates).Count -eq 1 -and $plan.metadata_updates[0].source -eq $effectivePinRelative) 'Session pin metadata plan missing'
    Assert (@($plan.approval_imports | Where-Object { $_.destination -eq 'instance/sdd/progress/approvals/fixture-historical.yaml' }).Count -eq 1) 'Approval imports must be disclosed even though excluded from snapshot'
    $ignorePath = Join-Path $project '.gitignore'
    $ignoreBytes = [IO.File]::ReadAllBytes($ignorePath)
    try {
      [IO.File]::AppendAllText($ignorePath, "`n!.hebrinex/`n")
      Reject { Plan $project } 'Contradictory gitignore' 'Negated harness exclusion'
    } finally { [IO.File]::WriteAllBytes($ignorePath, $ignoreBytes) }
    if ($layout -eq 'canonical') {
      & git init --quiet $project
      Assert ($LASTEXITCODE -eq 0) 'Git index fixture initialization failed'
      & git -C $project add --force -- .hebrinex/HARNESS_VERSION
      Assert ($LASTEXITCODE -eq 0) 'Git index fixture staging failed'
      Reject { Plan $project } 'contains tracked files' 'Already tracked harness must block migration'
      & git -C $project rm --cached --quiet -- .hebrinex/HARNESS_VERSION
      Assert ($LASTEXITCODE -eq 0) 'Git index fixture unstaging failed'
      $fixtureGit = [IO.Path]::GetFullPath((Join-Path $project '.git'))
      Assert ($fixtureGit.StartsWith([IO.Path]::GetFullPath($temp) + '\', [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetDirectoryName($fixtureGit) -eq $project -and [IO.Path]::GetFileName($fixtureGit) -eq '.git') 'Unsafe Git fixture cleanup path'
      Remove-Item -LiteralPath $fixtureGit -Recurse -Force
    }
    try {
      [IO.File]::WriteAllBytes($effectivePin, $strictUtf8.GetBytes($oldPinText + "`r`nharness_version: 0.17.3`r`n"))
      Reject { Plan $project } 'session pin requires one unambiguous' "layout=$layout; duplicate pin version"
      [IO.File]::WriteAllBytes($effectivePin, $strictUtf8.GetBytes($oldPinText.Replace('harness_version:', 'previous_version:')))
      Reject { Plan $project } 'session pin requires one unambiguous' "layout=$layout; missing pin version field"
      [IO.File]::WriteAllBytes($effectivePin, $strictUtf8.GetBytes($oldPinText.Replace($oldVersion, '0.15.0')))
      Reject { Plan $project } 'session pin version contradicts' "layout=$layout; contradictory pin version"
    } finally { [IO.File]::WriteAllBytes($effectivePin, $oldPinBytes) }
    $effectiveBinding = if ($layout -eq 'legacy') { Join-Path $authority 'PROJECT_BINDING.yaml' } else { $bindingFile }
    $savedBinding = [IO.File]::ReadAllBytes($effectiveBinding)
    $savedVersion = [IO.File]::ReadAllBytes($versionFile)
    try {
      Write-Fixture $versionFile "0.17.3`n"
      Reject { Plan $project } 'Unsupported, ambiguous or downgrade target version'
      Write-Fixture $effectiveBinding ($bindingText.Replace($oldVersion, '0.17.4'))
      Write-Fixture $versionFile "0.17.4`n"
      Reject { Plan $project } 'Unsupported, ambiguous or downgrade target version'
    } finally {
      [IO.File]::WriteAllBytes($effectiveBinding, $savedBinding)
      [IO.File]::WriteAllBytes($versionFile, $savedVersion)
    }
    Assert ((Tree-Hash $project) -ceq $before) 'Version negatives did not restore fixture bytes'
    foreach ($badPath in @('C:\', '\\server\share\project', ($project + '\..'), ($project + '.'), ($project + ':stream'), ($project + '\CON'))) {
      Reject { & $entry -Root $source -ProjectRoot $badPath -CheckOnly } 'scope|absolute|Ambiguous|reserved' "layout=$layout; badPath=$badPath"
    }
    Write-Fixture (Join-Path $authority 'binding.json') '{}'
    Reject { Plan $project } 'Central-runtime'
    Remove-Item -LiteralPath (Join-Path $authority 'binding.json')
    $lockExample = [IO.File]::ReadAllText((Join-Path $source 'orquestador/sdd/progress/locks/_README.md'))
    Assert ($lockExample -match '(?m)^status: active') 'Expected actual documented active lock example'
    foreach ($lockDir in @('orquestador/sdd/progress/locks','instance/sdd/progress/locks')) {
      $readme = Join-Path $authority ($lockDir + '/_README.md')
      $savedReadme = if (Test-Path -LiteralPath $readme) { [IO.File]::ReadAllBytes($readme) } else { $null }
      $lockFile = Join-Path $authority ($lockDir + '/template-live.lock.md')
      try {
        Write-Fixture $readme $lockExample
        $beforeLocks = Tree-Hash $project
        [void](Plan $project)
        Assert ((Tree-Hash $project) -ceq $beforeLocks) 'Documented lock template must be read-only and non-blocking'
        # A real record whose name contains template must still block.
        Write-Fixture $lockFile "lock_id: L-fixture`nowner_agent_id: fixture`nstatus: active`nexpires_at: 2999-01-01T00:00:00Z`n"
        Reject { Plan $project } 'Active lock'
        Write-Fixture $lockFile "lock_id: L-fixture`nowner_agent_id: fixture`nstatus: active`nexpires_at: 2000-01-01T00:00:00Z`n"
        Reject { Plan $project } 'Active lock'
        Write-Fixture $lockFile "lock_id: L-fixture`nstatus: released`nnotes: status: active is a historical example`n"
        [void](Plan $project)
      } finally {
        if (Test-Path -LiteralPath $lockFile) { Remove-Item -LiteralPath $lockFile }
        if ($null -ne $savedReadme) { [IO.File]::WriteAllBytes($readme, [byte[]]$savedReadme) }
        elseif (Test-Path -LiteralPath $readme) { Remove-Item -LiteralPath $readme }
      }
    }
    Assert (-not $plan.noop) 'Old version must not be noop'
    $accept = ConvertTo-Json -InputObject @($plan.overwrites) -Compress
    $plan = Plan $project $accept
    Assert $plan.acceptance_matches 'Exact overwrite acceptance failed'
    Reject { & $entry -Root $source -ProjectRoot $project -Apply -Snapshot $plan.snapshot -AcceptOverwritePathsJson '[]' } 'overwrite list'
    Reject { & $entry -Root $source -ProjectRoot $project -Apply -Snapshot $plan.snapshot -AcceptOverwritePathsJson $accept } 'ApprovalId required'
    $bad = Approve $plan $authority 'different command'
    Reject { & $entry -Root $source -ProjectRoot $project -Apply -Snapshot $plan.snapshot -AcceptOverwritePathsJson $accept -ApprovalId $bad } 'approval_command_mismatch'
    $id = Approve $plan $authority
    Assert ((Plan $project $accept).snapshot -ceq $plan.snapshot) 'Approval issuance invalidated snapshot'
    Write-Fixture (Join-Path $authority 'orquestador/context/stale.txt') 'changed'
    Reject { & $entry -Root $source -ProjectRoot $project -Apply -Snapshot $plan.snapshot -AcceptOverwritePathsJson $accept -ApprovalId $id } 'Stale'
    Remove-Item -LiteralPath (Join-Path $authority 'orquestador/context/stale.txt')
    $sourceFile = Join-Path $source 'agents/worker.md'
    $original = [IO.File]::ReadAllBytes($sourceFile)
    try {
      [IO.File]::AppendAllText($sourceFile, "`nfixture mutation")
      Reject { & $entry -Root $source -ProjectRoot $project -Apply -Snapshot $plan.snapshot -AcceptOverwritePathsJson $accept -ApprovalId $id } 'Stale'
    } finally { [IO.File]::WriteAllBytes($sourceFile, $original) }
    $currentBinding = if ($layout -eq 'legacy') { Join-Path $authority 'PROJECT_BINDING.yaml' } else { $bindingFile }
    $originalBinding = [IO.File]::ReadAllText($currentBinding)
    try {
      Write-Fixture $currentBinding ($originalBinding -replace '(?m)^project_root:.*$', 'project_root: "C:\wrong-fixture-root"')
      Reject { Plan $project } 'mismatch'
    } finally { Write-Fixture $currentBinding $originalBinding }
    Write-Host "consumer-migration: layout=$layout stage=apply from=$oldVersion to=0.17.3"
    $result = & $entry -Root $source -ProjectRoot $project -Apply -Snapshot $plan.snapshot -AcceptOverwritePathsJson $accept -ApprovalId $id | ConvertFrom-Json
    Assert ($result.status -eq 'applied') 'Apply failed'
    Assert ((Get-FileHash -LiteralPath (Join-Path $authority 'instance/sdd/progress/approvals/fixture-historical.yaml')).Hash -eq (Get-FileHash -LiteralPath (Join-Path $authority 'orquestador/sdd/progress/approvals/fixture-historical.yaml')).Hash) 'Historical approval import changed content'
    $actualPinBytes = [IO.File]::ReadAllBytes((Join-Path $authority 'instance/memory/local/session-pin.md'))
    Assert ([Convert]::ToBase64String($actualPinBytes) -ceq [Convert]::ToBase64String($expectedPinBytes)) 'Pin update changed bytes outside version (BOM/CRLF/custom tail)'
    $pinBackup = @(Get-ChildItem -LiteralPath (Join-Path $authority 'instance/migration/backups') -Directory -Filter 'migration-bound-update-*' | Sort-Object Name)[-1]
    $backedPinBytes = [IO.File]::ReadAllBytes((Join-Path $pinBackup.FullName ('files/' + $effectivePinRelative)))
    Assert ([Convert]::ToBase64String($backedPinBytes) -ceq [Convert]::ToBase64String($oldPinBytes)) 'Backup did not preserve original pin bytes'
    $marker = [IO.File]::ReadAllText((Join-Path $authority 'instance/context/migration-marker.txt'))
    Assert ($marker -eq $(if ($layout -eq 'canonical') { 'canonical value' } else { 'legacy value' })) 'Canonical/legacy preservation failed'
    $expectedReadme = if ($layout -eq 'canonical') { 'custom instance readme' } else { [IO.File]::ReadAllText((Join-Path $source 'instance/README.md')) }
    Assert ([IO.File]::ReadAllText($readmePath) -ceq $expectedReadme) 'Instance README content mismatch'
    if ($layout -eq 'canonical') { Assert ([IO.File]::ReadAllText((Join-Path $authority 'instance/mcp/agents-backend.local.yaml')) -eq 'local: preserved') 'Local configuration lost' }
    $again = Plan $project
    Assert $again.noop 'Content idempotency failed'
    Assert (@($again.metadata_updates).Count -eq 0) 'Current session pin must not have pending metadata changes'
    $canonicalMarker = Join-Path $authority 'instance/context/migration-marker.txt'
    $savedMarker = [IO.File]::ReadAllBytes($canonicalMarker)
    Assert (@($again.imports | Where-Object { $_.destination -eq 'instance/context/migration-marker.txt' }).Count -eq 0) 'Existing canonical marker must not be imported'
    Assert (@($again.preserved) -contains 'instance/context/migration-marker.txt') 'Existing canonical marker must be listed as preserved'
    try {
      Remove-Item -LiteralPath $canonicalMarker
      $missingCanonical = Plan $project
      Assert ($missingCanonical.from_version -eq '0.17.3' -and -not $missingCanonical.noop) 'Same version with missing canonical state must not be noop'
      $markerImports = @($missingCanonical.imports | Where-Object { $_.destination -eq 'instance/context/migration-marker.txt' })
      Assert ($markerImports.Count -eq 1) 'Missing canonical marker must have one import'
      Assert ($markerImports[0].source -eq 'orquestador/context/migration-marker.txt' -and $markerImports[0].sha256 -eq (Get-FileHash -LiteralPath (Join-Path $authority 'orquestador/context/migration-marker.txt')).Hash.ToLowerInvariant()) 'Import must describe source content digest'
      [void][IO.Directory]::CreateDirectory($canonicalMarker)
      Reject { Plan $project } 'Canonical file type conflict' "layout=$layout; canonical marker is a directory"
      Remove-Item -LiteralPath $canonicalMarker
    } finally {
      if (Test-Path -LiteralPath $canonicalMarker -PathType Container) { Remove-Item -LiteralPath $canonicalMarker }
      [IO.File]::WriteAllBytes($canonicalMarker, $savedMarker)
    }
    $pendingLegacy = Join-Path $authority 'orquestador/context/migration-pending/marker.txt'
    try {
      Write-Fixture $pendingLegacy 'pending canonical directory'
      $pending = Plan $project
      Assert (-not $pending.noop -and @($pending.pending_directories) -contains 'instance/context/migration-pending') 'Missing import parent must be planned'
    } finally {
      Remove-Item -LiteralPath $pendingLegacy
      Remove-Item -LiteralPath (Split-Path -Parent $pendingLegacy)
    }
    Assert ((Plan $project).snapshot -ceq $again.snapshot) 'Import negative fixtures did not restore snapshot'
    $id = Approve $again $authority
    $before = Tree-Hash $project
    Write-Host "consumer-migration: layout=$layout stage=noop-apply"
    $result = & $entry -Root $source -ProjectRoot $project -Apply -Snapshot $again.snapshot -ApprovalId $id | ConvertFrom-Json
    Assert ($result.status -eq 'noop' -and (Tree-Hash $project) -ceq $before) 'Noop wrote files'

    # Exercise documented overlay recovery, including its deliberate limitations.
    $backup = @(Get-ChildItem -LiteralPath (Join-Path $authority 'instance/migration/backups') -Directory -Filter 'migration-bound-update-*' | Sort-Object Name)[-1]
    Write-Fixture (Join-Path $authority 'added-after-update.txt') 'overlay keeps additions'
    [IO.File]::AppendAllText((Join-Path $project '.gitignore'), "`n# recovery marker`n")
    $global:LASTEXITCODE = 0
    Write-Host "consumer-migration: layout=$layout stage=recovery backup=$($backup.Name)"
    if ($layout -eq 'canonical') {
      $restored = @(& $cli restore-bound -Root $source -ProjectRoot $project -BackupId $backup.Name -Apply *>&1)
      Assert ($LASTEXITCODE -eq 0) ('Fixture restore failed: ' + ($restored -join ' '))
    } else {
      # Overlay cannot remove canonical state introduced after a legacy backup.
      Reject { & $cli restore-bound -Root $source -ProjectRoot $project -BackupId $backup.Name -Apply *>&1 } 'post migration template must target a supported release' 'Legacy overlay retains new canonical contract and must not claim operational recovery'
      Assert (([IO.File]::ReadAllText($versionFile)).Trim() -eq $oldVersion) 'Legacy overlay did not restore backed-up version'
      Assert (Test-Path -LiteralPath (Join-Path $authority 'instance/PROJECT_BINDING.yaml')) 'Legacy overlay unexpectedly removed canonical additions'
    }
    Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($effectivePin)) -ceq [Convert]::ToBase64String($oldPinBytes)) 'Recovery did not restore original backed-up pin'
    Assert (Test-Path -LiteralPath (Join-Path $authority 'added-after-update.txt')) 'Recovery unexpectedly deleted additions'
    Assert ([IO.File]::ReadAllText((Join-Path $project '.gitignore')) -match 'recovery marker') 'Recovery unexpectedly restored project gitignore'
    Write-Output "PASS: $layout CheckOnly, approvals, stale source/target, binding, Apply, preservation, noop, recovery overlay"
  }
} finally {
  $full = [IO.Path]::GetFullPath($temp)
  $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
  if (-not $full.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $full) -notlike 'hebrinex-consumer-migration-*') { throw 'Unsafe fixture cleanup path' }
  if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Recurse -Force }
}
exit 0
