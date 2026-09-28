#!/bin/bash
# All game checks in one go: type check (vs tools/typecheck_baseline.txt), unit tests,
# skins/lobby mocks, Rojo build. Prints one line per check; exit 1 on any failure.
#   bash tools/check.sh          # everything
#   bash tools/check.sh --quick  # skip the Rojo build
T="${SH_TOOLS:-/tmp/sh-tools}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
[ -x "$T/luau/luau" ] || bash tools/setup_env.sh >/dev/null
fail=0
norm() { sed 's/([0-9,]*)//;s/line [0-9]*/line N/' | sort; }

"$T/rojo/rojo" sourcemap default.project.json -o "$T/sourcemap.json" >/dev/null 2>&1
"$T/lsp/luau-lsp" analyze --definitions="$T/globalTypes.d.luau" --sourcemap="$T/sourcemap.json" src 2>&1 | norm > "$T/typecheck_now.txt"
new=$(comm -13 tools/typecheck_baseline.txt "$T/typecheck_now.txt")
if [ -z "$new" ]; then echo "typecheck: ok"; else echo "typecheck: NEW DIAGNOSTICS"; echo "$new"; fail=1; fi

out=$(cd tests && "$T/luau/luau" run.luau 2>&1 | tail -1)
echo "unit tests: $out"; echo "$out" | grep -q " 0 failed" || { (cd tests && "$T/luau/luau" run.luau 2>&1 | grep FAIL); fail=1; }

out=$(PATH="$T/luau:$PATH" python3 tests/skins/bundle.py 2>&1 | grep -E "passed")
echo "skins/lobby: $out"; echo "$out" | grep -q " 0 failed" || fail=1

if [ "${1:-}" != "--quick" ]; then
  if "$T/rojo/rojo" build default.project.json -o build/SurvivalHour.rbxlx >/dev/null 2>&1; then echo "build: ok"; else echo "build: FAILED"; fail=1; fi
fi
exit $fail
