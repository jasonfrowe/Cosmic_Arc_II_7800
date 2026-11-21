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

## M2: Fighter
- [ ] Launch, fly (16 headings, inertia), twin blasters, recall/dock, tether
- [ ] Ark auto-turret
- [ ] Raider and gunship AI (from Spacewar); salvage pods

## M3: Planet slice
- [ ] Horizontal smooth-scroll engine with a wrapping surface
- [ ] Shuttle, tractor beam, stun pulse, scanner strip
- [ ] Creatures (first 6 behaviours), ore crates, turrets, klaxon timer
- [ ] One biome bank

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
