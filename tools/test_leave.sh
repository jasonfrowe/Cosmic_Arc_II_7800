#!/bin/sh
# Leaving a planet early: button 2 held while docked, a countdown, away.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$("$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/leavetest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^leave|^result")
echo "$OUT" | grep -v "^result"
echo "$OUT" | grep -q "^result 1" && echo "leave test: PASS" || { echo "leave test: FAIL"; exit 1; }
