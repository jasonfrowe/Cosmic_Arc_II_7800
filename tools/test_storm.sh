#!/bin/sh
# The storm (as Cosmic Arc's): docked, the Ark's laser shoots the rock down
# (the Ark unhurt, the planet over); with the shuttle out, the rock hits the
# Ark and the planet's over.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
run() { DOCKED=$1 "$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/stormtest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^docked|^shuttle|^result"; }
A=$(run 1); B=$(run 0)
echo "$A" | grep -v result; echo "$B" | grep -v result
RA=$(echo "$A" | sed -n 's/^result //p'); RB=$(echo "$B" | sed -n 's/^result //p')
[ "$RA" = "1 0 1" ] && [ "$RB" = "1 1 1" ] && echo "storm test: PASS" || { echo "storm test: FAIL"; exit 1; }
