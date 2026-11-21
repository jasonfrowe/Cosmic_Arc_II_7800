; ===========================================================================
; The fighter (M2), the shots that fly at any angle, and the Ark's
; auto-turret.
;
; Button 2 launches the fighter from the bay under the Ark. Out, the
; joystick flies it (left/right turn, up thrusts, down brakes; it keeps
; its speed and wraps at the screen's edges), button 1 fires twin blasters,
; button 2 calls it home (it flies itself), or fly it into the bay to dock.
; The tether drains while it's out and charges while it's docked: run dry
; and it comes home on its own. Damage comes off the tether too: run dry
; that way and it's destroyed, and the Ark builds another.
; While it's out the Ark's laser is the auto-turret's: slow, but it aims at
; any angle, at the nearest threat.
;
;   ft_frame  sh_frame  tu_frame   one step each
;   ft_hurt   A = damage to the fighter
;   sh_spawn  a shot: sh_nt type, sh_nx/sh_ny centre, vx/vy velocity
; ===========================================================================

; ---- knobs ----
FT_TETH   = 96      ; a full tether
FT_LAUNCH = 24      ; tether needed to launch
FT_DRAIN  = 8       ; frames a tether point lasts, out
FT_CHARGE = 2       ; frames a tether point takes to charge, docked
FT_ROT    = $0380   ; turn a frame (16-bit angle)
FT_THRUST = $0010   ; thrust a frame (8.8 square units)
FT_SHOT   = $0300   ; blaster speed (plus the fighter's own)
FT_GAP    = 10      ; frames between blaster pairs
FT_SHLIFE = 36
FT_HOME   = $0180   ; speed flying home
FT_REBUILD = 240    ; frames to build a new fighter
TU_GAP    = 40      ; frames between auto-turret shots
TU_SPEED  = $0280
SH_PIRATE = $0200   ; pirate shot speed
SH_PLIFE  = 90

FT_DOCK   = 0
FT_OUT    = 1
FT_HOMING = 2
FT_DEAD   = 3

SH_FIGHTER = 1
SH_TURRET  = 2
SH_PIRATE_T = 3

BAY_X     = 80      ; the bay: launch below it, dock inside this box
BAY_Y     = 104
DOCK_X0   = 72
DOCK_X1   = 89
DOCK_Y0   = 96
DOCK_Y1   = 110

NS        = 8       ; shot slots

; ---- RAM ($2400-$24FF) ----
ft_st     = $2400
ft_x      = $2401   ; centre, 8.8 (x: 160A pixels, y: lines)
ft_xl     = $2402
ft_y      = $2403
ft_yl     = $2404
ft_vxl    = $2405   ; (vx, vy: contiguous, in this order)
ft_vxh    = $2406
ft_vyl    = $2407
ft_vyh    = $2408
ft_al     = $2409   ; heading, 16-bit
ft_ah     = $240A
ft_cool   = $240B
ft_teth   = $240C
ft_tm     = $240D
ft_drain  = $240E
ft_age    = $240F
sh_t      = $2410   ; [NS] 0 free, SH_ type
sh_x      = $2418
sh_xl     = $2420
sh_y      = $2428
sh_yl     = $2430
sh_vxl    = $2438
sh_vxh    = $2440
sh_vyl    = $2448
sh_vyh    = $2450
sh_life   = $2458
tu_cool   = $24C0
sp_fire2  = $24C5   ; in: button 2 held
sp_f2old  = $24C4
ft_b2     = $24DB   ; button 2 went down this frame
ft_flash  = $24DC
sh_nt     = $24DD
sh_nx     = $24DE
sh_ny     = $24DF
tg_dist   = $24E0
tg_x      = $24E1
tg_y      = $24E2
sp_frame8 = $24E3
sp_pay    = $24E4   ; energy a kill pays (by who made it)
ft_px     = $24E5   ; blaster side offset
ft_py     = $24E6
sh_slot   = $24E8   ; the shot loop's slot

; ---------------------------------------------------------------------------
ft_new
    lda #FT_DOCK
    sta ft_st
    lda #FT_TETH
    sta ft_teth
    lda #FT_DRAIN
    sta ft_drain
    lda #0
    sta ft_flash
    sta tu_cool
    sta sp_f2old
    ldx #NS-1
ft_new_s
    sta sh_t,x
    dex
    bpl ft_new_s
    rts

ft_frame
    lda ft_flash
    beq ft_fr_f
    dec ft_flash
ft_fr_f
    lda #0
    sta ft_b2
    lda sp_fire2
    beq ft_fr_nb
    lda sp_f2old
    bne ft_fr_nb
    inc ft_b2
ft_fr_nb
    lda sp_fire2
    sta sp_f2old
    lda ft_st
    beq ft_docked
    cmp #FT_OUT
    bne ft_fr_h
    jmp ft_out
ft_fr_h
    cmp #FT_HOMING
    bne ft_fr_d
    jmp ft_homing
ft_fr_d
    dec ft_tm               ; destroyed: the Ark builds another
    bne ft_fr_r
    lda #FT_DOCK
    sta ft_st
ft_fr_r
    rts

; ---- docked: charge; button 2 launches ----
ft_docked
    lda sp_frame8
    and #FT_CHARGE-1
    bne ft_dk_l
    lda ft_teth
    cmp #FT_TETH
    bcs ft_dk_l
    inc ft_teth
ft_dk_l
    lda ft_b2
    beq ft_fr_r
    lda sp_state
    cmp #ST_PLAY
    beq ft_dk_go
    cmp #ST_START
    beq ft_dk_go
    cmp #ST_CLEAR
    bne ft_fr_r
ft_dk_go
    lda ft_teth
    cmp #FT_LAUNCH
    bcc ft_fr_r
    lda #FT_OUT
    sta ft_st
    lda #BAY_X
    sta ft_x
    lda #BAY_Y+8
    sta ft_y
    lda #0
    sta ft_xl
    sta ft_yl
    sta ft_al
    sta ft_vxl
    sta ft_vxh
    sta ft_vyl
    sta ft_age
    sta ft_cool
    lda #$40                ; facing down, out of the bay
    sta ft_ah
    lda #1
    sta ft_vyh
    lda #SFX_LAUNCH
    jmp sfx

; ---- out: the player flies ----
ft_out
    lda ft_age
    cmp #255
    beq ft_o_age
    inc ft_age
ft_o_age
    dec ft_drain
    bne ft_o_b2
    lda #FT_DRAIN
    sta ft_drain
    lda ft_teth
    beq ft_o_home
    dec ft_teth
    bne ft_o_b2
ft_o_home
    lda #FT_HOMING
    sta ft_st
    jmp ft_homing
ft_o_b2
    lda ft_b2
    bne ft_o_home
    ; turn
    ldx sp_joy
    cpx #8
    bcs ft_o_move
    lda ft_turn,x
    beq ft_o_push
    bmi ft_o_left
    clc
    lda ft_al
    adc #<FT_ROT
    sta ft_al
    lda ft_ah
    adc #>FT_ROT
    sta ft_ah
    jmp ft_o_push
ft_o_left
    sec
    lda ft_al
    sbc #<FT_ROT
    sta ft_al
    lda ft_ah
    sbc #>FT_ROT
    sta ft_ah
ft_o_push
    ldx sp_joy
    lda ft_push,x
    beq ft_o_move
    cmp #1
    bne ft_o_brake
    lda #<FT_THRUST
    sta v_t0
    lda #>FT_THRUST
    sta v_t1
    lda ft_ah
    jsr vec_rot
    clc
    lda ft_vxl
    adc vx_l
    sta ft_vxl
    lda ft_vxh
    adc vx_h
    sta ft_vxh
    clc
    lda ft_vyl
    adc vy_l
    sta ft_vyl
    lda ft_vyh
    adc vy_h
    sta ft_vyh
    jmp ft_o_move
ft_o_brake
    ldy #3                  ; v -= v/8
    jsr ft_damp
ft_o_move
    ldy #6                  ; a little drag: v -= v/64
    jsr ft_damp
    jsr ft_clamp
    jsr ft_move
    jsr ft_fire
    ; flown into the bay (not straight after launching): docked
    lda ft_age
    cmp #45
    bcc ft_o_r
    jsr ft_inbay
    bcc ft_o_r
    jmp ft_dock
ft_o_r
    rts

; per joystick direction (0 up, clockwise): turn (-1 left, +1 right) and
; push (1 thrust, 2 brake)
ft_turn  .byte 0, 1, 1, 1, 0, -1, -1, -1
ft_push  .byte 1, 1, 0, 2, 2, 2, 0, 1

; C = 1: the fighter's centre is in the bay's box
ft_inbay
    lda ft_x
    cmp #DOCK_X0
    bcc ft_ib_no
    cmp #DOCK_X1
    bcs ft_ib_no
    lda ft_y
    cmp #DOCK_Y0
    bcc ft_ib_no
    cmp #DOCK_Y1
    bcs ft_ib_no
    sec
    rts
ft_ib_no
    clc
    rts

ft_dock
    lda #FT_DOCK
    sta ft_st
    lda #SFX_DOCK
    jmp sfx

; ---- homing: fly to the bay, no inertia ----
ft_homing
    lda ft_x
    sta v_t0
    lda ft_y
    sta v_t1
    lda #BAY_X
    sta v_t2
    lda #BAY_Y
    sta v_t3
    jsr vec_angle
    sta v_t2
    lda #8
    sta v_t3
    lda ft_ah
    jsr steer
    sta ft_ah
    lda #0
    sta ft_al
    lda #<FT_HOME
    sta v_t0
    lda #>FT_HOME
    sta v_t1
    lda ft_ah
    jsr vec_rot
    lda vx_l
    sta ft_vxl
    lda vx_h
    sta ft_vxh
    lda vy_l
    sta ft_vyl
    lda vy_h
    sta ft_vyh
    jsr ft_move
    jsr ft_inbay
    bcc ft_h_r
    jmp ft_dock
ft_h_r
    rts

; v -= v >> Y (arithmetic), both axes
ft_damp
    sty vec_tmp
    ldx #0
ft_dp_c
    lda ft_vxl,x
    sta v_t0
    lda ft_vxh,x
    sta v_t1
    ldy vec_tmp
ft_dp_s
    lda v_t1
    cmp #$80
    ror v_t1
    ror v_t0
    dey
    bne ft_dp_s
    sec
    lda ft_vxl,x
    sbc v_t0
    sta ft_vxl,x
    lda ft_vxh,x
    sbc v_t1
    sta ft_vxh,x
    inx
    inx
    cpx #4
    bne ft_dp_c
    rts

; |vx| <= $00C0 pixels, |vy| <= $0180 lines (the same speed, square)
ft_clamp
    ldx #0
ft_cl_c
    lda ft_vxh,x
    bmi ft_cl_neg
    sec
    lda ft_vxl,x
    sbc ft_vmax,x
    lda ft_vxh,x
    sbc ft_vmax+1,x
    bcc ft_cl_n             ; v < max
    lda ft_vmax,x
    sta ft_vxl,x
    lda ft_vmax+1,x
    sta ft_vxh,x
    jmp ft_cl_n
ft_cl_neg
    clc
    lda ft_vxl,x
    adc ft_vmax,x
    lda ft_vxh,x
    adc ft_vmax+1,x
    bcs ft_cl_n             ; v > -max
    sec
    lda #0
    sbc ft_vmax,x
    sta ft_vxl,x
    lda #0
    sbc ft_vmax+1,x
    sta ft_vxh,x
ft_cl_n
    inx
    inx
    cpx #4
    bne ft_cl_c
    rts
ft_vmax .word $00C0, $0180

; move, and wrap round the playfield's edges
ft_move
    clc
    lda ft_xl
    adc ft_vxl
    sta ft_xl
    lda ft_x
    adc ft_vxh
    cmp #160
    bcc ft_mv_x
    cmp #208
    bcs ft_mv_xn
    sec                     ; off the right: round to the left
    sbc #160
    jmp ft_mv_x
ft_mv_xn
    adc #160-1              ; (C set: +160) off the left: round to the right
ft_mv_x
    sta ft_x
    clc
    lda ft_yl
    adc ft_vyl
    sta ft_yl
    lda ft_y
    adc ft_vyh
    cmp #PF_TOP
    bcs ft_mv_y1
    adc #PF_BOT-PF_TOP
    jmp ft_mv_y
ft_mv_y1
    cmp #PF_BOT
    bcc ft_mv_y
    sbc #PF_BOT-PF_TOP
ft_mv_y
    sta ft_y
    rts

; ---- twin blasters ----
ft_fire
    lda ft_cool
    beq ft_fi_c
    dec ft_cool
    rts
ft_fi_c
    lda sp_fire
    bne ft_fi_go
    rts
ft_fi_go
    lda #FT_GAP
    sta ft_cool
    ; the guns: either side of the nose, 3 square units out
    lda #3
    sta v_t1
    lda #0
    sta v_t0
    lda ft_ah
    clc
    adc #$40
    jsr vec_rot
    lda vx_h
    sta ft_px
    lda vy_h
    sta ft_py
    ; the shots' velocity: the fighter's + FT_SHOT along the heading
    lda #<FT_SHOT
    sta v_t0
    lda #>FT_SHOT
    sta v_t1
    lda ft_ah
    jsr vec_rot
    clc
    lda vx_l
    adc ft_vxl
    sta vx_l
    lda vx_h
    adc ft_vxh
    sta vx_h
    clc
    lda vy_l
    adc ft_vyl
    sta vy_l
    lda vy_h
    adc ft_vyh
    sta vy_h
    lda #SH_FIGHTER
    sta sh_nt
    lda #FT_SHLIFE
    sta sh_life0
    clc
    lda ft_x
    adc ft_px
    sta sh_nx
    clc
    lda ft_y
    adc ft_py
    sta sh_ny
    jsr sh_spawn
    sec
    lda ft_x
    sbc ft_px
    sta sh_nx
    sec
    lda ft_y
    sbc ft_py
    sta sh_ny
    jsr sh_spawn
    lda #SFX_FSHOT
    jmp sfx

; ---- damage: A off the tether; nothing left and the fighter is lost ----
ft_hurt
    sta vec_tmp
    lda ft_flash            ; just hit: a moment's grace
    beq ft_hu_go
    rts
ft_hu_go
    lda ft_teth
    cmp vec_tmp
    beq ft_hu_dead
    bcc ft_hu_dead
    sbc vec_tmp
    sta ft_teth
    lda #20
    sta ft_flash
    lda #SFX_FHIT
    jmp sfx
ft_hu_dead
    lda #0
    sta ft_teth
    lda #FT_DEAD
    sta ft_st
    lda #FT_REBUILD
    sta ft_tm
    lda ft_x
    sta tg_x
    lda ft_y
    sta tg_y
    jsr pr_boomat
    lda #SFX_LOST
    jmp sfx

; ---------------------------------------------------------------------------
; Shots. sh_spawn: a shot of type sh_nt at (sh_nx, sh_ny), velocity vx/vy,
; life sh_life0. Keeps X.
sh_life0  = $24E7
sh_spawn
    ldy #NS-1
sh_sp_f
    lda sh_t,y
    beq sh_sp_go
    dey
    bpl sh_sp_f
    rts
sh_sp_go
    lda sh_nt
    sta sh_t,y
    lda sh_nx
    sta sh_x,y
    lda sh_ny
    sta sh_y,y
    lda #$80
    sta sh_xl,y
    sta sh_yl,y
    lda vx_l
    sta sh_vxl,y
    lda vx_h
    sta sh_vxh,y
    lda vy_l
    sta sh_vyl,y
    lda vy_h
    sta sh_vyh,y
    lda sh_life0
    sta sh_life,y
    rts

; move the shots; then what they hit
sh_frame
    ldx #NS-1
sh_fr_l
    lda sh_t,x
    beq sh_fr_n
    dec sh_life,x
    beq sh_fr_k
    clc
    lda sh_xl,x
    adc sh_vxl,x
    sta sh_xl,x
    lda sh_x,x
    adc sh_vxh,x
    sta sh_x,x
    cmp #160
    bcs sh_fr_k
    clc
    lda sh_yl,x
    adc sh_vyl,x
    sta sh_yl,x
    lda sh_y,x
    adc sh_vyh,x
    sta sh_y,x
    cmp #PF_TOP
    bcc sh_fr_k
    cmp #PF_BOT
    bcc sh_fr_hit
sh_fr_k
    lda #0
    sta sh_t,x
    beq sh_fr_n
sh_fr_hit
    stx sh_slot
    jsr sh_hits
    ldx sh_slot
sh_fr_n
    dex
    bpl sh_fr_l
    rts

; shot X: a player's shot against rocks and pirates; a pirate's against the
; Ark and the fighter
sh_hits
    lda sh_t,x
    cmp #SH_PIRATE_T
    bne sh_h_player
    ; the Ark
    lda sh_x,x
    cmp #ARK_HX0
    bcc sh_h_ftr
    cmp #ARK_HX1
    bcs sh_h_ftr
    lda sh_y,x
    cmp #ARK_HY0
    bcc sh_h_ftr
    cmp #ARK_HY1
    bcs sh_h_ftr
    lda #0
    sta sh_t,x
    lda #PSHOT_DMG
    jmp sp_arkdmg
sh_h_ftr
    jsr ft_isout
    bcc sh_h_r
    lda sh_x,x
    sec
    sbc ft_x
    clc
    adc #4
    cmp #9
    bcs sh_h_r
    lda sh_y,x
    sec
    sbc ft_y
    clc
    adc #5
    cmp #11
    bcs sh_h_r
    lda #0
    sta sh_t,x
    lda #PSHOT_FDMG
    jmp ft_hurt
sh_h_r
    rts
sh_h_player
    ; who pays: the turret's kills pay back their shot, the fighter's don't
    ldy #0
    cmp #SH_TURRET
    bne sh_h_pay
    ldy #KILL_PAY
sh_h_pay
    sty sp_pay
    ; rocks
    ldy #NR-1
sh_h_rk
    lda rk_t,y
    beq sh_h_rn
    cmp #RK_BOOM
    bcs sh_h_rn
    sta sp_t3
    lda sh_x,x
    clc
    adc #1
    sec
    sbc rk_x,y
    sty sp_t2
    ldy sp_t3
    cmp rock_w2-1,y
    ldy sp_t2
    bcs sh_h_rn
    lda sh_y,x
    sec
    sbc rk_y,y
    ldy sp_t3
    cmp rock_h-1,y
    ldy sp_t2
    bcs sh_h_rn
    ; hit
    lda #0
    sta sh_t,x
    tya
    tax
    stx sp_slot
    jsr sp_rockhit
    ldx sh_slot
    rts
sh_h_rn
    dey
    bpl sh_h_rk
    ; pirates
    jmp pr_shothit

; C = 1 when the fighter is flying (out or homing)
ft_isout
    lda ft_st
    cmp #FT_OUT
    beq ft_io_y
    cmp #FT_HOMING
    beq ft_io_y
    clc
    rts
ft_io_y
    sec
    rts

; ---------------------------------------------------------------------------
; The auto-turret: while the fighter is out, a shot every TU_GAP frames at
; the nearest rock or pirate (any angle). Shots cost SHOT_COST, as the
; laser's do.
tu_frame
    lda tu_cool
    beq tu_go
    dec tu_cool
    rts
tu_go
    lda sp_energy
    cmp #SHOT_COST+1
    bcs tu_r_j757
    jmp tu_r
tu_r_j757
    lda #255
    sta tg_dist
    ; rocks
    ldx #NR-1
tu_rk
    lda rk_t,x
    beq tu_rn
    cmp #RK_BOOM
    bcs tu_rn
    tay
    clc
    lda rk_x,x
    adc rock_cx-1,y
    sta v_t2
    clc
    lda rk_y,x
    adc rock_cy-1,y
    sta v_t3
    jsr tu_try
tu_rn
    dex
    bpl tu_rk
    ; pirates and missiles
    ldx #NP-1
tu_pr
    lda pr_t,x
    beq tu_pn
    cmp #PR_BOOM
    bcs tu_pn
    lda pr_x,x
    sta v_t2
    lda pr_y,x
    sta v_t3
    jsr tu_try
tu_pn
    dex
    bpl tu_pr
    lda tg_dist
    cmp #255
    beq tu_r
    ; fire from the Ark's centre at the target
    lda #ARK_CX
    sta v_t0
    sta sh_nx
    lda #ARK_CY
    sta v_t1
    sta sh_ny
    lda tg_x
    sta v_t2
    lda tg_y
    sta v_t3
    jsr vec_angle
    pha
    lda #<TU_SPEED
    sta v_t0
    lda #>TU_SPEED
    sta v_t1
    pla
    jsr vec_rot
    lda #SH_TURRET
    sta sh_nt
    lda #SH_PLIFE
    sta sh_life0
    jsr sh_spawn
    sec
    lda sp_energy
    sbc #SHOT_COST
    sta sp_energy
    lda #TU_GAP
    sta tu_cool
    lda #SFX_ZAP
    jmp sfx
tu_r
    rts

; target (v_t2, v_t3): nearer than tg_dist (|dx| * 2 + |dy|)? keep it
tu_try
    sec
    lda v_t2
    sbc #ARK_CX
    bcs tu_t_x
    eor #$FF
    adc #1
tu_t_x
    asl
    bcs tu_t_r
    sta vec_tmp
    sec
    lda v_t3
    sbc #ARK_CY
    bcs tu_t_y
    eor #$FF
    adc #1
tu_t_y
    clc
    adc vec_tmp
    bcs tu_t_r
    cmp tg_dist
    bcs tu_t_r
    sta tg_dist
    lda v_t2
    sta tg_x
    lda v_t3
    sta tg_y
tu_t_r
    rts

rock_cx .byte 4, 4, 2
rock_cy .byte 8, 6, 4
