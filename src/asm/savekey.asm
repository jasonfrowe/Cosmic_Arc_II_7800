; ===========================================================================
; SaveKey / AtariVox EEPROM (24LC256, 32K) on controller port 2.
;
; No SUBROUTINE scopes in this project: 7800basic's own labels start with a
; dot (dasm local labels), and a new scope hides them from its runtime.
;
; The bit-level I2C is 7800basic's i2c7800.inc (Alex Herbert's AtariVox
; driver, 7800 port by Mike Saarna), instantiated here with our own zero
; page scratch byte. If the game later turns on 7800basic's hssupport,
; which instantiates the same subroutines, drop the I2C_SUBS line below.
;
;   sk_read   read sk_len bytes at sk_addr into (sk_buf); C = 1: no SaveKey
;   sk_write  write sk_len bytes (<= 64, inside one 64-byte page) from
;             (sk_buf) to sk_addr, then wait for the write cycle; C = 1: none
;
; The game's save slot address is still to be reserved in AtariAge's
; SaveKey address list (docs/DESIGN.md 7.3).
; ===========================================================================

sk_scr   = $B6      ; I2C scratch (zero page, 7800basic's unused tracker block)
sk_buf   = $B7      ; 2: buffer pointer
sk_addr  = $2580    ; 2: EEPROM address (hi, lo)
sk_len   = $2582
sk_tries = $2583

    include "i2c7800.inc"
    I2C_SUBS sk_scr

; Set the EEPROM's address pointer (a write with no data). C = 1: no ACK.
sk_setaddr
    jsr i2c_startwrite
    bcs sk_setaddr_none
    lda sk_addr
    jsr i2c_txbyte
    lda sk_addr+1
    jsr i2c_txbyte
    clc
sk_setaddr_none
    rts

sk_read
    jsr sk_setaddr
    bcs sk_read_none
    jsr i2c_stopwrite
    jsr i2c_startread
    bcs sk_read_none
    ldy #0
sk_read_loop
    sty sk_tries            ; (the i2c routines use Y)
    jsr i2c_rxbyte
    ldy sk_tries
    sta (sk_buf),y
    iny
    cpy sk_len
    bne sk_read_loop
    jsr i2c_stopread
    clc
    rts
sk_read_none
    jsr i2c_stopwrite
    sec
    rts

sk_write
    jsr sk_setaddr
    bcs sk_write_none
    ldy #0
sk_write_loop
    sty sk_tries
    lda (sk_buf),y
    jsr i2c_txbyte
    ldy sk_tries
    iny
    cpy sk_len
    bne sk_write_loop
    jsr i2c_stopwrite
    ; the write cycle (up to 5 ms): the chip NACKs until it is done
    lda #0
    sta sk_tries
sk_write_poll
    jsr i2c_startwrite
    php
    jsr i2c_stopwrite
    plp
    bcc sk_write_done
    dec sk_tries
    bne sk_write_poll
    sec
    rts
sk_write_done
    clc
    rts
sk_write_none
    jsr i2c_stopwrite
    sec
    rts
