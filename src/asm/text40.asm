; ===========================================================================
; The 40-column screens' text (bank 1: the map, the port, the achievements):
; 12 rows of 40 in RAM ($2200 rows 0-5, $2700 rows 6-11); helpers that write
; into them (sv_dst).
;
; Colour: a 320A object has one palette, so a row is drawn as segments, one
; object each, split where its colour changes. Each row keeps up to SV_NB
; changes (sv_ink: a column and the palette from there on; white before the
; first), sorted by column. Rows are drawn only as far as their last
; character (sv_rlen, worked out once after sv_cls), so blank rows and the
; blank ends of rows cost MARIA nothing.
;
; Inverse text (sv_inv: code + 1, the font's odd codes 1-127) makes a bar 8
; lines high with the letters cut out: the tab bars, the status panel's
; labels, the selected line.
;
; The changes' RAM is deep space's (rocks, bolts, shots, pirates), free on
; these screens: deep space clears its tables when an encounter starts
; (sp_return: sp_clear, pr_new, the shots).
; ===========================================================================

P_WHITE   = 0       ; the map's palettes (the BASIC's mappal)
P_GOLD    = 1
P_CYAN    = 2
P_GREY    = 3
P_GREEN   = 5
P_RED     = 6
P_BLUE    = 7

SV_NB     = 10      ; colour changes a row, at most (more are dropped)
sv_bcol   = $2300   ; [12 x SV_NB] the changes: the column
sv_bpal   = $2410   ; [12 x SV_NB] ... and the palette from there on
sv_bn     = $2488   ; [12] changes in each row
sv_rlen   = $2494   ; [12] each row's length (to its last character)
sv_rnew   = $24A0   ; the lengths to work out again (sv_cls sets it)
sv_seg    = $24A1   ; sv_rows: the segment's first column,
sv_segp   = $24A2   ;   its palette,
sv_bi     = $24A3   ;   the change being read,
sv_bend   = $24A4   ;   the row's last one (+ 1),
sv_segend = $24A5   ;   where the segment ends,
sv_segw   = $24A6   ;   its piece's width (at most 32)
sv_row    = $24A7   ; the row sv_at last pointed into
sv_ic     = $24A8   ; sv_ink: column, palette, the row's last change (+ 1),
sv_ip     = $24A9   ;   the place found
sv_ie     = $24AB
sv_iy     = $24AC
sv_lock   = $24AD   ; sv_pen does nothing while it's set (a selected line:
                    ;   all one colour)
sv_iv     = $24B0   ; sv_inv's column
sv_tcur   = $24B1   ; sv_tabbar: the current tab, the first, how many, which
sv_tfirst = $24B2
sv_tn     = $24B3
sv_tk     = $24B4

; the rows: their segments (each split at 32: an object's widest)
sv_rows
    lda sv_rnew
    beq sv_r_go
    jsr sv_lens
sv_r_go
    ldx #0
sv_r_row
    stx sv_t4
    lda sv_rlen,x
    beq sv_r_next
    lda #0
    sta sv_seg
    sta sv_segp
    lda sv_b10,x
    sta sv_bi
    clc
    adc sv_bn,x
    sta sv_bend
sv_r_brk
    ldy sv_bi
    cpy sv_bend
    bcs sv_r_last
    lda sv_bcol,y
    ldx sv_t4
    cmp sv_rlen,x           ; (past the row's end: nothing more to draw)
    bcs sv_r_last
    cmp sv_seg
    beq sv_r_pal
    jsr sv_segplot          ; the segment up to the change
    ldy sv_bi
    lda sv_bcol,y
    sta sv_seg
sv_r_pal
    lda sv_bpal,y
    sta sv_segp
    inc sv_bi
    bne sv_r_brk
sv_r_last
    ldx sv_t4
    lda sv_rlen,x
    jsr sv_segplot
sv_r_next
    ldx sv_t4
    inx
    cpx #12
    bne sv_r_row
    rts

; row sv_t4's segment from column sv_seg to A (not included), palette sv_segp
sv_segplot
    sta sv_segend
sv_sp_l
    sec
    lda sv_segend
    sbc sv_seg
    beq sv_sp_r
    cmp #33
    bcc sv_sp_w
    lda #32
sv_sp_w
    sta sv_segw
    ldx sv_t4
    lda sv_rowlo,x          ; (no row crosses a page)
    clc
    adc sv_seg
    sta temp1
    lda sv_rowhi,x
    sta temp2
    lda #32
    sec
    sbc sv_segw
    and #31
    sta temp3
    lda sv_segp
    asl
    asl
    asl
    asl
    asl
    ora temp3
    sta temp3
    lda sv_seg
    asl
    asl                     ; (4 units a character)
    sta temp4
    stx temp5
    jsr plotcharacters
    lda sv_seg
    clc
    adc sv_segw
    sta sv_seg
    jmp sv_sp_l
sv_sp_r
    rts

; each row's length: to its last character that isn't a space
sv_lens
    lda #0
    sta sv_rnew
    ldx #11
sv_ln_r
    lda sv_rowlo,x
    sta sv_src
    lda sv_rowhi,x
    sta sv_src+1
    ldy #39
sv_ln_c
    lda (sv_src),y
    bne sv_ln_e
    dey
    bpl sv_ln_c
sv_ln_e
    iny
    tya
    sta sv_rlen,x
    dex
    bpl sv_ln_r
    rts

sv_rowlo
    .byte <$2200, <$2228, <$2250, <$2278, <$22A0, <$22C8
    .byte <$2700, <$2728, <$2750, <$2778, <$27A0, <$27C8
sv_rowhi
    .byte >$2200, >$2228, >$2250, >$2278, >$22A0, >$22C8
    .byte >$2700, >$2728, >$2750, >$2778, >$27A0, >$27C8
sv_b10
    .byte 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110

; row X, from column A on: palette Y (a change at that column already:
; replaced). A row's changes stay sorted by column.
sv_ink
    sta sv_ic
    sty sv_ip
    lda sv_b10,x
    clc
    adc sv_bn,x
    sta sv_ie
    ldy sv_b10,x
sv_ik_f
    cpy sv_ie
    bcs sv_ik_ins
    lda sv_bcol,y
    cmp sv_ic
    beq sv_ik_set
    bcs sv_ik_ins
    iny
    bne sv_ik_f
sv_ik_ins
    lda sv_bn,x
    cmp #SV_NB
    bcs sv_ik_r             ; (full)
    inc sv_bn,x
    sty sv_iy               ; the later ones up a place
    ldy sv_ie
sv_ik_sh
    cpy sv_iy
    beq sv_ik_set
    lda sv_bcol-1,y
    sta sv_bcol,y
    lda sv_bpal-1,y
    sta sv_bpal,y
    dey
    jmp sv_ik_sh
sv_ik_set
    lda sv_ic
    sta sv_bcol,y
    lda sv_ip
    sta sv_bpal,y
sv_ik_r
    rts

; palette A from sv_dst on (sv_dst kept); nothing while sv_lock is set
sv_pen
    ldx sv_lock
    bne sv_pn_r
    tay
    ldx sv_row
    lda sv_dst
    sec
    sbc sv_rowlo,x
    jmp sv_ink
sv_pn_r
    rts

; row X, Y characters from column A: inverse (glyphs 128 on as they are)
sv_inv
    sta sv_iv
    lda sv_rowlo,x
    clc
    adc sv_iv
    sta sv_src
    lda sv_rowhi,x
    sta sv_src+1
    dey
sv_iv_l
    lda (sv_src),y
    bmi sv_iv_n
    ora #1
    sta (sv_src),y
sv_iv_n
    dey
    bpl sv_iv_l
    rts

; ---- text helpers: sv_dst points into the rows ----
; sv_dst = row X, column A
sv_at
    stx sv_row
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
; A as three digits
sv_dec3
    ldx #0
sv_d3_l
    cmp #100
    bcc sv_d3_d
    sbc #100
    inx
    bne sv_d3_l
sv_d3_d
    pha
    txa
    jsr tx_digit
    jsr sv_putc
    pla
    jmp sv_dec2
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

; clear the text, and its colours
sv_cls
    ldx #239
    lda #0
sv_cl_l
    sta $2200,x
    sta $2700,x
    dex
    cpx #$FF
    bne sv_cl_l
    ldx #11
sv_cl_b
    sta sv_bn,x
    dex
    bpl sv_cl_b
    sta sv_lock
    lda #1
    sta sv_rnew
    rts

; ---- the frame every 40-column screen shares ----
; Row 0: a tab bar (inverse, cyan; the current tab gold). A: the current
; tab, X: the first in sv_tab* (0 the map's pages, 4 a port's), Y: how many.
sv_tabbar
    sta sv_tcur
    stx sv_tfirst
    sty sv_tn
    lda #0
    sta sv_tk
sv_tb_l
    lda sv_tk
    clc
    adc sv_tfirst
    tax
    lda sv_tabcol,x
    pha
    lda sv_tablo,x
    pha
    lda sv_tabhi,x
    tay
    lda sv_tablen,x
    sta sv_t2
    ldx #0
    pla
    sta sv_src
    pla
    jsr sv_at
    lda sv_src
    ldx sv_t2
    jsr sv_puts
    lda sv_tk               ; the current one: gold, a space either side
    cmp sv_tcur
    bne sv_tb_n
    clc
    adc sv_tfirst
    tax
    lda sv_tabcol,x
    sec
    sbc #1
    pha
    clc
    adc sv_tablen,x
    adc #2
    ldy #P_CYAN
    ldx #0
    jsr sv_ink
    pla
    ldy #P_GOLD
    ldx #0
    jsr sv_ink
sv_tb_n
    inc sv_tk
    lda sv_tk
    cmp sv_tn
    bne sv_tb_l
    ldx #0
    lda #0
    ldy #P_CYAN
    jsr sv_ink
    ldx #0                  ; the whole row inverse: a bar
    lda #0
    ldy #40
    jmp sv_inv
; the tabs: the map's pages, a port's
sv_tabcol .byte 2, 11, 19, 30,  3, 12, 22, 34
sv_tablen .byte 6, 5, 8, 7,  5, 6, 8, 4
sv_tablo  .byte <tx_tsec, <tx_tcha, <tx_tclo, <tx_tach, <tx_ttra, <tx_tbou, <tx_tyar, <tx_tban
sv_tabhi  .byte >tx_tsec, >tx_tcha, >tx_tclo, >tx_tach, >tx_ttra, >tx_tbou, >tx_tyar, >tx_tban
tx_tsec .byte ("S"-32)*2,("E"-32)*2,("C"-32)*2,("T"-32)*2,("O"-32)*2,("R"-32)*2   ; 'SECTOR' (6)
tx_tcha .byte ("C"-32)*2,("H"-32)*2,("A"-32)*2,("R"-32)*2,("T"-32)*2   ; 'CHART' (5)
tx_tclo .byte ("C"-32)*2,("L"-32)*2,("O"-32)*2,("S"-32)*2,("E"-32)*2,0,("U"-32)*2,("P"-32)*2   ; 'CLOSE UP' (8)
tx_tach .byte ("A"-32)*2,("C"-32)*2,("H"-32)*2,("I"-32)*2,("E"-32)*2,("V"-32)*2,("E"-32)*2   ; 'ACHIEVE' (7)
tx_ttra .byte ("T"-32)*2,("R"-32)*2,("A"-32)*2,("D"-32)*2,("E"-32)*2   ; 'TRADE' (5)
tx_tbou .byte ("B"-32)*2,("O"-32)*2,("U"-32)*2,("N"-32)*2,("T"-32)*2,("Y"-32)*2   ; 'BOUNTY' (6)
tx_tyar .byte ("S"-32)*2,("H"-32)*2,("I"-32)*2,("P"-32)*2,("Y"-32)*2,("A"-32)*2,("R"-32)*2,("D"-32)*2   ; 'SHIPYARD' (8)
tx_tban .byte ("B"-32)*2,("A"-32)*2,("N"-32)*2,("K"-32)*2   ; 'BANK' (4)

; Rows 10-11: the status panel. Its labels as an inverse cyan bar, the
; values under them (the energy gold under half, red under a quarter).
;   CREDITS  BANK    ENERGY  HOLDS MANIFEST
;   000500   000000  100/100 00/10 00/12
sv_status
    ldx #10
    lda #1
    jsr sv_at
    lda #<tx_stlab
    ldy #>tx_stlab
    ldx #39
    jsr sv_puts
    ldx #10
    lda #0
    ldy #40
    jsr sv_inv
    ldx #10
    lda #0
    ldy #P_CYAN
    jsr sv_ink
    ldx #11                 ; the credits, the bank
    lda #1
    jsr sv_at
    lda gs_cred
    jsr sv_bcd
    lda gs_cred+1
    jsr sv_bcd
    lda gs_cred+2
    jsr sv_bcd
    ldx #11
    lda #10
    jsr sv_at
    lda gs_bank
    jsr sv_bcd
    lda gs_bank+1
    jsr sv_bcd
    lda gs_bank+2
    jsr sv_bcd
    ldx #11                 ; the energy, coloured by how much is left
    lda #18
    jsr sv_at
    lda sp_enmax
    lsr
    cmp sp_energy
    lda #P_WHITE
    bcc sv_st_e
    lda sp_enmax
    lsr
    lsr
    cmp sp_energy
    lda #P_GOLD
    bcc sv_st_e
    lda #P_RED
sv_st_e
    jsr sv_pen
    lda sp_energy
    jsr sv_dec3
    lda #("/"-32)*2
    jsr sv_putc
    lda sp_enmax
    jsr sv_dec3
    lda #P_WHITE
    jsr sv_pen
    ldx #11                 ; the holds
    lda #26
    jsr sv_at
    jsr pt_holdused
    jsr sv_dec2
    lda #("/"-32)*2
    jsr sv_putc
    ldx gs_uhold
    lda up_holds,x
    jsr sv_dec2
    ldx #11                 ; the manifest: specimens kept, of 12
    lda #32
    jsr sv_at
    lda #0
    ldx #5
sv_st_k
    clc
    adc gs_keep,x
    dex
    bpl sv_st_k
    jsr sv_dec2
    lda #("/"-32)*2
    jsr sv_putc
    lda #12
    jmp sv_dec2
tx_stlab .byte ("C"-32)*2,("R"-32)*2,("E"-32)*2,("D"-32)*2,("I"-32)*2,("T"-32)*2,("S"-32)*2,0,0,("B"-32)*2,("A"-32)*2,("N"-32)*2,("K"-32)*2,0,0,0,0,("E"-32)*2,("N"-32)*2,("E"-32)*2,("R"-32)*2,("G"-32)*2,("Y"-32)*2,0,0,("H"-32)*2,("O"-32)*2,("L"-32)*2,("D"-32)*2,("S"-32)*2,0,("M"-32)*2,("A"-32)*2,("N"-32)*2,("I"-32)*2,("F"-32)*2,("E"-32)*2,("S"-32)*2,("T"-32)*2   ; 'CREDITS  BANK    ENERGY  HOLDS MANIFEST' (39)


; ===========================================================================
; Achievements (16: gs_ach, a bit each; DESIGN.md 6.5b). Most are worked out
; from the voyage's state (ac_check, when the map's shown); the rest are
; set where they happen (ac_set: deep space, the planet, the port).
; ===========================================================================
AC_PAIRS  = 0       ; a pair of every kind kept
AC_SURVEY = 1       ; one of every kind kept by stardate AC_DATE
AC_ACE    = 2       ; AC_KILLS pirates destroyed
AC_CHART  = 3       ; every sector visited
AC_RICH   = 4       ; 10,000 credits aboard
AC_REFIT  = 5       ; every upgrade
AC_RELIC  = 6       ; the relic delivered
AC_CLEAN  = 7       ; an encounter without a scratch on the Ark
AC_SWEEP  = 8       ; every creature on a planet, the shuttle never lost
AC_STORMS = 9       ; AC_ROCKS storm rocks shot down
AC_FAR    = 10      ; the far sector (64) reached
AC_RAID   = 11      ; a wave-10 encounter survived
AC_TRADE  = 12      ; AC_SOLD goods sold at ports
AC_BANKER = 13      ; 5,000 in the bank
AC_LOADED = 14      ; 20 holds full
AC_POD    = 15      ; home in the escape pod
AC_DATE   = 150
AC_KILLS  = 50
AC_ROCKS  = 5
AC_SOLD   = 50

gs_achn   = $25FE   ; [2] achievements announced (on the map)
ac_hit    = $23FE   ; this encounter or planet: the Ark (or shuttle) hit
gs_achi   = $2584   ; the one being announced
ac_t      = $2571

; achievement A earned
ac_set
    tax
    lda ac_bit,x
    cpx #8
    bcs ac_s_hi
    ora gs_ach
    sta gs_ach
    rts
ac_s_hi
    ora gs_ach+1
    sta gs_ach+1
    rts
ac_bit    .byte 1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128

; the ones the voyage's state shows
ac_check
    ldx #5                  ; the fewest of a kind kept
    lda #2
    sta ac_t
ac_c_k
    lda gs_keep,x
    cmp ac_t
    bcs ac_c_k2
    sta ac_t
ac_c_k2
    dex
    bpl ac_c_k
    lda ac_t
    cmp #2
    bcc ac_c_1
    lda #AC_PAIRS
    jsr ac_set
ac_c_1
    lda ac_t
    beq ac_c_2
    lda gs_date+1
    bne ac_c_2
    lda gs_date
    cmp #AC_DATE
    bcs ac_c_2
    lda #AC_SURVEY
    jsr ac_set
ac_c_2
    lda gs_kills+1
    bne ac_c_2y
    lda gs_kills
    cmp #AC_KILLS
    bcc ac_c_3
ac_c_2y
    lda #AC_ACE
    jsr ac_set
ac_c_3
    ldx #63
ac_c_3l
    lda gx_flag,x
    lsr
    bcc ac_c_4
    dex
    bpl ac_c_3l
    lda #AC_CHART
    jsr ac_set
ac_c_4
    lda gs_cred
    beq ac_c_5
    lda #AC_RICH
    jsr ac_set
ac_c_5
    lda gs_ulas             ; (the hull to the top, the holds too)
    cmp #EN_UPS
    bcc ac_c_6
    lda gs_uhold
    cmp #2
    bcc ac_c_6
    lda #AC_REFIT
    jsr ac_set
ac_c_6
    lda gs_relst
    cmp #2
    bne ac_c_9
    lda #AC_RELIC
    jsr ac_set
ac_c_9
    lda gs_storms
    cmp #AC_ROCKS
    bcc ac_c_10
    lda #AC_STORMS
    jsr ac_set
ac_c_10
    lda gx_flag+63
    lsr
    bcc ac_c_12
    lda #AC_FAR
    jsr ac_set
ac_c_12
    lda gs_sold
    cmp #AC_SOLD
    bcc ac_c_13
    lda #AC_TRADE
    jsr ac_set
ac_c_13
    lda gs_bank
    bne ac_c_13y
    lda gs_bank+1
    cmp #$50
    bcc ac_c_14
ac_c_13y
    lda #AC_BANKER
    jsr ac_set
ac_c_14
    jsr pt_holdused
    cmp #20
    bcc ac_c_r
    lda #AC_LOADED
    jsr ac_set
ac_c_r
    rts

; check, and one not yet announced: C = 1, gs_achi (and now announced)
ac_new
    jsr ac_check
    ldx #0
ac_n_l
    txa
    pha
    lda ac_bit,x
    cpx #8
    bcs ac_n_hi
    and gs_ach
    beq ac_n_n
    and gs_achn
    bne ac_n_n
    lda ac_bit,x
    ora gs_achn
    sta gs_achn
    bcc ac_n_y
ac_n_hi
    and gs_ach+1
    beq ac_n_n
    and gs_achn+1
    bne ac_n_n
    lda ac_bit,x
    ora gs_achn+1
    sta gs_achn+1
ac_n_y
    pla
    sta gs_achi
    sec
    rts
ac_n_n
    pla
    tax
    inx
    cpx #16
    bne ac_n_l
    clc
    rts

; their names (9 characters each)
ac_names
    .byte ("P"-32)*2,("A"-32)*2,("I"-32)*2,("R"-32)*2,("S"-32)*2,0,0,0,0   ; 'PAIRS    ' (9)
    .byte ("S"-32)*2,("U"-32)*2,("R"-32)*2,("V"-32)*2,("E"-32)*2,("Y"-32)*2,0,0,0   ; 'SURVEY   ' (9)
    .byte ("A"-32)*2,("C"-32)*2,("E"-32)*2,0,0,0,0,0,0   ; 'ACE      ' (9)
    .byte ("C"-32)*2,("H"-32)*2,("A"-32)*2,("R"-32)*2,("T"-32)*2,("E"-32)*2,("D"-32)*2,0,0   ; 'CHARTED  ' (9)
    .byte ("T"-32)*2,("Y"-32)*2,("C"-32)*2,("O"-32)*2,("O"-32)*2,("N"-32)*2,0,0,0   ; 'TYCOON   ' (9)
    .byte ("R"-32)*2,("E"-32)*2,("F"-32)*2,("I"-32)*2,("T"-32)*2,0,0,0,0   ; 'REFIT    ' (9)
    .byte ("R"-32)*2,("E"-32)*2,("L"-32)*2,("I"-32)*2,("C"-32)*2,0,0,0,0   ; 'RELIC    ' (9)
    .byte ("U"-32)*2,("N"-32)*2,("T"-32)*2,("O"-32)*2,("U"-32)*2,("C"-32)*2,("H"-32)*2,("E"-32)*2,("D"-32)*2   ; 'UNTOUCHED' (9)
    .byte ("S"-32)*2,("W"-32)*2,("E"-32)*2,("E"-32)*2,("P"-32)*2,0,0,0,0   ; 'SWEEP    ' (9)
    .byte ("S"-32)*2,("T"-32)*2,("O"-32)*2,("R"-32)*2,("M"-32)*2,("S"-32)*2,0,0,0   ; 'STORMS   ' (9)
    .byte ("F"-32)*2,("A"-32)*2,("R"-32)*2,0,("S"-32)*2,("H"-32)*2,("O"-32)*2,("R"-32)*2,("E"-32)*2   ; 'FAR SHORE' (9)
    .byte ("D"-32)*2,("E"-32)*2,("E"-32)*2,("P"-32)*2,0,("R"-32)*2,("A"-32)*2,("I"-32)*2,("D"-32)*2   ; 'DEEP RAID' (9)
    .byte ("M"-32)*2,("E"-32)*2,("R"-32)*2,("C"-32)*2,("H"-32)*2,("A"-32)*2,("N"-32)*2,("T"-32)*2,0   ; 'MERCHANT ' (9)
    .byte ("B"-32)*2,("A"-32)*2,("N"-32)*2,("K"-32)*2,("E"-32)*2,("R"-32)*2,0,0,0   ; 'BANKER   ' (9)
    .byte ("L"-32)*2,("O"-32)*2,("A"-32)*2,("D"-32)*2,("E"-32)*2,("D"-32)*2,0,0,0   ; 'LOADED   ' (9)
    .byte ("L"-32)*2,("I"-32)*2,("F"-32)*2,("E"-32)*2,("B"-32)*2,("O"-32)*2,("A"-32)*2,("T"-32)*2,0   ; 'LIFEBOAT ' (9)
