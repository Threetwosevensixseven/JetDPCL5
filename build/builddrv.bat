:: Set current directory
::@echo off
C:
CD %~dp0

:: Write date, time and git version into asm file for next build
ZXVersion.exe

:: Arguments passed from Zeus or command line:
::   -c   Launch CSpect
set cspect=0
for %%a in (%*) do (
  if "%%a"=="-c" set cspect=1
) 

:: Launch CSpect if option was set
if %cspect% equ 0 goto NoCSpect
pskill.exe -t cspect.exe
hdfmonkey.exe put C:\spec\sd\cspect-next-2gb.img ..\bin\JetDPCL5.drv demos\JetDPCL5\JetDPCL5.drv
::hdfmonkey.exe put C:\spec\sd\cspect-next-2gb.img ..\bin\TestP.drv demos\JetDPCL5\TestP.drv
::hdfmonkey.exe put C:\spec\sd\cspect-next-2gb.img autoexec.bas nextzxos\autoexec.bas
cd C:\spec\CSpect2_15_01
CSpect.exe -w2 -zxnext -nextrom -basickeys -exit -brk -tv -com="COM3:2000000" -mmc=..\sd\cspect-next-2gb.img
:NoCSpect

pause
