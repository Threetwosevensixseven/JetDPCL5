; constants.asm

DriverBank              equ 30
DriverDrvBank           equ 31
ZXBank0                 equ 32
printer_port            equ $fe
relocs                  equ 0
ULA_PORT                equ $fe
SMC                     equ 0
BufferAddr              equ $E000
BufferSize              equ $1FFF
BufferEnd               equ BufferAddr+BufferSize
PrinterTest             equ 1
if PrinterTest=1
  PrinterIP             equ "192.168.1.7"
  PrinterPort            equ "9100"
else
  PrinterIP             equ "192.168.1.29"
  PrinterPort           equ "9100"
endif


; Ports
Port                    proc
  NextReg               equ $243B
pend

; Registers
Reg                     proc
  MachineID             equ $00
  CoreMSB               equ $01
  CPUSpeed              equ $07
  CoreLSB               equ $0E
  VideoTiming           equ $11
pend

; UART
UART_RxD                equ $143B                       ; Also used to set the baudrate
UART_TxD                equ $133B                       ; Also reads status
UART_Sel                equ $153B                       ; Selects between ESP and Pi, and sets upper 3 bits of baud
UART_SetBaud            equ UART_RxD                    ; Sets baudrate
UART_GetStatus          equ UART_TxD                    ; Reads status bits
UART_mRX_DATA_READY     equ %xxxxx 0 0 1                ; Status bit masks
UART_mTX_BUSY           equ %xxxxx 0 1 0                ; Status bit masks
UART_mRX_FIFO_FULL      equ %xxxxx 1 0 0                ; Status bit masks
ESPTimeout              equ 65535*4;65535               ; Use 10000 for 3.5MHz, but 28NHz needs to be 65535
ESPTimeout2             equ 10000                       ; Use 10000 for 3.5MHz, but 28NHz needs to be 65535

; Chars
SMC                     equ 0
CR                      equ 13
LF                      equ 10
Space                   equ 32
Copyright               equ 127

