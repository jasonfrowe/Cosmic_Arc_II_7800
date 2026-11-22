; ===========================================================================
; Drawing deep space: every small sprite, straight through 7800basic's
; plotsprite (what a BASIC plotsprite statement compiles to: temp1/temp2
; the graphic (plus frame * width), temp3 palette * 32 | the width's two's
; complement, temp4 x, temp5 y, temp6 the mode | %01000000). The BASIC
; draws the Ark (a tall sprite) first, then calls sp_draw.
;
; Palettes: P2 rocks, P3 bolts/aim/turret shots/pods, P4 explosions and
; pirates, P6 the fighter.
; ===========================================================================

dr_i      = $24CE
dr_f      = $24CF


sp_draw
    ; the aim marker, while the Ark's own laser is on
    lda sp_state
    cmp #ST_OVER
    beq dr_rocks
    cmp #ST_ARRIVE          ; (not while the Ark comes or goes)
    bcs dr_rocks
    jsr ft_isout
    bcs dr_rocks
    lda sp_aimx
    sta temp4
    lda sp_aimy
    sta temp5
    lda #0
    PLOT aim, 3

dr_rocks
    ldx #NR-1
dr_rk_l
    stx dr_i
    lda rk_t,x
    bne dr_rk_n_j48
    jmp dr_rk_n
dr_rk_n_j48
    tay
    lda rk_x,x
    sta temp4
    lda rk_y,x
    sta temp5
    cpy #RK_L
    bne dr_rk_m
    lda #0
    PLOT rock_l, 2
    jmp dr_rk_n
dr_rk_m
    cpy #RK_M
    bne dr_rk_s
    lda #0
    PLOT rock_m, 2
    jmp dr_rk_n
dr_rk_s
    cpy #RK_S
    bne dr_rk_b
    lda #0
    PLOT rock_s, 2
    jmp dr_rk_n
dr_rk_b
    lda rk_tm,x
    jsr dr_boomf
    PLOT boom0, 4
dr_rk_n
    ldx dr_i
    dex
    bmi dr_rk_l_j78
    jmp dr_rk_l
dr_rk_l_j78

    ; the Ark's laser bolts
    ldx #NB-1
dr_bl_l
    stx dr_i
    lda bl_t,x
    beq dr_bl_n
    lda bl_x,x
    sta temp4
    lda bl_y,x
    sta temp5
    lda bl_d,x              ; (bolts are one byte wide)
    PLOT bolt0, 3
dr_bl_n
    ldx dr_i
    dex
    bpl dr_bl_l

    ; shots: the fighter's (P6), the turret's (P3), pirates' (P4)
    ldx #NS-1
dr_sh_l
    stx dr_i
    lda sh_t,x
    beq dr_sh_n
    tay
    sec
    lda sh_x,x
    sbc #2
    sta temp4
    sec
    lda sh_y,x
    sbc #2
    sta temp5
    cpy #SH_FIGHTER
    bne dr_sh_t
    lda #0
    PLOT dot, 6
    jmp dr_sh_n
dr_sh_t
    cpy #SH_TURRET
    bne dr_sh_p
    lda #0
    PLOT dot, 3
    jmp dr_sh_n
dr_sh_p
    lda #0
    PLOT dot, 4
dr_sh_n
    ldx dr_i
    dex
    bpl dr_sh_l

    ; pirates, missiles, explosions
    ldx #NP-1
dr_pr_l
    stx dr_i
    lda pr_t,x
    bne dr_pr_t
    jmp dr_pr_n
dr_pr_t
    tay
    lda sp_frame8           ; lights blink
    lsr
    lsr
    lsr
    and #1
    sta dr_f
    cpy #PR_RAID
    bne dr_pr_g
    sec
    lda pr_x,x
    sbc #4
    sta temp4
    sec
    lda pr_y,x
    sbc #4
    sta temp5
    lda dr_f
    asl                     ; (two bytes wide)
    PLOT raider0, 4
    jmp dr_pr_n
dr_pr_g
    cpy #PR_GUN
    bne dr_pr_m
    sec
    lda pr_x,x
    sbc #6
    sta temp4
    sec
    lda pr_y,x
    sbc #6
    sta temp5
    lda #0
    PLOT gunship, 4
    jmp dr_pr_n
dr_pr_m
    cpy #PR_MISS
    bne dr_pr_b
    sec
    lda pr_x,x
    sbc #2
    sta temp4
    sec
    lda pr_y,x
    sbc #2
    sta temp5
    lda dr_f
    PLOT missile0, 4
    jmp dr_pr_n
dr_pr_b
    sec
    lda pr_x,x
    sbc #4
    sta temp4
    sec
    lda pr_y,x
    sbc #8
    sta temp5
    lda pr_tm,x
    jsr dr_boomf
    PLOT boom0, 4
dr_pr_n
    ldx dr_i
    dex
    bmi dr_pods
    jmp dr_pr_l

    ; salvage pods (blinking as they run out)
dr_pods
    ldx #NPD-1
dr_pd_l
    stx dr_i
    lda pd_t,x
    beq dr_pd_n
    cmp #45
    bcs dr_pd_on
    lda sp_frame8
    and #4
    bne dr_pd_n
dr_pd_on
    sec
    lda pd_x,x
    sbc #2
    sta temp4
    sec
    lda pd_y,x
    sbc #4
    sta temp5
    lda sp_frame8
    lsr
    lsr
    lsr
    and #1
    PLOT pod0, 3
dr_pd_n
    ldx dr_i
    dex
    bpl dr_pd_l

    ; the fighter: the saucer, its lights running round (it blinks for a
    ; moment after a hit)
    jsr ft_isout
    bcc dr_r
    lda ft_flash
    and #2
    bne dr_r
    sec
    lda ft_x
    sbc #4
    sta temp4
    sec
    lda ft_y
    sbc #3
    sta temp5
    lda sp_frame8
    lsr
    and #6                  ; frame 0-3, two bytes wide
    PLOT saucer0, 6
dr_r
    rts

