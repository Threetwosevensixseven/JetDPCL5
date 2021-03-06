; vars.asm

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

; Application
SavedArgs:              dw 0
SavedArgsLen            dw 0
SavedStackPrint:        dw $0000
SavedIYPrint:           dw $0000
IsNext:                 ds 0
ArgBuffer:              ds 256
WantsHelp:              ds 1

; UART
Prescaler:              ds 3

Files                   proc
  MainCfg:              db "c:/sys/JetDPCL5.cfg", 0
pend

Keys                    proc
  Printers:             db "Printers", 0
  Name:                 db "Name", 0
  Address:              db "Address", 0
pend

