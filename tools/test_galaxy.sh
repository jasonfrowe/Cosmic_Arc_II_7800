#!/bin/sh
# The galaxy generator against DESIGN.md 3.2's rules, for several seeds: 64
# sectors on the grid, every warp to a sector, all reachable from home and
# home from all (one-way warps can't cut any off), numbered by distance,
# ports (home, 2+ in safe space, 1+ a tier), no nebula in safe space.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OK=1
for s in 1 2 3 17 42 99 123 200; do
  OUT=$(SEED=$s "$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
    -autoboot_script "$ROOT/tools/emu/galaxytest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^seed|^result")
  echo "$OUT" | grep "^seed"
  echo "$OUT" | grep -q "^result 1" || OK=0
done
[ $OK = 1 ] && echo "galaxy test: PASS" || { echo "galaxy test: FAIL"; exit 1; }
