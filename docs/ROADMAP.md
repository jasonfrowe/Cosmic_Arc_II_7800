# Roadmap

Built as vertical slices, as Gamma Force was: get each mode playable on its own,
then link them together.

## M0: Skeleton ✅ (2026-11-21)
- [x] Build script (vendored 7800basic + asm, from Gamma Force), CMake wrapper, `tools/play.sh` (`-nomouse`), `tools/snap.sh`
- [x] 272K SuperGame layout, `.a78` header: MathUnit (`ACM`), POKEYs $0450 + $0440, SaveKey
- [x] a7800 fork: second POKEY for SuperGame carts; commit the $0440 device change (pushed to `cordic`)
- [x] a7800 fork: SaveKey (24LC256) on port 2
- [x] `src/asm/mathunit.asm` from the FPGA repo's `docs/MATHUNIT.md`
- [x] Boots to a hardware check and plays a dual-POKEY test tune (verified by soloing each POKEY)
- [x] Run the M0 ROM on the real AstroCart (with and without a SaveKey): all OK, both POKEYs
- [ ] js7800_astrocart: second POKEY on SuperGame carts (for the browser build)

## M1: Deep space slice (Mothership) ✅ (2026-11-21)
- [x] Art pipeline: `tools/gfx.py` (ASCII art → 160A PNGs), RP6502-styled Ark and rocks, 160A font from Spacewar's
- [x] Title screen; hardware check behind button 2
- [x] Ark in the centre, 8-way laser along 8 lanes, aim marker, energy bar
- [x] Asteroid waves along the lanes, splitting large → medium → small; explosions; HUD (score, wave, energy)
- [x] `tools/snap.sh` scripted input and an autopilot soak test; holds 60 fps with 9 rocks
- [x] Balance and fire rate checked on hardware
- [x] Fixes from hardware: down diagonals (input), rocks drifting off the diagonal lanes, a bigger Ark (48 x 24) with a fighter bay

## M2: Fighter ✅ (2026-11-21)
- [x] Launch (button 2), fly (16 headings, inertia, down brakes, wraps at the edges), twin blasters, recall (button 2, flies itself home) or fly into the bay to dock
- [x] Tether: drains out, charges docked; run dry and it comes home; damage comes off it too and can destroy it (the Ark builds another)
- [x] Ark auto-turret while the fighter is out (any angle, nearest threat, slow)
- [x] Raiders (circle the Ark, shoot), gunships (park between lanes, launch homing missiles), missiles
- [x] Salvage pods from destroyed pirates: only the fighter picks them up, for Ark energy
- [x] HUD: Ark energy and fighter tether bars
- [x] `snap.lua` fighter autopilot (`AUTOFIGHTER`); all sprites drawn from assembly (`draw.asm`)
- [x] From hardware: the pirate window (small rocks only for 20 s after the first pirate), rocks hurt pirates (who dodge them on the math unit), the fighter docks only with button 2
- [x] From hardware: directional fighter controls; music for the title, rocks and pirates
- [ ] Tune on hardware: fighter handling, tether rates, turret rate, pirate damage
- [x] Deep space in its own bank (bank 2): bank 1 back to 10.4K free, bank 2 9.7K free

## M3: Planet slice ✅ (2026-11-22)
- [x] Horizontal smooth scroll over a wrapping surface (1024 px, 6.4 screens): `plotmap` with the coarse column, fine x off the left edge (MARIA wraps)
- [x] Shuttle (the saucer): out of the Ark and back up into it to dock and hand over; tractor beam; stun pulse; scanner strip
- [x] Creatures with 6 behaviours (walker, hopper, runner, burrower, glider, blinker) from the RP6502 beasties; ore crates (heavy); turrets on towers (shoot, knock cargo loose); the 60 s clock and the klaxon; every creature delivered: the Ark's energy full
- [x] One biome (bank 3: code and map); after each deep-space wave, a planet
- [x] `tools/test_planet.sh`; `AUTOPLANET`; deep-space tests skip planets (`sp_noplanet`)
- [x] From hardware: turrets destroy the shuttle (8 towers, one always in view); the Ark stays over its own spot; creatures struggle in the beam and react (stun, then beam); the shuttle stops while beaming; the beam always reaches the ground exactly; creatures no longer vanish (MARIA's line time: one ground row)
- [x] `tools/bankcheck.py` in the build
- [x] From hardware: blinkers' jumps (a sign bug), rolling ground, out of energy on a planet ends the game, the Ark comes and goes between scenes, gunships a threat, rocks destroy the saucer, the saucer needs twice the shots
- [x] From hardware: no stun; the shuttle fires like the saucer (button 1), the beam on button 2; shot turrets out 10 s; shot creatures dead; RP6502 docking (inside the Ark; hold down to come out; up the tube and let go to dock); no hiding creatures; catchable without a stun (70-85% in the beam)
- [x] From hardware: bullets outrun the shuttle; the saucer called home is safe; easy docking with the Ark's tunnel (push up near it: in by itself; hold down: out by itself); `test_feel.sh`, `test_recall.sh`
- [x] From hardware: the RP6502 defences (guns that move as one, a screen-wide pulse to dodge) instead of shuttle bullets; both buttons the beam; frame rate held (scanner as characters); `test_defense.sh`
- [x] From hardware: the Ark's doorway twice the shuttle's width, straight up only (no accidental docking); the defences' pace rises with the stage (stage 1: half the old speed, 2.5 s between pulses)
- [x] From hardware: the flight band is the guns' range (never lands: fixes ore rising into the sky); the storm as Cosmic Arc's (klaxon, a rock at the Ark, the Ark's laser when docked); the Ark lower, a short tunnel; the defences' pace by level as the RP6502 game; `test_storm.sh`
- [x] From hardware: the Ark doesn't fire on docking; 10 s from the klaxon to the rock, a slower rock always in sight (and on the scanner); no countdown; creatures react 75%; one thing in the beam; a solid, palette-cycled beam
- [x] From hardware: dock on the move (up-left/up-right, near the ceiling); random pulse gaps over a steady full-band sweep: no safe line (tested at the band's top, middle, foot)
- [ ] A planet music track (the Arc theme for now)
- [ ] Tune on hardware: shuttle speed, beam reach, turret danger, creature behaviours

## M4: Sector map
- [ ] Seeded galaxy generator (grid-laid graph, warp bitmasks, rules in DESIGN §3.2)
- [ ] Sector view, galactic chart, fog of war, fuel, stardate
- [ ] Encounter roll → M1/M2; planet sector → M3

## M5: Starports
- [ ] 320A tabbed menus: Commodities, Bio-Bounty, Shipyard
- [ ] Port classes, stock and restock, prices by tier
- [ ] Upgrades applied to every mode

## M6: Save / continue
- [ ] SaveKey save slot, saved on docking; Continue on the title
- [ ] HSC fallback: measure the free space; full or reduced save

## M7: Full game
- [ ] All tiers, biomes, 24 species, carrier
- [ ] Full soundtrack
- [ ] Ending, rank, high scores
- [ ] Balancing pass
- [ ] Manual, browser build (js7800_astrocart) on GitHub Pages
