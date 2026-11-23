; ===========================================================================
; Bank 6: two more 40-column screens after the star chart (button 2 from
; the chart: gs_go = 3, the BASIC's achloop): the close-up chart (ac_view 0),
; then the achievements (1); button 2 on to the next, fire back to the map.
;
; The close-up chart: 5 x 5 grid cells round the Ark, each 8 columns by 2
; rows: a sector seen shows its number (its kind's symbol once visited, ?
; before), the visited ones their warps (- across, | \ / down, through the
; row between); the Ark's sector marked.
;
; The achievements (bank 6, with its own copy of the 40-column font at
; $A000): 16 in a 4 x 4 grid, an icon (two glyphs of the font: grey until
; earned, then in colour) over each name; the stick picks one, and row 10
; says what it takes (and how far along). Button 2 or fire: back to the
; map. Reached from the star chart (button 2: gs_go = 3, the BASIC's
; achloop). The checks themselves are in text40.asm (bank 1).
; ===========================================================================

BANK_ACH  = 6
ac_i      = $27F8   ; (sv_t4)
ac_view   = $22F7   ; 0 the close-up chart, 1 the achievements
cz_x      = $22F0   ; (the close-up's scratch: the sector view's items,
cz_d      = $22F1   ;  rebuilt when it's back)
cz_wc     = $22F2
cz_wr     = $22F3
cz_ox     = $22F4
cz_oy     = $22F5
cz_k      = $22F6

ac_enter
    lda #%01000011          ; 320A, 1-byte characters (the map's)
    sta sCTRL
    lda #>font320
    sta sCHARBASE
    lda #3
    sta gs_go
    lda #0
    sta sv_sel
    sta ac_view
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
    lda ac_view
    bne ac_f_ab
    jsr cz_build
    jmp ac_f_nd
ac_f_ab
    jsr ac_build
ac_f_nd
    lda sp_joy
    sta sv_pjoy
    lda sp_fire
    sta sv_pf
    lda sp_fire2
    sta sv_pf2
    jsr sv_rows
    lda ac_view
    bne ac_f_ic
    rts
ac_f_ic
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
    ; button 2 (fresh): the close-up on to the achievements, they back to
    ; the map; fire: back
    lda sp_fire2
    beq ac_i_f
    lda sv_pf2
    bne ac_i_f
    lda ac_view
    bne ac_i_back
    inc ac_view
    inc sv_dirty
    lda #SFX_BEEP
    jmp sfx
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
    lda ac_view             ; (the close-up: nothing to choose)
    bne ac_i_s2
    rts
ac_i_s2
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

; ---------------------------------------------------------------------------
; the close-up chart's text
CZ_DIG    = 129     ; (tools/gfx.py: + 2 x digit)
CZ_DIGI   = 149     ; (inverted: the Ark's)
CZ_LEFT   = 169     ; (+ 2 x kind: empty, port, planet, nebula, 4 unknown)
CZ_LEFTI  = 179
CZ_RIGHT  = 189
CZ_RIGHTI = 191
CZ_ACROSS = 193
CZ_DOWNL  = 195
CZ_DOWNR  = 197
CZ_DIAGR  = 199     ; (\)
CZ_DIAGL  = 201     ; (/)
CZ_X      = 203
CZ_COLS   = 8
CZ_ROWS   = 5

cz_build
    jsr sv_cls
    ldx #0                  ; row 0: CLOSE UP   SECTOR nn
    lda #1
    jsr sv_at
    lda #<cz_s_title
    ldy #>cz_s_title
    ldx #18
    jsr sv_puts
    lda gs_sec
    clc
    adc #1
    jsr sv_dec2
    ldx gs_sec              ; the window: the Ark 3 cells in, 2 down
    lda gx_cell,x
    and #15
    sec
    sbc #3
    sta cz_ox
    lda gx_cell,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc #2
    sta cz_oy
    ; the links first (the boxes over them)
    lda #63
    sta cz_x
cz_l_s
    ldx cz_x
    lda gx_flag,x
    lsr
    bcc cz_l_sn             ; (visited only: their warps are known)
    jsr cz_place
    lda #7
    sta cz_d
cz_l_w
    ldx cz_x
    ldy cz_d
    lda gx_warp,x
    and ac_bit,y
    beq cz_l_wn
    jsr cz_link
cz_l_wn
    dec cz_d
    bpl cz_l_w
cz_l_sn
    dec cz_x
    bpl cz_l_s
    ; the boxes: the sectors seen, in the window
    lda #63
    sta cz_x
cz_b_s
    ldx cz_x
    lda gx_flag,x
    and #3
    beq cz_b_sn
    jsr cz_place
    lda cz_wc
    cmp #CZ_COLS
    bcs cz_b_sn
    lda cz_wr
    cmp #CZ_ROWS
    bcs cz_b_sn
    jsr cz_box
cz_b_sn
    dec cz_x
    bpl cz_b_s
    ldx #11
    lda #1
    jsr sv_at
    lda #<cz_s_help
    ldy #>cz_s_help
    ldx #35
    jmp sv_puts

; sector cz_x's place in the window: cz_wc, cz_wr (out of it: big, either
; way)
cz_place
    ldx cz_x
    lda gx_cell,x
    and #15
    sec
    sbc cz_ox
    sta cz_wc
    lda gx_cell,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc cz_oy
    sta cz_wr
    rts

; sector cz_x's box: its end (kind, or unknown), two digits, the end; the
; Ark's inverted (cz_k: 0, or the inverted codes' offset)
cz_box
    lda cz_wr
    asl
    adc #1
    tax
    lda cz_wc
    asl
    asl
    adc cz_wc               ; x 5
    jsr sv_at
    lda #0
    ldx cz_x
    cpx gs_sec
    bne cz_bx_k
    lda #CZ_LEFTI-CZ_LEFT   ; (10: the same for the digits and the end... )
cz_bx_k
    sta cz_k
    lda gx_flag,x           ; its kind's end (unknown, not yet visited)
    lsr
    lda #4
    bcc cz_bx_u
    lda gx_info,x
    and #3
cz_bx_u
    asl
    adc #CZ_LEFT
    adc cz_k
    jsr sv_putc
    lda cz_x                ; the digits: sector + 1
    clc
    adc #1
    ldx #0
cz_bx_t
    cmp #10
    bcc cz_bx_o
    sbc #10
    inx
    bne cz_bx_t
cz_bx_o
    pha
    txa
    asl
    adc #CZ_DIG
    jsr cz_putk
    pla
    asl
    adc #CZ_DIG
    jsr cz_putk
    lda cz_k                ; the end (inverted: +2)
    beq cz_bx_r
    lda #2
cz_bx_r
    clc
    adc #CZ_RIGHT
    jmp sv_putc
; a digit's code, inverted for the Ark's (the inverted digits are 20 on)
cz_putk
    ldx cz_k
    beq cz_pk
    clc
    adc #CZ_DIGI-CZ_DIG
cz_pk
    jmp sv_putc

; sector cz_x's warp cz_d: its line (from the cell whose line it is: cz_lc,
; cz_lr; which: cz_lk)
cz_link
    ldy cz_d
    clc
    lda cz_wc
    adc cz_lc,y
    sta ac_i                ; (its cell's column)
    cmp #CZ_COLS
    bcc cz_lk_r_far592
    jmp cz_lk_r
cz_lk_r_far592
    clc
    lda cz_wr
    adc cz_lr,y
    cmp #CZ_ROWS
    bcs cz_lk_r
    asl
    adc #1
    sta sv_t0               ; (its box's row)
    lda ac_i
    asl
    asl
    adc ac_i
    sta sv_t1               ; (its box's column)
    lda cz_lk,y
    cmp #2
    bne cz_lk_d
    ldx sv_t0               ; across: the column after the box
    lda sv_t1
    clc
    adc #4
    jsr sv_at
    lda #CZ_ACROSS
    jmp sv_putc
cz_lk_d
    cmp #4
    bne cz_lk_g
    ldx sv_t0               ; down: the row below, between the digits
    inx
    lda sv_t1
    clc
    adc #1
    jsr sv_at
    lda #CZ_DOWNL
    jsr sv_putc
    lda #CZ_DOWNR
    jmp sv_putc
cz_lk_g
    ldx sv_t0               ; a diagonal: the row below, the column after
    inx                     ;  the box (\) or before it (/); X if the other
    cmp #3                  ;  one's there
    bne cz_lk_l
    lda sv_t1
    clc
    adc #4
    jsr sv_at
    lda #CZ_DIAGR
    ldx #CZ_DIAGL
    bne cz_lk_x
cz_lk_l
    lda sv_t1
    beq cz_lk_r             ; (off the left)
    sec
    sbc #1
    jsr sv_at
    lda #CZ_DIAGL
    ldx #CZ_DIAGR
cz_lk_x
    stx sv_t2
    ldy #0
    pha
    lda (sv_dst),y
    cmp sv_t2
    bne cz_lk_w
    pla
    lda #CZ_X
    pha
cz_lk_w
    pla
    jmp sv_putc
cz_lk_r
    rts

; by warp direction (0 up, clockwise): the cell whose line it is (column,
; row from the sector's), and which line (2 across, 3 down-right, 4 down,
; 5 down-left)
cz_lc     .byte 0, 1, 0, 0, 0, 0, -1, -1
cz_lr     .byte -1, -1, 0, 0, 0, 0, 0, -1
cz_lk     .byte 4, 5, 2, 3, 4, 5, 2, 3
cz_s_title .byte ("C"-32)*2,("L"-32)*2,("O"-32)*2,("S"-32)*2,("E"-32)*2,0,("U"-32)*2,("P"-32)*2,0,0,0,("S"-32)*2,("E"-32)*2,("C"-32)*2,("T"-32)*2,("O"-32)*2,("R"-32)*2,0   ; 'CLOSE UP   SECTOR ' (18)
cz_s_help .byte ("F"-32)*2,("I"-32)*2,("R"-32)*2,("E"-32)*2,(":"-32)*2,0,("B"-32)*2,("A"-32)*2,("C"-32)*2,("K"-32)*2,0,0,0,("B"-32)*2,("U"-32)*2,("T"-32)*2,("T"-32)*2,("O"-32)*2,("N"-32)*2,0,("2"-32)*2,(":"-32)*2,0,("A"-32)*2,("C"-32)*2,("H"-32)*2,("I"-32)*2,("E"-32)*2,("V"-32)*2,("E"-32)*2,("M"-32)*2,("E"-32)*2,("N"-32)*2,("T"-32)*2,("S"-32)*2   ; 'FIRE: BACK   BUTTON 2: ACHIEVEMENTS' (35)
