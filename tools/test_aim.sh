#!/bin/sh
# Check that all 8 joystick directions aim the Ark's laser (0-7 in order).
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
OUT=$("$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/aimtest.lua" -skip_gameinfo -nomouse 2>&1 | grep aim)
echo "$OUT"
GOT=$(echo "$OUT" | sed 's/.*aim //' | tr -d '\n')
[ "$GOT" = "01234567" ] && echo "aim test: PASS" || { echo "aim test: FAIL ($GOT)"; exit 1; }
