param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$failures = New-Object System.Collections.Generic.List[string]
function Fail($m){ $failures.Add($m) | Out-Null }
function P($rel){ Join-Path $Root $rel }
function T($rel){ if(!(Test-Path -LiteralPath (P $rel))){ Fail "missing $rel"; return '' }; [IO.File]::ReadAllText((P $rel)) }
$expected = @('claude-code','codex','gemini','cursor','copilot','qwen','deepseek','generic-ai')
$matrix = T 'orquestador/portability/adapter-matrix.yaml'
foreach($id in $expected){
  if($matrix -notmatch "adapter_id: $([regex]::Escape($id))"){ Fail "adapter matrix missing $id" }
  $yaml = "orquestador/adapters/$id.yaml"
  $md = "orquestador/adapters/$id.md"
  $yt = T $yaml
  [void](T $md)
  foreach($needle in @('harness_version: "0.10.0"','memory_reliability: untrusted_for_evidence','preflight_enforcement: required_before_effects','detractor_senior','first_message','reentry_light','reentry_full','debug_log_intake','compactation_recovery')){
    if($yt -notmatch [regex]::Escape($needle)){ Fail "$yaml missing $needle" }
  }
}
$badPattern = '\beentry[-_ ]?light\b|\breentry full\b|infoHebri[.]md.*(cargar|load)'
foreach($rel in @('orquestador/adapters','prompts')){
  Get-ChildItem -LiteralPath (P $rel) -Recurse -File | ForEach-Object {
    $txt=[IO.File]::ReadAllText($_.FullName)
    if($txt -match $badPattern){ Fail "adapter/preset drift token in $($_.FullName)" }
  }
}
if($failures.Count){ Write-Host 'Adapter drift failed:'; $failures | ForEach-Object { Write-Host "- $_" }; exit 2 }
Write-Host 'OK. Adapter portability drift check passed.'
