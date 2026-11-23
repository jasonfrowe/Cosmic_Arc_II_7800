; ===========================================================================
; Text. The font (src/gfx/font.png, tools/gfx.py) holds ASCII 32-95 as
; doublewide characters, so a character's code is (ASCII - 32) * 2.
; tx_ascii converts at run time.
; ===========================================================================

CH_SPACE = 0
CH_BAR4  = (91-32)*2    ; [ a full bar cell
CH_BAR3  = (92-32)*2    ; \ three quarters
CH_BAR2  = (93-32)*2    ; ] half
CH_BAR1  = (94-32)*2    ; ^ a quarter
CH_STAR  = (95-32)*2    ; _ a star
; after the terrain (tools/gfx.py EXTRA: glyph n is code 2n)
CH_STAR2  = 144         ; a star in color 2, a bright star in 3 (they twinkle)
CH_STAR3  = 146
CH_SCTRK  = 148         ; the planet's scanner (P0): track, its ends, a tower,
CH_SCL    = 150         ;   the Ark, a creature, the shuttle, the storm's rock
CH_SCR    = 152
CH_SCTWR  = 154
CH_SCARK  = 156
CH_SCCR   = 158
CH_SCSH   = 160
CH_SCROCK = 162
CH_LOOSE  = 164         ; the HUD (P0): a creature still loose, caught
CH_CAUGHT = 166
CH_ENERGY = 168         ; the energy bar's icon (P7)
CH_BAYL   = 170         ; the shuttle's bay: [ ], ore in it
CH_BAYR   = 172
CH_ORE    = 174
CH_SHUT   = 176         ; the shuttle, and lost (being rebuilt)
CH_SHLOST = 178

; A = ASCII -> A = character code
tx_ascii
    sec
    sbc #32
    asl
    rts

; A = 0-9 -> A = the digit's character code
tx_digit
    clc
    adc #16
    asl
    rts

; ---- strings, already as character codes ----
tx_wave   .byte ("W"-32)*2, ("A"-32)*2, ("V"-32)*2, ("E"-32)*2, 0
tx_energy .byte ("E"-32)*2, ("N"-32)*2, ("E"-32)*2, ("R"-32)*2, ("G"-32)*2, ("Y"-32)*2, 0
tx_clear  .byte ("W"-32)*2, ("A"-32)*2, ("V"-32)*2, ("E"-32)*2, 0
          .byte ("C"-32)*2, ("L"-32)*2, ("E"-32)*2, ("A"-32)*2, ("R"-32)*2
tx_lost   .byte ("A"-32)*2, ("R"-32)*2, ("C"-32)*2, 0, ("L"-32)*2, ("O"-32)*2, ("S"-32)*2, ("T"-32)*2
tx_repair .byte ("F"-32)*2, 0, ("R"-32)*2, ("E"-32)*2, ("P"-32)*2, ("A"-32)*2, ("I"-32)*2, ("R"-32)*2, 0, 0
tx_pirates .byte ("P"-32)*2, ("I"-32)*2, ("R"-32)*2, ("A"-32)*2, ("T"-32)*2, ("E"-32)*2, ("S"-32)*2, ("!"-32)*2
tx_planet .byte ("P"-32)*2, ("L"-32)*2, ("A"-32)*2, ("N"-32)*2, ("E"-32)*2, ("T"-32)*2
tx_timeup .byte ("T"-32)*2, ("I"-32)*2, ("M"-32)*2, ("E"-32)*2, 0, ("U"-32)*2, ("P"-32)*2
tx_warning .byte ("W"-32)*2, ("A"-32)*2, ("R"-32)*2, ("N"-32)*2, ("I"-32)*2, ("N"-32)*2, ("G"-32)*2
tx_pclear .byte ("P"-32)*2, ("L"-32)*2, ("A"-32)*2, ("N"-32)*2, ("E"-32)*2, ("T"-32)*2, 0, ("C"-32)*2, ("L"-32)*2, ("E"-32)*2, ("A"-32)*2, ("R"-32)*2
tx_ptime .byte 0, 0, ("T"-32)*2, ("I"-32)*2, ("M"-32)*2, ("E"-32)*2, 0
tx_hold .byte ("H"-32)*2, ("O"-32)*2, ("L"-32)*2, ("D"-32)*2, 0, 0, ("-"-32)*2, ("-"-32)*2, ("-"-32)*2, ("-"-32)*2, ("H"-32)*2, ("O"-32)*2, ("L"-32)*2, ("D"-32)*2, 0, ("B"-32)*2, ("E"-32)*2, ("A"-32)*2, ("S"-32)*2, ("T"-32)*2, ("H"-32)*2, ("O"-32)*2, ("L"-32)*2, ("D"-32)*2, 0, 0, ("O"-32)*2, ("R"-32)*2, ("E"-32)*2, 0
tx_storm .byte ("S"-32)*2, ("T"-32)*2, ("O"-32)*2, ("R"-32)*2, ("M"-32)*2, 0, ("C"-32)*2, ("O"-32)*2, ("M"-32)*2, ("I"-32)*2, ("N"-32)*2, ("G"-32)*2
tx_allclear .byte ("A"-32)*2, ("L"-32)*2, ("L"-32)*2, 0, ("C"-32)*2, ("L"-32)*2, ("E"-32)*2, ("A"-32)*2, ("R"-32)*2
tx_archit .byte ("A"-32)*2, ("R"-32)*2, ("C"-32)*2, 0, ("H"-32)*2, ("I"-32)*2, ("T"-32)*2
tx_holdsfull .byte ("H"-32)*2,("O"-32)*2,("L"-32)*2,("D"-32)*2,("S"-32)*2,0,("F"-32)*2,("U"-32)*2,("L"-32)*2,("L"-32)*2   ; 'HOLDS FULL' (10)
tx_relic .byte ("R"-32)*2,("E"-32)*2,("L"-32)*2,("I"-32)*2,("C"-32)*2,0,("A"-32)*2,("B"-32)*2,("O"-32)*2,("A"-32)*2,("R"-32)*2,("D"-32)*2   ; 'RELIC ABOARD' (12)
; the worlds (5 letters each, surface.asm pl_world)
tx_worlds
    .byte ("V"-32)*2, ("E"-32)*2, ("R"-32)*2, ("D"-32)*2, ("A"-32)*2
    .byte ("R"-32)*2, ("U"-32)*2, ("B"-32)*2, ("R"-32)*2, ("A"-32)*2
    .byte ("G"-32)*2, ("L"-32)*2, ("A"-32)*2, ("C"-32)*2, ("I"-32)*2
    .byte ("U"-32)*2, ("M"-32)*2, ("B"-32)*2, ("R"-32)*2, ("A"-32)*2
    .byte ("A"-32)*2, ("R"-32)*2, ("E"-32)*2, ("N"-32)*2, ("A"-32)*2
    .byte ("T"-32)*2, ("O"-32)*2, ("X"-32)*2, ("I"-32)*2, ("S"-32)*2
tx_incoming .byte ("R"-32)*2, ("O"-32)*2, ("C"-32)*2, ("K"-32)*2, ("S"-32)*2, 0, ("I"-32)*2, ("N"-32)*2, ("C"-32)*2, ("O"-32)*2, ("M"-32)*2, ("I"-32)*2, ("N"-32)*2, ("G"-32)*2
