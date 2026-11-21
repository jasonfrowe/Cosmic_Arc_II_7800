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
  set zoneheight 8
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
  dim sp_aimx = $2383
  dim sp_aimy = $2384
  dim sp_energy = $2386
  dim sp_state = $238C
  dim sp_flash = $2393
  dim sp_msglen = $239D
  dim sp_msgx = $239E
  dim hud_top = $23A0
  dim hud_bot = $23B8
  dim sp_msg = $23D0
  dim starch = $23F0
  rem zero page
  dim fireheld = a
  dim fire2held = b
  rem i, t, f, x, y: 7800basic's own one-letter variables
  rem Buttons: joy0fire1 is button 1 (fire; a one-button stick's too),
  rem joy0fire0 button 2 (as Gamma Force and Spacewar).

  BACKGRND = $00
  rem P0 text, P1 the Ark, P2 rocks, P3 bolts and aim, P4 explosions,
  rem P5/P6 stars, P7 the energy bar
  P0C1 = $0F
  P1C1 = $44 : P1C2 = $42 : P1C3 = $4C
  P2C1 = $62 : P2C2 = $66 : P2C3 = $6A
  P3C1 = $98 : P3C2 = $9A : P3C3 = $0F
  P4C1 = $04 : P4C2 = $36 : P4C3 = $1E
  P5C1 = $04
  P6C1 = $0A
  P7C1 = $C8

  characterset font
  rem the font is ASCII 32-95 (tools/gfx.py); ~ stands in for " and '
  alphachars ' !~#$%&~()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  starch = 126

  asm
  jsr snd_init
  jsr hw_init
  lda #MUS_THEME
  jsr mus_play
end
  fireheld = 1 : fire2held = 1
  if hw_math = 0 then goto hwcheck

  rem ======================================================================
title
  gosub drawstars
titleloop
  restorescreen
  plotsprite ark 1 56 83
  plotchars 'COSMIC ARC II' 0 28 4
  plotchars 'PRESS FIRE' 0 40 17
  plotchars 'BUTTON 2: HW CHECK' 5 8 20
  drawscreen
  if !joy0fire0 then fire2held = 0
  if joy0fire0 && !fire2held then fire2held = 1 : goto hwcheck
  if !joy0fire1 then fireheld = 0 : goto titleloop
  if fireheld then goto titleloop
  fireheld = 1

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
  asm
  jsr sp_frame
end
  P1C1 = $44
  if sp_flash & 2 then P1C1 = $0F
  P7C1 = $C8
  if sp_energy < 49 then P7C1 = $1C
  if sp_energy < 25 then P7C1 = $36

  restorescreen
  if sp_state <> 2 then plotsprite ark 1 56 83 : plotsprite aim 3 sp_aimx sp_aimy
  for i = 0 to 9
    t = rk_t[i]
    if t = 0 then goto rocknext
    x = rk_x[i] : y = rk_y[i]
    if t = 1 then plotsprite rock_l 2 x y
    if t = 2 then plotsprite rock_m 2 x y
    if t = 3 then plotsprite rock_s 2 x y
    if t < 4 then goto rocknext
    f = 0
    if rk_tm[i] < 12 then f = 1
    if rk_tm[i] < 6 then f = 2
    plotsprite boom0 4 x y f
rocknext
  next
  for i = 0 to 3
    if bl_t[i] = 0 then goto boltnext
    x = bl_x[i] : y = bl_y[i] : f = bl_d[i]
    plotsprite bolt0 3 x y f
boltnext
  next
  plotchars hud_top 0 0 0 20
  plotchars hud_bot 7 0 23 20
  if sp_msglen then plotchars sp_msg 0 sp_msgx 6 sp_msglen
  drawscreen

  if sp_state <> 2 then goto gameloop
  rem the Ark is lost: fire (pressed anew) for the title
  if !joy0fire1 then fireheld = 0 : goto gameloop
  if fireheld then goto gameloop
  fireheld = 1
  goto title

  rem ======================================================================
  rem Two stars a row, then save the screen as the background
drawstars
  clearscreen
  for i = 1 to 22
    t = rand & 127
    t = t + (rand & 15)
    plotchars starch 5 t i 1
    t = rand & 127
    t = t + 16
    plotchars starch 6 t i 1
  next
  savescreen
  return

  rem ======================================================================
  rem The hardware check (hwtest.asm): fire solos a POKEY, button 2 leaves
hwcheck
  clearscreen
  plotchars 'HARDWARE CHECK' 0 24 2
  plotchars hw_l0 0 0 5 20
  plotchars hw_l1 0 0 6 20
  plotchars hw_l2 0 0 7 20
  plotchars hw_l3 0 0 8 20
  plotchars hw_l4 0 0 9 20
  plotchars hw_l5 0 0 10 20
  plotchars hw_l6 0 0 11 20
  plotchars hw_l7 0 0 13 20
  plotchars 'FIRE: SOLO A POKEY' 5 8 18
  plotchars 'BUTTON 2: BACK' 5 24 20
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
  inline text.asm
  inline sound.asm
  inline music.asm
  inline savekey.asm
  inline hwtest.asm
  inline space.asm

  bank 2
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",2
end

  bank 3
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",3
end

  bank 4
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",4
end

  bank 5
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",5
end

  bank 6
  rem signature, read at $8000 by hwtest.asm
  asm
  .byte "CA",6
end

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
