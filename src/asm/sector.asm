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
; sv_leave puts the game's back). Text in RAM, 12 rows of 40, drawn as two
; 20-character objects a row.
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
    ; the chart's marker on the Ark's sector (blinking)
    lda sv_view
    cmp #1
    bne sv_f_r
    lda sv_tick
    and #16
    bne sv_f_r
    lda #<ch_mark
    sta temp1
    lda #>ch_mark
    sta temp2
    lda #(1 << 5) | 31      ; palette 1, 1 wide
    sta temp3
    lda sv_mx
    sta temp4
    lda sv_my
    sta temp5
    jsr plotcharacters
sv_f_r
    rts
ch_mark   .byte 176

; ---------------------------------------------------------------------------
; The sector view
;   0  SECTOR 12  CORE                STARDATE 0034
;   1  STARPORT  CLASS BSB
;   2  (a message)
;   3-8 the items, two a row: LAND / DOCK, then the warps:  > 12 PLANET
;   10 FUEL 20  CREDITS 000500   ENERGY 96
;   11 FIRE: GO   BUTTON 2: STAR CHART
sv_build
    jsr sv_cls
    ; the items: what's here, then the warps
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
    iny
sv_b_wn
    ldx sv_t3
    inx
    cpx #8
    bne sv_b_w
    sty sv_nitems
    ; row 0
    ldx #0
    lda #1
    jsr sv_at
    lda #<tx_sector
    ldy #>tx_sector
    ldx #7
    jsr sv_puts
    lda gs_sec
    clc
    adc #1
    jsr sv_dec2
    lda #2
    jsr sv_skip
    ldx gs_sec
    jsr sv_tier
    ldx #0
    lda #26
    jsr sv_at
    lda #<tx_date
    ldy #>tx_date
    ldx #9
    jsr sv_puts
    lda gs_date
    sta sv_t0
    lda gs_date+1
    sta sv_t1
    jsr sv_dec4
    ; row 1: what's here
    ldx #1
    lda #1
    jsr sv_at
    ldx gs_sec
    jsr sv_what
    ; row 2: a message (or, with none, a new achievement)
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
    ldx #2
    lda #1
    jsr sv_at
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
    ; the items
    ldx #0
sv_b_it
    cpx sv_nitems
    bcc sv_b_itd_far791
    jmp sv_b_itd
sv_b_itd_far791
    stx sv_t3
    txa
    lsr
    clc
    adc #4                  ; row 4 on
    tax
    lda sv_t3
    and #1
    beq sv_b_c0
    lda #20
sv_b_c0
    clc
    adc #1
    jsr sv_at
    ldx sv_t3               ; the cursor
    lda #0
    cpx sv_sel
    bne sv_b_cu
    lda #178
sv_b_cu
    jsr sv_putc
    lda #1
    jsr sv_skip
    ldx sv_t3
    lda sv_items,x
    bmi sv_b_act
    sta sv_t2
    lda #<tx_warp
    ldy #>tx_warp
    ldx #5
    jsr sv_puts
    lda sv_t2
    clc
    adc #1
    jsr sv_dec2
    lda #1
    jsr sv_skip
    ldx sv_t2               ; known? what's there
    lda gx_flag,x
    and #1
    beq sv_b_unk
    jsr sv_short
    jmp sv_b_itn
sv_b_unk
    lda #("?"-32)*2
    jsr sv_putc
    jmp sv_b_itn
sv_b_act
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
    ldx sv_t3
    inx
    beq sv_b_it_far855
    jmp sv_b_it
sv_b_it_far855
sv_b_itd
    ; row 10: credits, energy
    ldx #10
    lda #1
    jsr sv_at
    lda #<tx_credits
    ldy #>tx_credits
    ldx #8
    jsr sv_puts
    lda gs_cred
    jsr sv_bcd
    lda gs_cred+1
    jsr sv_bcd
    lda gs_cred+2
    jsr sv_bcd
    lda #3
    jsr sv_skip
    lda #<tx_energy
    ldy #>tx_energy
    ldx #7
    jsr sv_puts
    lda sp_energy
    jsr sv_dec3
    ; row 11
    ldx #11
    lda #1
    jsr sv_at
    lda #<tx_svhelp
    ldy #>tx_svhelp
    ldx #36
    jmp sv_puts

; the tier of sector X, in words
sv_tier
    lda gx_info,x
    rol
    rol
    rol
    and #3
    tax
    lda sv_tierlo,x
    pha
    lda sv_tierhi,x
    tay
    lda sv_tierlen,x
    tax
    pla
    jmp sv_puts

; what's in sector X, in full (row 1)
sv_what
    stx sv_t2
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
    ldx sv_t2
    lda gx_info,x
    and #3
    cmp #GT_PORT
    bne sv_w_port_far1171
    jmp sv_w_port
sv_w_port_far1171
    cmp #GT_PLANET
    beq sv_w_r_far1141
    jmp sv_w_r
sv_w_r_far1141
    lda #2                  ; a planet: its world's name
    jsr sv_skip
    ldx sv_t2
    lda gx_info,x
    lsr
    lsr
    and #7
    sta sv_t0
    asl
    asl
    adc sv_t0               ; * 5
    clc
    adc #<tx_worlds
    pha
    lda #>tx_worlds
    adc #0
    tay
    ldx #5
    pla
    jsr sv_puts
    lda #1                  ; its level: Ln
    jsr sv_skip
    lda #("L"-32)*2
    jsr sv_putc
    ldx sv_t2
    jsr gx_plevel
    jsr tx_digit
    jsr sv_putc
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
    lda #<tx_relsig
    ldy #>tx_relsig
    ldx #12
    jmp sv_puts
sv_w_port
    lda #2                  ; a port: its class (B buys, S sells: ore,
    jsr sv_skip             ;  organics, equipment)
    lda #<tx_class
    ldy #>tx_class
    ldx #6
    jsr sv_puts
    ldx sv_t2
    lda gx_info,x
    lsr
    lsr
    sta sv_t0
    ldx #3
sv_w_cl
    lsr sv_t0
    lda #("B"-32)*2
    bcc sv_w_b
    lda #("S"-32)*2
sv_w_b
    jsr sv_putc
    dex
    bne sv_w_cl
sv_w_r
    rts

; what's in sector X, short (a warp's line)
sv_short
    lda gx_info,x
    and #3
    tax
    lda sv_shlo,x
    pha
    lda sv_shhi,x
    tay
    ldx #6
    pla
    jmp sv_puts

; ---- the sector view's input ----
sv_input
    ; button 2 (fresh): the star chart
    lda sp_fire2
    beq sv_i_nc
    lda sv_pf2
    bne sv_i_nc
    lda #1
    sta sv_view
    sta sv_dirty
    rts
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
; The star chart: the grid (rows 1-8, columns 8-31: a node and a link a
; cell), what's been seen; the Ark's sector marked
;   0  STAR CHART
;   10 the legend
;   11 BUTTON 2: BACK
ch_build
    jsr sv_cls
    ldx #0
    lda #15
    jsr sv_at
    lda #<tx_chart
    ldy #>tx_chart
    ldx #10
    jsr sv_puts
    ; the sectors seen: their nodes; the visited ones' warps
    ldx #63
ch_b_s
    stx sv_t3
    lda gx_flag,x
    bne ch_b_s1
    jmp ch_b_sn
ch_b_s1
    lda gx_cell,x
    jsr ch_cellat           ; sv_dst: its node
    ldx sv_t3
    lda gx_flag,x
    and #1
    beq ch_b_unk
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
    lda gx_cell,x
    jsr ch_cellat           ; its node again; links at +1 (right), -1 (left)
    lda sv_t2
    and #4                  ; E
    beq ch_b_se
    ldy #1
    lda #160+2
    ora (sv_dst),y
    sta (sv_dst),y
ch_b_se
    lda sv_t2
    and #8                  ; SE: from here down to the right
    beq ch_b_sw
    ldy #1
    lda #160+4
    ora (sv_dst),y
    sta (sv_dst),y
ch_b_sw
    lda sv_t2
    and #64                 ; W: the link to its left
    beq ch_b_w2
    jsr ch_left
    lda #160+2
    ora (sv_dst),y
    sta (sv_dst),y
ch_b_w2
    lda sv_t2
    and #32                 ; SW: from here down to the left
    beq ch_b_ne
    jsr ch_left
    lda #160+8
    ora (sv_dst),y
    sta (sv_dst),y
ch_b_ne
    ; NE and NW: the row above's links (a diagonal down from there)
    lda sv_t2
    and #2                  ; NE: the link above-right, down-left
    beq ch_b_nw
    ldx sv_t3
    lda gx_cell,x
    sec
    sbc #16
    jsr ch_cellat
    ldy #1
    lda #160+8
    ora (sv_dst),y
    sta (sv_dst),y
ch_b_nw
    lda sv_t2
    and #128                ; NW: the link above-left, down-right
    beq ch_b_sn
    ldx sv_t3
    lda gx_cell,x
    sec
    sbc #16
    jsr ch_cellat
    jsr ch_left
    lda #160+4
    ora (sv_dst),y
    sta (sv_dst),y
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
    asl
    clc
    adc #8
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
    ; the legend, the help
    ldx #10
    lda #1
    jsr sv_at
    lda #<tx_legend
    ldy #>tx_legend
    ldx #38
    jsr sv_puts
    ldx #11
    lda #1
    jsr sv_at
    lda #<tx_chhelp
    ldy #>tx_chhelp
    ldx #31
    jmp sv_puts
ch_sym    .byte 128+4, 128+8, 128+12, 128+16   ; empty, port, planet, nebula

; sv_dst = cell A's node (row 1 + its row, column 8 + 2 * its column)
ch_cellat
    sta sv_t0
    and #15
    asl
    clc
    adc #8
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
; sv_dst back one (the link left of a node); Y = 0
ch_left
    lda sv_dst
    bne ch_l1
    dec sv_dst+1
ch_l1
    dec sv_dst
    ldy #0
    rts

ch_input
    ; button 2 (fresh): the close-up chart (the BASIC: bank 6); fire: back
    lda sp_fire2
    beq ch_i_f
    lda sv_pf2
    bne ch_i_f
    lda #3
    sta gs_go
    rts
ch_i_f
    lda sp_fire
    beq ch_i_r
    lda sv_pf
    bne ch_i_r
ch_i_back
    lda #0
    sta sv_view
    lda #1
    sta sv_dirty
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
tx_chart   .byte ("S"-32)*2,("T"-32)*2,("A"-32)*2,("R"-32)*2,0,("C"-32)*2,("H"-32)*2,("A"-32)*2,("R"-32)*2,("T"-32)*2
tx_svhelp  .byte ("F"-32)*2,("I"-32)*2,("R"-32)*2,("E"-32)*2,(":"-32)*2,0,("G"-32)*2,("O"-32)*2,0,0,0,0,0,0,0,0
           .byte ("B"-32)*2,("U"-32)*2,("T"-32)*2,("T"-32)*2,("O"-32)*2,("N"-32)*2,0,("2"-32)*2,(":"-32)*2,0
           .byte ("S"-32)*2,("T"-32)*2,("A"-32)*2,("R"-32)*2,0,("C"-32)*2,("H"-32)*2,("A"-32)*2,("R"-32)*2,("T"-32)*2
tx_chhelp .byte ("F"-32)*2,("I"-32)*2,("R"-32)*2,("E"-32)*2,(":"-32)*2,0,("B"-32)*2,("A"-32)*2,("C"-32)*2,("K"-32)*2,0,0,0,("B"-32)*2,("U"-32)*2,("T"-32)*2,("T"-32)*2,("O"-32)*2,("N"-32)*2,0,("2"-32)*2,(":"-32)*2,0,("C"-32)*2,("L"-32)*2,("O"-32)*2,("S"-32)*2,("E"-32)*2,0,("U"-32)*2,("P"-32)*2   ; 'FIRE: BACK   BUTTON 2: CLOSE UP' (31)
; the legend: a node glyph, then its word
tx_legend  .byte 128+8,0,("P"-32)*2,("O"-32)*2,("R"-32)*2,("T"-32)*2,0,0
           .byte 128+12,0,("P"-32)*2,("L"-32)*2,("A"-32)*2,("N"-32)*2,("E"-32)*2,("T"-32)*2,0,0
           .byte 128+16,0,("N"-32)*2,("E"-32)*2,("B"-32)*2,("U"-32)*2,("L"-32)*2,("A"-32)*2,0,0
           .byte 128,0,("U"-32)*2,("N"-32)*2,("K"-32)*2,("N"-32)*2,("O"-32)*2,("W"-32)*2,("N"-32)*2,0
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
