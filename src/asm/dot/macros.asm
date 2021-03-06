; macros.asm

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

include "version.asm", 1                                ; Auto-generated by ..\build\cspect.bat or builddot.bat. Has
                                                        ; date/time and git commit counts generated by an external tool.
Border                  macro(Colour)
                        if Colour=0                     ; Convenience macro to help during debugging. The dot command
                          xor a                         ; doesn't change the border colour during regular operation.
                        else
                          ld a, Colour
                        endif
                        out (ULA_PORT), a
                        if Colour=0
                          xor a
                        else
                          ld a, Colour*8
                        endif
                        ld (23624), a
mend

Freeze                  macro(Colour1, Colour2)         ; Convenience macro to help during debugging. Alternates
Loop:                   Border(Colour1)                 ; the border rapidly between two colours. This really helps
                        Border(Colour2)                 ; to show that the machine hasn't crashed. Also it give you
                        jr Loop                         ; 8*7=56 colour combinations to use, instead of 7.
mend

MFBreak                 macro()                         ; Intended for NextZXOS NMI debugging
                        push af                         ; MF must be enabled first, by pressing M1 button
                        ld a, r                         ; then choosing Return from the NMI menu.
                        di
                        in a, ($3f)
                        rst 8                           ; It's possible the stack will end up unbalanced
mend                                                    ; if the MF break doesn't get triggered!

CSBreak                 macro()                         ; Intended for CSpect debugging
                        push bc                         ; enabled when the -brk switch is supplied
                        noflow                          ; Mitigate the worst effect of running on real hardware
                        db $DD, $01                     ; On real Z80 or Z80N, this does NOP:LD BC, NNNN
                        nop                             ; so we set safe values for NN
                        nop                             ; and NN,
                        pop bc                          ; then we restore the value of bc we saved earlier
mend

CSExit                  macro()                         ; Intended for CSpect debugging
                        noflow                          ; enabled when the -exit switch is supplied
                        db $DD, $00                     ; This executes as NOP:NOP on real hardware
mend

MirrorA                 macro()                         ; Macro for Z80N mirror a opcode
                        noflow
                        db $ED, $24
mend

CpHL                    macro(Register)                 ; Convenience wrapper to compare HL with BC or DE
                        or a                            ; Note that Zeus macros can accept register literals, so the
                        sbc hl, Register                ; call would be CPHL(de) without enclosing quotes.
                        add hl, Register
mend

ErrorAlways             macro(ErrAddr)                  ; Parameterised wrapper for unconditional custom error
                        ld hl, ErrAddr
                        jp ErrorProc
mend

ErrorIfCarry            macro(ErrAddr)                  ; Parameterised wrapper for throwing custom esxDOS-style error
                        jr nc, Continue
                        ld hl, ErrAddr
                        jp ErrorProc
Continue:
mend

ErrorIfNoCarry          macro(ErrAddr)                  ; Parameterised wrapper for throwing custom NextZXOS-style error
                        jr c, Continue
                        ld hl, ErrAddr
                        jp ErrorProc
Continue:
mend

ErrorIfZero             macro(ErrAddr)                  ; Parameterised wrapper for throwing error if loop overruns
                        jr nz, Continue
                        ld hl, ErrAddr
                        jp ErrorProc
Continue:
mend

ErrorIfNotZero          macro(ErrAddr)                  ; Parameterised wrapper for throwing error after comparison
                        jr z, Continue
                        ld hl, ErrAddr
                        jp ErrorProc
Continue:
mend

ErrorIfCarryEsx         macro()                         ; Wrapper for throwing standard esxDOS error
                        jr nc, Continue
                        jp ErrorProcEsx
Continue:
mend

PrintMsg                macro(Address)                  ; Parameterised wrapper for null-terminated buffer print routine
                        ld hl, Address
                        call PrintRst16
mend

PrintMsgLen             macro(Address, Len)                  ; Parameterised wrapper for null-terminated buffer print routine
                        ld hl, Address
                        ld bc, Len
                        call PrintRst16Len
mend

PrintBufferHex          macro(Addr, Len)                ; Parameterised wrapper for fixed-length hex print routine
                        ld hl, Addr
                        ld de, Len
                        call PrintBufferHexProc
mend

SafePrintStart          macro()                         ; Included at the start of every routine which calls rst 16
                        di                              ; Interrupts off while paging. Subsequent code will enable them.
                        ld (SavedStackPrint), sp        ; Save current stack to be restored in SafePrintEnd()
                        ld sp, (Return.Stack1)          ; Set stack back to what BASIC had at entry, so safe for rst 16
                        ld (SavedIYPrint), iy
                        ld iy, $5C3A
mend

SafePrintEnd            macro()                         ; Included at the end of every routine which calls rst 16
                        di                              ; Interrupts off while paging. Subsequent code doesn't care.
SavedA equ $+1:         ld a, SMC                       ; Restore A so it's completely free of side-effects
                        ld sp, (SavedStackPrint)        ; Restore stack to what it was before SafePrintStart()
                        ld iy, (SavedIYPrint)
mend

Rst8                    macro(Command)                  ; Parameterised wrapper for esxDOS API routine
                        rst $08
                        noflow
                        db Command
mend

NextRegRead             macro(Register)                 ; Nextregs have to be read through the register I/O port pair,
                        ld bc, $243B                    ; as there is no dedicated ZX80N opcode like there is for
                        ld a, Register                  ; writes.
                        out (c), a
                        inc b
                        in a, (c)
mend

WaitFrames              macro(Frames)                   ; Parameterised wrapper for safe halt routine
                        ld bc, Frames
                        call WaitFramesProc
mend

FillLDIR                macro(SourceAddr, Size, Value)  ; Parameterised wrapper for LDIR fill
                        ld a, Value
                        ld hl, SourceAddr
                        ld (hl), a
                        ld de, SourceAddr+1
                        ld bc, Size-1
                        ldir
mend

CopyLDIR                macro(SourceAddr, DestAddr, Size)
                        ld hl, SourceAddr
                        ld de, DestAddr
                        ld bc, Size
                        ldir
mend

GetSizedArg             macro(ArgTailPtr, DestAddr)    ; Parameterised wrapper for arg parser
                        ld hl, (ArgTailPtr)
                        ld de, DestAddr
                        call GetSizedArgProc
mend

SetUARTBaud             macro(BaudTable, BaudMsg)       ; Parameterised wrapper for UART baud setting routine
                        ld hl, BaudTable                ; Not currently used
                        ld de, BaudMsg
                        call SetUARTBaudProc
mend

