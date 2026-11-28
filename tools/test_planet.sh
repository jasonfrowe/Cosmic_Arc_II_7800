#!/bin/sh
# A planet from the title (Select), the autopilot: at least one creature
# caught, the planet ends and play goes back to deep space, and the planet's
# loop ran in (nearly) every frame.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$("$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/planettest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^caught|^result")
echo "$OUT" | grep "^caught"
echo "$OUT" | sed -n 's/^result //p' | awk '{ if ($1 >= 1 && $4 == 1 && $2 * 100 >= $3 * 97) { print "planet test: PASS"; exit 0 } print "planet test: FAIL"; exit 1 } END { if (NR == 0) { print "planet test: FAIL (no results from the emulator)"; exit 1 } }'
