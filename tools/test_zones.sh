#!/bin/sh
# Check that no zone's display list gets near full in late, crowded waves
# (wave 12 on, rocks left to pile up): the fullest zone under 80% of its
# space, and the game loop never stuck (no frame it didn't run, 4 in a row).
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$("$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/zonetest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^zone|^wave|^worst")
echo "$OUT" | grep -v "^worst"
echo "$OUT" | sed -n 's/^worst //p' | awk '{ if ($1 * 5 < $3 * 4 && $5 < 4) { print "zone test: PASS"; exit 0 } print "zone test: FAIL"; exit 1 } END { if (NR == 0) { print "zone test: FAIL (no results from the emulator)"; exit 1 } }'
