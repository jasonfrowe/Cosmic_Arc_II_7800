#!/bin/sh
# Achievements: earned, announced on the map; their screen (bank 6), in and out.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$("$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/achtest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^ach|^result")
echo "$OUT" | grep -v "^result"
echo "$OUT" | grep -q "^result 1" && echo "achievements test: PASS" || { echo "achievements test: FAIL"; exit 1; }
