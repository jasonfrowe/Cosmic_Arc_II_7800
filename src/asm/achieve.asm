; ===========================================================================
; The achievements (bank 6, with its own copy of the 40-column font at
; $A000): 16 in a 4 x 4 grid, an icon (two glyphs of the font: grey until
; earned, then in colour) over each name; the stick picks one, and row 10
; says what it takes (and how far along). Button 2 or fire: back to the
; map. Reached from the star chart (button 2: gs_go = 3, the BASIC's
; achloop). The checks themselves are in text40.asm (bank 1).
; ===========================================================================

BANK_ACH  = 6
ac_i      = $27F8   ; (sv_t4)

ac_enter
    lda #%01000011          ; 320A, 1-byte characters (the map's)
    sta sCTRL
    lda #>font320
    sta sCHARBASE
    lda #3
    sta gs_go
    lda #0
    sta sv_sel
    lda #8
    sta sv_pjoy
    lda #1
    sta sv_pf
    sta sv_pf2
    sta sv_dirty
    jmp ac_check

ac_frame
    inc sv_tick
    jsr ac_input
    lda sv_dirty
    beq ac_f_nd
    lda #0
    sta sv_dirty
    jsr ac_build
ac_f_nd
    lda sp_joy
    sta sv_pjoy
    lda sp_fire
    sta sv_pf
    lda sp_fire2
    sta sv_pf2
    jsr sv_rows
    ; the icons: one object each (two glyphs), grey or in colour
    ldx #15
ac_f_i
    stx ac_i
    txa
    asl
    adc #<ac_codes
    sta temp1
    lda #>ac_codes
    adc #0
    sta temp2
    jsr ac_has
    lda #3                  ; (grey)
    bcc ac_f_p
    txa
    and #3
    ora #4                  ; (palettes 4-7 by column)
ac_f_p
    asl
    asl
    asl
    asl
    asl
    ora #30                 ; (2 wide: 32 - 2)
    sta temp3
    txa
    and #3
    tay
    lda ac_x,y
    sta temp4
    txa
    lsr
    lsr
    asl
    adc #2                  ; row 2 + 2 x its row
    sta temp5
    jsr plotcharacters
    ldx ac_i
    dex
    bpl ac_f_i
    rts
ac_x      .byte 16, 56, 96, 136     ; (column 4 + 10 x: 4 units a character)

; C = 1: achievement X earned (X kept)
ac_has
    lda ac_bit,x
    cpx #8
    bcs ac_h_hi
    and gs_ach
    jmp ac_h_r
ac_h_hi
    and gs_ach+1
ac_h_r
    cmp #1
    rts

ac_input
    ; button 2 or fire (fresh): back to the map
    lda sp_fire2
    beq ac_i_f
    lda sv_pf2
    beq ac_i_back
ac_i_f
    lda sp_fire
    beq ac_i_s
    lda sv_pf
    bne ac_i_s
ac_i_back
    lda #0
    sta gs_go
    rts
ac_i_s
    ; the stick (fresh): up, down a row (4), left, right one
    ldx sp_joy
    cpx sv_pjoy
    beq ac_i_r
    lda sv_sel
    cpx #0
    bne ac_i_dn
    sec
    sbc #4
    bcc ac_i_r
    bcs ac_i_set
ac_i_dn
    cpx #4
    bne ac_i_rt
    clc
    adc #4
    jmp ac_i_set
ac_i_rt
    cpx #2
    bne ac_i_lt
    clc
    adc #1
    jmp ac_i_set
ac_i_lt
    cpx #6
    bne ac_i_r
    sec
    sbc #1
    bcc ac_i_r
ac_i_set
    cmp #16
    bcs ac_i_r
    sta sv_sel
    inc sv_dirty
    lda #SFX_BEEP
    jmp sfx
ac_i_r
    rts

; the text: ACHIEVEMENTS  nn OF 16; the names (the cursor on one); what it
; takes; the help
ac_build
    jsr sv_cls
    ldx #0
    lda #1
    jsr sv_at
    lda #<ac_s_title
    ldy #>ac_s_title
    ldx #12
    jsr sv_puts
    ldx #0                  ; (how many)
    stx sv_t3
ac_b_cn
    jsr ac_has
    bcc ac_b_cn2
    inc sv_t3
ac_b_cn2
    inx
    cpx #16
    bne ac_b_cn
    ldx #0
    lda #28
    jsr sv_at
    lda sv_t3
    jsr sv_dec2
    lda #<ac_s_of16
    ldy #>ac_s_of16
    ldx #6
    jsr sv_puts
    ; the names: row 3 + 2 x its row, column 10 x its column (the cursor
    ; first)
    ldx #15
ac_b_n
    stx ac_i
    txa
    and #3
    tay
    lda ac_col,y
    pha
    txa
    lsr
    lsr
    asl
    adc #3
    tax
    pla
    jsr sv_at
    lda #0
    ldx ac_i
    cpx sv_sel
    bne ac_b_c
    lda #178
ac_b_c
    jsr sv_putc
    lda ac_i                ; ac_names + 9 x
    asl
    asl
    asl
    adc ac_i
    adc #<ac_names
    pha
    lda #>ac_names
    adc #0
    tay
    pla
    ldx #9
    jsr sv_puts
    ldx ac_i
    dex
    bpl ac_b_n
    ; row 10: what the selected one takes, and how far along
    ldx #10
    lda #1
    jsr sv_at
    ldx sv_sel
    lda ac_dlo,x
    pha
    lda ac_dhi,x
    tay
    lda ac_dlen,x
    tax
    pla
    jsr sv_puts
    ldx sv_sel
    lda ac_prog,x
    beq ac_b_h
    jsr ac_count
    pha
    lda #1
    jsr sv_skip
    pla
    jsr sv_dec2
    lda #("/"-32)*2
    jsr sv_putc
    ldx sv_sel
    lda ac_max,x
    jsr sv_dec2
ac_b_h
    ldx #11
    lda #1
    jsr sv_at
    lda #<ac_s_help
    ldy #>ac_s_help
    ldx #30
    jmp sv_puts
ac_col    .byte 0, 10, 20, 30

; how far along (A: ac_prog's kind): 1 kinds with a pair, 2 kinds with one,
; 3 pirates (at most 99), 4 sectors visited, 5 storm rocks
ac_count
    cmp #3
    bcs ac_ct_3
    sta sv_t2               ; (1: a pair; 2: one)
    lda #0
    sta sv_t3
    ldx #5
ac_ct_k
    lda gs_keep,x
    beq ac_ct_kn
    cmp #2
    bcs ac_ct_ky
    lda sv_t2
    cmp #2
    bne ac_ct_kn
ac_ct_ky
    inc sv_t3
ac_ct_kn
    dex
    bpl ac_ct_k
    lda sv_t3
    rts
ac_ct_3
    bne ac_ct_4
    lda gs_kills+1
    bne ac_ct_99
    lda gs_kills
    cmp #100
    bcc ac_ct_r
ac_ct_99
    lda #99
ac_ct_r
    rts
ac_ct_4
    cmp #4
    bne ac_ct_5
    lda #0
    sta sv_t3
    ldx #63
ac_ct_v
    lda gx_flag,x
    lsr
    bcc ac_ct_vn
    inc sv_t3
ac_ct_vn
    dex
    bpl ac_ct_v
    lda sv_t3
    rts
ac_ct_5
    lda gs_storms
    cmp #100
    bcs ac_ct_99
    rts

; the icons' glyph codes (two each: 180 + 4i, 182 + 4i)
ac_codes
    .byte 180, 182
    .byte 184, 186
    .byte 188, 190
    .byte 192, 194
    .byte 196, 198
    .byte 200, 202
    .byte 204, 206
    .byte 208, 210
    .byte 212, 214
    .byte 216, 218
    .byte 220, 222
    .byte 224, 226
    .byte 228, 230
    .byte 232, 234
    .byte 236, 238
    .byte 240, 242
ac_prog   .byte 1, 2, 3, 4, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0
ac_max    .byte 6, 6, 50, 64, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0
ac_dlo    .byte <ac_d0, <ac_d1, <ac_d2, <ac_d3, <ac_d4, <ac_d5, <ac_d6, <ac_d7, <ac_d8, <ac_d9, <ac_d10, <ac_d11, <ac_d12, <ac_d13, <ac_d14, <ac_d15
ac_dhi    .byte >ac_d0, >ac_d1, >ac_d2, >ac_d3, >ac_d4, >ac_d5, >ac_d6, >ac_d7, >ac_d8, >ac_d9, >ac_d10, >ac_d11, >ac_d12, >ac_d13, >ac_d14, >ac_d15
ac_dlen   .byte 25, 32, 18, 18, 25, 17, 25, 32, 32, 24, 15, 27, 31, 21, 13, 26
ac_d0 .byte ("K"-32)*2,("E"-32)*2,("E"-32)*2,("P"-32)*2,0,("A"-32)*2,0,("P"-32)*2,("A"-32)*2,("I"-32)*2,("R"-32)*2,0,("O"-32)*2,("F"-32)*2,0,("E"-32)*2,("V"-32)*2,("E"-32)*2,("R"-32)*2,("Y"-32)*2,0,("K"-32)*2,("I"-32)*2,("N"-32)*2,("D"-32)*2   ; 'KEEP A PAIR OF EVERY KIND' (25)
ac_d1 .byte ("K"-32)*2,("E"-32)*2,("E"-32)*2,("P"-32)*2,0,("O"-32)*2,("N"-32)*2,("E"-32)*2,0,("O"-32)*2,("F"-32)*2,0,("E"-32)*2,("A"-32)*2,("C"-32)*2,("H"-32)*2,0,("B"-32)*2,("Y"-32)*2,0,("S"-32)*2,("T"-32)*2,("A"-32)*2,("R"-32)*2,("D"-32)*2,("A"-32)*2,("T"-32)*2,("E"-32)*2,0,("1"-32)*2,("5"-32)*2,("0"-32)*2   ; 'KEEP ONE OF EACH BY STARDATE 150' (32)
ac_d2 .byte ("D"-32)*2,("E"-32)*2,("S"-32)*2,("T"-32)*2,("R"-32)*2,("O"-32)*2,("Y"-32)*2,0,("5"-32)*2,("0"-32)*2,0,("P"-32)*2,("I"-32)*2,("R"-32)*2,("A"-32)*2,("T"-32)*2,("E"-32)*2,("S"-32)*2   ; 'DESTROY 50 PIRATES' (18)
ac_d3 .byte ("V"-32)*2,("I"-32)*2,("S"-32)*2,("I"-32)*2,("T"-32)*2,0,("E"-32)*2,("V"-32)*2,("E"-32)*2,("R"-32)*2,("Y"-32)*2,0,("S"-32)*2,("E"-32)*2,("C"-32)*2,("T"-32)*2,("O"-32)*2,("R"-32)*2   ; 'VISIT EVERY SECTOR' (18)
ac_d4 .byte ("H"-32)*2,("A"-32)*2,("V"-32)*2,("E"-32)*2,0,("1"-32)*2,("0"-32)*2,("0"-32)*2,("0"-32)*2,("0"-32)*2,0,("C"-32)*2,("R"-32)*2,("E"-32)*2,("D"-32)*2,("I"-32)*2,("T"-32)*2,("S"-32)*2,0,("A"-32)*2,("B"-32)*2,("O"-32)*2,("A"-32)*2,("R"-32)*2,("D"-32)*2   ; 'HAVE 10000 CREDITS ABOARD' (25)
ac_d5 .byte ("B"-32)*2,("U"-32)*2,("Y"-32)*2,0,("E"-32)*2,("V"-32)*2,("E"-32)*2,("R"-32)*2,("Y"-32)*2,0,("U"-32)*2,("P"-32)*2,("G"-32)*2,("R"-32)*2,("A"-32)*2,("D"-32)*2,("E"-32)*2   ; 'BUY EVERY UPGRADE' (17)
ac_d6 .byte ("B"-32)*2,("R"-32)*2,("I"-32)*2,("N"-32)*2,("G"-32)*2,0,("T"-32)*2,("H"-32)*2,("E"-32)*2,0,("R"-32)*2,("E"-32)*2,("L"-32)*2,("I"-32)*2,("C"-32)*2,0,("T"-32)*2,("O"-32)*2,0,("A"-32)*2,0,("P"-32)*2,("O"-32)*2,("R"-32)*2,("T"-32)*2   ; 'BRING THE RELIC TO A PORT' (25)
ac_d7 .byte ("C"-32)*2,("L"-32)*2,("E"-32)*2,("A"-32)*2,("R"-32)*2,0,("A"-32)*2,("N"-32)*2,0,("E"-32)*2,("N"-32)*2,("C"-32)*2,("O"-32)*2,("U"-32)*2,("N"-32)*2,("T"-32)*2,("E"-32)*2,("R"-32)*2,0,("W"-32)*2,("I"-32)*2,("T"-32)*2,("H"-32)*2,("O"-32)*2,("U"-32)*2,("T"-32)*2,0,("A"-32)*2,0,("H"-32)*2,("I"-32)*2,("T"-32)*2   ; 'CLEAR AN ENCOUNTER WITHOUT A HIT' (32)
ac_d8 .byte ("C"-32)*2,("A"-32)*2,("T"-32)*2,("C"-32)*2,("H"-32)*2,0,("A"-32)*2,("L"-32)*2,("L"-32)*2,0,("O"-32)*2,("N"-32)*2,0,("A"-32)*2,0,("P"-32)*2,("L"-32)*2,("A"-32)*2,("N"-32)*2,("E"-32)*2,("T"-32)*2,(","-32)*2,0,("N"-32)*2,("O"-32)*2,("N"-32)*2,("E"-32)*2,0,("L"-32)*2,("O"-32)*2,("S"-32)*2,("T"-32)*2   ; 'CATCH ALL ON A PLANET, NONE LOST' (32)
ac_d9 .byte ("S"-32)*2,("H"-32)*2,("O"-32)*2,("O"-32)*2,("T"-32)*2,0,("D"-32)*2,("O"-32)*2,("W"-32)*2,("N"-32)*2,0,("5"-32)*2,0,("S"-32)*2,("T"-32)*2,("O"-32)*2,("R"-32)*2,("M"-32)*2,0,("R"-32)*2,("O"-32)*2,("C"-32)*2,("K"-32)*2,("S"-32)*2   ; 'SHOOT DOWN 5 STORM ROCKS' (24)
ac_d10 .byte ("R"-32)*2,("E"-32)*2,("A"-32)*2,("C"-32)*2,("H"-32)*2,0,("S"-32)*2,("E"-32)*2,("C"-32)*2,("T"-32)*2,("O"-32)*2,("R"-32)*2,0,("6"-32)*2,("4"-32)*2   ; 'REACH SECTOR 64' (15)
ac_d11 .byte ("S"-32)*2,("U"-32)*2,("R"-32)*2,("V"-32)*2,("I"-32)*2,("V"-32)*2,("E"-32)*2,0,("A"-32)*2,0,("W"-32)*2,("A"-32)*2,("V"-32)*2,("E"-32)*2,0,("1"-32)*2,("0"-32)*2,0,("E"-32)*2,("N"-32)*2,("C"-32)*2,("O"-32)*2,("U"-32)*2,("N"-32)*2,("T"-32)*2,("E"-32)*2,("R"-32)*2   ; 'SURVIVE A WAVE 10 ENCOUNTER' (27)
ac_d12 .byte ("D"-32)*2,("O"-32)*2,("C"-32)*2,("K"-32)*2,0,("A"-32)*2,("T"-32)*2,0,("A"-32)*2,0,("P"-32)*2,("O"-32)*2,("R"-32)*2,("T"-32)*2,0,("O"-32)*2,("N"-32)*2,0,("A"-32)*2,("N"-32)*2,0,("E"-32)*2,("M"-32)*2,("P"-32)*2,("T"-32)*2,("Y"-32)*2,0,("T"-32)*2,("A"-32)*2,("N"-32)*2,("K"-32)*2   ; 'DOCK AT A PORT ON AN EMPTY TANK' (31)
ac_d13 .byte ("S"-32)*2,("A"-32)*2,("V"-32)*2,("E"-32)*2,0,("5"-32)*2,("0"-32)*2,("0"-32)*2,("0"-32)*2,0,("I"-32)*2,("N"-32)*2,0,("T"-32)*2,("H"-32)*2,("E"-32)*2,0,("B"-32)*2,("A"-32)*2,("N"-32)*2,("K"-32)*2   ; 'SAVE 5000 IN THE BANK' (21)
ac_d14 .byte ("F"-32)*2,("I"-32)*2,("L"-32)*2,("L"-32)*2,0,("2"-32)*2,("0"-32)*2,0,("H"-32)*2,("O"-32)*2,("L"-32)*2,("D"-32)*2,("S"-32)*2   ; 'FILL 20 HOLDS' (13)
ac_d15 .byte ("G"-32)*2,("E"-32)*2,("T"-32)*2,0,("H"-32)*2,("O"-32)*2,("M"-32)*2,("E"-32)*2,0,("I"-32)*2,("N"-32)*2,0,("T"-32)*2,("H"-32)*2,("E"-32)*2,0,("E"-32)*2,("S"-32)*2,("C"-32)*2,("A"-32)*2,("P"-32)*2,("E"-32)*2,0,("P"-32)*2,("O"-32)*2,("D"-32)*2   ; 'GET HOME IN THE ESCAPE POD' (26)
ac_s_title .byte ("A"-32)*2,("C"-32)*2,("H"-32)*2,("I"-32)*2,("E"-32)*2,("V"-32)*2,("E"-32)*2,("M"-32)*2,("E"-32)*2,("N"-32)*2,("T"-32)*2,("S"-32)*2   ; 'ACHIEVEMENTS' (12)
ac_s_of16 .byte 0,("O"-32)*2,("F"-32)*2,0,("1"-32)*2,("6"-32)*2   ; ' OF 16' (6)
ac_s_help .byte ("S"-32)*2,("T"-32)*2,("I"-32)*2,("C"-32)*2,("K"-32)*2,(":"-32)*2,0,("C"-32)*2,("H"-32)*2,("O"-32)*2,("O"-32)*2,("S"-32)*2,("E"-32)*2,0,0,0,("B"-32)*2,("U"-32)*2,("T"-32)*2,("T"-32)*2,("O"-32)*2,("N"-32)*2,0,("2"-32)*2,(":"-32)*2,0,("B"-32)*2,("A"-32)*2,("C"-32)*2,("K"-32)*2   ; 'STICK: CHOOSE   BUTTON 2: BACK' (30)
