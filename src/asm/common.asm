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

; an explosion's timer (17 down) -> A = its frame's offset (one byte wide
; frames would be the frame; boom frames are two bytes wide)
dr_boomf
    cmp #12
    bcs dr_bf0
    cmp #6
    bcs dr_bf1
    lda #4
    rts
dr_bf1
    lda #2
    rts
dr_bf0
    lda #0
    rts

; ---------------------------------------------------------------------------
; The Ark's capacities by upgrade level (port.asm's shipyard; the planet asks
; pt_holdfree before taking ore aboard): the holds
up_holds  .byte 10, 15, 20, 20

; C = 1: room in the holds (goods + creatures in stasis < the holds)
pt_holdfree
    jsr pt_holdused
    ldx gs_uhold
    cmp up_holds,x          ; (C = 1: as many as the holds or more)
    lda #0
    rol                     ; A = C
    eor #1
    lsr                     ; C = room
    rts
; A = the holds in use: goods and creatures in stasis
pt_holdused
    clc
    lda gs_ore
    adc gs_org
    adc gs_eqp
    ldx #5
pt_hu_l
    adc gs_stasis,x
    dex
    bpl pt_hu_l
    rts

; ---- the Ark's hull: its most energy (sp_enmax: EN_BASE + EN_STEP an
; upgrade, gs_ulas, to EN_TOP), and the energy bar scaled to it ----
EN_BASE   = 100
EN_STEP   = 5
EN_TOP    = 200
EN_UPS    = 20      ; hull upgrades, at most
sp_enmax  = $258F
sp_enk    = $23FF   ; 96 x 256 / sp_enmax (the bar's scale)
sp_enbar  = $2574   ; the energy on the bar's scale, 0-96 (the BASIC's
                    ;   colours; the escape scene's otherwise)
en_setmax
    lda gs_ulas
    asl
    asl
    adc gs_ulas
    clc
    adc #EN_BASE
    cmp #EN_TOP+1
    bcc en_sm_m
    lda #EN_TOP
en_sm_m
    sta sp_enmax
    ldx #0                  ; k = 24576 / max: subtract till it's gone
    ldy #$60
    lda #0
en_sm_l
    cpy #0
    bne en_sm_s
    cmp sp_enmax
    bcc en_sm_d
en_sm_s
    sec
    sbc sp_enmax
    bcs en_sm_n
    dey
en_sm_n
    inx
    bne en_sm_l
en_sm_d
    stx sp_enk
    rts
; X = sp_enbar = the energy on the bar's scale (0-96)
en_bar
    ldx #96
    lda sp_energy
    cmp sp_enmax
    bcs en_b_r
    sta M_A
    lda sp_enk
    sta M_B
    lda #0
    sta M_A+1
    sta M_B+1
    sta M_CTRL
    ldx M_P+1
en_b_r
    stx sp_enbar
    rts

; the HUD's top line, 0-5: the credits ($ and the digits, no leading zeros)
hud_cred
    ldy #0
    ldx #0
hc_l
    lda gs_cred,x
    lsr
    lsr
    lsr
    lsr
    jsr tx_digit
    sta hud_top,y
    iny
    lda gs_cred,x
    and #$0F
    jsr tx_digit
    sta hud_top,y
    iny
    inx
    cpx #3
    bne hc_l
    ldy #0
hc_z
    lda hud_top,y
    cmp #(16 << 1)          ; ("0")
    bne hc_d
    lda #0
    sta hud_top,y
    iny
    cpy #5
    bne hc_z
hc_d
    dey
    bmi hc_r
    lda #("$"-32)*2
    sta hud_top,y
hc_r
    rts
