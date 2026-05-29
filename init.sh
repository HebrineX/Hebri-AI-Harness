#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
MANIFEST="$ROOT/orquestador/harness-manifest.txt"

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

if ! grep -q "session-contract.md" "$ROOT/AGENTS.md"; then
    echo "ERROR: AGENTS.md no referencia session-contract.md"
    exit 2
fi

if ! grep -q "G6_agent_closure_complete" "$ROOT/orquestador/method/multiagent-protocol.md"; then
    echo "ERROR: multiagent-protocol.md no define cierre de agentes P0"
    exit 2
fi

if ! grep -q "G5A_detractor_pass_complete" "$ROOT/orquestador/method/multiagent-protocol.md"; then
    echo "ERROR: multiagent-protocol.md no define detractor pass P0"
    exit 2
fi

if ! grep -q "anti-confirmation bias" "$ROOT/orquestador/method/global-rules.md"; then
    echo "ERROR: global-rules.md no define anti-confirmation bias"
    exit 2
fi

if ! grep -q "git log + PROGRESS.md + registry" "$ROOT/orquestador/method/changelog-policy.md"; then
    echo "ERROR: changelog-policy.md no define gate de reconstruccion historica"
    exit 2
fi

if ! grep -q "deploy" "$ROOT/orquestador/method/deploy-migration-policy.md"; then
    echo "ERROR: deploy-migration-policy.md no define gate de deploy/migracion"
    exit 2
fi

if ! grep -q "HARNESS_VERSION" "$ROOT/orquestador/method/reference-drift-policy.md"; then
    echo "ERROR: reference-drift-policy.md no define control de version"
    exit 2
fi

if ! grep -q "pipeline" "$ROOT/orquestador/method/ci-pipeline-policy.md"; then
    echo "ERROR: ci-pipeline-policy.md no define control de pipeline"
    exit 2
fi

if ! grep -q "P0/P1/P2" "$ROOT/orquestador/method/backlog-policy.md"; then
    echo "ERROR: backlog-policy.md no define clasificacion P0/P1/P2"
    exit 2
fi

if ! grep -q "reporter" "$ROOT/orquestador/method/audit-reporting-policy.md"; then
    echo "ERROR: audit-reporting-policy.md no define separacion auditor/reporter"
    exit 2
fi

if ! grep -q "Cross-links" "$ROOT/orquestador/method/final-report-evidence-policy.md"; then
    echo "ERROR: final-report-evidence-policy.md no define cross-links"
    exit 2
fi

if ! grep -q "Codex" "$ROOT/orquestador/method/ai-preset-policy.md"; then
    echo "ERROR: ai-preset-policy.md no define presets por IA"
    exit 2
fi

if ! grep -q "0.7.9" "$ROOT/HARNESS_VERSION"; then
    echo "ERROR: HARNESS_VERSION no declara 0.7.9"
    exit 2
fi

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

if [ "$HARNESS_BINDING_VERSION" != "0.7.9" ]; then
    echo "ERROR: PROJECT_BINDING.yaml no declara harness_version 0.7.9"
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

if ! grep -q "tool_policy" "$ROOT/orquestador/policies/tool-policy.yaml"; then
    echo "ERROR: tool-policy.yaml no define schema de policy"
    exit 2
fi

if ! grep -q "Rol del chat: interprete" "$ROOT/orquestador/method/session-contract.md"; then
    echo "ERROR: session-contract.md no define rol interprete"
    exit 2
fi

if grep -R "\[Completar" "$ROOT/AGENTS.md" "$ROOT/PROGRESS.md" >/dev/null 2>&1; then
    if [ "$BINDING_MODE" = "source_template" ]; then
        echo "INFO: Placeholders operativos esperados en source_template"
    else
        echo "WARN: Quedan placeholders operativos en AGENTS.md o PROGRESS.md"
    fi
fi

echo "OK. Harness estructurado correctamente."
exit 0
