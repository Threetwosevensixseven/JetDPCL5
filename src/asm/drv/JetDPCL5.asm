; JetDPCL5.asm

zeusemulate             "Next", "RAW"                   ; RAW prevents Zeus from adding some BASIC emulator-friendly
zoLogicOperatorsHighPri = false                         ; data like the stack and system variables. Not needed because
zxAllowFloatingLabels   = false                         ; this only runs on the Next, and everything is already present.
//optionsize 5
//Cspect optionbool 15, -15, "Cspect", false              ; Zeus GUI option to launch CSpect

zxnextmap DriverBank,-1,-1,-1,-1,-1,-1,-1               ; Assemble into Next RAM bank but displace back down to $0000
org $0000                                               ; $0000 is the entry point for API calls directed to the
ApiEntry:               jr EntryStart                   ; printer driver.
                        db "JetDPCL5v1."                ; Put a signature and version in the file in case we ever
                        BuildNo()                       ; need to detect it programmatically
                        db 0
EntryStart:             ld a, b                         ; On entry, B=call id with HL,DE other parameters.
                        cp $fb                          ; A standard printer driver that supports NextBASIC and CP/M
                        jr z, output_char               ; only needs to provide 2 standard calls:
                        cp $f7                          ;   B=$f7: return output status
                        jr z, return_status             ;   B=$fb: output character
                        cp $01                          ; Test command 1
                        jr z, OpenESPConnection
ApiError:
                        xor a                           ; A=0, unsupported call id
                        scf                             ; Fc=1, signals error
                        ret
return_status:
                        ld bc, $ffff                    ; Set bc to $ffff to indicate success
                        and a                           ; clear carry to indicate success
                        ret                             ; exit with BC=$0000 and carry set if bust
output_char:
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
                        and a                           ; clear carry to indicate success
                        ret

OpenESPConnection       proc
                        ld hl, [RE_Ok]Commands.OK
                        //ld hl, [RE_Test]$0000
                        CSBreak()
                        //ESPSend("AT")
                        //call ESPReceiveWaitOK
                        ret
pend

Commands                proc
  OK:                   db "OK", CR, LF, 0
pend

if ($>512)
  zeuserror "Driver code exceeds 512 bytes!"
else
  defs 512-$
endif

; Each relocation is the offset of the high byte of an address to be relocated.
; This particular driver is so simple it doesn't contain any absolute addresses
; needing to be relocated. (border.asm is a slightly more complex driver that
; does have a relocation table).
reloc_start:
include "RelocateTable.asm", true
reloc_end:

include "constants.asm"
include "macros.asm"
include "version.asm", true

Start equ ApiEntry
Length equ $-ApiEntry
zeusprint "Generating ", (reloc_end-reloc_start)/2, "relocation symbols"
export_sym "..\..\..\bin\JetDPCL5.sym", %11111111111 00
zeusinvoke "..\..\..\build\ZXRelocate.bat"
output_bin "..\..\..\bin\JetDPCL5.bin", Start, Length


