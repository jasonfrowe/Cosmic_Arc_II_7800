; ===========================================================================
; Sound: music on two POKEYs, effects on the TIA.
;
;   voice 0  lead      POKEY 1 ($0450) channels 1+2 joined, 16 bits, 1.79 MHz
;   voice 1  bass      POKEY 1 channels 3+4 joined, 16 bits, 1.79 MHz
;   voice 2  harmony   POKEY 2 ($0440) channels 1+2 joined (arpeggios)
;   voice 3  drums     POKEY 2 channel 3 (15 kHz clock: kick, snare, hats)
;   effects            TIA channels 0 and 1
;
; Music data (gen/music.asm, from tools/music.py), per voice a stream:
;   $00-$7F n d   note n (plus the voice's transpose) for d sixteenths
;   $80 d         rest
;   $81 i         instrument i (envelope, arpeggio)
;   $82 lo hi     jump      $83 lo hi   call (one level)   $84 return
;   $85 t         transpose $86         end of the voice
; A song: speed (frames a sixteenth), voice mask, four stream addresses.
; Runs in the NMI (snd_tick, from 7800basic's userinterrupt), in vblank.
;
; From Super Mega Pinball 7800 (src/sound.asm). Zero page $B0-$B5 is in
; 7800basic's tracker block, unused here (the game has its own player).
; ===========================================================================

PKA     = $0450     ; POKEY 1
PKB     = $0440     ; POKEY 2 (cart type bit 10: tools/a78header.py)

PKA_AUDF1 = PKA+0
PKA_AUDC1 = PKA+1
PKA_AUDF2 = PKA+2
PKA_AUDC2 = PKA+3
PKA_AUDF3 = PKA+4
PKA_AUDC3 = PKA+5
PKA_AUDF4 = PKA+6
PKA_AUDC4 = PKA+7
PKA_AUDCTL = PKA+8
PKA_SKCTL = PKA+15
PKB_AUDF1 = PKB+0
PKB_AUDC1 = PKB+1
PKB_AUDF2 = PKB+2
PKB_AUDC2 = PKB+3
PKB_AUDF3 = PKB+4
PKB_AUDC3 = PKB+5
PKB_AUDF4 = PKB+6
PKB_AUDC4 = PKB+7
PKB_AUDCTL = PKB+8
PKB_SKCTL = PKB+15

musp    = $B0   ; 2
musq    = $B2   ; 2
mtmp    = $B4
mtmp2   = $B5

mus_on    = $2500
mus_speed = $2501
mus_mask  = $2502
m_ptrlo   = $2504 ; [4]
m_ptrhi   = $2508
m_wait    = $250C
m_note    = $2510
m_trans   = $2514
m_envlo   = $2518
m_envhi   = $251C
m_arplo   = $2520
m_arphi   = $2524
m_arpblo  = $2528
m_arpbhi  = $252C
m_retlo   = $2530
m_rethi   = $2534
m_ins     = $2538
m_vol     = $253C
m_off     = $2540 ; arpeggio offset this frame
m_done    = $2544
m_guard   = $2548
sfx_id    = $2550 ; [2] per TIA channel
sfx_lo    = $2552
sfx_hi    = $2554

snd_init
    lda #0
    sta mus_on
    sta sfx_id
    sta sfx_id+1
    sta AUDV0
    sta AUDV1
mus_silence
    lda #0
    sta PKA_SKCTL
    sta PKB_SKCTL
    ldx #7
mus_silence_s
    sta PKA,x
    sta PKB,x
    dex
    bpl mus_silence_s
    lda #3
    sta PKA_SKCTL
    sta PKB_SKCTL
    lda #$78                ; 1+2 and 3+4 joined, both at 1.79 MHz
    sta PKA_AUDCTL
    lda #$51                ; 1+2 joined at 1.79 MHz, 3/4 on 15 kHz
    sta PKB_AUDCTL
    rts

; mus_play: song A
mus_play
    tax
    lda #0
    sta mus_on              ; keep the NMI out
    lda song_lo,x
    sta musp
    lda song_hi,x
    sta musp+1
    ldy #0
    lda (musp),y
    sta mus_speed
    iny
    lda (musp),y
    sta mus_mask
    ldx #0
mus_play_v
    iny
    lda (musp),y
    sta m_ptrlo,x
    iny
    lda (musp),y
    sta m_ptrhi,x
    lda #0
    sta m_wait,x
    sta m_trans,x
    sta m_vol,x
    sta m_done,x
    sta m_arphi,x
    lda #<env_off
    sta m_envlo,x
    lda #>env_off
    sta m_envhi,x
    inx
    cpx #4
    bne mus_play_v
    jsr mus_silence
    lda #1
    sta mus_on
    rts

env_off .byte 0, $FF

; ---------------------------------------------------------------------------
snd_tick
    jsr sfx_tick
    lda mus_on
    bne snd_tick_go
    rts
snd_tick_go
    ldx #3
snd_tick_voice
    lda m_done,x
    beq *+5
    jmp snd_tick_next
    lda m_wait,x
    beq snd_tick_read
    dec m_wait,x
    beq *+5
    jmp snd_tick_next
snd_tick_read
    lda #16
    sta m_guard
    lda m_ptrlo,x
    sta musp
    lda m_ptrhi,x
    sta musp+1
snd_tick_cmd
    dec m_guard
    bne *+5
    jmp snd_tick_store
    ldy #0
    lda (musp),y
    bmi snd_tick_ctl
    ; a note
    clc
    adc m_trans,x
    sta m_note,x
    iny
    lda (musp),y
    jsr snd_tick_setwait
    jsr snd_tick_newnote
    lda #2
    jmp snd_tick_adv_store
snd_tick_ctl
    cmp #$80
    bne snd_tick_c1
    ; rest
    iny
    lda (musp),y
    jsr snd_tick_setwait
    lda #<env_off
    sta m_envlo,x
    lda #>env_off
    sta m_envhi,x
    lda #2
    jmp snd_tick_adv_store
snd_tick_c1
    cmp #$81
    bne snd_tick_c2
    iny
    lda (musp),y
    sta m_ins,x
    lda #2
    jsr snd_tick_adv
    jmp snd_tick_cmd
snd_tick_c2
    cmp #$82
    bne snd_tick_c3
    iny
    lda (musp),y
    pha
    iny
    lda (musp),y
    sta musp+1
    pla
    sta musp
    jmp snd_tick_cmd
snd_tick_c3
    cmp #$83
    bne snd_tick_c4
    clc
    lda musp
    adc #3
    sta m_retlo,x
    lda musp+1
    adc #0
    sta m_rethi,x
    iny
    lda (musp),y
    pha
    iny
    lda (musp),y
    sta musp+1
    pla
    sta musp
    jmp snd_tick_cmd
snd_tick_c4
    cmp #$84
    bne snd_tick_c5
    lda m_retlo,x
    sta musp
    lda m_rethi,x
    sta musp+1
    jmp snd_tick_cmd
snd_tick_c5
    cmp #$85
    bne snd_tick_c6
    iny
    lda (musp),y
    sta m_trans,x
    lda #2
    jsr snd_tick_adv
    jmp snd_tick_cmd
snd_tick_c6
    ; end
    lda #1
    sta m_done,x
    lda #<env_off
    sta m_envlo,x
    lda #>env_off
    sta m_envhi,x
    jmp snd_tick_next
snd_tick_adv_store
    jsr snd_tick_adv
snd_tick_store
    lda musp
    sta m_ptrlo,x
    lda musp+1
    sta m_ptrhi,x
snd_tick_next
    dex
    bmi snd_tick_out
    jmp snd_tick_voice
snd_tick_out
    jmp mus_output

snd_tick_adv
    clc
    adc musp
    sta musp
    bcc snd_tick_a1
    inc musp+1
snd_tick_a1
    rts

; wait = d * speed frames
snd_tick_setwait
    sta mtmp
    lda #0
    ldy mus_speed
snd_tick_sw
    clc
    adc mtmp
    dey
    bne snd_tick_sw
    sta m_wait,x
    ldy #1
    rts

; start the instrument's envelope and arpeggio
snd_tick_newnote
    cpx #3
    beq snd_tick_drum
    ldy m_ins,x
    lda ins_env_lo,y
    sta m_envlo,x
    lda ins_env_hi,y
    sta m_envhi,x
    lda ins_arp_lo,y
    sta m_arplo,x
    sta m_arpblo,x
    lda ins_arp_hi,y
    sta m_arphi,x
    sta m_arpbhi,x
    ldy #1
    rts
snd_tick_drum
    ldy m_note,x
    lda drum_lo,y
    sta m_envlo,x
    lda drum_hi,y
    sta m_envhi,x
    ldy #1
    rts

; ---------------------------------------------------------------------------
mus_output
    ldx #2
mus_output_v
    ; volume: the envelope's next value (held at $FF)
    lda m_envlo,x
    sta musq
    lda m_envhi,x
    sta musq+1
    ldy #0
    lda (musq),y
    sta m_vol,x
    iny
    lda (musq),y
    cmp #$FF
    beq mus_output_hold
    inc m_envlo,x
    bne mus_output_hold
    inc m_envhi,x
mus_output_hold
    ; arpeggio offset
    lda #0
    sta m_off,x
    lda m_arphi,x
    beq mus_output_noarp
    sta musq+1
    lda m_arplo,x
    sta musq
    ldy #0
    lda (musq),y
    cmp #$FF
    bne mus_output_ao
    lda m_arpblo,x
    sta m_arplo,x
    sta musq
    lda m_arpbhi,x
    sta m_arphi,x
    sta musq+1
    lda (musq),y
mus_output_ao
    sta m_off,x
    inc m_arplo,x
    bne mus_output_noarp
    inc m_arphi,x
mus_output_noarp
    lda mus_mask
    and voicebit,x
    bne mus_output_on
    lda #0
    sta m_vol,x
mus_output_on
    dex
    bpl mus_output_v

    ; voice 0 -> POKEY 1 ch 1+2
    lda m_note
    clc
    adc m_off
    tay
    lda f16lo,y
    sta PKA_AUDF1
    lda f16hi,y
    sta PKA_AUDF2
    lda #0
    sta PKA_AUDC1
    lda m_vol
    ora #$A0
    sta PKA_AUDC2
    ; voice 1 -> POKEY 1 ch 3+4
    lda m_note+1
    clc
    adc m_off+1
    tay
    lda f16lo,y
    sta PKA_AUDF3
    lda f16hi,y
    sta PKA_AUDF4
    lda #0
    sta PKA_AUDC3
    lda m_vol+1
    ora #$A0
    sta PKA_AUDC4
    ; voice 2 -> POKEY 2 ch 1+2
    lda m_note+2
    clc
    adc m_off+2
    tay
    lda f16lo,y
    sta PKB_AUDF1
    lda f16hi,y
    sta PKB_AUDF2
    lda #0
    sta PKB_AUDC1
    lda m_vol+2
    ora #$A0
    sta PKB_AUDC2
    ; voice 3: drum macro, AUDC/AUDF pairs, AUDC 0 = over
    lda mus_mask
    and #8
    beq mus_output_dq
    lda m_envlo+3
    sta musq
    lda m_envhi+3
    sta musq+1
    ldy #0
    lda (musq),y
    sta PKB_AUDC3
    beq mus_output_dd
    iny
    lda (musq),y
    sta PKB_AUDF3
    clc
    lda musq
    adc #2
    sta m_envlo+3
    lda musq+1
    adc #0
    sta m_envhi+3
mus_output_dd
    rts
mus_output_dq
    lda #0
    sta PKB_AUDC3
    rts

voicebit .byte 1,2,4,8

; ---------------------------------------------------------------------------
; Effects on the TIA: sfx A. Each effect: AUDC, AUDF, AUDV a frame, AUDC $FF ends.
; Channel and priority from sfx_chan / sfx_pri.
sfx
    tay
    ldx sfx_chan,y
    lda sfx_id,x
    beq sfx_take
    tax
    lda sfx_pri,x
    ldx sfx_chan,y
    cmp sfx_pri,y
    beq sfx_take
    bcs sfx_r
sfx_take
    lda #0
    sta sfx_id,x            ; (the NMI leaves the channel alone meanwhile)
    lda sfx_dlo,y
    sta sfx_lo,x
    lda sfx_dhi,y
    sta sfx_hi,x
    tya
    sta sfx_id,x
sfx_r
    rts

sfx_tick
    ldx #1
sfx_tick_c
    lda sfx_id,x
    beq sfx_tick_off
    lda sfx_lo,x
    sta musq
    lda sfx_hi,x
    sta musq+1
    ldy #0
    lda (musq),y
    cmp #$FF
    beq sfx_tick_end
    sta AUDC0,x
    iny
    lda (musq),y
    sta AUDF0,x
    iny
    lda (musq),y
    sta AUDV0,x
    clc
    lda sfx_lo,x
    adc #3
    sta sfx_lo,x
    bcc sfx_tick_n
    inc sfx_hi,x
    jmp sfx_tick_n
sfx_tick_end
    lda #0
    sta sfx_id,x
sfx_tick_off
    lda #0
    sta AUDV0,x
sfx_tick_n
    dex
    bpl sfx_tick_c
    rts
