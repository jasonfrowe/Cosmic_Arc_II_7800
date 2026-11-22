#!/bin/sh
# The planet's cargo: ore beamed up with button 1 slows the shuttle across to
# half its top speed; button 2 drops it, and it falls and lands.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$("$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/cargotest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^ore|^result")
echo "$OUT" | grep -v "^result"
echo "$OUT" | grep -q "^result 1" && echo "cargo test: PASS" || { echo "cargo test: FAIL"; exit 1; }
