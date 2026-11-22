; ===========================================================================
; Shared by deep space (bank 2) and the planet (bank 3), so in bank 1: the
; HUD's bars, the score, centred messages, the PLOT macro.
; ===========================================================================

; PLOT graphic, palette: A = frame * width (bytes); temp4 = x, temp5 = y.
; Straight through 7800basic's plotsprite (see draw.asm).
    MAC PLOT            ; PLOT graphic, palette: A = frame * width (bytes)
    clc
    adc #<{1}
    sta temp1
    lda #>{1}
    adc #0
    sta temp2
    lda #({2}<<5)|{1}_width_twoscompliment
    sta temp3
    lda #({1}_mode|%01000000)
    sta temp6
    jsr plotsprite
    ENDM

; (hwp): character A, then X as 8 cells of 12, then a space
hud_bar
    ldy #0
    sta (hwp),y
    stx sp_t0
    iny
hud_b_full
    lda sp_t0
    cmp #12
    bcc hud_b_part
    sbc #12
    sta sp_t0
    lda #CH_BAR4
    sta (hwp),y
    iny
    cpy #9
    bne hud_b_full
    beq hud_b_end
hud_b_part
    ldx #0                  ; the part cell: quarters of 12 (3 each)
hud_b_q
    cmp #3
    bcc hud_b_qd
    sbc #3
    inx
    bne hud_b_q
hud_b_qd
    lda bar_part,x
    sta (hwp),y
    iny
hud_b_sp
    cpy #10
    beq hud_b_r
    lda #CH_SPACE
    sta (hwp),y
    iny
    bne hud_b_sp
hud_b_end
    lda #CH_SPACE
    sta (hwp),y
hud_b_r
    rts

bar_part .byte 0, CH_BAR1, CH_BAR2, CH_BAR3

; add sc_m/sc_l (BCD: hundreds-thousands, tens-ones) to the score
sc_m      = $24EE
sc_l      = $24EF
sc_add
    sed
    clc
    lda sp_score+2
    adc sc_l
    sta sp_score+2
    lda sp_score+1
    adc sc_m
    sta sp_score+1
    lda sp_score
    adc #0
    sta sp_score
    cld
    rts

; copy X characters from (A, Y) and centre them
sp_msgcopy
    sta hwp
    sty hwp+1
    stx sp_t0
    ldy #0
sp_mc_l
    lda (hwp),y
    sta sp_msg,y
    iny
    cpy sp_t0
    bne sp_mc_l
    lda sp_t0
    asl
    asl
    sta sp_t1               ; width/2 in pixels = len * 4
    sec
    lda #80
    sbc sp_t1
    tax
    lda sp_t0
sp_msgset
    sta sp_msglen
    stx sp_msgx
    rts
