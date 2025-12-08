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

; We use the via chip to control the clear-to-send signal since the UART seems to have a bug
VIACHIP_PORTA = $6001
VIACHIP_DIRECTION_PORTA = $6003

UART_DATA   = $5000
UART_STATUS = $5001
UART_CMD    = $5002
UART_CTRL   = $5003

BASICMSGSTART:
    .asciiz "Start MS Basic with "

BASICMSGEND:
    .asciiz "R"

LOAD:
    rts

SAVE:
    rts

INITBIOS:
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
    beq @init_buffer
    jsr CHROUT
    inx
    jmp @postmsg
; Initialize our write and read pointers
; Modifies: P, A
@init_buffer:
    lda READ_PTR                  ; Make ring buffer pointers the same
    sta WRITE_PTR
    lda #$01                      ; Set bit 0 of via chip port A specify pin 0 of port A will be used as output
    sta VIACHIP_DIRECTION_PORTA
    lda #$fe                      ; Make sure pin 0 of port A is low to so we default to clear-to-send being set (it's inverted at the MAX232 chip before going over the serial cable.)
    and VIACHIP_PORTA
    sta VIACHIP_PORTA
    rts               ; Back to wozmon

; Modifies: P, A
MONRDKEY:
CHRIN:
    phx
    jsr BUFFER_SIZE    ; Check if we have characters in our ring buffer. If so, read the next one and set the carry bit.
    beq @no_keypressed
    jsr READ_BUFFER
    jsr CHROUT
    pha                ; We're about to clobber A which has our character. Push it to the stack and pop it after the upcoming clear-to-send logic.
    jsr BUFFER_SIZE
    cmp #$b0           ; If the buffer size (in A) is greater than about 2/3 of the buffer size (about #$B0)
    bcs @mostly_full   ; If the buffer was mostly full (A - #$B0 >= 0), it means the CMP's subtract didn't need to borrow. (Carry flag is an inverted borrow flag in 6502 subtraction.)
    lda #$fe           ; Set VIA chip port A pin 0 low to re-enable clear-to-send signal (it's inverted at the MAX232 before going over the serial cable.)
    and VIACHIP_PORTA
    sta VIACHIP_PORTA
@mostly_full:
    pla                ; Restore the character we received from the CHROUT call above
    plx
    sec
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
BUFFER_SIZE:
    lda WRITE_PTR
    sec
    sbc READ_PTR
    rts

; Assume the UART is our only source of interrupts
IRQ_HANDLER:
    pha
    phx
    lda UART_STATUS      ; Clear the UART's interrupt flag by reading from the status register
    lda UART_DATA
    jsr WRITE_BUFFER
    jsr BUFFER_SIZE
    cmp #$f0             ; If our input buffer is _almost_ full (remote machine may have sent a few more bytes already), consider it full.
    bcc @not_almost_full ; The cmp instruction prior will have the carry bit clear if the const (#$F0) is >= to A.
    lda #$01             ; If the input buffer is full, set VIA chip port A pin 0 high to disable clear-to-send signal (it's inverted at the MAX232 before going over the serial cable.)
    ora VIACHIP_PORTA
    sta VIACHIP_PORTA
@not_almost_full:
    plx
    pla
    rti

.include "beneater-wozmon.s"

.segment "RESETVECTORS"
    .word $0f00       ; NMI
    .word RESETWOZ    ; RESET
    .word IRQ_HANDLER ; IRQ
