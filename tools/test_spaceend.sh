#!/bin/sh
# Deep space endings: the Ark waits for the saucer before it leaves a cleared
# wave; when the Ark is lost, the pirates leave (within 6 s); the stars'
# glyph cells survive the saucer flying (they're drawn straight from RAM).
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
cd "$(dirname "$A7800")"
run() { MODE=$1 "$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -video none -sound none -nothrottle \
  -autoboot_script "$ROOT/tools/emu/endtest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^saucer|^the Ark|^the stars|^result"; }
A=$(run saucer); B=$(run over)
echo "$A" | grep -v result; echo "$B" | grep -v result
[ "$(echo "$A" | sed -n 's/^result //p')" = "1 0" ] && [ "$(echo "$B" | sed -n 's/^result //p')" = "1 1" ] \
  && echo "space end test: PASS" || { echo "space end test: FAIL"; exit 1; }
