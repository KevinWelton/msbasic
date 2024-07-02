.segment "CODE"

SAVE:
        ; pha
        ; jsr     WHEREO
        ; jsr     OUTSP
        ; lda     #$ff
        ;jmp     LB4BF

LOAD:
        ; beq     L2739
        ; sta     $A64E
        ; jsr     CHRGET
        ; bne     L2738
        ; ldy     #$80
        ; jsr     USR3
        ; bcs     LC6EF

        ; lda     #<LOADED
        ; ldy     #>LOADED
        ; jsr     STROUT

        ; ldx     P3L
        ; ldy     P3H
        ; txa
        ; stx     VARTAB
        ; sty     VARTAB+1
        jmp     FIX_LINKS

; MONCOUT:
;         pha
;         lda     OUTFLG
;         jsr     COUT5
;         bne     COUT3
;         pla
;         jmp     OUTALL

; COUT3:
;         pla
;         cmp     #LF
;         beq     COUT6
;         cmp     #CR
;         beq     COUT4
;         jmp     OUTPUT
; COUT4:
;         jsr     CRCK
;         lda     #CR
;         rts

; COUT5:
;         cmp     #$54
;         beq     COUT6
;         cmp     #$55
;         beq     COUT6
;         cmp     #$4C
; COUT6:
;         rts

; MONRDKEY2:
;         jsr     ROONEK
;         tya
;         beq     COUT5
;         jmp     GETKY
