; Rudimentary input and output BIOS routines for msbasic
; Build with "ca65 <filename>" to create obj file
; Link with "ld65 -C bios.cfg -Ln bios.sym <objfile>"

; Start BASIC using the address of COLD_START label (see output lbl file when building BASIC)
;   For example, if COLD_START is $9F06,  "9F06" <newline> followed by "R".

.setcpu "65C02"
.debuginfo           ; Generate symbol table
.segment "BIOS"

UART_DATA   = $5000
UART_STATUS = $5001
UART_CMD    = $5002
UART_CTRL   = $5003

LOAD:
    rts

SAVE:
    rts

ISCNTC:
    rts

MONRDKEY:
CHRIN:
    lda UART_STATUS  ; Check if UART receive buffer is full. If it is, set the carry flag and keep char in A.
    and #$08
    beq @no_keypressed
    lda UART_DATA
    jsr CHROUT
    sec
    rts
@no_keypressed:
    clc
    rts

MONCOUT:
CHROUT:
    pha             ; Write data to UART
    sta UART_DATA
    lda #$ff
@txdelay:
    dec
    bne @txdelay
    pla
    rts

.include "beneater-wozmon.s"

.segment "RESETVECTORS"
    .word $0f00       ; NMI
    .word RESETWOZ    ; RESET
    .word $0000       ; BRK/IRQ
