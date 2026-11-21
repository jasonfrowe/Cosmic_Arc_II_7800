; ===========================================================================
; Pirates (M2): they come in off the lanes, where the Ark's laser can't
; reach them for long, so they're the fighter's job.
;
;   Raider    fast; circles the Ark (crossing the lanes now and then) and
;             shoots at it. 2 hits.
;   Gunship   slow; parks between two lanes and launches missiles. 5 hits.
;   Missile   homes on the Ark. The auto-turret and the fighter can shoot
;             it down. 1 hit.
;
; A raider or gunship destroyed leaves a salvage pod drifting: only the
; fighter can pick it up, for Ark energy (the way to make up misses and
; hits). Explosions (pirates', the fighter's) live in the pirate slots.
;
;   pr_frame  pd_frame   one step each
;   pr_spawn  A = type, from an edge
;   pr_shothit  shot X against the pirates (from sh_hits)
;   pr_bolthits the Ark's laser bolts against the pirates
; ===========================================================================

PR_RAID   = 1
PR_GUN    = 2
PR_MISS   = 3
PR_BOOM   = 4

NP        = 6       ; pirate slots (pirates, missiles, explosions)
NPD       = 2       ; pod slots

; ---- knobs ----
R_RAID    = 62      ; orbit radius (square units)
R_GUN     = 70      ; parking radius
PSHOT_DMG = 6       ; a pirate shot hitting the Ark
PSHOT_FDMG = 16     ; ... hitting the fighter (off its tether)
MISS_DMG  = 10      ; a missile reaching the Ark
MISS_FDMG = 16
RAM_FDMG  = 24      ; the fighter flying into a pirate
POD_PAY   = 16      ; Ark energy in a salvage pod
POD_LIFE  = 200     ; pairs of frames a pod lasts
MISS_LIFE = 200     ; pairs of frames a missile lasts
MISS_MAX  = 2       ; missiles in the air from all gunships
RAID_GAP  = 70      ; frames between a raider's shots, + up to 63
GUN_GAP   = 150     ; frames between a gunship's missiles

; ---- RAM ----
pr_t      = $2460   ; [NP]
pr_x      = $2466   ; centre, 8.8
pr_xl     = $246C
pr_y      = $2472
pr_yl     = $2478
pr_vxl    = $247E
pr_vxh    = $2484
pr_vyl    = $248A
pr_vyh    = $2490
pr_a      = $2496   ; heading
pr_hp     = $249C
pr_tm     = $24A2   ; shot timer / explosion timer
pr_o      = $24A8   ; orbit angle / parking angle / a missile's life
pd_t      = $24AE   ; [NPD] life, 0 = free
pd_x      = $24B0
pd_xl     = $24B2
pd_y      = $24B4
pd_yl     = $24B6
pd_vxl    = $24B8
pd_vxh    = $24BA
pd_vyl    = $24BC
pd_vyh    = $24BE
sp_praid  = $24C1   ; raiders still to come this wave
sp_pgun   = $24C2   ; gunships still to come
sp_ptm    = $24C3   ; frames to the next pirate
pr_live   = $24E9   ; pirates and missiles about
pr_slot   = $24EA
pr_want   = $24EB
pr_tt     = $24EC
pr_miss   = $24ED

; per type (raider, gunship, missile)
pr_spl    .byte $40, $A0, $C0       ; speed, 8.8 square units a frame
pr_sph    .byte $01, $00, $00
pr_turn   .byte 4, 2, 3             ; most it turns a frame
pr_hpmax  .byte 2, 5, 1
pr_hw     .byte 5, 7, 3             ; hit box half sizes (+1 for a shot)
pr_hh     .byte 5, 7, 3
pr_scm    .byte $03, $07, $00       ; points, BCD: 300, 750, 50
pr_scl    .byte $00, $50, $50

; ---------------------------------------------------------------------------
pr_new
    lda #0
    ldx #NP-1
pr_new_l
    sta pr_t,x
    dex
    bpl pr_new_l
    sta pd_t
    sta pd_t+1
    sta pr_live
    rts

; a free slot in X (C = 0), or C = 1
pr_alloc
    ldx #NP-1
pr_al_l
    lda pr_t,x
    beq pr_al_y
    dex
    bpl pr_al_l
    sec
    rts
pr_al_y
    clc
    rts

; an explosion at (tg_x, tg_y)
pr_boomat
    jsr pr_alloc
    bcs pr_ba_r
    lda #PR_BOOM
    sta pr_t,x
    lda tg_x
    sta pr_x,x
    lda tg_y
    sta pr_y,x
    lda #17
    sta pr_tm,x
pr_ba_r
    rts

; a pirate of type A from a random edge
pr_spawn
    sta pr_tt
    jsr pr_alloc
    bcs pr_ba_r
    lda #0
    sta M_A+1
    sta M_B+1
    sta M_CTRL
    lda #150
    sta M_B
    lda M_RND
    sta M_A
    lda M_RND
    and #3
    tay
    lda M_P+1               ; 0-149 along the edge
    cpy #2
    bcs pr_sp_side
    adc #5
    sta tg_x
    lda #PF_TOP+4
    cpy #0
    beq pr_sp_y
    lda #PF_BOT-6
pr_sp_y
    sta tg_y
    jmp pr_sp_go
pr_sp_side
    clc
    adc #PF_TOP+5
    sta tg_y
    lda #4
    cpy #2
    beq pr_sp_x
    lda #155
pr_sp_x
    sta tg_x
pr_sp_go
    lda pr_tt
; a pirate of type A at (tg_x, tg_y), slot X
pr_place
    sta pr_t,x
    tay
    lda tg_x
    sta pr_x,x
    lda tg_y
    sta pr_y,x
    lda #0
    sta pr_xl,x
    sta pr_yl,x
    sta pr_vxl,x
    sta pr_vxh,x
    sta pr_vyl,x
    sta pr_vyh,x
    lda pr_hpmax-1,y
    sta pr_hp,x
    lda #90
    sta pr_tm,x
    lda M_RND
    cpy #PR_GUN
    bne pr_pl_o
    and #$E0                ; between two lanes
    ora #$10
pr_pl_o
    cpy #PR_MISS
    bne pr_pl_o2
    lda #MISS_LIFE
pr_pl_o2
    sta pr_o,x
    ; heading: at the Ark
    stx pr_slot
    lda tg_x
    sta v_t0
    lda tg_y
    sta v_t1
    lda #ARK_CX
    sta v_t2
    lda #ARK_CY
    sta v_t3
    jsr vec_angle
    ldx pr_slot
    sta pr_a,x
    rts

; ---------------------------------------------------------------------------
pr_frame
    lda #0
    sta pr_live
    sta pr_miss
    ldx #NP-1
pr_cnt
    lda pr_t,x
    cmp #PR_MISS
    bne pr_cnt_n
    inc pr_miss
pr_cnt_n
    dex
    bpl pr_cnt
    ldx #NP-1
pr_fr_l
    stx pr_slot
    lda pr_t,x
    bne pr_fr_t
    jmp pr_fr_n
pr_fr_t
    cmp #PR_BOOM
    bcc pr_fr_alive
    dec pr_tm,x
    bne pr_fr_bn
    lda #0
    sta pr_t,x
pr_fr_bn
    jmp pr_fr_n
pr_fr_alive
    inc pr_live
    ; where to: the Ark (missile), or a point round it
    cmp #PR_MISS
    beq pr_fr_ark
    cmp #PR_RAID
    bne pr_fr_park
    lda sp_frame8
    and #1
    beq pr_fr_orb
    inc pr_o,x              ; a raider's point goes round
pr_fr_orb
    lda #R_RAID
    bne pr_fr_pt
pr_fr_park
    lda #R_GUN
pr_fr_pt
    sta v_t1
    lda #0
    sta v_t0
    lda pr_o,x
    jsr vec_rot
    clc
    lda #ARK_CX
    adc vx_h
    sta v_t2
    clc
    lda #ARK_CY
    adc vy_h
    sta v_t3
    jmp pr_fr_aim
pr_fr_ark
    lda #ARK_CX
    sta v_t2
    lda #ARK_CY
    sta v_t3
pr_fr_aim
    ldx pr_slot
    lda pr_x,x
    sta v_t0
    lda pr_y,x
    sta v_t1
    jsr vec_angle
    sta pr_want
    ldx pr_slot
    lda pr_t,x
    cmp #PR_GUN
    bne pr_fr_steer
    lda M_LEN+1             ; a gunship at its spot parks
    bne pr_fr_steer
    lda M_LEN
    cmp #6
    bcs pr_fr_steer
    lda #0
    sta pr_vxl,x
    sta pr_vxh,x
    sta pr_vyl,x
    sta pr_vyh,x
    jsr pr_gunfire
    jmp pr_fr_col
pr_fr_steer
    lda pr_want
    sta v_t2
    ldy pr_t,x
    lda pr_turn-1,y
    sta v_t3
    lda pr_a,x
    jsr steer
    ldx pr_slot
    sta pr_a,x
    ldy pr_t,x
    lda pr_spl-1,y
    sta v_t0
    lda pr_sph-1,y
    sta v_t1
    lda pr_a,x
    jsr vec_rot
    ldx pr_slot
    lda vx_l
    sta pr_vxl,x
    lda vx_h
    sta pr_vxh,x
    lda vy_l
    sta pr_vyl,x
    lda vy_h
    sta pr_vyh,x
    clc
    lda pr_xl,x
    adc pr_vxl,x
    sta pr_xl,x
    lda pr_x,x
    adc pr_vxh,x
    sta pr_x,x
    clc
    lda pr_yl,x
    adc pr_vyl,x
    sta pr_yl,x
    lda pr_y,x
    adc pr_vyh,x
    sta pr_y,x
    ; a raider shoots
    lda pr_t,x
    cmp #PR_RAID
    bne pr_fr_col
    dec pr_tm,x
    bne pr_fr_col
    lda M_RND
    and #63
    clc
    adc #RAID_GAP
    sta pr_tm,x
    jsr pr_shoot
pr_fr_col
    ldx pr_slot
    jsr pr_collide
pr_fr_n
    ldx pr_slot
    dex
    bmi pr_fr_r
    jmp pr_fr_l
pr_fr_r
    rts

; raider X shoots at the Ark (if it's on the screen)
pr_shoot
    lda pr_x,x
    cmp #4
    bcc pr_sh_r
    cmp #156
    bcs pr_sh_r
    sta v_t0
    sta sh_nx
    lda pr_y,x
    sta v_t1
    sta sh_ny
    lda #ARK_CX
    sta v_t2
    lda #ARK_CY
    sta v_t3
    jsr vec_angle
    pha
    lda #<SH_PIRATE
    sta v_t0
    lda #>SH_PIRATE
    sta v_t1
    pla
    jsr vec_rot
    lda #SH_PIRATE_T
    sta sh_nt
    lda #SH_PLIFE
    sta sh_life0
    jsr sh_spawn
    lda #SFX_PSHOT
    jsr sfx
    ldx pr_slot
pr_sh_r
    rts

; gunship X, parked: a missile now and then
pr_gunfire
    dec pr_tm,x
    bne pr_gf_r
    lda #GUN_GAP
    sta pr_tm,x
    lda pr_miss
    cmp #MISS_MAX
    bcs pr_gf_r
    inc pr_miss
    lda pr_x,x
    sta tg_x
    lda pr_y,x
    sta tg_y
    jsr pr_alloc
    bcs pr_gf_x
    lda #PR_MISS
    jsr pr_place
    lda #SFX_MISSILE
    jsr sfx
pr_gf_x
    ldx pr_slot
pr_gf_r
    rts

; pirate X against the Ark (missiles) and the fighter
pr_collide
    lda pr_t,x
    cmp #PR_MISS
    bne pr_co_f
    ; a missile runs out
    lda sp_frame8
    and #1
    bne pr_co_life
    dec pr_o,x
    bne pr_co_life
    jmp pr_kill_quiet
pr_co_life
    lda pr_x,x
    cmp #ARK_HX0
    bcc pr_co_f
    cmp #ARK_HX1
    bcs pr_co_f
    lda pr_y,x
    cmp #ARK_HY0
    bcc pr_co_f
    cmp #ARK_HY1
    bcs pr_co_f
    jsr pr_kill_quiet
    lda #MISS_DMG
    jmp sp_arkdmg
pr_co_f
    jsr ft_isout
    bcc pr_co_r
    ldy pr_t,x
    ; |dx| < half width + 4, |dy| < half height + 5
    sec
    lda pr_x,x
    sbc ft_x
    bcs pr_co_dx
    eor #$FF
    adc #1
pr_co_dx
    sec
    sbc #4
    bcc pr_co_dxo
    cmp pr_hw-1,y
    bcs pr_co_r
pr_co_dxo
    sec
    lda pr_y,x
    sbc ft_y
    bcs pr_co_dy
    eor #$FF
    adc #1
pr_co_dy
    sec
    sbc #5
    bcc pr_co_hit
    cmp pr_hh-1,y
    bcs pr_co_r
pr_co_hit
    lda ft_flash            ; (just hit: a moment's grace)
    bne pr_co_r
    cpy #PR_MISS
    bne pr_co_ram
    jsr pr_kill_quiet
    lda #MISS_FDMG
    jmp ft_hurt
pr_co_ram
    lda #RAM_FDMG
    jsr ft_hurt
    ldx pr_slot
    lda #0
    sta sp_pay
    lda #1
    jmp pr_damage
pr_co_r
    rts

; ---------------------------------------------------------------------------
; pirate X takes A hits; destroyed: points, sp_pay energy, a pod, a bang
pr_damage
    sta vec_tmp
    lda pr_hp,x
    sec
    sbc vec_tmp
    beq pr_dm_kill
    bcc pr_dm_kill
    sta pr_hp,x
    lda #SFX_ZAP
    jmp sfx
pr_dm_kill
    ldy pr_t,x
    lda pr_scm-1,y
    sta sc_m
    lda pr_scl-1,y
    sta sc_l
    jsr sc_add
    clc
    lda sp_energy
    adc sp_pay
    cmp #EN_MAX
    bcc pr_dm_e
    lda #EN_MAX
pr_dm_e
    sta sp_energy
    lda pr_t,x
    cmp #PR_MISS
    beq pr_dm_boom
    jsr pd_drop
pr_dm_boom
    lda #SFX_BOOM
    jsr sfx
    ldx pr_slot
; pirate X becomes an explosion
pr_kill_quiet
    lda #PR_BOOM
    sta pr_t,x
    lda #17
    sta pr_tm,x
    rts

; shot X against the pirates (sh_hits; sp_pay set)
pr_shothit
    ldy #NP-1
pr_sh_l
    lda pr_t,y
    beq pr_sh_n
    cmp #PR_BOOM
    bcs pr_sh_n
    sta pr_tt
    sec
    lda sh_x,x
    sbc pr_x,y
    bcs pr_sh_dx
    eor #$FF
    adc #1
pr_sh_dx
    sty pr_slot
    ldy pr_tt
    cmp pr_hw-1,y
    ldy pr_slot
    bcs pr_sh_n
    sec
    lda sh_y,x
    sbc pr_y,y
    bcs pr_sh_dy
    eor #$FF
    adc #1
pr_sh_dy
    ldy pr_tt
    cmp pr_hh-1,y
    ldy pr_slot
    bcs pr_sh_n
    lda #0
    sta sh_t,x
    tya
    tax
    lda #1
    jmp pr_damage
pr_sh_n
    dey
    bpl pr_sh_l
    rts

; the Ark's laser bolts against the pirates
pr_bolthits
    lda #KILL_PAY
    sta sp_pay
    ldx #NB-1
pr_bh_b
    lda bl_t,x
    beq pr_bh_bn
    ldy #NP-1
pr_bh_p
    lda pr_t,y
    beq pr_bh_pn
    cmp #PR_BOOM
    bcs pr_bh_pn
    sta pr_tt
    clc
    lda bl_x,x
    adc #2
    sec
    sbc pr_x,y
    bcs pr_bh_dx
    eor #$FF
    adc #1
pr_bh_dx
    sty pr_slot
    ldy pr_tt
    cmp pr_hw-1,y
    ldy pr_slot
    bcs pr_bh_pn
    clc
    lda bl_y,x
    adc #2
    sec
    sbc pr_y,y
    bcs pr_bh_dy
    eor #$FF
    adc #1
pr_bh_dy
    ldy pr_tt
    cmp pr_hh-1,y
    ldy pr_slot
    bcs pr_bh_pn
    lda #0
    sta bl_t,x
    stx sh_slot
    tya
    tax
    lda #1
    jsr pr_damage
    ldx sh_slot
    jmp pr_bh_bn
pr_bh_pn
    dey
    bpl pr_bh_p
pr_bh_bn
    dex
    bpl pr_bh_b
    rts

; ---------------------------------------------------------------------------
; Pods. pd_drop: one where pirate X was, drifting at a quarter its speed.
pd_drop
    ldy #NPD-1
pd_dr_f
    lda pd_t,y
    beq pd_dr_go
    dey
    bpl pd_dr_f
    rts
pd_dr_go
    lda #POD_LIFE
    sta pd_t,y
    lda pr_x,x
    sta pd_x,y
    lda pr_y,x
    sta pd_y,y
    lda #0
    sta pd_xl,y
    sta pd_yl,y
    lda pr_vxh,x
    cmp #$80
    ror
    sta pd_vxh,y
    lda pr_vxl,x
    ror
    sta pd_vxl,y
    lda pd_vxh,y
    cmp #$80
    ror
    sta pd_vxh,y
    lda pd_vxl,y
    ror
    sta pd_vxl,y
    lda pr_vyh,x
    cmp #$80
    ror
    sta pd_vyh,y
    lda pr_vyl,x
    ror
    sta pd_vyl,y
    lda pd_vyh,y
    cmp #$80
    ror
    sta pd_vyh,y
    lda pd_vyl,y
    ror
    sta pd_vyl,y
    rts

pd_frame
    ldx #NPD-1
pd_fr_l
    lda pd_t,x
    bne pd_fr_n_j699
    jmp pd_fr_n
pd_fr_n_j699
    lda sp_frame8
    and #1
    bne pd_fr_mv
    dec pd_t,x
    bne pd_fr_n_j704
    jmp pd_fr_n
pd_fr_n_j704
pd_fr_mv
    clc
    lda pd_xl,x
    adc pd_vxl,x
    sta pd_xl,x
    lda pd_x,x
    adc pd_vxh,x
    sta pd_x,x
    cmp #158
    bcs pd_fr_k
    clc
    lda pd_yl,x
    adc pd_vyl,x
    sta pd_yl,x
    lda pd_y,x
    adc pd_vyh,x
    sta pd_y,x
    cmp #PF_TOP+4
    bcc pd_fr_k
    cmp #PF_BOT-4
    bcs pd_fr_k
    ; the fighter picks it up
    jsr ft_isout
    bcc pd_fr_n
    sec
    lda pd_x,x
    sbc ft_x
    bcs pd_fr_dx
    eor #$FF
    adc #1
pd_fr_dx
    cmp #6
    bcs pd_fr_n
    sec
    lda pd_y,x
    sbc ft_y
    bcs pd_fr_dy
    eor #$FF
    adc #1
pd_fr_dy
    cmp #9
    bcs pd_fr_n
    clc
    lda sp_energy
    adc #POD_PAY
    cmp #EN_MAX
    bcc pd_fr_e
    lda #EN_MAX
pd_fr_e
    sta sp_energy
    lda #$02                ; 250 points
    sta sc_m
    lda #$50
    sta sc_l
    jsr sc_add
    stx pr_slot
    lda #SFX_POD
    jsr sfx
    ldx pr_slot
pd_fr_k
    lda #0
    sta pd_t,x
pd_fr_n
    dex
    bmi pd_fr_l_j769
    jmp pd_fr_l
pd_fr_l_j769
    rts
