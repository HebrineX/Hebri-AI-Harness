#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
test -f "$ROOT/orquestador/instruction-builder/instruction-registry.yaml" || { echo "instruction registry missing" >&2; exit 2; }
for f in kernel preflight memory-routing roles claude-hooks denylists; do
  test -f "$ROOT/orquestador/instruction-builder/fragments/$f.md" || { echo "missing fragment $f" >&2; exit 2; }
done
echo "OK. Instruction builder check-only passed."
