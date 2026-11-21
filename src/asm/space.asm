; ===========================================================================
; Deep space, Mothership mode (M1): the Ark in the centre, 8-way point
; defense, asteroid waves that split (large -> 2 medium -> 2 small).
;
; Rocks come in along the 8 firing lanes (as the 2600 game's came along
; its 4), so every rock can be shot from where it is. A rock that breaks
; sends both halves on down its lane, one faster than the other. (Pirates,
; M2, are what come in off the lanes and need the fighter.)
;
;   sp_new     a new game: energy, score, wave 1
;   sp_frame   one step: input (sp_joy 0-7 / 8 none, sp_fire), bolts,
;              rocks, collisions, waves, the HUD text
;
; The BASIC (cosmicarc.bas) draws from the tables here. Positions are
; screen pixels (x 0-159, 160A) and lines (y 0-191); rocks keep 8.8 fixed
; point. Velocities and angles work in "square" units, x counted in
; hi-res pixels (twice 160A's), so a rock's speed looks the same in every
; direction: the math unit gets dx*2, and x velocity is halved after.
;
; Playfield: y 8-183. Rows 0 and 23 (8 lines each) are the HUD.
; ===========================================================================

NR        = 10      ; rock slots (rocks and explosions)
NB        = 4       ; bolt slots

ARK_X     = 64      ; the Ark's sprite, 32 x 16
ARK_Y     = 88
ARK_CX    = 80      ; its centre
ARK_CY    = 95
ARK_HX0   = 66      ; its hit box: x 66-93, y 88-101
ARK_HX1   = 94
ARK_HY0   = 88
ARK_HY1   = 102

PF_TOP    = 8
PF_BOT    = 184

EN_MAX    = 96      ; energy: 12 bar cells of 8
FIRE_GAP  = 8       ; frames between bolts
BOLT_LIFE = 40

RK_FREE   = 0
RK_L      = 1
RK_M      = 2
RK_S      = 3
RK_BOOM   = 4       ; an explosion: rk_tm counts down from 17

ST_PLAY   = 0
ST_CLEAR  = 1       ; "WAVE CLEAR", then the next wave
ST_OVER   = 2       ; "ARC LOST"
ST_START  = 3       ; "WAVE nn" before the rocks come

; ---- RAM ($2300-$23FF) ----
rk_t      = $2300   ; [NR]
rk_x      = $230A
rk_xl     = $2314
rk_y      = $231E
rk_yl     = $2328
rk_vxl    = $2332
rk_vxh    = $233C
rk_vyl    = $2346
rk_vyh    = $2350
rk_tm     = $235A
bl_t      = $2364   ; [NB] frames left (0 = free)
bl_x      = $2368
bl_y      = $236C
bl_dx     = $2370
bl_dy     = $2374
bl_d      = $2378
sp_joy    = $2380   ; in: 0-7, 8 = centred
sp_fire   = $2381   ; in: button 1 held
sp_aim    = $2382   ; 0-7 (0 up, clockwise)
sp_aimx   = $2383   ; the aim marker's sprite position
sp_aimy   = $2384
sp_cool   = $2385
sp_energy = $2386
sp_score  = $2387   ; 3 BCD bytes, high first
sp_wave   = $238A   ; binary
sp_wavebcd = $238B
sp_state  = $238C
sp_timer  = $238D
sp_left   = $238E   ; rocks still to come this wave
sp_spawn  = $238F   ; frames to the next one
sp_gap    = $2390   ; frames between rocks this wave
sp_spdl   = $2391   ; a large rock's speed this wave (8.8, square units)
sp_spdh   = $2392
sp_flash  = $2393   ; the Ark was hit: frames of red
sp_live   = $2394   ; rocks (not explosions) on screen
sp_t0     = $2395
sp_t1     = $2396
sp_t2     = $2397
sp_t3     = $2398
sp_ang    = $2399   ; 2
sp_slot   = $239B
sp_kids   = $239C
sp_msglen = $239D   ; 0: no message
sp_msgx   = $239E
sp_ticks  = $239F   ; game loop passes (for frame-rate checks)
hud_top   = $23A0   ; 20 characters
hud_bot   = $23B8   ; 20
sp_msg    = $23D0   ; 20

; ---------------------------------------------------------------------------
sp_new
    lda #EN_MAX
    sta sp_energy
    lda #0
    sta sp_score
    sta sp_score+1
    sta sp_score+2
    sta sp_wave
    sta sp_wavebcd
    sta sp_aim
    sta sp_flash
    jsr sp_clear
    jmp sp_nextwave

sp_clear
    ldx #NR-1
    lda #0
sp_clear_r
    sta rk_t,x
    dex
    bpl sp_clear_r
    ldx #NB-1
sp_clear_b
    sta bl_t,x
    dex
    bpl sp_clear_b
    rts

; the next wave: more rocks, faster, closer together
sp_nextwave
    inc sp_wave
    sed
    clc
    lda sp_wavebcd
    adc #1
    sta sp_wavebcd
    cld
    lda sp_wave
    clc
    adc #3
    cmp #13
    bcc sp_nw_n
    lda #12
sp_nw_n
    sta sp_left
    ; gap = 110 - 10 * wave, at least 40
    lda sp_wave
    asl
    sta sp_t0
    asl
    asl
    clc
    adc sp_t0
    sta sp_t0
    sec
    lda #110
    sbc sp_t0
    bcc sp_nw_g
    cmp #40
    bcs sp_nw_g2
sp_nw_g
    lda #40
sp_nw_g2
    sta sp_gap
    lda #30
    sta sp_spawn
    ; speed = $60 + 8 * wave (8.8)
    lda sp_wave
    asl
    asl
    asl
    clc
    adc #$60
    sta sp_spdl
    lda #0
    adc #0
    sta sp_spdh
    lda #ST_START
    sta sp_state
    lda #90
    sta sp_timer
    jmp sp_msg_wave

; ---------------------------------------------------------------------------
sp_frame
    inc sp_ticks
    lda sp_flash
    beq sp_f_nf
    dec sp_flash
sp_f_nf
    lda sp_state
    cmp #ST_OVER
    bne sp_f_live
    jsr sp_rocks            ; (the rocks drift on, the Ark is gone)
    jmp sp_hud
sp_f_live
    jsr sp_input
    jsr sp_bolts
    jsr sp_rocks
    jsr sp_hits
    jsr sp_waves
    jmp sp_hud

; ---- input: aim, fire ----
sp_input
    lda sp_joy
    cmp #8
    bcs sp_in_keep
    sta sp_aim
sp_in_keep
    ldx sp_aim
    clc
    lda #ARK_CX-2
    adc aim_ox,x
    sta sp_aimx
    clc
    lda #ARK_CY-2
    adc aim_oy,x
    sta sp_aimy
    lda sp_cool
    beq sp_in_c
    dec sp_cool
    rts
sp_in_c
    lda sp_fire
    beq sp_in_r
    lda sp_state
    cmp #ST_PLAY
    bne sp_in_r
    lda sp_energy
    cmp #2
    bcc sp_in_r             ; too weak to fire
    ldy #NB-1
sp_in_s
    lda bl_t,y
    beq sp_in_fire
    dey
    bpl sp_in_s
sp_in_r
    rts
sp_in_fire
    lda #BOLT_LIFE
    sta bl_t,y
    lda sp_aimx
    sta bl_x,y
    lda sp_aimy
    sta bl_y,y
    lda bolt_dx,x
    sta bl_dx,y
    lda bolt_dy,x
    sta bl_dy,y
    txa
    sta bl_d,y
    lda #FIRE_GAP
    sta sp_cool
    dec sp_energy
    lda #SFX_ZAP
    jmp sfx

; aim marker / bolt start, from the Ark's centre, on the lane (diagonals:
; 1 pixel across for 2 lines, as the bolts and the rocks move); bolt steps
; a frame
aim_ox  .byte 0, 7, 22, 7, 0, -7, -22, -7
aim_oy  .byte -14, -14, 0, 14, 14, 14, 0, -14
bolt_dx .byte 0, 2, 3, 2, 0, -2, -3, -2
bolt_dy .byte -5, -4, 0, 4, 5, 4, 0, -4

; ---- bolts ----
sp_bolts
    ldx #NB-1
sp_bl_l
    lda bl_t,x
    beq sp_bl_n
    dec bl_t,x
    clc
    lda bl_x,x
    adc bl_dx,x
    sta bl_x,x
    cmp #157
    bcs sp_bl_k
    clc
    lda bl_y,x
    adc bl_dy,x
    sta bl_y,x
    cmp #PF_TOP
    bcc sp_bl_k
    cmp #PF_BOT-4
    bcc sp_bl_n
sp_bl_k
    lda #0
    sta bl_t,x
sp_bl_n
    dex
    bpl sp_bl_l
    rts

; ---- rocks: move, leave the screen, explosions run down ----
sp_rocks
    lda #0
    sta sp_live
    ldx #NR-1
sp_rk_l
    lda rk_t,x
    beq sp_rk_n
    cmp #RK_BOOM
    bcc sp_rk_mv
    dec rk_tm,x
    bne sp_rk_n
    lda #0
    sta rk_t,x
    beq sp_rk_n
sp_rk_mv
    inc sp_live
    clc
    lda rk_xl,x
    adc rk_vxl,x
    sta rk_xl,x
    lda rk_x,x
    adc rk_vxh,x
    sta rk_x,x
    cmp #160
    bcs sp_rk_gone
    clc
    lda rk_yl,x
    adc rk_vyl,x
    sta rk_yl,x
    lda rk_y,x
    adc rk_vyh,x
    sta rk_y,x
    cmp #PF_TOP-4
    bcc sp_rk_gone
    cmp #PF_BOT
    bcc sp_rk_n
sp_rk_gone
    lda #0
    sta rk_t,x
    dec sp_live
sp_rk_n
    dex
    bpl sp_rk_l
    rts

; ---- collisions ----
sp_hits
    ldx #NR-1
sp_h_rock
    lda rk_t,x
    beq sp_h_skip
    cmp #RK_BOOM
    bcc sp_h_live
sp_h_skip
    jmp sp_h_next
sp_h_live
    tay
    ; the rock against the Ark: rx < 94, rx + w > 66, ry < 102, ry + h > 88
    lda rk_x,x
    cmp #ARK_HX1
    bcs sp_h_bolts
    clc
    adc rock_w-1,y
    cmp #ARK_HX0+1
    bcc sp_h_bolts
    lda rk_y,x
    cmp #ARK_HY1
    bcs sp_h_bolts
    clc
    adc rock_h-1,y
    cmp #ARK_HY0+1
    bcc sp_h_bolts
    stx sp_slot
    jsr sp_arkhit
    ldx sp_slot
    jmp sp_h_next
sp_h_bolts
    stx sp_slot
    ldy #NB-1
sp_h_b
    lda bl_t,y
    beq sp_h_bn
    ldx sp_slot
    lda rk_t,x
    sta sp_t3
    ; the bolt's middle (x+2, y+2) inside the rock's box
    lda bl_x,y
    clc
    adc #2
    sec
    sbc rk_x,x
    ldx sp_t3
    cmp rock_w-1,x
    bcs sp_h_bn
    ldx sp_slot
    lda bl_y,y
    clc
    adc #2
    sec
    sbc rk_y,x
    ldx sp_t3
    cmp rock_h-1,x
    bcs sp_h_bn
    lda #0
    sta bl_t,y
    ldx sp_slot
    jsr sp_rockhit
    ldx sp_slot
    jmp sp_h_next
sp_h_bn
    dey
    bpl sp_h_b
    ldx sp_slot
sp_h_next
    dex
    bmi sp_h_done
    jmp sp_h_rock
sp_h_done
    rts

rock_w  .byte 8, 7, 4
rock_h  .byte 16, 12, 8
rock_dmg .byte 16, 12, 8
; points, BCD: large 20, medium 50, small 100 (middle byte / low byte)
rock_pm .byte $00, $00, $01
rock_pl .byte $20, $50, $00

; a rock (slot X) hits the Ark
sp_arkhit
    ldy rk_t,x
    sec
    lda sp_energy
    sbc rock_dmg-1,y
    bcs sp_ah_e
    lda #0
sp_ah_e
    sta sp_energy
    jsr sp_boom
    lda #20
    sta sp_flash
    lda #SFX_HIT
    jsr sfx
    lda sp_energy
    bne sp_ah_r
    lda #ST_OVER
    sta sp_state
    lda #0
    ldy #NB-1
sp_ah_b
    sta bl_t,y              ; the bolts go with the Ark
    dey
    bpl sp_ah_b
    lda #SFX_LOST
    jsr sfx
    jmp sp_msg_over
sp_ah_r
    rts

; slot X becomes an explosion
sp_boom
    lda #RK_BOOM
    sta rk_t,x
    lda #17
    sta rk_tm,x
    rts

; a bolt destroys rock X (= sp_slot): points, energy, two smaller rocks
sp_rockhit
    ldy rk_t,x
    sty sp_kids
    sed
    clc
    lda sp_score+2
    adc rock_pl-1,y
    sta sp_score+2
    lda sp_score+1
    adc rock_pm-1,y
    sta sp_score+1
    lda sp_score
    adc #0
    sta sp_score
    cld
    clc                     ; a kill pays 2: a sure shot gains, a spray loses
    lda sp_energy
    adc #2
    cmp #EN_MAX
    bcc sp_rh_e
    lda #EN_MAX
sp_rh_e
    sta sp_energy
    lda #SFX_BOOM
    jsr sfx                 ; (sfx uses X and Y)
    ldx sp_slot
    lda sp_kids
    cmp #RK_S
    bcs sp_rh_boom          ; a small one just goes
    ; the children go on down the lane, one faster than the other
    inc sp_kids             ; their size
    ; the parent's heading: atan2(vy, 2 vx)
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
    lda M_ANG
    sta sp_ang
    lda M_ANG+1
    sta sp_ang+1
    lda #$00
    jsr sp_kid
    lda #$30
    jsr sp_kid
    ldx sp_slot
sp_rh_boom
    jmp sp_boom

; one child of rock sp_slot, size sp_kids, heading sp_ang, speed this
; wave's + $20 a size step + A
sp_kid
    sta sp_t2
    ldy #NR-1
sp_kid_f
    lda rk_t,y
    beq sp_kid_go
    dey
    bpl sp_kid_f
    rts                     ; no room
sp_kid_go
    tya
    tax
    ldy sp_slot
    lda sp_kids
    sta rk_t,x
    lda rk_x,y
    clc
    adc #1
    sta rk_x,x
    lda rk_y,y
    clc
    adc #2
    sta rk_y,x
    lda #0
    sta rk_xl,x
    sta rk_yl,x
    lda sp_kids
    sec
    sbc #1
    asl
    asl
    asl
    asl
    asl
    clc
    adc sp_t2
    clc
    adc sp_spdl
    sta M_X
    lda sp_spdh
    adc #0
    sta M_X+1
    lda #0
    sta M_Y
    sta M_Y+1
    lda sp_ang
    sta M_T
    lda sp_ang+1
    sta M_T+1
    jmp sp_setvel

; velocity of rock X from the math unit's turned vector (square units):
; vx = XR / 2, vy = YR
sp_setvel
    lda M_XR+1
    cmp #$80
    ror
    sta rk_vxh,x
    lda M_XR
    ror
    sta rk_vxl,x
    lda M_YR
    sta rk_vyl,x
    lda M_YR+1
    sta rk_vyh,x
    rts

; ---- waves: spawning, clear, next ----
sp_waves
    lda sp_state
    cmp #ST_START
    bne sp_w_play
    dec sp_timer
    bne sp_w_r
    lda #ST_PLAY
    sta sp_state
    lda #0
    sta sp_msglen
sp_w_r
    rts
sp_w_play
    cmp #ST_CLEAR
    bne sp_w_p2
    dec sp_timer
    bne sp_w_r
    jmp sp_nextwave
sp_w_p2
    lda sp_left
    bne sp_w_spawn
    lda sp_live
    bne sp_w_r
    ; wave clear: a bonus of energy
    lda #ST_CLEAR
    sta sp_state
    lda #120
    sta sp_timer
    clc
    lda sp_energy
    adc #24
    cmp #EN_MAX
    bcc sp_w_e
    lda #EN_MAX
sp_w_e
    sta sp_energy
    lda #SFX_CLEAR
    jsr sfx
    jmp sp_msg_clear
sp_w_spawn
    dec sp_spawn
    bne sp_w_r
    lda sp_gap
    sta sp_spawn
    ldx #NR-1
sp_w_f
    lda rk_t,x
    beq sp_w_new
    dex
    bpl sp_w_f
    lda #1                  ; no room: try again next frame
    sta sp_spawn
    rts
sp_w_new
    dec sp_left
    lda #RK_L
    sta rk_t,x
    lda #0
    sta rk_xl,x
    sta rk_yl,x
    ; a lane, 0-7 (0 up, clockwise): its start at the playfield's edge
    lda M_RND
    and #7
    tay
    lda lane_x,y
    sta rk_x,x
    lda lane_y,y
    sta rk_y,x
    ; heading: at the Ark's centre
    sec
    lda #ARK_CX-4
    sbc rk_x,x
    sta sp_t0
    lda #0
    sbc #0
    sta sp_t1
    asl sp_t0               ; x in square units
    rol sp_t1
    lda sp_t0
    sta M_X
    lda sp_t1
    sta M_X+1
    sec
    lda #ARK_CY-8
    sbc rk_y,x
    sta M_Y
    lda #0
    sbc #0
    sta M_Y+1
    lda M_ANG
    sta M_T
    lda M_ANG+1
    sta M_T+1
    lda sp_spdl
    sta M_X
    lda sp_spdh
    sta M_X+1
    lda #0
    sta M_Y
    sta M_Y+1
    jmp sp_setvel

; where a large rock (8 x 16) enters on each lane: on the line from the
; Ark's centre (80, 95) through the lane's direction (in square units:
; diagonals are 1 pixel across for 2 lines), at the playfield's edge
lane_x  .byte 76, 115, 152, 115, 76, 37, 0, 37
lane_y  .byte PF_TOP, PF_TOP, 87, PF_BOT-16, PF_BOT-16, PF_BOT-16, 87, PF_TOP

; ---------------------------------------------------------------------------
; The HUD text (character codes: (ASCII - 32) * 2, doublewide)
;   top:    "000000        WAVE 01"
;   bottom: "ENERGY [[[[[[[[[[[[ "
sp_hud
    ldy #0
    ldx #0
sp_hud_sc
    lda sp_score,x
    lsr
    lsr
    lsr
    lsr
    jsr tx_digit
    sta hud_top,y
    iny
    lda sp_score,x
    and #$0F
    jsr tx_digit
    sta hud_top,y
    iny
    inx
    cpx #3
    bne sp_hud_sc
    lda #0
sp_hud_sp
    sta hud_top,y
    iny
    cpy #13
    bne sp_hud_sp
    ldx #0
sp_hud_w
    lda tx_wave,x
    sta hud_top,y
    iny
    inx
    cpx #5
    bne sp_hud_w
    lda sp_wavebcd
    lsr
    lsr
    lsr
    lsr
    jsr tx_digit
    sta hud_top,y
    iny
    lda sp_wavebcd
    and #$0F
    jsr tx_digit
    sta hud_top,y
    ; bottom: the energy bar, 12 cells of 4
    ldx #0
sp_hud_en
    lda tx_energy,x
    sta hud_bot,x
    inx
    cpx #7
    bne sp_hud_en
    lda sp_energy
    sta sp_t0
sp_hud_bar
    lda sp_t0
    cmp #8
    bcc sp_hud_part
    sbc #8
    sta sp_t0
    lda #CH_BAR4
    sta hud_bot,x
    inx
    cpx #19
    bne sp_hud_bar
    beq sp_hud_end
sp_hud_part
    lsr
    tay
    lda bar_part,y
    sta hud_bot,x
    lda #0
    sta sp_t0
    inx
    cpx #19
    bne sp_hud_part0
    beq sp_hud_end
sp_hud_part0
    lda #0
    sta hud_bot,x
    inx
    cpx #20
    bne sp_hud_part0
sp_hud_end
    lda #0
    sta hud_bot+19
    rts

bar_part .byte 0, CH_BAR1, CH_BAR2, CH_BAR3

; ---- messages in the middle of the screen ----
sp_msg_wave
    ldx #0
sp_mw_l
    lda tx_wave,x
    sta sp_msg,x
    inx
    cpx #5
    bne sp_mw_l
    lda sp_wavebcd
    lsr
    lsr
    lsr
    lsr
    jsr tx_digit
    sta sp_msg+5
    lda sp_wavebcd
    and #$0F
    jsr tx_digit
    sta sp_msg+6
    lda #7
    ldx #80-28
    jmp sp_msgset
sp_msg_clear
    lda #<tx_clear
    ldy #>tx_clear
    ldx #10
    jmp sp_msgcopy
sp_msg_over
    lda #<tx_lost
    ldy #>tx_lost
    ldx #8
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
