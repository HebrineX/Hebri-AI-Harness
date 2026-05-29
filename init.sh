#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

echo "Verificando estructura del Hebri-AI-Harness..."

DIRECTORIES="
orquestador/method
orquestador/context
orquestador/sdd/specs/_template
orquestador/sdd/progress
orquestador/sdd/progress/locks
orquestador/sdd/progress/schemas
orquestador/sdd/progress/templates
orquestador/sdd/progress/cycles
orquestador/sdd/progress/cycles/_template
orquestador/sdd/progress/approvals
orquestador/policies
orquestador/policies/schemas
prompts
agents
"

FILES="
README.md
AGENTS.md
PROGRESS.md
CHANGELOG.md
HARNESS_VERSION
PROJECT_BINDING.yaml
orquestador/README.md
orquestador/context-profiles.md
orquestador/method/session-contract.md
orquestador/method/harness-resolution.md
orquestador/method/ciclo-de-trabajo.md
orquestador/method/global-rules.md
orquestador/method/sdd.md
orquestador/method/roles.md
orquestador/method/autonomia.md
orquestador/method/brief-operativo.md
orquestador/method/operating-modes.md
orquestador/method/multiagent-protocol.md
orquestador/method/agent-role-taxonomy.md
orquestador/method/ai-engineering.md
orquestador/context/product.md
orquestador/context/architecture.md
orquestador/sdd/specs/_template/requirements.md
orquestador/sdd/specs/_template/design.md
orquestador/sdd/specs/_template/tasks.md
orquestador/sdd/specs/bootstrap-harness.md
orquestador/sdd/progress/_README.md
orquestador/sdd/progress/state.yaml
orquestador/sdd/progress/registry.yaml
orquestador/sdd/progress/registry.md
orquestador/sdd/progress/future-p1.md
orquestador/sdd/progress/schemas/state.schema.yaml
orquestador/sdd/progress/schemas/evidence-schema.md
orquestador/sdd/progress/templates/approval-envelope.md
orquestador/sdd/progress/templates/preflight-template.md
orquestador/sdd/progress/templates/reentry-checklist.md
orquestador/sdd/progress/templates/clarification-checklist.md
orquestador/sdd/progress/templates/analysis-checklist.md
orquestador/sdd/progress/templates/blast-radius.md
orquestador/sdd/progress/templates/task-graph.yaml
orquestador/sdd/progress/templates/agent-profile-template.yaml
orquestador/sdd/progress/templates/detractor-pass.md
orquestador/sdd/progress/templates/verification-matrix.yaml
orquestador/sdd/progress/templates/final-report.md
orquestador/sdd/progress/templates/agent-closure.md
orquestador/sdd/progress/cycles/_template/audit.jsonl
orquestador/sdd/progress/cycles/_template/gate-log.yaml
orquestador/sdd/progress/approvals/_README.md
orquestador/sdd/progress/blocked.md
orquestador/sdd/progress/locks/_README.md
orquestador/policies/gap-library.md
orquestador/policies/permissions.md
orquestador/policies/risk-criteria.md
orquestador/policies/tool-policy.yaml
orquestador/policies/command-taxonomy.md
orquestador/policies/write-set-policy.md
orquestador/policies/secret-denylist.md
orquestador/policies/schemas/_README.md
agents/leader.md
agents/spec_author.md
agents/implementer.md
agents/reviewer.md
agents/auditor.md
agents/reporter.md
prompts/migrar-harness-0-7.prompt.md
prompts/usuario-contrato-reentry.prompt.md
"

for dir in $DIRECTORIES; do
    if [ ! -d "$ROOT/$dir" ]; then
        echo "ERROR: Falta el directorio $dir"
        exit 2
    fi
done

for file in $FILES; do
    if [ ! -f "$ROOT/$file" ]; then
        echo "ERROR: Falta el archivo $file"
        exit 2
    fi
    if [ ! -s "$ROOT/$file" ]; then
        echo "ERROR: Archivo vacio $file"
        exit 2
    fi
done

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

if ! grep -q "0.7.0" "$ROOT/HARNESS_VERSION"; then
    echo "ERROR: HARNESS_VERSION no declara 0.7.0"
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

if [ "$HARNESS_BINDING_VERSION" != "0.7.0" ]; then
    echo "ERROR: PROJECT_BINDING.yaml no declara harness_version 0.7.0"
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
    echo "WARN: Quedan placeholders operativos en AGENTS.md o PROGRESS.md"
fi

echo "OK. Harness estructurado correctamente."
exit 0
