#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
MANIFEST="$ROOT/orquestador/harness-manifest.txt"
require_grep(){ pattern="$1"; file="$2"; message="$3"; if ! grep -q "$pattern" "$file"; then echo "ERROR: $message"; exit 2; fi; }
check_registry_paths(){
  registry="$1"
  [ -f "$ROOT/$registry" ] || { echo "ERROR: Falta registry $registry"; exit 2; }
  grep -E '^[[:space:]]*(-[[:space:]]+|path:[[:space:]]+)(agents|orquestador|prompts|scripts)/|^[[:space:]]*(-[[:space:]]+|path:[[:space:]]+)(README[.]md|CHANGELOG[.]md|HARNESS_VERSION|PROGRESS[.]md|PROJECT_BINDING[.]yaml|init[.]sh)' "$ROOT/$registry" | sed -E 's/^[[:space:]]*-[[:space:]]+//; s/^[[:space:]]*path:[[:space:]]+//; s/[[:space:]]+$//' | while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    case "$rel" in *\** ) continue ;; esac
    [ -e "$ROOT/$rel" ] || { echo "ERROR: $registry referencia ruta inexistente: $rel"; exit 2; }
  done
}
estimate_tokens_for_files(){ total_chars=0; for rel in "$@"; do if [ -f "$ROOT/$rel" ]; then chars="$(wc -c < "$ROOT/$rel" | tr -d ' ')"; total_chars=$((total_chars + chars)); fi; done; echo $(((total_chars + 3) / 4)); }
check_context_budget(){ name="$1"; max="$2"; shift 2; used="$(estimate_tokens_for_files "$@")"; hard=$((max * 2)); if [ "$used" -gt "$hard" ]; then echo "ERROR: Presupuesto de contexto excede limite duro para $name: $used > $hard tokens estimados (soft $max)"; exit 2; fi; if [ "$used" -gt "$max" ]; then echo "WARN: Presupuesto de contexto excedido para $name: $used > $max tokens estimados (limite duro $hard)"; fi; }
get_binding_value(){ key="$1"; sed -n "s/^$key:[[:space:]]*//p" "$ROOT/PROJECT_BINDING.yaml" | head -n 1 | sed 's/^"//; s/"$//; s/\r$//'; }
normalize_path(){ path="$1"; if [ -z "$path" ]; then printf '%s\n' ""; return 0; fi; if command -v cygpath >/dev/null 2>&1; then cygpath -u "$path" 2>/dev/null || printf '%s\n' "$path"; else printf '%s\n' "$path"; fi; }
resolve_powershell(){
  if command -v pwsh >/dev/null 2>&1; then printf '%s\n' "pwsh"; return 0; fi
  if command -v powershell.exe >/dev/null 2>&1; then printf '%s\n' "powershell.exe"; return 0; fi
  if command -v powershell >/dev/null 2>&1; then printf '%s\n' "powershell"; return 0; fi
  echo "ERROR: No se encontro pwsh ni powershell.exe/powershell en PATH"; exit 127
}
PSH="$(resolve_powershell)"
echo "Verificando estructura del Hebri-AI-Harness..."
[ -s "$MANIFEST" ] || { echo "ERROR: Falta el manifiesto orquestador/harness-manifest.txt"; exit 2; }
HARNESS_RELEASE_VERSION="$(tr -d '\r\n' < "$ROOT/HARNESS_VERSION")"
printf '%s' "$HARNESS_RELEASE_VERSION" | grep -Eq '^0[.][0-9]+[.][0-9]+$' || { echo "ERROR: HARNESS_VERSION no es SemVer 0.x.y"; exit 2; }
if grep -q '^file infoHebri[.]md$' "$MANIFEST"; then echo "ERROR: infoHebri.md no debe figurar en el manifest"; exit 2; fi
while IFS= read -r line || [ -n "$line" ]; do entry="$(printf '%s' "$line" | sed 's/[[:space:]]*$//')"; case "$entry" in ""|\#*) continue ;; esac; kind="${entry%% *}"; path="${entry#* }"; [ "$kind" != "$path" ] || { echo "ERROR: Entrada invalida en manifest: $entry"; exit 2; }; case "$kind" in dir) [ -d "$ROOT/$path" ] || { echo "ERROR: Falta el directorio $path"; exit 2; };; file) [ -f "$ROOT/$path" ] || { echo "ERROR: Falta el archivo $path"; exit 2; }; [ -s "$ROOT/$path" ] || { echo "ERROR: Archivo vacio $path"; exit 2; };; *) echo "ERROR: Tipo invalido en manifest: $kind"; exit 2;; esac; done < "$MANIFEST"
BINDING_MODE="$(get_binding_value binding_mode)"; PROJECT_ROOT_RAW="$(get_binding_value project_root)"; HARNESS_BINDING_VERSION="$(get_binding_value harness_version)"
[ "$BINDING_MODE" = "source_template" ] || [ "$BINDING_MODE" = "bound" ] || { echo "ERROR: PROJECT_BINDING.yaml binding_mode invalido: $BINDING_MODE"; exit 2; }
[ "$HARNESS_BINDING_VERSION" = "$HARNESS_RELEASE_VERSION" ] || { echo "ERROR: PROJECT_BINDING.yaml no declara harness_version $HARNESS_RELEASE_VERSION"; exit 2; }
if [ "$BINDING_MODE" = "bound" ]; then [ -n "$PROJECT_ROOT_RAW" ] || { echo "ERROR: PROJECT_BINDING.yaml bound requiere project_root"; exit 2; }; [ "$(basename "$ROOT")" = ".hebrinex" ] || { echo "ERROR: Un harness bound debe vivir en <project_root>/.hebrinex"; exit 2; }; ACTUAL_PROJECT_ROOT="$(CDPATH= cd -- "$ROOT/.." && pwd)"; EXPECTED_PROJECT_ROOT="$(normalize_path "$PROJECT_ROOT_RAW")"; [ "$EXPECTED_PROJECT_ROOT" = "$ACTUAL_PROJECT_ROOT" ] || { echo "ERROR: PROJECT_BINDING mismatch"; exit 2; }; [ ! -f "$ROOT/infoHebri.md" ] || { echo "ERROR: infoHebri.md no debe existir dentro de un harness bound"; exit 2; }; fi
echo "Binding: $BINDING_MODE"; echo "Harness path: $ROOT"; [ -z "$PROJECT_ROOT_RAW" ] || echo "Project root: $(normalize_path "$PROJECT_ROOT_RAW")"
check_operational_version_drift(){
  failed=0
  for pattern in \
    "HARNESS_VERSION" \
    "PROJECT_BINDING.yaml" \
    "AGENTS.md" \
    "README.md" \
    "orquestador/context-budget.yaml" \
    "orquestador/instruction-builder/instruction-registry.yaml" \
    "orquestador/memory/local/session-pin.md" \
    "orquestador/runtime/active-session.template.json" \
    "orquestador/runtime/schemas/active-session.schema.json" \
    "orquestador/portability/*.yaml" \
    "orquestador/adapters/*.yaml" \
    "orquestador/policies/schemas/*.yaml" \
    "orquestador/sdd/progress/templates/*.yaml" \
    "prompts/adapters/preset-*.prompt.md" \
    "prompts/bootstrap/primer-mensaje-harness.prompt.md" \
    "prompts/session/reentry-liviano.prompt.md" \
    "prompts/session/usuario-contrato-reentry.prompt.md"; do
    for file in "$ROOT"/$pattern; do
      [ -f "$file" ] || continue
      if grep -E 'harness_version:[[:space:]]*"?0[.]8[.][0-9]([^0-9]|$)|Version operativa esperada:[[:space:]]*0[.]8[.][0-9]([^0-9]|$)|Referencia operativa actual:[^0-9]*0[.]8[.][0-9]([^0-9]|$)|const[[:space:]]*[:=][[:space:]]*"0[.]8[.][0-9]([^0-9]|$)"' "$file" >/dev/null 2>&1; then
        echo "ERROR: Drift de version operativa antigua en ${file#$ROOT/}"
        grep -nE 'harness_version:[[:space:]]*"?0[.]8[.][0-9]([^0-9]|$)|Version operativa esperada:[[:space:]]*0[.]8[.][0-9]([^0-9]|$)|Referencia operativa actual:[^0-9]*0[.]8[.][0-9]([^0-9]|$)|const[[:space:]]*[:=][[:space:]]*"0[.]8[.][0-9]([^0-9]|$)"' "$file" || true
        failed=1
      fi
    done
  done
  [ "$failed" -eq 0 ] || exit 2
}
check_operational_version_drift
if grep -R --exclude-dir=backups "\.hebrinex/policies" "$ROOT/AGENTS.md" "$ROOT/orquestador" >/dev/null 2>&1; then echo "ERROR: Ruta obsoleta detectada: .hebrinex/policies"; exit 2; fi
if grep -R --exclude-dir=backups "\.hebrinex/orquestador/sdd/\.hebrinex" "$ROOT/agents" "$ROOT/prompts" >/dev/null 2>&1; then echo "ERROR: Ruta canonica duplicada detectada"; exit 2; fi
require_grep "$HARNESS_RELEASE_VERSION" "$ROOT/HARNESS_VERSION" "HARNESS_VERSION no declara $HARNESS_RELEASE_VERSION"
require_grep "schema: hebrinex.context_budget" "$ROOT/orquestador/context-budget.yaml" "context-budget.yaml no define schema"
require_grep "context_budget" "$ROOT/orquestador/memory/local/session-pin.md" "session-pin.md no declara context_budget"
require_grep "memory-closure-checklist.md" "$ROOT/orquestador/method/memory-layer-policy.md" "memory-layer-policy.md no exige cierre de memoria"
require_grep "memory-closure-checklist.md" "$ROOT/orquestador/method/final-report-evidence-policy.md" "final-report-evidence-policy.md no exige memory closure checklist"
require_grep "memory-closure-checklist.md" "$ROOT/orquestador/harness-manifest.txt" "manifest no incluye memory closure checklist"
require_grep "orquestador/registry-index.yaml" "$ROOT/orquestador/harness-manifest.txt" "registry-index.yaml no esta en manifest"
require_grep "orquestador/prompt-registry.yaml" "$ROOT/orquestador/harness-manifest.txt" "prompt-registry.yaml no esta en manifest"
require_grep "orquestador/agents/agent-registry.yaml" "$ROOT/orquestador/harness-manifest.txt" "agent-registry.yaml no esta en manifest"
require_grep "orquestador/agents/capability-registry.yaml" "$ROOT/orquestador/harness-manifest.txt" "capability-registry.yaml no esta en manifest"
require_grep "orquestador/agents/lifecycle-registry.yaml" "$ROOT/orquestador/harness-manifest.txt" "lifecycle-registry.yaml no esta en manifest"
require_grep "orquestador/security/permission-registry.yaml" "$ROOT/orquestador/harness-manifest.txt" "permission-registry.yaml no esta en manifest"
require_grep "orquestador/security/threat-model.yaml" "$ROOT/orquestador/harness-manifest.txt" "threat-model.yaml no esta en manifest"
require_grep "orquestador/migration/migration-registry.yaml" "$ROOT/orquestador/harness-manifest.txt" "migration-registry.yaml no esta en manifest"
require_grep "orquestador/migration/contracts/post-migration-contract.yaml" "$ROOT/orquestador/harness-manifest.txt" "post-migration-contract.yaml no esta en manifest"
require_grep "orquestador/agents/agent-registry.yaml" "$ROOT/orquestador/registry-index.yaml" "registry-index no incluye agent-registry"
require_grep "orquestador/security/permission-registry.yaml" "$ROOT/orquestador/registry-index.yaml" "registry-index no incluye security permission registry"
require_grep "orquestador/migration/migration-registry.yaml" "$ROOT/orquestador/registry-index.yaml" "registry-index no incluye migration registry"
require_grep "schema: hebrinex.prompt_registry" "$ROOT/orquestador/prompt-registry.yaml" "prompt-registry.yaml no define schema"
require_grep "prompts/roles" "$ROOT/orquestador/prompt-registry.yaml" "prompt-registry no declara prompts de roles"
require_grep "prompts/migration" "$ROOT/orquestador/prompt-registry.yaml" "prompt-registry no declara prompts de migracion"
for registry in \
  "orquestador/registry-index.yaml" \
  "orquestador/prompt-registry.yaml" \
  "orquestador/adapter-registry.yaml" \
  "orquestador/context-profile-registry.yaml" \
  "orquestador/gate-registry.yaml" \
  "orquestador/policy-registry.yaml" \
  "orquestador/template-registry.yaml"; do
  require_grep "schema: hebrinex" "$ROOT/$registry" "$registry no define schema hebrinex"
  check_registry_paths "$registry"
done
require_grep "scripts/validate-harness.ps1" "$ROOT/orquestador/harness-manifest.txt" "validate-harness.ps1 no esta en manifest"
require_grep "scripts/validate-agent-contracts.ps1" "$ROOT/orquestador/harness-manifest.txt" "validate-agent-contracts.ps1 no esta en manifest"
require_grep "scripts/validate-security-policy.ps1" "$ROOT/orquestador/harness-manifest.txt" "validate-security-policy.ps1 no esta en manifest"
require_grep "scripts/validate-migration.ps1" "$ROOT/orquestador/harness-manifest.txt" "validate-migration.ps1 no esta en manifest"
require_grep "scripts/audit-harness.ps1" "$ROOT/orquestador/harness-manifest.txt" "audit-harness.ps1 no esta en manifest"
require_grep "scripts/migrate-harness.ps1" "$ROOT/orquestador/harness-manifest.txt" "migrate-harness.ps1 no esta en manifest"
require_grep "scripts/validate-release.ps1" "$ROOT/orquestador/harness-manifest.txt" "validate-release.ps1 no esta en manifest"
require_grep "scripts/validate-cli.ps1" "$ROOT/orquestador/harness-manifest.txt" "validate-cli.ps1 no esta en manifest"
require_grep "scripts/validate-bootstrap.ps1" "$ROOT/orquestador/harness-manifest.txt" "validate-bootstrap.ps1 no esta en manifest"
require_grep "scripts/validate-bound-update.ps1" "$ROOT/orquestador/harness-manifest.txt" "validate-bound-update.ps1 no esta en manifest"
require_grep "scripts/validate-bound-backups.ps1" "$ROOT/orquestador/harness-manifest.txt" "validate-bound-backups.ps1 no esta en manifest"
require_grep "scripts/validate-bound-restore.ps1" "$ROOT/orquestador/harness-manifest.txt" "validate-bound-restore.ps1 no esta en manifest"
require_grep "project-binding.schema.yaml" "$ROOT/orquestador/harness-manifest.txt" "schema project-binding no esta en manifest"
require_grep "context-budget.schema.yaml" "$ROOT/orquestador/harness-manifest.txt" "schema context-budget no esta en manifest"
require_grep "memory-registry.schema.yaml" "$ROOT/orquestador/harness-manifest.txt" "schema memory-registry no esta en manifest"
require_grep "registry.schema.yaml" "$ROOT/orquestador/harness-manifest.txt" "schema registry no esta en manifest"
require_grep "RunNegativeTests" "$ROOT/scripts/validate-harness.ps1" "validate-harness.ps1 no expone pruebas negativas"
require_grep "agents/_schema.md" "$ROOT/orquestador/harness-manifest.txt" "agent schema no esta en manifest"
require_grep "agents/detractor-senior.md" "$ROOT/orquestador/harness-manifest.txt" "detractor senior agent no esta en manifest"
require_grep "minimal-implementation-policy.md" "$ROOT/orquestador/harness-manifest.txt" "minimal implementation policy no esta en manifest"
require_grep "detractor-senior-checklist.md" "$ROOT/orquestador/harness-manifest.txt" "detractor-senior-checklist.md no esta en manifest"
require_grep "prompts/audit/detractor-senior.prompt.md" "$ROOT/orquestador/harness-manifest.txt" "detractor senior prompt no esta en manifest"
require_grep "orquestador/portability/core-skills.yaml" "$ROOT/orquestador/harness-manifest.txt" "portability core no esta en manifest"
require_grep "orquestador/portability/adapter-matrix.yaml" "$ROOT/orquestador/harness-manifest.txt" "adapter matrix no esta en manifest"
require_grep "orquestador/adapters/claude-code.yaml" "$ROOT/orquestador/harness-manifest.txt" "adapter yaml claude no esta en manifest"
require_grep "orquestador/adapters/generic-ai.yaml" "$ROOT/orquestador/harness-manifest.txt" "adapter yaml generic no esta en manifest"
require_grep "scripts/check-adapter-drift.ps1" "$ROOT/orquestador/harness-manifest.txt" "check-adapter-drift.ps1 no esta en manifest"
require_grep "adapter_portability" "$ROOT/orquestador/context-budget.yaml" "context-budget no define adapter_portability"
require_grep "detractor_senior" "$ROOT/orquestador/portability/core-skills.yaml" "core portable no incluye detractor_senior"
require_grep "orquestador/runtime/active-session.template.json" "$ROOT/orquestador/harness-manifest.txt" "active-session runtime no esta en manifest"
require_grep "orquestador/runtime/commands.md" "$ROOT/orquestador/harness-manifest.txt" "runtime commands no esta en manifest"
require_grep "prompts/runtime/harness-runtime.prompt.md" "$ROOT/orquestador/harness-manifest.txt" "prompt runtime no esta en manifest"
require_grep "runtime_status" "$ROOT/orquestador/context-budget.yaml" "context-budget no define runtime_status"
require_grep "runtime_reentry" "$ROOT/orquestador/context-budget.yaml" "context-budget no define runtime_reentry"
require_grep "runtime_status" "$ROOT/orquestador/memory/memory-routing.yaml" "memory-routing no define runtime_status"
require_grep "non_authoritative" "$ROOT/orquestador/runtime/active-session.template.json" "active-session debe declarar non_authoritative"
require_grep "orquestador/integrations/claude/settings.template.json" "$ROOT/orquestador/harness-manifest.txt" "claude settings template no esta en manifest"
require_grep "orquestador/integrations/claude/CLAUDE.template.md" "$ROOT/orquestador/harness-manifest.txt" "CLAUDE.template no esta en manifest"
require_grep "scripts/claude-reentry.ps1" "$ROOT/orquestador/harness-manifest.txt" "claude-reentry.ps1 no esta en manifest"
require_grep "non_authoritative" "$ROOT/orquestador/sdd/progress/templates/claude-reentry-state.yaml" "claude reentry state debe ser no autoritativo"
require_grep "Preflight only" "$ROOT/scripts/install-claude-hooks.ps1" "install-claude-hooks.ps1 debe ser preflight only"
require_grep "orquestador/instruction-builder/instruction-registry.yaml" "$ROOT/orquestador/harness-manifest.txt" "instruction registry no esta en manifest"
require_grep "orquestador/instruction-builder/fragments/kernel.md" "$ROOT/orquestador/harness-manifest.txt" "instruction fragments no estan en manifest"
require_grep "scripts/build-instructions.ps1" "$ROOT/orquestador/harness-manifest.txt" "build-instructions.ps1 no esta en manifest"
require_grep "scripts/validate-drift.ps1" "$ROOT/orquestador/harness-manifest.txt" "validate-drift.ps1 no esta en manifest"
require_grep "scripts/regularize-state.ps1" "$ROOT/orquestador/harness-manifest.txt" "regularize-state.ps1 no esta en manifest"
require_grep "scripts/regularize-registry.ps1" "$ROOT/orquestador/harness-manifest.txt" "regularize-registry.ps1 no esta en manifest"
require_grep "orquestador/method/cli-contract.md" "$ROOT/orquestador/harness-manifest.txt" "cli-contract.md no esta en manifest"
require_grep "HL0_agent_authority" "$ROOT/orquestador/agents/agent-registry.yaml" "agent-registry no declara HL0_agent_authority"
require_grep "agent_definition_authority:[[:space:]]*harness_only" "$ROOT/orquestador/agents/agent-registry.yaml" "agent-registry no declara autoridad harness_only"
require_grep "ai_may_define_agents:[[:space:]]*false" "$ROOT/orquestador/agents/agent-registry.yaml" "agent-registry no bloquea agentes definidos por IA"
require_grep "missing_capability:[[:space:]]*block" "$ROOT/orquestador/agents/capability-registry.yaml" "capability-registry no bloquea capability faltante"
require_grep "command_injection" "$ROOT/orquestador/security/threat-model.yaml" "threat-model no cubre command injection"
require_grep "path_traversal" "$ROOT/orquestador/security/threat-model.yaml" "threat-model no cubre path traversal"
require_grep "check_only_writes:[[:space:]]*false" "$ROOT/orquestador/migration/migration-registry.yaml" "migration-registry no mantiene CheckOnly sin escrituras"
require_grep "apply_requires_backup:[[:space:]]*true" "$ROOT/orquestador/migration/migration-registry.yaml" "migration-registry no exige backup para Apply"
if [ "$BINDING_MODE" = "source_template" ]; then require_grep "migration_status:[[:space:]]*not_applied" "$ROOT/orquestador/migration/contracts/post-migration-contract.yaml" "post-migration-contract source_template debe estar not_applied"; else require_grep "migration_status:[[:space:]]*applied" "$ROOT/orquestador/migration/contracts/post-migration-contract.yaml" "post-migration-contract bound debe estar applied"; fi
if [ "$BINDING_MODE" = "source_template" ]; then
  CI_FILE="$ROOT/.github/workflows/ci.yml"
  [ -f "$CI_FILE" ] || { echo "ERROR: Falta CI oficial .github/workflows/ci.yml"; exit 2; }
  require_grep "pull_request:" "$CI_FILE" "CI oficial no corre en pull_request"
  require_grep "push:" "$CI_FILE" "CI oficial no corre en push"
  require_grep "validate-harness[.]ps1 -Root [.] -RunNegativeTests" "$CI_FILE" "CI oficial no ejecuta validate-harness con negativos"
  require_grep "validate-cli[.]ps1 -Root [.] -RunNegativeTests" "$CI_FILE" "CI oficial no ejecuta validate-cli con negativos"
  require_grep "audit-harness[.]ps1 -Root [.] -RunNegativeTests" "$CI_FILE" "CI oficial no ejecuta audit-harness con negativos"
  require_grep "check-adapter-drift[.]ps1 -Root [.]$" "$CI_FILE" "CI oficial no ejecuta check-adapter-drift"
  require_grep "validate-migration[.]ps1 -Root [.] -RunNegativeTests" "$CI_FILE" "CI oficial no ejecuta fixtures de migracion"
  require_grep "validate-security-policy[.]ps1 -Root [.] -RunNegativeTests" "$CI_FILE" "CI oficial no ejecuta seguridad negativa"
  require_grep "validate-fixtures[.]ps1 -Root [.] -RunNegativeTests" "$CI_FILE" "CI oficial no ejecuta fixtures"
  require_grep "[.]/init[.]sh" "$CI_FILE" "CI oficial no ejecuta init.sh"
fi
require_grep "ComputeHash" "$ROOT/scripts/build-instructions.ps1" "build-instructions.ps1 debe usar ComputeHash compatible PS 5.1"
if grep -q "HashData\|ToHexString" "$ROOT/scripts/build-instructions.ps1"; then echo "ERROR: build-instructions.ps1 usa APIs incompatibles con Windows PowerShell 5.1"; exit 2; fi
"$PSH" -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/regularize-state.ps1" -Root "$ROOT"
"$PSH" -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/regularize-registry.ps1" -Root "$ROOT"
"$PSH" -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/build-instructions.ps1" -Root "$ROOT"
"$PSH" -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/validate-drift.ps1" -Root "$ROOT" -RunNegativeTests
"$PSH" -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/validate-release.ps1" -Root "$ROOT"
"$PSH" -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/validate-cli.ps1" -Root "$ROOT" -RunNegativeTests
"$PSH" -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/validate-bootstrap.ps1" -Root "$ROOT" -RunNegativeTests
"$PSH" -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/validate-bound-update.ps1" -Root "$ROOT" -RunNegativeTests
"$PSH" -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/validate-bound-backups.ps1" -Root "$ROOT" -RunNegativeTests
"$PSH" -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/validate-bound-restore.ps1" -Root "$ROOT" -RunNegativeTests
"$PSH" -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/validate-agent-contracts.ps1" -Root "$ROOT" -RunNegativeTests
"$PSH" -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/validate-security-policy.ps1" -Root "$ROOT" -RunNegativeTests
"$PSH" -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/validate-migration.ps1" -Root "$ROOT" -RunNegativeTests
"$PSH" -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/audit-harness.ps1" -Root "$ROOT" -RunNegativeTests
require_grep "G3A_detractor_senior_pre_implementation" "$ROOT/orquestador/sdd/progress/state.yaml" "state.yaml no declara G3A detractor senior"
require_grep "detractor_senior" "$ROOT/orquestador/method/agent-role-taxonomy.md" "taxonomy no declara detractor_senior"
require_grep "context-budget.yaml" "$ROOT/orquestador/adapters/generic-ai.md" "generic adapter no usa context-budget"
require_grep "context-budget.yaml" "$ROOT/prompts/adapters/preset-codex.prompt.md" "preset codex no usa context-budget"
require_grep "context-budget.yaml" "$ROOT/prompts/adapters/preset-claude.prompt.md" "preset claude no usa context-budget"
require_grep "context-budget.yaml" "$ROOT/prompts/adapters/preset-gemini.prompt.md" "preset gemini no usa context-budget"
require_grep "excluyendo materialmente" "$ROOT/prompts/migration/migrar-harness-0-7.prompt.md" "prompt migracion no excluye materialmente infoHebri.md"
require_grep "excluir siempre" "$ROOT/orquestador/sdd/specs/bootstrap-harness.md" "bootstrap spec no define exclusiones materiales"
require_grep "G5I_memory_consistency_complete" "$ROOT/orquestador/sdd/progress/state.yaml" "state.yaml no declara gate memoria"
require_grep "approvals:" "$ROOT/orquestador/sdd/progress/state.yaml" "state.yaml no separa approvals"
require_grep "Rol del chat: interprete" "$ROOT/orquestador/method/session-contract.md" "session-contract.md no define rol interprete"
check_context_budget memory_bootstrap 1700 PROJECT_BINDING.yaml orquestador/memory/local/session-pin.md orquestador/memory/memory-registry.yaml orquestador/memory/memory-routing.yaml orquestador/context-budget.yaml orquestador/entrypoints/reentry-light.md
check_context_budget first_message 1800 PROJECT_BINDING.yaml orquestador/memory/local/session-pin.md orquestador/memory/memory-registry.yaml orquestador/memory/memory-routing.yaml orquestador/context-budget.yaml orquestador/entrypoints/first-message.md
check_context_budget debug_log_intake 2000 PROJECT_BINDING.yaml orquestador/memory/local/session-pin.md orquestador/memory/memory-registry.yaml orquestador/memory/memory-routing.yaml orquestador/context-budget.yaml orquestador/entrypoints/debug-log-intake.md orquestador/entrypoints/reentry-light.md
check_context_budget leader_light 2600 PROJECT_BINDING.yaml orquestador/memory/local/session-pin.md orquestador/memory/memory-registry.yaml orquestador/memory/memory-routing.yaml orquestador/context-budget.yaml orquestador/sdd/progress/state.yaml orquestador/sdd/progress/registry.yaml orquestador/method/session-contract.md
if grep -R "\[Completar" "$ROOT/AGENTS.md" "$ROOT/PROGRESS.md" >/dev/null 2>&1; then if [ "$BINDING_MODE" = "source_template" ]; then echo "INFO: Placeholders operativos esperados en source_template"; else echo "WARN: Quedan placeholders operativos en AGENTS.md o PROGRESS.md"; fi; fi
"$PSH" -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/check-adapter-drift.ps1" -Root "$ROOT"
echo "OK. Harness estructurado correctamente."
exit 0
