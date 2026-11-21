#!/bin/sh
# Run Cosmic Arc II in the a7800 emulator fork (~/Software/a7800), with a
# SaveKey in port 2. -nomouse leaves the desktop mouse alone.
#   tools/play.sh [more mame options]
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
EMU="${A7800:-$HOME/Software/a7800/mame64}"
ROM="$ROOT/build/cosmicarc.a78"
[ -f "$ROM" ] || "$ROOT/tools/build.sh"
cd "$ROOT"
exec "$EMU" a7800 -cart "$ROM" -joy2 savekey -nomouse -window -skip_gameinfo "$@"
