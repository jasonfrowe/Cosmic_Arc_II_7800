#!/bin/sh
# Saved voyages on the SaveKey (save.asm, voyages.asm): four runs of the
# emulator on one nvram directory (a power cycle between each): a voyage
# saved on docking; its summary and Continue; a broken byte reads as damaged,
# cleared; cleared for good, and back to the title (tools/emu/savetest.lua).
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A7800=${A7800:-$HOME/Software/a7800/mame64}
NV=$(mktemp -d)
trap 'rm -rf "$NV"' EXIT
cd "$(dirname "$A7800")"
ok=1
for PHASE in A B C D; do
  if [ $PHASE = C ]; then
    # break a byte of slot 1's galaxy ($7400 + $90)
    python3 -c "import sys; p=sys.argv[1]; b=bytearray(open(p,'rb').read()); b[0x7490]^=0x55; open(p,'wb').write(b)" "$NV/a7800/joy2_savekey" || ok=0
  fi
  OUT=$(PHASE=$PHASE "$A7800" a7800 -cart "$ROOT/build/cosmicarc.a78" -joy2 savekey -nvram_directory "$NV" \
    -video none -sound none -nothrottle -autoboot_script "$ROOT/tools/emu/savetest.lua" -skip_gameinfo -nomouse 2>&1 | grep -E "^save|^result")
  echo "$OUT" | grep -v "^result"
  echo "$OUT" | grep -q "^result 1" || ok=0
done
[ $ok = 1 ] && echo "save test: PASS" || { echo "save test: FAIL"; exit 1; }
