#!/bin/sh
# The map's pages: warps with their ways (one-way >), the star chart's cursor and
# its warps, the tab bar round the pages (DESIGN.md 3.6b).
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$("$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/charttest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^chart|^result")
echo "$OUT" | grep -v "^result"
echo "$OUT" | grep -q "^result 1" && echo "chart test: PASS" || { echo "chart test: FAIL"; exit 1; }
