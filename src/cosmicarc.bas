  rem ======================================================================
  rem  COSMIC ARC II
  rem  The sequel to Cosmic Arc (RP6502) for the Atari 7800 + AstroCart.
  rem  7800basic for the game flow and drawing; assembly for the engines
  rem  (src/asm). See docs/DESIGN.md and docs/ENGINE.md.
  rem ======================================================================

  rem 272K SuperGame (as Atari Gamma Force): bank 1 fixed at $4000 (the
  rem game), banks 2-16 switched in at $8000 (sta $8000 with bank - 2),
  rem the last bank (17) fixed at $C000 (graphics).
  rem tools/a78header.py then adds the second POKEY ($0440) and the math
  rem unit ("ACM") to the header.
  set romsize 272k
  rem 16-line zones: a zone's display list has room for 31 objects, and a
  rem 16-line sprite touches 2 zones, not 3 (8-line zones overflowed in busy
  rem waves and wrecked the zone below). zoneprotection drops what won't fit.
  set zoneheight 16
  set zoneprotection on
  set screenheight 192
  set doublewide on
  displaymode 160A
  set 7800header 'name Cosmic Arc II'
  set pokeysupport $450

  rem ---- RAM map (docs/ENGINE.md) ----
  dim hw_math = $2590
  dim hw_maskix = $2598
  dim hw_l0 = $2600
  dim hw_l1 = $2620
  dim hw_l2 = $2640
  dim hw_l3 = $2660
  dim hw_l4 = $2680
  dim hw_l5 = $26A0
  dim hw_l6 = $26C0
  dim hw_l7 = $26E0
  rem space.asm
  dim rk_t = $2300
  dim rk_x = $230A
  dim rk_y = $231E
  dim rk_tm = $235A
  dim bl_t = $2364
  dim bl_x = $2368
  dim bl_y = $236C
  dim bl_d = $2378
  dim sp_joy = $2380
  dim sp_fire = $2381
  dim sp_fire2 = $24C5
  dim sp_aimx = $2383
  dim sp_aimy = $2384
  dim sp_energy = $2386
  dim sp_state = $238C
  dim sp_arky = $23FC
  dim sp_flash = $2393
  dim sp_msglen = $239D
  dim sp_msgx = $239E
  dim hud_top = $23A0
  dim hud_bot = $23B8
  dim hud_bot2 = $24D0
  dim sp_msg = $23D0
  dim starch = $23F0
  dim starch2 = $2576
  dim starch3 = $2577
  dim twtick = $2575
  dim pl_world = $27F0
  dim gs_test = $259F
  dim gs_go = $259B
  dim gs_seed = $2597
  dim twtick2 = $2579
  rem the escape pod's scene
  dim esct = $2573
  dim escx = $2574
  dim escy = $2578
  dim escv = $258B
  dim escbx = $258C
  dim escby = $258D
  rem surface.asm (the planet)
  dim pl_state = $2714
  dim pl_fine = $2719
  dim pl_col = $271A
  dim pl_arksx = $2770
  dim pl_arkv = $2771
  dim pl_arky = $2775
  dim pl_scans = $22E0
  dim pl_tick = $271B
  rem zero page
  dim fireheld = a
  dim fire2held = b
  rem i, t, f, x, y: 7800basic's own one-letter variables
  rem Buttons: joy0fire1 is button 1 (fire; a one-button stick's too),
  rem joy0fire0 button 2 (as Gamma Force and Spacewar).

  gosub spacepal

  characterset font
  rem the font is ASCII 32-95 (tools/gfx.py); ~ stands in for " and '
  alphachars ' !~#$%&~()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  starch = 126 : starch2 = 144 : starch3 = 146

  asm
  lda #BANK_SPACE         ; deep space's bank (docs/ENGINE.md: banks)
  jsr bank_in
  jsr snd_init
  jsr hw_init
  lda #$FF
  sta mu_song
  lda #MUS_TITLE
  jsr mu_switch
end
  fireheld = 1 : fire2held = 1
  if hw_math = 0 then goto hwcheck

  rem ======================================================================
title
  asm
  lda #MUS_TITLE
  jsr mu_switch
end
  gosub drawstars
titleloop
  restorescreen
  plotsprite ark 1 56 80
  plotchars 'COSMIC ARC II' 0 28 2
  plotchars 'PRESS FIRE' 0 40 8
  plotchars 'BUTTON 2: HW CHECK' 3 8 10
  drawscreen
  gosub twinkle
  if !joy0fire0 then fire2held = 0
  if joy0fire0 && !fire2held then fire2held = 1 : goto hwcheck
  if switchselect then goto planettest
  if !joy0fire1 then fireheld = 0 : goto titleloop
  if fireheld then goto titleloop
  fireheld = 1
  rem (tests: gs_test set, straight into deep space, waves and planets)
  if gs_test = 0 then goto newgame

  rem ======================================================================
  rem Deep space (space.asm)
game
  gosub drawstars
  asm
  jsr sp_new
end
gameloop
  rem (one condition a line: an if after "then ... :" only runs when the
  rem first one held)
  t = 8
  if joy0up then t = 0
  if joy0down then t = 4
  if joy0right then t = 2
  if joy0left then t = 6
  if joy0up && joy0right then t = 1
  if joy0down && joy0right then t = 3
  if joy0down && joy0left then t = 5
  if joy0up && joy0left then t = 7
  sp_joy = t
  sp_fire = 0
  if joy0fire1 then sp_fire = 1
  sp_fire2 = 0
  if joy0fire0 then sp_fire2 = 1
  asm
  jsr sp_frame
end
  P1C1 = $44
  if sp_flash & 2 then P1C1 = $0F
  P7C1 = $C8
  if sp_energy < 49 then P7C1 = $1C
  if sp_energy < 25 then P7C1 = $36

  restorescreen
  if sp_state <> 2 && sp_arky then plotsprite ark 1 56 sp_arky
  asm
  jsr sp_draw
end
  plotchars hud_top 0 0 0 20
  plotchars hud_bot 7 0 11 10
  plotchars hud_bot2 3 80 11 10
  if sp_msglen then plotchars sp_msg 0 sp_msgx 3 sp_msglen
  drawscreen
  gosub twinkle

  if sp_state = 4 && gs_test then goto planet
  if sp_state = 4 then goto sector
  if sp_state <> 2 then goto gameloop
  rem the Ark is lost: the escape pod (tests: fire, pressed anew, for the
  rem title)
  if gs_test = 0 then goto escape
  if !joy0fire1 then fireheld = 0 : goto gameloop
  if fireheld then goto gameloop
  fireheld = 1
  goto title

  rem ======================================================================
  rem The planet (surface.asm, bank 3): the Ark in orbit, the ground (two
  rem rows of the map, scrolled), the sprites, the HUD. Then back up.
planettest
  gs_test = 1
  asm
  jsr sp_new
end
planet
  asm
  lda #BANK_PLANET
  jsr bank_in
  jsr pl_new
end
  gosub planetpal
planetloop
  t = 8
  if joy0up then t = 0
  if joy0down then t = 4
  if joy0right then t = 2
  if joy0left then t = 6
  if joy0up && joy0right then t = 1
  if joy0down && joy0right then t = 3
  if joy0down && joy0left then t = 5
  if joy0up && joy0left then t = 7
  sp_joy = t
  sp_fire = 0
  if joy0fire1 then sp_fire = 1
  sp_fire2 = 0
  if joy0fire0 then sp_fire2 = 1
  rem (on a planet: button 1 the beam, button 2 drops the cargo)
  asm
  jsr pl_frame
end
  P7C1 = $C8
  if sp_energy < 49 then P7C1 = $1C
  if sp_energy < 25 then P7C1 = $36
  clearscreen
  rem the Ark hangs over its own spot of the planet
  if pl_arkv && pl_arky then plotsprite ark 1 pl_arksx pl_arky
  rem the ground: one row (zone 10). (The map width as a number: a name is
  rem taken for a variable; = PL_MAPW)
  plotmap pl_map 5 pl_fine 10 21 1 pl_col 0 149
  rem the scanner (surface.asm pl_scanner): towers, the Ark, creatures,
  rem the shuttle, the storm's rock; its ends either side
  plotchars pl_scans 0 8 1 18
  asm
  jsr pl_draw
end
  plotchars hud_top 0 0 0 20
  plotchars hud_bot 7 0 11 10
  plotchars hud_bot2 0 80 11 10
  if sp_msglen then plotchars sp_msg 0 sp_msgx 3 sp_msglen
  drawscreen
  rem the beam shimmers: its palette (P3) cycles, in the vertical blank
  t = (pl_tick / 4) & 3
  P3C2 = beamc2[t] : P3C3 = beamc3[t]
  if pl_state <> 3 then goto planetloop
  rem out of energy on the planet: the game's over
  if sp_energy = 0 then goto planetlost
  if gs_test then goto planetnext
  rem leaving the planet: an encounter? (the sector's odds)
  asm
  lda #BANK_MAP
  jsr bank_in
  jsr sv_depart
end
  if gs_go = 1 then goto encounter
  goto sector
planetnext
  asm
  lda #BANK_SPACE
  jsr bank_in
  jsr sp_return
end
  gosub spacepal
  gosub drawstars
  goto gameloop
planetlost
  asm
  lda #BANK_SPACE
  jsr bank_in
end
  gosub spacepal
  if gs_test = 0 then goto escape
  fireheld = 1
  goto title

  rem ======================================================================
  rem The Ark lost: it breaks up, and the escape pod (the saucer) drops from
  rem its bay and races away (a nod to the 2600 game's ending). Then home in
  rem a new Ark (sector.asm gx_lost: a tenth of the credits; the bank kept)
escape
  gosub drawstars
  esct = 0 : escx = 76 : escy = 104 : escv = 0 : escbx = 70 : escby = 88
escapeloop
  if esct < 250 then esct = esct + 1
  t = esct & 7
  if t = 0 then gosub escboom
  P1C1 = $44
  if esct & 4 then P1C1 = $0F
  restorescreen
  if esct < 96 then plotsprite ark 1 56 80
  t = esct & 7
  t = t / 3
  if esct < 104 then plotsprite boom0 4 escbx escby t
  t = esct / 4
  t = t & 3
  if esct >= 20 && escy > 8 then plotsprite saucer0 6 escx escy t
  if esct >= 24 then plotchars 'ESCAPE POD AWAY' 0 20 9
  if esct >= 110 then plotchars 'THE ARK IS LOST' 0 20 2
  if esct >= 200 then plotchars 'PRESS FIRE' 0 40 10
  drawscreen
  gosub twinkle
  if esct >= 20 then gosub escmove
  if esct < 200 then goto escapeloop
  if !joy0fire1 then fireheld = 0 : goto escapeloop
  if fireheld then goto escapeloop
  fireheld = 1
  asm
  lda #BANK_MAP
  jsr bank_in
  jsr gx_lost
end
  goto sector
  rem a new blast somewhere on the hull, while it lasts
escboom
  if esct >= 96 then return
  escbx = rand & 31
  escbx = escbx + 58
  escby = rand & 15
  escby = escby + 82
  asm
  lda #SFX_BOOM
  jsr sfx
end
  return
  rem the pod: drops clear of the bay, then faster and faster, away up and
  rem to the right
escmove
  if escy = 0 then return
  if esct < 44 then escy = escy + 1 : return
  t = esct & 3
  if t = 0 && escv < 16 then escv = escv + 1
  t = escv / 4
  escx = escx + t
  t = escv / 8
  t = t + 10
  if escy < t then escy = 0 : return
  t = t - 10
  escy = escy - t
  if escx > 156 then escy = 0
  return

  rem ======================================================================
  rem A new game: deep space reset, the galaxy from the seed (the timing of
  rem the press), the sector map (sector.asm, bank 4: 320A text)
newgame
  gs_seed[0] = twtick : gs_seed[1] = twtick2 : gs_seed[2] = rand : gs_seed[3] = INTIM
  asm
  lda #BANK_SPACE
  jsr bank_in
  jsr sp_new
  lda #BANK_MAP
  jsr bank_in
  jsr gx_new
end
sector
  asm
  lda #BANK_MAP
  jsr bank_in
  jsr sv_enter
  lda #MUS_MAP
  jsr mu_switch
end
  gosub mappal
sectorloop
  t = 8
  if joy0up then t = 0
  if joy0down then t = 4
  if joy0right then t = 2
  if joy0left then t = 6
  if joy0up && joy0right then t = 1
  if joy0down && joy0right then t = 3
  if joy0down && joy0left then t = 5
  if joy0up && joy0left then t = 7
  sp_joy = t
  sp_fire = 0
  if joy0fire1 then sp_fire = 1
  sp_fire2 = 0
  if joy0fire0 then sp_fire2 = 1
  clearscreen
  asm
  jsr sv_frame
end
  drawscreen
  if gs_go = 1 then goto encounter
  if gs_go = 2 then goto landplanet
  if gs_go = 3 then goto achieve
  goto sectorloop
  rem the achievements (achieve.asm, bank 6: 320A, its own copy of the font)
achieve
  asm
  lda #BANK_ACH
  jsr bank_in
  jsr ac_enter
end
achloop
  t = 8
  if joy0up then t = 0
  if joy0down then t = 4
  if joy0right then t = 2
  if joy0left then t = 6
  sp_joy = t
  sp_fire = 0
  if joy0fire1 then sp_fire = 1
  sp_fire2 = 0
  if joy0fire0 then sp_fire2 = 1
  clearscreen
  asm
  jsr ac_frame
end
  drawscreen
  if gs_go = 3 then goto achloop
  goto sector
  rem an encounter on the way: deep space, a wave for the tier
encounter
  asm
  jsr sv_leave
  lda #BANK_SPACE
  jsr bank_in
  jsr sp_return
end
  gosub spacepal
  gosub drawstars
  goto gameloop
landplanet
  asm
  jsr sv_leave
end
  gosub spacepal
  goto planet
  rem the map's colours (320A text: every colour of a palette the same)
mappal
  BACKGRND = $00
  P0C1 = $0E : P0C2 = $0E : P0C3 = $0E
  P1C1 = $1C : P1C2 = $1C : P1C3 = $1C
  P2C1 = $9C : P2C2 = $9C : P2C3 = $9C
  rem (the achievements' icons: P3 not yet earned, P4-P7 earned, by column)
  P3C1 = $04 : P3C2 = $04 : P3C3 = $04
  P4C1 = $1C : P4C2 = $1C : P4C3 = $1C
  P5C1 = $CA : P5C2 = $CA : P5C3 = $CA
  P6C1 = $4A : P6C2 = $4A : P6C3 = $4A
  P7C1 = $8C : P7C2 = $8C : P7C3 = $8C
  return

  rem ======================================================================
  rem Palettes: deep space's, and a planet's
spacepal
  BACKGRND = $00
  rem P0 text, P1 the Ark, P2 rocks, P3 bolts, aim, turret shots, pods and
  rem the tether bar, P4 explosions and pirates, P5 stars, P6 the fighter,
  rem P7 the energy bar
  P0C1 = $0F
  P1C1 = $44 : P1C2 = $42 : P1C3 = $4C
  P2C1 = $62 : P2C2 = $66 : P2C3 = $6A
  P3C1 = $98 : P3C2 = $9A : P3C3 = $0F
  P4C1 = $04 : P4C2 = $36 : P4C3 = $1E
  P5C1 = $06
  P6C1 = $D4 : P6C2 = $DC : P6C3 = $0F
  P7C1 = $C8
  P0C2 = $1C : P0C3 = $44
  P5C1 = $06 : P5C2 = $86 : P5C3 = $0E
  return

  rem the stars twinkle: P5's three colours (three kinds of star) each run
  rem round a 32-step brightness cycle, a third of the way apart
twinkle
  twtick = twtick + 1
  if twtick = 0 then twtick2 = twtick2 + 1
  t = (twtick / 4) & 31
  P5C1 = twink1[t]
  t = (t + 11) & 31
  P5C2 = twink2[t]
  t = (t + 11) & 31
  P5C3 = twink3[t]
  return
  data twink1
  $04, $04, $06, $06, $08, $0A, $0C, $0A, $08, $06, $06, $04, $04, $04, $02, $02
  $04, $04, $06, $06, $06, $08, $08, $06, $06, $04, $04, $02, $02, $02, $04, $04
end
  data twink2
  $82, $84, $86, $88, $8A, $8C, $8E, $8C, $8A, $88, $86, $84, $82, $82, $82, $84
  $84, $86, $86, $84, $84, $82, $82, $80, $80, $80, $82, $82, $84, $84, $82, $82
end
  data twink3
  $08, $0A, $0C, $0E, $0F, $0E, $0C, $0A, $08, $06, $06, $06, $08, $08, $06, $06
  $06, $08, $0A, $08, $06, $06, $04, $04, $06, $06, $08, $08, $06, $06, $06, $08
end

  rem the tractor beam's colours, cycled (P3: edge, core)
  data beamc2
  $96, $98, $9A, $98
end
  data beamc3
  $AC, $0E, $AE, $0F
end

  rem P2 creatures (yellow, pink, cyan), P5 the ground (grass, soil, hills),
  rem the sky dark blue; the rest as deep space's
planetpal
  rem the world (surface.asm pl_world): its sky and its ground (grass, soil,
  rem stones; crates too), as Cosmic Arc's worlds by palette
  t = pl_world
  BACKGRND = wsky[t]
  P2C1 = $1C : P2C2 = $4A : P2C3 = $9C
  P5C1 = wtop[t] : P5C2 = wsoil[t] : P5C3 = wstone[t]
  return
  rem VERDA (green), RUBRA (rust), GLACI (ice), UMBRA (violet), ARENA (sand),
  rem TOXIS (acid)
  data wsky
  $82, $F0, $70, $50, $A0, $C0
end
  data wtop
  $C6, $36, $0E, $5A, $2C, $DA
end
  data wsoil
  $22, $32, $96, $54, $26, $D4
end
  data wstone
  $E4, $3A, $9A, $5E, $22, $EA
end

  rem ======================================================================
  rem Stars (three a row, playfield rows 1-10), then save the screen as the
  rem background
drawstars
  clearscreen
  for i = 1 to 10
    t = rand & 63
    gosub plotstar
    t = rand & 63
    t = t + 48
    gosub plotstar
    t = rand & 63
    t = t + 96
    gosub plotstar
  next
  savescreen
  return
  rem a star at t, row i: half dim, a quarter blue, a quarter bright
plotstar
  f = rand & 3
  if f < 2 then plotchars starch 5 t i 1 : return
  if f = 2 then plotchars starch2 5 t i 1 : return
  plotchars starch3 5 t i 1
  return

  rem ======================================================================
  rem The hardware check (hwtest.asm): fire solos a POKEY, button 2 leaves
hwcheck
  clearscreen
  plotchars 'HARDWARE CHECK' 0 24 0
  plotchars hw_l0 0 0 1 20
  plotchars hw_l1 0 0 2 20
  plotchars hw_l2 0 0 3 20
  plotchars hw_l3 0 0 4 20
  plotchars hw_l4 0 0 5 20
  plotchars hw_l5 0 0 6 20
  plotchars hw_l6 0 0 7 20
  plotchars hw_l7 0 0 8 20
  plotchars 'FIRE: SOLO A POKEY' 5 8 10
  plotchars 'BUTTON 2: BACK' 5 24 11
  drawscreen
  asm
  jsr hw_frame
end
  if !joy0fire0 then fire2held = 0
  if joy0fire0 && !fire2held && hw_math then fire2held = 1 : goto hwleave
  if !joy0fire1 then fireheld = 0 : goto hwcheck
  if fireheld then goto hwcheck
  fireheld = 1
  asm
  lda #SFX_BEEP
  jsr sfx
  ldy hw_maskix
  iny
  cpy #3
  bne mask_ok
  ldy #0
mask_ok
  tya
  jsr hw_mask
end
  goto hwcheck
hwleave
  asm
  lda #0
  jsr hw_mask
end
  goto title

  rem ======================================================================
  rem Runs every frame from 7800basic's NMI, off screen.
userinterrupt
  asm
  jmp snd_tick
end

  rem Assembly files are copied flat into the build directory (tools/build.sh).
  inline mathunit.asm
  inline banks.asm
  inline vec.asm
  inline common.asm
  inline text.asm
  inline text40.asm
  inline sound.asm
  inline sfx.asm
  inline savekey.asm
  inline hwtest.asm

  rem ======================================================================
  rem  Bank 2: deep space (space.asm and the rest). In from the start: the
  rem  BASIC calls it straight (sp_new, sp_frame, sp_draw).
  rem ======================================================================
  bank 2
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",2
end
  inline space.asm
  inline fighter.asm
  inline pirates.asm
  inline draw.asm

  rem ======================================================================
  rem  Bank 3: the planet (surface.asm, and its map: MARIA reads the map's
  rem  character codes as it draws, so the map lives in this bank too)
  rem ======================================================================
  bank 3
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",3
end
  inline surface.asm
  inline planetmap.asm

  rem ======================================================================
  rem  Bank 4: the sector map (sector.asm), and its 40-column font at $A000
  rem  (MARIA reads it from here while the map shows)
  rem ======================================================================
  bank 4
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",4
end
  inline sector.asm
  asm
  if . > $A000
  echo "bank 4: the code reaches the font's place ($A000)"
  err
  endif
  ds $A000 - ., 0
end
  asm
font320
end
  inline font320.asm
  rem a starport's screens (after the font: $B000 on)
  inline port.asm

  rem ======================================================================
  rem  Bank 5: the music (gen/music.asm, tools/music.py): sound.asm's player
  rem  switches it in while it reads (in the NMI, in vblank)
  rem ======================================================================
  bank 5
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",5
end
  inline music.asm

  rem ======================================================================
  rem  Bank 6: the achievements' screen (achieve.asm), and its own copy of
  rem  the 40-column font at $A000 (MARIA reads it from the bank that's in)
  rem ======================================================================
  bank 6
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",6
end
  inline achieve.asm
  asm
  if . > $A000
  echo "bank 6: the code reaches the font's place ($A000)"
  err
  endif
  ds $A000 - ., 0
font320b
end
  inline font320b.asm

  bank 7
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",7
end

  bank 8
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",8
end

  bank 9
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",9
end

  bank 10
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",10
end

  bank 11
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",11
end

  bank 12
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",12
end

  bank 13
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",13
end

  bank 14
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",14
end

  bank 15
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",15
end

  bank 16
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",16
end

  rem ======================================================================
  rem  The last bank: graphics (MARIA reads them from here at any time).
  rem  tools/gfx.py makes them; colors 0-3 are the PNG's indexes 0-3.
  rem ======================================================================
  bank 17
  incgraphic gfx/font.png 160A 0 1 2 3
  rem (frame groups must stay contiguous in one block: tools/gfxcheck.py;
  rem the creatures straight after the font, which takes 180 of a line's 256)
  incgraphic gfx/creature00.png 160A 0 1 2 3
  incgraphic gfx/creature01.png 160A 0 1 2 3
  incgraphic gfx/creature02.png 160A 0 1 2 3
  incgraphic gfx/creature03.png 160A 0 1 2 3
  incgraphic gfx/creature04.png 160A 0 1 2 3
  incgraphic gfx/creature05.png 160A 0 1 2 3
  incgraphic gfx/creature06.png 160A 0 1 2 3
  incgraphic gfx/creature07.png 160A 0 1 2 3
  incgraphic gfx/creature08.png 160A 0 1 2 3
  incgraphic gfx/creature09.png 160A 0 1 2 3
  incgraphic gfx/creature10.png 160A 0 1 2 3
  incgraphic gfx/creature11.png 160A 0 1 2 3
  incgraphic gfx/creature12.png 160A 0 1 2 3
  incgraphic gfx/creature13.png 160A 0 1 2 3
  incgraphic gfx/creature14.png 160A 0 1 2 3
  incgraphic gfx/creature15.png 160A 0 1 2 3
  incgraphic gfx/creature16.png 160A 0 1 2 3
  incgraphic gfx/creature17.png 160A 0 1 2 3
  incgraphic gfx/creature18.png 160A 0 1 2 3
  incgraphic gfx/creature19.png 160A 0 1 2 3
  incgraphic gfx/creature20.png 160A 0 1 2 3
  incgraphic gfx/creature21.png 160A 0 1 2 3
  incgraphic gfx/creature22.png 160A 0 1 2 3
  incgraphic gfx/creature23.png 160A 0 1 2 3
  incgraphic gfx/ark.png 160A 0 1 2 3
  incgraphic gfx/rock_l.png 160A 0 1 2 3
  incgraphic gfx/rock_m.png 160A 0 1 2 3
  incgraphic gfx/rock_s.png 160A 0 1 2 3
  incgraphic gfx/aim.png 160A 0 1 2 3
  incgraphic gfx/bolt0.png 160A 0 1 2 3
  incgraphic gfx/bolt1.png 160A 0 1 2 3
  incgraphic gfx/bolt2.png 160A 0 1 2 3
  incgraphic gfx/bolt3.png 160A 0 1 2 3
  incgraphic gfx/bolt4.png 160A 0 1 2 3
  incgraphic gfx/bolt5.png 160A 0 1 2 3
  incgraphic gfx/bolt6.png 160A 0 1 2 3
  incgraphic gfx/bolt7.png 160A 0 1 2 3
  incgraphic gfx/boom0.png 160A 0 1 2 3
  incgraphic gfx/boom1.png 160A 0 1 2 3
  incgraphic gfx/boom2.png 160A 0 1 2 3
  incgraphic gfx/saucer0.png 160A 0 1 2 3
  incgraphic gfx/saucer1.png 160A 0 1 2 3
  incgraphic gfx/saucer2.png 160A 0 1 2 3
  incgraphic gfx/saucer3.png 160A 0 1 2 3
  incgraphic gfx/raider0.png 160A 0 1 2 3
  incgraphic gfx/raider1.png 160A 0 1 2 3
  incgraphic gfx/gunship.png 160A 0 1 2 3
  incgraphic gfx/missile0.png 160A 0 1 2 3
  incgraphic gfx/missile1.png 160A 0 1 2 3
  incgraphic gfx/dot.png 160A 0 1 2 3
  incgraphic gfx/pod0.png 160A 0 1 2 3
  incgraphic gfx/pod1.png 160A 0 1 2 3
  incgraphic gfx/beam0.png 160A 0 1 2 3
  incgraphic gfx/beam1.png 160A 0 1 2 3
  incgraphic gfx/crate.png 160A 0 1 2 3
  incgraphic gfx/tower.png 160A 0 1 2 3
  incgraphic gfx/turret.png 160A 0 1 2 3
  incgraphic gfx/tunnel.png 160A 0 1 2 3
  incgraphic gfx/pulse.png 160A 0 1 2 3
