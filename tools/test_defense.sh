#!/bin/sh
# The planet's defences: docked, no shuttle is lost; camped anywhere in the
# band (its top, middle, foot) the pulses find it; the loop keeps full speed.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
run() { HOVER=$1 "$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/defensetest.lua" -skip_gameinfo -nomouse 2>&1 | grep hovering; }
OK=1
# (fields: "hovering at line N: P pulses, L shuttles lost; loop ran R of T frames")
for y in 0 100 124 148; do
  R=$(run $y); echo "$R"
  echo "$R" | awk -v y=$y '{ ok = ($12 == $14) && (y == 0 ? $7 == 0 : $7 > 0); exit !ok }' || OK=0
done
[ $OK = 1 ] && echo "defense test: PASS" || { echo "defense test: FAIL"; exit 1; }
