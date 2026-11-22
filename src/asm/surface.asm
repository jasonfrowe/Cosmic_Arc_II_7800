; ===========================================================================
; The planet (M3): Cosmic Arc's surface run, on a horizontally scrolling
; planet that wraps round (1024 pixels: tools/planet.py).
;
; The Ark hangs in orbit at the top of the screen (it follows you round).
; The shuttle (the saucer) sits at the screen's centre across: the ground
; scrolls under it. Down launches it from the Ark; it flies up into the Ark
; to dock and hand over what it carries.
;   button 1  the tractor beam: a creature (or ore crate) under the shuttle
;             rises into it while the beam holds; let go and it drops
;   button 2  the stun pulse: creatures and turrets near the shuttle freeze
; Creatures: walker, hopper, runner (flees the beam), burrower, glider,
; blinker (teleports). Turrets ride towers and shoot at the shuttle: a hit
; knocks its cargo loose. The clock: 60 s; at 15 the klaxon; at 0, time's
; up (a shuttle still out costs the Ark energy). Every creature delivered:
; the Ark's energy full again.
;
;   pl_new    a planet: creatures, crates, turrets; the shuttle docked
;   pl_frame  one step; pl_state = PL_DONE when it's over
;   pl_draw   the sprites (the BASIC draws the Ark, the ground, the HUD)
;
; World x: 16 bits, 0-1023 (hi & 3). Screen y: lines. Camera: cam = the
; shuttle's world x - 80; a thing's screen x = (its x - cam) & 1023, shown
; if under 160 or 1016 and over (half off the left: MARIA wraps x).
; ===========================================================================

BANK_PLANET = 3

; ---- knobs ----
PL_TIME   = 60      ; seconds on the surface
PL_KLAXON = 15      ; the klaxon from here
PL_ACC    = $20     ; shuttle acceleration across (8.8 pixels a frame)
PL_VMAX   = $0200   ; top speed across
PL_LIFT   = 1       ; lines a frame a creature rises in the beam
BEAM_HALF = 6       ; the beam takes a creature whose middle is this near
PL_STUNCD = 150     ; frames between stun pulses
PL_STUNR  = 36      ; a pulse reaches this far across (and down)
CR_STUN   = 150     ; frames a creature stays stunned
TT_FREEZE = 200     ; frames a turret stays frozen
TT_GAP    = 120     ; frames between a turret's shots (+ up to 63)
TT_SPREAD = 31      ; its aim strays up to +-TT_SPREAD/2 (of 256 a turn)
TT_RANGE  = 72      ; it shoots at a shuttle this near across
TS_SPEED  = $0200
TS_DMG    = 4       ; a turret shot costs the Ark this
CR_PAY    = 12      ; Ark energy for a creature delivered
LOST_DMG  = 12      ; ... lost at time up with the shuttle out

PL_DOCKY  = 58      ; the shuttle's centre, docked in the Ark's bay
PL_YMAX   = 146
GROUND_Y  = 149     ; a creature's top, standing (feet on the surface, 157)
GLIDE_Y   = 112

; shuttle
PL_DOCKED = 0
PL_FLYING = 1
; pl_state
PL_PLAY   = 0
PL_CLEAR  = 1
PL_TIMEUP = 2
PL_DONE   = 3
; creature states
CS_GROUND = 0
CS_AIR    = 1       ; jumping, falling, or a glider flying
CS_LIFT   = 2       ; in the beam
CS_HELD   = 3       ; in the shuttle
CS_HIDE   = 4       ; burrowed / blinked out
; kinds
CK_WALK   = 0
CK_HOP    = 1
CK_RUN    = 2
CK_BURROW = 3
CK_GLIDE  = 4
CK_BLINK  = 5
; cargo
HOLD_NONE = 0
HOLD_CR   = 1
HOLD_ORE  = 2

NCR       = 4
NCK       = 2
NTT       = 2
NTS       = 4

; ---- RAM ($2700-$27FF) ----
pl_wx     = $2700   ; the shuttle's world x: lo, hi, fraction
pl_wxh    = $2701
pl_wxf    = $2702
pl_vxl    = $2703
pl_vxh    = $2704
pl_cam    = $2705   ; lo, hi
pl_camh   = $2706
pl_y      = $2707
pl_st     = $2709
pl_hold   = $270A
pl_holdi  = $270B
pl_beam   = $270C
pl_stun   = $270D
pl_pulse  = $270E
pl_hit    = $270F
pl_tml    = $2710
pl_tmh    = $2711
pl_secs   = $2712
pl_sub    = $2713
pl_state  = $2714
pl_endtm  = $2715
pl_caught = $2716
pl_total  = $2717
pl_ore    = $2718
pl_fine   = $2719   ; the ground's x (fine scroll)
pl_col    = $271A   ; ... and its first map column
pl_tick   = $271B   ; frames on the planet
pl_f2old  = $271C
pl_msgtm  = $271D
pl_yh     = $271E   ; (crate climbing: half speed)
cr_t      = $2720   ; [NCR] kind + 1 (0: none)
cr_xl     = $2724
cr_xh     = $2728
cr_xf     = $272C
cr_y      = $2730
cr_yf     = $2734
cr_vyl    = $2738
cr_vyh    = $273C
cr_st     = $2740
cr_tm     = $2744
cr_stun   = $2748
cr_dir    = $274C   ; 0 right, 1 left
cr_sx     = $2750   ; screen x this frame
cr_vis    = $2754   ; on the screen this frame
cr_fast   = $2758   ; a runner running: frames left
ck_st     = $2760   ; [NCK] 0 gone, else CS_ state + 1
ck_xl     = $2762
ck_xh     = $2764
ck_y      = $2766
ck_yf     = $2768
ck_sx     = $276A
ck_vis    = $276C
tt_xl     = $2770   ; [NTT]
tt_xh     = $2772
tt_y      = $2774
tt_dir    = $2776
tt_cool   = $2778
tt_frz    = $277A
tt_sx     = $277C
tt_vis    = $277E
ts_t      = $2780   ; [NTS]
ts_xl     = $2784
ts_xh     = $2788
ts_xf     = $278C
ts_y      = $2790
ts_yf     = $2794
ts_vxl    = $2798
ts_vxh    = $279C
ts_vyl    = $27A0
ts_vyh    = $27A4
ts_sx     = $27A8
ts_vis    = $27AC
pl_t0     = $27B0
pl_t1     = $27B1
pl_t2     = $27B2
pl_i      = $27B3

; ---------------------------------------------------------------------------
pl_new
    ldx #$4F                ; clear $2700-$274F... and the rest below
    lda #0
pl_new_c
    sta $2700,x
    sta $2750,x
    dex
    bpl pl_new_c
    ldx #$5F
pl_new_c2
    sta $27A0,x
    dex
    bpl pl_new_c2
    lda #PL_DOCKED
    sta pl_st
    lda #PL_DOCKY
    sta pl_y
    lda #<512               ; the shuttle starts between the towers
    sta pl_wx
    lda #>512
    sta pl_wxh
    lda #PL_TIME
    sta pl_secs
    lda #60
    sta pl_sub
    ; creatures: 2-4, kinds at random, spread round the planet
    lda M_RND
    and #3
    cmp #3
    bne pl_new_n
    lda #2
pl_new_n
    clc
    adc #2
    sta pl_total
    tay
    dey
pl_new_cr
    lda M_RND
    and #7
    cmp #6
    bcs pl_new_cr           ; a kind 0-5
    clc
    adc #1
    sta cr_t,y
    lda pl_spread,y         ; quarters of the planet, apart
    clc
    adc M_RND
    and #$3F
    sta pl_t0
    lda pl_spread,y
    and #$C0
    ora pl_t0
    sta cr_xl,y
    lda pl_spreadh,y
    sta cr_xh,y
    lda #GROUND_Y
    sta cr_y,y
    lda #CS_GROUND
    sta cr_st,y
    lda M_RND
    and #1
    sta cr_dir,y
    lda M_RND
    ora #$40
    sta cr_tm,y
    lda cr_t,y
    cmp #CK_GLIDE+1
    bne pl_new_g
    lda #GLIDE_Y
    sta cr_y,y
    lda #CS_AIR
    sta cr_st,y
pl_new_g
    dey
    bpl pl_new_cr
    ; ore crates
    ldy #NCK-1
pl_new_k
    lda #CS_GROUND+1
    sta ck_st,y
    lda M_RND
    sta ck_xl,y
    lda M_RND
    and #3
    sta ck_xh,y
    lda #GROUND_Y
    sta ck_y,y
    dey
    bpl pl_new_k
    ; turrets: towers at 256 and 768
    lda #0
    sta tt_xl
    sta tt_xl+1
    lda #1
    sta tt_xh
    lda #3
    sta tt_xh+1
    lda #120
    sta tt_y
    lda #100
    sta tt_y+1
    lda #60
    sta tt_cool
    sta tt_cool+1
    jsr pl_camera
    lda #MUS_TITLE          ; (the Arc theme, for now)
    jsr mu_switch
    lda #<tx_planet
    ldy #>tx_planet
    ldx #6
    jsr sp_msgcopy
    lda #120
    sta pl_msgtm
    rts

; quarters of the planet (x 0-1023) for the creatures, lo and hi
pl_spread  .byte $80, $40, $C0, $00
pl_spreadh .byte 0, 1, 2, 3

; ---------------------------------------------------------------------------
pl_frame
    inc pl_tick
    lda pl_msgtm
    beq pl_fr_m
    dec pl_msgtm
    bne pl_fr_m
    lda #0
    sta sp_msglen
pl_fr_m
    lda pl_state
    beq pl_fr_play
    ; over: let it run a moment, then done
    cmp #PL_DONE
    beq pl_fr_r
    dec pl_endtm
    bne pl_fr_idle
    lda #PL_DONE
    sta pl_state
pl_fr_idle
    jsr pl_camera
    jsr pl_creatures
    jsr pl_screen
    jmp pl_hud
pl_fr_r
    rts
pl_fr_play
    jsr pl_clock
    jsr pl_shuttle
    jsr pl_camera
    jsr pl_creatures
    jsr pl_crates
    jsr pl_turrets
    jsr pl_screen
    jsr pl_shots
    jsr pl_beamwork
    jsr pl_pulsework
    jsr pl_checkall
    jmp pl_hud

; ---- the clock ----
pl_clock
    dec pl_sub
    bne pl_ck_r
    lda #60
    sta pl_sub
    dec pl_secs
    bne pl_ck_k
    ; time's up
    lda #PL_TIMEUP
    sta pl_state
    lda #150
    sta pl_endtm
    lda #0
    sta pl_beam
    lda pl_st
    cmp #PL_FLYING
    bne pl_ck_tu
    jsr pl_drop             ; the shuttle's still out: what it held is lost,
    lda #LOST_DMG           ; and it costs the Ark
    jsr pl_arkdmg
pl_ck_tu
    lda #<tx_timeup
    ldy #>tx_timeup
    ldx #7
    jsr sp_msgcopy
    lda #0
    sta pl_msgtm
    rts
pl_ck_k
    lda pl_secs
    cmp #PL_KLAXON+1
    bcs pl_ck_r
    lda #SFX_KLAXON         ; the klaxon, each second
    jsr sfx
    lda pl_secs
    cmp #PL_KLAXON
    bne pl_ck_r
    lda #<tx_warning
    ldy #>tx_warning
    ldx #7
    jsr sp_msgcopy
    lda #90
    sta pl_msgtm
pl_ck_r
    rts

; ---- the shuttle ----
pl_shuttle
    lda pl_hit
    beq pl_sh_h
    dec pl_hit
pl_sh_h
    ldx sp_joy
    ; across: accelerate the stick's way, or slow down
    cpx #8
    bcs pl_sh_slow
    lda pl_across,x
    beq pl_sh_slow
    bmi pl_sh_left
    clc
    lda pl_vxl
    adc #PL_ACC
    sta pl_vxl
    lda pl_vxh
    adc #0
    sta pl_vxh
    jmp pl_sh_clamp
pl_sh_left
    sec
    lda pl_vxl
    sbc #PL_ACC
    sta pl_vxl
    lda pl_vxh
    sbc #0
    sta pl_vxh
    jmp pl_sh_clamp
pl_sh_slow
    lda pl_vxl              ; v -= v/8 (arithmetic shifts)
    sta pl_t0
    lda pl_vxh
    sta pl_t1
    ldy #3
pl_sh_s8
    lda pl_t1
    cmp #$80
    ror pl_t1
    ror pl_t0
    dey
    bne pl_sh_s8
    sec
    lda pl_vxl
    sbc pl_t0
    sta pl_vxl
    lda pl_vxh
    sbc pl_t1
    sta pl_vxh
    ; (tiny speeds stop)
    lda pl_vxh
    bne pl_sh_clamp
    lda pl_vxl
    cmp #8
    bcs pl_sh_clamp
    lda #0
    sta pl_vxl
pl_sh_clamp
    lda pl_vxh
    bmi pl_sh_cn
    cmp #>PL_VMAX
    bcc pl_sh_mv
    lda #<PL_VMAX
    sta pl_vxl
    lda #>PL_VMAX
    sta pl_vxh
    jmp pl_sh_mv
pl_sh_cn
    cmp #$FE                ; (-PL_VMAX: $FE00)
    bcs pl_sh_mv
    lda #$00
    sta pl_vxl
    lda #$FE
    sta pl_vxh
pl_sh_mv
    clc
    lda pl_wxf
    adc pl_vxl
    sta pl_wxf
    lda pl_wx
    adc pl_vxh
    sta pl_wx
    lda pl_vxh
    and #$80
    beq pl_sh_mp
    lda #$FF
pl_sh_mp
    adc pl_wxh
    and #3
    sta pl_wxh
    ; up and down
    ldx sp_joy
    cpx #8
    bcs pl_sh_r
    lda pl_updown,x
    beq pl_sh_r
    bmi pl_sh_up
    ; down: out of the bay, and down to just above the ground
    lda #PL_FLYING
    sta pl_st
    lda pl_y
    cmp #PL_YMAX
    bcs pl_sh_r
    inc pl_y
    rts
pl_sh_up
    lda pl_st
    cmp #PL_FLYING
    bne pl_sh_r
    lda pl_hold             ; a crate's heavy: half speed up
    cmp #HOLD_ORE
    bne pl_sh_u1
    inc pl_yh
    lda pl_yh
    and #1
    beq pl_sh_r
pl_sh_u1
    dec pl_y
    lda pl_y
    cmp #PL_DOCKY+1
    bcs pl_sh_r
    ; into the bay: docked, and hand over the cargo
    lda #PL_DOCKY
    sta pl_y
    lda #PL_DOCKED
    sta pl_st
    jmp pl_deliver
pl_sh_r
    rts

; per joystick direction (0 up, clockwise): across (-1, 0, 1), up/down (-1 up)
pl_across  .byte 0, 1, 1, 1, 0, -1, -1, -1
pl_updown  .byte -1, -1, 0, 1, 1, 1, 0, -1

pl_deliver
    lda pl_hold
    beq pl_dv_r
    cmp #HOLD_CR
    bne pl_dv_ore
    ldx pl_holdi
    lda #0
    sta cr_t,x
    inc pl_caught
    clc
    lda sp_energy
    adc #CR_PAY
    cmp #EN_MAX
    bcc pl_dv_e
    lda #EN_MAX
pl_dv_e
    sta sp_energy
    lda #$05                ; 500 points
    sta sc_m
    lda #$00
    sta sc_l
    jmp pl_dv_done
pl_dv_ore
    ldx pl_holdi
    lda #0
    sta ck_st,x
    inc pl_ore
    lda #$02                ; 200 points
    sta sc_m
    lda #$00
    sta sc_l
pl_dv_done
    jsr sc_add
    lda #HOLD_NONE
    sta pl_hold
    lda #SFX_DELIVER
    jmp sfx
pl_dv_r
    rts

; ---- the camera: cam = shuttle - 80; the ground's scroll ----
pl_camera
    sec
    lda pl_wx
    sbc #80
    sta pl_cam
    lda pl_wxh
    sbc #0
    and #3
    sta pl_camh
    ; map column = cam / 8, fine = cam & 7 -> the ground's x = -fine
    lda pl_camh
    sta pl_t0
    lda pl_cam
    lsr pl_t0
    ror
    lsr pl_t0
    ror
    lsr pl_t0
    ror
    sta pl_col
    lda pl_cam
    and #7
    eor #$FF
    clc
    adc #1
    sta pl_fine
    rts

; world x (A lo, Y hi) -> C = 1 and A = screen x if it's on the screen (an
; 8-wide thing, half off the left allowed)
pl_scrx
    sec
    sbc pl_cam
    sta pl_t2
    tya
    sbc pl_camh
    and #3
    beq pl_sx_lo
    cmp #3
    bne pl_sx_no
    lda pl_t2
    cmp #248
    bcc pl_sx_no
    sec
    rts
pl_sx_lo
    lda pl_t2
    cmp #160
    bcs pl_sx_no
    sec
    rts
pl_sx_no
    clc
    rts

; every thing's screen x this frame
pl_screen
    ldx #NCR-1
pl_sc_c
    lda #0
    sta cr_vis,x
    lda cr_t,x
    beq pl_sc_cn
    lda cr_st,x
    cmp #CS_HIDE
    beq pl_sc_cn
    cmp #CS_HELD
    beq pl_sc_cn
    ldy cr_xh,x
    lda cr_xl,x
    jsr pl_scrx
    bcc pl_sc_cn
    sta cr_sx,x
    inc cr_vis,x
pl_sc_cn
    dex
    bpl pl_sc_c
    ldx #NCK-1
pl_sc_k
    lda #0
    sta ck_vis,x
    lda ck_st,x
    beq pl_sc_kn
    cmp #CS_HELD+1
    beq pl_sc_kn
    ldy ck_xh,x
    lda ck_xl,x
    jsr pl_scrx
    bcc pl_sc_kn
    sta ck_sx,x
    inc ck_vis,x
pl_sc_kn
    dex
    bpl pl_sc_k
    ldx #NTT-1
pl_sc_t
    lda #0
    sta tt_vis,x
    ldy tt_xh,x
    lda tt_xl,x
    jsr pl_scrx
    bcc pl_sc_tn
    sta tt_sx,x
    inc tt_vis,x
pl_sc_tn
    dex
    bpl pl_sc_t
    ldx #NTS-1
pl_sc_s
    lda #0
    sta ts_vis,x
    lda ts_t,x
    beq pl_sc_sn
    ldy ts_xh,x
    lda ts_xl,x
    jsr pl_scrx
    bcc pl_sc_sn
    sta ts_sx,x
    inc ts_vis,x
pl_sc_sn
    dex
    bpl pl_sc_s
    rts

; ---- creatures ----
pl_creatures
    ldx #NCR-1
pl_cr_l
    stx pl_i
    lda cr_t,x
    bne pl_cr_go
    jmp pl_cr_n
pl_cr_go
    lda cr_stun,x
    beq pl_cr_ns
    dec cr_stun,x
pl_cr_ns
    lda cr_st,x
    cmp #CS_LIFT
    bne pl_cr_nl
    jmp pl_cr_n             ; (the beam moves it: pl_beamwork)
pl_cr_nl
    cmp #CS_HELD
    bne pl_cr_nh
    jmp pl_cr_n
pl_cr_nh
    cmp #CS_AIR
    bne pl_cr_ground
    ; in the air: a glider glides; anything else falls
    lda cr_t,x
    cmp #CK_GLIDE+1
    bne pl_cr_fall
    lda cr_stun,x
    bne pl_cr_gn
    jsr pl_walk             ; across, 0.75 a frame (twice: see pl_walk)
    jsr pl_walk
    ldx pl_i
pl_cr_gn
    jmp pl_cr_n
pl_cr_fall
    clc
    lda cr_vyl,x
    adc #$20                ; gravity (a hop: ~44 frames, ~30 lines up)
    sta cr_vyl,x
    lda cr_vyh,x
    adc #0
    sta cr_vyh,x
    clc
    lda cr_yf,x
    adc cr_vyl,x
    sta cr_yf,x
    lda cr_y,x
    adc cr_vyh,x
    sta cr_y,x
    cmp #GROUND_Y
    bcc pl_cr_air
    lda #GROUND_Y           ; landed
    sta cr_y,x
    lda #CS_GROUND
    sta cr_st,x
pl_cr_air
    lda cr_t,x              ; a hopper keeps moving across in its jump
    cmp #CK_HOP+1
    bne pl_cr_an
    jsr pl_walk
    ldx pl_i
pl_cr_an
    jmp pl_cr_n
pl_cr_ground
    cmp #CS_HIDE
    bne pl_cr_gr
    ; hidden (burrowed, blinked out): come back after a while
    lda cr_stun,x
    bne pl_cr_up            ; (a stun brings it up at once)
    dec cr_tm,x
    beq pl_cr_up
    jmp pl_cr_n
pl_cr_up
    lda #CS_GROUND
    sta cr_st,x
    lda #120
    sta cr_tm,x
    lda cr_t,x
    cmp #CK_BLINK+1
    bne pl_cr_un
    ; a blinker comes back up to 64 pixels away
    lda M_RND
    and #$7F
    sec
    sbc #$40
    clc
    adc cr_xl,x
    sta cr_xl,x
    lda #0
    bcc pl_cr_bx
    lda #1
pl_cr_bx
    adc cr_xh,x
    and #3
    sta cr_xh,x
pl_cr_un
    jmp pl_cr_n
pl_cr_gr
    ; on the ground: stunned ones stand still
    lda cr_stun,x
    beq pl_cr_move
    jmp pl_cr_n
pl_cr_move
    ; a runner near the shuttle (with its beam on, or low) runs
    lda cr_t,x
    cmp #CK_RUN+1
    bne pl_cr_walk
    lda cr_fast,x
    beq pl_cr_rn
    dec cr_fast,x
    jsr pl_walk
    jsr pl_walk
    jsr pl_walk
    ldx pl_i
    jmp pl_cr_tm
pl_cr_rn
    lda cr_vis,x
    beq pl_cr_walk
    lda pl_beam
    bne pl_cr_rchk
    lda pl_y
    cmp #110
    bcc pl_cr_walk
pl_cr_rchk
    lda cr_sx,x
    clc
    adc #4
    sec
    sbc #80
    bcs pl_cr_rd
    eor #$FF
    adc #1
pl_cr_rd
    cmp #48
    bcs pl_cr_walk
    ; run: away from the shuttle
    lda #0
    ldy cr_sx,x
    cpy #76
    bcs pl_cr_rr
    lda #1
pl_cr_rr
    sta cr_dir,x
    lda #40
    sta cr_fast,x
pl_cr_walk
    jsr pl_walk
    ldx pl_i
pl_cr_tm
    ; its own timer: turn, hop, burrow, blink
    dec cr_tm,x
    bne pl_cr_n
    lda M_RND
    ora #$40
    sta cr_tm,x
    lda cr_t,x
    cmp #CK_HOP+1
    bne pl_cr_t2
    lda #$FD                ; a hop: up at 2.75 lines a frame
    sta cr_vyh,x
    lda #$40
    sta cr_vyl,x
    lda #CS_AIR
    sta cr_st,x
    lda #60
    sta cr_tm,x
    jmp pl_cr_n
pl_cr_t2
    cmp #CK_BURROW+1
    beq pl_cr_hide
    cmp #CK_BLINK+1
    bne pl_cr_turn
pl_cr_hide
    lda #CS_HIDE
    sta cr_st,x
    lda #90
    sta cr_tm,x
    jmp pl_cr_n
pl_cr_turn
    lda cr_dir,x
    eor #1
    sta cr_dir,x
pl_cr_n
    ldx pl_i
    dex
    bmi pl_cr_r
    jmp pl_cr_l
pl_cr_r
    rts

; creature X walks: 3/8 of a pixel a frame its way (call it again to go faster)
pl_walk
    lda cr_dir,x
    bne pl_wk_l
    clc
    lda cr_xf,x
    adc #$60
    sta cr_xf,x
    lda cr_xl,x
    adc #0
    sta cr_xl,x
    lda cr_xh,x
    adc #0
    and #3
    sta cr_xh,x
    rts
pl_wk_l
    sec
    lda cr_xf,x
    sbc #$60
    sta cr_xf,x
    lda cr_xl,x
    sbc #0
    sta cr_xl,x
    lda cr_xh,x
    sbc #0
    and #3
    sta cr_xh,x
    rts

; ---- crates (they only fall, if dropped) ----
pl_crates
    ldx #NCK-1
pl_ck_l
    lda ck_st,x
    cmp #CS_AIR+1
    bne pl_ck_n
    inc ck_y,x              ; falling
    inc ck_y,x
    lda ck_y,x
    cmp #GROUND_Y
    bcc pl_ck_n
    lda #GROUND_Y
    sta ck_y,x
    lda #CS_GROUND+1
    sta ck_st,x
pl_ck_n
    dex
    bpl pl_ck_l
    rts

; ---- turrets: up and down their towers; a shot at the shuttle ----
pl_turrets
    ldx #NTT-1
pl_tt_l
    stx pl_i
    lda tt_frz,x
    beq pl_tt_go
    dec tt_frz,x
    jmp pl_tt_n
pl_tt_go
    lda pl_tick
    and #1
    bne pl_tt_f
    lda tt_dir,x
    bne pl_tt_up
    inc tt_y,x
    lda tt_y,x
    cmp #140
    bcc pl_tt_f
    inc tt_dir,x
    bne pl_tt_f
pl_tt_up
    dec tt_y,x
    lda tt_y,x
    cmp #96
    bcs pl_tt_f
    lda #0
    sta tt_dir,x
pl_tt_f
    lda tt_cool,x
    beq pl_tt_shoot
    dec tt_cool,x
    jmp pl_tt_n
pl_tt_shoot
    lda pl_st
    cmp #PL_FLYING
    beq pl_tt_n_far947
    jmp pl_tt_n
pl_tt_n_far947
    ldy tt_xh,x
    lda tt_xl,x
    jsr pl_scrx
    bcs pl_tt_n_far951
    jmp pl_tt_n
pl_tt_n_far951
    sta pl_t0               ; its screen x
    clc
    adc #4
    sec
    sbc #80
    bcs pl_tt_dx
    eor #$FF
    adc #1
pl_tt_dx
    cmp #TT_RANGE
    bcc pl_tt_n_far962
    jmp pl_tt_n
pl_tt_n_far962
    ldx pl_i
    lda M_RND
    and #63
    clc
    adc #TT_GAP
    sta tt_cool,x
    ; a shot from the turret's top at the shuttle
    ldy #NTS-1
pl_tt_sl
    lda ts_t,y
    beq pl_tt_sg
    dey
    bpl pl_tt_sl
    jmp pl_tt_n
pl_tt_sg
    sty pl_t1
    lda #1
    sta ts_t,y
    lda tt_xl,x
    clc
    adc #2
    sta ts_xl,y
    lda tt_xh,x
    adc #0
    and #3
    sta ts_xh,y
    lda tt_y,x
    sta ts_y,y
    lda #0
    sta ts_xf,y
    sta ts_yf,y
    lda pl_t0
    clc
    adc #4
    sta v_t0
    lda tt_y,x
    sta v_t1
    lda #80
    sta v_t2
    lda pl_y
    sta v_t3
    jsr vec_angle
    sta pl_t2               ; the aim strays a little
    lda M_RND
    and #TT_SPREAD
    sec
    sbc #TT_SPREAD/2
    clc
    adc pl_t2
    pha
    lda #<TS_SPEED
    sta v_t0
    lda #>TS_SPEED
    sta v_t1
    pla
    jsr vec_rot
    ldy pl_t1
    lda vx_l
    sta ts_vxl,y
    lda vx_h
    sta ts_vxh,y
    lda vy_l
    sta ts_vyl,y
    lda vy_h
    sta ts_vyh,y
    lda #SFX_PSHOT
    jsr sfx
pl_tt_n
    ldx pl_i
    dex
    bmi pl_tt_r
    jmp pl_tt_l
pl_tt_r
    rts

; ---- turret shots: move; hit the shuttle ----
pl_shots
    ldx #NTS-1
pl_ts_l
    lda ts_t,x
    bne pl_ts_go
    jmp pl_ts_n
pl_ts_go
    clc
    lda ts_xf,x
    adc ts_vxl,x
    sta ts_xf,x
    lda ts_xl,x
    adc ts_vxh,x
    sta ts_xl,x
    lda ts_vxh,x
    and #$80
    beq pl_ts_p
    lda #$FF
pl_ts_p
    adc ts_xh,x
    and #3
    sta ts_xh,x
    clc
    lda ts_yf,x
    adc ts_vyl,x
    sta ts_yf,x
    lda ts_y,x
    adc ts_vyh,x
    sta ts_y,x
    cmp #24
    bcc pl_ts_k
    cmp #160
    bcs pl_ts_k
    ; off the screen across: gone
    ldy ts_xh,x
    lda ts_xl,x
    stx pl_i
    jsr pl_scrx
    ldx pl_i
    bcc pl_ts_k
    ; the shuttle (centre 80, pl_y): +-5 across, +-4 down
    clc
    adc #2
    sec
    sbc #80
    bcs pl_ts_dx
    eor #$FF
    adc #1
pl_ts_dx
    cmp #6
    bcs pl_ts_n
    lda pl_st
    cmp #PL_FLYING
    bne pl_ts_n
    lda ts_y,x
    clc
    adc #2
    sec
    sbc pl_y
    bcs pl_ts_dy
    eor #$FF
    adc #1
pl_ts_dy
    cmp #5
    bcs pl_ts_n
    lda pl_hit
    bne pl_ts_k
    ; hit: the cargo's knocked loose, and it costs the Ark
    lda #60
    sta pl_hit
    stx pl_i
    jsr pl_drop
    lda #TS_DMG
    jsr pl_arkdmg
    ldx pl_i
pl_ts_k
    lda #0
    sta ts_t,x
pl_ts_n
    dex
    bmi pl_ts_r
    jmp pl_ts_l
pl_ts_r
    rts

; the Ark takes A (no lower than 1: the planet can't end the game)
pl_arkdmg
    sta pl_t0
    sec
    lda sp_energy
    sbc pl_t0
    bcc pl_ad_1
    bne pl_ad_e
pl_ad_1
    lda #1
pl_ad_e
    sta sp_energy
    lda #SFX_HIT
    jmp sfx

; whatever the shuttle holds or is lifting falls
pl_drop
    lda pl_hold
    beq pl_dp_lift
    ldx pl_holdi
    cmp #HOLD_CR
    bne pl_dp_ore
    lda #CS_AIR
    sta cr_st,x
    lda #0
    sta cr_vyl,x
    sta cr_vyh,x
    lda pl_y
    clc
    adc #4
    sta cr_y,x
    jsr pl_under_cr
    jmp pl_dp_none
pl_dp_ore
    lda #CS_AIR+1
    sta ck_st,x
    lda pl_y
    clc
    adc #4
    sta ck_y,x
    jsr pl_under_ck
pl_dp_none
    lda #HOLD_NONE
    sta pl_hold
pl_dp_lift
    ; anything in the beam drops too
    ldx #NCR-1
pl_dp_c
    lda cr_st,x
    cmp #CS_LIFT
    bne pl_dp_cn
    lda #CS_AIR
    sta cr_st,x
    lda #0
    sta cr_vyl,x
    sta cr_vyh,x
pl_dp_cn
    dex
    bpl pl_dp_c
    ldx #NCK-1
pl_dp_k
    lda ck_st,x
    cmp #CS_LIFT+1
    bne pl_dp_kn
    lda #CS_AIR+1
    sta ck_st,x
pl_dp_kn
    dex
    bpl pl_dp_k
    rts

; creature / crate X goes under the shuttle (world x = shuttle - 4)
pl_under_cr
    sec
    lda pl_wx
    sbc #4
    sta cr_xl,x
    lda pl_wxh
    sbc #0
    and #3
    sta cr_xh,x
    rts
pl_under_ck
    sec
    lda pl_wx
    sbc #4
    sta ck_xl,x
    lda pl_wxh
    sbc #0
    and #3
    sta ck_xh,x
    rts

; ---- the tractor beam ----
pl_beamwork
    lda #0
    sta pl_beam
    lda sp_fire
    bne pl_bw_off_far1215
    jmp pl_bw_off
pl_bw_off_far1215
    lda pl_st
    cmp #PL_FLYING
    beq pl_bw_off_far1218
    jmp pl_bw_off
pl_bw_off_far1218
    lda pl_hold
    beq pl_bw_off_far1220
    jmp pl_bw_off
pl_bw_off_far1220
    inc pl_beam
    lda pl_tick
    and #15
    bne pl_bw_go
    lda #SFX_BEAM
    jsr sfx
pl_bw_go
    ; creatures: take one under the beam; lift what's in it
    ldx #NCR-1
pl_bw_c
    lda cr_t,x
    beq pl_bw_cn
    lda cr_st,x
    cmp #CS_LIFT
    beq pl_bw_lift
    cmp #CS_HIDE
    beq pl_bw_cn
    cmp #CS_HELD
    beq pl_bw_cn
    lda cr_vis,x
    beq pl_bw_cn
    lda cr_y,x
    cmp pl_y
    bcc pl_bw_cn            ; above the shuttle
    lda cr_sx,x
    clc
    adc #4
    sec
    sbc #80
    bcs pl_bw_dx
    eor #$FF
    adc #1
pl_bw_dx
    cmp #BEAM_HALF+1
    bcs pl_bw_cn
    lda #CS_LIFT
    sta cr_st,x
    jsr pl_under_cr
pl_bw_lift
    jsr pl_under_cr         ; it comes along under the shuttle
    lda cr_y,x
    sec
    sbc #PL_LIFT
    sta cr_y,x
    sec
    sbc pl_y
    cmp #5
    bcs pl_bw_cn
    ; in: the shuttle holds it
    lda #CS_HELD
    sta cr_st,x
    stx pl_holdi
    lda #HOLD_CR
    sta pl_hold
    lda #SFX_CAPTURE
    jmp sfx
pl_bw_cn
    dex
    bpl pl_bw_c
    ; crates, the same, at half speed
    ldx #NCK-1
pl_bw_k
    lda ck_st,x
    beq pl_bw_kn
    cmp #CS_LIFT+1
    beq pl_bw_klift
    cmp #CS_HELD+1
    beq pl_bw_kn
    lda ck_vis,x
    beq pl_bw_kn
    lda ck_sx,x
    clc
    adc #4
    sec
    sbc #80
    bcs pl_bw_kx
    eor #$FF
    adc #1
pl_bw_kx
    cmp #BEAM_HALF+1
    bcs pl_bw_kn
    lda #CS_LIFT+1
    sta ck_st,x
pl_bw_klift
    jsr pl_under_ck
    lda pl_tick
    and #1
    bne pl_bw_kn
    dec ck_y,x
    lda ck_y,x
    sec
    sbc pl_y
    cmp #5
    bcs pl_bw_kn
    lda #CS_HELD+1
    sta ck_st,x
    stx pl_holdi
    lda #HOLD_ORE
    sta pl_hold
    lda #SFX_CAPTURE
    jmp sfx
pl_bw_kn
    dex
    bpl pl_bw_k
    rts
pl_bw_off
    ; no beam: anything rising in it drops
    ldx #NCR-1
pl_bo_c
    lda cr_st,x
    cmp #CS_LIFT
    bne pl_bo_cn
    lda #CS_AIR
    sta cr_st,x
    lda #0
    sta cr_vyl,x
    sta cr_vyh,x
pl_bo_cn
    dex
    bpl pl_bo_c
    ldx #NCK-1
pl_bo_k
    lda ck_st,x
    cmp #CS_LIFT+1
    bne pl_bo_kn
    lda #CS_AIR+1
    sta ck_st,x
pl_bo_kn
    dex
    bpl pl_bo_k
    rts

; ---- the stun pulse ----
pl_pulsework
    lda pl_pulse
    beq pl_pw_s
    dec pl_pulse
pl_pw_s
    lda pl_stun
    beq pl_pw_b
    dec pl_stun
pl_pw_b
    lda sp_fire2
    tax
    eor pl_f2old            ; pressed this frame?
    and sp_fire2
    stx pl_f2old
    beq pl_pw_r
    lda pl_stun
    bne pl_pw_r
    lda pl_st
    cmp #PL_FLYING
    bne pl_pw_r
    lda #PL_STUNCD
    sta pl_stun
    lda #12
    sta pl_pulse
    lda #SFX_STUN
    jsr sfx
    ; creatures in reach
    ldx #NCR-1
pl_pw_c
    lda cr_vis,x
    beq pl_pw_cn
    lda cr_sx,x
    clc
    adc #4
    jsr pl_near
    bcs pl_pw_cn
    lda cr_y,x
    jsr pl_neary
    bcs pl_pw_cn
    lda #CR_STUN
    sta cr_stun,x
pl_pw_cn
    dex
    bpl pl_pw_c
    ; turrets
    ldx #NTT-1
pl_pw_t
    lda tt_vis,x
    beq pl_pw_tn
    lda tt_sx,x
    clc
    adc #4
    jsr pl_near
    bcs pl_pw_tn
    lda tt_y,x
    jsr pl_neary
    bcs pl_pw_tn
    lda #TT_FREEZE
    sta tt_frz,x
pl_pw_tn
    dex
    bpl pl_pw_t
pl_pw_r
    rts

; C = 0: screen x A is within PL_STUNR of the shuttle (80)
pl_near
    sec
    sbc #80
    bcs pl_nr_p
    eor #$FF
    adc #1
pl_nr_p
    cmp #PL_STUNR
    rts
; C = 0: line A is within PL_STUNR of the shuttle
pl_neary
    sec
    sbc pl_y
    bcs pl_ny_p
    eor #$FF
    adc #1
pl_ny_p
    cmp #PL_STUNR
    rts

; ---- every creature delivered: the planet's clear ----
pl_checkall
    lda pl_caught
    cmp pl_total
    bne pl_ca_r
    lda #PL_CLEAR
    sta pl_state
    lda #180
    sta pl_endtm
    lda #EN_MAX             ; the Ark's energy full again (as in the original)
    sta sp_energy
    lda #$10                ; 1000 points
    sta sc_m
    lda #0
    sta sc_l
    jsr sc_add
    lda #SFX_CLEAR
    jsr sfx
    lda #<tx_pclear
    ldy #>tx_pclear
    ldx #12
    jsr sp_msgcopy
    lda #0
    sta pl_msgtm
pl_ca_r
    rts

; ---- the HUD ----
;   top:    "000000  TIME 45  2/4"
;   bottom: "A" + the Ark's energy  |  "HOLD BEAST" / "HOLD  ORE " / "HOLD  ----"
pl_hud
    ldy #0
    ldx #0
pl_hd_sc
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
    bne pl_hd_sc
    ldx #0
pl_hd_t
    lda tx_ptime,x
    sta hud_top,y
    iny
    inx
    cpx #7
    bne pl_hd_t
    ; seconds: two digits (the math unit divides by 10)
    lda pl_secs
    sta M_N
    lda #0
    sta M_N+1
    sta M_N+2
    sta M_N+3
    sta M_D+1
    sta M_CTRL
    lda #10
    sta M_D
    lda M_Q
    jsr tx_digit
    sta hud_top,y
    iny
    lda M_R
    jsr tx_digit
    sta hud_top,y
    iny
    lda #0
    sta hud_top,y
    iny
    sta hud_top,y
    iny
    lda pl_caught
    jsr tx_digit
    sta hud_top,y
    iny
    lda #("/"-32)*2
    sta hud_top,y
    iny
    lda pl_total
    jsr tx_digit
    sta hud_top,y
    ; bottom
    lda #<hud_bot
    sta hwp
    lda #>hud_bot
    sta hwp+1
    lda #("A"-32)*2
    ldx sp_energy
    jsr hud_bar
    ldx pl_hold
    lda pl_holdtx,x
    tax
    ldy #9
pl_hd_hold
    lda tx_hold,x
    sta hud_bot2,y
    dex
    dey
    bpl pl_hd_hold
    rts

pl_holdtx .byte 9, 19, 29       ; the last character of each in tx_hold

; ---------------------------------------------------------------------------
; Drawing (the BASIC has drawn the Ark and the ground): towers, turrets,
; crates, creatures, the beam, the shuttle, shots, the pulse, the scanner.
pl_draw
    ; towers: 4 segments, y 96-159, then their turrets
    ldx #NTT-1
pl_dw_t
    stx pl_i
    lda tt_vis,x
    beq pl_dw_tn
    lda tt_sx,x
    sta temp4
    lda #96
    sta pl_t0
pl_dw_seg
    lda pl_t0
    sta temp5
    lda #0
    PLOT tower, 4
    ldx pl_i
    lda tt_sx,x
    sta temp4
    clc
    lda pl_t0
    adc #16
    sta pl_t0
    cmp #160
    bcc pl_dw_seg
    lda tt_y,x
    sta temp5
    lda tt_frz,x            ; frozen: it blinks
    beq pl_dw_tt
    lda pl_tick
    and #4
    bne pl_dw_tn
pl_dw_tt
    lda #0
    PLOT turret, 4
pl_dw_tn
    ldx pl_i
    dex
    bpl pl_dw_t

    ; crates
    ldx #NCK-1
pl_dw_k
    stx pl_i
    lda ck_vis,x
    beq pl_dw_kn
    lda ck_sx,x
    sta temp4
    lda ck_y,x
    sta temp5
    lda #0
    PLOT crate, 5
pl_dw_kn
    ldx pl_i
    dex
    bpl pl_dw_k

    ; creatures: kind * 4 + facing * 2 + step; two bytes a frame
    ldx #NCR-1
pl_dw_c
    stx pl_i
    lda cr_vis,x
    beq pl_dw_cn
    lda cr_stun,x           ; stunned: it blinks
    beq pl_dw_cv
    lda pl_tick
    and #8
    bne pl_dw_cn
pl_dw_cv
    lda cr_sx,x
    sta temp4
    lda cr_y,x
    sta temp5
    lda cr_t,x
    sec
    sbc #1
    asl
    asl
    sta pl_t0
    lda cr_dir,x
    asl
    ora pl_t0
    sta pl_t0
    lda pl_tick
    lsr
    lsr
    lsr
    and #1
    ora pl_t0
    asl
    PLOT creature00, 2
pl_dw_cn
    ldx pl_i
    dex
    bpl pl_dw_c

    ; the beam: 16-line segments from the shuttle down to the ground
    lda pl_beam
    beq pl_dw_nob
    lda pl_y
    clc
    adc #4
    sta pl_t0
pl_dw_bs
    lda #76
    sta temp4
    lda pl_t0
    sta temp5
    lda pl_tick
    and #2                  ; (frame 0 or 1, two bytes wide)
    PLOT beam0, 3
    clc
    lda pl_t0
    adc #16
    sta pl_t0
    cmp #146                ; (the last one reaches the ground's surface)
    bcc pl_dw_bs
pl_dw_nob

    ; the shuttle (blinks for a moment after a hit)
    lda pl_hit
    and #4
    bne pl_dw_ns
    lda #76
    sta temp4
    sec
    lda pl_y
    sbc #3
    sta temp5
    lda pl_tick
    lsr
    and #6
    PLOT saucer0, 6
pl_dw_ns

    ; turret shots
    ldx #NTS-1
pl_dw_s
    stx pl_i
    lda ts_vis,x
    beq pl_dw_sn
    lda ts_sx,x
    sta temp4
    lda ts_y,x
    sta temp5
    lda #0
    PLOT dot, 4
pl_dw_sn
    ldx pl_i
    dex
    bpl pl_dw_s

    ; the stun pulse
    lda pl_pulse
    beq pl_dw_np
    lda #72
    sta temp4
    sec
    lda pl_y
    sbc #8
    sta temp5
    lda #0
    PLOT ring, 3
pl_dw_np

    ; the scanner (row 1): the whole planet in 128 pixels from x 16
    lda pl_wx
    ldy pl_wxh
    jsr pl_scan
    lda #17
    sta temp5
    lda #0
    PLOT dot, 6
    ldx #NCR-1
pl_dw_sc
    stx pl_i
    lda cr_t,x
    beq pl_dw_scn
    lda cr_st,x
    cmp #CS_HIDE
    beq pl_dw_scn
    cmp #CS_HELD
    beq pl_dw_scn
    lda cr_xl,x
    ldy cr_xh,x
    jsr pl_scan
    lda #22
    sta temp5
    lda #0
    PLOT dot, 2
pl_dw_scn
    ldx pl_i
    dex
    bpl pl_dw_sc
    ldx #NTT-1
pl_dw_st
    stx pl_i
    lda tt_xl,x
    ldy tt_xh,x
    jsr pl_scan
    lda #24
    sta temp5
    lda #0
    PLOT dot, 4
    ldx pl_i
    dex
    bpl pl_dw_st
    rts

; world x (A lo, Y hi) -> temp4 = its place on the scanner (x / 8 + 16)
pl_scan
    sta pl_t0
    sty pl_t1
    lsr pl_t1
    ror pl_t0
    lsr pl_t1
    ror pl_t0
    lsr pl_t1
    ror pl_t0
    clc
    lda pl_t0
    adc #16
    sta temp4
    rts

