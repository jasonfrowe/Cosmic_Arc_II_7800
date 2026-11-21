# Engine notes

How the cart, the build and the code fit together. Design is in
[DESIGN.md](DESIGN.md); this file covers how it's built.

## Build and run

```
tools/build.sh                 # -> build/cosmicarc.a78 (needs wasmtime)
tools/play.sh                  # the a7800 fork, SaveKey in port 2, -nomouse
tools/snap.sh ROM DIR 60,120   # headless: screenshots + DIR/sound.wav
cmake -B build && cmake --build build   # the same build, through CMake
```

`tools/build.sh` runs `tools/music.py` (writes `src/gen/music.asm`), copies
`src/` and every `.asm` flat into `build/work` (7800basic turns an inline
file's path into a symbol name, so a `/` breaks it), runs the vendored
7800basic, then `tools/a78header.py` finishes the header.

`tools/snap.sh` (through `tools/emu/snap.lua`) takes, in the environment:

- `POKES="frame:addr:value,..."` (hex): write memory at given frames, for
  example `POKES=300:2502:0C` solos POKEY 2.
- `INPUTS="from-to:Field;..."`: hold a control over a frame range, for example
  `INPUTS="300-305:P1 Button 1;400-500:P1 Right"`.
- `AUTOPLAY=frame`: from then on, aim at the nearest rock and fire. Every 600
  frames it prints the wave, score, energy, the frames in which the game loop
  ran (600 = full speed) and the most rocks seen.

The 7800 BIOS runs first, so the game starts about 200 frames in. In MAME,
"P1 Button 1" is 7800basic's `joy0fire1`.

`tools/gfx.py` makes the PNGs in `src/gfx/` from ASCII art (run it with
`.venv/bin/python`; it needs Pillow). The PNGs are committed, so the build
doesn't need it.

## Cartridge

272K SuperGame, the same layout as Atari Gamma Force (cart type `$044A`: the
mapper is `a78_p450_ta` in the emulator):

| Bank | Where | Holds |
|---|---|---|
| 1 | $4000, fixed | the game, the engines, the music player and data |
| 2-16 | $8000, switched (`sta $8000` with bank - 2) | one per mode / biome / music set (DESIGN.md 7.2) |
| 17 | $C000, fixed | graphics (MARIA reads them at any time), 7800basic's runtime |

For now each switched bank holds only a signature, `"CA", n`, at $8000, which
the boot check reads.

Header (`tools/a78header.py` over what 7800basic writes):

| Byte | Value | |
|---|---|---|
| 53-54 | bit 10 added | second POKEY at $0440 (bit 6, $0450, comes from `set pokeysupport $450`) |
| 58 | 2 | SaveKey / AtariVox |
| 59-61 | `ACM` | AstroCart math unit |
| 67 | 3 | v4 audio: POKEYs at $0440 + $0450 |

## Hardware

- **Math unit** (`src/asm/mathunit.asm`): equates from the AstroCart V4
  repo's `docs/MATHUNIT.md`, the definition. (Spacewar's copy of that doc is
  out of date.) It's also the only random number generator: read `M_RND`
  with `LDA abs`.
- **POKEYs**: the AstroCart's are sound only. There's no `RANDOM`, keyboard
  or pots, and no register can be read back to detect them.
- **SaveKey** (`src/asm/savekey.asm`): `sk_read` / `sk_write` over
  7800basic's `i2c7800.inc`. Writes stay inside one 64-byte page and poll
  the chip until its write cycle ends.

## Sound

`src/asm/sound.asm` is Super Mega Pinball 7800's player: four voices.

| Voice | Chip | |
|---|---|---|
| 0 lead | POKEY 1 ($0450) ch 1+2, 16-bit | |
| 1 bass | POKEY 1 ch 3+4, 16-bit | |
| 2 harmony / arpeggio | POKEY 2 ($0440) ch 1+2, 16-bit | |
| 3 drums | POKEY 2 ch 3, 15 kHz clock | |
| effects | TIA channels 0, 1 | `sfx` with an `SFX_` id |

`mus_play` (A = song) starts a song; `snd_tick` runs from 7800basic's
`userinterrupt` every frame. `mus_mask` (bits 0-3) mutes voices. The
songs and effects are written in `tools/music.py`.

## RAM

| Where | What |
|---|---|
| zero page $B0-$B5 | sound.asm (7800basic's tracker block, unused) |
| zero page $B6-$B8 | savekey.asm |
| zero page $B9-$BC | hwtest.asm |
| $2300-$23FF | space.asm: rocks, bolts, the HUD's text |
| $2500-$255F | sound.asm |
| $2580-$2584 | savekey.asm |
| $2590-$259F, $2600-$26FF | hwtest.asm (the boot check; reusable later) |
| $1880-$1FFF | 7800basic's display lists (8-line zones, 192 lines) |

7800basic leaves $2200-$27FF free. The save block (DESIGN.md 7.5) will go
at $2200.

## Display

160A, 8-line zones, 192 lines (24 rows): row 0 and row 23 are the HUD, rows
1-22 the playfield (y 8-183). Text is doublewide: 8 pixels a character, 20
across. The font is ASCII 32-95, so a character's code is (ASCII - 32) * 2
(`text.asm`). 7800basic's `alphachars` maps literal strings the same way.
Stars are one-character objects saved with `savescreen`. Each frame does
`restorescreen`, then the sprites (`plotsprite`), then the HUD (`plotchars`
from RAM).

Deep space geometry: the Ark's centre is (80, 95). The 8 lanes leave it
straight up/down/across, or diagonally at 1 pixel across for 2 lines (45° on
screen, since a 160A pixel is about two lines wide). Rocks enter on a lane
and fly at the centre, and bolts start from the aim marker on the same lane.
The math unit works in "square" units (x doubled) so speeds look the same in
every direction.

## Pitfalls found so far

- **No `SUBROUTINE` in our assembly.** 7800basic's labels start with a dot
  (`.userinterrupt`, ...), which dasm treats as local labels. A
  `SUBROUTINE` in an inline file starts a new scope, and 7800basic's runtime
  then can't see them: `ifconst .userinterrupt` failed, and the NMI never
  called the music player. Use plain labels prefixed with the routine's
  name (`snd_tick_go`), as Gamma Force does.
- A 7800basic `dim` and an assembly label can't share a name. Give asm
  strings and tables their own names (`hw_lt0`, not `hw_l0`).
- Don't `dim` a name that's one of 7800basic's one-letter variables (`i`,
  `t`, `x`...): they're already defined. Use them as they are.
- `plotsprite` won't take array elements (`rk_x[i]`): copy them into
  variables first.
- 7800basic wants PNGs with small palettes: save them 2-bit (`bits=2`).
- dasm has a line length limit: split long `.byte` lines (music.py does).
- `sfx` uses X and Y: reload loop registers after calling it.
- Buttons: `joy0fire1` is button 1 (and a one-button stick's), `joy0fire0`
  button 2, as in Gamma Force and Spacewar.

## Emulator fork changes (~/Software/a7800)

- The second POKEY at $0440 now also works on SuperGame carts (`a78_p450_t2`,
  `_t6`, `_ta`), not only flat ones (`a78_slot.cpp`, `rom.cpp/h`).
- **SaveKey** controller (`-joy2 savekey`, `src/devices/bus/a7800_ctrl/savekey.cpp`):
  a 24LC256 with 2-byte addresses (MAME's `i2cmem` only does 8-bit),
  stored in `nvram/a7800/joy2_savekey` (32K). The driver now passes
  controller pins as the RIOT drives them, from both the port A output
  and the data direction register, since the I2C code drives SDA through
  the direction register.
- Still to do: the same dual-POKEY change in js7800_astrocart for the browser
  build.
