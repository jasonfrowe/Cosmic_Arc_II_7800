#!/bin/sh
# Check that pirates never leave the screen or wrap round its edges.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$("$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/edgetest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^pirate|^edges")
echo "$OUT" | grep "^pirate"
echo "$OUT" | sed -n 's/^edges //p' | awk '{ if ($1 == 0 && $2 == 0) { print "edge test: PASS"; exit 0 } print "edge test: FAIL"; exit 1 }'
