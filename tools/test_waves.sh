#!/bin/sh
# Play 11 waves (the laser and fighter autopilots, energy held full) and check:
# no wave clears with a pirate still about, and the rocks' music comes back
# after the pirates are destroyed.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$(WAVELOG=1 AUTOPLAY=330 AUTOFIGHTER=330 INPUTS="300-305:P1 Button 1" SNAP_FRAMES=10000 \
  "$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -joy2 savekey -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/snap.lua" -skip_gameinfo -nomouse 2>&1 | grep "state [0-9] song")
CLEARS=$(echo "$OUT" | grep -c "state 1 song")
BAD=$(echo "$OUT" | grep "state 1 song" | grep -E "slots [^|]*[123] ")
BACK=$(echo "$OUT" | awk '/song 2/ { p = 1 } /state 0 song 1/ && p { n++ ; p = 0 } END { print n + 0 }')
echo "waves cleared: $CLEARS; cleared with a pirate about: $(echo "$BAD" | grep -c state); rocks music back mid-wave: $BACK times"
[ -z "$BAD" ] && [ "$CLEARS" -ge 5 ] && [ "$BACK" -ge 3 ] && echo "wave test: PASS" || { echo "$BAD"; echo "wave test: FAIL"; exit 1; }
