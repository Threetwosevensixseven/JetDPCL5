; JetDPCL5_drv.asm

zeusemulate             "Next", "RAW"                   ; RAW prevents Zeus from adding some BASIC emulator-friendly
zoLogicOperatorsHighPri = false                         ; data like the stack and system variables. Not needed because
zxAllowFloatingLabels   = false                         ; this only runs on the Next, and everything is already present.

include "constants.asm"
include "RelocateCount.asm", true
zeusassert RelocateCount<255, "Relocation table cannot have more than 255 entries!"

zxnextmap DriverDrvBank,-1,-1,-1,-1,-1,-1,-1            ; Displace into Zeus MMU bank 31
org $0000                                               ; but assemble as if at $0000.

Start:
                        defm "NDRV"                     ; .DRV file signature
                        defb 'P'+$80                    ; standard driver id for printer device with IM1 ISR
                        defb RelocateCount              ; number of relocation entries (0..255)
                        defb 0                          ; number of 8K DivMMC RAM banks needed
                        defb 2                          ; number of 8K Spectrum RAM banks needed

import_bin  "..\..\..\bin\JetDPCL5.bin"                 ; The driver + relocation table should now be included.

;       First, for each mmcbank requested:
;
;       defb    bnk_patches     ; number of driver patches for this bank id
;       defw    bnk_size        ; size of data to pre-load into bank (0..8192)
;                               ; (remaining space will be erased to zeroes)
;       defs    bnk_size        ; data to pre-load into bank
;       defs    bnk_patches*2   ; for each patch, a 2-byte offset (0..511) in
;                               ; the 512-byte driver to write the bank id to
;       NOTE: The first patch for each mmcbank should never be changed by your
;             driver code, as .uninstall will use the value for deallocating.

; There are no mmcbanks

;       Then, for each zxbank requested:
;
;       defb    bnk_patches     ; number of driver patches for this bank id
;       defw    bnk_size        ; size of data to pre-load into bank (0..8192)
;                               ; (remaining space will be erased to zeroes)
;       defs    bnk_size        ; data to pre-load into bank
;       defs    bnk_patches*2   ; for each patch, a 2-byte offset (0..511) in
;                               ; the 512-byte driver to write the bank id to
;       NOTE: The first patch for each zxbank should never be changed by your
;             driver code, as .uninstall will use the value for deallocating.

; ZX BANK 0
db 1                                                    ; One bank ID patch
dw ZX0_Length                                           ; Length of ZX bank 0
ZX0_Start:
import_bin "..\..\..\bin\ZXBank0.bin"
ZX0_Length equ $-ZX0_Start
dw BA_ZX0                                               ; The single bank ID patch address

; ZX BANK 1
db 1                                                    ; One bank ID patch
dw ZX1_Length                                           ; Length of ZX bank 1
ZX1_Start:                                              ; This bank is a buffer. No static contents.
ZX1_Length equ $-ZX1_Start
dw BA_ZX1                                               ; The single bank ID patch address

Length equ $-Start

output_bin "..\..\..\bin\JetDPCL5.drv", Start, Length

