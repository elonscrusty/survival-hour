#!/bin/bash
# Sell Hot Dogs checks: catalog regen, type check, unit tests, Rojo build, headless smoke test.
#   bash tools/check.sh           # everything
#   bash tools/check.sh --quick   # skip build + smoke test
# Tools: luau, rojo 7.7.0, luau-lsp 1.53.0 (+ globalTypes), lune 0.10.4. Set SHD_TOOLS to their folder.
T="${SHD_TOOLS:-/tmp/sh-tools}"
cd "$(dirname "$0")/.." || exit 1
fail=0
python3 tools/gen_catalog.py >/dev/null || { echo "catalog: FAILED"; fail=1; }
"$T/rojo/rojo" sourcemap default.project.json -o "$T/shd_sourcemap.json" >/dev/null 2>&1
diag=$("$T/lsp/luau-lsp" analyze --definitions="$T/globalTypes.d.luau" --sourcemap="$T/shd_sourcemap.json" src 2>&1 | grep -E "Error|Warning" )
if [ -z "$diag" ]; then echo "typecheck: ok"; else echo "typecheck: ISSUES"; echo "$diag"; fail=1; fi
out=$(cd tests && "$T/luau/luau" run.luau 2>&1 | tail -1)
echo "unit tests: $out"; echo "$out" | grep -q " 0 failed" || fail=1
if [ "${1:-}" != "--quick" ]; then
  if "$T/rojo/rojo" build default.project.json -o build/SellHotDogs.rbxlx >/dev/null 2>&1; then echo "build: ok"; else echo "build: FAILED"; fail=1; fi
  out=$(timeout 300 "$T/lune/lune" run tools/smoke/smoke.luau 2>&1 | tail -1)
  echo "smoke (headless, Lune): $out"; echo "$out" | grep -q " 0 failed, 0 script errors" || fail=1
fi
exit $fail
