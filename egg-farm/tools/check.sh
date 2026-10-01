#!/bin/bash
# Egg Farm: every offline check in one go. Prints one line per check; exit 1 on any failure.
#   bash tools/check.sh          # type check, unit tests, both Rojo builds
#   bash tools/check.sh --quick  # skip the Rojo builds
# Tools (luau, luau-lsp, rojo) come from tools/setup_env.sh (installed into $EF_TOOLS).
T="${EF_TOOLS:-${SH_TOOLS:-/tmp/sh-tools}}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
[ -x "$T/luau/luau" ] || bash tools/setup_env.sh >/dev/null
fail=0
norm() { sed 's/([0-9,]*)//;s/line [0-9]*/line N/' | sort; }

"$T/rojo/rojo" sourcemap test.project.json -o "$T/ef_sourcemap.json" >/dev/null 2>&1
"$T/lsp/luau-lsp" analyze --definitions="$T/globalTypes.d.luau" --sourcemap="$T/ef_sourcemap.json" \
	--ignore="vendor/**" src test 2>&1 | grep -v "^$" | norm > "$T/ef_typecheck_now.txt"
touch tools/typecheck_baseline.txt
new=$(comm -13 tools/typecheck_baseline.txt "$T/ef_typecheck_now.txt")
if [ -z "$new" ]; then echo "typecheck: ok"; else echo "typecheck: NEW DIAGNOSTICS"; echo "$new"; fail=1; fi

out=$("$T/luau/luau" tests/run.luau 2>&1)
last=$(echo "$out" | grep -E "passed, [0-9]+ failed" | tail -1)
echo "unit tests: ${last:-did not finish}"
echo "$last" | grep -q " 0 failed" || { echo "$out" | grep -E "FAIL|error" | head -40; fail=1; }

if [ "${1:-}" != "--quick" ]; then
	mkdir -p build
	if "$T/rojo/rojo" build default.project.json -o build/EggFarm.rbxlx >/dev/null 2>&1; then echo "build (game): ok"; else echo "build (game): FAILED"; fail=1; fi
	if "$T/rojo/rojo" build test.project.json -o build/EggFarm.Test.rbxlx >/dev/null 2>&1; then echo "build (test place): ok"; else echo "build (test place): FAILED"; fail=1; fi
fi
exit $fail
