; general.asm

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

InstallErrorHandler     proc                            ; Our error handler gets called by the OS if SCROLL? N happens
                        ld hl, ErrorHandler             ; during printing, or any other ROM errors get thrown. We trap
                        Rst8(M_ERRH)                    ; the error in our ErrorHandler routine to give us a chance to
                        ret                             ; clean up the dot cmd before exiting to BASIC.
pend

ErrorHandler            proc                            ; If we trap any errors thrown by the ROM, we currently just
                        ld hl, Err.Break                ; exit the dot cmd with a  "D BREAK - CONT repeats" custom
                        jp Return.WithCustomError       ; error.
pend

ErrorProc               proc
                        if enabled ErrDebug
                          call PrintRst16Error
Stop:                     Border(2)
                          jr Stop
                        else                            ; The normal (non-debug) error routine shows the error in both
                          push hl                       ; If we want to print the error at the top of the screen,
                          call PrintRst16Error          ; as well as letting BASIC print it in the lower screen,
                          pop hl                        ; then uncomment this code.
                          jp Return.WithCustomError     ; Straight to the error handing exit routine
                        endif
pend

ErrorProcEsx            proc
                        if enabled ErrDebug
Stop:                     Border(2)
                          jr Stop
                        else
                          ld (Return.SetError), a       ; <SMC Write ld a, 0
                          jp Return.WithCustomError     ; Straight to the error handing exit routine
                        endif
pend

RestoreF8               proc
                        ld a, [Saved]SMC                ; This was saved here when we entered the dot command
                        and %1000 0000                  ; Mask out everything but the F8 enable bit
                        ld d, a
                        NextRegRead(Reg.Peripheral2)    ; Read the current value of Peripheral 2 register
                        and %0111 1111                  ; Clear the F8 enable bit
                        or d                            ; Mask back in the saved bit
                        nextreg Reg.Peripheral2, a      ; Save back to Peripheral 2 register
                        ret
pend

RestoreSpeed            proc
                        nextreg Reg.CPUSpeed,[Saved]SMC ; Restore speed to what it originally was at dot cmd entry
                        ret
pend

RestoreBanks            proc
                        push af
                        ld a, [Driver]$FF               ; Read the MMU bank that was previously in slot 7.
                        cp $FF                          ; If it was $FF then we never changed it,
                        jr z, Restore1                  ; so skip this part,
                        nextreg $57, a                  ; otherwise restore the original MMU bank to slot 7.
Restore1:               ld a, [Bank1]$FF                ; Read the MMU bank that was previously in slot 6.
                        call Deallocate8KBank           ; Ignore any error because we are doing best efforts to exit
                        ld a, [Slot6]$FF                ; If<>$FF this is what BASIC had here on entry.
                        cp $FF                          ; If it was $FF then we never changed it,
                        jr z, NoRestore                 ; so skip this part,
                        nextreg $56, a                  ; otherwise restore the original MMU bank to slot 6.
NoRestore:              pop af
                        ret
pend

Return                  proc                            ; This routine restores everything preserved at the start of
ToBasic:                                                ; the dot cmd, for success and errors, then returns to BASIC.
                        call RestoreSpeed               ; Restore original CPU speed
                        call RestoreF8                  ; Restore original F8 enable/disable state.
                        call RestoreBanks               ; Restore original banks
Stack:                  ld sp, [Stack1]SMC              ; Unwind stack to original point.
                        ld iy, [IY1]SMC                 ; Restore IY.
                        ld a, [SetError]0               ; <SMC Standard esxDOS error code gets patched here.
                        ei
                        ret                             ; Return to BASIC.
WithCustomError:
                        push hl
                        call RestoreSpeed               ; Restore original CPU speed
                        call RestoreF8                  ; Restore original F8 enable/disable state
                        call RestoreBanks               ; Restore original banks
                        xor a
                        scf                             ; Signal error, hl = custom error message
                        pop hl
                        jp Stack                        ; (NextZXOS is not currently displaying standard error messages,
pend                                                    ;  with a>0 and carry cleared, so we use a custom message.)

Wait5Frames             proc                            ; Convenience routines for different lengths of wait.
                        WaitFrames(5)                   ; Each frame is 1/50th of a second.
                        ret
pend

Wait30Frames            proc                            ; Convenience routines for different lengths of wait.
                        WaitFrames(30)                  ; Each frame is 1/50th of a second.
                        ret
pend

Wait80Frames            proc                            ; Convenience routines for different lengths of wait.
                        WaitFrames(80)                  ; Each frame is 1/50th of a second.
                        ret
pend

Wait100Frames           proc                            ; Convenience routines for different lengths of wait.
                        WaitFrames(100)                 ; Each frame is 1/50th of a second.
                        ret
pend

WaitFramesProc          proc
                        di
                        ld (SavedStack), sp             ; Save stack
                        ld sp, $8000                    ; Put stack in upper 48K so FRAMES gets updated (this is a
                        ei                              ; peculiarity of mode 1 interrupts inside dot commands).
Loop:                   halt                            ; Note that we already have a bank allocated by IDE_BANK
                        dec bc                          ; at $8000, so we're not corrupting BASIC by doing this.
                        ld a, b
                        or c
                        jr nz, Loop                     ; Wait for BC frames
                        di                              ; In this dot cmd interrupts are off unless waiting or printing
                        ld sp, [SavedStack]SMC          ; Restore stack
                        ret
pend

Allocate8KBank          proc
                        ld hl, $0001                    ; H = $00: rc_banktype_zx, L = $01: rc_bank_alloc
Internal:               exx
                        ld c, 7                         ; 16K Bank 7 required for most NextZXOS API calls
                        ld de, IDE_BANK                 ; M_P3DOS takes care of stack safety stack for us
                        Rst8(esxDOS.M_P3DOS)            ; Make NextZXOS API call through esxDOS API with M_P3DOS
                        ErrorIfNoCarry(Err.NoMem)       ; Fatal error, exits dot command
                        ld a, e                         ; Return in a more conveniently saveable register (A not E)
                        ret
pend

Deallocate8KBank        proc                            ; Takes bank to deallocate in A (not E) for convenience
                        cp $FF                          ; If value is $FF it means we never allocated the bank,
                        ret z                           ; so return with carry clear (error) if that is the case
                        ld e, a                         ; Now move bank to deallocate into E for the API call
                        ld hl, $0003                    ; H = $00: rc_banktype_zx, L = $03: rc_bank_free
                        jr Allocate8KBank.Internal      ; Rest of deallocate is the same as the allocate routine
pend

; ***************************************************************************
; * Parse an argument from the command tail                                 *
; ***************************************************************************
; Entry: HL=command tail
;        DE=destination for argument
; Exit:  Fc=0 if no argument
;        Fc=1: parsed argument has been copied to DE and null-terminated
;        HL=command tail after this argument
;        BC=length of argument
; NOTE: BC is validated to be 1..255; if not, it does not return but instead
;       exits via show_usage.
;
; Routine provided by Garry Lancaster, with thanks :) Original is here:
; https://gitlab.com/thesmog358/tbblue/blob/master/src/asm/dot_commands/defrag.asm#L599
GetSizedArgProc         proc
                        ld a, h
                        or l
                        ret z                           ; exit with Fc=0 if hl is $0000 (no args)
                        ld bc, 0                        ; initialise size to zero
Loop:                   ld a, (hl)
                        inc hl
                        and a
                        ret z                           ; exit with Fc=0 if $00
                        cp CR
                        ret z                           ; or if CR
                        cp ':'
                        ret z                           ; or if ':'
                        cp ' '
                        jr z, Loop                      ; skip any spaces
                        cp '"'
                        jr z, Quoted                    ; on for a quoted arg
Unquoted:               ld (de), a                      ; store next char into dest
                        inc de
                        inc c                           ; increment length
                        jr z, BadSize                   ; don't allow >255
                        ld  a, (hl)
                        and a
                        jr z, Complete                  ; finished if found $00
                        cp CR
                        jr z, Complete                  ; or CR
                        cp ':'
                        jr z, Complete                  ; or ':'
                        cp '"'
                        jr z, Complete                  ; or '"' indicating start of next arg
                        inc hl
                        cp ' '
                        jr nz, Unquoted                 ; continue until space
Complete:               xor a
                        ld (de), a                      ; terminate argument with NULL
                        ld a, b
                        or c
                        jr z, BadSize                   ; don't allow zero-length args
                        scf                             ; Fc=1, argument found
                        ret
Quoted:                 ld a, (hl)
                        and a
                        jr z, Complete                  ; finished if found $00
                        cp CR
                        jr z, Complete                  ; or CR
                        inc hl
                        cp '"'
                        jr z, Complete                  ; finished when next quote consumed
                        ld (de), a                      ; store next char into dest
                        inc de
                        inc c                           ; increment length
                        jr z, BadSize                   ; don't allow >255
                        jr Quoted
BadSize:                pop af                          ; discard return address
                        ErrorAlways(Err.ArgsBad)
pend

ParseHelp               proc
                        ret nc                          ; Return immediately if no arg found
                        push af
                        push bc
                        push hl
                        ld a, b
                        or c
                        cp 2
                        jr nz, Return
                        ld hl, ArgBuffer
                        ld a, (hl)
                        cp '-'
                        jr nz, Return
                        inc hl
                        ld a, (hl)
                        cp 'h'
                        jr nz, Return
                        ld a, 1
                        ld (WantsHelp), a
Return:                 pop hl
                        pop bc
                        pop af
                        ret
pend

/*
WaitKey                 proc                            ; Just a debugging routine that allows me to clear
                        Border(6)                       ; my serial logs at a certain point, before logging
                        ei                              ; the traffic I'm interested in debugging.
Loop1:                  xor a
                        in a, ($FE)
                        cpl
                        and 15
                        halt
                        jr nz, Loop1
Loop2:                  xor a
                        in a, ($FE)
                        cpl
                        and 15
                        halt
                        jr z, Loop2
                        Border(7)
                        di
                        ret
pend
*/

