; Rudimentary input and output BIOS routines for msbasic
; Build with "ca65 <filename>" to create obj file
; Link with "ld65 -C bios.cfg -Ln bios.sym <objfile>"

; Start BASIC using the address of COLD_START label (see output lbl file when building BASIC)
;   Right now that is at $9F06. So in Wozmon, enter "9F06" then enter "R"

.setcpu "65C02"
.debuginfo           ; Generate symbol table

.zeropage
            .org ZP_START0
READ_PTR:   .res 1
WRITE_PTR:  .res 1

.segment "INPUT_BUFFER"

INPUT_BUFFER: .res $100

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
    lda #$8b          ; UART command register: No parity, echo on, NO interrupts (we will enable before running wozmon)
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
@prepinput:
    jsr INIT_BUFFER   ; Init our ring buffer and clear the interrupt disable processor flag
    cli
    lda #$89          ; UART command register: No parity, echo on, YES interrupts
    sta UART_CMD

    jmp RESETWOZ      ; Start Wozmon

BASICMSGSTART:
    .asciiz "Start MS Basic with "

BASICMSGEND:
    .asciiz "R"

; Modifies: P, A
MONRDKEY:
CHRIN:
    phx
    jsr SIZE_BUFFER    ; Check if we have characters in our ring buffer. If so, read the next one and set the carry bit.
    beq @no_keypressed
    jsr READ_BUFFER
    jsr CHROUT
    sec
    plx
    rts
@no_keypressed:
    plx
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

; Initialize our write and read pointers
; Modifies: P, A
INIT_BUFFER:
    lda READ_PTR    ; Make ring buffer pointers the same
    sta WRITE_PTR
    rts

; Write character in A to WRITE_PTR
; Modifies: P, X
WRITE_BUFFER:
    ldx WRITE_PTR
    sta INPUT_BUFFER, X
    inc WRITE_PTR
    rts

; Read character in READ_PTR to A
; Modifies: P, X, A
READ_BUFFER:
    ldx READ_PTR
    lda INPUT_BUFFER, X
    inc READ_PTR
    rts

; Return bytes in buffer in A
; Modifies: P, A
SIZE_BUFFER:
    lda WRITE_PTR
    sec
    sbc READ_PTR
    rts

; Assume the UART is our only source of interrupts
IRQ_HANDLER:
    pha
    phx
    lda UART_STATUS   ; Clear the UART's interrupt flag by reading from the status register
    lda UART_DATA
    jsr WRITE_BUFFER
    plx
    pla
    rti

.include "beneater-wozmon.s"

.segment "RESETVECTORS"
    .word $0f00       ; NMI
    .word COLDBOOT    ; RESET
    .word IRQ_HANDLER ; IRQ
