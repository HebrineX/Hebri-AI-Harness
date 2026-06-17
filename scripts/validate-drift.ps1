param([string]$Root = (Split-Path -Parent $PSScriptRoot), [switch]$RunNegativeTests)
$ErrorActionPreference = "Stop"
$failures = New-Object System.Collections.Generic.List[string]
function Fail($m){ $failures.Add($m) | Out-Null }
function Txt($rel){ $p=Join-Path $Root $rel; if(!(Test-Path -LiteralPath $p)){ Fail "missing $rel"; return "" }; [IO.File]::ReadAllText($p) }
$version = (Txt "HARNESS_VERSION").Trim()
if($version -ne "0.8.8"){ Fail "HARNESS_VERSION must be 0.8.8" }
$registry = Txt "orquestador/instruction-builder/instruction-registry.yaml"
foreach($needle in @("harness_version: `"0.8.8`"","claude-code","codex","gemini","generic-ai","kernel","preflight","denylists")){ if($registry -notmatch [regex]::Escape($needle)){ Fail "registry missing $needle" } }
foreach($frag in @("kernel","preflight","memory-routing","roles","claude-hooks","denylists")){ [void](Txt "orquestador/instruction-builder/fragments/$frag.md") }
foreach($rel in @("prompts/preset-claude.prompt.md","prompts/preset-codex.prompt.md","prompts/preset-gemini.prompt.md","orquestador/integrations/claude/CLAUDE.template.md")){ $t=Txt $rel; if($t -match "infoHebri[.]md.*(load|cargar como operativo)"){ Fail "$rel loads infoHebri operationally" } }
if($RunNegativeTests){ $bad="HARNESS_VERSION=0.8.6 infoHebri.md load"; if($bad -notmatch "0[.]8[.]6"){ Fail "negative version drift test did not trigger" }; if($bad -notmatch "infoHebri[.]md.*load"){ Fail "negative infoHebri test did not trigger" } }
if($failures.Count){ Write-Host "Strong drift validation failed:"; $failures | ForEach-Object { Write-Host "- $_" }; exit 2 }
Write-Host "OK. Strong drift validation passed."
