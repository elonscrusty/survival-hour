#!/bin/bash
# Pet Expedition checks: type check (no new diagnostics allowed), unit tests, Rojo build.
#   bash tools/check.sh          # everything
#   bash tools/check.sh --quick  # skip the Rojo build
T="${SH_TOOLS:-/tmp/sh-tools}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
[ -x "$T/luau/luau" ] || bash ../../tools/setup_env.sh >/dev/null
fail=0

"$T/rojo/rojo" sourcemap default.project.json -o "$T/pe_sourcemap.json" >/dev/null 2>&1
diag=$("$T/lsp/luau-lsp" analyze --definitions="$T/globalTypes.d.luau" --sourcemap="$T/pe_sourcemap.json" src 2>&1)
if [ -z "$diag" ]; then echo "typecheck: ok"; else echo "typecheck: DIAGNOSTICS"; echo "$diag" | head -60; fail=1; fi

out=$(cd tests && "$T/luau/luau" run.luau 2>&1)
echo "unit tests: $(echo "$out" | tail -1)"
echo "$out" | tail -1 | grep -q " 0 failed" || { echo "$out" | grep FAIL; fail=1; }

if [ "${1:-}" != "--quick" ]; then
  mkdir -p build
  if "$T/rojo/rojo" build default.project.json -o build/PetExpedition.rbxlx >/dev/null 2>&1; then echo "build: ok"; else echo "build: FAILED"; fail=1; fi
fi
exit $fail
