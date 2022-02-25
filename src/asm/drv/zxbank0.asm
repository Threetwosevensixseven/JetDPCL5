; zxbank0.asm

org $8000
ZXBank0Start:

OpenESPConnection       proc
                        push hl                         ; Save address of ConnIsOpen
                        call ESPFlush
                        ESPSend("ATE0")                 ; * Until we have absolute frame-based timeouts, send first AT
                        call ESPReceiveWaitOK           ; * cmd twice to give it longer to respond to one of them.
                        ESPSend("AT+CIPCLOSE")          ; Don't raise error on CIPCLOSE
                        call ESPReceiveWaitOK           ; Because it might not be open
                        ESPSend("AT+CIPMUX=0")
                        call ESPReceiveWaitOK
                        ESPSend("AT+CIPSTART=""TCP"",""" + PrinterIP + """," + PrinterPort)
                        call ESPReceiveWaitOK
                        call InitESPBuffer
                        pop hl                          ; Restore address of ConnIsOpen
                        ld (hl), 1                      ; Set ConnIsOpen=1
                        ret
pend

InitESPBuffer           proc
                        ld hl, BufferAddr
                        ld (Buffer.Start), hl
                        ld (Buffer.Pos), hl
                        ret
pend

PrintESPCharToBuffer    proc
                        ld a, e

                        cp CR
                        jr z, Retry
                        cp LF
                        jr z, Retry
                        cp 32
                        ret c
                        cp 128
                        ret nc

Retry:                  ld de, (Buffer.Pos)
                        ld hl, BufferEnd                        ; Max Buffer length is $1FFF
                        CpHL(de)
                        jr z, Flush                             ; If we will to overflow, print buffer first
                        ex de, hl
                        ld (hl), a
                        inc hl
                        ld (Buffer.Pos), hl
                        cp CR
                        ret nz
                        ld e, LF
                        jr PrintESPCharToBuffer
Flush:                  push af
                        call SendBufferToESP
                        pop af
                        jr Retry
pend

SendBufferToESP         proc
                        ESPSendBufferSized(Cmd.CIPSEND,Cmd.CIPSENDLen)
                        ld hl, (Buffer.Pos)
                        ld de, BufferAddr
                        or a
                        sbc hl, de                      ; HL = number of bytes to print
                        ld (SendCount), hl
                        call ConvertWordToAsc           ; Convert HL to up to five decimal digit bytes (max 4 here)
                        ld e, a                         ; hl = Address of digits
                        ld d, 0                         ; de = Count of digits
                        call ESPSendBufferProc          ; Send decimal digits
                        ESPSendBufferSized(Cmd.CRLF,Cmd.CRLFLen)
                        call ESPReceiveWaitOK
                        ld hl, BufferAddr               ; hl = start of bytes to send
                        ld de, [SendCount]SMC           ; de = number of bytes to send
                        call ESPSendBufferProc
                        call ESPReceiveWaitOK
                        call InitESPBuffer
                        ret
pend

CloseESPConnection      proc
                        push hl                         ; Save address of ConnIsOpen
                        call SendBufferToESP
                        ESPSend("AT+CIPCLOSE")          ; Don't raise error on CIPCLOSE
                        call ESPReceiveWaitOK           ; Because it might not be open
                        pop hl                          ; Restore address of ConnIsOpen
                        ld (hl), 0                      ; Set ConnIsOpen=0
                        ret
pend

ConvertWordToAsc        proc                            ; Input word in hl
                        ld de, WordStart                ; Returns with output word in hl and length in a
                        ld bc, -10000
                        call Num1
                        ld bc, -1000
                        call Num1
                        ld bc, -100
                        call Num1
                        ld c, -10
                        call Num1
                        ld c, -1
                        call Num1
                        ld hl, WordStart
                        ld b, 5
                        ld c, '0'
FindLoop:               ld a, (hl)
                        cp c
                        jp nz, Found
                        inc hl
                        djnz FindLoop
Found:                  ld a, b
                        ld (WordLen), a
                        ld (WordStart), hl
                        ret
Num1:                   ld a, '0'-1
Num2:                   inc a
                        add hl, bc
                        jr c, Num2
                        sbc hl, bc
                        ld (de), a
                        inc de
                        ret
pend

DecimalDigits proc Table:

; Multipler  Index  Digits
  dw      1  ;   0       1
  dw     10  ;   1       2
  dw    100  ;   2       3
  dw   1000  ;   3       4
  dw  10000  ;   4       5
pend

WordStart:              ds 5
WordLen:                dw $0000

Red                     proc
                        Border(2)
                        jr Red
pend

Cmd                     proc
 CIPSEND                db "AT+CIPSEND="
 CIPSENDLen             equ $-CIPSEND
 CRLF                   db CR, LF
 CRLFLen                equ $-CRLF
pend

include "esp.asm"

Buffer                  proc
  Start                 dw 0                            ; Buffer always starts at beginning of slot 7
  Pos                   dw 0                            ; Buffer can extend to end of slot 7
pend

ZXBank0Length equ $-ZXBank0Start
zeusprint "ZX Bank 0 size=",ZXBank0Length

output_bin "..\..\..\bin\ZXBank0.bin", ZXBank0Start, ZXBank0Length

