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
- `AUTOFIGHTER=frame`: launch the fighter and fly it at the nearest pirate
  or pod, firing when lined up.
- `AUTOPLAY=frame`: from then on, aim at the nearest rock or pirate and fire. Every 600
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
| 1 | $4000, fixed | the BASIC (game flow, the escape scene), banks.asm, text, text40 (the 40-column screens' rows and helpers; the achievements' checks), the sound player, effects, the SaveKey, saved voyages (save.asm), the hardware check |
| 2 | $8000, switched | deep space: space, fighter, pirates, vec, draw |
| 3 | $8000, switched | the planet: surface.asm and its map (MARIA reads the map as it draws) |
| 4 | $8000, switched | the map: sector.asm; the 40-column font at $A000; port.asm (the build's "bytes left" counts only after port.asm: about 4.7K more is free before the font) |
| 5 | $8000, switched | the music (gen/music.asm) |
| 6 | $8000, switched | the close-up chart and the achievements (achieve.asm), the voyage screen (voyages.asm); a copy of the 40-column font at $A000 (`font320b.asm`) |
| 7-16 | $8000, switched | to come |
| 17 | $C000, fixed | graphics (MARIA reads them at any time), 7800basic's runtime |

`bank_in` (`banks.asm`, A = bank) switches a bank in (`sta $8000` with the
bank - 2) and remembers it in `cur_bank`. Bank 2 goes in at boot and stays in,
because the BASIC calls deep space straight (`sp_new`, `sp_frame`, `sp_draw`). The
hardware check switches every bank through, then puts `cur_bank` back.
What must stay in a fixed bank: anything the NMI runs (the music player, its
data, the effects), anything called while another bank is in (`mu_switch`,
`sfx`), and graphics. Each switched bank still starts with its "CA", n
signature at $8000.

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
  the chip until its write cycle ends. The voyages (`save.asm`): `sl_save`,
  `sl_load`, `sl_clear`, `sl_resume` (DESIGN.md 7.5b). The boot check uses
  the byte at `$7FC0`; the slots `$7400-$79FF`.

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

## The map's screens (320A)

The sector view and star chart are 320A with 1-byte characters: 40
columns. 7800basic puts its saved `sCTRL` and `sCHARBASE` into MARIA at
every `drawscreen`, so `sv_enter` sets them ($43, the 40-column font) and
`sv_leave` puts the game's back ($50, `font`). The font (`font320.asm`,
from `tools/gfx.py`) is in bank 4 at $A000 (the same 4K pattern as the
game's font at $C000, safe from holey DMA), glyph n at byte 2n so the text
codes are the game's. Each glyph line is a page; page p is line 15 - p.
Text is 12 rows of 40 in the planet's RAM ($2200, $2700: free on the map).
Every colour of a palette is set the same (320A), so an object is one
colour: `text40.asm` draws each row as segments split where the colour
changes (`sv_ink`: a column and a palette, up to 10 a row, sorted;
`sv_pen` at the write position), each at most 32 wide, and only as far as
the row's last character (blank rows cost MARIA nothing). Inverse text is
the font's odd codes (code + 1: an 8-line bar with the letter cut out;
`sv_inv`). The palettes (`mappal`): 0 white, 1 gold, 2 cyan, 3 grey, 5
green, 6 red, 7 blue (4-7 also the achievements' icons). Every map page has
the tab bar (`sv_tabbar`) and the status panel (`sv_status`), both in bank 1.

The star chart (`ch_build`): a node every 3 characters (column 2 + 3x, row
1 + y), then two lane characters, A and B. A lane's bits (1 across, 2
down-right, 4 down-left) are OR'd into A (codes 160 + 2k); `ch_fillb` then
sets B from A (`ch_linkb`). The diagonals run from node centre to node
centre over A, B and the lower half of the row. The text is all grey; the
visited ports, planets and nebulae and the Ark's sector are one-character
objects on top in their colour (`ch_nodes`, each frame), their cells in the
text blank (248, or 250 with the lane down). So the chart needs no colour
changes in its rows, and a node's lane down stays grey.

## Graphics blocks

7800basic fills a graphics block a line (256 bytes) at a time, in
`incgraphic` order, and moves on to the next block ($E000) when a line is
full. The code finds a frame as the first frame's address plus frame x
width, so **every group of numbered frames must stay in one block**:
`tools/gfxcheck.py` fails the build if a group is split. (The creatures
split once when the font grew: frames 6-23 read glyphs.) The font is 180
bytes of a line; the creatures come straight after it.

## RAM

| Where | What |
|---|---|
| zero page $B0-$B5 | sound.asm (7800basic's tracker block, unused) |
| zero page $B6-$B8 | savekey.asm |
| zero page $B9-$BC | hwtest.asm |
| $2300-$23FF | space.asm: rocks, bolts, the HUD's text |
| $2400-$24FF | fighter.asm, pirates.asm, vec.asm, draw.asm: the fighter, shots, pirates, pods |
| $2700-$27FF | surface.asm: the planet (shuttle, camera, creatures, crates) |
| $2200-$22FF | surface.asm: the planet's turrets and their shots |
| $2500-$256A | sound.asm: the music player (six voices) |
| $257A-$257F | sound.asm: the TIA effects |
| $22E0-$22F1 | surface.asm: the planet scanner's line (18 characters, its ends included; the map's text there otherwise) |
| $2575-$2577 | the stars' twinkle counter; the dim and bright stars' glyph cells (BASIC; plotchars draws from RAM: these must never be reused) |
| $2580-$2584 | savekey.asm |
| $2591 | save.asm: the voyage's slot + 1 (`gs_slot`; 0 not saved) |
| $23D0-$23D8 | save.asm: the header, scratch (deep space's message: unused on the map) |
| $23A0-$23B7, $27F9-$27FE | voyages.asm: the slots' summaries (deep space's HUD line), scratch (the port's) |
| $2300-$2377, $2410-$24A0 | text40.asm: the 40-column screens' colour changes and row lengths (deep space's rocks, bolts, shots, pirates: cleared when an encounter starts) |
| $237C-$237F, $24AA, $24B5-$24BF | sector.asm: the chart's cursor, the sector view's items' ways (deep space's too) |
| $2585-$258A | sector.asm: aboard: fuel ore, organics, equipment; upgrade levels (laser, holds, tanks) |
| $256B-$2570 | sector.asm: creatures in stasis by kind (6) |
| $2572, $258E | sector.asm: the planet being landed on: its creatures (`gs_pop`), its level (`gs_plevel`) |
| $25A0-$25FF | sector.asm: the voyage's long-lived block (saved; 11 ports' stock): kept pairs, the bank, port stock and glut, planets' creatures taken, achievements, pirates destroyed, storm rocks, the relic, the restock ticks |
| $2573, $2574, $2578, $258B-$258D | the BASIC's escape scene |
| $2573, $2574, $2578, $258B-$258D, $259E | port.asm's scratch (the escape scene's bytes); $2574 also the energy bar's value |
| $258F, $23FF | common.asm: the hull (most energy), the bar's scale |
| $23FE, $2584, $2571 | text40.asm: achievements (hit this encounter/planet, the one announced, scratch) |
| $2590-$259F | sector.asm: the voyage (sector, fuel, stardate, credits, seed; $259F the tests' flag) (the boot check's before a game) |
| $2600-$26FF | sector.asm: the galaxy by sector (warps, cells, info, flags: visited, seen, jumps to safe space) (the boot check's before a game) |
| $1880-$1FFF | 7800basic's display lists (8-line zones, 192 lines) |

7800basic leaves $2200-$27FF free. A saved voyage is copied straight from
where it lives (save.asm's chunks, DESIGN.md 7.5b).

## Display

160A, **16-line zones**, 192 lines (12 rows): row 0 and row 11 are the HUD,
rows 1-10 the playfield (y 16-175). Each zone's display list has room for 31
objects (`$1880-$1FFF`). `set zoneprotection on` drops objects that won't fit,
rather than letting them overflow into the next zone's list. Text is doublewide: 8 pixels a
character, 20 across, with each glyph's 8 lines at the top of a 16-line
character (`font.png` is 16 tall). The font is ASCII 32-95, so a character's
code is (ASCII - 32) * 2 (`text.asm`). 7800basic's `alphachars` maps literal
strings the same way.
Stars are one-character objects saved with `savescreen`, three kinds (P5's colours 1-3); the BASIC's `twinkle` cycles P5 each frame. Glyphs after the terrain (tools/gfx.py `EXTRA`, codes in text.asm `CH_*`): stars, the planet scanner, HUD icons. The planet HUD draws in P0, whose colours 2 and 3 (yellow, red) text never uses. Each frame does
`restorescreen`, then the sprites (`plotsprite`), then the HUD (`plotchars`
from RAM).

Deep space geometry: the Ark is a 48 x 32 sprite at (56, 80), on a zone
boundary so it costs one object a zone, its centre
(the hull's middle line) at (80, 95), with the fighter's bay underneath. The 8
lanes leave the centre straight up/down/across, or diagonally at exactly 1
pixel across for 2 lines (45° on screen, since a 160A pixel is about two lines
wide). Rocks enter on a lane with their centre exactly on its line. A rock keeps
its lane (`rk_ln`), and its velocity comes from the lane, not from a heading.
Diagonal speeds are s/√2 on the math unit, with vy made even and vx = vy/2
exactly, so rounding can't move a rock off its lane. When a rock splits, the
pieces start at their parent's centre on the same lane. Bolts start from the
aim marker on the lane, and a bolt hit allows a pixel of slack either side.

Deep space's modules: `space.asm` (the Ark, rocks, waves, HUD), `fighter.asm`
(the fighter, any-angle shots, the auto-turret), `pirates.asm` (raiders,
gunships, missiles, pods), `vec.asm` (vectors and steering on the math unit;
one-byte angles, $00 east, $40 down), `draw.asm` (every small sprite). The
BASIC draws only the Ark, a tall sprite. `draw.asm` calls 7800basic's
`plotsprite` directly: temp1/2 is the graphic plus frame × width, temp3 is the
palette × 32 | the width's two's complement, temp4/5 are x and y, and temp6 is
the mode | %01000000. That's what a BASIC `plotsprite` statement compiles to.

Tests (in the emulator, headless):

```
tools/test_aim.sh     # all 8 joystick directions aim the laser
tools/test_lanes.sh   # every rock, split pieces too, within 1.5 px of its lane
tools/test_zones.sh   # late crowded waves: the fullest zone under 80% of its list,
                      # and the game loop never stalls (4+ frames)
tools/test_waves.sh   # 11 waves: none clears with a pirate about; the rocks'
                      # music comes back after the pirates are destroyed
tools/test_edges.sh   # pirates never leave the screen or wrap (84,000 samples)
tools/test_planet.sh  # Select -> a planet: the autopilot catches, the planet ends,
                      # back to space; the loop runs every frame
tools/test_feel.sh    # what a player notices: the shuttle's bullets outrun it;
                      # docking from near the Ark by pushing up < 2 s; undocking < 2 s
tools/test_recall.sh  # the saucer called home through a rock in its way: never dies
tools/test_defense.sh # the planet's pulse: never hits a docked shuttle; finds one
                      # camped at the band's top, middle and foot; full speed
tools/test_galaxy.sh   # the galaxy generator's rules (and jumps to safe space), 8 seeds
tools/test_depart.sh   # leaving an outer-rim port: encounters ~60%, waves by jumps to safe
tools/test_port.sh     # a starport: trading (stock prices), bounties (glut), the
                       # manifest, the shipyard (prices by tier)
tools/test_deplete.sh  # ports restock and planets refill with jumps; a barren
                       # planet can't be landed on; a planet's creatures
tools/test_pod.sh      # the Ark lost: the escape scene, home in a new Ark, a
                       # tenth of the credits, the bank kept
tools/test_ach.sh      # achievements earned and announced; their screen (bank 6)
tools/test_relic.sh    # the relic: signal, landing, heavy, aboard, paid for, RELIC
tools/test_level.sh    # planet levels: L5 far out (rare kinds), L1 at home (common)
tools/test_leave.sh    # leaving a planet early: button 2 held docked, a countdown
tools/test_cargo.sh    # ore beamed up halves the speed across; button 2 drops it
tools/test_journey.sh  # New Game, a warp into an encounter, back on the map, land, back
tools/test_save.sh     # four runs, one SaveKey: saved on docking; Continue; damaged; cleared
tools/test_chart.sh    # the map's pages: warps' ways (one-way >), the chart's cursor,
                       # a warp from the chart, round the tab bar
tools/test_arrival.sh  # rocks reach the Ark in the same time from every lane
tools/test_spaceend.sh # the Ark waits for the saucer before leaving a wave; pirates
                       # leave when the Ark is lost
tools/test_storm.sh   # each way the rock comes: in sight 1.5 s+ unanswered; docked,
                      # the Ark shoots it down unhurt; out, it hits the Ark (16)
```

The deep-space tests set `sp_noplanet` ($23EF) so waves go straight on without
planets (`NOPLANET=1` for `snap.lua`).

`tools/fixbranches.py` turns each "Branch out of range" in the last build's
log into the opposite branch round a `JMP`. Run it, then build again. The
assembly runs long with macros like `PLOT`.

## The planet's scrolling

The ground is one row of `tools/planet.py`'s map. Its surface rises and falls
over three levels, 0, 4 or 8 lines into the row, with slope characters between.
`pl_hd`/`pl_hs` give each column's depth and slope, and `pl_ground` turns a
world x into the surface's line. The row is grass along the surface, soil under it,
glyphs after the font in the same character block, so their codes are 128
on), in zone 10. It's stored 128 + 21 wide: the first 21 columns again at the
end, so a 21-column window never has to wrap. Every frame: `clearscreen`, then
`plotmap pl_map 5 pl_fine 10 21 1 pl_col 0 149`, where `pl_col` = camera / 8
and `pl_fine` = -(camera & 7). An x of 249-255 starts the row off the left
edge, and MARIA wraps it. The camera is the shuttle's world x - 80, and a
thing's screen x is (its x - camera) & 1023 (`pl_scrx`).

`common.asm` (bank 1) holds what both modes use: the `PLOT` macro, the HUD's
bar, the score, centred messages. `vec.asm` moved to bank 1 too.

**MARIA's time on a line:** a row of 21 doublewide characters costs MARIA about
200 of its cycles a line. With a horizon row in zone 9 as well, the sprites
there (creatures, crates, towers, the beam) ran it out of time on the real console,
so the last objects in the list vanished: creatures crossing the screen, and pieces of
the beam. The emulator doesn't limit DMA, so it doesn't show this. The ground is
now one row (zone 10), zone 9 has only sprites, and the creatures are drawn first.
Keep wide character rows out of zones full of sprites.

**Frame time:** the planet loop sits close to a frame. Each `plotsprite` is a few
hundred cycles, and 8 scanner dots and a fourth tower segment pushed it to 30
fps. Things that never move (the towers' and the Ark's scanner marks) are
characters in the scanner's line instead.

**Graphics space:** bank 17's main area is full (0 bytes). In 16-line zones the
graphics share 256-byte-wide rows: the font with its terrain glyphs (144 bytes)
and every sprite so far. Later graphics should go into the bank of the mode that uses
them, which is in while MARIA draws them.

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
- **`if a then x : if b then y` nests**: the second `if` only runs when `a`
  held. That lost the down-diagonal aims (found on hardware). Put one
  condition on each line, or use `&&`. `tools/test_aim.sh` checks all 8 directions.
- `plotsprite` won't take array elements (`rk_x[i]`): copy them into
  variables first.
- 7800basic wants PNGs with small palettes: save them 2-bit (`bits=2`).
- dasm has a line length limit: split long `.byte` lines (music.py does).
- `sfx` uses X and Y: reload loop registers after calling it.
- **Zone overflow.** With 8-line zones (15 objects each), busy waves overfilled
  the zone under the Ark: rocks on the side lanes, the Ark's pieces, stars and
  bolts all landed there. An overflow wrecks the *next* zone's list, so the
  bottom of the Ark and everything near it vanished (found on hardware). Fixed
  with 16-line zones (31 objects, and a sprite touches 2 zones, not 3), the Ark
  on a zone boundary, and `zoneprotection`. `tools/test_zones.sh` watches
  7800basic's `dlend` (zero page $65 on, one byte a zone). The fullest zone in
  wave 22 went from 70/80 bytes to 40/160.
- Don't work a moving thing's heading out again from its rounded velocity:
  the error builds up (small rocks drifted 4 px off their lanes, found on
  hardware). Keep the intent (the lane) and work out from that.
- **A loop that skips a slot before saving its index**, then reloads the
  index from where it's saved, keeps going back to an old slot forever. The game
  hung with a pirate and an empty slot. Save the index first. The zone test now
  fails if the game loop stalls (it passed while hung before).
- **Counting live things once a frame and spawning later in that frame**: a
  check later in the frame doesn't see the new one. A gunship spawned in the
  frame the wave-clear check ran, so the wave cleared with it on screen. Count
  a pirate as soon as it's placed (`pr_place`).
- **`plotmap`'s map width must be a number**: an assembler name there
  (`PL_MAPW`) is read as a variable's address, and the second row read the first
  row's data.
- **A name for both a variable and a routine** (`pl_frame`): give each its own.
- **Many small sprites cost frames**: a tall tractor beam of 8-line pieces (up to
  11 `plotsprite`s) dropped 6% of the planet's frames. 16-line pieces, one a zone,
  fixed it.
- **Calling across switched banks**: a bank-3 routine called `dr_boomf` in
  bank 2, which isn't in on a planet. The assembler can't see it. `tools/bankcheck.py`
  (run by the build) fails a build with a `jsr`/`jmp` from one switched bank into
  another. Shared code goes in bank 1 (`common.asm`).
- **Adding a signed byte to a 16-bit value**: the high byte needs $FF for a
  negative step, and the carry counted once. The blinker's teleport added its
  -64..63 step as unsigned, with the carry counted twice, and threw it 200-500
  pixels across the planet ("creatures jumping around", found on hardware).
- **"Disappearing" can be the design.** Burrowers ducking under and blinkers
  teleporting read as a rendering bug from the player's chair, and made creatures
  impossible to catch. Nothing alive hides now.
- **Test what the player feels, not only what the code does.** Bullets slower than
  the shuttle, the recall path through rocks, and docking that needed pixel-perfect
  lining up all passed the mechanical tests. `test_feel.sh` and `test_recall.sh`
  measure them directly, and each was checked to fail on the old build.
- **Cutting code by label**: search for the label at the start of a line
  (`"\nlabel\n"`), not the first match: a branch to it comes first and the cut
  takes the wrong lines (it happened three times).
- **7800basic's `plotsprite` drops a sprite at x = 0** (the pulse's left half
  vanished). Use x = 1.
- **Sprites cost frames; characters don't.** The planet's scanner dots (5 sprites)
  and tall towers dropped frames. The scanner is now a RAM text line, rebuilt each frame.
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
