; zxbank0.asm

org $8000
ZXBank0Start:

OpenESPConnection       proc                            ; Enter with address on ConnIsOpen in HL.
                        push hl                         ; Save address of ConnIsOpen.
                        call ESPFlush
                        ESPSend("ATE0")                 ; Turn off remote echo by ESP.
                        call ESPReceiveWaitOK           ; Wait for OK or ERROR response.
                        ESPSend("AT+CIPCLOSE")          ; Don't raise error on AT+CIPCLOSE,
                        call ESPReceiveWaitOK           ; Because no connections might be open.
                        ESPSend("AT+CIPMUX=0")          ; Use only one connection, which simplifies commands.
                        call ESPReceiveWaitOK           ; Wait for OK or ERROR response.
                        ESPSend("AT+CIPSTART=""TCP"",""" + PrinterIP + """," + PrinterPort) ; Connect to JetDirect
                        call ESPReceiveWaitOK           ; print server (usually port 9100), and wait for OK or ERROR.
                        call ClearBuffer                ; Ensure buffer is empty.
                        pop hl                          ; Restore address of ConnIsOpen.
                        ld (hl), 1                      ; Set ConnIsOpen=1.
                        ret
pend

ClearBuffer             proc                            ; No input parameters.
                        ld hl, BufferAddr               ; Usually $E000, start of slot 7. Max buffer size is $1FFF.
                        ld (Buffer.Start), hl           ; Set both buffer Start and Pos the same,
                        ld (Buffer.Pos), hl             ; signifying that the char count is 0.
                        ret
pend

CopyCharToBuffer        proc                            ; Enter with char to copy to buffer in E,
                        ld a, e                         ; but copy to A to work with.
                        cp CR                           ; Allow CR
                        jr z, Validated
                        cp LF                           ; and LF,
                        jr z, Validated
                        cp 32                           ; but drop any other chars < 32
                        ret c
                        cp 128                          ; or >= 128. All chars 32..127 are OK.
                        ret nc
Validated:              ld de, (Buffer.Pos)
                        ld hl, BufferEnd                ; Max Buffer length is $1FFF.
                        CpHL(de)
                        jr z, Flush                     ; If we will overflow by adding this char,
                        ex de, hl                       ; print and empty buffer first.
                        ld (hl), a                      ; Copy char to buffer at current position,
                        inc hl                          ; advance the position,
                        ld (Buffer.Pos), hl             ; and save back to the current position.
                        cp CR                           ; If not a CR exit now.
                        ret nz                          ; Otherwise expand every CR
                        ld e, LF                        ; into CRLF
                        jr CopyCharToBuffer             ; by calling back into the routine again.
Flush:
                        push af                         ; Save the uncopied char,
                        call SendBufferToESP            ; print and empty the buffer,
                        pop af                          ; restore the uncopied char,
                        jr Validated                    ; then copy it to the buffer.
pend

SendBufferToESP         proc                            ; No input parameters.
                        ESPSendBufferSized(Cmd.CIPSEND,Cmd.CIPSENDLen) ; Send AT+CIPSEND= to ESP
                        ld hl, (Buffer.Pos)             ; Load buffer start
                        ld de, (Buffer.Start)
                        or a                            ; and calculate buffer size.
                        sbc hl, de                      ; HL = number of bytes to send to print.
                        ld a, h
                        or l                            ; If buffer is empty, return immediately, because
                        ret z                           ; (Buffer.Pos)=(Buffer.Start) so the count is 0.
                        ld (SendCount), hl              ; Save the buffer count.
                        call ConvertWordToAsc           ; Convert count to between 1..4 decimal digit bytes.
                        ld e, a                         ; hl = Address of digits.
                        ld d, 0                         ; de = Count of digits.
                        call ESPSendBufferProc          ; Send decimal digits to ESP as continuation of AT+CIPSEND.
                        ESPSendBufferSized(Cmd.CRLF,Cmd.CRLFLen); Terminate AT+CIPSEND with CRLF and send to ESP.
                        call ESPReceiveWaitOK           ; Wait for OK response (will also be followed by >).
                        ld hl, BufferAddr               ; hl = start of bytes to send.
                        ld de, [SendCount]SMC           ; de = number of bytes to send.
                        call ESPSendBufferProc          ; Print the entire buffer to ESP,
                        call ESPReceiveWaitOK           ; and wait for OK or ERROR.
                        call ClearBuffer                ; Finally clear buffer
                        ret                             ; and return.
pend

CloseESPConnection      proc                            ; Enter with address on ConnIsOpen in HL.
                        push hl                         ; Save address of ConnIsOpen.
                        call SendBufferToESP
                        ESPSend("AT+CIPCLOSE")          ; Don't raise error on AT+CIPCLOSE,
                        call ESPReceiveWaitOK           ; Because no connections might be open.
                        pop hl                          ; Restore address of ConnIsOpen.
                        ld (hl), 0                      ; Set ConnIsOpen=0.
                        ret
pend

; Originally came from: https://wikiti.brandonw.net/index.php?title=Z80_Routines:Other:DispHL
; or somewhere similar, and adapted to suit.
ConvertWordToAsc        proc                            ; Input word in hl.
                        ld de, WordStart                ; Returns with output word in hl and length in a.
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
                        ret                             ; Returns with output word in hl and length in a.
Num1:                   ld a, '0'-1
Num2:                   inc a
                        add hl, bc
                        jr c, Num2
                        sbc hl, bc
                        ld (de), a
                        inc de
                        ret
pend

WordStart:              ds 5                            ; Results of ConvertWordToAsc
WordLen:                dw $0000                        ; Get stored permanently here.

Cmd                     proc
 CIPSEND                db "AT+CIPSEND="                ; Prefix of AT_CIPSEND cmd. Follow w/ 1..5 ASCII digits & CRLF.
 CIPSENDLen             equ $-CIPSEND
 CRLF                   db CR, LF                       ; Terminating CRLF.
 CRLFLen                equ $-CRLF
pend

include "esp.asm"                                       ; All the ESP macros and routines are collected in this file.

Buffer                  proc
  Start                 dw BufferAddr                   ; Buffer always starts at beginning of slot 7 ($E000).
  Pos                   dw BufferAddr                   ; Buffer can extend to almost the end of slot 7 ($FFFE),
pend                                                    ; but starts off empty.

ZXBank0Length equ $-ZXBank0Start
zeusprint "ZX Bank 0 size=",ZXBank0Length

output_bin "..\..\..\bin\ZXBank0.bin", ZXBank0Start, ZXBank0Length

