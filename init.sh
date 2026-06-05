#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
MANIFEST="$ROOT/orquestador/harness-manifest.txt"

require_grep() {
    pattern="$1"
    file="$2"
    message="$3"
    if ! grep -q "$pattern" "$file"; then
        echo "ERROR: $message"
        exit 2
    fi
}

echo "Verificando estructura del Hebri-AI-Harness..."

if [ ! -s "$MANIFEST" ]; then
    echo "ERROR: Falta el manifiesto orquestador/harness-manifest.txt"
    exit 2
fi

while IFS= read -r line || [ -n "$line" ]; do
    entry="$(printf '%s' "$line" | sed 's/[[:space:]]*$//')"
    case "$entry" in
        ""|\#*) continue ;;
    esac

    kind="${entry%% *}"
    path="${entry#* }"
    if [ "$kind" = "$path" ]; then
        echo "ERROR: Entrada invalida en manifest: $entry"
        exit 2
    fi

    case "$kind" in
        dir)
            if [ ! -d "$ROOT/$path" ]; then
                echo "ERROR: Falta el directorio $path"
                exit 2
            fi
            ;;
        file)
            if [ ! -f "$ROOT/$path" ]; then
                echo "ERROR: Falta el archivo $path"
                exit 2
            fi
            if [ ! -s "$ROOT/$path" ]; then
                echo "ERROR: Archivo vacio $path"
                exit 2
            fi
            ;;
        *)
            echo "ERROR: Tipo invalido en manifest: $kind"
            exit 2
            ;;
    esac
done < "$MANIFEST"

if grep -R "\.hebrinex/policies" "$ROOT/AGENTS.md" "$ROOT/orquestador" >/dev/null 2>&1; then
    echo "ERROR: Ruta obsoleta detectada: .hebrinex/policies"
    exit 2
fi

if grep -R "\.hebrinex/orquestador/sdd/\.hebrinex" "$ROOT/agents" "$ROOT/prompts" >/dev/null 2>&1; then
    echo "ERROR: Ruta canonica duplicada detectada"
    exit 2
fi

require_grep "session-contract.md" "$ROOT/AGENTS.md" "AGENTS.md no referencia session-contract.md"
require_grep "orquestador/memory" "$ROOT/AGENTS.md" "AGENTS.md no referencia memoria operativa"
require_grep "G6_agent_closure_complete" "$ROOT/orquestador/method/multiagent-protocol.md" "multiagent-protocol.md no define cierre de agentes P0"
require_grep "G5A_detractor_pass_complete" "$ROOT/orquestador/method/multiagent-protocol.md" "multiagent-protocol.md no define detractor pass P0"
require_grep "anti-confirmation bias" "$ROOT/orquestador/method/global-rules.md" "global-rules.md no define anti-confirmation bias"
require_grep "schema: hebrinex.memory.registry" "$ROOT/orquestador/memory/memory-registry.yaml" "memory-registry.yaml no define schema"
require_grep "reentry_light" "$ROOT/orquestador/memory/memory-routing.yaml" "memory-routing.yaml no define reentry_light"
require_grep "Memory layers" "$ROOT/orquestador/memory/local/session-pin.md" "session-pin.md no declara capas de memoria"
require_grep "first-message" "$ROOT/orquestador/entrypoints/README.md" "entrypoints README no define first-message"
require_grep "Generic AI Adapter" "$ROOT/orquestador/adapters/generic-ai.md" "generic-ai adapter ausente o invalido"
require_grep "Codex Adapter" "$ROOT/orquestador/adapters/codex.md" "codex adapter ausente o invalido"
require_grep "Claude Code Adapter" "$ROOT/orquestador/adapters/claude-code.md" "claude-code adapter ausente o invalido"
require_grep "Gemini Adapter" "$ROOT/orquestador/adapters/gemini.md" "gemini adapter ausente o invalido"
require_grep "Qwen Adapter" "$ROOT/orquestador/adapters/qwen.md" "qwen adapter ausente o invalido"
require_grep "DeepSeek Adapter" "$ROOT/orquestador/adapters/deepseek.md" "deepseek adapter ausente o invalido"
require_grep "adapter" "$ROOT/orquestador/method/adapter-contract.md" "adapter-contract.md no define adapters"
require_grep "memory" "$ROOT/orquestador/method/context-loading-policy.md" "context-loading-policy.md no define memoria"
require_grep "git log + PROGRESS.md + registry" "$ROOT/orquestador/method/changelog-policy.md" "changelog-policy.md no define gate de reconstruccion historica"
require_grep "deploy" "$ROOT/orquestador/method/deploy-migration-policy.md" "deploy-migration-policy.md no define gate de deploy/migracion"
require_grep "HARNESS_VERSION" "$ROOT/orquestador/method/reference-drift-policy.md" "reference-drift-policy.md no define control de version"
require_grep "pipeline" "$ROOT/orquestador/method/ci-pipeline-policy.md" "ci-pipeline-policy.md no define control de pipeline"
require_grep "P0/P1/P2" "$ROOT/orquestador/method/backlog-policy.md" "backlog-policy.md no define clasificacion P0/P1/P2"
require_grep "reporter" "$ROOT/orquestador/method/audit-reporting-policy.md" "audit-reporting-policy.md no define separacion auditor/reporter"
require_grep "Cross-links" "$ROOT/orquestador/method/final-report-evidence-policy.md" "final-report-evidence-policy.md no define cross-links"
require_grep "session-pin" "$ROOT/orquestador/method/ai-preset-policy.md" "ai-preset-policy.md no define session-pin"
require_grep "0.8.0" "$ROOT/HARNESS_VERSION" "HARNESS_VERSION no declara 0.8.0"

get_binding_value() {
    key="$1"
    sed -n "s/^$key:[[:space:]]*//p" "$ROOT/PROJECT_BINDING.yaml" | head -n 1 | sed 's/^"//; s/"$//; s/\r$//'
}

normalize_path() {
    path="$1"
    if [ -z "$path" ]; then
        printf '%s\n' ""
        return 0
    fi
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -u "$path" 2>/dev/null || printf '%s\n' "$path"
    else
        printf '%s\n' "$path"
    fi
}

BINDING_MODE="$(get_binding_value binding_mode)"
PROJECT_ROOT_RAW="$(get_binding_value project_root)"
HARNESS_BINDING_VERSION="$(get_binding_value harness_version)"

if [ "$BINDING_MODE" != "source_template" ] && [ "$BINDING_MODE" != "bound" ]; then
    echo "ERROR: PROJECT_BINDING.yaml binding_mode invalido: $BINDING_MODE"
    exit 2
fi

if [ "$HARNESS_BINDING_VERSION" != "0.8.0" ]; then
    echo "ERROR: PROJECT_BINDING.yaml no declara harness_version 0.8.0"
    exit 2
fi

if [ "$BINDING_MODE" = "bound" ]; then
    if [ -z "$PROJECT_ROOT_RAW" ]; then
        echo "ERROR: PROJECT_BINDING.yaml bound requiere project_root"
        exit 2
    fi
    ROOT_BASENAME="$(basename "$ROOT")"
    if [ "$ROOT_BASENAME" != ".hebrinex" ]; then
        echo "ERROR: Un harness bound debe vivir en <project_root>/.hebrinex"
        exit 2
    fi
    ACTUAL_PROJECT_ROOT="$(CDPATH= cd -- "$ROOT/.." && pwd)"
    EXPECTED_PROJECT_ROOT="$(normalize_path "$PROJECT_ROOT_RAW")"
    if [ "$EXPECTED_PROJECT_ROOT" != "$ACTUAL_PROJECT_ROOT" ]; then
        echo "ERROR: PROJECT_BINDING mismatch"
        echo "  project_root esperado: $EXPECTED_PROJECT_ROOT"
        echo "  project_root real:     $ACTUAL_PROJECT_ROOT"
        exit 2
    fi
fi

echo "Binding: $BINDING_MODE"
echo "Harness path: $ROOT"
if [ -n "$PROJECT_ROOT_RAW" ]; then
    echo "Project root: $(normalize_path "$PROJECT_ROOT_RAW")"
fi

require_grep "tool_policy" "$ROOT/orquestador/policies/tool-policy.yaml" "tool-policy.yaml no define schema de policy"
require_grep "Rol del chat: interprete" "$ROOT/orquestador/method/session-contract.md" "session-contract.md no define rol interprete"

if grep -R "\[Completar" "$ROOT/AGENTS.md" "$ROOT/PROGRESS.md" >/dev/null 2>&1; then
    if [ "$BINDING_MODE" = "source_template" ]; then
        echo "INFO: Placeholders operativos esperados en source_template"
    else
        echo "WARN: Quedan placeholders operativos en AGENTS.md o PROGRESS.md"
    fi
fi

echo "OK. Harness estructurado correctamente."
exit 0