; ===========================================================================
; A starport (bank 4, after the map's font): docked, three tabs.
;   COMMODITIES  fuel ore, organics, equipment: the port's class (a bit each:
;                1 sells, 0 buys) says which way; prices by its tier (the
;                rim pays more, and charges more: carry goods outward) and
;                its stock (pt_stock: each one bought from it dearer, each
;                one sold to it cheaper; back to normal with the stardate)
;   BIO-BOUNTY   creatures in stasis (delivered on planets), by kind: sell
;                one for a bounty (more out in the rim; less where it's had
;                many lately: pt_glut), or keep a pair of each for the
;                manifest
;   SHIPYARD     energy (dearer out in the rim), upgrades: the hull (+5
;                energy, to 200), the holds
;   BANK         (safe space's ports only) savings: kept when the Ark's lost
; The stick picks a line, fire acts, button 2 the next tab, left (Bio-Bounty)
; keeps one. LEAVE PORT: back to the sector (and an encounter, maybe).
; Credits are BCD (gs_cred: 3 bytes, high first).
; ===========================================================================

pt_tab    = $27FB   ; the tab (0-2)
pt_msg    = $27FC   ; the message (0 none, else pt_m*)
pt_n      = $27FD   ; lines on this tab (the last: LEAVE PORT)
pt_vl     = $27FE   ; a price, BCD: tens/ones, then hundreds
pt_vh     = $27FF

pt_ta     = $27F9   ; (the generator's scratch: free once it's done)
pt_tb     = $27FA
pt_tc     = $2573   ; (more scratch: the escape scene's, free here)
pt_td     = $2574
pt_te     = $2578
pt_amt    = $258B   ; [3] an amount to move, BCD (high first)
pt_ntab   = $259E   ; tabs here: 3, or 4 with the bank (safe space)
PT_BANKOFS = gs_bank - gs_cred

pt_enter
    lda #2
    sta sv_view
    jsr pt_tier             ; the bank: safe space's ports
    cmp #1
    lda #3
    adc #0
    eor #7                  ; (tier 0: C = 0, 3 -> 4; else 4 -> 3)
    sta pt_ntab
    lda #0
    sta pt_tab
    sta sv_sel
    sta pt_msg
    lda #1
    sta sv_dirty
    lda gs_relst            ; the relic aboard: the port takes it, 2000
    cmp #1
    bne pt_en_r
    inc gs_relst
    lda #$20
    sta pt_vh
    lda #0
    sta pt_vl
    jsr pt_add
    jsr sl_save             ; (saved, the relic paid for)
    lda #15
    jmp pt_say
pt_en_r
    jsr sl_save             ; docked: the voyage saved (save.asm)
    cmp #1
    bcc pt_en_d
    adc #16-1-1             ; (C set: 1 -> 16 VOYAGE SAVED, 2 -> 17)
    jmp pt_say
pt_en_d
    lda #SFX_DOCK
    jmp sfx

; the port's tier (A, 0-3); its class bits (pt_class: bit k set, it sells k)
pt_tier
    ldx gs_sec
    lda gx_info,x
    rol
    rol
    rol
    and #3
    rts
pt_class
    ldx gs_sec
    lda gx_info,x
    lsr
    lsr
    and #7
    rts

; X = this port's number (0-6: ports in order of sector)
pt_pidx
    ldx #0
    ldy #0
pt_px_l
    cpy gs_sec
    beq pt_px_r
    lda gx_info,y
    and #3
    cmp #GT_PORT
    bne pt_px_n
    inx
pt_px_n
    iny
    bne pt_px_l
pt_px_r
    rts
; commodity X -> X = its place in pt_stock, here
pt_sidx
    stx pt_tc
    jsr pt_pidx
    stx pt_td
    txa
    asl
    adc pt_td
    adc pt_tc
    tax
    rts
; A = pt_tb * A >> Y (the math unit)
pt_mulsh
    sta M_B
    lda pt_tb
    sta M_A
    lda #0
    sta M_A+1
    sta M_B+1
    sta M_CTRL
    lda M_P+1
    sta pt_tc
    lda M_P
pt_ms_l
    lsr pt_tc
    ror
    dey
    bne pt_ms_l
    rts

; A (binary 0-255) to BCD: pt_vl, pt_vh
pt_bcd
    ldx #0
pt_bc_h
    cmp #100
    bcc pt_bc_t
    sbc #100
    inx
    bne pt_bc_h
pt_bc_t
    stx pt_vh
    ldx #0
pt_bc_t2
    cmp #10
    bcc pt_bc_o
    sbc #10
    inx
    bne pt_bc_t2
pt_bc_o
    sta pt_vl
    txa
    asl
    asl
    asl
    asl
    ora pt_vl
    sta pt_vl
    rts

; credits + the price; credits - the price (C = 1: done; C = 0: not enough,
; unchanged)
pt_add
    sed
    clc
    lda gs_cred+2
    adc pt_vl
    sta gs_cred+2
    lda gs_cred+1
    adc pt_vh
    sta gs_cred+1
    lda gs_cred
    adc #0
    sta gs_cred
    cld
    rts
pt_sub
    sed
    sec
    lda gs_cred+2
    sbc pt_vl
    sta sv_t0
    lda gs_cred+1
    sbc pt_vh
    sta sv_t1
    lda gs_cred
    sbc #0
    cld
    bcc pt_sb_r
    sta gs_cred
    lda sv_t1
    sta gs_cred+1
    lda sv_t0
    sta gs_cred+2
pt_sb_r
    rts

; commodity X's price here (BCD in pt_vl/pt_vh): base x K / 60. A port
; that makes it (sells it) asks K = 60 - stock (3/4 of base when full, up a
; sixtieth for each one gone); one that needs it (buys it) pays K = 75, 84,
; 94, 103 by tier (5/4 of base, an eighth more a tier) - what it's bought
; lately. Bought where it's made, sold where it's needed: a profit, more out
; in the rim. C = 1: the port sells it. (pt_te: the same, as non-zero.)
pt_cprice
    stx pt_ta               ; (its own scratch: callers loop on sv_t3)
    jsr pt_class
    ldx pt_ta
    and gx_bit,x
    sta pt_te
    lda pt_cbase,x
    sta pt_tb               ; (base)
    jsr pt_sidx
    lda pt_stock,x
    ldy pt_te
    beq pt_cp_b
    eor #$FF                ; sells: 60 - stock
    sec
    adc #60
    jsr pt_k60
    sec
    rts
pt_cp_b
    sta pt_tc               ; buys: K by tier - bought
    jsr pt_tier
    tax
    lda pt_ktier,x
    sec
    sbc pt_tc
    jsr pt_k60
    clc
    rts
pt_cbase  .byte 20, 30, 50
pt_ktier  .byte 75, 84, 94, 103
; base (pt_tb) x A / 60, rounded, to BCD (pt_vl, pt_vh)
pt_k60
    sta M_B
    lda pt_tb
    sta M_A
    lda #0
    sta M_A+1
    sta M_B+1
    sta M_CTRL
    clc
    lda M_P
    adc #30
    sta pt_tc
    lda M_P+1
    adc #0
    tay
    lda pt_tc
    ldx #0                  ; / 60: count the sixties
pt_k6_l
    cpy #0
    bne pt_k6_s
    cmp #60
    bcc pt_k6_d
pt_k6_s
    sec
    sbc #60
    bcs pt_k6_n
    dey
pt_k6_n
    inx
    bne pt_k6_l
pt_k6_d
    txa
    jmp pt_bcd
; X = commodity: its stock here (A)
pt_stk
    jsr pt_sidx
    lda pt_stock,x
    rts

; kind X's bounty here: (30 + 8 * kind) * (2 + tier) / 2, less an eighth
; for each creature the port's bought lately, down to half (pt_glut)
pt_bounty
    txa
    asl
    asl
    asl
    adc #30
    sta M_A
    lda #0
    sta M_A+1
    sta M_B+1
    sta M_CTRL
    jsr pt_tier
    clc
    adc #2
    sta M_B
    lda M_P+1
    lsr
    lda M_P
    ror
    sta pt_tb
    jsr pt_pidx
    lda pt_glut,x
    cmp #4
    bcc pt_bo_g
    lda #4
pt_bo_g
    eor #$FF                ; x (8 - glut) / 8
    clc
    adc #9
    ldy #3
    jsr pt_mulsh
    jmp pt_bcd

; ---- the screen ----
;   0  the tab bar (TRADE, BOUNTY, SHIPYARD, and BANK in safe space)
;   1  SECTOR 12  CORE  STARPORT BSB
;   2  (a tab's column heads)
;   3-9 its lines (the selected one a gold bar), LEAVE PORT the last
;   10 CREDITS 000500   HOLDS 04/10
;   11 a message (gold), or the help
pt_build
    jsr sv_cls
    lda pt_tab              ; the frame
    ldx #4
    ldy pt_ntab
    jsr sv_tabbar
    ldx #1                  ; row 1: the sector, its tier, the port's class
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
    lda #2
    jsr sv_skip
    lda #P_CYAN
    jsr sv_pen
    lda #<pt_s_title
    ldy #>pt_s_title
    ldx #9
    jsr sv_puts
    lda #P_WHITE
    jsr sv_pen
    ldx gs_sec
    jsr sv_class
    ldx #2                  ; row 2 (the heads): grey
    lda #0
    ldy #P_GREY
    jsr sv_ink
    ldx #3                  ; the lines: white
    lda #0
    ldy #P_WHITE
    jsr sv_ink
    ; the lines
    lda pt_tab
    bne pt_b_t1
    jsr pt_b_comm
    jmp pt_b_lv
pt_b_t1
    cmp #1
    bne pt_b_t2
    jsr pt_b_bio
    jmp pt_b_lv
pt_b_t2
    cmp #2
    bne pt_b_t3
    jsr pt_b_yard
    jmp pt_b_lv
pt_b_t3
    jsr pt_b_bank
pt_b_lv
    ; the last line: LEAVE PORT
    lda pt_n
    sec
    sbc #1
    jsr pt_line
    lda #<pt_s_leave
    ldy #>pt_s_leave
    ldx #10
    jsr sv_puts
    ; the selected line: a gold bar across the screen, all one colour
    lda sv_sel
    clc
    adc #3
    tax
    lda #0
    sta sv_bn,x
    ldy #P_GOLD
    jsr sv_ink
    lda sv_sel
    clc
    adc #3
    tax
    lda #0
    ldy #40
    jsr sv_inv
pt_b_nm
    ; row 10: credits, holds
    ldx #10
    lda #1
    jsr sv_at
    lda #P_CYAN
    jsr sv_pen
    lda #<pt_s_cred
    ldy #>pt_s_cred
    ldx #8
    jsr sv_puts
    lda #P_WHITE
    jsr sv_pen
    lda gs_cred
    jsr sv_bcd
    lda gs_cred+1
    jsr sv_bcd
    lda gs_cred+2
    jsr sv_bcd
    lda #3
    jsr sv_skip
    lda #P_CYAN
    jsr sv_pen
    lda #<pt_s_holds
    ldy #>pt_s_holds
    ldx #6
    jsr sv_puts
    lda #P_WHITE
    jsr sv_pen
    jsr pt_holdused
    jsr sv_dec2
    lda #("/"-32)*2
    jsr sv_putc
    ldx gs_uhold
    lda up_holds,x
    jsr sv_dec2
    ; row 11: a message (gold), or the help (grey)
    ldx #11
    lda #1
    jsr sv_at
    ldx pt_msg
    beq pt_b_hp
    lda #P_GOLD
    jsr sv_pen
    ldx pt_msg
    lda pt_msglo-1,x
    pha
    lda pt_msghi-1,x
    tay
    lda pt_msglen-1,x
    tax
    pla
    jmp sv_puts
pt_b_hp
    lda #P_GREY
    jsr sv_pen
    lda pt_tab
    cmp #1
    beq pt_b_hk
    lda #<pt_s_help
    ldy #>pt_s_help
    ldx #32
    jmp sv_puts
pt_b_hk
    lda #<pt_s_helpk
    ldy #>pt_s_helpk
    ldx #31
    jmp sv_puts

; sv_dst = line A (row 3 + A), column 2 (pt_build marks the selected one)
pt_line
    clc
    adc #3
    tax
    lda #2
    jmp sv_at

; COMMODITIES: (row 2: HELD over the numbers)
;   NAME  nn   SELLS nnn  nn LEFT / BUYS  nnn  WANTS nn
pt_b_comm
    ldx #2
    lda #13
    jsr sv_at
    lda #<pt_s_held
    ldy #>pt_s_held
    ldx #4
    jsr sv_puts
    lda #4
    sta pt_n
    ldx #0
pt_bc_l
    stx sv_t3
    txa
    jsr pt_line
    ldx sv_t3
    lda pt_cnlo,x
    ldy pt_cnhi,x
    ldx #9
    jsr sv_puts
    lda #2
    jsr sv_skip
    ldx sv_t3
    lda gs_ore,x
    jsr sv_dec2
    lda #3
    jsr sv_skip
    ldx sv_t3
    jsr pt_cprice
    bcc pt_bc_b
    lda #<pt_s_psells
    ldy #>pt_s_psells
    bne pt_bc_p
pt_bc_b
    lda #<pt_s_pbuys
    ldy #>pt_s_pbuys
pt_bc_p
    ldx #6
    jsr sv_puts
    jsr pt_putprice
    lda #2
    jsr sv_skip
    ldx sv_t3
    jsr pt_stk
    ldy pt_te
    beq pt_bc_w
    jsr sv_dec2             ; nn LEFT
    lda #<pt_s_left
    ldy #>pt_s_left
    ldx #5
    jsr sv_puts
    jmp pt_bc_n
pt_bc_w
    eor #PT_FULL            ; WANTS nn
    pha
    lda #<pt_s_wants
    ldy #>pt_s_wants
    ldx #6
    jsr sv_puts
    pla
    jsr sv_dec2
pt_bc_n
    ldx sv_t3
    inx
    cpx #3
    bne pt_bc_l
    ; row 8: the relic's rumour (near it: the first sector its warps reach)
    lda gs_relst
    bne pt_bc_r
    ldx #8
    lda #1
    jsr sv_at
    lda #P_GOLD
    jsr sv_pen
    lda #<pt_s_rumour
    ldy #>pt_s_rumour
    ldx #37
    jsr sv_puts
    ldx #0
pt_bc_rw
    stx sv_t3
    lda gs_relic
    jsr gx_warpto
    bcc pt_bc_rs
    ldx sv_t3
    inx
    cpx #8
    bne pt_bc_rw
    lda gs_relic            ; (no warps out: its own)
pt_bc_rs
    clc
    adc #1
    jmp sv_dec2
pt_bc_r
    rts
pt_cnlo   .byte <pt_s_c0, <pt_s_c1, <pt_s_c2
pt_cnhi   .byte >pt_s_c0, >pt_s_c1, >pt_s_c2

; the price (pt_vh, pt_vl) as 3 digits (hundreds, tens, ones)
pt_putprice
    lda pt_vh
    and #15
    jsr tx_digit
    jsr sv_putc
    lda pt_vl
    jmp sv_bcd

; BIO-BOUNTY: NAME  nn IN STASIS   BOUNTY nnn   KEPT
pt_b_bio
    lda #7
    sta pt_n
    ldx #0
pt_bb_l
    stx sv_t3
    txa
    jsr pt_line
    ldx sv_t3
    lda pt_knlo,x
    ldy pt_knhi,x
    ldx #9
    jsr sv_puts
    ldx sv_t3
    lda gs_stasis,x
    jsr sv_dec2
    lda #<pt_s_stasis
    ldy #>pt_s_stasis
    ldx #7
    jsr sv_puts
    lda #2
    jsr sv_skip
    lda #<pt_s_bounty
    ldy #>pt_s_bounty
    ldx #7
    jsr sv_puts
    ldx sv_t3
    jsr pt_bounty
    jsr pt_putprice
    lda #1
    jsr sv_skip
    ldx sv_t3
    lda gs_keep,x
    beq pt_bb_n
    lda #<pt_s_kept
    ldy #>pt_s_kept
    ldx #5
    jsr sv_puts
    ldx sv_t3
    lda gs_keep,x
    jsr tx_digit
    jsr sv_putc
pt_bb_n
    ldx sv_t3
    inx
    cpx #6
    bne pt_bb_l
    rts
pt_knlo   .byte <pt_s_k0, <pt_s_k1, <pt_s_k2, <pt_s_k3, <pt_s_k4, <pt_s_k5
pt_knhi   .byte >pt_s_k0, >pt_s_k1, >pt_s_k2, >pt_s_k3, >pt_s_k4, >pt_s_k5

; SHIPYARD
pt_b_yard
    lda #4
    sta pt_n
    lda #0                  ; REPAIR   ENERGY nnn/nnn   n A POINT
    jsr pt_line
    lda #<pt_s_y1
    ldy #>pt_s_y1
    ldx #16
    jsr sv_puts
    lda sp_energy
    jsr sv_dec3
    lda #("/"-32)*2
    jsr sv_putc
    lda sp_enmax
    jsr sv_dec3
    lda #3
    jsr sv_skip
    jsr pt_tier
    tax
    lda pt_repc,x
    jsr tx_digit
    jsr sv_putc
    lda #<pt_s_each1
    ldy #>pt_s_each1
    ldx #8
    jsr sv_puts
    lda #1                  ; HULL     nnn  NEXT nnnn (+5 energy each)
    jsr pt_line
    lda #<pt_s_y2
    ldy #>pt_s_y2
    ldx #9
    jsr sv_puts
    lda sp_enmax
    jsr sv_dec3
    ldx #0
    jsr pt_putnext
    lda #2                  ; HOLDS    nn   NEXT nnnn
    jsr pt_line
    lda #<pt_s_y3
    ldy #>pt_s_y3
    ldx #9
    jsr sv_puts
    ldx gs_uhold
    lda up_holds,x
    jsr sv_dec2
    ldx #1
    jmp pt_putnext

; BANK: SAVINGS nnnnnn  SAFE IF THE ARK IS LOST; deposit, withdraw
pt_b_bank
    lda #5
    sta pt_n
    ldx #2                  ; (the savings: white, not a heading)
    lda #0
    ldy #P_WHITE
    jsr sv_ink
    ldx #2
    lda #1
    jsr sv_at
    lda #<pt_s_sav
    ldy #>pt_s_sav
    ldx #8
    jsr sv_puts
    lda gs_bank
    jsr sv_bcd
    lda gs_bank+1
    jsr sv_bcd
    lda gs_bank+2
    jsr sv_bcd
    lda #2
    jsr sv_skip
    lda #<pt_s_safe
    ldy #>pt_s_safe
    ldx #23
    jsr sv_puts
    ldx #0
pt_bk_l
    stx sv_t3
    txa
    jsr pt_line
    ldx sv_t3
    lda pt_bklo,x
    ldy pt_bkhi,x
    ldx #12
    jsr sv_puts
    ldx sv_t3
    inx
    cpx #4
    bne pt_bk_l
    rts
pt_bklo   .byte <pt_s_bk0, <pt_s_bk1, <pt_s_bk2, <pt_s_bk3
pt_bkhi   .byte >pt_s_bk0, >pt_s_bk1, >pt_s_bk2, >pt_s_bk3

; BANK: lines 0-1 deposit 100 / all, 2-3 withdraw 100 / all
pt_bank
    lda sv_sel
    lsr
    lda #0                  ; the amount: 100, or everything ($99s: less
    sta pt_amt              ;  if there's less)
    sta pt_amt+2
    lda #1
    bcc pt_bn_a
    lda #$99
    sta pt_amt
    sta pt_amt+2
pt_bn_a
    sta pt_amt+1
    ldx #0
    ldy #PT_BANKOFS
    lda sv_sel
    cmp #2
    bcc pt_bn_m
    ldx #PT_BANKOFS
    ldy #0
pt_bn_m
    jsr pt_move
    lda pt_amt
    ora pt_amt+1
    ora pt_amt+2
    bne pt_bn_ok
    lda #14
    jmp pt_say
pt_bn_ok
    lda sv_sel
    cmp #2
    lda #12
    adc #0
    jmp pt_say

; move pt_amt (BCD) from account X to account Y (0 the credits, PT_BANKOFS
; the bank): no more than X has (pt_amt: what moved)
pt_move
    lda gs_cred,x
    cmp pt_amt
    bcc pt_mv_less
    bne pt_mv_go
    lda gs_cred+1,x
    cmp pt_amt+1
    bcc pt_mv_less
    bne pt_mv_go
    lda gs_cred+2,x
    cmp pt_amt+2
    bcs pt_mv_go
pt_mv_less
    lda gs_cred,x
    sta pt_amt
    lda gs_cred+1,x
    sta pt_amt+1
    lda gs_cred+2,x
    sta pt_amt+2
pt_mv_go
    sed
    sec
    lda gs_cred+2,x
    sbc pt_amt+2
    sta gs_cred+2,x
    lda gs_cred+1,x
    sbc pt_amt+1
    sta gs_cred+1,x
    lda gs_cred,x
    sbc pt_amt
    sta gs_cred,x
    clc
    lda gs_cred+2,y
    adc pt_amt+2
    sta gs_cred+2,y
    lda gs_cred+1,y
    adc pt_amt+1
    sta gs_cred+1,y
    lda gs_cred,y
    adc pt_amt
    sta gs_cred,y
    cld
    rts

; upgrade X's next price, or MAX
pt_putnext
    stx sv_t3
    lda #3
    jsr sv_skip
    ldx sv_t3
    lda gs_ulas,x
    cmp pt_upmax,x
    bcc pt_pn_n
    lda #<pt_s_max
    ldy #>pt_s_max
    ldx #3
    jmp sv_puts
pt_pn_n
    lda #<pt_s_next
    ldy #>pt_s_next
    ldx #5
    jsr sv_puts
    jsr pt_upprice
    lda pt_vh
    jsr sv_bcd
    lda pt_vl
    jmp sv_bcd

; upgrade sv_t3's next price (BCD: pt_vh hundreds+thousands, pt_vl). The
; hull: 1000 + 200 a level (in hundreds, to BCD)
pt_upprice
    ldx sv_t3
    bne pt_up_t
    lda gs_ulas
    asl
    adc #10
    jsr pt_bcd
    lda pt_vl
    sta pt_vh
    lda #0
    sta pt_vl
    rts
pt_up_t
    lda gs_ulas,x           ; (level 0 or 1)
    asl
    clc
    adc sv_t3
    adc sv_t3
    adc sv_t3
    adc sv_t3               ; (x 4 + level x 2: the table's place)
    tax
    lda pt_uptab,x
    sta pt_vh
    lda pt_uptab+1,x
    sta pt_vl
    rts
; by upgrade (the hull: pt_upprice's own), holds, tanks: level 1, level 2
; (BCD, high byte first); the levels there are
pt_upmax  .byte EN_UPS, 2, 2
pt_uptab  .byte $00, $00, $00, $00
          .byte $30, $00, $60, $00
          .byte $30, $00, $60, $00

; ---- input ----
pt_input
    ; button 2 (fresh): the next tab
    lda sp_fire2
    beq pt_i_nt
    lda sv_pf2
    bne pt_i_nt
    ldx pt_tab
    inx
    cpx pt_ntab
    bcc pt_i_t
    ldx #0
pt_i_t
    stx pt_tab
    lda #0
    sta sv_sel
    sta pt_msg
    inc sv_dirty
    lda #SFX_BEEP
    jmp sfx
pt_i_nt
    ; the stick (fresh): up, down a line; left (Bio-Bounty): keep one
    ldx sp_joy
    cpx sv_pjoy
    beq pt_i_f
    cpx #0
    bne pt_i_dn
    lda sv_sel
    beq pt_i_f
    dec sv_sel
    jmp pt_i_mv
pt_i_dn
    cpx #4
    bne pt_i_lt
    lda sv_sel
    clc
    adc #1
    cmp pt_n
    bcs pt_i_f
    sta sv_sel
pt_i_mv
    lda #0
    sta pt_msg
    inc sv_dirty
    lda #SFX_BEEP
    jmp sfx
pt_i_lt
    cpx #6
    bne pt_i_f
    lda pt_tab
    cmp #1
    bne pt_i_f
    jmp pt_keep
pt_i_f
    ; fire (fresh): the line
    lda sp_fire
    beq pt_i_r
    lda sv_pf
    bne pt_i_r
    inc sv_dirty
    lda sv_sel
    clc
    adc #1
    cmp pt_n
    beq pt_leave
    lda pt_tab
    bne pt_i_f1
    jmp pt_trade
pt_i_f1
    cmp #1
    bne pt_i_f2
    jmp pt_sell
pt_i_f2
    cmp #2
    bne pt_i_f3
    jmp pt_yard
pt_i_f3
    jmp pt_bank
pt_i_r
    rts

pt_leave
    jsr sl_save             ; (what was traded here kept)
    lda #0
    sta pt_msg
    sta sv_view
    sta sv_sel
    lda #SFX_LAUNCH
    jsr sfx
    jmp sv_depart           ; leaving: an encounter?

pt_say
    sta pt_msg
    tax
    lda pt_msgsfx-1,x
    jmp sfx

; COMMODITIES: the port sells it: buy one; it buys it: sell one
pt_trade
    ldx sv_sel
    jsr pt_cprice
    bcs pt_tr_buy
    ldx sv_sel
    lda gs_ore,x
    bne pt_tr_s
    lda #5
    jmp pt_say
pt_tr_s
    ldx sv_sel              ; it wants no more
    jsr pt_stk
    cmp #PT_FULL
    bcc pt_tr_s2
    lda #11
    jmp pt_say
pt_tr_s2
    inc pt_stock,x
    inc gs_sold             ; (MERCHANT: goods sold)
    bne pt_tr_s3
    dec gs_sold
pt_tr_s3
    ldx sv_sel
    dec gs_ore,x
    jsr pt_add
    lda #1
    jmp pt_say
pt_tr_buy
    ldx sv_sel              ; none left
    jsr pt_stk
    bne pt_tr_b1
    lda #10
    jmp pt_say
pt_tr_b1
    jsr pt_holdfree
    bcs pt_tr_b2
    lda #4
    jmp pt_say
pt_tr_b2
    jsr pt_sub
    bcs pt_tr_b3
    lda #3
    jmp pt_say
pt_tr_b3
    ldx sv_sel
    inc gs_ore,x
    jsr pt_sidx
    dec pt_stock,x
    lda #2
    jmp pt_say

; BIO-BOUNTY: sell one of the kind
pt_sell
    ldx sv_sel
    lda gs_stasis,x
    bne pt_sl_s
    lda #5
    jmp pt_say
pt_sl_s
    dec gs_stasis,x
    jsr pt_bounty
    jsr pt_add
    jsr pt_pidx             ; it's had one more
    lda pt_glut,x
    cmp #15
    bcs pt_sl_g
    inc pt_glut,x
pt_sl_g
    lda #1
    jmp pt_say
; ... or keep one (a pair of each: the manifest; kept ones leave the holds
; for the Ark's own bays)
pt_keep
    inc sv_dirty
    ldx sv_sel
    cpx #6
    bcs pt_kp_r
    lda gs_keep,x
    cmp #2
    bcc pt_kp_1
    lda #9
    jmp pt_say
pt_kp_1
    lda gs_stasis,x
    bne pt_kp_2
    lda #5
    jmp pt_say
pt_kp_2
    dec gs_stasis,x
    inc gs_keep,x
    lda #6
    jmp pt_say
pt_kp_r
    rts

; SHIPYARD
pt_yard
    lda sv_sel
    bne pt_y2
    ; energy to the full, while the credits last
    lda #0
    sta sv_t4
pt_y1_l
    lda sp_energy
    cmp sp_enmax
    bcs pt_y1_d
    jsr pt_tier
    tax
    lda pt_repc,x
    sta pt_vl
    lda #0
    sta pt_vh
    jsr pt_sub
    bcc pt_y1_d
    inc sp_energy
    inc sv_t4
    bne pt_y1_l
pt_y1_d
pt_y_said
    lda sv_t4               ; some bought: BOUGHT; none: full, or broke
    beq pt_y_none
    lda #2
    jmp pt_say
pt_y_none
    lda sp_energy
    cmp sp_enmax
    bcs pt_y_full
    lda #3
    jmp pt_say
pt_y_full
    lda #7
    jmp pt_say
pt_y2
    ; an upgrade (the hull, holds)
    sec
    sbc #1
    sta sv_t3
    tax
    lda gs_ulas,x
    cmp pt_upmax,x
    bcc pt_y2_n
    lda #7
    jmp pt_say
pt_y2_n
    jsr pt_upprice
    jsr pt_sub
    bcs pt_y2_ok
    lda #3
    jmp pt_say
pt_y2_ok
    ldx sv_t3
    inc gs_ulas,x
    txa
    bne pt_y2_m
    jsr en_setmax           ; the hull: 5 more, and those 5 filled
    lda sp_energy
    clc
    adc #EN_STEP
    sta sp_energy
pt_y2_m
    lda #8
    jmp pt_say

; energy a point, by tier (BCD, < 10)
pt_repc   .byte 4, 5, 6, 8

; messages
pt_msglo  .byte <pt_m1, <pt_m2, <pt_m3, <pt_m4, <pt_m5, <pt_m6, <pt_m7, <pt_m8, <pt_m9, <pt_m10, <pt_m11, <pt_m12, <pt_m13, <pt_m14, <pt_m15, <pt_m16, <pt_m17
pt_msghi  .byte >pt_m1, >pt_m2, >pt_m3, >pt_m4, >pt_m5, >pt_m6, >pt_m7, >pt_m8, >pt_m9, >pt_m10, >pt_m11, >pt_m12, >pt_m13, >pt_m14, >pt_m15, >pt_m16, >pt_m17
pt_msglen .byte 4, 6, 18, 18, 12, 21, 12, 8, 22, 8, 17, 9, 9, 15, 37, 12, 26
pt_msgsfx .byte SFX_POD, SFX_POD, SFX_HIT, SFX_HIT, SFX_HIT, SFX_DELIVER, SFX_BEEP, SFX_CLEAR, SFX_BEEP, SFX_HIT, SFX_HIT, SFX_POD, SFX_POD, SFX_HIT, SFX_CLEAR, SFX_DOCK, SFX_HIT

; ---- strings ----
pt_s_title .byte ("S"-32)*2,("T"-32)*2,("A"-32)*2,("R"-32)*2,("P"-32)*2,("O"-32)*2,("R"-32)*2,("T"-32)*2,0   ; 'STARPORT ' (9)
pt_s_c0 .byte ("F"-32)*2,("U"-32)*2,("E"-32)*2,("L"-32)*2,0,("O"-32)*2,("R"-32)*2,("E"-32)*2,0   ; 'FUEL ORE ' (9)
pt_s_c1 .byte ("O"-32)*2,("R"-32)*2,("G"-32)*2,("A"-32)*2,("N"-32)*2,("I"-32)*2,("C"-32)*2,("S"-32)*2,0   ; 'ORGANICS ' (9)
pt_s_c2 .byte ("E"-32)*2,("Q"-32)*2,("U"-32)*2,("I"-32)*2,("P"-32)*2,("M"-32)*2,("E"-32)*2,("N"-32)*2,("T"-32)*2   ; 'EQUIPMENT' (9)
pt_s_held .byte ("H"-32)*2,("E"-32)*2,("L"-32)*2,("D"-32)*2   ; 'HELD' (4)
pt_s_pbuys .byte ("B"-32)*2,("U"-32)*2,("Y"-32)*2,("S"-32)*2,0,0   ; 'BUYS  ' (6)
pt_s_psells .byte ("S"-32)*2,("E"-32)*2,("L"-32)*2,("L"-32)*2,("S"-32)*2,0   ; 'SELLS ' (6)
pt_s_k0 .byte ("W"-32)*2,("A"-32)*2,("L"-32)*2,("K"-32)*2,("E"-32)*2,("R"-32)*2,0,0,0   ; 'WALKER   ' (9)
pt_s_k1 .byte ("H"-32)*2,("O"-32)*2,("P"-32)*2,("P"-32)*2,("E"-32)*2,("R"-32)*2,0,0,0   ; 'HOPPER   ' (9)
pt_s_k2 .byte ("R"-32)*2,("U"-32)*2,("N"-32)*2,("N"-32)*2,("E"-32)*2,("R"-32)*2,0,0,0   ; 'RUNNER   ' (9)
pt_s_k3 .byte ("B"-32)*2,("U"-32)*2,("R"-32)*2,("R"-32)*2,("O"-32)*2,("W"-32)*2,("E"-32)*2,("R"-32)*2,0   ; 'BURROWER ' (9)
pt_s_k4 .byte ("G"-32)*2,("L"-32)*2,("I"-32)*2,("D"-32)*2,("E"-32)*2,("R"-32)*2,0,0,0   ; 'GLIDER   ' (9)
pt_s_k5 .byte ("B"-32)*2,("L"-32)*2,("I"-32)*2,("N"-32)*2,("K"-32)*2,("E"-32)*2,("R"-32)*2,0,0   ; 'BLINKER  ' (9)
pt_s_stasis .byte 0,("S"-32)*2,("T"-32)*2,("A"-32)*2,("S"-32)*2,("I"-32)*2,("S"-32)*2   ; ' STASIS' (7)
pt_s_bounty .byte ("B"-32)*2,("O"-32)*2,("U"-32)*2,("N"-32)*2,("T"-32)*2,("Y"-32)*2,0   ; 'BOUNTY ' (7)
pt_s_kept .byte ("K"-32)*2,("E"-32)*2,("P"-32)*2,("T"-32)*2,0   ; 'KEPT ' (5)
pt_s_y1 .byte ("R"-32)*2,("E"-32)*2,("P"-32)*2,("A"-32)*2,("I"-32)*2,("R"-32)*2,0,0,0,("E"-32)*2,("N"-32)*2,("E"-32)*2,("R"-32)*2,("G"-32)*2,("Y"-32)*2,0   ; 'REPAIR   ENERGY ' (16)
pt_s_y2 .byte ("H"-32)*2,("U"-32)*2,("L"-32)*2,("L"-32)*2,0,0,0,0,0   ; 'HULL     ' (9)
pt_s_y3 .byte ("H"-32)*2,("O"-32)*2,("L"-32)*2,("D"-32)*2,("S"-32)*2,0,0,0,0   ; 'HOLDS    ' (9)
pt_s_next .byte ("N"-32)*2,("E"-32)*2,("X"-32)*2,("T"-32)*2,0   ; 'NEXT ' (5)
pt_s_max .byte ("M"-32)*2,("A"-32)*2,("X"-32)*2   ; 'MAX' (3)
pt_s_each1 .byte 0,("A"-32)*2,0,("P"-32)*2,("O"-32)*2,("I"-32)*2,("N"-32)*2,("T"-32)*2   ; ' A POINT' (8)
pt_s_leave .byte ("L"-32)*2,("E"-32)*2,("A"-32)*2,("V"-32)*2,("E"-32)*2,0,("P"-32)*2,("O"-32)*2,("R"-32)*2,("T"-32)*2   ; 'LEAVE PORT' (10)
pt_s_cred .byte ("C"-32)*2,("R"-32)*2,("E"-32)*2,("D"-32)*2,("I"-32)*2,("T"-32)*2,("S"-32)*2,0   ; 'CREDITS ' (8)
pt_s_holds .byte ("H"-32)*2,("O"-32)*2,("L"-32)*2,("D"-32)*2,("S"-32)*2,0   ; 'HOLDS ' (6)
pt_s_help .byte ("F"-32)*2,("I"-32)*2,("R"-32)*2,("E"-32)*2,(":"-32)*2,0,("T"-32)*2,("R"-32)*2,("A"-32)*2,("D"-32)*2,("E"-32)*2,0,0,0,("B"-32)*2,("U"-32)*2,("T"-32)*2,("T"-32)*2,("O"-32)*2,("N"-32)*2,0,("2"-32)*2,(":"-32)*2,0,("N"-32)*2,("E"-32)*2,("X"-32)*2,("T"-32)*2,0,("T"-32)*2,("A"-32)*2,("B"-32)*2   ; 'FIRE: TRADE   BUTTON 2: NEXT TAB' (32)
pt_s_helpk .byte ("F"-32)*2,("I"-32)*2,("R"-32)*2,("E"-32)*2,(":"-32)*2,0,("S"-32)*2,("E"-32)*2,("L"-32)*2,("L"-32)*2,0,("O"-32)*2,("N"-32)*2,("E"-32)*2,0,0,0,("L"-32)*2,("E"-32)*2,("F"-32)*2,("T"-32)*2,(":"-32)*2,0,("K"-32)*2,("E"-32)*2,("E"-32)*2,("P"-32)*2,0,("O"-32)*2,("N"-32)*2,("E"-32)*2   ; 'FIRE: SELL ONE   LEFT: KEEP ONE' (31)
pt_m1 .byte ("S"-32)*2,("O"-32)*2,("L"-32)*2,("D"-32)*2   ; 'SOLD' (4)
pt_m2 .byte ("B"-32)*2,("O"-32)*2,("U"-32)*2,("G"-32)*2,("H"-32)*2,("T"-32)*2   ; 'BOUGHT' (6)
pt_m3 .byte ("N"-32)*2,("O"-32)*2,("T"-32)*2,0,("E"-32)*2,("N"-32)*2,("O"-32)*2,("U"-32)*2,("G"-32)*2,("H"-32)*2,0,("C"-32)*2,("R"-32)*2,("E"-32)*2,("D"-32)*2,("I"-32)*2,("T"-32)*2,("S"-32)*2   ; 'NOT ENOUGH CREDITS' (18)
pt_m4 .byte ("T"-32)*2,("H"-32)*2,("E"-32)*2,0,("H"-32)*2,("O"-32)*2,("L"-32)*2,("D"-32)*2,("S"-32)*2,0,("A"-32)*2,("R"-32)*2,("E"-32)*2,0,("F"-32)*2,("U"-32)*2,("L"-32)*2,("L"-32)*2   ; 'THE HOLDS ARE FULL' (18)
pt_m5 .byte ("N"-32)*2,("O"-32)*2,("N"-32)*2,("E"-32)*2,0,("T"-32)*2,("O"-32)*2,0,("S"-32)*2,("E"-32)*2,("L"-32)*2,("L"-32)*2   ; 'NONE TO SELL' (12)
pt_m6 .byte ("K"-32)*2,("E"-32)*2,("P"-32)*2,("T"-32)*2,0,("F"-32)*2,("O"-32)*2,("R"-32)*2,0,("T"-32)*2,("H"-32)*2,("E"-32)*2,0,("M"-32)*2,("A"-32)*2,("N"-32)*2,("I"-32)*2,("F"-32)*2,("E"-32)*2,("S"-32)*2,("T"-32)*2   ; 'KEPT FOR THE MANIFEST' (21)
pt_m7 .byte ("A"-32)*2,("L"-32)*2,("R"-32)*2,("E"-32)*2,("A"-32)*2,("D"-32)*2,("Y"-32)*2,0,("F"-32)*2,("U"-32)*2,("L"-32)*2,("L"-32)*2   ; 'ALREADY FULL' (12)
pt_m8 .byte ("U"-32)*2,("P"-32)*2,("G"-32)*2,("R"-32)*2,("A"-32)*2,("D"-32)*2,("E"-32)*2,("D"-32)*2   ; 'UPGRADED' (8)
pt_m9 .byte ("A"-32)*2,0,("P"-32)*2,("A"-32)*2,("I"-32)*2,("R"-32)*2,0,("I"-32)*2,("S"-32)*2,0,("A"-32)*2,("L"-32)*2,("R"-32)*2,("E"-32)*2,("A"-32)*2,("D"-32)*2,("Y"-32)*2,0,("K"-32)*2,("E"-32)*2,("P"-32)*2,("T"-32)*2   ; 'A PAIR IS ALREADY KEPT' (22)
pt_m10 .byte ("S"-32)*2,("O"-32)*2,("L"-32)*2,("D"-32)*2,0,("O"-32)*2,("U"-32)*2,("T"-32)*2   ; 'SOLD OUT' (8)
pt_m11 .byte ("T"-32)*2,("H"-32)*2,("E"-32)*2,("Y"-32)*2,0,("W"-32)*2,("A"-32)*2,("N"-32)*2,("T"-32)*2,0,("N"-32)*2,("O"-32)*2,0,("M"-32)*2,("O"-32)*2,("R"-32)*2,("E"-32)*2   ; 'THEY WANT NO MORE' (17)
pt_s_left .byte 0,("L"-32)*2,("E"-32)*2,("F"-32)*2,("T"-32)*2   ; ' LEFT' (5)
pt_s_wants .byte ("W"-32)*2,("A"-32)*2,("N"-32)*2,("T"-32)*2,("S"-32)*2,0   ; 'WANTS ' (6)
pt_s_sav .byte ("S"-32)*2,("A"-32)*2,("V"-32)*2,("I"-32)*2,("N"-32)*2,("G"-32)*2,("S"-32)*2,0   ; 'SAVINGS ' (8)
pt_s_safe .byte ("S"-32)*2,("A"-32)*2,("F"-32)*2,("E"-32)*2,0,("I"-32)*2,("F"-32)*2,0,("T"-32)*2,("H"-32)*2,("E"-32)*2,0,("A"-32)*2,("R"-32)*2,("K"-32)*2,0,("I"-32)*2,("S"-32)*2,0,("L"-32)*2,("O"-32)*2,("S"-32)*2,("T"-32)*2   ; 'SAFE IF THE ARK IS LOST' (23)
pt_s_bk0 .byte ("D"-32)*2,("E"-32)*2,("P"-32)*2,("O"-32)*2,("S"-32)*2,("I"-32)*2,("T"-32)*2,0,("1"-32)*2,("0"-32)*2,("0"-32)*2,0   ; 'DEPOSIT 100 ' (12)
pt_s_bk1 .byte ("D"-32)*2,("E"-32)*2,("P"-32)*2,("O"-32)*2,("S"-32)*2,("I"-32)*2,("T"-32)*2,0,("A"-32)*2,("L"-32)*2,("L"-32)*2,0   ; 'DEPOSIT ALL ' (12)
pt_s_bk2 .byte ("W"-32)*2,("I"-32)*2,("T"-32)*2,("H"-32)*2,("D"-32)*2,("R"-32)*2,("A"-32)*2,("W"-32)*2,0,("1"-32)*2,("0"-32)*2,("0"-32)*2   ; 'WITHDRAW 100' (12)
pt_s_bk3 .byte ("W"-32)*2,("I"-32)*2,("T"-32)*2,("H"-32)*2,("D"-32)*2,("R"-32)*2,("A"-32)*2,("W"-32)*2,0,("A"-32)*2,("L"-32)*2,("L"-32)*2   ; 'WITHDRAW ALL' (12)
pt_m12 .byte ("D"-32)*2,("E"-32)*2,("P"-32)*2,("O"-32)*2,("S"-32)*2,("I"-32)*2,("T"-32)*2,("E"-32)*2,("D"-32)*2   ; 'DEPOSITED' (9)
pt_m13 .byte ("W"-32)*2,("I"-32)*2,("T"-32)*2,("H"-32)*2,("D"-32)*2,("R"-32)*2,("A"-32)*2,("W"-32)*2,("N"-32)*2   ; 'WITHDRAWN' (9)
pt_m14 .byte ("N"-32)*2,("O"-32)*2,("T"-32)*2,("H"-32)*2,("I"-32)*2,("N"-32)*2,("G"-32)*2,0,("T"-32)*2,("O"-32)*2,0,("M"-32)*2,("O"-32)*2,("V"-32)*2,("E"-32)*2   ; 'NOTHING TO MOVE' (15)
pt_m15 .byte ("T"-32)*2,("H"-32)*2,("E"-32)*2,0,("R"-32)*2,("E"-32)*2,("L"-32)*2,("I"-32)*2,("C"-32)*2,(":"-32)*2,0,("2"-32)*2,("0"-32)*2,("0"-32)*2,("0"-32)*2,0,("C"-32)*2,("R"-32)*2,("E"-32)*2,("D"-32)*2,("I"-32)*2,("T"-32)*2,("S"-32)*2,0,("F"-32)*2,("R"-32)*2,("O"-32)*2,("M"-32)*2,0,("T"-32)*2,("H"-32)*2,("E"-32)*2,0,("P"-32)*2,("O"-32)*2,("R"-32)*2,("T"-32)*2   ; 'THE RELIC: 2000 CREDITS FROM THE PORT' (37)
pt_m16 .byte ("V"-32)*2,("O"-32)*2,("Y"-32)*2,("A"-32)*2,("G"-32)*2,("E"-32)*2,0,("S"-32)*2,("A"-32)*2,("V"-32)*2,("E"-32)*2,("D"-32)*2   ; 'VOYAGE SAVED' (12)
pt_m17 .byte ("T"-32)*2,("H"-32)*2,("E"-32)*2,0,("S"-32)*2,("A"-32)*2,("V"-32)*2,("E"-32)*2,("K"-32)*2,("E"-32)*2,("Y"-32)*2,0,("D"-32)*2,("I"-32)*2,("D"-32)*2,0,("N"-32)*2,("O"-32)*2,("T"-32)*2,0,("A"-32)*2,("N"-32)*2,("S"-32)*2,("W"-32)*2,("E"-32)*2,("R"-32)*2   ; 'THE SAVEKEY DID NOT ANSWER' (26)
pt_s_rumour .byte ("R"-32)*2,("U"-32)*2,("M"-32)*2,("O"-32)*2,("U"-32)*2,("R"-32)*2,(":"-32)*2,0,("S"-32)*2,("T"-32)*2,("R"-32)*2,("A"-32)*2,("N"-32)*2,("G"-32)*2,("E"-32)*2,0,("R"-32)*2,("E"-32)*2,("A"-32)*2,("D"-32)*2,("I"-32)*2,("N"-32)*2,("G"-32)*2,("S"-32)*2,0,("N"-32)*2,("E"-32)*2,("A"-32)*2,("R"-32)*2,0,("S"-32)*2,("E"-32)*2,("C"-32)*2,("T"-32)*2,("O"-32)*2,("R"-32)*2,0   ; 'RUMOUR: STRANGE READINGS NEAR SECTOR ' (37)
