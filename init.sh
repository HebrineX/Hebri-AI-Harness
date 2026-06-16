#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
MANIFEST="$ROOT/orquestador/harness-manifest.txt"
require_grep(){ pattern="$1"; file="$2"; message="$3"; if ! grep -q "$pattern" "$file"; then echo "ERROR: $message"; exit 2; fi; }
estimate_tokens_for_files(){ total_chars=0; for rel in "$@"; do if [ -f "$ROOT/$rel" ]; then chars="$(wc -c < "$ROOT/$rel" | tr -d ' ')"; total_chars=$((total_chars + chars)); fi; done; echo $(((total_chars + 3) / 4)); }
check_context_budget(){ name="$1"; max="$2"; shift 2; used="$(estimate_tokens_for_files "$@")"; if [ "$used" -gt "$max" ]; then echo "ERROR: Presupuesto de contexto excedido para $name: $used > $max tokens estimados"; exit 2; fi; }
get_binding_value(){ key="$1"; sed -n "s/^$key:[[:space:]]*//p" "$ROOT/PROJECT_BINDING.yaml" | head -n 1 | sed 's/^"//; s/"$//; s/\r$//'; }
normalize_path(){ path="$1"; if [ -z "$path" ]; then printf '%s\n' ""; return 0; fi; if command -v cygpath >/dev/null 2>&1; then cygpath -u "$path" 2>/dev/null || printf '%s\n' "$path"; else printf '%s\n' "$path"; fi; }
echo "Verificando estructura del Hebri-AI-Harness..."
[ -s "$MANIFEST" ] || { echo "ERROR: Falta el manifiesto orquestador/harness-manifest.txt"; exit 2; }
if grep -q '^file infoHebri[.]md$' "$MANIFEST"; then echo "ERROR: infoHebri.md no debe figurar en el manifest"; exit 2; fi
while IFS= read -r line || [ -n "$line" ]; do entry="$(printf '%s' "$line" | sed 's/[[:space:]]*$//')"; case "$entry" in ""|\#*) continue ;; esac; kind="${entry%% *}"; path="${entry#* }"; [ "$kind" != "$path" ] || { echo "ERROR: Entrada invalida en manifest: $entry"; exit 2; }; case "$kind" in dir) [ -d "$ROOT/$path" ] || { echo "ERROR: Falta el directorio $path"; exit 2; };; file) [ -f "$ROOT/$path" ] || { echo "ERROR: Falta el archivo $path"; exit 2; }; [ -s "$ROOT/$path" ] || { echo "ERROR: Archivo vacio $path"; exit 2; };; *) echo "ERROR: Tipo invalido en manifest: $kind"; exit 2;; esac; done < "$MANIFEST"
BINDING_MODE="$(get_binding_value binding_mode)"; PROJECT_ROOT_RAW="$(get_binding_value project_root)"; HARNESS_BINDING_VERSION="$(get_binding_value harness_version)"
[ "$BINDING_MODE" = "source_template" ] || [ "$BINDING_MODE" = "bound" ] || { echo "ERROR: PROJECT_BINDING.yaml binding_mode invalido: $BINDING_MODE"; exit 2; }
[ "$HARNESS_BINDING_VERSION" = "0.8.3" ] || { echo "ERROR: PROJECT_BINDING.yaml no declara harness_version 0.8.3"; exit 2; }
if [ "$BINDING_MODE" = "bound" ]; then [ -n "$PROJECT_ROOT_RAW" ] || { echo "ERROR: PROJECT_BINDING.yaml bound requiere project_root"; exit 2; }; [ "$(basename "$ROOT")" = ".hebrinex" ] || { echo "ERROR: Un harness bound debe vivir en <project_root>/.hebrinex"; exit 2; }; ACTUAL_PROJECT_ROOT="$(CDPATH= cd -- "$ROOT/.." && pwd)"; EXPECTED_PROJECT_ROOT="$(normalize_path "$PROJECT_ROOT_RAW")"; [ "$EXPECTED_PROJECT_ROOT" = "$ACTUAL_PROJECT_ROOT" ] || { echo "ERROR: PROJECT_BINDING mismatch"; exit 2; }; [ ! -f "$ROOT/infoHebri.md" ] || { echo "ERROR: infoHebri.md no debe existir dentro de un harness bound"; exit 2; }; fi
echo "Binding: $BINDING_MODE"; echo "Harness path: $ROOT"; [ -z "$PROJECT_ROOT_RAW" ] || echo "Project root: $(normalize_path "$PROJECT_ROOT_RAW")"
if grep -R "0[.]8[.][0-2]" "$ROOT" --exclude="CHANGELOG.md" --exclude="infoHebri.md" --exclude-dir=".git" >/dev/null 2>&1; then echo "ERROR: Drift de version antigua detectado fuera de CHANGELOG.md"; grep -R "0[.]8[.][0-2]" "$ROOT" --exclude="CHANGELOG.md" --exclude="infoHebri.md" --exclude-dir=".git" || true; exit 2; fi
if grep -R "\.hebrinex/policies" "$ROOT/AGENTS.md" "$ROOT/orquestador" >/dev/null 2>&1; then echo "ERROR: Ruta obsoleta detectada: .hebrinex/policies"; exit 2; fi
if grep -R "\.hebrinex/orquestador/sdd/\.hebrinex" "$ROOT/agents" "$ROOT/prompts" >/dev/null 2>&1; then echo "ERROR: Ruta canonica duplicada detectada"; exit 2; fi
require_grep "0.8.3" "$ROOT/HARNESS_VERSION" "HARNESS_VERSION no declara 0.8.3"
require_grep "schema: hebrinex.context_budget" "$ROOT/orquestador/context-budget.yaml" "context-budget.yaml no define schema"
require_grep "context_budget" "$ROOT/orquestador/memory/local/session-pin.md" "session-pin.md no declara context_budget"
require_grep "memory-closure-checklist.md" "$ROOT/orquestador/method/memory-layer-policy.md" "memory-layer-policy.md no exige cierre de memoria"
require_grep "memory-closure-checklist.md" "$ROOT/orquestador/method/final-report-evidence-policy.md" "final-report-evidence-policy.md no exige memory closure checklist"
require_grep "memory-closure-checklist.md" "$ROOT/orquestador/harness-manifest.txt" "manifest no incluye memory closure checklist"
require_grep "scripts/validate-harness.ps1" "$ROOT/orquestador/harness-manifest.txt" "validate-harness.ps1 no esta en manifest"
require_grep "project-binding.schema.yaml" "$ROOT/orquestador/harness-manifest.txt" "schema project-binding no esta en manifest"
require_grep "context-budget.schema.yaml" "$ROOT/orquestador/harness-manifest.txt" "schema context-budget no esta en manifest"
require_grep "memory-registry.schema.yaml" "$ROOT/orquestador/harness-manifest.txt" "schema memory-registry no esta en manifest"
require_grep "registry.schema.yaml" "$ROOT/orquestador/harness-manifest.txt" "schema registry no esta en manifest"
require_grep "RunNegativeTests" "$ROOT/scripts/validate-harness.ps1" "validate-harness.ps1 no expone pruebas negativas"
require_grep "agents/_schema.md" "$ROOT/orquestador/harness-manifest.txt" "agent schema no esta en manifest"
require_grep "agents/detractor-senior.md" "$ROOT/orquestador/harness-manifest.txt" "detractor senior agent no esta en manifest"
require_grep "minimal-implementation-policy.md" "$ROOT/orquestador/harness-manifest.txt" "minimal implementation policy no esta en manifest"
require_grep "detractor-senior-checklist.md" "$ROOT/orquestador/harness-manifest.txt" "detractor-senior-checklist.md no esta en manifest"
require_grep "prompts/detractor-senior.prompt.md" "$ROOT/orquestador/harness-manifest.txt" "detractor senior prompt no esta en manifest"
require_grep "G3A_detractor_senior_pre_implementation" "$ROOT/orquestador/sdd/progress/state.yaml" "state.yaml no declara G3A detractor senior"
require_grep "detractor_senior" "$ROOT/orquestador/method/agent-role-taxonomy.md" "taxonomy no declara detractor_senior"
require_grep "context-budget.yaml" "$ROOT/orquestador/adapters/generic-ai.md" "generic adapter no usa context-budget"
require_grep "context-budget.yaml" "$ROOT/prompts/preset-codex.prompt.md" "preset codex no usa context-budget"
require_grep "context-budget.yaml" "$ROOT/prompts/preset-claude.prompt.md" "preset claude no usa context-budget"
require_grep "context-budget.yaml" "$ROOT/prompts/preset-gemini.prompt.md" "preset gemini no usa context-budget"
require_grep "excluyendo materialmente" "$ROOT/prompts/migrar-harness-0-7.prompt.md" "prompt migracion no excluye materialmente infoHebri.md"
require_grep "excluir siempre" "$ROOT/orquestador/sdd/specs/bootstrap-harness.md" "bootstrap spec no define exclusiones materiales"
require_grep "G5I_memory_consistency_complete" "$ROOT/orquestador/sdd/progress/state.yaml" "state.yaml no declara gate memoria"
require_grep "approvals:" "$ROOT/orquestador/sdd/progress/state.yaml" "state.yaml no separa approvals"
require_grep "Rol del chat: interprete" "$ROOT/orquestador/method/session-contract.md" "session-contract.md no define rol interprete"
check_context_budget memory_bootstrap 1500 PROJECT_BINDING.yaml orquestador/memory/local/session-pin.md orquestador/memory/memory-registry.yaml orquestador/memory/memory-routing.yaml orquestador/context-budget.yaml orquestador/entrypoints/reentry-light.md
check_context_budget first_message 1800 PROJECT_BINDING.yaml orquestador/memory/local/session-pin.md orquestador/memory/memory-registry.yaml orquestador/memory/memory-routing.yaml orquestador/context-budget.yaml orquestador/entrypoints/first-message.md
check_context_budget debug_log_intake 2000 PROJECT_BINDING.yaml orquestador/memory/local/session-pin.md orquestador/memory/memory-registry.yaml orquestador/memory/memory-routing.yaml orquestador/context-budget.yaml orquestador/entrypoints/debug-log-intake.md orquestador/entrypoints/reentry-light.md
check_context_budget leader_light 2400 PROJECT_BINDING.yaml orquestador/memory/local/session-pin.md orquestador/memory/memory-registry.yaml orquestador/memory/memory-routing.yaml orquestador/context-budget.yaml orquestador/sdd/progress/state.yaml orquestador/sdd/progress/registry.yaml orquestador/method/session-contract.md
if grep -R "\[Completar" "$ROOT/AGENTS.md" "$ROOT/PROGRESS.md" >/dev/null 2>&1; then if [ "$BINDING_MODE" = "source_template" ]; then echo "INFO: Placeholders operativos esperados en source_template"; else echo "WARN: Quedan placeholders operativos en AGENTS.md o PROGRESS.md"; fi; fi
echo "OK. Harness estructurado correctamente."
exit 0