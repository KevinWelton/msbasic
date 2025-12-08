; This version of Wozmon is meant to be included in the 18-bios.s file. It is not self contained.

; NOTE: This is adapted from the version of Woz's code at https://github.com/jefftranter/6502/blob/master/asm/wozmon/wozmon.s
; ------------------------------------------------------------------------------

;  The WOZ Monitor for the Apple 1
;  Written by Steve Wozniak in 1976
;  Adapted for BenEater's 6502 kit

.setcpu "65C02"
.segment "WOZMON"

; Page 0 Variables

XAML            = $24             ;  Last "opened" location Low (eXAMine Low byte)
XAMH            = $25             ;  Last "opened" location High (eXAMine High byte)
STL             = $26             ;  Store address Low
STH             = $27             ;  Store address High
HEXPARSEL       = $28             ;  Hex value parsing Low
HEXPARSEH       = $29             ;  Hex value parsing High
YSAV            = $2A             ;  Used to see if hex value is given
MODE            = $2B             ;  $00=XAM, $7F=STOR, $AE=BLOCK XAM

IN              = $0200           ;  Input buffer to $027F

CHR_BKSPACE   = $08
CHR_ESCAPE    = $1b
CHR_BKSLASH   = $5c
CHR_CR        = $0d
CHR_LF        = $0a
CHR_PERIOD    = $2e
CHR_COLON     = $3a
CHR_R_UP      = $52
CHR_ZERO      = $30
CHR_NINE      = $39
CHAR_SPACE    = $20

RESETWOZ:
                CLD               ; Clear decimal arithmetic mode (not strictly necessary anymore)
                NOP               ; Padding to keep this at exactly 256 bytes (probably don't need)
                LDA #$1f          ; UART control register: 8 bit word, 1 stop bit, 19200 baud
                STA UART_CTRL
                LDA #$89          ; UART command register: No parity, no echo, yes interrupts
                STA UART_CMD
                CLI               ; Clear interrupt disable (enable interrupts)
                JSR BIOSINIT      ; Label is in beneater-bios.s

NOTCR:          CMP #CHR_BKSPACE  ; Backspace?
                BEQ BACKSPACE
                CMP #CHR_ESCAPE   ; ESC?
                BEQ ESCAPE
                INY               ; Advance text index.
                BPL NEXTCHAR      ; Auto ESC if > 127.

ESCAPE:         LDA #CHR_BKSLASH
                JSR ECHO          ; Output it.

GETLINE:        LDA #CHR_CR       ; Print CRLF
                JSR ECHO
                LDA #CHR_LF
                JSR ECHO
                LDY #$01          ; Initialize text index.

BACKSPACE:      DEY               ; Back up text index.
                BMI GETLINE       ; Beyond start of line, reinitialize.

NEXTCHAR:
                jsr CHRIN         ; Does our BIOS ring buffer have anything? If not, keep checking.
                bcc NEXTCHAR
                STA IN,Y          ; Add to text buffer.
                CMP #CHR_CR       ; CR?
                BNE NOTCR         ; No.
                LDY #$FF          ; Reset text index.
                LDA #$00          ; For XAM mode.
                TAX               ; 0->X.

SETBLOCK:       ASL               ; For BLOCK XAM mode, bit 7 must be 1. Woz's code always assumed the high bit was 1. We don't. So shift the 1 in the . char to bit 7.

SETSTOR:        ASL               ; Leaves $7B if setting STOR mode.

SETMODE:        STA MODE          ; $00=XAM, $7B=STOR, $AE=BLOCK XAM.

BLSKIP:         INY               ; Advance text index.

NEXTITEM:       LDA IN,Y          ; Get character.
                CMP #CHR_CR       ; CR?
                BEQ GETLINE       ; Yes, done this line.
                CMP #CHR_PERIOD   ; "."?
                BCC BLSKIP        ; Skip delimiter.
                BEQ SETBLOCK      ; Set BLOCK XAM mode.
                CMP #CHR_COLON    ; ":"?
                BEQ SETSTOR       ; Yes. Set STOR mode.
                CMP #CHR_R_UP     ; "R"?
                BEQ RUNPROGRAM    ; Yes. Run user program.
                STX HEXPARSEL     ; $00->HEXPARSEL.
                STX HEXPARSEH     ;  and HEXPARSEH.
                STY YSAV          ; Save Y for comparison.

NEXTHEX:        LDA IN,Y          ; Get character for hex test.
                EOR #$30          ; Map digits to $0-9.
                CMP #$0A          ; Digit?
                BCC DIG           ; Yes.
                ADC #$88          ; Map letter "A"-"F" to $FA-FF.
                CMP #$FA          ; Hex letter?
                BCC NOTHEX        ; No, character not hex.

DIG:            ASL
                ASL               ; Hex digit to MSD of A.
                ASL
                ASL
                LDX #$04          ; Shift count.

HEXSHIFT:       ASL               ; Hex digit left, MSB to carry.
                ROL HEXPARSEL     ; Rotate into LSD.
                ROL HEXPARSEH     ; Rotate into MSD’s.
                DEX               ; Done 4 shifts?
                BNE HEXSHIFT      ; No, loop.
                INY               ; Advance text index.
                BNE NEXTHEX       ; Always taken. Check next character for hex.

NOTHEX:         CPY YSAV          ; Check if HEXPARSEL, HEXPARSEH empty (no hex digits).
                BEQ ESCAPE        ; Yes, generate ESC sequence.
                BIT MODE          ; Test MODE byte.
                BVC NOTSTOR       ; B6=0 STOR, 1 for XAM and BLOCK XAM
                LDA HEXPARSEL     ; LSD’s of hex data.
                STA (STL,X)       ; Store at current ‘store index’.
                INC STL           ; Increment store index.
                BNE NEXTITEM      ; Get next item. (no carry).
                INC STH           ; Add carry to ‘store index’ high order.

TONEXTITEM:     JMP NEXTITEM      ; Get next command item.

RUNPROGRAM:     JMP (XAML)        ; Run at current XAM index.

NOTSTOR:        BMI XAMNEXT       ; B7=0 for XAM, 1 for BLOCK XAM.

                LDX #$02          ; Byte count.
SETADR:         LDA HEXPARSEL-1,X ; Copy hex data to
                STA STL-1,X       ;  ‘store index’.
                STA XAML-1,X      ; And to ‘XAM index’.
                DEX               ; Next of 2 bytes.
                BNE SETADR        ; Loop unless X=0.

NXTPRNT:        BNE PRDATA        ; NE means no address to print.
                LDA #CHR_CR       ; CR.
                JSR ECHO          ; Output it.
                LDA #CHR_LF
                JSR ECHO
                LDA XAMH          ; ‘Examine index’ high-order byte.
                JSR PRBYTE        ; Output it in hex format.
                LDA XAML          ; Low-order ‘examine index’ byte.
                JSR PRBYTE        ; Output it in hex format.
                LDA #CHR_COLON    ; ":".
                JSR ECHO          ; Output it.

PRDATA:         LDA #CHAR_SPACE   ; Blank.
                JSR ECHO          ; Output it.
                LDA (XAML,X)      ; Get data byte at ‘examine index’.
                JSR PRBYTE        ; Output it in hex format.

XAMNEXT:        STX MODE          ; 0->MODE (XAM mode).
                LDA XAML
                CMP HEXPARSEL     ; Compare ‘examine index’ to hex data.
                LDA XAMH
                SBC HEXPARSEH
                BCS TONEXTITEM    ; Not less, so no more data to output.
                INC XAML
                BNE MOD8CHK       ; Increment ‘examine index’.
                INC XAMH

MOD8CHK:        LDA XAML          ; Check low-order ‘examine index’ byte
                AND #$07          ;  For MOD 8=0
                BPL NXTPRNT       ; Always taken.

PRBYTE:         PHA               ; Save A for LSD.
                LSR
                LSR
                LSR               ; MSD to LSD position.
                LSR
                JSR PRHEX         ; Output hex digit.
                PLA               ; Restore A.

PRHEX:          AND #$0F          ; Mask LSD for hex print.
                ORA #CHR_ZERO     ; Add "0".
                CMP #CHR_NINE+1   ; Digit?
                BCC ECHO          ; Yes, output it.
                ADC #$06          ; Add offset for letter. 

ECHO:           STA UART_DATA     ; Output character
                PHA
                LDA #$ff          ; Init echo delay loop
echo_delay_loop:
                DEC
                BNE echo_delay_loop
                PLA
                RTS               ; Return.
