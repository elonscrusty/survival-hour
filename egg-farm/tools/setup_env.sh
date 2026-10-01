#!/bin/bash
# Installs the command-line tools the checks need (Linux; idempotent). Tools go to $EF_TOOLS.
# Windows/macOS users: install Rojo 7.7.0 (https://rojo.space) and open the built place instead.
set -u
[ "$(uname -s)" = "Linux" ] || exit 0
T="${EF_TOOLS:-${SH_TOOLS:-/tmp/sh-tools}}"
mkdir -p "$T"; cd "$T" || exit 0
get() { curl -fsSL --retry 3 -o "$1" "$2"; }
[ -x "$T/luau/luau" ] || { get luau.zip https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip && mkdir -p luau && unzip -qo luau.zip -d luau && chmod +x luau/* && rm -f luau.zip; }
[ -x "$T/rojo/rojo" ] || { get rojo.zip https://github.com/rojo-rbx/rojo/releases/download/v7.7.0/rojo-7.7.0-linux-x86_64.zip && mkdir -p rojo && unzip -qo rojo.zip -d rojo && chmod +x rojo/rojo && rm -f rojo.zip; }
[ -x "$T/lsp/luau-lsp" ] || { get lsp.zip https://github.com/JohnnyMorganz/luau-lsp/releases/download/1.53.0/luau-lsp-linux-x86_64.zip && mkdir -p lsp && unzip -qo lsp.zip -d lsp && chmod +x lsp/luau-lsp && rm -f lsp.zip; }
[ -s "$T/globalTypes.d.luau" ] || get globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.53.0/scripts/globalTypes.d.luau
# Model work only (large download): EF_WITH_BPY=1 bash tools/setup_env.sh
if [ "${EF_WITH_BPY:-0}" = "1" ] && ! python3 -c "import bpy" 2>/dev/null; then pip install -q bpy==5.0.1; fi
echo "tools ready in $T"
