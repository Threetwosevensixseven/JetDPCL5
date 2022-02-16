; JetDPCL5_drv.asm

zeusemulate             "Next", "RAW"                   ; RAW prevents Zeus from adding some BASIC emulator-friendly
zoLogicOperatorsHighPri = false                         ; data like the stack and system variables. Not needed because
zxAllowFloatingLabels   = false                         ; this only runs on the Next, and everything is already present.
//optionsize 5
//Cspect optionbool 15, -15, "Cspect", false              ; Zeus GUI option to launch CSpect

zxnextmap DriverDrvBank,-1,-1,-1,-1,-1,-1,-1            ; Assemble into Next RAM bank but displace back down to $0000
org $0000                                               ; $0000 is the entry point for API calls directed to the
                                                        ; printer driver.
Start:
                        defm "NDRV"                     ; .DRV file signature
                        defb "P"                        ; standard driver id for printer device.
                        defb RelocateCount              ; number of relocation entries (0..255)
                        defb 0                          ; number of 8K DivMMC RAM banks needed
                        defb 0                          ; number of 8K Spectrum RAM banks needed

import_bin  "..\..\..\bin\JetDPCL5.bin"                 ; The driver + relocation table should now be included.

include "constants.asm"
include "RelocateCount.asm", true

Length equ $-Start

output_bin "..\..\..\bin\JetDPCL5.drv", Start, Length

zeusassert RelocateCount<255, "Relocation table cannot have more than 255 entries!"

