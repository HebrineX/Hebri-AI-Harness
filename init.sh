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
orquestador/README.md
orquestador/context-profiles.md
orquestador/method/session-contract.md
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

if ! grep -q "0.6.0" "$ROOT/HARNESS_VERSION"; then
    echo "ERROR: HARNESS_VERSION no declara 0.6.0"
    exit 2
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