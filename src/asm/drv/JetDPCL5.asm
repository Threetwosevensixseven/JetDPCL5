; JetDPCL5.asm

zeusemulate             "Next", "RAW"                   ; RAW prevents Zeus from adding some BASIC emulator-friendly
zoLogicOperatorsHighPri = false                         ; data like the stack and system variables. Not needed because
zxAllowFloatingLabels   = false                         ; this only runs on the Next, and everything is already present.

zxnextmap DriverBank,-1,-1,-1,-1,-1,-1,-1          ; Displace driver into Zeus MMU bank 30, assemble at $0000.
org $0000                                               ; Displace ZX0 bank into Zeus MMU bank 32, assemble at $8000.
ApiEntry:               jr EntryStart                   ; $0000 is the entry point for API calls directed to the
                        nop                             ; printer driver.
IsrEntry:               jr IsrStart                     ; IM1 ISR must be at $0003.
                        db "JetDPCL5v1."                ; Put a signature and version in the file in case we ever
                        BuildNo()                       ; need to detect it programmatically.
                        db 0
IsrStart:               ret                             ; Replace with routine that counts FRAMES and closes TCP socket
EntryStart:             ld a, b                         ; On entry, B=call id with HL,DE other parameters.
                        cp $fb                          ; A standard printer driver that supports NextBASIC and CP/M
                        jr z, output_char               ; only needs to provide 2 standard calls:
                        cp $f7                          ;   B=$f7: return output status
                        jr z, return_status             ;   B=$fb: output character
                        cp $01                          ; Test command 1
                        jr z, OpenESPConnectionFar
                        cp $02
                        jr z, CloseESPConnectionFar
ApiError:
                        xor a                           ; A=0, unsupported call id
                        scf                             ; Fc=1, signals error
                        ret
return_status:
                        ld bc, $ffff                    ; Set bc to $ffff to indicate success
                        and a                           ; clear carry to indicate success
                        ret                             ; exit with BC=$0000 and carry set if bust
output_char:
                        push de
                        ld hl, [RE_IsOpen1]ConnIsOpen
                        ld a, (hl)
                        or a
                        call z, [RE_Open1]OpenESPConnectionFar
                        pop de
                        ld a, $7f                       ; It's good practice to allow the user to abort with BREAK
                        in a,($fe)                      ; if the printer is stuck in a busy loop.
                        rra
                        jr c, check_printer             ; on if SPACE not pressed
                        ld a, $fe
                        in a, ($fe)
                        rra
                        jr c, check_printer             ; on if CAPS SHIFT not pressed
                        ld a, $fe                       ; exit with A=$fe and carry set
                        scf                             ; so "End of file" reported
                        ret
check_printer:                                          ; Wait for the printer to become ready.
                        ld c, (printer_port)
                        out (c), e
                        call [RE_Page2a]PageZXBanks
                        call PrintESPCharToBuffer
                        call [RE_Page2b]RestoreZXBanks
                        and a                           ; clear carry to indicate success
                        ret

NextRegReadProc         proc
                        ld bc, Port.NextReg
                        out (c), a
                        inc b
                        in a, (c)
                        ret
pend

PageZXBanks             proc
                        NextRegRead($54)
                        ld ([RE_RestoreAddr0]RestoreZXBanks.Restore0), a
                        ld a, ([RE_RestoreBank0]BA_ZX0)
                        nextreg $54, a
                        NextRegRead($57)
                        ld ([RE_RestoreAddr1]RestoreZXBanks.Restore1), a
                        ld a, ([RE_RestoreBank1]BA_ZX1)
                        nextreg $57, a
                        ret
pend


RestoreZXBanks          proc
                        ld a, [Restore0]SMC
                        nextreg $54, a
                        ld a, [Restore1]SMC
                        nextreg $57, a
                        ret
pend

BA_ZX0:                 db 0
BA_ZX1:                 db 0

OpenESPConnectionFar    proc
                        call [RE_Page3a]PageZXBanks
                        call OpenESPConnection
                        call [RE_Page3b]RestoreZXBanks
                        and a                                   ; Return success
                        ret
pend

ConnIsOpen:             db 0

CloseESPConnectionFar   proc
                        call [RE_Page4a]PageZXBanks
                        ld hl, [RE_IsOpen2]ConnIsOpen
                        call CloseESPConnection
                        call [RE_Page4b]RestoreZXBanks
                        and a                                   ; Return success
                        ret
pend

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
export_sym "..\..\..\bin\JetDPCL5.sym", %11111111111 00
zeusinvoke "..\..\..\build\ZXRelocate.bat"
output_bin "..\..\..\bin\JetDPCL5.bin", Start, Length

include "zxbank0.asm"


