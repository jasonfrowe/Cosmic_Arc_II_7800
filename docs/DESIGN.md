# Cosmic Arc II: design

A sequel to [Cosmic Arc for the RP6502](https://github.com/jasonfrowe/RP6502-Cosmic-Arc)
(itself a reimagining of the 2600 classic), built for the Atari 7800 with
the AstroCart (MathUnit + second POKEY). The two original phases, defending the Ark in deep space
and abducting creatures from the surface, stay at the core. They now sit
inside a trading-and-exploration layer in the spirit of the BBS game
TradeWars 2002: a galaxy of connected sectors, ports with buy/sell
classes, fuel, cargo and upgrades.

> Status: design draft. The early decisions are recorded in [Decisions](#decisions).
> Hardware reference: the AstroCart V4 FPGA design (`~/Software/FPGA/Atari7800_AstroCart_V4`).

---

## 1. Story frame

The sun of Alpha Ro is failing (from the first game). The Ark has to
cross the Alpha Ro cluster, 64 sectors, and fill its **manifest**, one
specimen of every species, before the star collapses. Ports trade with the
Ark and pirates hunt it. The further you go from the core, the rarer the
creatures and the richer the ports.

The fading star doubles as the game's clock (see §6.4). It gives the
trading layer urgency, so the player can't grind forever.

---

## 2. Core loop

```
        ┌──────────────────────────────────────────────────┐
        ▼                                                  │
  1. PLOT COURSE ── spend Fuel ──▶ 2. TRANSIT ENCOUNTER    │
     (sector map)                   (deep space, maybe)     │
                                         │                  │
                         ┌───────────────┴──────────┐       │
                         ▼                          ▼       │
               3a. PLANET (abduct / mine)   3b. STARPORT    │
                         │                  (trade, repair, │
                         │                   upgrade, save) │
                         └───────────────┬──────────┘       │
                                         ▼                  │
                               4. ESCALATE: go deeper ──────┘
```

One warp is one **turn** and advances the stardate clock by one.

---

## 3. Mode 1: the sector map

### 3.1 Structure

- **64 sectors**, numbered 1-64, sector 1 is home. Sectors 1-10 are
  **Safe Space** (no hostile encounters, like TradeWars' FedSpace).
- Sectors are linked by **warps**, and most are two-way. A few are
  **one-way** (TradeWars style): you can go in but not straight back.
  There are dead ends and a few bottlenecks.
- Distance from sector 1, in warp hops, sets each sector's **threat tier**:

| Tier | Sectors | Encounters | Planets | Ports |
|---|---|---|---|---|
| Safe | 1-10 | none | common species, weak turrets | standard prices |
| Core | 11-15 | slow asteroids | common | standard |
| Mid-Rim | 16-40 | pirate flankers, denser rocks | rare species (3× bounty), shielded turrets | better prices |
| Outer Rim | 41-64 | asteroid storms + pirate squadrons | apex species | Black Market (top-tier upgrades) |

### 3.2 A seeded galaxy

**New Game** takes its seed from the timing of the button press (the frame
count and the MathUnit generator's state when the press comes), and builds the galaxy into RAM with the MathUnit's random generator
(xorshift, `$043E`). The same seed always makes the same galaxy. The seed shows on the pause
screen, but it can't be typed in. The generator has to satisfy these rules,
and otherwise re-rolls:

- Every sector can be reached from sector 1 (one-way warps may not cut
  any part off).
- Sectors 1-10 form a connected Safe Space with at least 2 starports, one of
  them in sector 1 or next to it.
- At least one starport per tier. Black Market ports only in the Outer Rim.
- Every species on the manifest appears on at least one planet, and apex
  species only in the Outer Rim.
- Dead ends lean toward rare planets and salvage (worth the detour).
- Tiers come from the hop distance (breadth-first search from sector 1);
  sector numbers are then given out in order of distance, so a low number
  means safe, as in the table above.

Only the seed and what has changed (visits, stock, populations) need
saving. The galaxy itself is rebuilt from the seed on Continue.

### 3.3 Making the map drawable (technical design decision)

The 7800 can't draw arbitrary lines cheaply, so the galaxy is a **graph laid
out on a hidden grid**: sectors sit on grid cells (for example 12×8), and
a warp only joins a sector to one of its 8 neighbours. Then the whole chart
draws with a handful of tile characters (node, `─`, `│`, `╱`, `╲`, arrowheads
for one-way warps), in 320A or 160A character mode.

Each sector's warps are **one byte**: one bit per compass direction. A warp
is two-way when both ends have the bit set and one-way when only the
source does. So 64 bytes describe the whole graph.

### 3.4 Sector types

| Type | Icon | What's there |
|---|---|---|
| Starport | `P` + class (`BSB`, `SBS`...) | trade, repair, shipyard, save |
| Biosphere planet | green | 2-4 capturable species |
| Resource planet | brown | Fuel Ore / Organics deposits to mine |
| Nebula / asteroid field | grey | high encounter odds, salvage, fuel ore in rocks |
| Empty | - | transit only |

Port classes use TradeWars shorthand over three commodities, **Fuel Ore,
Organics, Equipment**: `B` buys, `S` sells, in that order. `BSB` = buys
Fuel Ore, sells Organics, buys Equipment.

### 3.5 Fog of war

- Unvisited sectors show `?`. Visiting a sector reveals it and its warps.
- **Density Scanner** (cheap, early): shows the threat tier of adjacent
  sectors.
- **Holo Scanner** (expensive): reveals the type of adjacent sectors.
- Port prices in the chart are the ones from your **last visit**.

### 3.6 Screens

- **Sector view** (the default): the current sector's info at the top
  (type, port class, threat), its warps below as a short list to pick
  with the joystick, like TradeWars' "Warps to: 4 - 7 - 12".
- **Galactic chart** (button 2 on the sector view): the full grid, the
  cursor scrolls over it, revealed sectors only.

---

## 4. Mode 2: deep-space combat (transit encounters)

A single-screen arena. The Ark sits in the centre, and the fighter wraps
at the screen edges (Spacewar's arena).

### 4.1 Encounter roll

On arrival in a sector: `chance = base[tier] + nebula bonus - stealth
upgrade`. Safe Space never rolls. The kind of encounter depends on the tier:
an asteroid wave, a pirate ambush, a derelict (salvage pods, a few rocks),
or a mixed storm (Outer Rim). An encounter ends when its wave count is
cleared, the pirates are destroyed or retreat, or the Ark's shields fail.
If the shields fail, the Ark takes hull damage, loses some cargo and
limps on to the destination. It isn't game over unless the hull is gone.

### 4.2 Mothership mode (default)

- Joystick picks one of **8 directions**, and button 1 fires the point-defense
  laser that way. The 2600 asked you to centre the stick between shots.
  Here, holding the button auto-fires at a fixed rate, and each shot
  costs energy.
- **Asteroids come in along the 8 firing lanes**, as the 2600 game's came
  along its 4, so any rock can be shot from where it is. A rock that
  breaks sends both halves on down its lane, one faster than the other.
  Threats that come in *off* the lanes (pirates) are the fighter's job.
- **Energy balance: perfect play breaks even.** A kill pays back exactly the
  energy its shot cost (1 and 1). Missed shots and rocks that reach the Ark
  (16 / 12 / 8 for large / medium / small) are real losses, and they have to
  be made up some other way: creature captures, starports. Clearing a wave
  pays nothing. The knobs are faster rocks in later waves and sectors, and
  weapon upgrades. They're all in one block at the top of `src/asm/space.asm`.
  Energy runs to 96 and fire rate is a bolt every 8 frames (both checked on
  hardware).
- Button 2 **launches the fighter**.

### 4.3 Fighter mode

- **The saucer** from Cosmic Arc (RP6502)'s lander, 8 x 7 with a rim of
  lights that runs round. (A wedge with 16 headings came first. The saucer looks the part.)
- **Directional**: the fighter flies the way the stick points (8 ways).
  Let go and it eases to a stop.
  Its velocity closes an eighth of the gap to top speed in the stick's
  direction each frame, so it has some weight but goes where it's pointed. Button 1
  fires twin blasters the way the stick last pointed. It wraps at the screen's edges.
  (The first version used asteroid-style turn and thrust, which didn't work well.)
- Button 2 recalls the fighter (it flies home on autopilot and docks). Only
  button 2 docks it: flying into the bay doesn't, since that's too easy to do by
  mistake. A dry tether also brings it home.
- **Tether energy** drains while the fighter is out (a full tether lasts
  about 13 s) and recharges only when docked (about 3 s). At zero the fighter
  is forced to recall. This makes the launch → intercept → dock → defend rhythm.
  Hits on the fighter come off the tether too. If damage empties it, the fighter is
  destroyed and the Ark takes 4 s to build another.
- **Energy rule:** the fighter's blasters are free (the tether limits them),
  so its kills pay no energy. The auto-turret's shots cost and pay like the
  laser's. Salvage pods, which only the fighter can pick up, are deep space's
  way to earn energy back.
- While you fly, the Ark runs **auto-turret**: slow tracking of the
  nearest threat (the MathUnit's atan2 picks the aim), its rate set by the Auto-Turret
  upgrade. Its shields absorb stray hits.

### 4.4 Why deploy?

| Only the fighter can... | Only the Ark is good at... |
|---|---|
| chase pirates that flank and hang back out of the laser's line | dense asteroid waves from all sides |
| destroy a pirate carrier's shield generator | heavy single shots that split big rocks |
| grab salvage pods before they drift off-screen | protecting itself (the auto-turret is weak) |

### 4.5 The pirate window

When a wave's first pirate arrives, "PIRATES!" flashes up, and for the next
20 seconds new rocks are **small ones only**, which the auto-turret and the
Ark can handle. That's the window to launch the fighter and engage. It shuts
after 20 seconds, or as soon as the last pirate is destroyed with none still to
come, and then large rocks come back. (`PR_WINDOW` in `space.asm`.) The pirates'
music plays while any are about or coming, and the rocks' music comes back when
the last one goes. Each wave starts with the rocks' music.

### 4.6 Rocks are everyone's hazard

A rock hurts whatever it hits: the Ark, the fighter, a raider or a gunship. A
pirate hit by one takes a hit, and a missile is destroyed. Pirates look ahead
on the MathUnit: they work out where they and every rock will be now, 8 and
16 frames on. If a rock will pass closer than `R_AVOID`, they sidestep across
its path, to the side they're already on, turning twice as fast as normal. A
parked gunship leaves its spot and returns afterwards. In a test with raiders
among dense large rocks, this cut rock hits on pirates from 19 to about 1 a
minute per pirate. The fighter has no autopilot for this: dodging is the
player's job.

Pirates never leave the screen or wrap round its edges: the fighter couldn't
get at them. Their centres stay inside the playfield (`pr_keepin`).

### 4.7 Enemies

- **Asteroids**: large → 2 medium → 2 small (art from the RP6502 game).
- **Raider**: fast, flanks the Ark, strafes and runs. Spacewar AI with lead-angle aiming.
- **Gunship**: slow, parks off the Ark's 8 firing lines and lobs missiles.
- **Carrier** (Outer Rim): launches raiders, protected by a shield
  generator only the fighter can reach.
- **Missiles** can be shot down by the auto-turret.

---

## 5. Mode 3: planetary extraction

The Ark holds high orbit at the top of the screen and the shuttle flies
the surface below.

### 5.0 As built (M3, after playtesting)

The Ark hangs over **one spot** of the planet. It doesn't follow the shuttle,
which has to come back to it: under the Ark it can fly up into the bay to dock
and hand over its cargo (a creature: +12 Ark energy, 500 points; an ore crate:
200 points). Anywhere else it can't climb to the Ark's height. The shuttle
(the saucer) stays at the screen's centre while the ground scrolls under it.
Each cleared deep-space wave goes down to a planet, and the game returns to
space when it's over.

| | Numbers (knobs in `surface.asm`) |
|---|---|
| The surface | 1024 px round (6.4 screens), wraps; the ground is one character row |
| The clock | 60 s, the klaxon from 15 s; time up with the shuttle out: its cargo lost, the Ark -12 |
| The beam | button 1: **the shuttle stops dead**. A creature whose middle is within 5 px rises half a line a frame; unstunned, it **struggles** (a pixel across every 4 frames) and drops if it gets more than 5 px out (unstunned walkers and runners got free about 3 times in 4 in testing). Crates rise a quarter line a frame and halve the climb. |
| Stun pulse | button 2, every 2.5 s: creatures within 36 px stunned 2.5 s (they don't react or struggle), turrets frozen 3.3 s. **Stun, then beam.** |
| Creatures | 2-4 a planet. A low shuttle overhead (within 28 px, below line 96) sets them off: walker turns about at random and hurries, hopper jumps away, runner sprints, burrower digs in, glider (always bobbing between lines 96 and 136) hurries, blinker teleports when the beam touches it |
| Turrets | **a tower every 128 px** (8; one always in view). Each on the screen fires every 45-76 frames at the flying shuttle, aim straying a little. **A hit destroys the shuttle**: its cargo falls, the Ark loses 12, and launches another 2.5 s later |
| All caught | the Ark's energy full again, 1,000 points |

On a planet the Ark can't drop below 1 energy: only deep space ends the game.

### 5.1 The surface

- **Horizontal smooth scrolling** over a surface **4-8 screens wide
  that wraps around** (it's a planet, so the wrap needs no edge rules).
- A **scanner strip** in the HUD shows the whole surface: creatures,
  crates, turrets and the shuttle.
- Planet look (palette, tile set, sky) is picked per biome: jungle, ice,
  desert, volcanic, crystal. Each biome is one ROM bank of tiles.

### 5.2 Controls

- Joystick: fly (left/right with momentum, up/down for altitude).
- **Button 1, tractor beam** (downward cone). Creatures move erratically
  and must be held in the beam until they're pulled aboard. Ore crates
  sit still but are heavy, so the shuttle climbs slowly while carrying one.
- **Button 2, stun pulse**: short range. It freezes a turret or a fast
  creature for a moment, with a cooldown.
- Fly back up into the Ark to unload. The shuttle holds 1 creature (2
  with an upgrade) or 1 crate per trip.

### 5.3 Defenses and timer

- Turrets ride on towers (as in the original) and fire upward. From
  Mid-Rim on, they're shielded until stunned.
- **Orbital warning**: after a set time, a klaxon (a meteor storm is
  coming). The shuttle has to dock before the countdown ends, or it's lost
  with its cargo (the Ark keeps a spare at a repair cost, see §6).
- Catch every species on a planet before the klaxon for an energy
  refill and a bonus, as in the original.

### 5.4 Species

- The manifest starts at **about 24 species** (6 per tier plus 6 apex). The count
  can change to fit ROM, sprite budget and balance. The art starts from the
  RP6502 game's beasties. Each one has a movement
  pattern (hop, burrow, flee the beam, swarm, glide, teleport) and a
  bounty.
- A planet holds 2-4 species and a finite number of each. Planets
  repopulate slowly with the stardate.

---

## 6. Mode 4: starports and the economy

### 6.1 Screen

320A text menus (Gamma Force's cutscene text path) with three tabs:

1. **Commodities**: buy/sell Fuel Ore, Organics, Equipment according to
   the port class. Prices depend on the port's tier and its stock. Stock
   drains as you trade and refills with the stardate, so you can't milk one
   port forever.
2. **Bio-Bounty**: hand in creatures for credits, or **keep one
   specimen of each species** in stasis for the manifest. The choice
   between selling now and keeping for the win is the economy's central
   tension.
3. **Shipyard**: repair the hull, buy fuel, buy upgrades.

Docking at a port also **saves the game** (SaveKey).

### 6.2 Resources

To keep the HUD readable, there are only four meters:

| Resource | Spent on | Restored by |
|---|---|---|
| **Fuel** | warps (1, or 2 into a nebula) | buying it, mining Fuel Ore |
| **Energy** (shields + laser) | taking hits, firing | refills after each encounter / planet |
| **Hull** | shield failures, shuttle losses | repair at a port (credits) |
| **Fighter tether** | time deployed | docking |

Plus **Credits**, **Cargo holds** (commodities and crates), and **Stasis
bays** (creatures).

### 6.3 Upgrades (tiered, 3 levels each)

Point-defense laser (faster fire, bolts that pierce a rock, a cheaper shot) ·
Cargo holds · Stasis bays · Fuel tanks · Auto-turret AI · Fighter thrusters
· Fighter blasters · Tether capacity · Tractor beam width · Shuttle hold ·
Density / Holo scanner · Stealth (fewer encounters) · Hull plating. The
Black Market sells level 3 and the unique items.

### 6.4 The clock, and no soft-locks

- **Stardate**: one per warp. Alpha Ro collapses at a fixed stardate (for
  example 400). The HUD shows the star's state. Ports restock and planets
  repopulate as it runs.
- **Out of fuel**: **Emergency Drift** to a random adjacent sector, which
  forces a high-intensity encounter with shields down. Alternatively, mine Fuel Ore by
  shooting rocks in an asteroid-field sector, where the fragments are
  tractor-beam pickups.
- **Broke and damaged**: Safe Space ports always sell 1 fuel and patch the hull
  to 25% for free once per N stardates.

### 6.5 Ending and score

- **Win**: the manifest is complete. Then, warp back to sector 1 before
  the collapse, and the ending plays.
- **Lose**: the hull is destroyed, or the star collapses first. You get partial credit
  for each species saved.
- **Rank** (Cadet → Admiral) from the score: species saved, credits,
  pirates destroyed, stardates to spare. It goes in the high-score table.

---

## 7. Technical plan

### 7.1 Toolchain

**Decided:** 7800basic for game flow, menus and data, plus assembly for
the engines, as in Gamma Force. Gamma Force already has the pieces this
game needs: SuperGame banking, a POKEY player, hiscore/SaveKey through
`hiscore.asm`, a smooth-scroll engine and 320A cutscene text. Its build
(`tools/build.sh`, the vendored 7800basic, the CMake wrapper) is the
template.

### 7.2 Cartridge

- **SuperGame bank switching from day one**, starting at 272K as in Gamma
  Force: a fixed bank at $4000, 16K banks switched at $8000, the last bank
  fixed at $C000.
- The modes don't overlap, so **each mode gets its own bank(s)**, and a
  mode change is a bank switch plus a screen rebuild:

| Bank | Contents |
|---|---|
| fixed $4000 | main loop, game state, mode dispatcher, music player, math helpers |
| 2 | sector map + chart + galaxy data |
| 3 | starport menus, economy tables, text |
| 4-5 | deep-space combat (code + sprites) |
| 6 | planet engine (horizontal scroll) + shuttle/creature code |
| 7-11 | planet biomes: tiles, species sprites |
| 12-14 | music (dual-POKEY tracks) |
| 15-16 | title, intro/ending cutscenes, high-score table |
| fixed $C000 | font, HUD, shared sprites |

- Header: `ACM` at bytes 59-61 (MathUnit), POKEY at $0450 (bit 6) and $0440
  (bit 10 / v4 audio byte 67 = 3, as in Pinball's `tools/a78header.py`), SaveKey in byte 58.

### 7.3 Hardware reference and tool gaps

The **AstroCart V4 FPGA design** is the hardware reference. It runs
SuperGame up to 512K (and up to 255 banks / 4 MB), two POKEYs at
`$0450` + `$0440`, and the MathUnit, all on the console, and it has been
tested with Gamma Force, Spacewar and Pinball. Its `docs/MATHUNIT.md` is the
register definition that the emulator's `astromath.h` matches bit for bit.

Limits of the real cart that the game has to respect:

- **POKEY is the sound half only.** There's no POKEY `RANDOM`, keyboard or
  pots. All randomness comes from the MathUnit's `RND` (`$043E`). Read it
  with `LDA abs`, since read-modify-write and page-crossing indexed reads step
  it more than once.
- **No banked RAM, no XM.** RAM is the console's 4K, plus the optional 16K
  of cart RAM at `$4000` (SuperGame "with RAM") if we ever need it. That
  would give up Gamma Force's fixed ROM bank at `$4000`, so we keep the fixed
  bank unless RAM runs out.
- **The cart's own saving is High Score Cart only.** A SaveKey is a
  joystick-port device, separate from the cart, so it works on the real
  console.

Gaps in our tools, to close in M0:

1. **Dual POKEY with bank switching in the emulator.** In
   `a7800/src/devices/bus/a7800/a78_slot.cpp:511` the second POKEY is turned on
   only for `A78_TYPE0 + A78_POKEY0450` (no bank switching), and the `$0440`
   device change is still uncommitted in the fork's working tree. Needed: a
   `pokey440` in `a78_rom_p450_sg_device`, the same rule for SuperGame,
   and the same change in js7800_astrocart if it doesn't have it.
2. **SaveKey in the emulator.** The fork supports the High Score Cart
   (`hiscore.cpp`) but logs "SaveKey ... not supported". Add a 24LC256 SaveKey
   on joystick port 2 to the fork. A save slot of about 350 bytes (§7.5) needs its
   own reserved range in the SaveKey address map. **Fallback** for players
   without a SaveKey: the High Score Cart (the AstroCart has one built in).
   It has 2K in all, shared with every other HSC game through the HSC
   ROM's table directory. M6 checks whether a save of about 290 bytes fits
   there without disturbing other games' tables. If it doesn't, the save
   gets cut down to what fits (seed, ship, manifest, stardate, with the
   galaxy's changes reset), or Continue needs a SaveKey.
3. **MathUnit docs.** `Spacewar_7800/docs/MATHUNIT.md` lists offsets that
   don't match version 2. Use the FPGA repo's `docs/MATHUNIT.md` and write
   one register include file (`src/asm/mathunit.inc`) for this project.

### 7.4 Display

| Mode | Graphics | Engine |
|---|---|---|
| Sector map / chart | 320A characters (or 160A), single screen | new, simple |
| Starport | 320A text | Gamma Force cutscene text |
| Deep space | 160A, single screen, starfield | Spacewar arena + sprite plotter |
| Planet | 160A, **horizontal** smooth scroll | new: horizontal version of Gamma Force's engine |

Horizontal scrolling on MARIA is easier than vertical. Every zone's
character objects move by their X position for the fine scroll, and the
coarse scroll moves each object's start pointer, with no zone
rotation. Zones are 16 lines. The playfield is the sky band (the Ark), the
flight band, and the ground band with towers.

**Sprite budget (deep space, worst case):** Ark (multi-strip), fighter,
10 rocks, 4 pirates, 8 player shots, 6 enemy shots, 2 pods. Check it against
MARIA's per-zone DMA early with Gamma Force's `dmalog.py`.

### 7.5 RAM / save state (estimate)

| | Bytes |
|---|---|
| Warps (1/sector), rebuilt from the seed, not saved | (64) |
| Sector flags: visited, type, tier (1/sector) | 64 |
| Port stock: 3 commodities × 20 ports | 60 |
| Planet populations: 4 × ~25 planets | 100 |
| Ship: credits, fuel, hull, upgrades, cargo, stasis | ~48 |
| Manifest bitfield (24 species) | 3 |
| Stardate, score, galaxy seed (4 bytes) | ~10 |
| **Save slot total** | **~290** |

The 7800 has 4K of RAM, so this fits. It lives in one block that saves
and loads whole.

### 7.6 MathUnit uses

- Fighter thrust and heading (rotate), pirate pursuit and lead aiming
  (atan2 + length), auto-turret target selection (nearest by length).
- Asteroid split velocities, missile homing.
- Economy: price = base × tier × stock ratio (multiply/divide).
- Galaxy generation and spawns: the unit's random generator (the only RNG
  on the cart; see §7.3).

### 7.7 Audio

- **Dual POKEY music**: 8 voices, for example lead + harmony + bass + drums on
  POKEY 1 and pads/arpeggio on POKEY 2, or keep POKEY 2 free for SFX
  in combat. Base it on Pinball's dual-POKEY `sound.asm` and Gamma Force's
  `generate_music.py` / `vgm2pokey.py`.
- Tracks: title, sector map (calm), deep space (driving), planet (by
  tier), starport, klaxon sting, ending. The RP6502 game's `COSMIC1`/`COSMIC2`
  (OPL) are the starting point for the title and combat themes.
- TIA for SFX, so the music never drops out (Gamma Force's split).

### 7.8 Music so far

| Song | Where | |
|---|---|---|
| `MUS_TITLE` | the title, the hardware check | the Arc theme, D minor |
| `MUS_ROCKS` | deep space | A minor, driving eighths in the bass |
| `MUS_PIRATES` | from "PIRATES!" until the pirates are gone and the window has closed | E Phrygian, faster, stabs, a chugging bass, toms |

The songs are written in `tools/music.py`, a bar a line (each checked to be 16 sixteenths).

### 7.9 Assets carried over

From `RP6502-Cosmic-Arc/Sprites`: asteroids, beasties, lander (the shuttle),
laser, beam, mothership, main-screen tiles. They get halved horizontally for 160A and
reduced to 3 colours a palette with Gamma Force's `art7800.py` pipeline.
Fighter and pirate art from Spacewar.

---

## Decisions

| # | Question | Decision (2026-11-21) |
|---|---|---|
| 1 | Toolchain | 7800basic + assembly, as in Gamma Force |
| 2 | Galaxy | Seeded and generated at New Game, with the rules in §3.2 |
| 3 | Clock | Fading-star deadline (§6.4) |
| 4 | Hardware | AstroCart V4 FPGA design is the reference: large SuperGame carts, dual POKEY and MathUnit together are fine |
| 5 | Controller | Two-button joystick required |
| 6 | Manifest | About 24 species to start; adjust for ROM, sprites and balance. Art from the RP6502 game |
| 7 | Seed | From the timing of the New Game button press; no seed entry |
| 8 | Saves | SaveKey first; fall back to the High Score Cart if the data fits (§7.3) |
| 9 | Name | "Arc", as in the RP6502 game |

## Open questions

None at the moment.
