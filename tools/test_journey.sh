#!/bin/sh
# The map's loop: New Game to the map; a warp with no fuel drifts into an
# encounter, cleared, and the Ark arrives at its destination on the map; it
# lands on a planet and comes back to the map.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$("$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/journeytest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^map|^result")
echo "$OUT" | grep -v "^result"
echo "$OUT" | grep -q "^result 1" && echo "journey test: PASS" || { echo "journey test: FAIL"; exit 1; }
