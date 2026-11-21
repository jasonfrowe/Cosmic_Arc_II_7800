; ===========================================================================
; Vectors on the math unit, in "square" units (x in hi-res pixels, twice
; 160A's, so a speed looks the same in every direction). Angles are one
; byte: $00 east, $40 down, $80 west, $C0 up.
;
;   vec_rot    A = angle, v_t0/v_t1 = length (8.8)
;              -> vx_l/vx_h (160A pixels, 8.8: x halved), vy_l/vy_h (lines)
;   vec_angle  from (v_t0, v_t1) to (v_t2, v_t3), screen x/y
;              -> A = angle; M_LEN = the distance (square units)
;   steer      A = heading, v_t2 = wanted, v_t3 = most it may turn -> A
; ===========================================================================

v_t0      = $24CA
v_t1      = $24CB
v_t2      = $24CC
v_t3      = $24CD
vx_l      = $24C6
vx_h      = $24C7
vy_l      = $24C8
vy_h      = $24C9
vec_tmp   = $24DA

vec_rot
    sta M_T+1
    lda #0
    sta M_T
    sta M_Y
    sta M_Y+1
    lda v_t0
    sta M_X
    lda v_t1
    sta M_X+1
    lda M_XR+1
    cmp #$80
    ror
    sta vx_h
    lda M_XR
    ror
    sta vx_l
    lda M_YR
    sta vy_l
    lda M_YR+1
    sta vy_h
    rts

vec_angle
    sec
    lda v_t2
    sbc v_t0
    sta vx_l
    lda #0
    sbc #0
    sta vx_h
    asl vx_l                ; x in square units
    rol vx_h
    lda vx_l
    sta M_X
    lda vx_h
    sta M_X+1
    sec
    lda v_t3
    sbc v_t1
    sta M_Y
    lda #0
    sbc #0
    sta M_Y+1
    lda M_ANG+1
    rts

steer
    sta vec_tmp
    sec
    lda v_t2
    sbc vec_tmp             ; how far round, signed
    bmi steer_neg
    cmp v_t3
    bcc steer_set
    lda vec_tmp
    clc
    adc v_t3
    rts
steer_neg
    eor #$FF
    clc
    adc #1
    cmp v_t3
    bcc steer_set
    lda vec_tmp
    sec
    sbc v_t3
    rts
steer_set
    lda v_t2
    rts
