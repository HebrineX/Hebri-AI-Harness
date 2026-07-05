#!/usr/bin/env sh
set -eu
PROJECT_ROOT="${1:-$(pwd)}"
HARNESS="$PROJECT_ROOT/.hebrinex"
test -f "$HARNESS/orquestador/integrations/claude/settings.template.json" || { echo "Claude settings template missing" >&2; exit 2; }
echo "CheckOnly: run pwsh -File $HARNESS/scripts/install-claude-hooks.ps1 -ProjectRoot $PROJECT_ROOT -CheckOnly"
echo "Apply (after operator SI): run pwsh -File $HARNESS/scripts/install-claude-hooks.ps1 -ProjectRoot $PROJECT_ROOT -Apply"
