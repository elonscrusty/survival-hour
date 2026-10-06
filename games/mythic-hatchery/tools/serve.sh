#!/bin/bash
set -e
cd "$(dirname "$0")/.."
python3 tools/prepare_runtime.py >/dev/null
exec "${SH_TOOLS:-/tmp/sh-tools}/rojo/rojo" serve build/runtime/runtime.project.json "$@"
