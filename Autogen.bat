ECHO OFF
cls

cd /
cd Users\CIDA\Desktop\KiddieOS

setlocal enabledelayedexpansion

set QuantFile=7

set Drive=1

set file1=kernel
set file2=fwriter
set file3=window
set file4=fat16
set file5=shell16
set file6=wmanager
set file7=keyboard

set filebin1=Binary\%file1%.bin
set filebin2=Binary\%file2%.bin
set filebin3=Binary\%file3%.bin
set filebin4=Binary\%file4%.bin
set filebin5=Binary\%file5%.bin
set filebin6=Binary\%file6%.bin
set filebin7=Driver\%file7%.sys

set VHD=KiddieOS
set LibFile=Hardware\memory.lib
set ImageFile=DiskImage\%VHD%.vhd
set OffsetPartition=0
::set OffsetPartition=61173

del %ImageFile%


set /A nasm=0
set SizeSector=512

	set /p Choose="Do you want to reassemble the FAT16 and MBR?(S\N)"
	if %Choose% EQU S CALL :ReassembleFAT
	if %Choose% EQU s CALL :ReassembleFAT
	
	call ::SendFatToVHD
	
cecho {\n}

:Assembler
	set /a i=i+1
	set "NameVar=filebin%i%"
	set "NameVar1=file%i%"
	call set FileOut=%%%NameVar%%%
	call set MyFile=%%%NameVar1%%%
	cecho {0C}
	if NOT EXIST %MyFile%.asm goto NoExistFile 
	nasm -O0 -f bin %MyFile%.asm -o %FileOut%
	if %ERRORLEVEL% EQU 1 goto BugCode
	cecho {#}
	if %nasm% NEQ 1 (cecho {0B}"%MyFile%" file Mounted successfully!{\n}) else ( cecho {0B}.)
	if %i% NEQ %QuantFile% goto Assembler
	if %nasm% NEQ 0 GOTO:EOF
	
	set i=0
	set Sector=591
	set Segment=0x0800   rem Segmento do kernel
	set Boot=0x7C00      rem Offset do Inicial Bootloader
	set Kernel=0x0000    rem Offset Inicial Do Kernel
	call :AutoGenerator
	
:ReadFile
	set /a i=i+1
	set "NameVar=filebin%i%"
	set "NameVar1=file%i%"
	call set FileOut=%%%NameVar%%%
	call set MyFile=%%%NameVar1%%%
	
	for %%a in (dir "%FileOut%") do set size=%%~za
	cecho {0A}Processing '%MyFile%'

	set /A Counter=1
	set /A NumSectors=1

	for /l %%g in (1, 1, %size%) do (

		if !Counter! == 512 ( 
			set /A Counter=1
			set /A NumSectors+=1
			cecho {0A}.
		)
		set /A Counter=Counter+1
	)

set /A "W=0"
	echo.
	
	if %i% == 1 set /A StartAddr=Kernel
	if %i% GEQ 2 set /A StartAddr=FinalAddr+2
	set /A FinalAddr=StartAddr+size
	call :ToHex
	call :WriteDefLib
	
	cecho {0F} SIZE BYTES     = {0D}%size%{#}{\n}
	cecho {0F} INIT SECTOR    = {0D}%Sector%{#}{\n}
	cecho {0F} QUANT. SECTORS = {0D}%NumSectors%{#}{\n}
	cecho {0F} START ADDRESS  = {0D}%StartAddr%{#}{\n}
	cecho {0F} FINAL ADDRESS  = {0D}%FinalAddr%{#}{\n}
	
	set /A Sector+=NumSectors
	
	if %i% NEQ %QuantFile% goto ReadFile
	
	call :WriteEndDef
	call :ReAssembler
	call :VHDCreate
	call :BootFlashDrive
	
	cecho {\n}
	echo Which virtual machine do you want to run?
	echo.
	echo 1. KiddieOSUSB
	echo 2. KiddieOSVHD
	echo 0. Nothing
	echo.
	set /p Choose=
	if %Choose% EQU 1 "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm  --putenv VBOX_GUI_DBG_ENABLED=true KiddieOSUSB
	if %Choose% EQU 2 "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm  --putenv VBOX_GUI_DBG_ENABLED=true KiddieOSVHD
	
	cecho {\n}
	goto END
	
:ToHex
set "hex="
set "map=0123456789ABCDEF"
for /L %%N in (1,1,4) do (
   set /a "d=StartAddr&15,StartAddr>>=4"
   for /f %%D in ("!d!") do (
      set "hex=!map:~%%D,1!!hex!"
   )
)
set "StartAddr=0x%hex%"
set "hex="
for /L %%N in (1,1,4) do (
   set /a "d=FinalAddr&15,FinalAddr>>=4"
   for /f %%D in ("!d!") do (
      set "hex=!map:~%%D,1!!hex!"
   )
)
set "FinalAddr=0x%hex%"
GOTO:EOF

:BugCode
	echo.
	echo Fix the Error in the file!
	cecho {0F}
	echo.
	pause
	goto END
	
:NoExistFile
	echo.
	echo The '%MyFile%.asm' File not exist!
	cecho {0F}
	echo.
	pause
	goto END
	
:AutoGenerator
	echo ; =============================================== > %LibFile%
	echo ; AUTO GENERATED FILE - NOT CHANGE! >> %LibFile%
	echo ; >> %LibFile%
	echo ; KiddieOS - Memory Library Routines >> %LibFile%
	echo ; Created by Autogen >> %LibFile%
	echo ; Version 1.0.0 >> %LibFile%
	echo ; =============================================== >> %LibFile%
	echo. >> %LibFile%
	echo %%IFNDEF _MEMORY_LIB_ >> %LibFile%
	echo %%DEFINE _MEMORY_LIB_ >> %LibFile%
	echo. >> %LibFile%
	echo %%DEFINE SYSTEM 16 >> %LibFile%
	echo. >> %LibFile%
	GOTO:EOF
	
:WriteDefLib
	CALL :UpCase MyFile
	echo %%DEFINE !MyFile!             !StartAddr! >> %LibFile%
	echo %%DEFINE !MyFile!_SECTOR      !Sector! >> %LibFile%
	echo %%DEFINE !MyFile!_NUM_SECTORS !NumSectors! >> %LibFile%
	GOTO:EOF
	
:WriteEndDef
	echo. >> %LibFile%
	echo %%ENDIF >> %LibFile%
	echo. >> %LibFile%
	cecho {\n}New "%LibFile%" LIB File Generated{\n}
	GOTO:EOF
		
:UpCase
SET %~1=!%~1:a=A!
SET %~1=!%~1:b=B!
SET %~1=!%~1:c=C!
SET %~1=!%~1:d=D!
SET %~1=!%~1:e=E!
SET %~1=!%~1:f=F!
SET %~1=!%~1:g=G!
SET %~1=!%~1:h=H!
SET %~1=!%~1:i=I!
SET %~1=!%~1:j=J!
SET %~1=!%~1:k=K!
SET %~1=!%~1:l=L!
SET %~1=!%~1:m=M!
SET %~1=!%~1:n=N!
SET %~1=!%~1:o=O!
SET %~1=!%~1:p=P!
SET %~1=!%~1:q=Q!
SET %~1=!%~1:r=R!
SET %~1=!%~1:s=S!
SET %~1=!%~1:t=T!
SET %~1=!%~1:u=U!
SET %~1=!%~1:v=V!
SET %~1=!%~1:w=W!
SET %~1=!%~1:x=X!
SET %~1=!%~1:y=Y!
SET %~1=!%~1:z=Z!
GOTO:EOF

:ReAssembler
	set i=0
	set /A nasm=1
	echo.
	cecho {0B}Remounting Binary Files.
	call :Assembler
	cecho {\n}
	cecho {0A}%i% Binary Files remounted successfully{\n\n}
	cecho {0F}
	GOTO:EOF

:VHDCreate	
	cecho {0A}Mounting VHD file...{\n}
	cecho {0B}
	imdisk -a -f %ImageFile% -s 32769K -m B:
	set i=0
	:Creating
		set /a i=i+1
		set "Var1=filebin%i%"
		set "Var3=file%i%"
		call set BinFile=%%%Var1%%%
		call set Bin=%%%Var3%%%
		
		cecho {0B}Adding '%Bin%' to the VHD file{\n}
		copy %BinFile% B:
		
		if %i% NEQ %QuantFile% goto Creating

		xcopy /S /E KiddieOS B:\KiddieOS
		
		cecho {0A}Dismounting VHD file...{\n}
		cecho {0B}
		imdisk -D -m B:
		
		cecho {0A}{\n}The '%VHD%.vhd' was created successfully!{\n\n}
GOTO:EOF

:ReassembleFAT
cecho {0B} Assembling FAT16 and MBR...{\n}
nasm -O0 -f bin -o Binary\bootmbr.bin bootmbr.asm
nasm -O0 -f bin -o Binary\bootvbr.bin bootvbr.asm
nasm -O0 -f bin -o FAT.bin FAT.asm
nasm -O0 -f bin -o Binary\footervhd.bin footervhd.asm
GOTO:EOF

:SendFatToVHD
cecho {0B}Sending FAT16 and MBR into VHD...{\n}
dd count=2 seek=0 bs=512 if=Binary\bootmbr.bin of=%ImageFile%
dd count=2 seek=63 bs=512 if=Binary\bootvbr.bin of=%ImageFile%
dd count=2 seek=67 bs=512 if=FAT.bin of=%ImageFile%
dd count=2 seek=65537 bs=512 if=Binary\footervhd.bin of=%ImageFile%
cecho {0A}Done!{\n}

cls
GOTO:EOF
	

:BootFlashDrive
	
	cecho {0B}Writing system in Disk (Drive %Drive%) ...{\n}
	rmpartusb drive=%Drive% filetousb file="%ImageFile%" filestart=0 length=33.558.528 usbstart=%OffsetPartition%
	cecho {0A}The System was written successfully{\n\n}
	cecho {0F}
GOTO:EOF

:END
	