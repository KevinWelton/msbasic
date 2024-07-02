.segment "CODE"
ISCNTC:
        lda     UART_DATA
        cmp     #$03
;!!! runs into "STOP"