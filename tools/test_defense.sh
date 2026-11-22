#!/bin/sh
# The planet's defences: above the guns' range (line 84) no shuttle is lost;
# in it (line 140) pulses hit; the loop keeps full speed while they fire.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
run() { HOVER=$1 "$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/defensetest.lua" -skip_gameinfo -nomouse 2>&1 | grep hovering; }
HI=$(run 84); LO=$(run 140)
echo "$HI"; echo "$LO"
# (fields: "hovering at line N: P pulses, L shuttles lost; loop ran R of T frames")
echo "$HI $LO" | awk '{ if ($7 == 0 && $22 > 0 && $12 == $14 && $27 == $29) { print "defense test: PASS"; exit 0 } print "defense test: FAIL"; exit 1 }'
