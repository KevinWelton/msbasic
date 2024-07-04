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


; Debugging code follows. Look below for the real start of bios.

LO = $00
HI = $01
TMP = $02

dbg:
    ldx #$ff        ; Initialize the stack pointer to be the top of the stack by loading x with $ff then transferring it to the stack pointer.
    txs

    ; Reset UART by writing anything to the status register
    lda #$00
    sta UART_STATUS

    ; UART control register: Set UART stop bit, word length, clock source and baud rate
    lda #$1f            ; 8 bit word, 1 stop bit, 19200 baud
    sta UART_CTRL

    ; UART command register: Set parity, echo, transmit interrupts and receive interrupts
    lda #$0b            ; No parity, echo or interrupts
    sta UART_CMD

    lda #0
    sta LO

    jsr printstart

; RAM is 0x0000 - 0x3fff. Let's test it.
fill:
    ldx #$3f
fillouter:
    stx HI
    ldy #$ff
fillinner:
    tya
    sta (LO), y
    dey
    cpy #$02            ; Don't verify areas that we use for storage of this program. This should be the last zp value used for storage.
    bcc fillzpcheck
    jmp fillepilogue
fillzpcheck:
    cpx #0
    beq filldone
fillepilogue:
    cpy #$ff            ; If we looped back around to $ff in the low byte, we are done and should decrement the high byte.
    bne fillinner
    dex
    cpx #$ff            ; If we looped back around to $ff in the high byte, we are done.
    bne fillouter
filldone:
    jsr writedonemsg

verify:
    ldx #$3f
vouter:
    stx HI
    ldy #$ff
vinner:
    sty TMP
    lda (LO), y
    cmp TMP
    bne logerr
    ; jsr print_addr   ; Enable for testing purposes
    ; jsr okmsg
    jmp vcont
logerr:
    jsr print_addr
    jsr errmsg
vcont:
    dey
    cpy #$02                ; Don't verify areas that we use for storage of this program. This should be the last zp value used for storage.
    bcc vzpcheck
    jmp vepilogue
vzpcheck:
    cpx #0
    beq vdone
vepilogue:
    cpy #$ff                ; If we looped back around to $ff in the high byte, we are done.
    bne vinner
    dex
    cpx #$01                ; Don't verify the stack as it has been mucked with.
    bne vnotstackbyte
    dex
vnotstackbyte:
    cpx #$ff                ; If we looped back around to $ff in the high byte, we are done.
    bne vouter
vdone:
    jsr printfinished
    jmp RESETWOZ

print_addr:
    php
    pha
    phx
    phy
    lda HI
    jsr printhex
    lda TMP
    jsr printhex
    ply
    plx
    pla
    plp
    rts

printhex:
    pha
    lsr
    lsr
    lsr
    lsr
    and #$0f
    jsr prepchar
    pla
    and #$0f
    jsr prepchar
    rts

prepchar:
    cmp #10
    bcs hex
    adc #$30 ; Zero char
    jmp ready
hex:
    sbc #10
    clc
    adc #$61 ; Lower case a char
ready:
    jsr send_char
    rts

ok: .asciiz " GOOD "
err: .asciiz " !!!!!! BAD !!!!!!! "
starting: .asciiz "STARTING..."
finished: .asciiz "FINISHED!"
writedone: .asciiz "Writing done. Verifying..."

printfinished:
    phx
    ldx #0
finishedloop:
    lda finished, x
    beq finisheddone
    jsr send_char
    inx
    jmp finishedloop
finisheddone:
    lda #$0D
    jsr send_char        ; Send newline
    lda #$0A
    jsr send_char
    plx
    rts

printstart:
    phx
    ldx #0
startloop:
    lda starting, x
    beq startdone
    jsr send_char
    inx
    jmp startloop
startdone:
    lda #$0D
    jsr send_char        ; Send newline
    lda #$0A
    jsr send_char
    plx
    rts

errmsg:
    phy
    phx
    ldx #0
errloop:
    lda err, x
    beq errdone
    jsr send_char
    inx
    jmp errloop
errdone:
    lda #$77            ; lower case w
    jsr send_char
    lda TMP
    jsr printhex
    lda #$20            ; space
    jsr send_char
    lda #$78            ; lower case x
    jsr send_char
    ldy TMP
    lda (LO), y
    jsr printhex

    lda #$0D
    jsr send_char        ; Send newline
    lda #$0A
    jsr send_char
    plx
    ply
    rts

okmsg:
    phx
    phy
    ldx #0
okloop:
    lda ok, x
    beq okdone
    jsr send_char
    inx
    jmp okloop
okdone:
    lda #$77             ; lower case w
    jsr send_char
    lda TMP
    jsr printhex
    lda #$20             ; space
    jsr send_char
    lda #$78             ; lower case x
    jsr send_char
    ldy TMP
    lda (LO), y
    jsr printhex

    lda #$0D
    jsr send_char        ; Send newline
    lda #$0A
    jsr send_char
    ply
    plx
    rts

writedonemsg:
    phx
    ldx #0
writedoneloop:
    lda writedone, x
    beq writedonedone
    jsr send_char
    inx
    jmp writedoneloop
writedonedone:
    lda #$0D
    jsr send_char        ; Send newline
    lda #$0A
    jsr send_char
    plx
    rts

send_char:
    phy
    phx
    pha
    sta UART_DATA
    ldx #$ff
tx_wait:
    dex
    bne tx_wait
    pla
    plx
    ply
    rts

rx_wait:
    lda UART_STATUS    ; Check if receive buffer is full. Keep waiting if not.
    and #$08
    beq rx_wait
    lda UART_DATA
    jsr send_char      ; Echo the char back through the serial port so we see what we typed
    jmp rx_wait













; Real bios follows


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
