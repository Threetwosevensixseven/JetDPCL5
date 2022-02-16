; macros.asm

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
