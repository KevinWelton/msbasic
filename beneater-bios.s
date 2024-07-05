; Rudimentary input and output BIOS routines for msbasic
; Build with "ca65 <filename>" to create obj file
; Link with "ld65 -C bios.cfg -Ln bios.sym <objfile>"

; Start BASIC using the address of COLD_START label (see output lbl file when building BASIC)
;   Right now that is at $9F06. So in Wozmon, enter "9F06" then enter "R"

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

COLDBOOT:
    lda #$1f          ; UART control register: 8 bit word, 1 stop bit, 19200 baud
    sta UART_CTRL
    lda #$8b          ; UART command register: No parity, echo on, no interrupts
    sta UART_CMD
    ldx #0
@premsg:
    lda BASICMSGSTART, x
    beq @premsgdone
    jsr CHROUT
    inx
    jmp @premsg
@premsgdone:
    lda #>COLD_START
    jsr PRBYTE
    lda #<COLD_START
    jsr PRBYTE
    ldx #0
@postmsg:
    lda BASICMSGEND, x
    beq @postmsgdone
    jsr CHROUT
    inx
    jmp @postmsg
@postmsgdone:
    lda #$0d          ; Print CRLF
    jsr CHROUT
    lda #$0a
    jsr CHROUT
    jmp RESETWOZ      ; Start Wozmon

BASICMSGSTART:
    .asciiz "Start MS Basic with "

BASICMSGEND:
    .asciiz "R"

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
    .word COLDBOOT    ; RESET
    .word $0000       ; BRK/IRQ
