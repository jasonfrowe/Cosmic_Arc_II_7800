  rem ======================================================================
  rem  COSMIC ARC II
  rem  The sequel to Cosmic Arc (RP6502) for the Atari 7800 + AstroCart.
  rem  7800basic for the game flow; assembly for the engines (src/asm).
  rem  See docs/DESIGN.md and docs/ENGINE.md.
  rem ======================================================================

  rem 272K SuperGame (as Atari Gamma Force): bank 1 fixed at $4000 (the
  rem game), banks 2-16 switched in at $8000 (sta $8000 with bank - 2),
  rem the last bank (17) fixed at $C000 (graphics).
  rem tools/a78header.py then adds the second POKEY ($0440) and the math
  rem unit ("ACM") to the header.
  set romsize 272k
  set zoneheight 8
  set screenheight 192
  displaymode 320A
  set 7800header 'name Cosmic Arc II'
  set pokeysupport $450

  rem ---- RAM map (docs/ENGINE.md) ----
  rem $2500-$255F sound.asm, $2580-$2584 savekey.asm, $2590-$259F and
  rem $2600-$26FF hwtest.asm; zero page $B0-$BC (7800basic's tracker block)
  dim hw_maskix = $2598
  dim hw_l0 = $2600
  dim hw_l1 = $2620
  dim hw_l2 = $2640
  dim hw_l3 = $2660
  dim hw_l4 = $2680
  dim hw_l5 = $26A0
  dim hw_l6 = $26C0
  dim hw_l7 = $26E0
  dim fireheld = a

  BACKGRND = $00
  rem P0 white text, P1 title gold, P2 cyan labels, P3 green status
  P0C2 = $0F
  P1C2 = $1C
  P2C2 = $9A
  P3C2 = $C8
  characterset menufont
  alphachars ASCII

  asm
  jsr snd_init
  jsr hw_init
  lda #MUS_THEME
  jsr mus_play
  lda #0
  jsr hw_mask
end
  fireheld = 1

main
  clearscreen
  plotchars 'COSMIC ARC II' 1 54 2
  plotchars 'M0 HARDWARE CHECK' 2 46 4
  plotchars hw_l0 3 20 7 30
  plotchars hw_l1 3 20 8 30
  plotchars hw_l2 3 20 9 30
  plotchars hw_l3 3 20 10 30
  plotchars hw_l4 3 20 11 30
  plotchars hw_l5 3 20 12 30
  plotchars hw_l6 3 20 13 30
  plotchars hw_l7 3 20 15 30
  plotchars 'BUTTON: SOLO A POKEY' 0 40 19
  drawscreen
  asm
  jsr hw_frame
end
  if !joy0fire0 then fireheld = 0 : goto main
  if fireheld then goto main
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
  goto main

  rem ======================================================================
  rem Runs every frame from 7800basic's NMI, off screen.
userinterrupt
  asm
  jmp snd_tick
end

  rem Assembly files are copied flat into the build directory (tools/build.sh).
  inline mathunit.asm
  inline sound.asm
  inline music.asm
  inline savekey.asm
  inline hwtest.asm

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
  rem  The last bank: graphics (MARIA reads them from here at any time)
  rem ======================================================================
  bank 17
  incgraphic gfx/menufont.png 320A
