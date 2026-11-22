#!/bin/sh
# The storm (as Cosmic Arc's), from each way the rock comes (top, left,
# right): unanswered, it's in sight 1.5 s or more before it hits the Ark;
# docked and firing (after half a second), the Ark shoots it down unhurt and
# the planet's over; with the shuttle out, it hits the Ark (16).
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
run() { DOCKED=$1 DIR=$2 HOLDFIRE=$3 "$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/stormtest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^docked|^shuttle|^result"; }
OK=1
for d in 0 1 2; do
  W=$(run 1 $d 1); echo "unanswered: $W" | grep -v result
  [ "$(echo "$W" | sed -n 's/^result //p')" = "1 1 1 1" ] || OK=0
  A=$(run 1 $d 0); echo "$A" | grep -v result
  [ "$(echo "$A" | sed -n 's/^result //p' | cut -d' ' -f1-3)" = "1 0 1" ] || OK=0
done
B=$(run 0 1 0); echo "$B" | grep -v result
[ "$(echo "$B" | sed -n 's/^result //p' | cut -d' ' -f1-3)" = "1 1 1" ] || OK=0
[ $OK = 1 ] && echo "storm test: PASS" || { echo "storm test: FAIL"; exit 1; }
