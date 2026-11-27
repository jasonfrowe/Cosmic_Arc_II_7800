; ===========================================================================
; Saved voyages (bank 1): three slots on the SaveKey (savekey.asm), each a
; whole voyage with its own achievements. Saved on docking at a port, on
; leaving one, when a voyage starts and when the Ark's lost (DESIGN.md 7.5);
; loaded by the title's voyage screen (achieve.asm vs_*).
;
; A slot is SL_STEP bytes of the SaveKey from SL_BASE + slot x SL_STEP. The
; voyage is copied straight between RAM and the SaveKey in chunks (sl_r*,
; sl_len, sl_o*), none crossing one of the SaveKey's 64-byte pages:
;
;   $000  the header: "CA", SL_VER, the checksum (lo, hi)        5
;   $005  $2590-$259A: sector, the slot, stardate, credits, seed 11
;   $010  $2585-$258A: aboard, upgrades, goods sold              6
;   $016  $256B-$2570: creatures in stasis                       6
;   $01C  the Ark's energy, the score                            4
;   $020  $25E0-$25FF: the long-lived block's end                32
;   $040  $25A0-$25DF: ... and its start                         64
;   $080  $2600-$26FF: the galaxy (warps, cells, info, flags)    256
;
; 384 bytes. The hull's most energy (sp_enmax) comes from the upgrades
; (en_setmax); the warps are saved as they are, not rebuilt from the seed.
; The header is written last, so a save cut short reads as damaged. The
; checksum (Fletcher-style, two sums) covers every chunk but the header.
; ===========================================================================

SL_BASE   = $7400   ; the slots: $7400, $7600, $7800 (the hardware check's
SL_STEP   = $0200   ;   byte is $7FC0). To reserve in AtariAge's SaveKey list
SL_VER    = 1       ; the layout's version: another reads as damaged
SL_N      = 12      ; chunks, the header first

gs_slot   = $2591   ; the voyage's slot + 1 (0: not saved: no SaveKey)
sl_hdr    = $23D0   ; [5] the header (deep space's message: unused here)
sl_ck     = sl_hdr+3
sl_i      = $23D5   ; the chunk
sl_s      = $23D6   ; the slot (0-2)
sl_c0     = $23D7   ; the header's checksum, kept while the chunks' is summed
sl_c1     = $23D8

; chunk X of slot sl_s: the SaveKey's address, the RAM, the length
sl_addr
    lda sl_olo,x
    sta sk_addr+1
    lda sl_s
    asl                     ; (SL_STEP: 2 pages a slot)
    clc
    adc sl_ohi,x
    adc #>SL_BASE
    sta sk_addr
    lda sl_rlo,x
    sta sk_buf
    lda sl_rhi,x
    sta sk_buf+1
    lda sl_len,x
    sta sk_len
    rts

; the chunks' checksum (all but the header) into sl_ck
sl_sum
    lda #0
    sta sl_ck
    sta sl_ck+1
    ldx #1
sl_sm_c
    lda sl_rlo,x
    sta sk_buf
    lda sl_rhi,x
    sta sk_buf+1
    ldy sl_len,x
    dey
sl_sm_b
    lda (sk_buf),y
    clc
    adc sl_ck
    sta sl_ck
    clc
    adc sl_ck+1
    sta sl_ck+1
    dey
    bpl sl_sm_b             ; (chunks are 64 bytes at most)
    inx
    cpx #SL_N
    bne sl_sm_c
    rts

; save the voyage into its slot (gs_slot). A: 0 not saved (no slot, or a
; test), 1 saved, 2 the SaveKey didn't answer
sl_save
    lda gs_test
    bne sl_sv_no
    ldx gs_slot
    beq sl_sv_no
    cpx #4
    bcs sl_sv_no
    dex
    stx sl_s
    jsr sl_sum
    lda #"C"
    sta sl_hdr
    lda #"A"
    sta sl_hdr+1
    lda #SL_VER
    sta sl_hdr+2
    ldx #SL_N-1             ; (the header last)
sl_sv_l
    stx sl_i
    jsr sl_addr
    jsr sk_write
    bcs sl_sv_f
    ldx sl_i
    dex
    bpl sl_sv_l
    lda #1
    rts
sl_sv_f
    lda #2
    rts
sl_sv_no
    lda #0
    rts

; read slot A into the voyage's RAM. A: 0 empty, 1 a voyage, 2 damaged
; (a wrong checksum or version), 3 no SaveKey
sl_load
    sta sl_s
    ldx #0
    jsr sl_addr
    jsr sk_read
    bcs sl_ld_none
    lda sl_hdr
    cmp #"C"
    bne sl_ld_empty
    lda sl_hdr+1
    cmp #"A"
    bne sl_ld_empty
    lda sl_hdr+2
    cmp #SL_VER
    bne sl_ld_bad
    lda sl_ck
    sta sl_c0
    lda sl_ck+1
    sta sl_c1
    ldx #1
sl_ld_l
    stx sl_i
    jsr sl_addr
    jsr sk_read
    bcs sl_ld_none
    ldx sl_i
    inx
    cpx #SL_N
    bne sl_ld_l
    jsr sl_sum
    lda sl_ck
    cmp sl_c0
    bne sl_ld_bad
    lda sl_ck+1
    cmp sl_c1
    bne sl_ld_bad
    lda #1
    rts
sl_ld_empty
    lda #0
    rts
sl_ld_bad
    lda #2
    rts
sl_ld_none
    lda #3
    rts

; clear slot A (its header). C = 1: the SaveKey didn't answer
sl_clear
    sta sl_s
    lda #0
    ldx #4
sl_cl_l
    sta sl_hdr,x
    dex
    bpl sl_cl_l
    ldx #0
    jsr sl_addr
    jmp sk_write

; Continue: the voyage in slot gs_slot - 1 back (after sp_new: deep space's
; reset), ready for the map (sv_enter arrives at gs_dest)
sl_resume
    ldx gs_slot
    dex
    txa
    jsr sl_load
    lda sl_s
    clc
    adc #1
    sta gs_slot
    lda gs_sec
    sta gs_dest
    lda #0
    sta gs_msg
    jmp en_setmax

; the chunks: RAM, length, place in the slot
sl_rlo    .byte <sl_hdr, <$2590, <$2585, <$256B, <sp_energy, <sp_score, <$25E0, <$25A0, <$2600, <$2640, <$2680, <$26C0
sl_rhi    .byte >sl_hdr, >$2590, >$2585, >$256B, >sp_energy, >sp_score, >$25E0, >$25A0, >$2600, >$2640, >$2680, >$26C0
sl_len    .byte 5, 11, 6, 6, 1, 3, 32, 64, 64, 64, 64, 64
sl_olo    .byte <$000, <$005, <$010, <$016, <$01C, <$01D, <$020, <$040, <$080, <$0C0, <$100, <$140
sl_ohi    .byte >$000, >$005, >$010, >$016, >$01C, >$01D, >$020, >$040, >$080, >$0C0, >$100, >$140
