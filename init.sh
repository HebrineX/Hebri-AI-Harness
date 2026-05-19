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
orquestador/policies
prompts
agents
"

FILES="
README.md
AGENTS.md
PROGRESS.md
CHANGELOG.md
orquestador/README.md
orquestador/method/ciclo-de-trabajo.md
orquestador/method/sdd.md
orquestador/method/roles.md
orquestador/method/autonomia.md
orquestador/method/brief-operativo.md
orquestador/method/operating-modes.md
orquestador/method/multiagent-protocol.md
orquestador/method/ai-engineering.md
orquestador/context/product.md
orquestador/context/architecture.md
orquestador/sdd/specs/_template/requirements.md
orquestador/sdd/specs/_template/design.md
orquestador/sdd/specs/_template/tasks.md
orquestador/sdd/progress/_README.md
orquestador/sdd/progress/registry.md
orquestador/sdd/progress/blocked.md
orquestador/sdd/progress/locks/_README.md
orquestador/policies/gap-library.md
orquestador/policies/permissions.md
orquestador/policies/risk-criteria.md
agents/leader.md
agents/spec_author.md
agents/implementer.md
agents/reviewer.md
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

if grep -R "\[Completar" "$ROOT/AGENTS.md" "$ROOT/PROGRESS.md" >/dev/null 2>&1; then
    echo "WARN: Quedan placeholders operativos en AGENTS.md o PROGRESS.md"
fi

echo "OK. Harness estructurado correctamente."
exit 0

