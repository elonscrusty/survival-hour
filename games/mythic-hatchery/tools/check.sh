#!/bin/bash
# Mythic Hatchery checks: type check (no new diagnostics allowed), unit tests, Rojo build.
#   bash tools/check.sh          # everything
#   bash tools/check.sh --quick  # skip the Rojo build
T="${SH_TOOLS:-/tmp/sh-tools}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
[ -x "$T/luau/luau" ] || bash ../../tools/setup_env.sh >/dev/null
fail=0
python3 -m unittest discover -s tools -p "test_prepare_runtime.py" || fail=1

# Per-checkout sourcemap so parallel worktrees don't overwrite each other; missing folders are created empty.
mkdir -p src/client src/server src/shared
SM="$(mktemp)"
if ! "$T/rojo/rojo" sourcemap default.project.json -o "$SM" >/dev/null 2>&1; then echo "sourcemap: FAILED"; exit 1; fi
diag=$("$T/lsp/luau-lsp" analyze --definitions="$T/globalTypes.d.luau" --sourcemap="$SM" src 2>&1)
rm -f "$SM"
if [ -z "$diag" ]; then echo "typecheck: ok"; else echo "typecheck: DIAGNOSTICS"; echo "$diag" | head -60; fail=1; fi

out=$(cd tests && "$T/luau/luau" run.luau 2>&1)
echo "unit tests: $(echo "$out" | tail -1)"
echo "$out" | tail -1 | grep -q " 0 failed" || { echo "$out" | grep FAIL; fail=1; }

if [ "${1:-}" != "--quick" ]; then
  mkdir -p build
  python3 tools/prepare_runtime.py >/dev/null || exit 1
  if "$T/rojo/rojo" build build/runtime/runtime.project.json -o build/MythicHatchery.rbxlx >/dev/null 2>&1; then echo "build: ok"; python3 tools/verify_place.py build/MythicHatchery.rbxlx || fail=1; else echo "build: FAILED"; fail=1; fi
fi
exit $fail
