; ===========================================================================
; The 40-column screens' text (bank 1: the map, the port, the achievements):
; 12 rows of 40 in RAM ($2200 rows 0-5, $2700 rows 6-11), drawn as two
; 20-character 320A objects a row; helpers that write into them (sv_dst).
; ===========================================================================

; the rows: two 20-character objects each (palette 2 the top and bottom)
sv_rows
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
    rts

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
AC_FUMES  = 12      ; docked at a port on an empty tank
AC_BANKER = 13      ; 5,000 in the bank
AC_LOADED = 14      ; 20 holds full
AC_POD    = 15      ; home in the escape pod
AC_DATE   = 150
AC_KILLS  = 50
AC_ROCKS  = 5

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
    lda gs_ulas             ; (the hull to the top, holds and tanks too)
    cmp #EN_UPS
    bcc ac_c_6
    lda gs_uhold
    and gs_utank
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
    bcc ac_c_13
    lda #AC_FAR
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
    .byte ("O"-32)*2,("N"-32)*2,0,("F"-32)*2,("U"-32)*2,("M"-32)*2,("E"-32)*2,("S"-32)*2,0   ; 'ON FUMES ' (9)
    .byte ("B"-32)*2,("A"-32)*2,("N"-32)*2,("K"-32)*2,("E"-32)*2,("R"-32)*2,0,0,0   ; 'BANKER   ' (9)
    .byte ("L"-32)*2,("O"-32)*2,("A"-32)*2,("D"-32)*2,("E"-32)*2,("D"-32)*2,0,0,0   ; 'LOADED   ' (9)
    .byte ("L"-32)*2,("I"-32)*2,("F"-32)*2,("E"-32)*2,("B"-32)*2,("O"-32)*2,("A"-32)*2,("T"-32)*2,0   ; 'LIFEBOAT ' (9)
