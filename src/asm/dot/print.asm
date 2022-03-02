; msg.asm

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

Msg                     proc
  Startup:              db "JetDPCL5 v1.", BuildNoValue, CR
                        db Copyright, " 2022 Robin Verhagen-Guest", CR, CR, 0
  EOL:                  db CR, 0
  Driver:               db "Checking driver...", CR, 0
  Getting:              db "Reading printers...", CR, 0
  Flushing:             db "Flushing UART...", CR, 0
  Resetting:            db "Resetting ESP...", CR, 0
  Done:                 db "ESP successfully reset!", CR, 0
  Help:                 db "Reset ESP8266-01 WiFi module on the Spectrum Next", CR, CR
                        db "espreset [-h]", CR
                        db "Reset ESP without resetting the Next.", CR
                        db "Similar to powering the ESP off and on, or to issuing an AT+RST command.", CR, CR
                        db "OPTIONS", CR, CR
                        db "  -h", CR
                        db "  Display this help", CR, CR
                        db "JetDPCL5 v1.", BuildNoValue, CR
                        db BuildDateValue, " ", BuildTimeSecsValue, CR
                        db Copyright, " 2022 Robin Verhagen-Guest", CR, 0
pend

Err                     proc
                        ;  "<-Longest valid erro>", 'r'|128
  Break:                db "D BREAK - CONT repeat", 's'|128
  NoMem:                db "4 Out of memor",        'y'|128
  NotNext:              db "Spectrum Next require", 'd'|128
  //NotOS:                db "NextZXOS require",      'd'|128
  CoreMin:              db "Core 3.00.07 require",  'd'|128
  ArgsTooBig:           db "Arguments too lon",     'g'|128
  ArgsBad:              db "Invalid Argument",      's'|128

  NoDriver:             db "Driver not installe",   'd'|128


  //NotNB:                db "NextBASIC require",     'd'|128
  NoSync:               db "Sync error or no ES",   'P'|128
  UnknownOUI:           db "Unknown OUI erro",      'r'|128
  BadDot:               db "Error reading dot cm",  'd'|128
  StubUpload:           db "Error uploading stu",   'b'|128
  StubRun:              db "Failed to start stu",   'b'|128
  FlashSet:             db "Flash param error ",    '1'|128
  FlashUpd:             db "Flash param error ",    '2'|128
  ReadFW:               db "Error reading firmwar", 'e'|128
  FWMissing:            db "Firmware missin",       'g'|128
  FWNeeded:             db "Firmware neede",        'd'|128
  NotFW:                db "Not a firmware fil",    'e'|128
  BadFW:                db "Firmware is bad forma", 't'|128
  BaudChg:              db "Error changing bau",    'd'|128
  FlashUp:              db "Error writing flas",    'h'|128
  BadMd5:               db "MD5 hash failur",       'e'|128
  Finalize:             db "Error finalizing writ", 'e'|128
  ExitWrite:            db "Error exiting writ",    'e'|128
pend

PrintRst16              proc
                        SafePrintStart()
                        if DisableScroll
                          ld a, 24                      ; Set upper screen to not scroll
                          ld (SCR_CT), a                ; for another 24 rows of printing
                        endif
                        ei
Loop:                   ld a, (hl)
                        inc hl
                        or a
                        jp z, Return
                        rst 16
                        jr Loop
Return:                 SafePrintEnd()
                        ret
pend

PrintRst16Error         proc
                        SafePrintStart()
Loop:                   ld a, (hl)
                        ld b, a
                        and %1 0000000
                        ld a, b
                        jp nz, LastChar
                        inc hl
                        rst 16
                        jr Loop
Return:                 jp PrintRst16.Return
LastChar                and %0 1111111
                        rst 16
                        ld a, CR                        ; The error message doesn't include a trailing CR in the
                        rst 16                          ; definition, so we want to add one when we print it
                        jr Return                       ; in the upper screen.
pend

PrintCharUnsafe         proc
                        ld b, a
                        ld a, 24                      ; Set upper screen to not scroll
                        ld (SCR_CT), a                ; for another 24 rows of printing
                        ld a, b
                        cp 13
                        jr z, Printable
                        cp 32
                        ret c
                        cp 127
                        ret nc
Printable:              rst 16
                        ret
pend

