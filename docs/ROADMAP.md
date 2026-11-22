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
