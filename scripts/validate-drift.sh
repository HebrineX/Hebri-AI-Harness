#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
test "$(cat "$ROOT/HARNESS_VERSION")" = "0.8.9" || { echo "HARNESS_VERSION must be 0.8.9" >&2; exit 2; }
for f in kernel preflight memory-routing roles claude-hooks denylists; do
  test -f "$ROOT/orquestador/instruction-builder/fragments/$f.md" || { echo "missing fragment $f" >&2; exit 2; }
done
echo "OK. Strong drift validation passed."
