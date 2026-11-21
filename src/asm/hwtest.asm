; ===========================================================================
; M0 hardware check: the boot screen's tests.
;
;   hw_init   runs every test once and writes the screen's text lines
;   hw_frame  each frame: the live random byte, the music's POKEY mask
;   hw_mask   A = 0 both POKEYs, 1 POKEY 1 ($0450) only, 2 POKEY 2 ($0440) only
;
; The text is 8 lines of 32 bytes at hw_lines, character codes (text.asm),
; plotted by the BASIC with plotchars, 20 columns a line: a label at
; column 0, a status at column 12.
; ===========================================================================

hwp       = $B9     ; 2: source string
hwd       = $BB     ; 2: destination in hw_lines

hw_lines  = $2600   ; 8 x 32
HW_COLS   = 20
HW_STAT   = 12

hw_math   = $2590   ; 1: the unit answers
hw_trig   = $2591   ; 1: version 2 (trig block)
hw_arith  = $2592   ; 1: multiply/divide right
hw_angle  = $2593   ; 1: atan2/length right
hw_banks  = $2594   ; banks that failed (0 = all good)
hw_sk     = $2595   ; 0 none, 1 ok, 2 failed
hw_skb    = $2596   ; 2: SaveKey test bytes
hw_maskix = $2598   ; (also a BASIC dim)
hw_t0     = $2599
hw_t1     = $259A

hw_init
    ; blank the lines
    lda #CH_SPACE
    ldx #0
hw_init_clr
    sta hw_lines,x
    inx
    bne hw_init_clr
    ; labels
    ldx #7
hw_init_lbl
    txa
    pha
    lda hw_lbl_lo,x
    sta hwp
    lda hw_lbl_hi,x
    sta hwp+1
    txa
    ldx #0
    jsr hw_text
    pla
    tax
    dex
    bpl hw_init_lbl

    jsr hw_t_math
    jsr hw_t_banks
    jsr hw_t_savekey
    lda #0
    jmp hw_mask

; ---------------------------------------------------------------------------
; hw_text: write the zero-terminated string at (hwp) to line A, column X
hw_text
    asl
    asl
    asl
    asl
    asl
    sta hwd
    txa
    clc
    adc hwd
    sta hwd
    lda #>hw_lines
    sta hwd+1
    ldy #0
hw_text_c
    lda (hwp),y
    beq hw_text_r
    jsr tx_ascii
    sta (hwd),y
    iny
    bne hw_text_c
hw_text_r
    rts

; hw_status: string A (index into hw_st_lo/hi) to line X's status column,
; the rest of the line blanked first
hw_status
    tay
    lda hw_st_lo,y
    sta hwp
    lda hw_st_hi,y
    sta hwp+1
    stx hw_t1
    txa
    asl
    asl
    asl
    asl
    asl
    clc
    adc #HW_STAT
    tax
    ldy #HW_COLS-HW_STAT
    lda #CH_SPACE
hw_status_pad
    sta hw_lines,x
    inx
    dey
    bne hw_status_pad
    lda hw_t1
    ldx #HW_STAT
    jmp hw_text

; hw_hex: A as two hex digits at hw_lines + X, X+1
hw_hex
    pha
    lsr
    lsr
    lsr
    lsr
    tay
    lda hw_hexd,y
    jsr tx_ascii
    sta hw_lines,x
    pla
    and #$0F
    tay
    lda hw_hexd,y
    jsr tx_ascii
    sta hw_lines+1,x
    rts

; ---------------------------------------------------------------------------
hw_t_math
    lda #0
    sta hw_math
    sta hw_trig
    sta hw_arith
    sta hw_angle
    lda M_ID
    cmp #M_ID_V1
    beq hw_t_math_hasmath
    jmp hw_t_math_nomath
hw_t_math_hasmath
    inc hw_math
    lda M_VER
    cmp #M_VER_V2
    bne hw_t_math_notrig
    inc hw_trig
hw_t_math_notrig
    ; $1234 x $0567 = $006256EC, unsigned
    lda #0
    sta M_CTRL
    lda #$34
    sta M_A
    lda #$12
    sta M_A+1
    lda #$67
    sta M_B
    lda #$05
    sta M_B+1
    lda M_P
    cmp #$EC
    bne hw_t_math_arbad
    lda M_P+1
    cmp #$56
    bne hw_t_math_arbad
    lda M_P+2
    cmp #$62
    bne hw_t_math_arbad
    lda M_P+3
    bne hw_t_math_arbad
    ; 1000000 / 7 = 142857 ($00022E09) remainder 1
    lda #$40
    sta M_N
    lda #$42
    sta M_N+1
    lda #$0F
    sta M_N+2
    lda #$00
    sta M_N+3
    lda #7
    sta M_D
    lda #0
    sta M_D+1
    lda M_Q
    cmp #$09
    bne hw_t_math_arbad
    lda M_Q+1
    cmp #$2E
    bne hw_t_math_arbad
    lda M_Q+2
    cmp #$02
    bne hw_t_math_arbad
    lda M_R
    cmp #1
    bne hw_t_math_arbad
    inc hw_arith
hw_t_math_arbad
    lda hw_trig
    beq hw_t_math_done
    ; (3000, 4000): length 5000 ($1388), angle 9672 ($25C8) of $10000
    lda #<3000
    sta M_X
    lda #>3000
    sta M_X+1
    lda #<4000
    sta M_Y
    lda #>4000
    sta M_Y+1
    sec
    lda M_LEN
    sbc #<(5000-2)
    sta hw_t0
    lda M_LEN+1
    sbc #>(5000-2)
    bne hw_t_math_done
    lda hw_t0
    cmp #5                  ; within 5000 +-2
    bcs hw_t_math_done
    sec
    lda M_ANG
    sbc #<(9672-4)
    sta hw_t0
    lda M_ANG+1
    sbc #>(9672-4)
    bne hw_t_math_done
    lda hw_t0
    cmp #9                  ; within 9672 +-4
    bcs hw_t_math_done
    inc hw_angle
hw_t_math_done
hw_t_math_nomath
    ; statuses
    ldx #0
    lda hw_math
    jsr hw_okmissing
    ldx #1
    lda hw_trig
    jsr hw_okmissing
    ldx #2
    lda hw_arith
    jsr hw_okfail
    ldx #3
    lda hw_angle
    jmp hw_okfail

hw_okmissing
    beq hw_t_math_m
    lda #ST_OK
    jmp hw_status
hw_t_math_m
    lda #ST_MISSING
    jmp hw_status
hw_okfail
    beq hw_t_math_f
    lda #ST_OK
    jmp hw_status
hw_t_math_f
    lda #ST_FAIL
    jmp hw_status

; ---------------------------------------------------------------------------
; banks 2-16: each starts with "CA" and its number (cosmicarc.bas)
hw_t_banks
    lda #0
    sta hw_banks
    ldx #0
hw_t_banks_b
    stx $8000               ; SuperGame: bank X+2 at $8000
    lda $8000
    cmp #'C
    bne hw_t_banks_bad
    lda $8001
    cmp #'A
    bne hw_t_banks_bad
    txa
    clc
    adc #2
    cmp $8002
    beq hw_t_banks_ok
hw_t_banks_bad
    inc hw_banks
hw_t_banks_ok
    inx
    cpx #15
    bne hw_t_banks_b
    lda #0
    sta $8000
    ldx #5
    lda hw_banks
    bne hw_t_banks_f
    lda #ST_OK
    jmp hw_status
hw_t_banks_f
    lda #ST_FAIL
    jsr hw_status
    lda hw_banks
    ldx #5*32+HW_STAT+5
    jmp hw_hex

; ---------------------------------------------------------------------------
; SaveKey: read a byte, write it inverted, read it back, put it back
HW_SKADDR = $7FC0
hw_t_savekey
    lda #0
    sta hw_sk
    lda #>HW_SKADDR
    sta sk_addr
    lda #<HW_SKADDR
    sta sk_addr+1
    lda #1
    sta sk_len
    lda #<hw_skb
    sta sk_buf
    lda #>hw_skb
    sta sk_buf+1
    jsr sk_read
    bcs hw_t_savekey_none
    lda hw_skb
    sta hw_skb+1            ; the original
    eor #$5A
    sta hw_skb
    jsr sk_write
    bcs hw_t_savekey_fail
    lda #0
    sta hw_skb
    jsr sk_read
    bcs hw_t_savekey_fail
    lda hw_skb+1
    eor #$5A
    cmp hw_skb
    bne hw_t_savekey_fail
    lda hw_skb+1
    sta hw_skb
    jsr sk_write
    bcs hw_t_savekey_fail
    inc hw_sk
    ldx #6
    lda #ST_OK
    jmp hw_status
hw_t_savekey_fail
    lda #2
    sta hw_sk
    ldx #6
    lda #ST_FAIL
    jmp hw_status
hw_t_savekey_none
    ldx #6
    lda #ST_NOTFOUND
    jmp hw_status

; ---------------------------------------------------------------------------
hw_frame
    lda hw_math
    beq hw_frame_r
    lda M_RND
    ldx #4*32+HW_STAT+1
    jsr hw_hex
    lda #("$"-32)*2
    sta hw_lines+4*32+HW_STAT
hw_frame_r
    rts

hw_mask
    sta hw_maskix
    tay
    lda hw_masks,y
    sta mus_mask
    lda hw_maskst,y
    ldx #7
    jmp hw_status

hw_masks  .byte $0F, $03, $0C
hw_maskst .byte ST_BOTH, ST_P1, ST_P2

hw_hexd .byte "0123456789ABCDEF"

hw_lt0 .byte "MATH UNIT",0
hw_lt1 .byte "TRIG",0
hw_lt2 .byte "MUL/DIV",0
hw_lt3 .byte "ATAN/LEN",0
hw_lt4 .byte "RANDOM",0
hw_lt5 .byte "BANKS",0
hw_lt6 .byte "SAVEKEY",0
hw_lt7 .byte "MUSIC",0
hw_lbl_lo .byte <hw_lt0,<hw_lt1,<hw_lt2,<hw_lt3,<hw_lt4,<hw_lt5,<hw_lt6,<hw_lt7
hw_lbl_hi .byte >hw_lt0,>hw_lt1,>hw_lt2,>hw_lt3,>hw_lt4,>hw_lt5,>hw_lt6,>hw_lt7

ST_OK       = 0
ST_FAIL     = 1
ST_MISSING  = 2
ST_NOTFOUND = 3
ST_BOTH     = 4
ST_P1       = 5
ST_P2       = 6
hw_s0 .byte "OK",0
hw_s1 .byte "FAIL",0
hw_s2 .byte "MISSING",0
hw_s3 .byte "NONE",0
hw_s4 .byte "BOTH",0
hw_s5 .byte "$0450",0
hw_s6 .byte "$0440",0
hw_st_lo .byte <hw_s0,<hw_s1,<hw_s2,<hw_s3,<hw_s4,<hw_s5,<hw_s6
hw_st_hi .byte >hw_s0,>hw_s1,>hw_s2,>hw_s3,>hw_s4,>hw_s5,>hw_s6
