#!/bin/sh
# What a player notices on a planet: the shuttle's bullets outrun it, docking
# from near the Ark by just pushing up takes under 2 s, undocking by holding
# down under 2 s.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$("$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/feeltest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^bullets|^docking|^undocking|^result")
echo "$OUT" | grep -v "^result"
echo "$OUT" | sed -n 's/^result //p' | awk '{ if ($1 >= 10 && $2 >= 0 && $2 <= 2 && $3 >= 0 && $3 <= 2) { print "feel test: PASS"; exit 0 } print "feel test: FAIL"; exit 1 }'
