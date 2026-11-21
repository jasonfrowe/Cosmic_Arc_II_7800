# Roadmap

Built as vertical slices, as Gamma Force was: get each mode playable on its own,
then link them together.

## M0: Skeleton
- [ ] Build script (vendored 7800basic or asm), CMake wrapper, `tools/play.sh` (`-nomouse`)
- [ ] 272K SuperGame layout, `.a78` header: MathUnit (`ACM`), POKEYs $0450 + $0440, SaveKey
- [ ] a7800 fork: second POKEY for SuperGame carts; commit the $0440 device change
- [ ] a7800 fork: SaveKey (24LC256) on port 2
- [ ] MathUnit register include file, checked against `astromath.h`
- [ ] Boots to a title screen and plays a dual-POKEY test tune

## M1: Deep space slice (Mothership)
- [ ] Art pipeline: RP6502 sprites → 160A
- [ ] Ark in the centre, 8-way laser, energy meter
- [ ] Asteroid waves with splitting; HUD

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
- [ ] Galaxy data (grid-laid graph, warp bitmasks), generator or fixed map
- [ ] Sector view, galactic chart, fog of war, fuel, stardate
- [ ] Encounter roll → M1/M2; planet sector → M3

## M5: Starports
- [ ] 320A tabbed menus: Commodities, Bio-Bounty, Shipyard
- [ ] Port classes, stock and restock, prices by tier
- [ ] Upgrades applied to every mode

## M6: Save / continue
- [ ] SaveKey save slot, saved on docking; Continue on the title

## M7: Full game
- [ ] All tiers, biomes, 24 species, carrier
- [ ] Full soundtrack
- [ ] Ending, rank, high scores
- [ ] Balancing pass
- [ ] Manual, browser build (js7800_astrocart) on GitHub Pages
