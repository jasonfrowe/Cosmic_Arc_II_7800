#!/bin/sh
# Rocks take the same time to reach the Ark from every lane (up/down,
# diagonal, across): within 10% of each other, two or more rocks of each.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$("$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/arrivaltest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^frames|^result")
echo "$OUT" | grep -v result
echo "$OUT" | sed -n 's/^result //p' | awk -v N="$(echo "$OUT" | grep -oE '\([0-9]+\)' | tr -d '()' | sort -n | head -1)"  '{ lo = $1; hi = $1; for (i = 2; i <= 3; i++) { if ($i < lo) lo = $i; if ($i > hi) hi = $i }
  if (N >= 2 && lo > 0 && hi / lo <= 1.10) { print "arrival test: PASS"; exit 0 } print "arrival test: FAIL"; exit 1 }'
