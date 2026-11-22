#!/bin/sh
# The saucer called home is safe: no deaths on the way back, in busy waves.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$("$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/recalltest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^trips|^result")
echo "$OUT" | grep "^trips"
echo "$OUT" | sed -n 's/^result //p' | awk '{ if ($1 >= 20 && $2 == 0) { print "recall test: PASS"; exit 0 } print "recall test: FAIL"; exit 1 }'
