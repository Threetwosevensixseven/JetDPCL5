; main.asm

optionsize 5
Cspect optionbool 15, -15, "Cspect", false              ; Zeus GUI option to launch CSpect

multipass 4

if (multipass == 0)
  include "JetDPCL5.asm"
elseif (multipass == 1)
  include "JetDPCL5.asm"
elseif (multipass == 2)
  include "JetDPCL5_drv.asm"
elseif (multipass == 3)
  BuildArgs = "";
  if enabled Cspect
    BuildArgs = BuildArgs + "-c "
  endif
  zeusinvoke "..\..\..\build\builddrv.bat " + BuildArgs, "", false ; Run batch file with args
endif

