; ===========================================================================
; ROM banks. 272K SuperGame: bank 1 fixed at $4000, banks 2-16 switched in at
; $8000 (write the bank - 2 to $8000), bank 17 fixed at $C000.
;
; What has to stay in a fixed bank: anything the NMI runs (the music player
; and its data, the sound effects), anything called while another bank is
; in, and graphics (bank 17: MARIA reads them at any time).
;
;   bank_in   A = bank (2-16): switch it in at $8000, and remember it
; ===========================================================================

BANK_SPACE = 2      ; deep space: space, fighter, pirates, vec, draw

cur_bank  = $23EE   ; the bank in at $8000

bank_in
    sta cur_bank
    sec
    sbc #2
    sta $8000
    rts
