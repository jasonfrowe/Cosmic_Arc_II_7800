#!/bin/sh
# What a player notices on a planet: docking from the Ark's doorway by just
# pushing up takes under 2 s, undocking by holding down under 2 s, and flying
# up and away just out of the Ark doesn't dock it again, and docking with up
# held doesn't fire the Ark; flying past and pushing up-and-across docks.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$("$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/feeltest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^docking|^undocking|^flying|^result")
echo "$OUT" | grep -v "^result"
echo "$OUT" | sed -n 's/^result //p' | awk '{ if ($2 >= 0 && $2 <= 2 && $3 >= 0 && $3 <= 2 && $4 == 0 && $5 == 0 && $6 >= 0 && $6 <= 3 && $7 >= 0 && $7 <= 3) { print "feel test: PASS"; exit 0 } print "feel test: FAIL"; exit 1 }'
