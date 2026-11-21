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
;   pr_rockhits rocks against the pirates
;
; Rocks are a hazard to pirates as much as to the fighter: a rock that hits
; a raider or gunship breaks up and costs it a hit (a missile, its life).
; So pirates look ahead (pr_avoid): their place and every rock's 16 frames
; on, on the math unit; a rock due closer than R_AVOID and they turn away
; from it, twice as fast as they'd turn otherwise (a parked gunship leaves
; its spot, and comes back after).
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
R_AVOID   = 40      ; pirates sidestep a rock due closer than this (square)

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
pr_dodge  = $24F2   ; this pirate is turning from a rock
av_best   = $24F3
av_x      = $24F4
av_y      = $24F5
av_px     = $24F6
av_py     = $24F7
av_i      = $24F8
av_flee   = $24F9
av_min    = $24FA
av_d0x    = $24FB
av_d0y    = $24FC
av_dvx    = $24FD
av_dvy    = $24FE

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
    jsr pr_avoid            ; a rock coming: turn from it instead
    ldx pr_slot
    lda pr_dodge
    bne pr_fr_steer
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
    ldy pr_dodge
    beq pr_fr_tr
    asl                     ; dodging: turn twice as fast
pr_fr_tr
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
; pirate X (not a missile): any rock due within R_AVOID of it, now, 8 or 16
; frames on (both moving as they are)? Then sidestep: pr_want = square
; across the nearest such rock's path, to the side the pirate is already
; on, and pr_dodge = 1.
pr_avoid
    lda #0
    sta pr_dodge
    lda pr_t,x
    cmp #PR_MISS
    bcc pr_av_go
    rts
pr_av_go
    lda pr_vxl,x            ; the pirate's move over 16 frames
    sta v_t0
    lda pr_vxh,x
    jsr av_fut
    sta av_px
    lda pr_vyl,x
    sta v_t0
    lda pr_vyh,x
    jsr av_fut
    sta av_py
    lda #255
    sta av_best
    ldy #NR-1
pr_av_l
    lda rk_t,y
    bne pr_av_t
    jmp pr_av_n
pr_av_t
    cmp #RK_BOOM
    bcc pr_av_rk
    jmp pr_av_n
pr_av_rk
    sty av_i
    ; d0: pirate - rock centre, now
    tay                     ; (Y: the rock's size, X: its slot)
    ldx av_i
    clc
    lda rk_x,x
    adc rock_cx-1,y
    sta av_x
    clc
    lda rk_y,x
    adc rock_cy-1,y
    sta av_y
    ldx pr_slot
    sec
    lda pr_x,x
    sbc av_x
    sta av_d0x
    sec
    lda pr_y,x
    sbc av_y
    sta av_d0y
    ; dv: the pirate's 16-frame move less the rock's
    ldx av_i
    lda rk_vxl,x
    sta v_t0
    lda rk_vxh,x
    jsr av_fut
    sta av_x
    ldx av_i
    lda rk_vyl,x
    sta v_t0
    lda rk_vyh,x
    jsr av_fut
    sta av_y
    sec
    lda av_px
    sbc av_x
    sta av_dvx
    sec
    lda av_py
    sbc av_y
    sta av_dvy
    ; the nearest of d0, d0 + dv/2, d0 + dv
    lda #255
    sta av_min
    lda av_d0x
    sta av_x
    lda av_d0y
    sta av_y
    jsr av_dist
    lda av_dvx
    cmp #$80
    ror
    clc
    adc av_d0x
    sta av_x
    lda av_dvy
    cmp #$80
    ror
    clc
    adc av_d0y
    sta av_y
    jsr av_dist
    clc
    lda av_d0x
    adc av_dvx
    sta av_x
    clc
    lda av_d0y
    adc av_dvy
    sta av_y
    jsr av_dist
    lda av_min
    cmp #R_AVOID
    bcs pr_av_n2
    cmp av_best
    bcs pr_av_n2
    sta av_best
    ; which way to step: square across the rock's path, on the pirate's side
    ldx av_i
    lda rk_vxl,x
    asl
    sta M_X
    lda rk_vxh,x
    rol
    sta M_X+1
    lda rk_vyl,x
    sta M_Y
    lda rk_vyh,x
    sta M_Y+1
    lda M_ANG+1
    sta av_x                ; the rock's heading
    lda av_d0x              ; and the way from the rock to the pirate
    asl
    sta M_X
    lda #0
    bcc pr_av_sx
    lda #$FF
pr_av_sx
    sta M_X+1
    lda av_d0y
    sta M_Y
    bpl pr_av_sy
    lda #$FF
    bne pr_av_sy2
pr_av_sy
    lda #0
pr_av_sy2
    sta M_Y+1
    sec
    lda M_ANG+1
    sbc av_x                ; the pirate's side of the path
    bmi pr_av_left
    clc
    lda av_x
    adc #$40
    sta av_flee
    jmp pr_av_n2
pr_av_left
    sec
    lda av_x
    sbc #$40
    sta av_flee
pr_av_n2
    ldx pr_slot
    ldy av_i
pr_av_n
    dey
    bmi pr_av_end
    jmp pr_av_l
pr_av_end
    lda av_best
    cmp #255
    beq pr_av_r
    lda av_flee
    sta pr_want
    inc pr_dodge
pr_av_r
    rts

; (av_x, av_y): a signed pirate - rock difference; its length (square
; units) into av_min if it's less. Far apart (48+ either way): skipped.
av_dist
    lda av_x
    jsr av_near
    bcs av_ds_r
    asl
    sta M_X
    lda #0
    bcc av_ds_x
    lda #$FF
av_ds_x
    sta M_X+1
    lda av_y
    jsr av_near
    bcs av_ds_r
    sta M_Y
    stx M_Y+1               ; (av_near: X = $FF negative, 0 not)
    lda M_LEN+1
    bne av_ds_r
    lda M_LEN
    cmp av_min
    bcs av_ds_r
    sta av_min
av_ds_r
    ldx pr_slot
    rts

; a velocity (A = high byte, v_t0 = low, 8.8) times 16 -> A (whole pixels)
av_fut
    asl
    asl
    asl
    asl
    sta vec_tmp
    lda v_t0
    lsr
    lsr
    lsr
    lsr
    ora vec_tmp
    rts

; A = a signed difference: C = 1 if it's 48 or more either way; else A as
; it was, X = $FF when it's negative (0 if not), and for x, C = the sign
; once doubled (the BCC after the ASL)
av_near
    ldx #0
    cmp #$80
    bcc av_nr_p
    ldx #$FF
    cmp #$100-48
    bcc av_nr_far
    clc
    rts
av_nr_p
    cmp #48
    bcs av_nr_far
    clc
    rts
av_nr_far
    sec
    rts

; rocks against the pirates: a rock that hits one breaks up (no points),
; and the pirate takes a hit (a missile is gone)
pr_rockhits
    ldx #NP-1
pr_rh_l
    stx pr_slot             ; (first: the skips below reload X from it)
    lda pr_t,x
    bne pr_rh_n_far679
    jmp pr_rh_n
pr_rh_n_far679
    cmp #PR_BOOM
    bcc pr_rh_n_far681
    jmp pr_rh_n
pr_rh_n_far681
    stx pr_slot
    sta pr_tt
    ldy #NR-1
pr_rh_r
    lda rk_t,y
    bne pr_rh_rd_far687
    jmp pr_rh_rd
pr_rh_rd_far687
    cmp #RK_BOOM
    bcc pr_rh_rd_far689
    jmp pr_rh_rd
pr_rh_rd_far689
    sty av_i
    tay
    ; |pirate x - rock centre x| < pirate's half width + rock's
    clc
    lda rock_cx-1,y
    sta av_x
    lda rock_cy-1,y
    sta av_y
    ldy av_i
    clc
    lda rk_x,y
    adc av_x
    sta av_x                ; the rock's centre
    clc
    lda rk_y,y
    adc av_y
    sta av_y
    sec
    lda pr_x,x
    sbc av_x
    bcs pr_rh_dx
    eor #$FF
    adc #1
pr_rh_dx
    ldy pr_tt
    sec
    sbc pr_hw-1,y
    bcc pr_rh_ox
    ldy av_i
    ldx rk_t,y
    cmp rock_cx-1,x
    ldx pr_slot
    bcs pr_rh_rn
pr_rh_ox
    ldy av_i
    sec
    lda pr_y,x
    sbc av_y
    bcs pr_rh_dy
    eor #$FF
    adc #1
pr_rh_dy
    ldy pr_tt
    sec
    sbc pr_hh-1,y
    bcc pr_rh_hit
    ldy av_i
    ldx rk_t,y
    cmp rock_cy-1,x
    ldx pr_slot
    bcs pr_rh_rn
pr_rh_hit
    ldx av_i                ; the rock breaks up
    jsr sp_boom
    lda #SFX_BOOM
    jsr sfx
    ldx pr_slot
    lda pr_tt
    cmp #PR_MISS
    bne pr_rh_dmg
    jsr pr_kill_quiet
    jmp pr_rh_n
pr_rh_dmg
    lda #0
    sta sp_pay
    lda #1
    jsr pr_damage
    jmp pr_rh_n
pr_rh_rn
    ldy av_i
pr_rh_rd
    dey
    bmi pr_rh_r_far762
    jmp pr_rh_r
pr_rh_r_far762
pr_rh_n
    ldx pr_slot
    dex
    bmi pr_rh_l_far766
    jmp pr_rh_l
pr_rh_l_far766
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
