#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
VERSION="$(tr -d '\r\n' < "$ROOT/HARNESS_VERSION")"
printf '%s' "$VERSION" | grep -Eq '^0[.][0-9]+[.][0-9]+$' || { echo "HARNESS_VERSION must be SemVer 0.x.y" >&2; exit 2; }
for f in kernel preflight memory-routing roles claude-hooks denylists; do
  test -f "$ROOT/orquestador/instruction-builder/fragments/$f.md" || { echo "missing fragment $f" >&2; exit 2; }
done
echo "OK. Strong drift validation passed."
