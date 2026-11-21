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
