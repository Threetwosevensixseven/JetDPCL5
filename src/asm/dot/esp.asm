; esp.asm

;  Copyright 2020 Robin Verhagen-Guest
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;     http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.

ResetESP                proc                            ; Reset ESP with a normal (non-programming) reset
                        nextreg 2, 128                  ; Set RST low
                        call Wait5Frames                ; Hold in reset
                        nextreg 2, 0                    ; Set RST high
                        call Wait5Frames                ; Hold in reset
NoReset:                ret
pend

ESPFlush                proc
                        di
                        ld (SavedStack), sp             ; Save stack
                        ld sp, (Return.Stack1)          ; Put stack in upper 16K so FRAMES gets update
                        ei
                        ld a, (FRAMES)
                        add a, [WaitNFrames]255
                        ld (TimeoutFrame), a
                        ld bc, UART_GetStatus
WaitNotBusy:            in a, (c)                       ; This inputs from the 16-bit address UART_GetStatus
                        rrca                            ; Check UART_mRX_DATA_READY flag in bit 0
                        jp c, HasData                   ; Read Data if available
                        ld a, (FRAMES)
                        cp [TimeoutFrame]SMC
                        jp nz, WaitNotBusy              ; Try again for at least another N frames (5)
                        di
                        scf                             ; Set carry to signal error if N frames with no data,
                        jr Return                       ; and return
HasData:                inc b                           ; Otherwise Read the byte,
                        in a, (c)                       ; from the UART Rx port,
                        dec b
                        jr nz, WaitNotBusy              ; If so, check if there are more data bytes ready to read,
                        or a                            ; otherwise clear carry to signal success,
Return:                 di
                        ld sp, [SavedStack]SMC
                        ret                             ; and return
pend

