; ===========================================================================
; The sector map (bank 4): the galaxy, the sector view, the star chart,
; travel. docs/DESIGN.md 3.
;
; The galaxy: 64 sectors on a hidden 12 x 8 grid, each linked by warps to
; its 8 neighbours (one bit a direction, 0 up, clockwise, as the joystick).
; Built from a seed (the New Game press) with the math unit's generator:
; a random spanning tree (every sector reachable, both ways), extra warps,
; a few of those made one-way; sectors numbered by their distance from home
; (a breadth-first search), so a low number is near and safe; tiers from the
; number; ports, planets and nebulae laid out by tier.
;
; The screens are 320A, 1-byte characters, 40 columns (sv_enter switches
; 7800basic's saved CTRL and CHARBASE: drawscreen puts them in each frame;
; sv_leave puts the game's back). Text in RAM, 12 rows of 40, in colour
; (text40.asm). Every page has the same frame: a tab bar on row 0 (button 2
; steps through SECTOR, CHART, CLOSE UP, ACHIEVE) and the status panel on
; rows 10-11 (DESIGN.md 3.6b).
;
; The BASIC: newgame calls gx_new; the sector loop calls sv_frame each
; frame; sv_frame sets gs_go: 1 deep space (an encounter on the way), 2 land
; on the planet. Coming back, sv_enter arrives at gs_dest.
; ===========================================================================

BANK_MAP  = 4

; ---- game state (the hardware check's RAM: free once a game's begun) ----
gs_sec    = $2590   ; the Ark's sector (0-63, shown 1-64)
                    ; ($2591: free: no fuel any more)
gs_date   = $2592   ; the stardate (2 bytes, binary)
gs_cred   = $2594   ; credits (3 bytes BCD, high first)
gs_seed   = $2597   ; the galaxy's seed (4 bytes)
gs_go     = $259B   ; for the BASIC: 0 stay, 1 deep space, 2 the planet,
                    ;   3 the achievements
gs_dest   = $259C   ; where the Ark's going (arrives on sv_enter)
gs_msg    = $259D   ; a message on row 2: 0 none, else MSG_*
; what the Ark carries, and its upgrades (port.asm)
gs_ore    = $2585   ; fuel ore, organics, equipment (in the holds)
gs_org    = $2586
gs_eqp    = $2587
gs_ulas   = $2588   ; upgrades: the hull (0-20: +5 energy each), the holds (0-2),
gs_uhold  = $2589   ;   the fuel tanks
gs_sold   = $258A   ; goods sold at ports (MERCHANT; at most 255)
gs_stasis = $256B   ; [6] creatures in stasis, by kind
; the voyage's long-lived state ($25A0-$25EF: saved with the game)
gs_keep   = $25A0   ; [6] the manifest: specimens kept, by kind (0-2: a pair)
gs_bank   = $25A6   ; the bank (3 bytes BCD, high first): kept when the Ark's lost
pt_stock  = $25A9   ; [33] each port's stock (11 ports x 3 goods, 0-15): what
                    ;   it has to sell, or what it's bought (it wants 15 - that)
pt_glut   = $25CA   ; [11] creatures each port's bought lately (bounties fall)
gs_miss   = $25D5   ; [32] creatures taken from each planet lately, a nibble
                    ;   a sector (sector / 2; odd sectors the high nibble)
gs_ach    = $25F5   ; [2] achievements earned (a bit each)
gs_kills  = $25F7   ; [2] pirates destroyed (binary)
gs_storms = $25F9   ; storm rocks shot down
gs_relic  = $25FA   ; the relic's sector
gs_relst  = $25FB   ; the relic: 0 on its planet, 1 aboard, 2 delivered
gs_tick   = $25FC   ; jumps, for restocking: ports every 2, planets every 3
gs_tick3  = $25FD
                    ; ($25FE-$25FF: gs_achn, text40.asm)
gs_pop    = $2572   ; the planet being landed on: its creatures (surface.asm)
gs_plevel = $258E   ; ... and its level (1-5: gx_plevel)
GS_LONG   = $25A0   ; (the block: GS_LONGN bytes from here)
GS_LONGN  = $60
PT_NPORTS = 11
PT_NORMAL = 12      ; a port's stock of what it sells, restocked
PT_FULL   = 15
PL_POP    = 4       ; a planet's creatures, at most (gs_miss takes from it)
gs_test   = $259F   ; (tests set it: fire on the title goes straight into
                    ;   deep space, waves then planets, as before the map)

; ---- the galaxy, by sector ($2600-$26FF: the hardware check's) ----
gx_warp   = $2600   ; [64] warp bits (direction d: to the neighbour that way)
gx_cell   = $2640   ; [64] its grid cell: row * 16 + column
gx_info   = $2680   ; [64] type (bits 0-1), class or world (2-4), tier (6-7)
gx_flag   = $26C0   ; [64] 1 visited, 2 seen (next to a visited one); bits
                    ;   2-7: jumps back to safe space (the encounters' strength)

GT_EMPTY  = 0
GT_PORT   = 1
GT_PLANET = 2
GT_NEBULA = 3

; (holds by upgrade level: up_holds in common.asm)

; ---- the screens' scratch (the planet's RAM: free on the map) ----
; text rows 0-5 at $2200, 6-11 at $2700 (40 each)
sv_items  = $22F0   ; [10] the sector view's items: a sector, or $80 land,
                    ;   $81 dock
sv_nitems = $22FA
sv_sel    = $22FB   ; the selected item
sv_view   = $22FC   ; 0 the sector, 1 the chart
sv_pjoy   = $22FD   ; last frame's stick and buttons (fresh presses)
sv_pf     = $22FE
sv_pf2    = $22FF
sv_tick   = $27F0
sv_t0     = $27F1
sv_t1     = $27F2
sv_t2     = $27F3
sv_t3     = $27F4
sv_mx     = $27F5   ; the chart's marker: x, row
sv_my     = $27F6
sv_dirty  = $27F7   ; rebuild the text
sv_t4     = $27F8
; (more, in deep space's RAM: free on the map; text40.asm)
sv_itr    = $24AA   ; the sector view's item being written: its row, column
sv_itc    = $24BE
sv_idir   = $24B5   ; [9] each item's way (a warp: 0 up, clockwise)
ch_rep    = $24BF   ; the chart's cursor: frames to its next step (held)
sv_dg     = $237C   ; sv_dirto: the sector, the way being tried
sv_dk     = $237D
ch_cx     = $237E   ; the chart's cursor: its cell's column, row
ch_cy     = $237F
; the generator's (cell-indexed: row * 16 + column, 128)
gc_w      = $2200   ; [128] warp bits
gc_s      = $2280   ; [128] $FF free, else the sector (or $FE: taken)
gc_list   = $2700   ; [64] cells taken, in order
gc_ext    = $2740   ; [32] extra warps (cell, direction) for one-way ones
gc_n      = $27F9
gc_ne     = $27FA

sv_src    = $B9     ; zero page pointers (the hardware check's)
sv_dst    = $BB

MSG_REFUEL = 1
MSG_DRIFT = 2
MSG_BARREN = 3
MSG_POD   = 4
MSG_ACH   = 5       ; (ACHIEVEMENT: its name; gs_achi)

; ---------------------------------------------------------------------------
; a random number below A (A > 0): (rnd * A) / 256
gx_rand
    sta M_B
    lda M_RND
    sta M_A
    lda #0
    sta M_A+1
    sta M_B+1
    sta M_CTRL
    lda M_P+1
    rts

; the neighbour of cell A in direction X: A = its cell, C = 1 if off the grid
gx_nb
    sta sv_t0
    and #15
    clc
    adc gx_dcol,x
    cmp #12
    bcs gx_nb_r             ; (negative reads as big)
    sta sv_t1
    lda sv_t0
    lsr
    lsr
    lsr
    lsr
    clc
    adc gx_drow,x
    cmp #8
    bcs gx_nb_r
    asl
    asl
    asl
    asl
    ora sv_t1
    clc
gx_nb_r
    rts
gx_dcol   .byte 0, 1, 1, 1, 0, -1, -1, -1
gx_drow   .byte -1, -1, 0, 1, 1, 1, 0, -1
gx_bit    .byte 1, 2, 4, 8, 16, 32, 64, 128

; ---------------------------------------------------------------------------
; A new galaxy and a new voyage. The seed: gs_seed (the BASIC fills it from
; the press's timing).
gx_new
    ldx #0
gx_n_seed
    lda gs_seed,x
    sta M_RND               ; (a write shifts a seed byte in)
    inx
    cpx #4
    bne gx_n_seed
    ldx #127
gx_n_clr
    lda #0
    sta gc_w,x
    lda #$FF
    sta gc_s,x
    dex
    bpl gx_n_clr
    ; the first cell: home
    lda #8
    jsr gx_rand
    asl
    asl
    asl
    asl
    sta sv_t2
    lda #12
    jsr gx_rand
    ora sv_t2
    sta gc_list
    tax
    lda #$FE
    sta gc_s,x
    lda #1
    sta gc_n
    ; grow a tree: a taken cell, a direction; a free neighbour joins
gx_n_grow
    lda gc_n
    jsr gx_rand
    tax
    lda gc_list,x
    sta sv_t2               ; the cell
    lda #8
    jsr gx_rand
    sta sv_t3               ; the direction
    tax
    lda sv_t2
    jsr gx_nb
    bcs gx_n_grow
    tay
    lda gc_s,y
    cmp #$FF
    bne gx_n_grow
    lda #$FE
    sta gc_s,y
    tya
    ldx gc_n
    sta gc_list,x
    inc gc_n
    jsr gx_link
    lda gc_n
    cmp #64
    bne gx_n_grow
    ; extra warps between taken neighbours (some made one-way below)
    lda #0
    sta gc_ne
    lda #60
    sta sv_t4
gx_n_ex
    lda #64
    jsr gx_rand
    tax
    lda gc_list,x
    sta sv_t2
    lda #8
    jsr gx_rand
    sta sv_t3
    tax
    lda sv_t2
    jsr gx_nb
    bcs gx_n_exn
    tay
    lda gc_s,y
    cmp #$FE
    bne gx_n_exn
    ldx sv_t2               ; (already linked?)
    lda gc_w,x
    ldx sv_t3
    and gx_bit,x
    bne gx_n_exn
    jsr gx_link
    ldx gc_ne               ; remember it
    cpx #16
    bcs gx_n_exn
    lda sv_t2
    sta gc_ext,x
    lda sv_t3
    sta gc_ext+16,x
    inc gc_ne
gx_n_exn
    dec sv_t4
    bne gx_n_ex
    ; the first few extras one-way (the way back cut: the tree keeps every
    ; sector reachable both ways)
    ldx #0
gx_n_ow
    cpx gc_ne
    bcs gx_n_owd
    cpx #5
    bcs gx_n_owd
    stx sv_t4
    lda gc_ext+16,x
    sta sv_t3
    ldx sv_t4
    lda gc_ext,x
    ldx sv_t3
    jsr gx_nb
    tay                     ; the far end
    lda sv_t3
    eor #4                  ; its way back
    tax
    lda gx_bit,x
    eor #$FF
    and gc_w,y
    sta gc_w,y
    ldx sv_t4
    inx
    bne gx_n_ow
gx_n_owd
    ; number the sectors by distance from home: breadth-first over the warps
    ; (gc_list becomes the order; the tree's two-way warps reach them all)
    lda gc_list             ; home
    tax
    lda #0
    sta gc_s,x
    ldy #1                  ; sectors numbered
    ldx #0                  ; the queue's head
gx_n_bfs
    stx sv_t4
    sty gc_n
    lda gc_list,x
    sta sv_t2
    ldx #0
gx_n_bd
    stx sv_t3
    ldy sv_t2
    lda gc_w,y
    and gx_bit,x
    beq gx_n_bdn
    lda sv_t2
    jsr gx_nb
    tay
    lda gc_s,y
    cmp #$FE                ; taken, not numbered yet
    bne gx_n_bdn
    lda gc_n
    sta gc_s,y
    tax
    tya
    sta gc_list,x
    inc gc_n
gx_n_bdn
    ldx sv_t3
    inx
    cpx #8
    bne gx_n_bd
    ldy gc_n
    ldx sv_t4
    inx
    cpx gc_n
    bne gx_n_bfs
    ; by sector: warps, cells; types by tier
    ldx #63
gx_n_sec
    lda gc_list,x
    sta gx_cell,x
    tay
    lda gc_w,y
    sta gx_warp,x
    lda #0
    sta gx_flag,x
    txa                     ; the tier: 0-9 safe, 10-14 core, 15-39 mid, 40-63 outer
    ldy #3
    cmp #40
    bcs gx_n_t
    dey
    cmp #15
    bcs gx_n_t
    dey
    cmp #10
    bcs gx_n_t
    dey
gx_n_t
    tya
    lsr
    ror
    ror                     ; (tier to bits 6-7)
    sta sv_t0
    ; what's there: planets 40%, nebulae 12% (not in safe space), else empty
    lda #100
    jsr gx_rand
    ldy #GT_EMPTY
    cmp #40
    bcs gx_n_nb
    ldy #GT_PLANET
    lda #6                  ; its world
    jsr gx_rand
    asl
    asl
    ora #GT_PLANET
    tay
    lda #2                  ; half of them a level easier (bit 5: gx_plevel)
    jsr gx_rand
    beq gx_n_ty
    tya
    ora #$20
    tay
    bne gx_n_ty
gx_n_nb
    cmp #52
    bcs gx_n_ty
    cpx #10
    bcc gx_n_ty
    ldy #GT_NEBULA
gx_n_ty
    tya
    ora sv_t0
    sta gx_info,x
    dex
    bpl gx_n_sec
    ; each sector's jumps back to safe space (following the warps, so
    ; one-way ones count): gx_flag bits 2-7. Safe space 0; the rest
    ; relaxed until nothing changes (gc_s: cell -> sector still)
    ldx #63
gx_n_di
    lda #63 << 2
    cpx #10
    bcs gx_n_d0
    lda #0
gx_n_d0
    sta gx_flag,x
    dex
    bpl gx_n_di
gx_n_dpass
    lda #0
    sta gc_ne               ; (changed)
    ldx #63
gx_n_dk
    stx sv_t4
    lda gx_cell,x
    sta sv_t2
    ldx #0
gx_n_dd
    stx sv_t3
    ldy sv_t4
    lda gx_warp,y
    and gx_bit,x
    beq gx_n_ddn
    lda sv_t2
    jsr gx_nb
    tay
    lda gc_s,y              ; the sector that way
    tay
    lda gx_flag,y
    clc
    adc #1 << 2             ; its distance + 1
    bcs gx_n_ddn            ; (not reached yet: 63 + 1 would wrap)
    ldy sv_t4
    cmp gx_flag,y
    bcs gx_n_ddn
    sta gx_flag,y
    inc gc_ne
gx_n_ddn
    ldx sv_t3
    inx
    cpx #8
    bne gx_n_dd
    ldx sv_t4
    dex
    cpx #10
    bcs gx_n_dk
    lda gc_ne
    bne gx_n_dpass
    ; ports: home, two more in safe space, two in the core, three mid-rim,
    ; three in the outer rim (TradeWars classes: buys/sells a bit each),
    ; never two in one sector. Home buys everything (BBB), the first of
    ; safe space's others sells everything (SSS): a trade to start on.
    lda #0
    jsr gx_port
    lda gx_info
    and #$E3
    sta gx_info
    ldy #0
gx_n_pt
    lda gx_pfrom,y
    sta sv_t3
    lda gx_pspan,y
    jsr gx_rand
    clc
    adc sv_t3
    tax
    lda gx_info,x
    and #3
    cmp #GT_PORT
    beq gx_n_pt             ; (one there already: again)
    txa
    jsr gx_port
    cpy #0
    bne gx_n_pt2
    lda gx_info,x
    ora #$1C
    sta gx_info,x
gx_n_pt2
    iny
    cpy #PT_NPORTS-1
    bne gx_n_pt
    ; the voyage
    lda #0
    sta gs_sec
    sta gs_dest
    sta gs_date
    sta gs_date+1
    sta gs_cred
    sta gs_msg
    lda #$05                ; 500 credits
    sta gs_cred+1
    lda #0
    sta gs_cred+2
    lda #0                  ; nothing aboard, no upgrades
    ldx #5
gx_n_inv
    sta gs_stasis,x
    dex
    bpl gx_n_inv
    sta gs_ore
    sta gs_org
    sta gs_eqp
    sta gs_ulas
    sta gs_uhold
    sta gs_sold
    jsr en_setmax           ; (the hull as new: sp_energy's sp_new's)
    lda #0
    ldx #GS_LONGN-1         ; the long-lived block: all clear
gx_n_lg
    sta GS_LONG,x
    dex
    bpl gx_n_lg
    ; each port's stock: PT_NORMAL of what it sells, none bought
    ldx #0                  ; (sector)
    ldy #0                  ; (stock index)
gx_n_st
    lda gx_info,x
    and #3
    cmp #GT_PORT
    bne gx_n_st2
    lda gx_info,x
    lsr
    lsr
    sta sv_t0               ; (class bits: 1 sells)
    lda #3
    sta sv_t1
gx_n_st3
    lda #0
    lsr sv_t0
    bcc gx_n_st4
    lda #PT_NORMAL
gx_n_st4
    sta pt_stock,y
    iny
    dec sv_t1
    bne gx_n_st3
gx_n_st2
    inx
    cpx #64
    bne gx_n_st
    ; the relic: on a planet in the outer rim (from a random place on; none
    ; there, any planet)
    lda #64
    jsr gx_rand
    tax
    lda #$C0                ; (the tier wanted: outer rim, then any)
    sta sv_t0
gx_n_rp
    ldy #64
gx_n_rl
    lda gx_info,x
    and #3
    cmp #GT_PLANET
    bne gx_n_rn
    lda gx_info,x
    and sv_t0
    cmp sv_t0
    beq gx_n_rf
gx_n_rn
    inx
    txa
    and #63
    tax
    dey
    bne gx_n_rl
    lda sv_t0
    beq gx_n_rf             ; (no planets at all: wherever)
    lda #0
    sta sv_t0
    beq gx_n_rp
gx_n_rf
    stx gs_relic
    rts
gx_pfrom  .byte 1, 1, 10, 10, 15, 23, 31, 40, 48, 56
gx_pspan  .byte 9, 9, 5, 5, 8, 8, 9, 8, 8, 8

; sector A becomes a port (keeps its tier), a random class
gx_port
    tax
    sty sv_t4
    lda #8
    jsr gx_rand
    asl
    asl
    ora #GT_PORT
    sta sv_t0
    lda gx_info,x
    and #$C0
    ora sv_t0
    sta gx_info,x
    ldy sv_t4
    rts

; link cell sv_t2 to its neighbour Y the way sv_t3 (both ways)
gx_link
    ldx sv_t3
    lda gx_bit,x
    ldx sv_t2
    ora gc_w,x
    sta gc_w,x
    lda sv_t3
    eor #4
    tax
    lda gx_bit,x
    ora gc_w,y
    sta gc_w,y
    rts

; ---------------------------------------------------------------------------
; the sector in direction X from sector A: A = it (C = 1: none that way)
gx_warpto
    sta sv_t2
    tay
    lda gx_warp,y
    and gx_bit,x
    beq gx_wt_no
    lda gx_cell,y
    jsr gx_nb
    bcs gx_wt_no
    ldy #63
gx_wt_l
    cmp gx_cell,y
    beq gx_wt_y
    dey
    bpl gx_wt_l
gx_wt_no
    sec
    rts
gx_wt_y
    tya
    clc
    rts

; a jump's gone by: each port's stock a step back to normal (what it sells
; up to PT_NORMAL, what it's bought down to none) and its glut of creatures
; down one; every 3, each planet's creatures one back (gs_miss). (Leaves
; sv_t3 alone: sv_warp's.)
gx_restock
    inc gs_tick
    ldx #0                  ; (sector)
    ldy #0                  ; (stock index)
    sty gc_n                ; (port)
gx_rs_s
    lda gx_info,x
    and #3
    cmp #GT_PORT
    bne gx_rs_n
    lda gx_info,x
    lsr
    lsr
    sta gc_ne               ; (class bits: 1 sells)
    txa
    pha
    ldx #3
gx_rs_k
    lsr gc_ne
    lda pt_stock,y
    bcc gx_rs_b
    cmp #PT_NORMAL          ; sells: up to normal
    bcs gx_rs_kn
    adc #1
    bne gx_rs_ks
gx_rs_b
    cmp #0                  ; buys: down to none
    beq gx_rs_kn
    sbc #1                  ; (C = 1 after the cmp)
gx_rs_ks
    sta pt_stock,y
gx_rs_kn
    iny
    dex
    bne gx_rs_k
    ldx gc_n
    lda pt_glut,x
    beq gx_rs_g
    dec pt_glut,x
gx_rs_g
    inc gc_n
    pla
    tax
gx_rs_n
    inx
    cpx #64
    bne gx_rs_s
gx_rs_pl
    inc gs_tick3
    lda gs_tick3
    cmp #3
    bcc gx_rs_r
    lda #0
    sta gs_tick3
    ldx #31
gx_rs_p
    lda gs_miss,x
    tay
    and #$0F
    beq gx_rs_p1
    dey
gx_rs_p1
    tya
    and #$F0
    beq gx_rs_p2
    tya
    sec
    sbc #$10
    tay
gx_rs_p2
    tya
    sta gs_miss,x
    dex
    bpl gx_rs_p
gx_rs_r
    rts

; the creatures sector X's planet has now (PL_POP - those taken lately, at
; least 0): A
gx_pop
    txa
    lsr
    tay
    lda gs_miss,y
    bcc gx_pp_lo
    lsr
    lsr
    lsr
    lsr
gx_pp_lo
    and #$0F
    sta gc_ne
    lda #PL_POP
    sec
    sbc gc_ne
    bcs gx_pp_r
    lda #0
gx_pp_r
    rts

; The Ark's lost, the escape pod home (the BASIC's escape scene): home
; again in a new Ark, as at the start (fuel, energy, no upgrades, the holds
; and the bays empty), with a tenth of the credits. Kept: the bank, the
; chart, the achievements, the galaxy's ports and planets as they are.
gx_lost
    lda #0
    sta gs_sec
    sta gs_dest
    sta gs_ore
    sta gs_org
    sta gs_eqp
    sta gs_ulas
    sta gs_uhold
    ldx #5
gx_ls_k
    sta gs_stasis,x
    sta gs_keep,x
    dex
    bpl gx_ls_k
    lda gs_relst            ; the relic aboard: back on its planet
    cmp #2
    beq gx_ls_r
    lda #0
    sta gs_relst
gx_ls_r
    jsr en_setmax
    lda sp_enmax
    sta sp_energy
    ldx #4                  ; credits / 10 (a BCD digit)
gx_ls_c
    lsr gs_cred
    ror gs_cred+1
    ror gs_cred+2
    dex
    bne gx_ls_c
    lda #MSG_POD
    sta gs_msg
    lda #AC_POD
    jmp ac_set

; sector X's planet's level (A, 1-5): by its number (near home low, the
; rim high: harder, rarer creatures), one less if it's an easy one (bit 5 of
; gx_info; never below 1). Safe space's are all level 1.
gx_plevel
    txa
    ldy #0
gx_pl_l
    cmp gx_plth,y
    bcc gx_pl_d
    iny
    cpy #4
    bne gx_pl_l
gx_pl_d
    iny
    lda gx_info,x
    and #$20
    beq gx_pl_r
    cpy #2
    bcc gx_pl_r
    dey
gx_pl_r
    tya
    rts
gx_plth   .byte 10, 16, 28, 44

; the Ark arrives at gs_dest: visited, its neighbours seen
gx_arrive
    lda gs_dest
    sta gs_sec
    tax
    lda gx_flag,x
    ora #1
    sta gx_flag,x
    ldx #7
gx_ar_l
    stx sv_t3
    lda gs_sec
    jsr gx_warpto
    bcs gx_ar_n
    tay
    lda gx_flag,y
    ora #2
    sta gx_flag,y
gx_ar_n
    ldx sv_t3
    dex
    bpl gx_ar_l
    rts

; ===========================================================================
; The screens
; ===========================================================================
sv_enter
    lda #%01000011          ; 320A, 1-byte characters (DMA on)
    sta sCTRL
    lda #>font320
    sta sCHARBASE
    lda #0
    sta sv_view
    sta sv_sel
    sta gs_go
    lda #8
    sta sv_pjoy
    lda #1
    sta sv_pf
    sta sv_pf2
    sta sv_dirty
    jmp gx_arrive

sv_leave
    lda #%01010000          ; the game's: 160A, 2-byte characters
    sta sCTRL
    lda #>font
    sta sCHARBASE
    rts

; a frame: input, the text (when it changes), drawn
sv_frame
    inc sv_tick
    lda sv_view
    bne sv_f_chart
    jsr sv_input
    jmp sv_f_draw
sv_f_chart
    cmp #2
    bne sv_f_ch
    jsr pt_input
    jmp sv_f_draw
sv_f_ch
    jsr ch_input
sv_f_draw
    lda sv_dirty
    beq sv_f_nd
    lda #0
    sta sv_dirty
    lda sv_view
    bne sv_f_bc
    jsr sv_build
    jmp sv_f_nd
sv_f_bc
    cmp #2
    bne sv_f_bch
    jsr pt_build
    jmp sv_f_nd
sv_f_bch
    jsr ch_build
sv_f_nd
    lda sp_joy
    sta sv_pjoy
    lda sp_fire
    sta sv_pf
    lda sp_fire2
    sta sv_pf2
    jsr sv_rows
    lda sv_view
    cmp #1
    bne sv_f_r
    jsr ch_nodes
    ; the chart's cursor (white brackets), and the marker on the Ark's
    ; sector (gold, blinking)
    lda #<ch_curs
    sta temp1
    lda #>ch_curs
    sta temp2
    lda #(P_WHITE << 5) | 31 ; (1 wide)
    sta temp3
    lda ch_cx
    asl
    adc ch_cx
    adc #2                  ; (its column: 2 + 3 x)
    asl
    asl                     ; (4 units a character)
    sta temp4
    lda ch_cy
    clc
    adc #1
    sta temp5
    jsr plotcharacters
    lda sv_tick
    and #16
    bne sv_f_r
    lda #<ch_mark
    sta temp1
    lda #>ch_mark
    sta temp2
    lda #(P_GOLD << 5) | 31
    sta temp3
    lda sv_mx
    sta temp4
    lda sv_my
    sta temp5
    jsr plotcharacters
sv_f_r
    rts
ch_mark   .byte 176
ch_curs   .byte 244

; ---------------------------------------------------------------------------
; The sector view
;   0  the tab bar (SECTOR)
;   1  SECTOR 12  CORE                STARDATE 0034
;   2  STARPORT  CLASS BSB
;   3  (a message)
;   4-8 the items, two a row: LAND / DOCK, then the warps, each its way
;      from here, a red > if there's no way back, its number, what's known
;      there:  NE >12  VERDA L3
;   9  the help
;   10-11 the status panel
sv_build
    jsr sv_cls
    lda #0                  ; the frame
    ldx #0
    ldy #4
    jsr sv_tabbar
    jsr sv_status
    ; the items: what's here, then the warps (and the way each goes)
    ldy #0
    ldx gs_sec
    lda gx_info,x
    and #3
    cmp #GT_PLANET
    bne sv_b_np
    lda #$80
    sta sv_items,y
    iny
sv_b_np
    cmp #GT_PORT
    bne sv_b_nd
    lda #$81
    sta sv_items,y
    iny
sv_b_nd
    ldx #0
sv_b_w
    stx sv_t3
    sty sv_t4
    lda gs_sec
    jsr gx_warpto
    ldy sv_t4
    bcs sv_b_wn
    sta sv_items,y
    lda sv_t3
    sta sv_idir,y
    iny
sv_b_wn
    ldx sv_t3
    inx
    cpx #8
    bne sv_b_w
    sty sv_nitems
    ; row 1: the sector, its tier; the stardate
    ldx #1
    lda #1
    jsr sv_at
    lda #P_CYAN
    jsr sv_pen
    lda #<tx_sector
    ldy #>tx_sector
    ldx #7
    jsr sv_puts
    lda #P_WHITE
    jsr sv_pen
    lda gs_sec
    clc
    adc #1
    jsr sv_dec2
    lda #2
    jsr sv_skip
    ldx gs_sec
    jsr sv_tier
    ldx #1
    lda #26
    jsr sv_at
    lda #P_CYAN
    jsr sv_pen
    lda #<tx_date
    ldy #>tx_date
    ldx #9
    jsr sv_puts
    lda #P_WHITE
    jsr sv_pen
    lda gs_date
    sta sv_t0
    lda gs_date+1
    sta sv_t1
    jsr sv_dec4
    ; row 2: what's here
    ldx #2
    lda #1
    jsr sv_at
    ldx gs_sec
    jsr sv_what
    ; row 3: a message (or, with none, a new achievement), in gold
    lda gs_msg
    bne sv_b_na
    jsr ac_new
    bcc sv_b_na
    lda #MSG_ACH
    sta gs_msg
    lda #SFX_CLEAR
    jsr sfx
sv_b_na
    lda gs_msg
    beq sv_b_nm
    ldx #3
    lda #1
    jsr sv_at
    lda #P_GOLD
    jsr sv_pen
    lda gs_msg
    cmp #MSG_ACH
    bne sv_b_mm
    lda #<tx_mach
    ldy #>tx_mach
    ldx #13
    jsr sv_puts
    lda gs_achi             ; its name: ac_names + 9 x
    asl
    asl
    asl
    adc gs_achi
    adc #<ac_names
    pha
    lda #>ac_names
    adc #0
    tay
    pla
    ldx #9
    jsr sv_puts
    jmp sv_b_nm
sv_b_mm
    ldx gs_msg
    lda sv_msglo-1,x
    pha
    lda sv_msghi-1,x
    tay
    lda sv_msglen-1,x
    tax
    pla
    jsr sv_puts
sv_b_nm
    ; the items: rows 4-8, two a row (20 columns each, its bar 19 wide)
    ldx #0
sv_b_it
    cpx sv_nitems
    bcc sv_b_it1
    jmp sv_b_itd
sv_b_it1
    stx sv_t3
    txa
    lsr
    clc
    adc #4
    sta sv_itr               ; (its row)
    lda sv_t3
    and #1
    beq sv_b_c0
    lda #20
sv_b_c0
    sta sv_itc               ; (its column)
    ldx sv_t3               ; the selected one: a gold bar, all one colour
    cpx sv_sel
    bne sv_b_ns
    ldx sv_itr
    lda sv_itc
    ldy #P_GOLD
    jsr sv_ink
    lda #1
    sta sv_lock
sv_b_ns
    ldx sv_itr
    lda sv_itc
    clc
    adc #1
    jsr sv_at
    ldx sv_t3
    lda sv_items,x
    bmi sv_b_act
    ; a warp: its way, one-way or not, its number, what's known there
    sta sv_t2
    lda #P_CYAN
    jsr sv_pen
    ldx sv_t3
    lda sv_idir,x
    asl
    adc #<tx_dirs
    pha
    lda #>tx_dirs
    adc #0
    tay
    pla
    ldx #2
    jsr sv_puts
    lda #1
    jsr sv_skip
    ldx sv_t3               ; no way back: >
    lda sv_idir,x
    eor #4
    tax
    ldy sv_t2
    lda gx_warp,y
    and gx_bit,x
    bne sv_b_2w
    lda #P_RED
    jsr sv_pen
    lda #(">"-32)*2
    jsr sv_putc
    jmp sv_b_num
sv_b_2w
    lda #1
    jsr sv_skip
sv_b_num
    lda #P_WHITE
    jsr sv_pen
    lda sv_t2
    clc
    adc #1
    jsr sv_dec2
    lda #2
    jsr sv_skip
    ldx sv_t2               ; known (visited)? what's there
    lda gx_flag,x
    and #1
    beq sv_b_unk
    jsr sv_brief
    jmp sv_b_itn
sv_b_unk
    lda #P_GREY
    jsr sv_pen
    lda #<tx_qqq
    ldy #>tx_qqq
    ldx #3
    jsr sv_puts
    jmp sv_b_itn
sv_b_act
    pha
    lda #P_WHITE
    jsr sv_pen
    pla
    and #1
    bne sv_b_dock
    lda #<tx_land
    ldy #>tx_land
    ldx #14
    jsr sv_puts
    jmp sv_b_itn
sv_b_dock
    lda #<tx_dock
    ldy #>tx_dock
    ldx #14
    jsr sv_puts
sv_b_itn
    ldx sv_t3               ; the selected one: inverse, white after it
    cpx sv_sel
    bne sv_b_nx
    lda #0
    sta sv_lock
    ldx sv_itr
    lda sv_itc
    ldy #19
    jsr sv_inv
    ldx sv_itr
    lda sv_itc
    clc
    adc #19
    ldy #P_WHITE
    jsr sv_ink
sv_b_nx
    ldx sv_t3
    inx
    jmp sv_b_it
sv_b_itd
    ; row 9: the help
    ldx #9
    lda #1
    jsr sv_at
    lda #P_GREY
    jsr sv_pen
    lda #<tx_svhelp
    ldy #>tx_svhelp
    ldx #36
    jmp sv_puts

; the tier of sector X, in words, in its colour
sv_tier
    lda gx_info,x
    rol
    rol
    rol
    and #3
    pha
    tax
    lda sv_tiercol,x
    jsr sv_pen
    pla
    tax
    lda sv_tierlo,x
    pha
    lda sv_tierhi,x
    tay
    lda sv_tierlen,x
    tax
    pla
    jsr sv_puts
    lda #P_WHITE
    jmp sv_pen
sv_tiercol .byte P_GREEN, P_WHITE, P_GOLD, P_RED     ; safe, core, mid, outer
sv_tycol   .byte P_GREY, P_CYAN, P_GREEN, P_BLUE     ; empty, port, planet, nebula

; what's in sector X, in full (row 2)
sv_what
    stx sv_t2
    lda gx_info,x
    and #3
    tax
    lda sv_tycol,x
    jsr sv_pen
    ldx sv_t2
    lda gx_info,x
    and #3
    tax
    lda sv_typelo,x
    pha
    lda sv_typehi,x
    tay
    lda sv_typelen,x
    tax
    pla
    jsr sv_puts
    lda #P_WHITE
    jsr sv_pen
    ldx sv_t2
    lda gx_info,x
    and #3
    cmp #GT_PORT
    bne sv_w_np
    lda #2                  ; a port: its class (B buys, S sells: ore,
    jsr sv_skip             ;  organics, equipment)
    lda #<tx_class
    ldy #>tx_class
    ldx #6
    jsr sv_puts
    ldx sv_t2
    jmp sv_class
sv_w_np
    cmp #GT_PLANET
    bne sv_w_r
    lda #2                  ; a planet: its world, its level
    jsr sv_skip
    ldx sv_t2
    jsr sv_world
    lda #2                  ; ... and its life: LIFE n, or BARREN (taken)
    jsr sv_skip
    ldx sv_t2
    jsr gx_pop
    beq sv_w_bar
    pha
    lda #<tx_life
    ldy #>tx_life
    ldx #5
    jsr sv_puts
    pla
    jsr tx_digit
    jsr sv_putc
    jmp sv_w_rel
sv_w_bar
    lda #<tx_barren
    ldy #>tx_barren
    ldx #6
    jsr sv_puts
sv_w_rel
    ldx sv_t2               ; the relic here: RELIC SIGNAL
    cpx gs_relic
    bne sv_w_r
    lda gs_relst
    bne sv_w_r
    lda #2
    jsr sv_skip
    lda #P_GOLD
    jsr sv_pen
    lda #<tx_relsig
    ldy #>tx_relsig
    ldx #12
    jmp sv_puts
sv_w_r
    rts

; what's in sector X, short, in its colour (a warp's line, the chart's
; panel: 8 characters at most): PORT BSB, VERDA L3, NEBULA, EMPTY
sv_brief
    stx sv_t2
    lda gx_info,x
    and #3
    tax
    lda sv_tycol,x
    jsr sv_pen
    ldx sv_t2
    lda gx_info,x
    and #3
    cmp #GT_PORT
    bne sv_br_np
    lda #<tx_portw
    ldy #>tx_portw
    ldx #5
    jsr sv_puts
    ldx sv_t2
    jmp sv_class
sv_br_np
    cmp #GT_PLANET
    bne sv_br_o
    ldx sv_t2
    jmp sv_world
sv_br_o
    tax
    lda sv_shlo,x
    pha
    lda sv_shhi,x
    tay
    ldx #6
    pla
    jmp sv_puts

; sector X's port class: three letters, B buys, S sells (ore, organics,
; equipment)
sv_class
    lda gx_info,x
    lsr
    lsr
    sta sv_t0
    ldx #3
sv_cl_c
    lsr sv_t0
    lda #("B"-32)*2
    bcc sv_cl_b2
    lda #("S"-32)*2
sv_cl_b2
    jsr sv_putc
    dex
    bne sv_cl_c
    rts

; sector X's planet: its world's name and its level (VERDA L3)
sv_world
    stx sv_t0
    lda gx_info,x
    lsr
    lsr
    and #7
    sta sv_t1
    asl
    asl
    adc sv_t1               ; (x 5)
    clc
    adc #<tx_worlds
    pha
    lda #>tx_worlds
    adc #0
    tay
    pla
    ldx #5
    jsr sv_puts
    lda #1
    jsr sv_skip
    lda #("L"-32)*2
    jsr sv_putc
    ldx sv_t0
    jsr gx_plevel
    jsr tx_digit
    jmp sv_putc

; the way from the Ark's sector to sector A: X (C = 0), or C = 1 (no warp
; there)
sv_dirto
    sta sv_dg
    ldx #0
sv_dt_l
    stx sv_dk
    lda gs_sec
    jsr gx_warpto
    bcs sv_dt_n
    cmp sv_dg
    beq sv_dt_y
sv_dt_n
    ldx sv_dk
    inx
    cpx #8
    bne sv_dt_l
    sec
    rts
sv_dt_y
    ldx sv_dk
    clc
    rts

; ---- the sector view's input ----
sv_input
    ; button 2 (fresh): the star chart, its cursor on the Ark
    lda sp_fire2
    beq sv_i_nc
    lda sv_pf2
    bne sv_i_nc
    lda #1
    sta sv_view
    sta sv_dirty
    lda #SFX_BEEP
    jsr sfx
    jmp ch_home
sv_i_nc
    ; the stick (fresh pushes): up/down a row, left/right a column
    ldx sp_joy
    cpx sv_pjoy
    beq sv_i_fire
    cpx #8
    beq sv_i_fire
    lda sv_sel
    cpx #0
    bne sv_i_dn
    sec
    sbc #2
    bcc sv_i_fire
    bcs sv_i_set
sv_i_dn
    cpx #4
    bne sv_i_rt
    clc
    adc #2
    jmp sv_i_set
sv_i_rt
    cpx #2
    bne sv_i_lt
    ora #1
    jmp sv_i_set
sv_i_lt
    cpx #6
    bne sv_i_fire
    and #$FE
sv_i_set
    cmp sv_nitems
    bcs sv_i_fire
    sta sv_sel
    inc sv_dirty
    lda #SFX_BEEP
    jsr sfx
sv_i_fire
    ; fire (fresh): the item
    lda sp_fire
    beq sv_i_r
    lda sv_pf
    bne sv_i_r
    ldx sv_sel
    cpx sv_nitems
    bcs sv_i_r
    lda #0
    sta gs_msg
    lda sv_items,x
    bmi sv_i_act
    jmp sv_warp
sv_i_act
    and #1
    bne sv_i_dock
    ; land: the BASIC goes to the planet (its world, its creatures); none
    ; left: not yet
    ldx gs_sec
    jsr gx_pop
    bne sv_i_ld
    lda #1                  ; (the relic's there: down for it)
    cpx gs_relic
    bne sv_i_bar
    ldy gs_relst
    beq sv_i_ld
sv_i_bar
    lda #MSG_BARREN
    sta gs_msg
    inc sv_dirty
    lda #SFX_HIT
    jmp sfx
sv_i_ld
    sta gs_pop
    ldx gs_sec
    jsr gx_plevel
    sta gs_plevel
    ldx gs_sec
    lda gx_info,x
    lsr
    lsr
    and #7
    clc
    adc #1
    sta sp_wave
    lda #2
    sta gs_go
sv_i_r
    rts
sv_i_dock
    ; a port: its screen (port.asm)
    jmp pt_enter

; warp to sector A: a stardate; maybe an encounter on the way (no fuel:
; warps are free, as in TradeWars)
sv_warp
    sta gs_dest
    lda #0
    sta sv_t3
sv_wp_go
    inc gs_date
    bne sv_wp_d
    inc gs_date+1
sv_wp_d
    jsr gx_restock
    lda gs_dest
    jsr sv_encroll
    bcc sv_wp_none
    rts
sv_wp_none
    jsr gx_arrive           ; straight there
    lda #0
    sta sv_sel
    inc sv_dirty
    lda #SFX_ARRIVE
    jmp sfx
; An encounter at sector A? (sv_t3: extra odds, %.) Its odds by the tier
; (+25% in a nebula), its strength by the jumps back to safe space: the wave
; is that many, +0-1 (at least 1, at most 10). C = 1: there is one (sp_wave
; set, gs_go = 1: the BASIC goes to deep space).
sv_encroll
    tax
    lda gx_info,x
    rol
    rol
    rol
    and #3
    tay
    lda sv_encodds,y
    clc
    adc sv_t3
    sta sv_t3
    lda gx_info,x
    and #3
    cmp #GT_NEBULA          ; nebulae: pirates hide in them
    bne sv_er_nn
    lda sv_t3
    clc
    adc #25
    sta sv_t3
sv_er_nn
    stx sv_t4
    lda #100
    jsr gx_rand
    cmp sv_t3
    bcs sv_er_no
    ldx sv_t4
    lda gx_flag,x           ; the jumps back to safe space
    lsr
    lsr
    sta sv_t2
    lda #2
    jsr gx_rand
    clc
    adc sv_t2               ; + 0-1
    beq sv_er_w             ; (sp_wave: the wave - 1)
    sec
    sbc #1
sv_er_w
    cmp #10
    bcc sv_er_w2
    lda #9
sv_er_w2
    sta sp_wave
    jsr sv_wavebcd
    lda #1
    sta gs_go
    lda #SFX_LAUNCH
    jsr sfx
    sec
    rts
sv_er_no
    clc
    rts

; Leaving a planet or a port (sector gs_sec): an encounter? (C = 1, gs_go)
sv_depart
    lda gs_sec
    sta gs_dest
    lda #0
    sta gs_go
    sta sv_t3
    lda gs_sec
    jmp sv_encroll

; sp_wavebcd = sp_wave in BCD (the HUD's wave number; sp_nextwave adds 1 to
; both)
sv_wavebcd
    lda sp_wave
    ldx #0
sv_wb_l
    cmp #10
    bcc sv_wb_d
    sbc #10
    inx
    bne sv_wb_l
sv_wb_d
    sta sv_t0
    txa
    asl
    asl
    asl
    asl
    ora sv_t0
    sta sp_wavebcd
    rts
; by tier (safe, core, mid, outer): the odds (%)
sv_encodds .byte 0, 30, 45, 60

; ---------------------------------------------------------------------------
; The star chart: the grid (rows 1-8, columns 2-37: a node and two link
; characters a cell, so a diagonal runs node centre to node centre), the
; sectors seen (visited, or next to a visited one), each node in its kind's
; colour, the lanes grey; the visited ones' warps; the Ark's sector marked; a
; cursor (the stick) and, on row 9, the sector under it: fire warps there
; when it's one jump away.
;   0  the tab bar (CHART)
;   9  SEC 12  MID-RIM  VERDA L3       FIRE: WARP
;   10-11 the status panel
ch_build
    jsr sv_cls
    lda #1                  ; the frame
    ldx #0
    ldy #4
    jsr sv_tabbar
    jsr sv_status
    ; the sectors seen: their nodes; the visited ones' warps
    ldx #63
ch_b_s
    stx sv_t3
    lda gx_flag,x
    and #3                  ; (bits 2-7: the jumps back to safe space)
    bne ch_b_s1
    jmp ch_b_sn
ch_b_s1
    lda gx_cell,x
    jsr ch_cellat           ; sv_dst: its node
    ldx sv_t3
    lda gx_flag,x
    and #1
    beq ch_b_unk
    lda #248                ; (the Ark's: on top, in gold)
    cpx gs_sec
    beq ch_b_sym
    lda gx_info,x
    and #3
    tay
    lda ch_sym,y
    bne ch_b_sym
ch_b_unk
    lda #128                ; ? (seen, not visited)
ch_b_sym
    ldy #0
    ora (sv_dst),y          ; (a link down may be there already)
    sta (sv_dst),y
    ldx sv_t3
    lda gx_flag,x
    and #1
    bne ch_b_lk
    jmp ch_b_sn
ch_b_lk
    ; a visited sector's warps: down (S, and N: the node above's), across
    ; (E: the link to its right; W: to its left), the diagonals
    lda gx_warp,x
    sta sv_t2
    and #16                 ; S: this node's down
    beq ch_b_n
    ldy #0
    lda (sv_dst),y
    ora #2
    sta (sv_dst),y
ch_b_n
    lda sv_t2
    and #1                  ; N: the node above's down
    beq ch_b_e
    lda gx_cell,x
    sec
    sbc #16
    jsr ch_cellat
    ldy #0
    lda (sv_dst),y
    ora #128+2              ; (unseen above: drawn as ?)
    sta (sv_dst),y
    ldx sv_t3
ch_b_e
    ; E, SE: this node's link; W, SW: the left one's; NE: the one above's;
    ; NW: the one above-left's (the diagonals drawn down from the row above)
    lda sv_t2
    and #4                  ; E
    beq ch_b_se
    lda #160+2
    ldy #0
    jsr ch_orlink
ch_b_se
    lda sv_t2
    and #8                  ; SE: from here down to the right
    beq ch_b_w
    lda #160+4
    ldy #0
    jsr ch_orlink
ch_b_w
    lda sv_t2
    and #64                 ; W
    beq ch_b_sw
    lda #160+2
    ldy #1
    jsr ch_orlink
ch_b_sw
    lda sv_t2
    and #32                 ; SW: from here down to the left
    beq ch_b_ne
    lda #160+8
    ldy #1
    jsr ch_orlink
ch_b_ne
    lda sv_t2
    and #2                  ; NE: up to the right (down-left from above)
    beq ch_b_nw
    lda #160+8
    ldy #16
    jsr ch_orlink
ch_b_nw
    lda sv_t2
    and #128                ; NW: up to the left (down-right from above-left)
    beq ch_b_sn
    lda #160+4
    ldy #17
    jsr ch_orlink
ch_b_sn
    ldx sv_t3
    dex
    bmi ch_b_done
    jmp ch_b_s
ch_b_done
    ; the marker: the Ark's node
    ldx gs_sec
    lda gx_cell,x
    and #15
    sta sv_t0
    asl
    adc sv_t0
    adc #2                  ; (its column: 2 + 3 x)
    asl
    asl                     ; (a 320A character: 4 of the 160-pixel x)
    sta sv_mx
    lda gx_cell,x
    lsr
    lsr
    lsr
    lsr
    clc
    adc #1
    sta sv_my
    jsr ch_fillb
    jsr ch_paint
    jmp ch_info
ch_sym    .byte 128+4, 248, 248, 248   ; empty (a ring); port, planet, nebula on top
ch_ovsym  .byte 128+4, 128+8, 128+12, 128+16   ; the nodes on top: empty, port, planet, nebula
ch_ovpal  .byte (P_GOLD << 5) | 31, (P_CYAN << 5) | 31, (P_GREEN << 5) | 31, (P_BLUE << 5) | 31
ch_linkb  .byte 0, 148, 150, 152, 154, 156, 158, 246   ; link B by k (tools/gfx.py CH_LINKB)

; the nodes' colours: along each row a change only where the colour does
; (the links take the colour of the node to their left), the Ark's gold
; the chart's text all grey (the coloured nodes are drawn on top: ch_nodes)
ch_paint
    ldx #8
ch_p_r
    stx sv_t0
    lda #0
    ldy #P_GREY
    jsr sv_ink
    ldx sv_t0
    dex
    bne ch_p_r
    rts

; Each frame: the visited ports, planets and nebulae, one character each in
; their colour, and the Ark's sector (whatever it is) in gold, over the
; grey chart (one object a node: no colour changes in the text's rows)
ch_nodes
    ldx #63
ch_nd_l
    stx sv_t4
    lda gx_flag,x
    and #1
    beq ch_nd_n
    lda gx_info,x
    and #3
    tay
    cpx gs_sec
    beq ch_nd_p
    tya
    beq ch_nd_n             ; (empty: a grey ring, in the text)
ch_nd_p
    tya
    clc
    adc #<ch_ovsym
    sta temp1
    lda #>ch_ovsym
    adc #0
    sta temp2
    lda ch_ovpal,y
    cpx gs_sec
    bne ch_nd_c
    lda ch_ovpal            ; (gold)
ch_nd_c
    sta temp3
    lda gx_cell,x
    and #15
    sta temp4
    asl
    adc temp4
    adc #2
    asl
    asl
    sta temp4
    lda gx_cell,x
    lsr
    lsr
    lsr
    lsr
    clc
    adc #1
    sta temp5
    jsr plotcharacters
ch_nd_n
    ldx sv_t4
    dex
    bpl ch_nd_l
    rts

; each link B (the second character of a lane) as its link A says
ch_fillb
    lda #1
    sta sv_t0
ch_fb_r
    ldx sv_t0
    lda sv_rowlo,x
    sta sv_src
    lda sv_rowhi,x
    sta sv_src+1
    ldy #3                  ; (link A: column 3 + 3 x)
ch_fb_c
    lda (sv_src),y
    beq ch_fb_n
    sec
    sbc #160
    lsr
    tax
    lda ch_linkb,x
    iny
    sta (sv_src),y
    dey
ch_fb_n
    iny
    iny
    iny
    cpy #37
    bcc ch_fb_c
    inc sv_t0
    lda sv_t0
    cmp #9
    bne ch_fb_r
    rts

ch_info
    jsr ch_atcur
    bcc ch_in_r_far1888
    jmp ch_in_r
ch_in_r_far1888
    sta sv_t3
    tax
    lda gx_flag,x
    and #3
    bne ch_in_r_far1893
    jmp ch_in_r
ch_in_r_far1893
    lda sv_t3               ; one jump away? (sv_t4: the way, or $FF)
    jsr sv_dirto
    lda #$FF
    bcs ch_in_w
    txa
ch_in_w
    sta sv_t4
    ldx #9
    lda #1
    jsr sv_at
    lda #P_CYAN
    jsr sv_pen
    lda #<tx_sec
    ldy #>tx_sec
    ldx #4
    jsr sv_puts
    lda #P_WHITE
    jsr sv_pen
    lda sv_t3
    clc
    adc #1
    jsr sv_dec2
    lda #2
    jsr sv_skip
    ldx sv_t3
    jsr sv_tier
    lda #2
    jsr sv_skip
    ldx sv_t3
    lda gx_flag,x
    and #1
    beq ch_in_u
    jsr sv_brief
    jmp ch_in_h
ch_in_u
    lda #P_GREY
    jsr sv_pen
    lda #<tx_qqq
    ldy #>tx_qqq
    ldx #3
    jsr sv_puts
ch_in_h
    lda sv_t3               ; the Ark's: ARK HERE; a jump away: FIRE: WARP
    cmp gs_sec
    bne ch_in_j
    ldx #9
    lda #31
    jsr sv_at
    lda #P_GOLD
    jsr sv_pen
    lda #<tx_here
    ldy #>tx_here
    ldx #8
    jmp sv_puts
ch_in_j
    lda sv_t4
    bmi ch_in_r
    ldx #9
    lda #29
    jsr sv_at
    lda #P_GOLD
    jsr sv_pen
    lda #<tx_fwarp
    ldy #>tx_fwarp
    ldx #10
    jmp sv_puts
ch_in_r
    rts

; the sector under the cursor: A (C = 0), or C = 1 (none in that cell)
ch_atcur
    lda ch_cy
    asl
    asl
    asl
    asl
    ora ch_cx
    ldx #63
ch_ac_l
    cmp gx_cell,x
    beq ch_ac_y
    dex
    bpl ch_ac_l
    sec
    rts
ch_ac_y
    txa
    clc
    rts

; the cursor onto the Ark's sector
ch_home
    ldx gs_sec
    lda gx_cell,x
    and #15
    sta ch_cx
    lda gx_cell,x
    lsr
    lsr
    lsr
    lsr
    sta ch_cy
    rts

; sv_dst = cell A's node (row 1 + its row, column 2 + 3 x its column)
ch_cellat
    sta sv_t0
    and #15
    sta sv_t1
    asl
    adc sv_t1
    adc #2
    sta sv_t1
    lda sv_t0
    lsr
    lsr
    lsr
    lsr
    clc
    adc #1
    tax
    lda sv_t1
    jmp sv_at
; OR A into the link (A: the character after the node) of the cell Y before
; sector sv_t3's (0 its own, 1 left, 16 above, 17 above-left); X = sv_t3
ch_orlink
    sta sv_t4
    sty sv_t1
    ldx sv_t3
    lda gx_cell,x
    sec
    sbc sv_t1
    jsr ch_cellat
    ldy #1
    lda sv_t4
    ora (sv_dst),y
    sta (sv_dst),y
    ldx sv_t3
    rts

ch_input
    ; button 2 (fresh): the close-up chart (the BASIC: bank 6)
    lda sp_fire2
    beq ch_i_f
    lda sv_pf2
    bne ch_i_f
    lda #3
    sta gs_go
    rts
ch_i_f
    ; fire (fresh): warp to the sector under the cursor, if it's a jump
    ; away; on the Ark's own: back to the sector view
    lda sp_fire
    beq ch_i_s
    lda sv_pf
    bne ch_i_s
    jsr ch_atcur
    bcs ch_i_no
    cmp gs_sec
    beq ch_i_back
    tax
    lda gx_flag,x           ; (never seen: not a known way)
    and #3
    beq ch_i_no
    txa
    jsr sv_dirto
    bcs ch_i_no
    lda #0
    sta gs_msg
    lda sv_dg
    jsr sv_warp
    lda gs_go               ; (an encounter: deep space)
    bne ch_i_r
    jmp ch_home             ; there: the cursor on the Ark again
ch_i_no
    lda #SFX_HIT
    jmp sfx
ch_i_back
    lda #0
    sta sv_view
    lda #1
    sta sv_dirty
    rts
ch_i_s
    ; the stick: the cursor a cell (a fresh push, then again every few
    ; frames while it's held)
    ldx sp_joy
    cpx #8
    beq ch_i_r
    cpx sv_pjoy
    beq ch_i_hold
    lda #16
    sta ch_rep
    bne ch_i_mv
ch_i_hold
    dec ch_rep
    bne ch_i_r
    lda #5
    sta ch_rep
ch_i_mv
    lda ch_cx
    clc
    adc gx_dcol,x
    cmp #12
    bcs ch_i_r              ; (off the grid: negative reads as big)
    sta sv_t0
    lda ch_cy
    clc
    adc gx_drow,x
    cmp #8
    bcs ch_i_r
    sta ch_cy
    lda sv_t0
    sta ch_cx
    inc sv_dirty
ch_i_r
    rts

; ---- strings ----
tx_sector  .byte ("S"-32)*2,("E"-32)*2,("C"-32)*2,("T"-32)*2,("O"-32)*2,("R"-32)*2,0
tx_date    .byte ("S"-32)*2,("T"-32)*2,("A"-32)*2,("R"-32)*2,("D"-32)*2,("A"-32)*2,("T"-32)*2,("E"-32)*2,0
tx_warp    .byte ("W"-32)*2,("A"-32)*2,("R"-32)*2,("P"-32)*2,0
tx_land    .byte ("L"-32)*2,("A"-32)*2,("N"-32)*2,("D"-32)*2,0,("O"-32)*2,("N"-32)*2,0,("P"-32)*2,("L"-32)*2,("A"-32)*2,("N"-32)*2,("E"-32)*2,("T"-32)*2
tx_dock    .byte ("D"-32)*2,("O"-32)*2,("C"-32)*2,("K"-32)*2,0,("A"-32)*2,("T"-32)*2,0,("P"-32)*2,("O"-32)*2,("R"-32)*2,("T"-32)*2,0,0
tx_credits .byte ("C"-32)*2,("R"-32)*2,("E"-32)*2,("D"-32)*2,("I"-32)*2,("T"-32)*2,("S"-32)*2,0
tx_class   .byte ("C"-32)*2,("L"-32)*2,("A"-32)*2,("S"-32)*2,("S"-32)*2,0
tx_svhelp .byte ("F"-32)*2,("I"-32)*2,("R"-32)*2,("E"-32)*2,(":"-32)*2,0,("G"-32)*2,("O"-32)*2,0,0,("B"-32)*2,("U"-32)*2,("T"-32)*2,("T"-32)*2,("O"-32)*2,("N"-32)*2,0,("2"-32)*2,(":"-32)*2,0,("P"-32)*2,("A"-32)*2,("G"-32)*2,("E"-32)*2,("S"-32)*2,0,0,(">"-32)*2,0,("O"-32)*2,("N"-32)*2,("E"-32)*2,0,("W"-32)*2,("A"-32)*2,("Y"-32)*2   ; 'FIRE: GO  BUTTON 2: PAGES  > ONE WAY' (36)
tx_qqq .byte ("?"-32)*2,("?"-32)*2,("?"-32)*2   ; '???' (3)
tx_sec .byte ("S"-32)*2,("E"-32)*2,("C"-32)*2,0   ; 'SEC ' (4)
tx_fwarp .byte ("F"-32)*2,("I"-32)*2,("R"-32)*2,("E"-32)*2,(":"-32)*2,0,("W"-32)*2,("A"-32)*2,("R"-32)*2,("P"-32)*2   ; 'FIRE: WARP' (10)
tx_here .byte ("A"-32)*2,("R"-32)*2,("K"-32)*2,0,("H"-32)*2,("E"-32)*2,("R"-32)*2,("E"-32)*2   ; 'ARK HERE' (8)
tx_portw .byte ("P"-32)*2,("O"-32)*2,("R"-32)*2,("T"-32)*2,0   ; 'PORT ' (5)
tx_dirs .byte ("N"-32)*2,0,("N"-32)*2,("E"-32)*2,("E"-32)*2,0,("S"-32)*2,("E"-32)*2,("S"-32)*2,0,("S"-32)*2,("W"-32)*2,("W"-32)*2,0,("N"-32)*2,("W"-32)*2   ; 'N NEE SES SWW NW' (16)
; tiers
tx_tsafe   .byte ("S"-32)*2,("A"-32)*2,("F"-32)*2,("E"-32)*2,0,("S"-32)*2,("P"-32)*2,("A"-32)*2,("C"-32)*2,("E"-32)*2
tx_tcore   .byte ("C"-32)*2,("O"-32)*2,("R"-32)*2,("E"-32)*2
tx_tmid    .byte ("M"-32)*2,("I"-32)*2,("D"-32)*2,("-"-32)*2,("R"-32)*2,("I"-32)*2,("M"-32)*2
tx_touter  .byte ("O"-32)*2,("U"-32)*2,("T"-32)*2,("E"-32)*2,("R"-32)*2,0,("R"-32)*2,("I"-32)*2,("M"-32)*2
sv_tierlo  .byte <tx_tsafe, <tx_tcore, <tx_tmid, <tx_touter
sv_tierhi  .byte >tx_tsafe, >tx_tcore, >tx_tmid, >tx_touter
sv_tierlen .byte 10, 4, 7, 9
; types, in full and short
tx_yempty  .byte ("E"-32)*2,("M"-32)*2,("P"-32)*2,("T"-32)*2,("Y"-32)*2,0,("S"-32)*2,("P"-32)*2,("A"-32)*2,("C"-32)*2,("E"-32)*2
tx_yport   .byte ("S"-32)*2,("T"-32)*2,("A"-32)*2,("R"-32)*2,("P"-32)*2,("O"-32)*2,("R"-32)*2,("T"-32)*2
tx_yplanet .byte ("P"-32)*2,("L"-32)*2,("A"-32)*2,("N"-32)*2,("E"-32)*2,("T"-32)*2
tx_ynebula .byte ("N"-32)*2,("E"-32)*2,("B"-32)*2,("U"-32)*2,("L"-32)*2,("A"-32)*2
sv_typelo  .byte <tx_yempty, <tx_yport, <tx_yplanet, <tx_ynebula
sv_typehi  .byte >tx_yempty, >tx_yport, >tx_yplanet, >tx_ynebula
sv_typelen .byte 11, 8, 6, 6
tx_sempty  .byte ("E"-32)*2,("M"-32)*2,("P"-32)*2,("T"-32)*2,("Y"-32)*2,0
tx_sport   .byte ("P"-32)*2,("O"-32)*2,("R"-32)*2,("T"-32)*2,0,0
sv_shlo    .byte <tx_sempty, <tx_sport, <tx_yplanet, <tx_ynebula
sv_shhi    .byte >tx_sempty, >tx_sport, >tx_yplanet, >tx_ynebula
; messages
tx_mrefuel .byte ("R"-32)*2,("E"-32)*2,("F"-32)*2,("U"-32)*2,("E"-32)*2,("L"-32)*2,("E"-32)*2,("D"-32)*2,(","-32)*2,0
           .byte ("T"-32)*2,("R"-32)*2,("A"-32)*2,("D"-32)*2,("I"-32)*2,("N"-32)*2,("G"-32)*2,0
           .byte ("S"-32)*2,("O"-32)*2,("O"-32)*2,("N"-32)*2
tx_mdrift  .byte ("O"-32)*2,("U"-32)*2,("T"-32)*2,0,("O"-32)*2,("F"-32)*2,0,("F"-32)*2,("U"-32)*2,("E"-32)*2,("L"-32)*2
           .byte (":"-32)*2,0,("A"-32)*2,("D"-32)*2,("R"-32)*2,("I"-32)*2,("F"-32)*2,("T"-32)*2
sv_msglo   .byte <tx_mrefuel, <tx_mdrift, <tx_mbarren, <tx_mpod
sv_msghi   .byte >tx_mrefuel, >tx_mdrift, >tx_mbarren, >tx_mpod
sv_msglen  .byte 22, 19, 32, 37
tx_mach .byte ("A"-32)*2,("C"-32)*2,("H"-32)*2,("I"-32)*2,("E"-32)*2,("V"-32)*2,("E"-32)*2,("M"-32)*2,("E"-32)*2,("N"-32)*2,("T"-32)*2,(":"-32)*2,0   ; 'ACHIEVEMENT: ' (13)
tx_mpod .byte ("T"-32)*2,("H"-32)*2,("E"-32)*2,0,("P"-32)*2,("O"-32)*2,("D"-32)*2,0,("G"-32)*2,("O"-32)*2,("T"-32)*2,0,("H"-32)*2,("O"-32)*2,("M"-32)*2,("E"-32)*2,(":"-32)*2,0,("A"-32)*2,0,("N"-32)*2,("E"-32)*2,("W"-32)*2,0,("A"-32)*2,("R"-32)*2,("K"-32)*2,(","-32)*2,0,("1"-32)*2,("0"-32)*2,("%"-32)*2,0,("L"-32)*2,("E"-32)*2,("F"-32)*2,("T"-32)*2   ; 'THE POD GOT HOME: A NEW ARK, 10% LEFT' (37)
tx_mbarren .byte ("N"-32)*2,("O"-32)*2,("T"-32)*2,("H"-32)*2,("I"-32)*2,("N"-32)*2,("G"-32)*2,0,("L"-32)*2,("E"-32)*2,("F"-32)*2,("T"-32)*2,0,("T"-32)*2,("O"-32)*2,0,("C"-32)*2,("A"-32)*2,("T"-32)*2,("C"-32)*2,("H"-32)*2,0,("T"-32)*2,("H"-32)*2,("E"-32)*2,("R"-32)*2,("E"-32)*2,(":"-32)*2,0,("Y"-32)*2,("E"-32)*2,("T"-32)*2   ; 'NOTHING LEFT TO CATCH THERE: YET' (32)
tx_life .byte ("L"-32)*2,("I"-32)*2,("F"-32)*2,("E"-32)*2,0   ; 'LIFE ' (5)
tx_barren .byte ("B"-32)*2,("A"-32)*2,("R"-32)*2,("R"-32)*2,("E"-32)*2,("N"-32)*2   ; 'BARREN' (6)
tx_relsig .byte ("R"-32)*2,("E"-32)*2,("L"-32)*2,("I"-32)*2,("C"-32)*2,0,("S"-32)*2,("I"-32)*2,("G"-32)*2,("N"-32)*2,("A"-32)*2,("L"-32)*2   ; 'RELIC SIGNAL' (12)
