ISCNTC:
    jsr MONRDKEY
    bcc NOT_CNTC
    cmp #3
    bne NOT_CNTC
    jmp IS_CNTC

NOT_CNTC:
    rts

IS_CNTC:
    ; Fall through
