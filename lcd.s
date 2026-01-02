.segment "CODE"
.ifdef BENEATER

VIACHIP_PORTB = $6000
VIACHIP_DIRECTION_PORTB = $6002

VIACHIP_E  = %01000000 ; Enable bit
VIACHIP_RW = %00100000 ; Read/Write bit
VIACHIP_RS = %00010000 ; Register Select bit

lcd_wait:
    pha                             ; Push accumulator onto the stack as the caller of lcd_wait is expecting its value to be preserved
    lda #$f0                        ; Set data bits to input mode
    sta VIACHIP_DIRECTION_PORTB
lcd_busy:
    lda #VIACHIP_RW
    sta VIACHIP_PORTB
    lda #(VIACHIP_RW | VIACHIP_E)   ; Set RW & E bits
    sta VIACHIP_PORTB
    lda VIACHIP_PORTB               ; Read high nibble and put on stack since it has the busy flag
    pha
    lda #VIACHIP_RW
    sta VIACHIP_PORTB
    lda #(VIACHIP_RW | VIACHIP_E)    ; Set RW & E bits
    sta VIACHIP_PORTB
    lda VIACHIP_PORTB                ; Read low nibble. We won't use it.
    pla                              ; Restore high nibble from stack
    and #%00001000                   ; Mask the busy flag. If busy, loop.
    bne lcd_busy

    lda #VIACHIP_RW                  ; Clear enable flag and restore VIA chip's port B to output
    sta VIACHIP_PORTB
    lda #$ff                         ; Restore all data bits to output mode
    sta VIACHIP_DIRECTION_PORTB
    pla                              ; Pop the accumulator from the stack to restore it
    rts

LCDINIT:
    lda #$ff            ; Set all pins of port B to output mode
    sta VIACHIP_DIRECTION_PORTB
    lda #%00000010      ; Set 4 bit mode
    sta VIACHIP_PORTB
    ora #VIACHIP_E      ; Set E bit
    sta VIACHIP_PORTB
    eor #VIACHIP_E      ; Clear E bit
    sta VIACHIP_PORTB    
    lda #%00101000 ; Display instruction 1: Set display to 8 bit mode, 2 line display, 5x8 font
    jsr lcd_instruction
    lda #%00001110 ; Display instruction 2: Set display on, cursor on, cursor *NOT* blinking
    jsr lcd_instruction
    lda #%00000110 ; Display instruction 3: Set entry mode to increment address register (shift cursor) and *NOT* shift the display
    jsr lcd_instruction
    lda #%00000001 ; Display instruction 4: Clear the display
    jsr lcd_instruction
    rts

LCDCMD:
    jsr GETBYT         ; Argument is a 1 byte number. It will be in X.
    txa
lcd_instruction:
    jsr lcd_wait
    pha
    lsr                ; Send high 4 bits first
    lsr
    lsr
    lsr
    sta VIACHIP_PORTB
    ora #VIACHIP_E     ; Set E bit
    sta VIACHIP_PORTB
    eor #VIACHIP_E     ; Clear E bit
    sta VIACHIP_PORTB
    pla                ; Restore A and send low 4 bits
    and #$0f
    sta VIACHIP_PORTB
    ora #VIACHIP_E     ; Set E bit
    sta VIACHIP_PORTB
    eor #VIACHIP_E     ; Clear E bit
    sta VIACHIP_PORTB
    rts

LCDPRINT:
    jsr GETBYT         ; Argument is a 1 byte number. It will be in X.
    txa
    jsr lcd_wait
    pha
    lsr                ; Send high 4 bits first
    lsr
    lsr
    lsr
    ora #VIACHIP_RS    ; set RS bit
    sta VIACHIP_PORTB
    ora #VIACHIP_E     ; Set E bit
    sta VIACHIP_PORTB
    eor #VIACHIP_E     ; Clear E bit
    sta VIACHIP_PORTB
    pla                ; Restore A and send low 4 bits
    and #$0f
    ora #VIACHIP_RS    ; Set RS bit
    sta VIACHIP_PORTB
    ora #VIACHIP_E     ; Set E bit
    sta VIACHIP_PORTB
    eor #VIACHIP_E     ; Clear E bit
    sta VIACHIP_PORTB
    rts

.endif