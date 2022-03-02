; JetDPCL5.asm

zeusemulate             "Next", "RAW"                   ; RAW prevents Zeus from adding some BASIC emulator-friendly
zoLogicOperatorsHighPri = false                         ; data like the stack and system variables. Not needed because
zxAllowFloatingLabels   = false                         ; this runs on the Next and we are assembling to divMMC RAM.

zxnextmap DriverBank,-1,-1,-1,-1,-1,-1,-1               ; Displace driver into Zeus MMU bank 30, assemble at $0000.
org $0000
ApiEntry:               jr EntryStart                   ; $0000 is the entry point for API calls directed to the
                        nop                             ; printer driver.
IsrEntry:               ret                             ; IM1 ISR must be at $0003.
                        db IsrStart-IsrEntry-2          ; This is the relative offset for "jr IsrStart".
                        db "JetDPCL5v1."                ; Put a signature and version in the file in case we ever
                        BuildNo()                       ; need to detect it programmatically.
                        db 0
IsrStart:               jp [RE_ISR0] IM1ISR             ; Jump to the real IR1 ISR routine.
EntryStart:             ld a, b                         ; On entry, B=call id with HL,DE other parameters.
                        cp $fb                          ; A standard printer driver that supports NextBASIC and CP/M
                        jr z, OutputChar                ; only needs to provide 2 standard calls:
                        cp $f7                          ;   B=$f7: return output status;
                        jr z, ReturnStatus              ;   B=$fb: output character.
                        cp $7f
                        jr z, ReturnZXBank1
ApiError:
                        xor a                           ; A=0, unsupported call id.
                        scf                             ; FC=1, signals error.
                        ret
ReturnStatus:
                        ld bc, $ffff                    ; Set BC to $ffff to indicate success.
                        and a                           ; Clear carry to indicate success.
                        ret                             ; Exit with BC=$0000 and carry set if bust
OutputChar:
                        push de                         ; Character to print is in E, save it.
                        ld hl, [RE_IsOpen1]ConnIsOpen
                        ld a, (hl)
                        or a                            ; If connection is closed, open it now.
                        call z, [RE_Open1]OpenESPConnectionFar
                        pop de                          ; Restore char to print in E.
                        ld a, $7f                       ; It's good practice to allow the user to abort with BREAK
                        in a,($fe)                      ; if the printer is stuck in a busy loop.
                        rra
                        jr c, BufferChar                ; Carry on if SPACE not pressed.
                        ld a, $fe
                        in a, ($fe)
                        rra
                        jr c, BufferChar                ; Carry on if CAPS SHIFT not pressed.
                        ld a, $fe                       ; Otherwise exit with A=$fe and carry set,
                        scf                             ; so "End of file" os reported.
                        ret
BufferChar:
                        ld c, (printer_port)
                        out (c), e                      ; Copy char to be printed as a border colour,
                        call [RE_Page2a]PageZXBanks     ; Set up the ZX banks.
                        call CopyCharToBuffer           ; The "print" routine is in ZX bank 0 (slot 4).
                        call [RE_Page2b]RestoreZXBanks  ; Restore the original banks.
                        and a                           ; Clear carry to indicate success.
                        ret

NextRegReadProc         proc                            ; Entry: A = nextreg to read.
                        ld bc, Port.NextReg             ; Destroys BC.
                        out (c), a
                        inc b
                        in a, (c)                       ; Returns: A = value of nextreg.
                        ret
pend

ReturnZXBank1           proc
                        ld a, ([RE_ZX1]BA_ZX1)
                        ld c, a                         ; BC = 1st DRIVER TO value
                        ld de, 'J'*256+'e'              ; DE = 2nd DRIVER TO value
                        ld hl, 't'*256+'D'              ; HL = 3rd DRIVER TO value, DEHL = "JetD" magic signature
                        or a                            ; Clear carry to indicate success
                        ret
pend

PageZXBanks             proc
                        NextRegRead($54)                ; Read current value of slot 4.
                        ld ([RE_RestoreAddr0]RestoreZXBanks.Restore0), a ; Save current value of slot 4.
                        ld a, ([RE_RestoreBank0]BA_ZX0)
                        nextreg $54, a                  ; Set slot 4 to ZX bank 0.
                        NextRegRead($57)                ; Read current value of slot 7.
                        ld ([RE_RestoreAddr1]RestoreZXBanks.Restore1), a ; Save current value of slot 7.
                        ld a, ([RE_RestoreBank1]BA_ZX1)
                        nextreg $57, a                  ; Set slot 4 to ZX bank 1.
                        ret
pend


RestoreZXBanks          proc
                        ld a, [Restore0]SMC
                        nextreg $54, a                  ; Restore previous value of slot 4.
                        ld a, [Restore1]SMC
                        nextreg $57, a                  ; Restore previous value of slot 7.
                        ret
pend

BA_ZX0:                 db 0                            ; This is the dynamically allocated bank number for ZX bank 0.
BA_ZX1:                 db 0                            ; This is the dynamically allocated bank number for ZX bank 1.

OpenESPConnectionFar    proc
                        call [RE_Page3a]PageZXBanks     ; Page in ZX banks.
                        call OpenESPConnection          ; This routine is in ZX bank 0 (slot 4).
                        call [RE_Page3b]RestoreZXBanks  ; Restore original banks.
                        and a                           ; Return success.
                        ret
pend

ConnIsOpen:             db 0                            ; 0=closed, 1=open. Read and written by code in ZX bank 0.

CloseESPConnectionFar   proc
                        call [RE_Page4a]PageZXBanks     ; Page in ZX banks.
                        ld hl, [RE_IsOpen2]ConnIsOpen   ; Load input parameter to avoid relocation issues.
                        call CloseESPConnection         ; This routine is in ZX bank 0 (slot 4).
                        call [RE_Page4b]RestoreZXBanks  ; Restore original banks.
                        and a                           ; Return success.
                        ret
pend

IM1ISR                  proc                            ; Doesn't get called unless there are pending chars to print.
                        ld hl, [StopAtFrame]SMC         ; Target value of FRAMES when we want to send the print job.
                        ld de, (FRAMES)                 ; The current FRAMES value.
                        CpHL(de)                        ; If current value < target value
                        ret nc                          ; then exit ISR now,
                        jr CloseESPConnectionFar        ; otherwise send remaining buffer to ESP, close connection,
pend                                                    ; and disable this ISR until next char is printed.

if ($>512)
  zeuserror "Driver code exceeds 512 bytes!"
else
  zeusprint "Driver size=", $
  defs 512-$
endif

; Each relocation is the offset of the high byte of an address to be relocated.
reloc_start:
include "RelocateTable.asm", true
reloc_end:

include "constants.asm"
include "macros.asm"
include "version.asm", true

Start equ ApiEntry
Length equ $-ApiEntry
zeusprint "Generating ", (reloc_end-reloc_start)/2, "relocation table entries"
export_sym "..\..\..\tmp\JetDPCL5.sym", %11111111111 00
zeusinvoke "..\..\..\build\ZXRelocate.bat"
output_bin "..\..\..\tmp\JetDPCL5.bin", Start, Length

include "zxbank0.asm"


