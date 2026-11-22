#!/bin/sh
# Play the waves (the laser and fighter autopilots, energy held full) and
# check: every wave runs its 8 rounds of rocks with all its pirate waves
# between rounds 4 and 5 before it clears; none clears with a pirate still
# about; and the rocks' music comes back after the pirates.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$(NOPLANET=1 WAVELOG=1 AUTOPLAY=330 AUTOFIGHTER=330 INPUTS="300-305:P1 Button 1" SNAP_FRAMES=30000 \
  "$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -joy2 savekey -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/snap.lua" -skip_gameinfo -nomouse 2>&1 | grep "state [0-9] song")
CLEARS=$(echo "$OUT" | grep -c "state 1 song")
BAD=$(echo "$OUT" | grep "state 1 song" | grep -E "slots [^|]*[123] ")
# a clear before round 8, or with pirate waves still to come
EARLY=$(echo "$OUT" | grep "state 1 song" | awk '{ split($9, p, "/"); if ($6 != 8 || p[1] != p[2]) print }')
BACK=$(echo "$OUT" | awk '/song 2/ { p = 1 } /state 0 song 1/ && p { n++ ; p = 0 } END { print n + 0 }')
PIRW=$(echo "$OUT" | awk '{ split($9, p, "/"); if (p[1] > m) m = p[1] } END { print m + 0 }')
echo "waves cleared: $CLEARS; cleared early: $(echo "$EARLY" | grep -c state); cleared with a pirate about: $(echo "$BAD" | grep -c state); most pirate waves in a wave: $PIRW; rocks music back: $BACK times"
[ -z "$BAD" ] && [ -z "$EARLY" ] && [ "$CLEARS" -ge 4 ] && [ "$BACK" -ge 3 ] && [ "$PIRW" -ge 3 ] \
  && echo "wave test: PASS" || { echo "$BAD$EARLY"; echo "wave test: FAIL"; exit 1; }
