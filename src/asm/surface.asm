; ===========================================================================
; The planet (M3): Cosmic Arc's surface run, on a horizontally scrolling
; planet that wraps round (1024 pixels: tools/planet.py).
;
; The Ark hangs in orbit over one spot of the planet (it doesn't follow:
; the shuttle has to come back to it). The shuttle (the saucer) sits at the
; screen's centre across: the ground scrolls under it. Down launches it
; from the Ark; under the Ark it flies up into it to dock and hand over what
; it carries. It can't climb to the Ark's height anywhere else.
;   button 1  the tractor beam: the shuttle stops dead, and a creature (or
;             ore crate) under it rises, slowly, while the beam holds; a
;             creature struggles, and one that wriggles out of the beam drops
;   button 2  the stun pulse: creatures and turrets near the shuttle freeze;
;             a stunned creature neither reacts nor struggles
; Creatures react to a low shuttle overhead: the walker turns about at
; random, the hopper jumps away, the runner sprints, the burrower digs in,
; the glider bobs, and the blinker teleports when the beam touches it.
; Turrets: a tower every 128 pixels (one's always in view); they shoot at
; the shuttle: a hit destroys it (its cargo falls) and costs the Ark energy;
; the Ark launches another. The clock: 60 s; at 15 the klaxon; at 0, time's
; up (a shuttle still out is lost, at a cost). Every creature delivered:
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
PL_TIME   = 45      ; seconds until the storm (as Cosmic Arc's: the klaxon,
                    ;   then a rock comes at the Ark: be back aboard)
STORM_DELAY = 150   ; 4-frame steps from the klaxon to the rock (10 s: back
                    ;   to the Ark from anywhere: the far side is 512 px, 4.3 s)
ROCK_DMG  = 16      ; the rock hitting the Ark costs this
ROCK_SPD0 = $0080   ; the rock's speed (8.8 px a frame across; down, half
ROCK_SPDL = $20     ;   that in lines): 1/2 + 1/8 a level, at most 1. At
ROCK_SPDMAX = $0100 ;   level 0 it's in sight about 2 s each way.
AB_LIFE   = 40      ; frames an Ark bolt lasts
PL_ACC    = $20     ; shuttle acceleration across (8.8 pixels a frame)
PL_VMAX   = $0200   ; top speed across
BEAM_HALF = 5       ; the beam takes a creature whose middle is this near,
                    ;   and drops one that wriggles further out
BEAM_MINY = 100     ; the beam works only with the shuttle this low or lower
                    ;   (the RP6502 game's lander beams near the surface; a
                    ;   long beam costs too many sprites)
NEAR_X    = 28      ; a low shuttle this near across sets creatures off
NEAR_Y    = 96      ;   (lower than this line)
REACT_PCT = 192     ; ... and reacts this often in 256 (75%), decided each
                    ;   time the shuttle comes over (always was too hard)
PL_STUNCD = 150     ; frames between stun pulses
PL_STUNR  = 36      ; a pulse reaches this far across (and down)
CR_STUN   = 150     ; frames a creature stays stunned
TT_FREEZE = 200     ; frames a turret stays frozen
DF_TOP    = 97      ; the guns' highest line, and lowest (they move as one;
DF_BOT    = 145     ;   their pulse, 3 lower, covers the band: 100-148)
DF_DWELL  = 9       ; steps the guns pause at each end (the lines near the
                    ;   ends are passed half as often: this evens it out)
; The pace rises with the level (sp_level), as Cosmic Arc's (RP6502): 4
; frames a step, one less a level, to 1; pulses 120 frames apart, 15 less a
; level, to 30. Ours: the same steps, pulses from 150 (to 45): our guns'
; range is a little shorter, and 120 felt too quick to start.
DF_STEP1  = 4       ; frames a line the guns move at level 0
DF_PERIOD1 = 150    ; frames between pulses at level 0 (2.5 s),
DF_PERIODSTEP = 15  ;   this much less each level after,
DF_PERIODMIN = 45   ;   to no less than this (0.75 s)
DF_WARN   = 24      ; frames the guns flash before they fire
DF_PULSE  = 6       ; frames a pulse lasts
SHUTTLE_DMG = 12    ; the shuttle shot down costs the Ark this
PL_REBUILD = 150    ; frames until the Ark launches another
CR_PAY    = 12      ; Ark energy for a creature delivered
LOST_DMG  = 12      ; ... lost at time up with the shuttle out

PL_DOCKY  = 80      ; the shuttle's centre, docked in the Ark's bay
PL_YMIN   = 100     ; the free-flight band, lines 100-148: the guns' range
PL_YMAX   = 148     ;   (the towers always a threat; it never lands)
TUNNEL_Y  = 86      ; the tunnel under the Ark: lines 86-101 (one piece)
GROUND_Y  = 152     ; a creature's top on the highest ground (the surface
                    ;   at line 160; it's 160-168: pl_ground)
GLIDE_Y   = 124     ; a glider starts here, and bobs between lines 112 and 144
                    ;   (low enough for the beam: BEAM_MINY)
ARK_WX    = 512     ; the Ark's centre on the planet
DOCK_H    = 16      ; ... and this near the ceiling (passing, still rising)
DOCK_ZONE = 8       ; pushing up at the ceiling this near the Ark's middle
                    ;   (either side: a doorway twice the shuttle's width):
                    ;   the shuttle goes in by itself. (Wider, and flying
                    ;   away from the Ark upwards docked by accident.)
AUTO_IN   = 1       ; pl_auto: going in (centring, up the tunnel)
AUTO_OUT  = 2       ; ... coming out (down the tunnel)
LAUNCH_HOLD = 6     ; frames down's held, docked, to come out
PL_SHOT   = $0600   ; the shuttle's blasters: 3 px a frame across (6 lines up
                    ;   or down), plus the shuttle's own speed: always well
                    ;   ahead of it (the shuttle tops out at 2 px a frame)
PL_FGAP   = 10      ;   frames between pairs
PL_SHLIFE = 28
TT_DISABLE = 600    ; frames a shot turret is out (10 s)
NPS       = 4       ; the shuttle's shots

; shuttle
PL_DOCKED = 0
PL_FLYING = 1
PL_DEAD   = 2       ; shot down: the Ark builds another
; pl_state
PL_PLAY   = 0
PL_CLEAR  = 1
PL_TIMEUP = 2
PL_DONE   = 3
PL_ARRIVE = 4       ; the Ark comes down into orbit (the shuttle aboard)
PL_DEPART = 5       ; ... and climbs away when it's over
PL_LOST   = 6       ; the Ark's energy ran out: the game's over
PL_ARKY   = 64      ; the Ark's line, in orbit (lower: a short tunnel)
ARK_MIDY  = PL_ARKY+15  ; its hull's middle line
; creature states
CS_GROUND = 0
CS_AIR    = 1       ; jumping, falling, or a glider flying
CS_LIFT   = 2       ; in the beam
CS_HELD   = 3       ; in the shuttle
CS_HIDE   = 4       ; (unused now: no creature hides)
CS_DIE    = 5       ; shot: an explosion, then gone (cr_tm counts down)
; kinds
CK_WALK   = 0
CK_HOP    = 1
CK_RUN    = 2
CK_BURROW = 3       ; (the dodger)
CK_GLIDE  = 4
CK_BLINK  = 5       ; (the skitterer)
; cargo
HOLD_NONE = 0
HOLD_CR   = 1
HOLD_ORE  = 2
HOLD_RELIC = 3      ; the relic (crate RELIC_CK, on its planet): heavy

NCR       = 4
NCK       = 2
RELIC_CK  = NCK-1   ; (the relic, on its planet: this crate)
NTT       = 8       ; towers, 128 apart
NTS       = 6

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
pl_relic  = $27C0   ; the relic's on this planet (crate RELIC_CK)
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
; turrets and their shots: $2200-$2287
tt_xl     = $2200   ; [NTT]
tt_xh     = $2208
tt_y      = $2210
tt_dir    = $2218
tt_cool   = $2220
tt_frz    = $2228
tt_sx     = $2230
tt_vis    = $2238
ts_t      = $2240   ; [NTS]
ts_xl     = $2246
ts_xh     = $224C
ts_xf     = $2252
ts_y      = $2258
ts_yf     = $225E
ts_vxl    = $2264
ts_vxh    = $226A
ts_vyl    = $2270
ts_vyh    = $2276
ts_sx     = $227C
ts_vis    = $2282
pl_arksx  = $2770   ; the Ark's screen x, and on the screen (the BASIC)
pl_arkv   = $2771
pl_dead   = $2772   ; frames until a new shuttle
pl_boomx  = $2773   ; where it went down
pl_boomy  = $2774
pl_arky   = $2775   ; the Ark's sprite line (PL_ARKY in orbit; the BASIC)
pl_launch = $2776   ; frames down's been held, docked
pl_auto   = $2777   ; flying itself in or out of the Ark (AUTO_IN / AUTO_OUT)
df_y      = $27BA   ; the guns' line (all of them)
df_dir    = $27BB   ; the guns: 0 down, 1 up (a steady sweep: predictable)
df_wait   = $27EB   ; steps left paused at an end
df_cool   = $27BC   ; frames to the next pulse
df_pulse  = $27BD   ; frames the pulse has left
df_py     = $27BE   ; its line
df_period = $27BF
df_step   = $27D0   ; frames a line, this stage
df_tick   = $27D1
st_state  = $27D2   ; the storm: 0 not yet, 1 the klaxon, 2 the rock, 3 over
st_tm     = $27D3
sr_xl     = $27D4   ; the rock: world x, lo hi fraction
sr_xh     = $27D5
sr_xf     = $27D6
sr_y      = $27D7
sr_yf     = $27D8
sr_dir    = $27D9   ; 0 down from the top, 1 in from the left, 2 from the right
sr_sx     = $27DA   ; its screen x, and on the screen
sr_vis    = $27DB
ab_t      = $27DC   ; the Ark's bolt: frames left (0 none)
ab_x      = $27DD   ; (screen: docked, the camera's on the Ark)
ab_y      = $27DE
ab_d      = $27DF   ; its frame: 0 up, 2 right, 6 left
ab_held   = $27E0   ; the stick still held from the last shot
sr_spdl   = $27E1   ; the rock's speed, this level
sr_spdh   = $27E2
cr_react  = $27E4   ; [NCR] the shuttle overhead: 0 not decided, 1 reacts,
                    ;   2 lets it be (decided each time it comes over)
pl_busy   = $27E8   ; something's rising in the beam already
pl_world  = $27F0   ; the world (0-5: its palette and name; the BASIC reads)
NWORLD    = 6
pl_nodock = $27EA   ; just out of the Ark: only straight up docks again till
                    ;   it's left the doorway (across, or DOCK_H+4 lines down)
pl_cool   = $27B7
pl_aim    = $27B8   ; the way the stick last pointed (0 up, clockwise)
pl_killed = $27B9   ; creatures shot this planet
; the shuttle's shots: $2290-$22C3
ps_t      = $2290   ; [NPS] frames left (0 free)
ps_xl     = $2294
ps_xh     = $2298
ps_xf     = $229C
ps_y      = $22A0
ps_yf     = $22A4
ps_vxl    = $22A8
ps_vxh    = $22AC
ps_vyl    = $22B0
ps_vyh    = $22B4
ps_sx     = $22B8
ps_vis    = $22BC
pl_scans  = $22E0   ; [18] the scanner's line, its ends included (the BASIC
                    ;   plots it: one object)
pl_t0     = $27B0
pl_t1     = $27B1
pl_t2     = $27B2
pl_i      = $27B3
pl_gt     = $27B4   ; (pl_ground's)
pl_gc     = $27B5
pl_gnd    = $27B6   ; the surface's line under the shuttle, this frame

; ---------------------------------------------------------------------------
pl_new
    ldx #0                  ; clear $2700-$27FF and $2200-$22FF
    lda #0
pl_new_c
    sta $2700,x
    sta $2200,x
    inx
    bne pl_new_c
    sta ac_hit
    lda #PL_DOCKED
    sta pl_st
    lda #4                  ; the blasters aim down at first
    sta pl_aim
    lda #PL_ARRIVE          ; the Ark comes down into orbit first
    sta pl_state
    lda #1
    sta pl_arky
    lda #PL_DOCKY-PL_ARKY+1
    sta pl_y
    lda #<ARK_WX            ; the shuttle starts in the Ark
    sta pl_wx
    lda #>ARK_WX
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
    ldy gs_test             ; from the map: no more than the planet has left
    bne pl_new_np
    cmp gs_pop
    bcc pl_new_np
    lda gs_pop
pl_new_np
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
    ; the relic (sector.asm gs_relic): on this planet, as the last crate
    lda gs_test
    bne pl_new_nr
    lda gs_relst
    bne pl_new_nr
    lda gs_sec
    cmp gs_relic
    bne pl_new_nr
    inc pl_relic
pl_new_nr
    ; on the ground: creatures (not gliders) and crates
    ldx #NCR-1
pl_new_f
    lda cr_t,x
    beq pl_new_fn
    cmp #CK_GLIDE+1
    beq pl_new_fn
    jsr pl_crfloor
    sta cr_y,x
pl_new_fn
    dex
    bpl pl_new_f
    ldx #NCK-1
pl_new_kf
    jsr pl_ckfloor
    sta ck_y,x
    dex
    bpl pl_new_kf
    ; towers: one every 128 pixels from 64
    ldx #NTT-1
pl_new_t
    txa
    lsr                     ; x = 64 + 128 * n: lo = (n & 1) * 128 + 64
    lda #0
    ror
    ora #64
    sta tt_xl,x
    txa
    lsr
    sta tt_xh,x
    dex
    bpl pl_new_t
    ; the defences: the guns at the top; the first pulse a little later;
    ; pulses closer together each wave
    lda #DF_TOP
    sta df_y
    lda #0
    sta df_dir
    sta df_wait
    sta df_pulse
    sta pl_nodock
    ; this level's pace (as Cosmic Arc's: the level goes up only when every
    ; creature on a planet is caught; it starts at 0)
    lda sp_level
    sta pl_t0
    ; the rock's speed: ROCK_SPD0 + ROCK_SPDL a level, at most 2 px a frame
    sta M_A
    lda #0
    sta M_A+1
    sta M_B+1
    sta M_CTRL
    lda #ROCK_SPDL
    sta M_B
    clc
    lda M_P
    adc #<ROCK_SPD0
    sta sr_spdl
    lda M_P+1
    adc #>ROCK_SPD0
    sta sr_spdh
    sec                     ; (at most ROCK_SPDMAX)
    lda sr_spdl
    sbc #<ROCK_SPDMAX
    lda sr_spdh
    sbc #>ROCK_SPDMAX
    bcc pl_new_rs
    lda #<ROCK_SPDMAX
    sta sr_spdl
    lda #>ROCK_SPDMAX
    sta sr_spdh
pl_new_rs
    lda #DF_STEP1           ; frames a line: DF_STEP1 - stages after, >= 1
    sec
    sbc pl_t0
    bcc pl_new_s1
    bne pl_new_s2
pl_new_s1
    lda #1
pl_new_s2
    sta df_step
    sta df_tick
    lda pl_t0               ; frames between pulses: DF_PERIOD1 - 15 a stage
    sta M_A
    lda #0
    sta M_A+1
    sta M_B+1
    sta M_CTRL
    lda #DF_PERIODSTEP
    sta M_B
    sec
    lda #DF_PERIOD1
    sbc M_P
    bcc pl_new_dp
    ldy M_P+1
    bne pl_new_dp
    cmp #DF_PERIODMIN
    bcs pl_new_dp2
pl_new_dp
    lda #DF_PERIODMIN
pl_new_dp2
    sta df_period
    clc
    adc #60
    sta df_cool
    jsr pl_camera
    lda sp_wave             ; the world: a new one each planet (palettes, as
    beq pl_new_w            ;  Cosmic Arc's); the first (after wave 1) VERDA
    sec
    sbc #1
pl_new_w
    cmp #NWORLD
    bcc pl_new_w2
    sbc #NWORLD
    bcs pl_new_w
pl_new_w2
    sta pl_world
    jsr pl_hudname
    lda #MUS_PLANET
    jsr mu_switch
    lda #<tx_planet
    ldy #>tx_planet
    ldx #6
    jsr sp_msgcopy
    lda #120
    sta pl_msgtm
    lda #SFX_ARRIVE
    jmp sfx

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
    bne pl_fr_play_far350
    jmp pl_fr_play
pl_fr_play_far350
    cmp #PL_DONE
    bne pl_fr_r_far352
    jmp pl_fr_r
pl_fr_r_far352
    cmp #PL_ARRIVE
    bne pl_fr_dep
    inc pl_arky             ; the Ark comes down into orbit
    lda pl_arky
    cmp #PL_ARKY
    bcc pl_fr_ark
    lda #PL_PLAY
    sta pl_state
    jmp pl_fr_ark
pl_fr_dep
    cmp #PL_DEPART
    bne pl_fr_end
    dec pl_arky             ; ... and climbs away
    bne pl_fr_ark
    lda #PL_DONE
    sta pl_state
pl_fr_ark
    lda pl_st               ; the shuttle aboard goes with it
    cmp #PL_DOCKED
    bne pl_fr_idle
    clc
    lda pl_arky
    adc #PL_DOCKY-PL_ARKY
    sta pl_y
    jmp pl_fr_idle
pl_fr_end
    ; over (clear, time up, lost): a moment, then the Ark leaves (or, lost,
    ; it's done)
    dec pl_endtm
    bne pl_fr_idle
    lda pl_state
    cmp #PL_LOST
    bne pl_fr_go
    lda #PL_DONE
    sta pl_state
    bne pl_fr_idle
pl_fr_go
    lda #PL_DEPART
    sta pl_state
    lda #0
    sta sp_msglen
    lda #<ARK_WX            ; the camera to the Ark
    sta pl_wx
    lda #>ARK_WX
    sta pl_wxh
    lda pl_st
    cmp #PL_DOCKED
    beq pl_fr_dk
    lda #PL_DEAD            ; a shuttle still out was lost: none to show
    sta pl_st               ; (pl_dead 0: no wreck drawn either)
    lda #0
    sta pl_dead
pl_fr_dk
    lda #SFX_DEPART
    jsr sfx
pl_fr_idle
    jsr pl_camera
    jsr pl_creatures
    jsr pl_screen
    jmp pl_hud
pl_fr_r
    rts
pl_fr_play
    jsr pl_clock
    jsr pl_storm
    jsr pl_shuttle
    jsr pl_camera
    jsr pl_creatures
    jsr pl_crates
    jsr pl_defense
    jsr pl_screen
    jsr pl_dropbtn
    jsr pl_beamwork
    jsr pl_checkall
    jsr pl_scanner
    jmp pl_hud

; ---- the clock ----
pl_clock
    lda st_state            ; (counts only until the storm)
    bne pl_ck_r
    dec pl_sub
    bne pl_ck_r
    lda #60
    sta pl_sub
    dec pl_secs
    bne pl_ck_r
    ; the storm's coming (as Cosmic Arc's): the klaxon, then a rock at the
    ; Ark. Be back aboard to shoot it down.
    lda #1
    sta st_state
    lda #STORM_DELAY
    sta st_tm
    lda M_RND               ; where the rock will come from: 0 the top,
    and #3                  ;   1 the left, 2 the right (3: the top)
    cmp #3
    bcc pl_ck_d
    lda #0
pl_ck_d
    sta sr_dir
    lda #MUS_PIRATES        ; (the menace: the storm's coming)
    jsr mu_switch
    lda #<tx_storm
    ldy #>tx_storm
    ldx #12
    jsr sp_msgcopy
    lda #0
    sta pl_msgtm
pl_ck_r
    rts

; ---- the storm: the klaxon; the rock; the Ark's laser (docked) ----
pl_storm
    jsr pl_arkfire
    lda st_state
    cmp #1
    bne pl_st_rock
    ; the klaxon, twice a second, until the rock comes
    lda pl_tick
    and #31
    bne pl_st_k
    lda #SFX_KLAXON
    jsr sfx
pl_st_k
    lda pl_tick             ; (st_tm counts 4-frame steps)
    and #3
    bne pl_st_r
    dec st_tm
    bne pl_st_r
    ; the rock: from the top, the left or the right (never below)
    lda #2
    sta st_state
    lda #0
    sta sp_msglen
    sta sr_xf
    sta sr_yf
    lda sr_dir              ; (chosen at the klaxon)
    beq pl_st_top
    cmp #1
    beq pl_st_left
    lda #<(ARK_WX+104)      ; from the right (off the screen, docked)
    sta sr_xl
    lda #>(ARK_WX+104)
    sta sr_xh
    lda #ARK_MIDY-8
    sta sr_y
    rts
pl_st_left
    lda #<(ARK_WX-112)
    sta sr_xl
    lda #>(ARK_WX-112)
    sta sr_xh
    lda #ARK_MIDY-8
    sta sr_y
    rts
pl_st_top
    lda #<(ARK_WX-4)
    sta sr_xl
    lda #>(ARK_WX-4)
    sta sr_xh
    lda #16
    sta sr_y
pl_st_r
    rts
pl_st_rock
    cmp #2
    bne pl_st_r
    ; it comes straight at the Ark (down: half the speed, in lines)
    lda sr_dir
    bne pl_st_side
    lda sr_spdh
    lsr
    sta pl_t1
    lda sr_spdl
    ror
    clc
    adc sr_yf
    sta sr_yf
    lda sr_y
    adc pl_t1
    sta sr_y
    cmp #PL_ARKY+6-16+1     ; its foot reaching the Ark's top
    bcc pl_st_hit_far662
    jmp pl_st_hit
pl_st_hit_far662
    jmp pl_st_sx
pl_st_side
    cmp #1
    bne pl_st_fromr
    clc
    lda sr_xf
    adc sr_spdl
    sta sr_xf
    lda sr_xl
    adc sr_spdh
    sta sr_xl
    lda sr_xh
    adc #0
    and #3
    sta sr_xh
    ; reached the Ark's left edge (ARK_WX - 24, the rock 8 wide)?
    sec
    lda sr_xl
    sbc #<(ARK_WX-24-8)
    lda sr_xh
    sbc #>(ARK_WX-24-8)
    bcc pl_st_hit_far684
    jmp pl_st_hit
pl_st_hit_far684
    jmp pl_st_sx
pl_st_fromr
    sec
    lda sr_xf
    sbc sr_spdl
    sta sr_xf
    lda sr_xl
    sbc sr_spdh
    sta sr_xl
    lda sr_xh
    sbc #0
    and #3
    sta sr_xh
    ; reached the Ark's right edge (ARK_WX + 24)?
    sec
    lda sr_xl
    sbc #<(ARK_WX+24)
    lda sr_xh
    sbc #>(ARK_WX+24)
    bcc pl_st_hit
pl_st_sx
    ; on the screen? (and the Ark's bolt against it)
    lda #0
    sta sr_vis
    lda sr_xl
    ldy sr_xh
    jsr pl_scrx
    bcc pl_st_r2
    sta sr_sx
    inc sr_vis
    lda ab_t
    beq pl_st_r2
    clc
    lda ab_x
    adc #2
    sec
    sbc sr_sx
    cmp #8
    bcs pl_st_r2
    clc
    lda ab_y
    adc #2
    sec
    sbc sr_y
    cmp #16
    bcs pl_st_r2
    ; shot down: the storm's over, the planet's done (one more for STORMS)
    inc gs_storms
    bne pl_st_sc
    dec gs_storms
pl_st_sc
    lda #0
    sta ab_t
    lda #3
    sta st_state
    lda #$01                ; 100 points
    sta sc_m
    lda #0
    sta sc_l
    jsr sc_add
    lda #SFX_BOOM
    jsr sfx
    lda #<tx_allclear
    ldy #>tx_allclear
    ldx #9
    jsr sp_msgcopy
    jmp pl_st_end
pl_st_r2
    rts
pl_st_hit
    ; it hit the Ark: the Ark pays; a shuttle still out is lost with its cargo
    lda #3
    sta st_state
    lda pl_st
    cmp #PL_FLYING
    bne pl_st_h2
    jsr pl_drop
pl_st_h2
    lda #<tx_archit
    ldy #>tx_archit
    ldx #7
    jsr sp_msgcopy
    lda #ROCK_DMG
    jsr pl_arkdmg
    lda pl_state            ; (out of energy: lost, the game's over)
    bne pl_st_r2
pl_st_end
    lda #PL_TIMEUP          ; the planet's done: the Ark leaves
    sta pl_state
    lda #120
    sta pl_endtm
    lda #0
    sta pl_beam
    sta pl_msgtm
    rts

; the Ark's laser: docked, the stick fires it up, left or right (a fresh
; push each shot, one bolt at a time)
pl_arkfire
    lda ab_t                ; a bolt flying
    beq pl_af_new
    dec ab_t
    beq pl_af_new
    lda ab_d
    bne pl_af_side
    sec
    lda ab_y
    sbc #5
    sta ab_y
    cmp #20
    bcs pl_af_new
    lda #0
    sta ab_t
    beq pl_af_new
pl_af_side
    cmp #2
    bne pl_af_left
    clc
    lda ab_x
    adc #3
    sta ab_x
    cmp #157
    bcc pl_af_new
    lda #0
    sta ab_t
    beq pl_af_new
pl_af_left
    sec
    lda ab_x
    sbc #3
    sta ab_x
    bcs pl_af_new
    lda #0
    sta ab_t
pl_af_new
    ldx sp_joy
    cpx #8
    bne pl_af_st
    lda #0                  ; let go: the next push fires
    sta ab_held
    rts
pl_af_st
    lda pl_st
    cmp #PL_DOCKED
    bne pl_af_r
    lda ab_held
    bne pl_af_r
    lda ab_t
    bne pl_af_r
    cpx #0
    beq pl_af_up
    cpx #2
    beq pl_af_right
    cpx #6
    beq pl_af_lft
pl_af_r
    rts
pl_af_up
    lda #78
    sta ab_x
    lda #PL_ARKY+2
    sta ab_y
    lda #0
    beq pl_af_go
pl_af_right
    lda #104
    sta ab_x
    lda #ARK_MIDY-2
    sta ab_y
    lda #2
    bne pl_af_go
pl_af_lft
    lda #52
    sta ab_x
    lda #ARK_MIDY-2
    sta ab_y
    lda #6
pl_af_go
    sta ab_d
    lda #AB_LIFE
    sta ab_t
    lda #1
    sta ab_held
    lda #SFX_ZAP
    jmp sfx

; ---- the ground (tools/planet.py: pl_hd, pl_hs a column) ----
; world x (A lo, Y hi) -> A = the surface's line there (160-168). Uses Y.
pl_ground
    pha
    and #7
    lsr                     ; steps across its column: 0-3
    sta pl_gt
    pla
    lsr
    lsr
    lsr
    sta pl_gc
    tya
    and #3
    asl
    asl
    asl
    asl
    asl
    ora pl_gc
    tay                     ; the column, 0-127
    lda pl_hs,y
    beq pl_gr_flat
    bmi pl_gr_up
    lda pl_hd,y             ; going down: a line deeper each 2 pixels
    clc
    adc pl_gt
    jmp pl_gr_d
pl_gr_up
    lda pl_hd,y
    sec
    sbc pl_gt
    jmp pl_gr_d
pl_gr_flat
    lda pl_hd,y
pl_gr_d
    clc
    adc #160
    rts

; creature X standing: A = its top's line (the ground under its middle - 8)
pl_crfloor
    clc
    lda cr_xl,x
    adc #4
    pha
    lda cr_xh,x
    adc #0
    tay
    pla
    jsr pl_ground
    sec
    sbc #8
    rts

; crate X resting: A = its top's line
pl_ckfloor
    clc
    lda ck_xl,x
    adc #4
    pha
    lda ck_xh,x
    adc #0
    tay
    pla
    jsr pl_ground
    sec
    sbc #8
    rts

; ---- the shuttle ----
pl_shuttle
    lda pl_hit
    beq pl_sh_h
    dec pl_hit
pl_sh_h
    lda pl_st
    cmp #PL_DEAD
    bne pl_sh_alive
    dec pl_dead             ; shot down: the Ark launches another
    bne pl_sh_dr
    lda #PL_DOCKED
    sta pl_st
    lda #PL_DOCKY
    sta pl_y
    lda #<ARK_WX
    sta pl_wx
    lda #>ARK_WX
    sta pl_wxh
pl_sh_dr
    rts
pl_sh_alive
    cmp #PL_DOCKED
    bne pl_sh_out
    ; docked: inside the Ark (not drawn). Hold down a moment: it comes out
    ; and drops down the tunnel, clear of it, by itself
    ldx sp_joy
    cpx #8
    bcs pl_sh_dk0
    lda pl_updown,x
    bmi pl_sh_dk0
    beq pl_sh_dk0
    inc pl_launch
    lda pl_launch
    cmp #LAUNCH_HOLD
    bcc pl_sh_dr
    lda #PL_FLYING
    sta pl_st
    lda #AUTO_OUT
    sta pl_auto
    lda #1
    sta pl_nodock
    lda #0
    sta pl_vxl
    sta pl_vxh
    lda #PL_DOCKY+2
    sta pl_y
    lda #<ARK_WX
    sta pl_wx
    lda #>ARK_WX
    sta pl_wxh
    lda #SFX_LAUNCH
    jmp sfx
pl_sh_dk0
    lda #0
    sta pl_launch
    rts
pl_sh_out
    ; going in or coming out of the Ark: it flies itself (and nothing can
    ; hit it meanwhile)
    lda pl_auto
    bne pl_sh_o2_far634
    jmp pl_sh_o2
pl_sh_o2_far634
    lda #0
    sta pl_vxl
    sta pl_vxh
    lda pl_auto
    cmp #AUTO_IN
    beq pl_sh_in
    inc pl_y                ; out: down the tunnel, to clear of it
    lda pl_y
    cmp #PL_YMIN+6
    bcc pl_sh_ar
    lda #0
    sta pl_auto
pl_sh_ar
    rts
pl_sh_in
    ; in: slide over to the tunnel (2 px a frame), up it, and inside
    sec
    lda pl_wx
    sbc #<ARK_WX
    sta pl_t0
    lda pl_wxh
    sbc #>ARK_WX
    and #3
    beq pl_sh_ir            ; right of it (or on it)
    lda pl_t0               ; left of it: -1..-DOCK_ZONE
    cmp #$FE
    bcs pl_sh_ion
    clc
    lda pl_wx
    adc #2
    sta pl_wx
    lda pl_wxh
    adc #0
    and #3
    sta pl_wxh
    jmp pl_sh_iup
pl_sh_ir
    lda pl_t0
    cmp #3
    bcc pl_sh_ion
    sec
    lda pl_wx
    sbc #2
    sta pl_wx
    lda pl_wxh
    sbc #0
    and #3
    sta pl_wxh
    jmp pl_sh_iup
pl_sh_ion
    lda #<ARK_WX            ; on it
    sta pl_wx
    lda #>ARK_WX
    sta pl_wxh
pl_sh_iup
    dec pl_y
    lda pl_y
    cmp #PL_DOCKY+1
    bcs pl_sh_ar
    lda #PL_DOCKY           ; inside: docked, and the cargo handed over
    sta pl_y
    lda #<ARK_WX
    sta pl_wx
    lda #>ARK_WX
    sta pl_wxh
    lda #PL_DOCKED
    sta pl_st
    lda #0
    sta pl_auto
    sta pl_launch
    lda #1                  ; (up's still held from docking: the Ark fires
    sta ab_held             ;  only once the stick's been let go)
    jsr pl_deliver
    lda #SFX_DOCK
    jmp sfx
pl_sh_o2
    ; the beam on (button 1, low enough): the shuttle stops dead
    lda sp_fire
    beq pl_sh_free
    lda pl_hold
    bne pl_sh_free
    lda pl_y
    cmp #BEAM_MINY
    bcc pl_sh_free
    lda #0
    sta pl_vxl
    sta pl_vxh
    rts
pl_sh_free
    ; in the Ark's tube (above PL_YMIN): up and down only
    lda pl_y
    cmp #PL_YMIN
    bcs pl_sh_fr
    lda #0
    sta pl_vxl
    sta pl_vxh
    jmp pl_sh_ud0
pl_sh_fr
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
    ; the top speed: PL_VMAX, half with ore aboard (heavy, as going up), a
    ; quarter with the relic (pl_t1 lo, pl_t2 hi)
    ldx pl_hold
    lda pl_vlimlo,x
    sta pl_t1
    lda pl_vlimhi,x
    sta pl_t2
    lda pl_vxh
    bmi pl_sh_cn
    lda pl_vxl              ; v >= the limit: the limit
    cmp pl_t1
    lda pl_vxh
    sbc pl_t2
    bcc pl_sh_mv
    lda pl_t1
    sta pl_vxl
    lda pl_t2
    sta pl_vxh
    jmp pl_sh_mv
pl_sh_cn
    sec                     ; (-limit)
    lda #0
    sbc pl_t1
    sta pl_t1
    lda #0
    sbc pl_t2
    sta pl_t2
    lda pl_vxl              ; v < -limit: -limit
    cmp pl_t1
    lda pl_vxh
    sbc pl_t2
    bcs pl_sh_mv
    lda pl_t1
    sta pl_vxl
    lda pl_t2
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
pl_sh_ud0
    ; just out of the Ark: docking again once it's left the doorway
    lda pl_nodock
    beq pl_sh_nd
    lda pl_y
    cmp #PL_YMIN+DOCK_H+4
    bcs pl_sh_ndc
    jsr pl_underark
    bcs pl_sh_nd
pl_sh_ndc
    lda #0
    sta pl_nodock
pl_sh_nd
    ; the ground under it: it can't go lower than 8 above (and rising
    ; ground lifts it)
    lda pl_wx
    ldy pl_wxh
    jsr pl_ground
    sta pl_gnd
    sec
    sbc #8
    cmp #PL_YMAX            ; the band's foot: it never lands
    bcc pl_sh_gk
    lda #PL_YMAX
pl_sh_gk
    sta pl_t0
    cmp pl_y
    bcs pl_sh_ud
    sta pl_y
pl_sh_ud
    ; up and down
    ldx sp_joy
    cpx #8
    bcs pl_sh_r
    lda pl_updown,x
    beq pl_sh_r
    bmi pl_sh_up
    lda pl_y                ; down, to just above the ground
    cmp pl_t0
    bcs pl_sh_r
    inc pl_y
    rts
pl_sh_up
    ; pushing up (or up and across) in the Ark's doorway, near the ceiling:
    ; it goes in by itself. (Not straight after coming out: pl_nodock.)
    lda pl_y
    cmp #PL_YMIN+DOCK_H+1
    bcs pl_sh_u0
    lda pl_nodock           ; just out: straight up goes back in at once;
    beq pl_sh_dk            ;  up and across (flying away) doesn't
    lda sp_joy
    bne pl_sh_u0
pl_sh_dk
    jsr pl_underark
    bcc pl_sh_u0
    lda #AUTO_IN
    sta pl_auto
    lda #0
    sta pl_vxl
    sta pl_vxh
    rts
pl_sh_u0
    lda pl_hold             ; a crate's heavy: half speed up (the relic a
    cmp #HOLD_ORE           ;  quarter)
    bcc pl_sh_u1
    inc pl_yh
    lda pl_yh
    ldx pl_hold
    and pl_upmask-HOLD_ORE,x
    bne pl_sh_r
pl_sh_u1
    lda pl_y                ; below the ceiling (PL_YMIN): up
    cmp #PL_YMIN+1
    bcc pl_sh_ceil
    dec pl_y
    rts
pl_sh_ceil
pl_sh_r
    rts

; C = 1: the shuttle is near the Ark (within DOCK_ZONE across)
pl_underark
    sec
    lda pl_wx
    sbc #<ARK_WX
    sta pl_t0
    lda pl_wxh
    sbc #>ARK_WX
    and #3
    beq pl_ua_p
    cmp #3
    bne pl_ua_no
    lda pl_t0               ; a little to the left: -1..-DOCK_ZONE
    cmp #256-DOCK_ZONE
    rts                     ; (C = 1 when it's that near)
pl_ua_p
    lda pl_t0
    cmp #DOCK_ZONE+1
    bcs pl_ua_no
    sec
    rts
pl_ua_no
    clc
    rts

; by what's held (none, a creature, ore, the relic): top speed across;
; the frames going up (ore, the relic: 1 in 2, 1 in 4)
pl_vlimlo  .byte <PL_VMAX, <PL_VMAX, <(PL_VMAX/2), <(PL_VMAX/4)
pl_vlimhi  .byte >PL_VMAX, >PL_VMAX, >(PL_VMAX/2), >(PL_VMAX/4)
pl_upmask  .byte 1, 3
; per joystick direction (0 up, clockwise): across (-1, 0, 1), up/down (-1 up)
pl_across  .byte 0, 1, 1, 1, 0, -1, -1, -1
pl_updown  .byte -1, -1, 0, 1, 1, 1, 0, -1

pl_deliver
    lda pl_hold
    bne pl_dv_r_far1393
    jmp pl_dv_r
pl_dv_r_far1393
    cmp #HOLD_CR
    bne pl_dv_ore
    ldx pl_holdi
    ldy cr_t,x              ; into stasis, by its kind (port.asm: the
    lda gs_stasis-1,y       ;  Bio-Bounty)
    cmp #99
    bcs pl_dv_st
    adc #1
    sta gs_stasis-1,y
pl_dv_st
    lda gs_test             ; the planet has one fewer (gs_miss: back with
    bne pl_dv_nm            ;  time; not in the tests' old flow)
    lda gs_sec
    lsr
    tay
    lda #$01
    bcc pl_dv_lo
    lda #$10
pl_dv_lo
    clc
    adc gs_miss,y
    sta gs_miss,y
pl_dv_nm
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
    lda pl_hold             ; the relic: aboard (a port takes it: port.asm)
    cmp #HOLD_RELIC
    bne pl_dv_o2
    lda #0
    sta pl_relic
    lda #1
    sta gs_relst
    lda #<tx_relic
    ldy #>tx_relic
    ldx #12
    jsr sp_msgcopy
    lda #120
    sta pl_msgtm
    lda #$20                ; 2000 points
    sta sc_m
    lda #$00
    sta sc_l
    jmp pl_dv_done
pl_dv_o2
    inc pl_ore
    jsr pt_holdfree         ; into the holds as fuel ore, if there's room
    bcc pl_dv_full
    inc gs_ore
pl_dv_full
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
    ; the Ark (48 wide, its left edge at ARK_WX - 24): on the screen if its
    ; left edge is under 160, or within 48 off the left (MARIA wraps)
    lda #0
    sta pl_arkv
    sec
    lda #<(ARK_WX-24)
    sbc pl_cam
    sta pl_arksx
    lda #>(ARK_WX-24)
    sbc pl_camh
    and #3
    beq pl_cm_al
    cmp #3
    bne pl_cm_r
    lda pl_arksx
    cmp #208
    bcc pl_cm_r
    inc pl_arkv
    rts
pl_cm_al
    lda pl_arksx
    cmp #160
    bcs pl_cm_r
    inc pl_arkv
pl_cm_r
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
    rts

; ---- creatures ----
; Each kind reacts to the shuttle low overhead (pl_overhead). None ever
; hides: a creature alive is on the planet to be seen (burrowing and
; blinking out read as creatures vanishing).
;   walker     turns about at random, quickly, and hurries
;   hopper     jumps away
;   runner     sprints away
;   dodger     turns away and dashes
;   glider     (always bobbing up and down) hurries
;   skitterer  (always quick, turning about often)
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
    cmp #CS_DIE
    bne pl_cr_nd
    dec cr_tm,x             ; shot: the explosion runs out, then it's gone
    bne pl_cr_skip
    lda #0
    sta cr_t,x
    beq pl_cr_skip
pl_cr_nd
    cmp #CS_LIFT
    beq pl_cr_skip          ; (the beam moves it: pl_beamwork)
    cmp #CS_HELD
    beq pl_cr_skip
    cmp #CS_AIR
    bne pl_cr_gr0
    jmp pl_cr_air
pl_cr_gr0
    cmp #CS_HIDE
    bne pl_cr_ground
    jmp pl_cr_hidden
pl_cr_skip
    jmp pl_cr_n

pl_cr_ground
    lda cr_stun,x           ; stunned: it stands still
    beq pl_cr_g1
    jmp pl_cr_n
pl_cr_g1
    jsr pl_overhead
    bcc pl_cr_calm
    lda cr_t,x
    cmp #CK_WALK+1
    beq pl_cr_rwalk
    cmp #CK_HOP+1
    beq pl_cr_rhop
    cmp #CK_RUN+1
    beq pl_cr_rrun
    cmp #CK_BURROW+1
    beq pl_cr_rdig
    jmp pl_cr_calm
pl_cr_rwalk
    lda cr_tm,x             ; turn about soon, and again
    cmp #24
    bcc pl_cr_rw2
    lda M_RND
    and #15
    clc
    adc #4
    sta cr_tm,x
pl_cr_rw2
    jsr pl_walk
    ldx pl_i
    jmp pl_cr_calm
pl_cr_rhop
    jsr pl_away
    lda #$FD                ; a hop: up at 2.75 lines a frame
    sta cr_vyh,x
    lda #$40
    sta cr_vyl,x
    lda #CS_AIR
    sta cr_st,x
    jmp pl_cr_n
pl_cr_rrun
    lda cr_fast,x
    bne pl_cr_calm
    jsr pl_away
    lda #40
    sta cr_fast,x
    jmp pl_cr_calm
pl_cr_rdig
    ; the dodger: turns away and dashes (twice as fast) a moment
    lda cr_fast,x
    bne pl_cr_rd2
    jsr pl_away
    lda #20
    sta cr_fast,x
pl_cr_rd2
    jmp pl_cr_calm
pl_cr_calm
    ; a runner sprinting: three times as fast
    lda cr_fast,x
    beq pl_cr_walk
    dec cr_fast,x
    jsr pl_walk
    jsr pl_walk
    ldx pl_i
pl_cr_walk
    lda cr_t,x              ; the skitterer: always quick
    cmp #CK_BLINK+1
    bne pl_cr_wk1
    jsr pl_walk
pl_cr_wk1
    jsr pl_walk
    ldx pl_i
    ; its own timer: turn about, hop, burrow, blink
    dec cr_tm,x
    beq pl_cr_tm
    jmp pl_cr_n
pl_cr_tm
    lda M_RND
    ora #$40
    sta cr_tm,x
    lda cr_t,x
    cmp #CK_HOP+1
    bne pl_cr_t2
    lda #$FD
    sta cr_vyh,x
    lda #$40
    sta cr_vyl,x
    lda #CS_AIR
    sta cr_st,x
    jmp pl_cr_n
pl_cr_t2
    cmp #CK_BLINK+1         ; the skitterer: turns about often
    bne pl_cr_turn
    lda M_RND
    and #31
    clc
    adc #8
    sta cr_tm,x
pl_cr_turn
    lda cr_dir,x
    eor #1
    sta cr_dir,x
    jmp pl_cr_n

pl_cr_air
    lda cr_t,x
    cmp #CK_GLIDE+1
    bne pl_cr_fall
    ; a glider: across, bobbing up and down between lines 112 and 144
    lda cr_stun,x
    beq pl_cr_gl
    jmp pl_cr_n
pl_cr_gl
    jsr pl_walk
    jsr pl_walk
    ldx pl_i
    jsr pl_overhead
    bcc pl_cr_gb
    jsr pl_walk
    jsr pl_walk
    ldx pl_i
pl_cr_gb
    lda pl_tick
    and #1
    bne pl_cr_gt
    lda cr_vyh,x            ; (its bob: $00 down, else up)
    bne pl_cr_gup
    inc cr_y,x
    lda cr_y,x
    cmp #144
    bcc pl_cr_gt
    lda #1
    sta cr_vyh,x
    bne pl_cr_gt
pl_cr_gup
    dec cr_y,x
    lda cr_y,x
    cmp #113
    bcs pl_cr_gt
    lda #0
    sta cr_vyh,x
pl_cr_gt
    dec cr_tm,x
    bne pl_cr_gn
    lda M_RND
    ora #$40
    sta cr_tm,x
    lda cr_dir,x
    eor #1
    sta cr_dir,x
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
    jsr pl_crfloor
    sta pl_t0
    lda cr_y,x
    cmp pl_t0
    bcc pl_cr_fl2
    lda pl_t0               ; landed
    sta cr_y,x
    lda #CS_GROUND
    sta cr_st,x
pl_cr_fl2
    lda cr_t,x              ; a hopper keeps moving across in its jump
    cmp #CK_HOP+1
    bne pl_cr_n
    jsr pl_walk
    jsr pl_walk
    ldx pl_i
    jmp pl_cr_n

pl_cr_hidden
    ; hidden (burrowed, blinked out): back after a while (a stun: at once)
    lda cr_stun,x
    bne pl_cr_up
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
    bne pl_cr_n
    ; a blinker comes back up to 64 pixels away, either way. (The step is
    ; signed: its high byte is $FF going left. Adding it as unsigned, with
    ; the carry counted twice, threw blinkers 200-500 pixels.)
    lda M_RND
    and #$7F
    sec
    sbc #$40                ; -64..63
    sta pl_t0
    clc
    adc cr_xl,x
    sta cr_xl,x
    lda pl_t0
    and #$80
    beq pl_cr_bx            ; (C still the low byte's carry)
    lda #$FF
pl_cr_bx
    adc cr_xh,x
    and #3
    sta cr_xh,x
pl_cr_n
    ldx pl_i
    lda cr_t,x              ; on the ground: on the ground's line
    beq pl_cr_nn
    lda cr_st,x
    cmp #CS_GROUND
    bne pl_cr_nn
    jsr pl_crfloor
    sta cr_y,x
pl_cr_nn
    dex
    bmi pl_cr_r
    jmp pl_cr_l
pl_cr_r
    rts

; C = 1: creature X reacts: the shuttle is low (below NEAR_Y), flying,
; within NEAR_X across of it (on the screen), and it's decided to (REACT_PCT
; of the time, decided once each time the shuttle comes over)
pl_overhead
    lda pl_st
    cmp #PL_FLYING
    bne pl_oh_no
    lda pl_y
    cmp #NEAR_Y
    bcc pl_oh_no
    lda cr_vis,x
    beq pl_oh_no
    lda cr_sx,x
    jsr pl_beamoff
    cmp #NEAR_X
    bcs pl_oh_no
    lda cr_react,x          ; overhead: react or not, decided once
    bne pl_oh_dec
    lda M_RND
    cmp #REACT_PCT
    lda #1
    bcc pl_oh_set
    lda #2
pl_oh_set
    sta cr_react,x
pl_oh_dec
    cmp #1
    bne pl_oh_c
    sec
    rts
pl_oh_no
    lda #0                  ; gone from overhead: decide afresh next time
    sta cr_react,x
pl_oh_c
    clc
    rts

; creature X turns to face away from the shuttle
pl_away
    lda #0
    ldy cr_sx,x
    cpy #76
    bcs pl_aw_r
    lda #1
pl_aw_r
    sta cr_dir,x
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
    jsr pl_ckfloor
    sta pl_t0
    lda ck_y,x
    cmp pl_t0
    bcc pl_ck_n
    lda pl_t0
    sta ck_y,x
    lda #CS_GROUND+1
    sta ck_st,x
pl_ck_n
    dex
    bpl pl_ck_l
    rts

; ---- the planet's defences (as Cosmic Arc's, RP6502) ----
; Every gun moves as one: up and down its tower between DF_TOP and DF_BOT.
; Every so often (DF_PERIOD, less each wave) the guns flash a warning
; (DF_WARN frames), then fire: a pulse right across the screen at their
; height for DF_PULSE frames. A shuttle the pulse touches is destroyed.
; No bullets: you dodge it (by height), and time the beam between pulses.
pl_defense
    ; the guns' height: a steady sweep, end to end (the player can read it),
    ; a line every df_step frames, pausing DF_DWELL steps at each end. (No
    ; safe line: the sweep covers the band, the pulses come at random gaps.)
    dec df_tick
    bne pl_df_f
    lda df_step
    sta df_tick
    lda df_wait
    beq pl_df_mv
    dec df_wait
    jmp pl_df_f
pl_df_mv
    lda df_dir
    bne pl_df_up
    inc df_y
    lda df_y
    cmp #DF_BOT
    bcc pl_df_f
    lda #1
    sta df_dir
    lda #DF_DWELL
    sta df_wait
    bne pl_df_f
pl_df_up
    dec df_y
    lda df_y
    cmp #DF_TOP+1
    bcs pl_df_f
    lda #0
    sta df_dir
    lda #DF_DWELL
    sta df_wait
pl_df_f
    ; the pulse
    lda df_pulse
    beq pl_df_cool
    dec df_pulse
    ; the shuttle in it? (its middle within 4 lines of the pulse's)
    lda pl_st
    cmp #PL_FLYING
    bne pl_df_r
    lda pl_auto             ; (flying itself in or out: safe)
    bne pl_df_r
    lda pl_y
    sec
    sbc df_py
    bcs pl_df_dy
    eor #$FF
    adc #1
pl_df_dy
    cmp #5
    bcs pl_df_r
    jmp pl_shotdown
pl_df_cool
    dec df_cool
    beq pl_df_fire
    lda df_cool
    cmp #DF_WARN
    bne pl_df_r
    lda #SFX_MISSILE        ; the warning: the guns light up
    jmp sfx
pl_df_fire
    lda df_period           ; the next: 1/2 to 3/2 the period (no rhythm)
    sta M_A
    lda M_RND
    sta M_B
    lda #0
    sta M_A+1
    sta M_B+1
    sta M_CTRL
    lda df_period
    lsr
    clc
    adc M_P+1
    cmp #DF_WARN+8
    bcs pl_df_cl
    lda #DF_WARN+8
pl_df_cl
    sta df_cool
    lda #DF_PULSE
    sta df_pulse
    clc
    lda df_y
    adc #3                  ; the gun's middle
    sta df_py
    lda #SFX_PSHOT
    jmp sfx
pl_df_r
    rts

; the shuttle's shot down: its cargo falls, the Ark pays, and builds another
pl_shotdown
    jsr pl_drop
    lda #PL_DEAD
    sta pl_st
    lda #PL_REBUILD
    sta pl_dead
    lda #76
    sta pl_boomx
    sec
    lda pl_y
    sbc #8
    sta pl_boomy
    lda #0
    sta pl_beam
    lda #SFX_LOST
    jsr sfx
    lda #SHUTTLE_DMG
    jmp pl_arkdmg

; the Ark takes A; run out, and the game's over (PL_LOST)
pl_arkdmg
    ldy #1                  ; (no SWEEP this planet)
    sty ac_hit
    sta pl_t0
    sec
    lda sp_energy
    sbc pl_t0
    bcs pl_ad_e
    lda #0
pl_ad_e
    sta sp_energy
    bne pl_ad_hit
    ; out of energy: the game's over (the BASIC sees, when the planet's done)
    lda pl_state
    bne pl_ad_hit           ; (already over)
    lda #PL_LOST
    sta pl_state
    lda #150
    sta pl_endtm
    lda #0
    sta pl_beam
    lda #<tx_lost
    ldy #>tx_lost
    ldx #8
    jsr sp_msgcopy
    lda #0
    sta pl_msgtm
    lda #SFX_LOST
    jmp sfx
pl_ad_hit
    lda #SFX_HIT
    jmp sfx

; button 2 (a fresh press): whatever the shuttle holds drops (it lands,
; to be beamed up again)
pl_dropbtn
    lda sp_fire2
    tax
    eor pl_f2old
    and sp_fire2
    stx pl_f2old
    beq pl_db_r
    lda pl_st
    cmp #PL_FLYING
    bne pl_db_r
    lda pl_hold
    beq pl_db_r
    jsr pl_drop
    lda #SFX_CHIP
    jmp sfx
pl_db_r
    rts

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
; A creature under the beam starts to rise, half a line a frame. Not
; stunned, it struggles: it wriggles a pixel across every 4 frames, and one
; that gets more than BEAM_HALF from the beam's middle drops out. A blinker
; the beam touches (not stunned) blinks away instead. Crates rise at a
; quarter of a line a frame, and don't struggle.
pl_beamwork
    lda #0
    sta pl_beam
    lda sp_fire             ; button 1: the beam
    bne pl_bw_try
    jmp pl_bw_off
pl_bw_try
    lda pl_st
    cmp #PL_FLYING
    beq pl_bw_fly
    jmp pl_bw_off
pl_bw_fly
    lda pl_y
    cmp #BEAM_MINY
    bcs pl_bw_low
    jmp pl_bw_off
pl_bw_low
    lda pl_hold
    beq pl_bw_on
    jmp pl_bw_off
pl_bw_on
    inc pl_beam
    ; something already rising? then nothing else is taken (one at a time)
    lda #0
    sta pl_busy
    ldx #NCR-1
pl_bw_bz
    lda cr_t,x
    beq pl_bw_bz1
    lda cr_st,x
    cmp #CS_LIFT
    bne pl_bw_bz1
    inc pl_busy
pl_bw_bz1
    dex
    bpl pl_bw_bz
    ldx #NCK-1
pl_bw_bk
    lda ck_st,x
    cmp #CS_LIFT+1
    bne pl_bw_bk1
    inc pl_busy
pl_bw_bk1
    dex
    bpl pl_bw_bk
    lda pl_tick
    and #15
    bne pl_bw_go
    lda #SFX_BEAM
    jsr sfx
pl_bw_go
    ldx #NCR-1
pl_bw_c
    stx pl_i
    lda cr_t,x
    bne pl_bw_c1
    jmp pl_bw_cn
pl_bw_c1
    lda cr_st,x
    cmp #CS_LIFT
    beq pl_bw_lift
    cmp #CS_DIE             ; (shot: going)
    bne pl_bw_c1b
    jmp pl_bw_cn
pl_bw_c1b
    cmp #CS_HIDE
    bne pl_bw_c2
    jmp pl_bw_cn
pl_bw_c2
    cmp #CS_HELD
    bne pl_bw_c3
    jmp pl_bw_cn
pl_bw_c3
    lda cr_vis,x
    bne pl_bw_c4
    jmp pl_bw_cn
pl_bw_c4
    lda cr_y,x
    cmp pl_y
    bcs pl_bw_c5
    jmp pl_bw_cn            ; above the shuttle
pl_bw_c5
    lda cr_sx,x
    jsr pl_beamoff          ; how far its middle is from the beam's
    cmp #BEAM_HALF+1
    bcc pl_bw_take
    jmp pl_bw_cn
pl_bw_take
    lda pl_busy             ; one at a time: it walks on past
    beq pl_bw_tk
    jmp pl_bw_cn
pl_bw_tk
    jsr pt_holdfree         ; no room aboard (creatures take holds): it
    ldx pl_i                ;  won't come up
    bcs pl_bw_tk2
    lda pl_msgtm
    bne pl_bw_tkn
    lda #<tx_holdsfull
    ldy #>tx_holdsfull
    ldx #10
    jsr sp_msgcopy
    lda #90
    sta pl_msgtm
    lda #SFX_HIT
    jsr sfx
pl_bw_tkn
    jmp pl_bw_cn
pl_bw_tk2
    inc pl_busy
pl_bw_t2
    lda #CS_LIFT
    sta cr_st,x
pl_bw_lift
    ; it rises half a line a frame
    lda pl_tick
    and #1
    bne pl_bw_wr
    dec cr_y,x
pl_bw_wr
    ; it struggles: a pixel across every 8 frames
    lda pl_tick
    and #7
    bne pl_bw_in
    lda M_RND
    and #1
    sta cr_dir,x
    jsr pl_walk             ; (3/8 of a pixel: three of them)
    jsr pl_walk
    jsr pl_walk
    ldx pl_i
    ; out of the beam: it drops
    ldy cr_xh,x
    lda cr_xl,x
    jsr pl_scrx
    ldx pl_i
    bcc pl_bw_drop
    sta cr_sx,x
    jsr pl_beamoff
    cmp #BEAM_HALF+1
    bcc pl_bw_in
pl_bw_drop
    lda #CS_AIR
    sta cr_st,x
    lda #0
    sta cr_vyl,x
    sta cr_vyh,x
    jmp pl_bw_cn
pl_bw_in
    lda cr_y,x
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
    ldx pl_i
    dex
    bmi pl_bw_crates
    jmp pl_bw_c
pl_bw_crates
    ; crates: a quarter of a line a frame
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
    lda ck_y,x              ; only from under the shuttle (one above it
    cmp pl_y                ;  rose for ever: into the sky)
    bcc pl_bw_kn
    lda ck_sx,x
    jsr pl_beamoff
    cmp #BEAM_HALF+1
    bcs pl_bw_kn
    lda pl_busy             ; one at a time
    bne pl_bw_kn
    inc pl_busy
    lda #CS_LIFT+1
    sta ck_st,x
pl_bw_klift
    lda #3                  ; (the relic: half as fast)
    cpx #RELIC_CK
    bne pl_bw_kl2
    ldy pl_relic
    beq pl_bw_kl2
    lda #7
pl_bw_kl2
    and pl_tick
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
    cpx #RELIC_CK
    bne pl_bw_kh
    ldy pl_relic
    beq pl_bw_kh
    lda #HOLD_RELIC
pl_bw_kh
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

; A = a thing's screen x (8 wide) -> A = how far its middle is from the
; beam's (80), either way
pl_beamoff
    clc
    adc #4
    sec
    sbc #80
    bcs pl_bo_p
    eor #$FF
    adc #1
pl_bo_p
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
    clc
    lda pl_caught
    adc pl_killed
    cmp pl_total
    bne pl_ca_r
    lda #PL_CLEAR
    sta pl_state
    lda #180
    sta pl_endtm
    inc sp_level            ; every one caught: the next level (pace)
    lda pl_killed           ; every one caught (none shot): the bonus
    bne pl_ca_nb
    lda #EN_MAX             ; the Ark's energy full again (as in the original)
    sta sp_energy
    lda gs_test             ; ... and nothing lost on the way: SWEEP
    ora ac_hit
    bne pl_ca_sw
    lda #AC_SWEEP
    jsr ac_set
pl_ca_sw
    lda #$10                ; 1000 points
    sta sc_m
    lda #0
    sta sc_l
    jsr sc_add
pl_ca_nb
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

; ---- the scanner (row 1): the whole planet in 16 characters, 64 pixels
; each: + the towers, # the Ark, * a creature, @ the shuttle. Characters,
; not sprites: sprites cost frames (5 of them here dropped some).
pl_scanner
    ldx #17
pl_sn_c
    lda pl_scanbase,x
    sta pl_scans,x
    dex
    bpl pl_sn_c
    ldx #NCR-1
pl_sn_cr
    lda cr_t,x
    beq pl_sn_crn
    lda cr_st,x
    cmp #CS_HELD
    beq pl_sn_crn
    lda cr_xl,x
    ldy cr_xh,x
    jsr pl_scanix
    lda #CH_SCCR
    sta pl_scans+1,y
pl_sn_crn
    dex
    bpl pl_sn_cr
    lda st_state            ; the storm's rock: !
    cmp #2
    bne pl_sn_nr
    lda sr_xl
    ldy sr_xh
    jsr pl_scanix
    lda #CH_SCROCK
    sta pl_scans+1,y
pl_sn_nr
    lda pl_st               ; the shuttle (docked: the Ark shows)
    cmp #PL_FLYING
    bne pl_sn_r
    lda pl_wx
    ldy pl_wxh
    jsr pl_scanix
    lda #CH_SCSH
    sta pl_scans+1,y
pl_sn_r
    rts

; world x (A lo, Y hi) -> Y = its scanner character, x / 64 (0-15)
pl_scanix
    asl                     ; (lo's top 2 bits into hi)
    sta pl_gt
    tya
    rol
    asl pl_gt
    rol
    and #15
    tay
    rts

; the scanner's line without creatures: "-+-+-+-+#+-+-+-+" (towers at
; 64 + 128 n: characters 1, 3, ...; the Ark at 512: character 8)
pl_scanbase
    .byte CH_SCL
    .byte CH_SCTRK, CH_SCTWR, CH_SCTRK, CH_SCTWR, CH_SCTRK, CH_SCTWR, CH_SCTRK, CH_SCTWR
    .byte CH_SCARK, CH_SCTWR, CH_SCTRK, CH_SCTWR, CH_SCTRK, CH_SCTWR, CH_SCTRK, CH_SCTWR
    .byte CH_SCR

; ---- the HUD (rebuilt every 4th frame: it's text, and frames are tight) ----
;   top (P0):    "000000 VERDA" and a creature each, right: caught (yellow)
;                or still loose (outlined)
;   bottom:      the energy icon and bar (P7) | (P0) the shuttle (or lost),
;                its bay: [ ] empty, a creature, or ore
; the top line's fixed part: blank at 6, the world's name at 7-11 (once)
pl_hudname
    lda #0
    sta hud_top+6
    lda pl_world
    asl
    asl
    adc pl_world            ; * 5
    tax
    ldy #7
pl_hn_w
    lda tx_worlds,x
    sta hud_top,y
    inx
    iny
    cpy #12
    bne pl_hn_w
    rts

pl_hud
    lda pl_tick             ; the top line on one frame in 4, the bottom two
    and #3                  ; frames on (spread: frames are tight)
    beq pl_hud_go
    cmp #2
    bne pl_hud_r
    jmp pl_hud_bot
pl_hud_r
    rts
pl_hud_go
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
    ; (the world's name, 7-11: written once, pl_hudname)
    ldy #12
    lda #0
pl_hd_cl
    sta hud_top,y
    iny
    cpy #20
    bne pl_hd_cl
    ; the creatures: one every other character, the last at 18
    lda pl_total
    beq pl_hd_r
    asl
    sta pl_t0
    sec
    lda #20
    sbc pl_t0
    tay                     ; the first's place (the last at 18)
    ldx #0
pl_hd_cr
    lda #CH_CAUGHT
    cpx pl_caught
    bcc pl_hd_c1
    lda #CH_LOOSE
pl_hd_c1
    sta hud_top,y
    iny
    iny
    inx
    cpx pl_total
    bne pl_hd_cr
pl_hd_r
    rts
pl_hud_bot
    lda #<hud_bot
    sta hwp
    lda #>hud_bot
    sta hwp+1
    lda #CH_ENERGY
    ldx sp_energy
    jsr hud_bar
    ldy #9
    lda #0
pl_hd_bc
    sta hud_bot2,y
    dey
    bpl pl_hd_bc
    lda #CH_SHUT            ; the shuttle, or lost (being rebuilt)
    ldx pl_st
    cpx #PL_DEAD
    bne pl_hd_s
    lda #CH_SHLOST
pl_hd_s
    sta hud_bot2+1
    lda #CH_BAYL
    sta hud_bot2+3
    lda #CH_BAYR
    sta hud_bot2+5
    ldx pl_hold             ; in the bay
    lda pl_baych,x
    sta hud_bot2+4
    rts
pl_baych  .byte 0, CH_CAUGHT, CH_ORE, CH_ORE

; ---------------------------------------------------------------------------
; Drawing (the BASIC has drawn the Ark and the ground). Creatures first:
; zone 9, where they stand, has the most in it, and if MARIA runs short of
; time on a line it's the last objects that go. Then crates, towers and
; turrets, the beam, the shuttle (or its wreck), shots, the pulse, the
; scanner.
pl_draw
    ; creatures: kind * 4 + facing * 2 + step; two bytes a frame
    ldx #NCR-1
pl_dw_c
    stx pl_i
    lda cr_vis,x
    beq pl_dw_cn
    lda cr_st,x             ; shot: an explosion
    cmp #CS_DIE
    bne pl_dw_cv
    lda cr_sx,x
    sta temp4
    sec
    lda cr_y,x
    sbc #8
    sta temp5
    lda cr_tm,x
    jsr dr_boomf
    PLOT boom0, 4
    jmp pl_dw_cn
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
    bmi pl_dw_c_far2360
    jmp pl_dw_c
pl_dw_c_far2360

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
    cpx #RELIC_CK           ; the relic: the beam's palette (it shimmers)
    bne pl_dw_kc
    ldy pl_relic
    beq pl_dw_kc
    PLOT crate, 3
    jmp pl_dw_kn
pl_dw_kc
    PLOT crate, 5
pl_dw_kn
    ldx pl_i
    dex
    bpl pl_dw_k

    ; towers: from the guns (df_y) down to the ground (160: towers stand on
    ; the top level), 16-line pieces from the ground up and one at the top;
    ; the gun on top (flashing in another colour as it's about to fire)
    ldx #NTT-1
pl_dw_t
    stx pl_i
    lda tt_vis,x
    bne pl_dw_t1
    jmp pl_dw_tn
pl_dw_t1
    lda #144
    sta pl_t0
pl_dw_seg
    clc
    lda df_y
    adc #8
    cmp pl_t0
    bcs pl_dw_stop
    jsr pl_towerpc
    sec
    lda pl_t0
    sbc #16
    sta pl_t0
    jmp pl_dw_seg
pl_dw_stop
    sta pl_t0               ; the top piece, under the gun
    jsr pl_towerpc
    ldx pl_i
    lda tt_sx,x
    sta temp4
    lda df_y
    sta temp5
    lda df_cool             ; warning: the gun flashes
    cmp #DF_WARN
    bcs pl_dw_tt
    lda df_pulse
    bne pl_dw_tt
    lda pl_tick
    and #4
    beq pl_dw_tt
    lda #0
    PLOT turret, 1
    jmp pl_dw_tn
pl_dw_tt
    lda #0
    PLOT turret, 4
pl_dw_tn
    ldx pl_i
    dex
    bmi pl_dw_pulse
    jmp pl_dw_t

    ; the pulse: right across the screen at the guns' height (two 80-wide
    ; pieces)
pl_dw_pulse
    lda df_pulse
    beq pl_dw_beam
    lda #1
    sta temp4
    sec
    lda df_py
    sbc #1
    sta temp5
    lda #0
    PLOT pulse, 4
    lda #80
    sta temp4
    sec
    lda df_py
    sbc #1
    sta temp5
    lda #0
    PLOT pulse, 4

    ; the beam, exactly from the shuttle (pl_y + 4) to the ground (pl_gnd):
    ; 16-line pieces from the ground up while they fit, and one more at the
    ; top (overlapping: it's the same column)
pl_dw_beam
    lda pl_beam
    beq pl_dw_nob
    sec
    lda pl_gnd              ; the ground under the shuttle
    sbc #16
    sta pl_t0
pl_dw_bs
    lda pl_y
    clc
    adc #4
    cmp pl_t0
    bcs pl_dw_btop          ; this piece would start above the shuttle
    jsr pl_beampc
    sec
    lda pl_t0
    sbc #16
    sta pl_t0
    jmp pl_dw_bs
pl_dw_btop
    sta pl_t0               ; the top piece, at the shuttle
    jsr pl_beampc
pl_dw_nob

    ; the storm's rock, and the Ark's bolt
    lda st_state
    cmp #2
    bne pl_dw_nr
    lda sr_vis
    beq pl_dw_nr
    lda sr_sx
    sta temp4
    lda sr_y
    sta temp5
    lda #0
    PLOT rock_l, 4
pl_dw_nr
    lda ab_t
    beq pl_dw_nab
    lda ab_x
    sta temp4
    lda ab_y
    sta temp5
    lda ab_d
    PLOT bolt0, 3
pl_dw_nab

    ; the Ark's tunnel, under it in orbit (where the shuttle docks)
    lda pl_arkv
    beq pl_dw_nt
    lda pl_arky
    cmp #PL_ARKY
    bne pl_dw_nt
    clc
    lda pl_arksx
    adc #20                 ; (the Ark's middle - 4)
    sta pl_t0
    sta temp4
    lda #TUNNEL_Y
    sta temp5
    lda #0
    PLOT tunnel, 1
pl_dw_nt

    ; the shuttle, or its wreck while the Ark builds another
    lda pl_st
    cmp #PL_DEAD
    bne pl_dw_sh
    lda pl_dead
    cmp #PL_REBUILD-17
    bcc pl_dw_ns
    lda pl_boomx
    sta temp4
    lda pl_boomy
    sta temp5
    lda pl_dead
    sec
    sbc #PL_REBUILD-17      ; 17 down to 0
    jsr dr_boomf
    PLOT boom0, 4
    jmp pl_dw_ns
pl_dw_sh
    lda pl_st               ; docked: inside the Ark, not seen
    cmp #PL_DOCKED
    beq pl_dw_ns
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


    rts

; a tower piece at line pl_t0 (tower pl_i)
pl_towerpc
    ldx pl_i
    lda tt_sx,x
    sta temp4
    lda pl_t0
    sta temp5
    lda #0
    PLOT tower, 4
    rts

; a beam piece at line pl_t0
pl_beampc
    lda #76
    sta temp4
    lda pl_t0
    sta temp5
    lda pl_tick
    and #2                  ; (frame 0 or 1, two bytes wide)
    PLOT beam0, 3
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

