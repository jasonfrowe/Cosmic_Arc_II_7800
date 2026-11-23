#!/bin/sh
# The relic: its signal, landing for it, heavy to carry, aboard, paid for at a port.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$("$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/relictest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^relic|^result")
echo "$OUT" | grep -v "^result"
echo "$OUT" | grep -q "^result 1" && echo "relic test: PASS" || { echo "relic test: FAIL"; exit 1; }
