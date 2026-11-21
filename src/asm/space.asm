; ===========================================================================
; Deep space, Mothership mode (M1): the Ark in the centre, 8-way point
; defense, asteroid waves that split (large -> 2 medium -> 2 small).
;
; Rocks come in along the 8 firing lanes (as the 2600 game's came along
; its 4), so every rock can be shot from where it is. A rock that breaks
; sends both halves on down its lane, one faster than the other. (Pirates,
; M2, are what come in off the lanes and need the fighter.)
;
; A rock keeps its lane (rk_ln), and its velocity comes from the lane, not
; from a heading: straight, or exactly 1 pixel across for 2 lines on the
; diagonals, so rounding can't walk it off the lane (it did: headings
; worked out again at each split drifted small rocks 4 pixels aside).
; A rock's centre is its corner + (4, 8) large, (4, 6) medium, (2, 4) small.
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
; Playfield: y 16-175. Zone rows 0 and 11 (16 lines each) are the HUD.
; ===========================================================================

NR        = 10      ; rock slots (rocks and explosions)
NB        = 4       ; bolt slots

ARK_X     = 56      ; the Ark's sprite, 48 x 32, on a zone boundary
ARK_Y     = 80
ARK_CX    = 80      ; its centre (the hull's middle line)
ARK_CY    = 95
ARK_HX0   = 57      ; its hit box: x 57-102, y 86-102
ARK_HX1   = 103
ARK_HY0   = 86
ARK_HY1   = 103

PF_TOP    = 16
PF_BOT    = 176

EN_MAX    = 96      ; energy: 12 bar cells of 8

; ---- balance knobs (docs/DESIGN.md 4.2) ----
; Energy is net-neutral for perfect play: a kill pays back exactly the shot
; that made it. Misses and hits by rocks cost energy that has to come back
; some other way (captures, ports). Weapon upgrades (later) and faster rocks
; in later waves and sectors are the other knobs.
SHOT_COST = 1       ; energy a bolt costs
KILL_PAY  = 1       ; energy a kill pays (= SHOT_COST: perfect play breaks even)
CLEAR_PAY = 0       ; energy for clearing a wave (0: none, by the rule above)
FIRE_GAP  = 8       ; frames between bolts
WV_COUNT0 = 3       ; large rocks in a wave: WV_COUNT0 + wave, at most WV_COUNTMAX
WV_COUNTMAX = 12
WV_GAP0   = 110     ; frames between rocks: WV_GAP0 - WV_GAPSTEP * wave,
WV_GAPSTEP = 10     ;   at least WV_GAPMIN
WV_GAPMIN = 40
WV_SPEED0 = $60     ; a large rock's speed (8.8 square units a frame):
WV_SPEEDSTEP = 8    ;   WV_SPEED0 + WV_SPEEDSTEP * wave
KID_SPEED = $20     ; a smaller rock goes this much faster a size step
KID_SPLIT = $30     ; and the second piece of a split this much more again
; rock_dmg (below): energy a rock costs when it hits the Ark
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
sp_slot   = $239B
sp_kids   = $239C
sp_msglen = $239D   ; 0: no message
sp_msgx   = $239E
sp_ticks  = $239F   ; game loop passes (for frame-rate checks)
hud_top   = $23A0   ; 20 characters
hud_bot   = $23B8   ; 20
sp_msg    = $23D0   ; 20
rk_ln     = $23E4   ; [NR] the rock's lane, 0-7

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
    adc #WV_COUNT0
    cmp #WV_COUNTMAX+1
    bcc sp_nw_n
    lda #WV_COUNTMAX
sp_nw_n
    sta sp_left
    ; gap = WV_GAP0 - WV_GAPSTEP * wave, at least WV_GAPMIN
    lda sp_wave
    sta M_A
    lda #0
    sta M_A+1
    sta M_B+1
    sta M_CTRL
    lda #WV_GAPSTEP
    sta M_B
    sec
    lda #WV_GAP0
    sbc M_P
    bcc sp_nw_g
    ldx M_P+1
    bne sp_nw_g
    cmp #WV_GAPMIN
    bcs sp_nw_g2
sp_nw_g
    lda #WV_GAPMIN
sp_nw_g2
    sta sp_gap
    lda #30
    sta sp_spawn
    ; speed = WV_SPEED0 + WV_SPEEDSTEP * wave (8.8)
    lda #WV_SPEEDSTEP
    sta M_B
    clc
    lda M_P
    adc #<WV_SPEED0
    sta sp_spdl
    lda M_P+1
    adc #>WV_SPEED0
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
    cmp #SHOT_COST+1
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
    sec
    lda sp_energy
    sbc #SHOT_COST
    sta sp_energy
    lda #SFX_ZAP
    jmp sfx

; aim marker / bolt start, from the Ark's centre, on the lane (diagonals:
; 1 pixel across for 2 lines, as the bolts and the rocks move); bolt steps
; a frame
aim_ox  .byte 0, 9, 30, 9, 0, -9, -30, -9
aim_oy  .byte -18, -18, 0, 18, 18, 18, 0, -18
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
    adc #3                  ; (a pixel of slack either side)
    sec
    sbc rk_x,x
    ldx sp_t3
    cmp rock_w2-1,x
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

rock_w  .byte 8, 8, 4
rock_h  .byte 16, 12, 8
rock_w2 .byte 10, 10, 6      ; widths with the bolt's slack
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
    clc                     ; a kill pays back its shot
    lda sp_energy
    adc #KILL_PAY
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
    lda #0
    jsr sp_kid
    lda #KID_SPLIT
    jsr sp_kid
    ldx sp_slot
sp_rh_boom
    jmp sp_boom

; one child of rock sp_slot, size sp_kids, on its lane, speed this
; wave's + $20 a size step + A. Its centre is its parent's.
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
    lda rk_ln,y
    sta rk_ln,x
    lda rk_x,y
    sta rk_x,x
    lda rk_y,y
    sta rk_y,x
    lda rk_xl,y
    sta rk_xl,x
    lda rk_yl,y
    sta rk_yl,x
    ldy sp_kids
    clc
    lda rk_x,x
    adc kid_dx-2,y
    sta rk_x,x
    clc
    lda rk_y,x
    adc #2                  ; (large -> medium and medium -> small both 2 lines)
    sta rk_y,x
    tya
    sta rk_t,x
    ; speed: this wave's + KID_SPEED a size step + A
    sec
    sbc #1
    sta M_A
    lda #0
    sta M_A+1
    sta M_B+1
    sta M_CTRL
    lda #KID_SPEED
    sta M_B
    lda M_P
    clc
    adc sp_t2
    clc
    adc sp_spdl
    sta sp_t0
    lda sp_spdh
    adc #0
    sta sp_t1
    jmp sp_lanevel

; the children's corners from the parent's: medium 0 across, small 2
kid_dx  .byte 0, 2

; rock X's velocity down its lane at speed sp_t0/sp_t1 (8.8, square units:
; lines, or hi-res pixels across, a frame). Vertical lanes: vy = s.
; Across: vx = s/2 pixels. Diagonals: vy = s * 181/256 (s / sqrt 2, on the
; math unit), made even, and vx = vy/2 exactly.
sp_lanevel
    ldy rk_ln,x
    lda #0
    sta sp_t2               ; |vx| low, high in sp_t3
    sta sp_t3
    sta rk_vyl,x
    sta rk_vyh,x
    lda lane_kind,y
    beq sp_lv_vert
    cmp #1
    beq sp_lv_across
    ; diagonal
    lda sp_t0
    sta M_A
    lda sp_t1
    sta M_A+1
    lda #181
    sta M_B
    lda #0
    sta M_B+1
    sta M_CTRL
    lda M_P+1
    and #$FE
    sta rk_vyl,x
    lda M_P+2
    sta rk_vyh,x
    lsr
    sta sp_t3
    lda rk_vyl,x
    ror
    sta sp_t2
    jmp sp_lv_sign
sp_lv_vert
    lda sp_t0
    sta rk_vyl,x
    lda sp_t1
    sta rk_vyh,x
    jmp sp_lv_sign
sp_lv_across
    lda sp_t1
    lsr
    sta sp_t3
    lda sp_t0
    ror
    sta sp_t2
sp_lv_sign
    ; inwards: the lane's outward direction turned round
    lda sp_t2
    sta rk_vxl,x
    lda sp_t3
    sta rk_vxh,x
    lda lane_sx,y
    beq sp_lv_x0
    bpl sp_lv_y
    jsr sp_negx
    jmp sp_lv_y
sp_lv_x0
    lda #0
    sta rk_vxl,x
    sta rk_vxh,x
sp_lv_y
    lda lane_sy,y
    bmi sp_lv_ny
    bne sp_lv_r
    lda #0
    sta rk_vyl,x
    sta rk_vyh,x
sp_lv_r
    rts
sp_lv_ny
    sec
    lda #0
    sbc rk_vyl,x
    sta rk_vyl,x
    lda #0
    sbc rk_vyh,x
    sta rk_vyh,x
    rts
sp_negx
    sec
    lda #0
    sbc rk_vxl,x
    sta rk_vxl,x
    lda #0
    sbc rk_vxh,x
    sta rk_vxh,x
    rts

; per lane (0 up, clockwise): 0 vertical, 1 across, 2 diagonal; and the
; signs of a rock's velocity (inwards: towards the Ark)
lane_kind .byte 0, 2, 1, 2, 0, 2, 1, 2
lane_sx   .byte 0, -1, -1, -1, 0, 1, 1, 1
lane_sy   .byte 1, 1, 0, -1, -1, -1, 0, 1

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
    ; wave clear (CLEAR_PAY energy: none for now)
    lda #ST_CLEAR
    sta sp_state
    lda #120
    sta sp_timer
    clc
    lda sp_energy
    adc #CLEAR_PAY
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
    sta rk_ln,x
    tay
    lda lane_x,y
    sta rk_x,x
    lda lane_y,y
    sta rk_y,x
    lda sp_spdl
    sta sp_t0
    lda sp_spdh
    sta sp_t1
    jmp sp_lanevel

; where a large rock (8 x 16; centre = corner + (4, 8)) enters on each
; lane, at the playfield's edge, its centre exactly on the line from the
; Ark's centre (80, 95): diagonals 1 pixel across for 2 lines, e.g. lane 1's
; centre (115, 25) is 35 across for 70 up
lane_x  .byte 76, 111, 152, 112, 76, 40, 0, 41
lane_y  .byte 16, 17, 87, 159, 160, 159, 87, 17

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
