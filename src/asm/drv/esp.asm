; esp.asm

ESPSend                 macro(Text)                     ; 1 <= length(Text) <= 253
                        ld hl, Address                  ; Start of the text to send
                        ld e, length(Text)+2            ; Length of the text to send, including terminating CRLF
                        jp ESPSendProc                  ; Remaining send code is generic and reusable
Address:                db Text                         ; Text bytes get planted at the end of the macro
                        db CR, LF                       ; Followed by CRLF
mend

ESPSendBytes            macro(Address, Length)          ; 1 <= length(Text) <= 255 - MUST HAVE CRLF termination
                        ld hl, Address                  ; Start of the text to send
                        ld e, Length                    ; Length of the text to send, including terminating CRLF
                        jp ESPSendProc                  ; Remaining send code is generic and reusable
mend

ESPSendBuffer           macro(Address)                  ; 1 <= length(Text) <= 255 - MUST HAVE CRLF termination
                        ld hl, Address                  ; Start of the text to send
                        call GetBufferLength            ; returns with length in e and hl preserved
                        call ESPSendBufferProc          ; Remaining send code is generic and reusable
mend

ESPSendBufferLen        macro(Address, LenAddr)         ; 1 <= length(Text) <= 255 - MUST HAVE CRLF termination
                        ld hl, Address                  ; Start of the text to send
                        ld de, (LenAddr)
                        call ESPSendBufferProc          ; Remaining send code is generic and reusable
mend

ESPSendBufferSized      macro(Address, Len)              ; 1 <= length(Text) <= 255
                        ld hl, Address                  ; Start of the text to send
                        ld de, Len
                        call ESPSendBufferProc          ; Remaining send code is generic and reusable
mend

ESPSendProc             proc
                        call InitESPTimeout
                        ld bc, UART_GetStatus           ; UART Tx port also gives the UART status when read
ReadNextChar:           ld d, (hl)                      ; Read the next byte of the text to be sent
WaitNotBusy:            in a, (c)                       ; Read the UART status
                        and UART_mTX_BUSY               ; and check the busy bit (bit 1)
                        jr nz, CheckTimeout             ; If busy, keep trying until not busy
                        out (c), d                      ; Otherwise send the byte to the UART Tx port
                        inc hl                          ; Move to next byte of the text
                        dec e                           ; Check whether there are any more bytes of text
                        jp nz, ReadNextChar             ; If there are, read and repeat
                        jp (hl)                         ; Otherwise we are now pointing at the byte after the macro
CheckTimeout:           call CheckESPTimeout
                        jp WaitNotBusy
pend

ESPSendBufferProc       proc
                        call InitESPTimeout
                        ld bc, UART_GetStatus           ; UART Tx port also gives the UART status when read
ReadNextChar:           ld d, (hl)                      ; Read the next byte of the text to be sent
WaitNotBusy:            in a, (c)                       ; Read the UART status
                        and UART_mTX_BUSY               ; and check the busy bit (bit 1)
                        jr nz, WaitNotBusy//CheckTimeout             ; If busy, keep trying until not busy
                        out (c), d                      ; Otherwise send the byte to the UART Tx port
                        inc hl                          ; Move to next byte of the text
                        dec e                           ; Check whether there are any more bytes of text
                        jp nz, ReadNextChar             ; If there are, read and repeat
                        ret
CheckTimeout:           call CheckESPTimeout
                        jp WaitNotBusy
pend

ESPReceiveWaitOK        proc
                        call InitESPTimeout
                        xor a
                        ld (State), a
                        ld hl, FirstChar
                        ld (StateJump), hl
NotReady:               //ld a, 255
                        //ld(23692), a                    ; Turn off ULA scroll
                        ld a, high UART_GetStatus       ; Are there any characters waiting?
                        in a, (low UART_GetStatus)      ; This inputs from the 16-bit address UART_GetStatus
                        rrca                            ; Check UART_mRX_DATA_READY flag in bit 0
                        jp nc, NotReady//CheckTimeout             ; If not, retry
                        ld a, high UART_RxD             ; Otherwise Read the byte
                        in a, (low UART_RxD)            ; from the UART Rx port
StateJump equ $+1:      jp SMC
FirstChar:              cp 'O'
                        jp z, MatchOK
                        cp 'E'
                        jp z, MatchError
                        cp 'S'
                        jp z, MatchSendFail
                        jp Print
SubsequentChar:         cp (hl)
                        jp z, MatchSubsequent
                        ld hl, FirstChar
                        ld (StateJump), hl
Print:                  call CheckESPTimeout
Compare equ $+1:        ld de, SMC
                        push hl
                        CpHL(de)
                        pop hl
                        jp nz, NotReady
                        ld a, (State)
                        cp 0
                        ret z
                        scf
                        ret
MatchSubsequent:        inc hl
                        jp Print
MatchOK:                ld hl, SubsequentChar
                        ld (StateJump), hl
                        ld hl, OKEnd
                        ld (Compare), hl
                        ld hl, OK
                        xor a
                        ld (State), a
                        jp Print
MatchError:             ld hl, SubsequentChar
                        ld (StateJump), hl
                        ld hl, ErrorEnd
                        ld (Compare), hl
                        ld hl, Error
                        ld a, 1
                        ld (State), a
                        jp Print
MatchSendFail:          ld hl, SubsequentChar
                        ld (StateJump), hl
                        ld hl, SendFailEnd
                        ld (Compare), hl
                        ld hl, Error
                        ld a, 2
                        ld (State), a
                        jp Print
CheckTimeout:           call CheckESPTimeout
                        jp NotReady
State:                  db 0
OK:                     db "K", CR, LF
OKEnd:
Error:                  db "RROR", CR, LF
ErrorEnd:
SendFail:               db "END FAIL", CR, LF
SendFailEnd:
pend

CheckESPTimeout         proc
                        push hl
                        push af
Value equ $+1:          ld hl, SMC
                        dec hl
                        ld (Value), hl
                        ld a, h
                        or l
                        jr z, Rollover
Success:                pop af
                        pop hl
                        ret
Failure:
Stop:                   Border(2)
                        jr Stop
Rollover:
Value2 equ $+1:         ld hl, SMC                      ; Check the two upper values
                        ld a, h
                        or l
                        jr z, Failure                   ; If we hit here, 32 bit value is $00000000
                        dec hl
                        ld (Value2), hl
                        ld hl, ESPTimeout mod 65536
                        ld (Value), hl
                        jr Success
pend

InitESPTimeout          proc
                        push hl
                        ld hl, ESPTimeout mod 65536     ; Timeout is a 32-bit value, so save the two LSBs first,
                        ld (CheckESPTimeout.Value), hl
                        ld hl, ESPTimeout / 65536       ; then the two MSBs.
                        ld (CheckESPTimeout.Value2), hl
                        pop hl
                        ret
pend

ESPFlush                proc
                        ld bc, UART_GetStatus
ReadLoop:               ld a, high UART_GetStatus       ; Are there any characters waiting?
                        in a, (c)                       ; This inputs from the 16-bit address UART_GetStatus
                        rrca                            ; Check UART_mRX_DATA_READY flag in bit 0
                        ret nc                          ; Return immmediately if no data ready to be read
                        inc b                           ; Otherwise Read the byte
                        in a, (c)                       ; from the UART Rx port
                        dec b
                        jr ReadLoop                     ; then check if there are more data bytes ready to read
pend

