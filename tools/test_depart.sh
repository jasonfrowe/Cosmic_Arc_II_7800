#!/bin/sh
# Leaving a port (or planet) in a dangerous sector: an encounter some of the
# time, its wave set by the jumps back to safe space.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$("$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/departtest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "departures|^result")
echo "$OUT" | grep -v "^result"
echo "$OUT" | grep -q "^result 1" && echo "depart test: PASS" || { echo "depart test: FAIL"; exit 1; }
