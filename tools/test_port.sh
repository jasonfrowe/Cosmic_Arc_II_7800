#!/bin/sh
# A starport: commodities sold and bought at the tier's prices, a creature's
# bounty, one kept for the manifest, refuelling, repair, the laser upgrade,
# and an upgrade too dear left alone.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$("$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/porttest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^port|^result")
echo "$OUT" | grep -v "^result"
echo "$OUT" | grep -q "^result 1" && echo "port test: PASS" || { echo "port test: FAIL"; exit 1; }
