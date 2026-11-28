#!/bin/sh
# Check that rocks (and the pieces they split into) stay on their lanes:
# every rock's centre within 1.5 pixels of its lane line.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$("$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/lanetest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^lane|^worst")
echo "$OUT"
W=$(echo "$OUT" | sed -n 's/^worst //p')
awk -v w="$W" 'BEGIN { if (w == "") { print "lane test: FAIL (no results from the emulator)"; exit 1 } if (w <= 1.5) { print "lane test: PASS"; exit 0 } print "lane test: FAIL"; exit 1 }'
