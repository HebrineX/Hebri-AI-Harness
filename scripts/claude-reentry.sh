#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BRIEF_DIR="$ROOT/orquestador/runtime/claude"
BRIEF="$BRIEF_DIR/reentry-brief.md"
test -f "$ROOT/PROJECT_BINDING.yaml" || { echo "PROJECT_BINDING.yaml missing" >&2; exit 2; }
mkdir -p "$BRIEF_DIR"
VERSION="$(cat "$ROOT/HARNESS_VERSION")"
{
  echo "# Claude Reentry Brief"
  echo
  echo "- Harness path: $ROOT"
  echo "- Version: $VERSION"
  echo "- Approvals expired: true"
  echo "- Actions with effects require preflight + SI"
} > "$BRIEF"
echo "OK. Claude reentry checked."
