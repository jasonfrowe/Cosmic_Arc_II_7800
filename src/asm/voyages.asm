; ===========================================================================
; Bank 6: the voyage screen (after the title, with a SaveKey): the three
; save slots (save.asm), and back to the title. 40 columns, as the map's
; screens (text40.asm; this bank's copy of the font at $A000).
;
;   row 0       SELECT A VOYAGE (a cyan bar)
;   rows 2-7    each slot: VOYAGE n, its sector and stardate; under it (grey)
;               its credits and achievements. Empty: NEW VOYAGE (green);
;               damaged: in red, fire starts a new one there
;   row 8       BACK TO THE TITLE
;   row 10      the question (clear it?) or what happened
;   row 11      the help
;
; The stick picks a line (a gold bar), fire plays it: a saved voyage goes on
; (gs_go 2), an empty or damaged slot starts a new one (gs_go 1), the last
; line goes back to the title (gs_go 3). Button 2 on a saved voyage asks to
; clear it (fire yes, button 2 no). No SaveKey: gs_go 1 at once, not saved.
;
; Reading the slots puts each into the voyage's RAM in turn (a new voyage or
; Continue sets it all again); the screen keeps only a summary of each.
; ===========================================================================

vs_sum    = $23A0   ; [3 x 8] each slot: its state (sl_load's), the sector,
                    ;   stardate (lo, hi), credits (3, BCD), achievements
                    ;   (deep space's HUD line: rebuilt with every wave)
vs_t0     = $27F9   ; (the port's scratch: free before a voyage)
vs_t1     = $27FA
vs_k      = $27FB   ; the slot being read or written
vs_msg    = $27FC   ; 0 none, 1 cleared, 2 the SaveKey didn't answer
vs_ask    = $27FD   ; 1: asking to clear the selected one
vs_row    = $27FE

vs_enter
    lda #%01000011          ; 320A, 1-byte characters (the map's)
    sta sCTRL
    lda #>font320b
    sta sCHARBASE
    lda #0
    sta gs_go
    sta gs_slot
    sta vs_msg
    sta vs_ask
    lda #8
    sta sv_pjoy
    lda #1
    sta sv_pf
    sta sv_pf2
    sta sv_dirty
    ldx #2
vs_en_l
    stx vs_k
    jsr vs_read
    cmp #3
    beq vs_en_none
    ldx vs_k
    dex
    bpl vs_en_l
    ; the cursor on the first saved voyage, or the first slot
    ldx #0
vs_en_c
    lda vs_sum,x
    cmp #1
    beq vs_en_cs
    txa
    clc
    adc #8
    tax
    cpx #24
    bne vs_en_c
    ldx #0
vs_en_cs
    txa
    lsr
    lsr
    lsr
    sta sv_sel
    rts
vs_en_none
    lda #1                  ; no SaveKey: a new voyage, not saved
    sta gs_go
    rts

; read slot vs_k: its summary. A: sl_load's answer
vs_read
    lda vs_k
    jsr sl_load
    pha
    lda vs_k
    asl
    asl
    asl
    tax
    pla
    sta vs_sum,x
    cmp #1
    bne vs_rd_r
    lda gs_sec
    sta vs_sum+1,x
    lda gs_date
    sta vs_sum+2,x
    lda gs_date+1
    sta vs_sum+3,x
    lda gs_cred
    sta vs_sum+4,x
    lda gs_cred+1
    sta vs_sum+5,x
    lda gs_cred+2
    sta vs_sum+6,x
    lda gs_ach              ; achievements: the bits set
    sta vs_t0
    lda gs_ach+1
    sta vs_t1
    ldy #0
    lda #16
    sta vs_row
vs_rd_b
    lsr vs_t1
    ror vs_t0
    bcc vs_rd_bn
    iny
vs_rd_bn
    dec vs_row
    bne vs_rd_b
    tya
    sta vs_sum+7,x
    lda #1
vs_rd_r
    rts

vs_frame
    inc sv_tick
    jsr vs_input
    lda sv_dirty
    beq vs_f_nd
    lda #0
    sta sv_dirty
    jsr vs_build
vs_f_nd
    lda sp_joy
    sta sv_pjoy
    lda sp_fire
    sta sv_pf
    lda sp_fire2
    sta sv_pf2
    jmp sv_rows

vs_input
    lda sp_fire             ; (fresh presses)
    beq vs_i_b2
    lda sv_pf
    bne vs_i_b2
    jmp vs_fire
vs_i_b2
    lda sp_fire2
    beq vs_i_st
    lda sv_pf2
    bne vs_i_st
    jmp vs_but2
vs_i_st
    lda vs_ask              ; (asking: only the buttons)
    bne vs_i_r
    ldx sp_joy
    cpx sv_pjoy
    beq vs_i_r
    cpx #0
    bne vs_i_dn
    lda sv_sel
    beq vs_i_r
    dec sv_sel
    jmp vs_i_mv
vs_i_dn
    cpx #4
    bne vs_i_r
    lda sv_sel
    cmp #3
    bcs vs_i_r
    inc sv_sel
vs_i_mv
    lda #0
    sta vs_msg
    inc sv_dirty
    lda #SFX_BEEP
    jmp sfx
vs_i_r
    rts

; fire: yes to the question; else play the line
vs_fire
    inc sv_dirty
    lda vs_ask
    beq vs_fi_go
    lda #0
    sta vs_ask
    lda sv_sel
    sta vs_k
    jsr sl_clear
    lda #2
    bcs vs_fi_m
    lda vs_k
    asl
    asl
    asl
    tax
    lda #0
    sta vs_sum,x
    lda #SFX_CLEAR
    jsr sfx
    lda #1
vs_fi_m
    sta vs_msg
    rts
vs_fi_go
    lda sv_sel
    cmp #3
    bne vs_fi_s
    sta gs_go               ; the title
    rts
vs_fi_s
    tax
    clc
    adc #1
    sta gs_slot
    txa
    asl
    asl
    asl
    tax
    lda vs_sum,x
    cmp #1
    beq vs_fi_c
    lda #1                  ; a new voyage here
    sta gs_go
    rts
vs_fi_c
    lda #2                  ; this one, on
    sta gs_go
    rts

; button 2: no to the question; else ask to clear a saved (or damaged) one
vs_but2
    lda vs_ask
    beq vs_b2_a
    lda #0
    sta vs_ask
    inc sv_dirty
    rts
vs_b2_a
    lda sv_sel
    cmp #3
    bcs vs_b2_r
    asl
    asl
    asl
    tax
    lda vs_sum,x
    beq vs_b2_r
    lda #1
    sta vs_ask
    lda #0
    sta vs_msg
    inc sv_dirty
    lda #SFX_HIT
    jmp sfx
vs_b2_r
    rts

; the text
vs_build
    jsr sv_cls
    ldx #0                  ; row 0: the heading, a cyan bar
    lda #1
    jsr sv_at
    lda #<vs_s_head
    ldy #>vs_s_head
    ldx #15
    jsr sv_puts
    ldx #0
    lda #0
    ldy #40
    jsr sv_inv
    ldx #0
    lda #0
    ldy #P_CYAN
    jsr sv_ink
    ldx #2
vs_b_sl
    stx vs_k
    jsr vs_slot
    ldx vs_k
    dex
    bpl vs_b_sl
    ldx #8                  ; row 8: back to the title
    stx vs_row
    lda #1
    jsr sv_at
    lda #<vs_s_title
    ldy #>vs_s_title
    ldx #17
    jsr sv_puts
    ldx #8
    lda #0
    ldy #P_GREY
    jsr sv_ink
    lda sv_sel
    cmp #3
    bne vs_b_q
    jsr vs_bar
vs_b_q
    ; row 10: the question, or what happened
    lda vs_ask
    beq vs_b_m
    ldx #10
    lda #0
    jsr sv_at
    lda #<vs_s_ask1
    ldy #>vs_s_ask1
    ldx #13
    jsr sv_puts
    lda sv_sel
    clc
    adc #1
    jsr tx_digit
    jsr sv_putc
    lda #<vs_s_ask2
    ldy #>vs_s_ask2
    ldx #26
    jsr sv_puts
    ldx #10
    lda #0
    ldy #P_RED
    jsr sv_ink
    jmp vs_b_h
vs_b_m
    lda vs_msg
    beq vs_b_h
    ldx #10
    lda #1
    jsr sv_at
    lda vs_msg
    cmp #1
    bne vs_b_mf
    lda #<vs_s_clr
    ldy #>vs_s_clr
    ldx #14
    bne vs_b_mp
vs_b_mf
    lda #<vs_s_fail
    ldy #>vs_s_fail
    ldx #26
vs_b_mp
    jsr sv_puts
    ldx #10
    lda #0
    ldy #P_GOLD
    jsr sv_ink
vs_b_h
    ldx #11                 ; row 11: the help
    lda #1
    jsr sv_at
    lda #<vs_s_help
    ldy #>vs_s_help
    ldx #37
    jsr sv_puts
    ldx #11
    lda #0
    ldy #P_GREY
    jmp sv_ink

; the selected line (row vs_row): a gold bar, its colours gone
vs_bar
    ldx vs_row
    lda #0
    sta sv_bn,x
    ldy #P_GOLD
    jsr sv_ink
    ldx vs_row
    lda #0
    ldy #40
    jmp sv_inv

; slot vs_k: rows 2 + 2k (VOYAGE n, ...) and 3 + 2k (grey: credits,
; achievements)
vs_slot
    lda vs_k
    asl
    adc #2
    sta vs_row
    tax
    lda #1
    jsr sv_at
    lda #<vs_s_voy
    ldy #>vs_s_voy
    ldx #7
    jsr sv_puts
    lda vs_k
    clc
    adc #1
    jsr tx_digit
    jsr sv_putc
    ldx vs_row
    lda #12
    jsr sv_at
    lda vs_k
    asl
    asl
    asl
    tax
    stx vs_t0
    lda vs_sum,x
    cmp #1
    beq vs_sl_v
    cmp #2
    beq vs_sl_d
    lda #P_GREEN            ; empty
    jsr sv_pen
    lda #<vs_s_new
    ldy #>vs_s_new
    ldx #10
    jsr sv_puts
    jmp vs_sl_sel
vs_sl_d
    lda #P_RED
    jsr sv_pen
    lda #<vs_s_dam
    ldy #>vs_s_dam
    ldx #26
    jsr sv_puts
    jmp vs_sl_sel
vs_sl_v
    lda #<vs_s_sec
    ldy #>vs_s_sec
    ldx #7
    jsr sv_puts
    ldx vs_t0
    lda vs_sum+1,x
    clc
    adc #1
    jsr sv_dec2
    ldx vs_row
    lda #23
    jsr sv_at
    lda #<vs_s_date
    ldy #>vs_s_date
    ldx #9
    jsr sv_puts
    ldx vs_t0
    lda vs_sum+2,x
    sta sv_t0
    lda vs_sum+3,x
    sta sv_t1
    jsr sv_dec4
    ldx vs_row              ; under it, grey: credits, achievements
    inx
    lda #12
    jsr sv_at
    lda #<vs_s_cred
    ldy #>vs_s_cred
    ldx #8
    jsr sv_puts
    ldx vs_t0
    lda vs_sum+4,x
    jsr sv_bcd
    ldx vs_t0
    lda vs_sum+5,x
    jsr sv_bcd
    ldx vs_t0
    lda vs_sum+6,x
    jsr sv_bcd
    ldx vs_row
    inx
    lda #29
    jsr sv_at
    lda #<vs_s_ach
    ldy #>vs_s_ach
    ldx #9
    jsr sv_puts
    ldx vs_t0
    lda vs_sum+7,x
    jsr sv_dec2
    ldx vs_row
    inx
    lda #0
    ldy #P_GREY
    jsr sv_ink
vs_sl_sel
    lda vs_k
    cmp sv_sel
    bne vs_sl_r
    jmp vs_bar
vs_sl_r
    rts

vs_s_head .byte ("S"-32)*2,("E"-32)*2,("L"-32)*2,("E"-32)*2,("C"-32)*2,("T"-32)*2,0,("A"-32)*2,0,("V"-32)*2,("O"-32)*2,("Y"-32)*2,("A"-32)*2,("G"-32)*2,("E"-32)*2   ; 'SELECT A VOYAGE' (15)
vs_s_voy .byte ("V"-32)*2,("O"-32)*2,("Y"-32)*2,("A"-32)*2,("G"-32)*2,("E"-32)*2,0   ; 'VOYAGE ' (7)
vs_s_new .byte ("N"-32)*2,("E"-32)*2,("W"-32)*2,0,("V"-32)*2,("O"-32)*2,("Y"-32)*2,("A"-32)*2,("G"-32)*2,("E"-32)*2   ; 'NEW VOYAGE' (10)
vs_s_dam .byte ("D"-32)*2,("A"-32)*2,("M"-32)*2,("A"-32)*2,("G"-32)*2,("E"-32)*2,("D"-32)*2,(":"-32)*2,0,("F"-32)*2,("I"-32)*2,("R"-32)*2,("E"-32)*2,0,("S"-32)*2,("T"-32)*2,("A"-32)*2,("R"-32)*2,("T"-32)*2,("S"-32)*2,0,("A"-32)*2,("G"-32)*2,("A"-32)*2,("I"-32)*2,("N"-32)*2   ; 'DAMAGED: FIRE STARTS AGAIN' (26)
vs_s_sec .byte ("S"-32)*2,("E"-32)*2,("C"-32)*2,("T"-32)*2,("O"-32)*2,("R"-32)*2,0   ; 'SECTOR ' (7)
vs_s_date .byte ("S"-32)*2,("T"-32)*2,("A"-32)*2,("R"-32)*2,("D"-32)*2,("A"-32)*2,("T"-32)*2,("E"-32)*2,0   ; 'STARDATE ' (9)
vs_s_cred .byte ("C"-32)*2,("R"-32)*2,("E"-32)*2,("D"-32)*2,("I"-32)*2,("T"-32)*2,("S"-32)*2,0   ; 'CREDITS ' (8)
vs_s_ach .byte ("A"-32)*2,("C"-32)*2,("H"-32)*2,("I"-32)*2,("E"-32)*2,("V"-32)*2,("E"-32)*2,("D"-32)*2,0   ; 'ACHIEVED ' (9)
vs_s_title .byte ("B"-32)*2,("A"-32)*2,("C"-32)*2,("K"-32)*2,0,("T"-32)*2,("O"-32)*2,0,("T"-32)*2,("H"-32)*2,("E"-32)*2,0,("T"-32)*2,("I"-32)*2,("T"-32)*2,("L"-32)*2,("E"-32)*2   ; 'BACK TO THE TITLE' (17)
vs_s_ask1 .byte ("C"-32)*2,("L"-32)*2,("E"-32)*2,("A"-32)*2,("R"-32)*2,0,("V"-32)*2,("O"-32)*2,("Y"-32)*2,("A"-32)*2,("G"-32)*2,("E"-32)*2,0   ; 'CLEAR VOYAGE ' (13)
vs_s_ask2 .byte ("?"-32)*2,0,0,("F"-32)*2,("I"-32)*2,("R"-32)*2,("E"-32)*2,(":"-32)*2,0,("Y"-32)*2,("E"-32)*2,("S"-32)*2,0,0,("B"-32)*2,("U"-32)*2,("T"-32)*2,("T"-32)*2,("O"-32)*2,("N"-32)*2,0,("2"-32)*2,(":"-32)*2,0,("N"-32)*2,("O"-32)*2   ; '?  FIRE: YES  BUTTON 2: NO' (26)
vs_s_clr .byte ("V"-32)*2,("O"-32)*2,("Y"-32)*2,("A"-32)*2,("G"-32)*2,("E"-32)*2,0,("C"-32)*2,("L"-32)*2,("E"-32)*2,("A"-32)*2,("R"-32)*2,("E"-32)*2,("D"-32)*2   ; 'VOYAGE CLEARED' (14)
vs_s_fail .byte ("T"-32)*2,("H"-32)*2,("E"-32)*2,0,("S"-32)*2,("A"-32)*2,("V"-32)*2,("E"-32)*2,("K"-32)*2,("E"-32)*2,("Y"-32)*2,0,("D"-32)*2,("I"-32)*2,("D"-32)*2,0,("N"-32)*2,("O"-32)*2,("T"-32)*2,0,("A"-32)*2,("N"-32)*2,("S"-32)*2,("W"-32)*2,("E"-32)*2,("R"-32)*2   ; 'THE SAVEKEY DID NOT ANSWER' (26)
vs_s_help .byte ("F"-32)*2,("I"-32)*2,("R"-32)*2,("E"-32)*2,(":"-32)*2,0,("P"-32)*2,("L"-32)*2,("A"-32)*2,("Y"-32)*2,0,0,0,("B"-32)*2,("U"-32)*2,("T"-32)*2,("T"-32)*2,("O"-32)*2,("N"-32)*2,0,("2"-32)*2,(":"-32)*2,0,("C"-32)*2,("L"-32)*2,("E"-32)*2,("A"-32)*2,("R"-32)*2,0,("A"-32)*2,0,("V"-32)*2,("O"-32)*2,("Y"-32)*2,("A"-32)*2,("G"-32)*2,("E"-32)*2   ; 'FIRE: PLAY   BUTTON 2: CLEAR A VOYAGE' (37)
