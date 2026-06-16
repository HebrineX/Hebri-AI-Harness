#!/usr/bin/env sh
set -eu
PROJECT_ROOT="${1:-$(pwd)}"
HARNESS="$PROJECT_ROOT/.hebrinex"
test -f "$HARNESS/orquestador/integrations/claude/settings.template.json" || { echo "Claude settings template missing" >&2; exit 2; }
echo "Preflight only: copy settings.template.json into Claude settings after operator SI."
