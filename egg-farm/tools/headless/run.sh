#!/bin/bash
# Egg Farm headless integration harness (offline Roblox MOCK, not Roblox). See docs/HEADLESS_RESULTS.md.
#   bash tools/headless/run.sh [scenario ...]
exec python3 "$(dirname "$0")/run.py" "$@"
