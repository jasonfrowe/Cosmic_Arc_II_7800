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
gs_fuel   = $2591
gs_date   = $2592   ; the stardate (2 bytes, binary)
gs_cred   = $2594   ; credits (3 bytes BCD, high first)
gs_seed   = $2597   ; the galaxy's seed (4 bytes)
gs_go     = $259B   ; for the BASIC: 0 stay, 1 deep space, 2 the planet
gs_dest   = $259C   ; where the Ark's going (arrives on sv_enter)
gs_msg    = $259D   ; a message on row 2: 0 none, else MSG_*
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

FUEL_START = 20
FUEL_MAX  = 30

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
MSG_NOFUEL = 3

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
    ; ports: home, one more in safe space, one in the core, two mid-rim,
    ; two in the outer rim (TradeWars classes: buys/sells a bit each)
    lda #0
    jsr gx_port
    ldy #0
gx_n_pt
    lda gx_pfrom,y
    sta sv_t3
    lda gx_pspan,y
    jsr gx_rand
    clc
    adc sv_t3
    jsr gx_port
    iny
    cpy #6
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
    lda #FUEL_START
    sta gs_fuel
    rts
gx_pfrom  .byte 1, 10, 15, 27, 40, 52
gx_pspan  .byte 9, 5, 12, 13, 12, 12

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
    jsr ch_build
sv_f_nd
    lda sp_joy
    sta sv_pjoy
    lda sp_fire
    sta sv_pf
    lda sp_fire2
    sta sv_pf2
    ; the rows: two 20-character objects each (palette 2 the top and bottom)
    ldx #0
sv_f_rows
    stx sv_t4
    lda sv_rowlo,x
    sta temp1
    lda sv_rowhi,x
    sta temp2
    lda sv_rowpal,x
    ora #12                 ; (20 wide: 32 - 20)
    sta temp3
    lda #0
    sta temp4
    stx temp5
    jsr plotcharacters
    ldx sv_t4
    clc
    lda sv_rowlo,x
    adc #20
    sta temp1
    lda sv_rowhi,x
    adc #0
    sta temp2
    lda sv_rowpal,x
    ora #12
    sta temp3
    lda #80
    sta temp4
    stx temp5
    jsr plotcharacters
    ldx sv_t4
    inx
    cpx #12
    bne sv_f_rows
    ; the chart's marker on the Ark's sector (blinking)
    lda sv_view
    beq sv_f_r
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

sv_rowlo
    .byte <$2200, <$2228, <$2250, <$2278, <$22A0, <$22C8
    .byte <$2700, <$2728, <$2750, <$2778, <$27A0, <$27C8
sv_rowhi
    .byte >$2200, >$2228, >$2250, >$2278, >$22A0, >$22C8
    .byte >$2700, >$2728, >$2750, >$2778, >$27A0, >$27C8
sv_rowpal
    .byte 2 << 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2 << 5

; ---- text helpers: sv_dst points into the rows ----
; sv_dst = row X, column A
sv_at
    clc
    adc sv_rowlo,x
    sta sv_dst
    lda sv_rowhi,x
    adc #0
    sta sv_dst+1
    rts
; copy the string at (A lo, Y hi), X long, to sv_dst; sv_dst moves on
sv_puts
    sta sv_src
    sty sv_src+1
    ldy #0
sv_ps_l
    lda (sv_src),y
    sta (sv_dst),y
    iny
    dex
    bne sv_ps_l
    tya
sv_skip                     ; (A: move sv_dst on that many)
    clc
    adc sv_dst
    sta sv_dst
    bcc sv_ps_r
    inc sv_dst+1
sv_ps_r
    rts
; one character A
sv_putc
    ldy #0
    sta (sv_dst),y
    lda #1
    bne sv_skip
; A as two digits
sv_dec2
    ldx #0
sv_d2_l
    cmp #10
    bcc sv_d2_d
    sbc #10
    inx
    bne sv_d2_l
sv_d2_d
    pha
    txa
    jsr tx_digit
    jsr sv_putc
    pla
    jsr tx_digit
    jmp sv_putc
; (sv_t0 lo, sv_t1 hi) as four digits
sv_dec4
    ldx #3
sv_d4_l
    stx sv_t4
    ldy #0
sv_d4_s
    sec
    lda sv_t0
    sbc sv_p10lo,x
    sta sv_t2
    lda sv_t1
    sbc sv_p10hi,x
    bcc sv_d4_o
    sta sv_t1
    lda sv_t2
    sta sv_t0
    iny
    bne sv_d4_s
sv_d4_o
    tya
    jsr tx_digit
    jsr sv_putc
    ldx sv_t4
    dex
    bpl sv_d4_l
    rts
sv_p10lo  .byte <1, <10, <100, <1000
sv_p10hi  .byte >1, >10, >100, >1000
; a BCD byte A as two digits
sv_bcd
    pha
    lsr
    lsr
    lsr
    lsr
    jsr tx_digit
    jsr sv_putc
    pla
    and #15
    jsr tx_digit
    jmp sv_putc

; clear the text
sv_cls
    ldx #239
    lda #0
sv_cl_l
    sta $2200,x
    sta $2700,x
    dex
    cpx #$FF
    bne sv_cl_l
    rts

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
    ; row 2: a message
    lda gs_msg
    beq sv_b_nm
    ldx #2
    lda #1
    jsr sv_at
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
    ; row 10: fuel, credits, energy
    ldx #10
    lda #1
    jsr sv_at
    lda #<tx_fuel
    ldy #>tx_fuel
    ldx #5
    jsr sv_puts
    lda gs_fuel
    jsr sv_dec2
    lda #3
    jsr sv_skip
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
    jsr sv_dec2
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
    beq sv_w_port
    cmp #GT_PLANET
    bne sv_w_r
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
    ; land: the BASIC goes to the planet (its world)
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
    ; a port (trading to come): fuel topped up
    lda #FUEL_MAX
    sta gs_fuel
    lda #MSG_REFUEL
    sta gs_msg
    inc sv_dirty
    lda #SFX_POD
    jsr sfx
    jmp sv_depart           ; leaving: an encounter?

; warp to sector A: fuel, a stardate; maybe an encounter on the way
sv_warp
    sta gs_dest
    lda gs_fuel
    bne sv_wp_f
    ; out of fuel: adrift to a random neighbour, and an encounter for sure
    lda #MSG_DRIFT
    sta gs_msg
    lda sv_nitems
    jsr gx_rand
    tax
    lda sv_items,x
    bmi sv_wp_d0
    sta gs_dest
sv_wp_d0
    lda #100
    sta sv_t3               ; (a sure encounter)
    bne sv_wp_go
sv_wp_f
    dec gs_fuel
    lda #0
    sta sv_t3
sv_wp_go
    inc gs_date
    bne sv_wp_d
    inc gs_date+1
sv_wp_d
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
    ldx #14
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
    ; button 2 or fire (fresh): back to the sector
    lda sp_fire2
    beq ch_i_f
    lda sv_pf2
    beq ch_i_back
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
tx_fuel    .byte ("F"-32)*2,("U"-32)*2,("E"-32)*2,("L"-32)*2,0
tx_credits .byte ("C"-32)*2,("R"-32)*2,("E"-32)*2,("D"-32)*2,("I"-32)*2,("T"-32)*2,("S"-32)*2,0
tx_class   .byte ("C"-32)*2,("L"-32)*2,("A"-32)*2,("S"-32)*2,("S"-32)*2,0
tx_chart   .byte ("S"-32)*2,("T"-32)*2,("A"-32)*2,("R"-32)*2,0,("C"-32)*2,("H"-32)*2,("A"-32)*2,("R"-32)*2,("T"-32)*2
tx_svhelp  .byte ("F"-32)*2,("I"-32)*2,("R"-32)*2,("E"-32)*2,(":"-32)*2,0,("G"-32)*2,("O"-32)*2,0,0,0,0,0,0,0,0
           .byte ("B"-32)*2,("U"-32)*2,("T"-32)*2,("T"-32)*2,("O"-32)*2,("N"-32)*2,0,("2"-32)*2,(":"-32)*2,0
           .byte ("S"-32)*2,("T"-32)*2,("A"-32)*2,("R"-32)*2,0,("C"-32)*2,("H"-32)*2,("A"-32)*2,("R"-32)*2,("T"-32)*2
tx_chhelp  .byte ("B"-32)*2,("U"-32)*2,("T"-32)*2,("T"-32)*2,("O"-32)*2,("N"-32)*2,0,("2"-32)*2,(":"-32)*2,0
           .byte ("B"-32)*2,("A"-32)*2,("C"-32)*2,("K"-32)*2
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
sv_msglo   .byte <tx_mrefuel, <tx_mdrift
sv_msghi   .byte >tx_mrefuel, >tx_mdrift
sv_msglen  .byte 22, 19
