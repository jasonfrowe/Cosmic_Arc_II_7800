#!/bin/sh
# Planet levels: by distance from home; rare kinds far out, common near home.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$("$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/leveltest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^level|^result")
echo "$OUT" | grep -v "^result"
echo "$OUT" | grep -q "^result 1" && echo "level test: PASS" || { echo "level test: FAIL"; exit 1; }
