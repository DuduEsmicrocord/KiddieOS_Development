%INCLUDE "Hardware/memory.lib"
%INCLUDE "Hardware/info.lib"
[BITS SYSTEM]
[ORG KERNEL]

	
OS_VECTOR_JMP:
	jmp OSMain                ; 0000h (called by VBR)
	jmp PrintNameFile         ; 0003h
	jmp Print_Hexa_Value16    ; 0006h
	jmp Print_String          ; 0009h
	jmp Break_Line            ; 000Ch
	jmp Create_Panel          ; 000Fh
	jmp Clear_Screen          ; 0012h
	jmp Move_Cursor			  ; 0015h
	jmp Get_Cursor            ; 0018h
	jmp Show_Cursor			  ; 001Bh
	jmp Hide_Cursor			  ; 001Eh
	jmp Kernel_Menu			  ; 0021h
	jmp Write_Info			  ; 0024h
	jmp PrintNameFile         ; 0027h
	jmp WMANAGER_INIT         ; 002Ah
	jmp Print_Hexa_Value8     ; 002Dh
	jmp Play_Speaker_Tone     ; 0030h
	jmp Print_Dec_Value32     ; 0033h
	jmp Print_Hexa_Value32 	  ; 0036h
	jmp Print_Fat_Date 		  ; 0039h
	jmp Print_Fat_Time		  ; 003Ch
	jmp Calloc                ; 003Fh
	jmp Free                  ; 0042h
	jmp Parse_Dec_Value		  ; 0045h
	jmp END                   ; 0048h
	
; --------------------------------------------------
; Saltos para serem chamados por CALL FAR
; Por programas em outros segmentos, Ex.: DOS
	jmp syscall.prog			; 004Bh
	jmp winmng.video			; 004Eh
	jmp shell.cmd				; 0051h
	jmp tone.play 				; 0054h
	
syscall.prog: 	call SYSCMNG
				retf
winmng.video:	call WINMNG+3
				retf
shell.cmd:		call SHELL16+3
				retf
tone.play:		call Play_Speaker_Tone
				retf
; --------------------------------------------------

; _____________________________________________
; Directives and Inclusions ___________________

Vector:
	dw 	NameSystem
SIZE EQU ($ - Vector) / 2

%INCLUDE "Hardware/monitor.lib"
%INCLUDE "Hardware/disk.lib"
%INCLUDE "Hardware/keyboard.lib"
%INCLUDE "Hardware/fontswriter.lib"
%INCLUDE "Hardware/win16.lib"
%INCLUDE "Hardware/speaker.lib"

	
NameSystem db "KiddieOS",0

VetorHexa  db "0123456789ABCDEF",0
VetorCharsLower db "abcdefghijklmnopqrstuvwxyz",0
VetorCharsUpper db "ABCDEFGHIJKLMNOPQRSTUVWXYZ",0

VetorDec 	db "0123456789",0
Zero 		db 0

Extension  db "DRV"

PressKey   db "Press any key to continue...",0

; _____________________________________________

%DEFINE DRIVERS_OFFSET  	  KEYBOARD
%DEFINE FAT16.LoadAllFiles    FAT16
%DEFINE FAT16.LoadFatVbrData  FAT16+15
%DEFINE FAT16.OpenThisFile 	  FAT16+24
%DEFINE FAT16.LoadFile 		  FAT16+27
%DEFINE FAT16.SetSeek 		  FAT16+30
%DEFINE FAT16.CloseFile 	  FAT16+33
%DEFINE MEMX86.Detect_Low_Memory 	MEMX86+0
%DEFINE KEYBOARD.Initialize 		KEYBOARD+0
%DEFINE KEYBOARD.Enable_Scancode 	KEYBOARD+3
%DEFINE KEYBOARD.Disable_Scancode 	KEYBOARD+6
%DEFINE KEYBOARD.Set_Default_Parameters 	KEYBOARD+9

%DEFINE PCI.Init_PCI 	PCI

SHELL.Format_Command_Line EQU (SHELL16+6)
SHELL.PrintData 	 EQU 	(SHELL16+9)
SHELL.Copy_Buffers 	 EQU 	(SHELL16+12)
SHELL.Load_File_Path EQU 	(SHELL16+15)
SHELL.Store_Dir 	 EQU 	(SHELL16+18)
SHELL.Restore_Dir 	 EQU 	(SHELL16+21)

SHELL.CounterFName   EQU	(SHELL16+24)
SHELL.IsCommand 	 EQU	(SHELL16+27)
SHELL.CD_SEGMENT	 EQU	(SHELL16+28)

SHELL.DOS_HEADER_BYTES EQU  (SHELL16+30)
SHELL.BufferAux 	EQU 	(SHELL16+32)
SHELL.BufferAux2 	EQU 	(SHELL16+152)
SHELL.BufferArgs 	EQU 	(SHELL16+272)
SHELL.BufferKeys 	EQU 	(SHELL16+392)
SHELL.CursorRaw 	EQU 	(SHELL16+512)
SHELL.CursorCol 	EQU 	(SHELL16+513)

FAT16.FileSegments    EQU   (FAT16+36)
FAT16.DirSegments 	  EQU   (FAT16+38)
FAT16.LoadingDir      EQU   (FAT16+40)
			  

; _____________________________________________
; Starting the System _________________________

OSMain:
		cld
		mov 	ax, 0x3000		;0x0C00
		mov 	ds, ax
		mov 	es, ax
		mov 	fs, ax
		mov 	gs, ax
		mov 	ax, 0x0000		;0x07D0
		mov 	ss, ax
		mov 	sp, 0x1990		;0xFFFF

	; ===============================================
	; Fill IVT with DOS Interrupt Vector
	
	push 	es
	xor 	ax, ax
	mov 	es, ax
	xor 	bx, bx
	push 	ds
	pop 	ax
	add 	bx, (21h * 4)
	mov 	word[es:bx], DOS_INT_21H
	add 	bx, 2
	mov 	word[es:bx], ax
	pop 	es
	 
	; ===============================================
	
	;call 	VGA.SetVideoMode
	;call 	EffectInit
	;call 	Play_Sound
	
	; Text Mode
	mov 	ah, 00h
	mov 	al, 03h
	int 	10h
	
	call 	FAT16.LoadFatVbrData
	
	mov 	si, Extension
	mov 	bx, DRIVERS_OFFSET
	mov 	word[FAT16.DirSegments], 0x0200	; era 0x07C0
	
	call 	FAT16.LoadAllFiles
	;call 	KEYBOARD.Initialize
	call 	MEMX86.Detect_Low_Memory
	;call 	PCI.Init_PCI
	clc
	
; Descomente o código abaixo da linha '----' até a mesma linha '----' para testar a 
; a resolução do bug de travamento quando buffers são zerados.
; também der um enter no Shell sem digitar nada pra ver as modificações
; ----------------------------------------------------------------------------
;FirstCmd:
;	mov 	si, permission1
;	call 	Shell.Execute
;	cmp 	ax, 0xFF
;	jz 		PrintErr1
;	mov 	si, suc1
;	call 	Print_String
;SecondCmd:
;	mov 	si, permission
;	call 	Shell.Execute
;	cmp 	ax, 0
;	jz 		PrintSuc1
;	mov 	si, err1
;	call 	Print_String
;	jmp 	Load_Menu
	
;PrintErr1:
;	mov 	si, err1
;	call 	Print_String
;	jmp 	SecondCmd
;PrintSuc1:
;	mov 	si, suc1
;	call 	Print_String
;	jmp 	Load_Menu
	
;Shell.Execute: jmp 	SHELL16+3
;	nop
;	nop
;	permission db "chmod u=mdxrw kiddieos\system16\winmng32.kxe",0  ; Adicione um '0,' antes de '"chmod' para testar
;	permission1 db 0,0,0,0
;	err1 db "Erro de buffer zerado",0x0D,0x0A,0
;	suc1 db "Comando 'chmod' executado com sucesso",0x0D,0x0A,0
; ----------------------------------------------------------------------------

	
Load_Menu:
	mov 	si, PressKey
	call 	Print_String
	mov 	ah, 00h
	int 	16h
	

Kernel_Menu:
	call 	Hide_Cursor   ; Set Cursor Shape Hide
	
	Back_Blue_Screen:
		mov     bh, 0001_1111b     ; Blue_White 
		mov     cx, 0x0000         ; CH = 0, CL = 0     
		mov     dx, 0x1950         ; DH = 25, DL = 80
		call    Create_Panel
		
	Dialog_Panel:
		mov     bh, 0100_1111b     ; Red_White 
		mov     cx, 0x0818         ; CH = 8, CL = 24     
		mov     dx, 0x1038         ; DH = 16, DL = 56
		call    Create_Panel
		mov     bh, 0111_0000b     ; White_Black
		mov     cx, 0x0919         ; CH = 9, CL = 25     
		mov     dx, 0x0F37         ; DH = 15, DL = 55
		call    Create_Panel
		
	Dialog_Options:	
		add 	ch, 2
		add 	cl, 1
		push 	cx
		pop		dx
		mov 	byte[Counter], 0
		mov 	byte[Selection], ch
		mov     bh, 0100_1111b     ; Red_White
		call	Select_Event
		push 	dx
	Write_Options:
		pop 	dx
		push 	dx
		call	Move_Cursor
		mov 	si, Option1
		call	Print_String
		inc 	dh
		call	Move_Cursor
		mov 	si, Option2
		call	Print_String
		inc		dh
		call	Move_Cursor
		mov 	si, Option3
		call	Print_String
		pop 	dx
		push 	dx
		mov 	ax, G3
		call 	Play_Speaker_Tone
		jmp 	Select_Options
		
		QUANT_OPTIONS  EQU 3
		Option1    db "Textual Mode   (shell16.osf)",0
		Option2    db "Graphical Mode (winmng.osf)",0
		Option3    db "System Informations",0
		Selection  db 0
		Counter	   db 0
		Systems    dw SHELL16_INIT, WMANAGER_INIT, SYSTEM_INFORMATION
		  
		  
	Select_Options:
		mov 	ah, 00h
		int 	16h
		cmp 	ah, 0x50
		je 		IncSelection
		cmp 	ah, 0x48
		je 		DecSelection
		cmp 	al, 0x0D
		je 		RunSelection
		jmp 	Select_Options
		
	IncSelection:
		cmp		byte[Counter], QUANT_OPTIONS-1
		jne		IncNow
		mov 	byte[Counter], 0
		call 	Erase_Select
		sub		ch, 2
		call	Focus_Select
		jmp 	Write_Options
		IncNow:
			inc 	byte[Counter]
			call 	Erase_Select
			inc 	ch
			call	Focus_Select
			jmp 	Write_Options
	DecSelection:
		cmp		byte[Counter], 0
		jne		DecNow
		mov 	byte[Counter], QUANT_OPTIONS-1
		call 	Erase_Select
		add		ch, 2
		call	Focus_Select
		jmp 	Write_Options
		DecNow:
			dec 	byte[Counter]
			call 	Erase_Select
			dec 	ch
			call	Focus_Select
			jmp 	Write_Options
			
	RunSelection:
		pop 	dx
		xor 	bx, bx
		mov 	bl, byte[Counter]
		shl		bx, 1
		mov 	bx, word[Systems + bx]
		mov 	ax, A3
		call 	Play_Speaker_Tone
		jmp 	bx
	
	Erase_Select:
		mov  	ch, byte[Selection]
		mov 	dh, ch
		mov     bh, 0111_0000b     ; Black_White
		call 	Select_Event
		mov  	ch, byte[Selection]
	ret
	
	Focus_Select:
		mov 	dh, ch
		mov 	byte[Selection], ch
		mov     bh, 0100_1111b     ; Red_White
		call 	Select_Event
	ret	
	
	Select_Event:
		push  	dx
		add		dl, 28
		call	Create_Panel
		pop 	dx
	ret
	
	
	
	WMANAGER_INIT:
		
		mov		ax, 4800h 
		mov 	fs, ax
		mov 	ax, 5800h
		mov 	gs, ax
		
		call 	WINMNG
		
		mov 	ah, 00h
		mov 	al, 03h
		int 	10h
		
		mov 	byte[SHELL.CursorRaw], 0
		mov 	byte[SHELL.CursorCol], 0
		jmp 	Kernel_Menu
		;jmp 	OSMain
		
		
	SHELL16_INIT:
	
		jmp 	3000h:SHELL16	; Era 0C00h:...
		
		
	SYSTEM_INFORMATION:
		mov     bh, 0010_1111b     ; Green_White 
		mov     cx, 0x0616         ; CH = 8, CL = 24     
		mov     dx, 0x133A         ; DH = 16, DL = 56
		call    Create_Panel
		mov     bh, 0111_0010b     ; White_Green
		mov     cx, 0x0717         ; CH = 9, CL = 25     
		mov     dx, 0x1239         ; DH = 15, DL = 55
		call    Create_Panel
		inc 	ch
		inc 	cl
		mov 	dx, cx
		mov 	cx, 10
		mov 	si, Informations
		call	Write_Info
		mov 	ah, 00h
		int 	16h
		jmp 	Back_Blue_Screen
		
		Informations:
		SystemName  db "System Name  : KiddieOS",0
		Version 	db "Version      : ",VERSION,0
		Author      db "Author       : Francis (BFTC)",0
		Arquiteture db "Arquitecture : 16-bit (x86)",0
		FileSystem  db "File System  : FAT16",0
		RunningFile db "Running File : kernel.osf",0
		GuiVersion  db "GUI Version  : Window 2.0",0
		SourceCode  db "Source-Code  : Assembly x86",0
		Lang        db "Language     : English (US)",0
		DateTime    db "Date/Time    : 05/01/2021 08:31",0
		
		
		
; _____________________________________________
	

; _____________________________________________
; Kernel Sub-Routines _________________________


Print_Fat_Time:
	pusha
	mov 	bx, ax
	xor 	eax, eax
	mov 	ax, bx
	and 	ax, (11111b << 11)
	shr 	ax, 11
	cmp 	al, 10
	jnb 	NoTimeZero1
	push 	ax
	mov 	ax, 0x0E30
	int 	0x10
	pop 	ax
NoTimeZero1:
	call 	Print_Dec_Value32
	mov 	ah, 0x0E
	mov 	al, ':'
	int 	0x10
	mov 	ax, bx
	and 	ax, (111111b << 5)
	shr 	ax, 5
	cmp 	al, 10
	jnb 	NoTimeZero2
	push 	ax
	mov 	ax, 0x0E30
	int 	0x10
	pop 	ax
NoTimeZero2:
	call 	Print_Dec_Value32
	mov 	ah, 0x0E
	mov 	al, ':'
	int 	0x10
	mov 	ax, bx
	and 	ax, 11111b
	cmp 	al, 10
	jnb 	NoTimeZero3
	push 	ax
	mov 	ax, 0x0E30
	int 	0x10
	pop 	ax
NoTimeZero3:
	call 	Print_Dec_Value32
	popa
ret


Print_Fat_Date:
	pusha
	mov 	bx, ax
	xor 	eax, eax
	mov 	ax, bx
	and 	ax, 11111b
	cmp 	al, 10
	jnb 	NoZero1
	push 	ax
	mov 	ax, 0x0E30
	int 	0x10
	pop 	ax
NoZero1:
	call 	Print_Dec_Value32
	mov 	ah, 0x0E
	mov 	al, '/'
	int 	0x10
	mov 	ax, bx
	and 	ax, (1111b << 5)     ;(1111b << 5) = 480 = 111100000b
	shr 	ax, 5
	cmp 	al, 10
	jnb 	NoZero2
	push 	ax
	mov 	ax, 0x0E30
	int 	0x10
	pop 	ax
NoZero2:
	call 	Print_Dec_Value32
	mov 	ah, 0x0E
	mov 	al, '/'
	int 	0x10
	mov 	ax, bx
	and 	ax, (1111111b << 9)
	shr 	ax, 9
	sub 	ax, 20
	add 	ax, 2000
	call 	Print_Dec_Value32
	popa
ret

; Exibe nomes de arquivos do FAT16 colocados em ES:DI
PrintNameFile:
	pusha
	mov 	cx, 11
	mov 	ah, 0x0E
	mov 	dl, byte[es:di + 11]
	xor 	bx, bx
Analyze:
	mov 	al, byte[es:di]
	cmp 	al, 0x20
	je 		NoPrintSpace
	cmp 	cx, 11
	je 		Display
	cmp 	al, "."
	je 		Display
	mov 	bl, al
	cmp 	bl, 0x3A
	jb 		ConvertNumber
	jmp 	ConvertCase
ConvertNumber:
	sub 	bl, 0x30
	mov 	al, byte[VetorHexa + bx]
	jmp 	Display
ConvertCase:
	sub 	bl, 0x41
	mov 	al, byte[VetorCharsLower + bx]
Display:
	int 	0x10
	inc 	byte[SHELL.CounterFName]
NoPrintSpace:
	cmp 	cx, 4
	jne 	NoPrintDot
	cmp 	dl, 0x08
	jb 		PrintDot
	cmp 	dl, 0x20
	jne 	NoPrintDot
PrintDot:
	mov 	al, '.'
	int 	10h
NoPrintDot:
	inc 	di 
    loop 	Analyze
.DONE:
	popa
RET

; Exibe Strings estáticas do sistema operacional colocados em DS:SI
Print_String:
	pusha
	mov 	ah, 0eh
	prints:
		mov 	al, [si]
		cmp 	al, 0
		jz		ret_print
		inc 	si
		int 	10h
		jmp 	prints
	ret_print:
		popa
ret	

; Imprime representação hexadecimal de 16 bits colocado em DS:SI
Print_Hexa_Value16:
	pusha
	mov SI, AX
	mov DX, 0xF000
	mov CL, 12
Print_Hexa16:
	mov BX, SI
	and BX, DX
	shr BX, CL
	push SI
	mov AH, 0Eh
	mov AL, byte[VetorHexa + BX]
	int 10h
	pop SI
	cmp CL, 0
	jz RetHexa
	sub CL, 4
	shr DX, 4
	jmp Print_Hexa16
RetHexa:
	popa
ret

; Imprime representação hexadecimal de 8 bits colocado em DS:SI
Print_Hexa_Value8:
	pusha
	xor AH, AH
	mov SI, AX
	mov DX, 0x00F0
	mov CL, 4
Print_Hexa8:
	mov BX, SI
	and BX, DX
	shr BX, CL
	push SI
	mov AH, 0Eh
	mov AL, byte[VetorHexa + BX]
	int 10h
	pop SI
	cmp CL, 0
	jz RetHexa1
	sub CL, 4
	shr DX, 4
	jmp Print_Hexa8
RetHexa1:
	popa
ret

Print_Hexa_Value32:
	pushad
	mov 	esi, eax
	mov 	edx, 0xF0000000
	mov 	cl, 28
Print_Hexa32:
	mov 	ebx, esi
	and 	ebx, edx
	shr 	ebx, cl
	push 	esi
	mov 	ah, 0Eh
	mov 	al, byte[VetorHexa + bx]
	int 	10h
	pop 	esi
	cmp 	cl, 0
	jz 		RetHexa32
	sub 	cl, 4
	shr 	edx, 4 
	jmp 	Print_Hexa32
	RetHexa32:
	popad
ret

Print_Dec_Value32:
	pushad
	cmp 	eax, 0
	je 		ZeroAndExit
	xor 	edx, edx
	mov 	ebx, 10
	mov 	ecx, 1000000000
DividePerECX:
	cmp 	eax, ecx      ; EAX = 950000
	jb 		VerifyZero
	mov 	byte[Zero], 1
	push 	eax
	div 	ecx
	xor 	edx, edx
	push 	ax
	push 	bx
	mov 	bx, ax
	mov 	ah, 0Eh
	mov 	al, byte[VetorDec + bx]
	int 	10h
	pop 	bx
	pop 	ax
	mul 	ecx
	mov 	edx, eax
	pop 	eax
	sub 	eax, edx
	xor 	edx, edx
DividePer10:
	cmp 	ecx, 1
	je 		Ret_Dec32
	push 	eax
	mov 	eax, ecx
	div 	ebx
	mov 	ecx, eax
	pop 	eax
	jmp 	DividePerECX
VerifyZero:
	cmp 	byte[Zero], 0
	je 		ContDividing
	push 	ax
	mov 	ax, 0E30h
	int 	10h
	pop 	ax
ContDividing:
	jmp 	DividePer10
ZeroAndExit:
	mov 	ax, 0E30h
	int  	10h
Ret_Dec32:
	mov 	byte[Zero], 0
	popad
ret

Parse_Dec_Value:
	pusha
	mov 	edx, 1
	mov 	ebx, 10
	
	push 	ecx
	dec 	si
EndSI:
	inc 	si
	loop 	EndSI
	pop 	ecx
	
Parsing:
	push 	ecx
	mov 	ecx, 10
	std
	lodsb
	cld
	mov 	di, VetorDec
	repne 	scasb
	
	push 	ebx
	inc 	ecx
	sub 	ebx, ecx
	
	push 	edx
	mov 	eax, edx
	xor 	edx, edx
	mul 	ebx
	pop 	edx
	
	add 	[Number], eax
	pop 	ebx
	mov 	eax, edx
	xor 	edx, edx
	mul 	ebx
	mov 	edx, eax
	
	pop 	ecx
	loop 	Parsing
	
	popa
	mov 	eax, [Number]
	mov 	byte[Number], 0
ret
Number 	dd 	0

Write_Info:
	call	Move_Cursor
	call	Print_String
	call 	NextInfo
	inc 	dh
	loop 	Write_Info
ret
	
NextInfo:
	inc 	si
	cmp 	byte[si], 0
	jne 	NextInfo
	inc 	si
ret

; Quebra de linha na exibição de Strings
Break_Line:
	mov ah, 0Eh
	mov al, 10
	int 10h
	mov al, 13
	int 10h
ret

; Cria painel no modo texto usando rotina de Limpar tela
Create_Panel:
	pusha
	mov ah, 06h
	mov al, 0
	int 10h
	popa
ret

Clear_Screen:
	mov 	ah, 06h
	mov 	al, 0
	mov 	ch, 0
	mov 	cl, 0
	mov 	dh, 25
	mov 	dl, 80
	int 	10h
ret

; Movimenta o cursor dado os parâmetros em DX
Move_Cursor:
	pusha
	mov ah, 02h
	mov bh, 00h
	int 10h
	popa
ret

Get_Cursor:
	push ax
	push bx
	push cx
	mov ah, 03h
	mov bh, 00h
	int 10h
	pop cx
	pop bx
	pop ax
ret

Hide_Cursor:
	pusha
	mov 	ah, 01h
	mov 	ch, 20h   ; bit 5 set is hiding cursor
	mov 	cl, 07h
	int 	10h
	popa
ret

Show_Cursor:
	pusha
	mov 	ah, 01h
	mov 	ch, 00h
	mov 	cl, 07h
	int 	10h
	popa
ret


; ==============================================================
; Rotina que mostra o conteúdo do vetor formatado
; IN: ECX = Tamanho do Vetor
;     ESI = Endereço do Vetor

; OUT: Nenhum.
; ==============================================================
Show_Vector32:
	pushad
	
	mov 	ax, 0x0E7B
	int 	0x10
	xor 	ebx, ebx
	
ShowVector:
	push 	ebx
	shl		ebx, 2
	mov 	eax, dword[esi + ebx]
	call 	Print_Dec_Value32
	pop 	ebx
	inc 	ebx
	mov 	ah, 0x0E
	mov 	al, ','
	int 	0x10
	loop 	ShowVector
	mov 	ax, 0x0E7D
	int 	0x10
	mov 	ax, 0x0E0D
	int 	0x10
	mov 	ax, 0x0E0A
	int 	0x10
	
	popad
ret

; ==============================================================
; Rotina que aloca uma quantidade de bytes e retorna endereço
; IN: ECX = Tamanho de Posições (Size)
;     EBX = Tamanho do Inteiro (SizeOf(int))

; OUT: EAX = Endereço Alocado
; ==============================================================
Calloc:
	pushad
	
	xor 	eax, eax
	push 	ds
	pop 	es
	mov 	eax, MEMX86
	push 	ecx
	mov 	ecx, MEMX86_NUM_SECTORS
	
	Skip_Offset:
		add 	eax, 512
		loop 	Skip_Offset
		
	add 	eax, 4
	mov 	edi, eax
	xor 	eax, eax
	pop 	ecx
	push 	edi
	
	;mov 	es, ax
	
	cmp 	ebx, 1
	je 		Alloc_Size8
	cmp 	ebx, 2
	je 		Alloc_Size16
	cmp 	ebx, 4
	je 		Alloc_Size32
	jmp 	Return_Call
	
	; TODO 
	; Dados que podem estar na memória serão perdidos
	; nesta alocação, então melhor certificar que salvamos 
	; estes dados em algum lugar (talvez via push)
	; e recuperarmos na função Free()
	Alloc_Size8:  
		mov 	dword[Size_Busy], ecx
		rep 	stosb
		jmp 	Return_Call
	Alloc_Size16: 
		mov 	dword[Size_Busy], ecx
		shl 	dword[Size_Busy], 1
		rep 	stosw
		jmp 	Return_Call
	Alloc_Size32: 
		mov 	dword[Size_Busy], ecx
		shl 	dword[Size_Busy], 2
		rep 	stosd
		jmp 	Return_Call
	
Return_Call:
	pop 	DWORD[Return_Var_Calloc]
	popad
	mov 	eax, DWORD[Return_Var_Calloc]
	mov 	byte[Memory_Busy], 1
ret

Return_Var_Calloc dd 0
Size_Busy 	dd 0
Memory_Busy db 0


; ==============================================================
; Libera espaço dado um endereço alocado
; IN: EBX = Ponteiro de Endereço Alocado
;
; OUT: Nenhum.
; ==============================================================
Free:
	pushad
	mov 	edi, ebx
	;mov 	dword[ebx], 0x00000000
	push 	ds
	pop 	es
	mov 	al, 0
	mov 	ecx, dword[Size_Busy]
	rep 	stosb
	
	;push 	ds
	;pop 	es
	
	mov 	dword[Size_Busy], 0
	mov 	dword[Return_Var_Calloc], 0
	mov 	dword[Memory_Busy], 0
	popad
ret

; ---------------------------------------------------------
; DOS Services Routines

DOS_INT_21H:
	push 	ds 
	push 	cs
	pop 	ds
	push 	bx
	push 	ax
	xor 	bx, bx
	shr 	ax, 8
	mov 	bx, ax
	shl 	bx, 1
	mov 	bx, word[DOS_SERVICES + bx]
	jmp 	bx
	
DOS_SERVICES:
	dw 0x0000                   ; Função 0 (0x00)
	dw dos_read_input           ; Função 1 (0x01) com echo
	dw dos_write_char           ; Função 2 (0x02)
	dw 0x0000                   ; Função 3 (0x03)
	dw 0x0000                   ; Função 4 (0x04)
	dw dos_printer_output       ; Função 5 (0x05)
	dw dos_input_output         ; Função 6 (0x06)
	dw dos_char_input           ; Função 7 (0x07) sem echo
	dw 0x0000                   ; Função 8 (0x08)
	dw dos_write_string         ; Função 9 (0x09)
	dw dos_read_string 			; Função 10 (0x0A)
	times 0x32 dw 0x0000		; 0x0A - 0x3C (Reserved)
	dw dos_open_file			; Função 0x3D
	dw dos_close_file			; Função 0x3E
	dw dos_read_file			; Função 0x3F
	dw 0x0000					; Função 0x40
	dw 0x0000					; Função 0x41
	dw dos_seek_file			; Função 0x42
	dw 0x0000					; Função 0x43
	dw 0x0000
	dw 0x0000
	dw 0x0000
	dw 0x0000
	dw 0x0000
	dw 0x0000
	dw 0x0000
	dw 0x0000
	dw dos_exit_prog			; Função 0x4C
	
dos_read_input:
	pop 	ax
	pop 	bx
	
wait_key:
	mov 	ah, 1
	int 	0x16
	jz 		wait_key
	
	pop 	ds
iret
	
dos_write_char:
	pop 	ax
	pop 	bx
	
	;mov 	ah, 0x0E
	;mov 	al, dl
	;int 	0x10
	push 	es
	mov 	ax, ds
	mov 	es, ax
	mov 	[character], dl
	mov 	cx, 1
	mov 	di, character
	mov 	al, 0
	call 	SHELL.PrintData
	pop 	es
	
	mov 	al, [character]
	pop 	ds
iret

character db 0

dos_printer_output:
	pop 	ax
	pop 	bx
	
	xor 	dh, dh
	push 	dx
	xor 	dx, dx
	mov 	cx, 3
search_printer:
	mov 	ah, 0x01
	int 	0x17
	and 	ah, 00111111b
	cmp 	ah, 0
	jnz 	next_port
	
	pop 	ax
	mov 	ah, 00h
	int 	0x17
	jmp 	return_printer
	
next_port:	
	inc 	dx
	loop 	search_printer
	pop 	ax

return_printer:
	pop 	ds
iret

dos_input_output:
	pop 	ax
	pop 	bx
	
	cmp 	dl, 255
	jne 	write_char
	
	mov 	ah, 1
	int 	0x16
	jz 		error_no_char
	
	pop 	ds
	push 	bp
	mov 	bp, sp
	and	 	WORD [bp + 6], 0xFFBF
	pop 	bp
	mov 	ah, 0x00
	int 	0x16
	jmp 	return_in_out
	
error_no_char:
	pop 	ds
	push 	bp
	mov 	bp, sp
	or	 	WORD [bp + 6], 0x40
	pop 	bp
	xor 	ax, ax
	jmp 	return_in_out
	
write_char:
	mov 	ah, 2
	int 	0x21
	;mov 	ah, 0x0E
	mov 	al, dl
	;int 	0x10
	pop 	ds
	
return_in_out:
	iret
	


dos_char_input:
	pop 	ax
	pop 	bx
	
wait_echo:
	mov 	ah, 1
	int 	0x16
	jz 		wait_echo
	
no_echo:
	mov 	ax, 0x00
	int 	0x16
	
	pop 	ds
iret

dos_write_string:
	pop 	ax
	pop 	bx
	pusha
	
	;add 	dx, [SHELL.DOS_HEADER_BYTES]
	mov 	di, dx
	mov 	al, 1
	call 	SHELL.PrintData
	
	popa
	pop 	ds
iret

dos_read_string:
	pop 	ax
	pop 	bx
	
	xor 	bx, bx
	xor 	cx, cx
	
	mov 	ax, es
	mov 	ds, ax
	
	mov 	di, dx
	mov 	byte[di + 1], 0
	cmp 	byte[di], 0
	jz 		return_read_str
read_str:
	push 	di
	push 	cx
	mov 	ah, 07h
	int 	0x21
	cmp 	al, 0x08
	jz 		back_char
	mov 	ah, 02h
	mov 	dl, al
	int 	0x21
	cmp 	al, 0x0D
	jz 		return_read_wpop
	pop 	cx
	pop 	di
	xor 	bx, bx
	mov 	bl, [offset_char]
	mov 	[es:di + bx + 2], al
	inc 	cl
	mov 	[es:di + 1], cl
	inc 	bl
	mov 	[offset_char], bl
	cmp 	byte[es:di], bl
	jnz 	read_str
	push 	di
	push 	cx
is_major:
	mov 	ah, 07h
	int 	0x21
	cmp 	al, 0x08
	jne 	is_major
back_char:
	pop 	cx
	pop 	di
	cmp 	byte[offset_char], 0
	jz 		read_str
	mov 	ah, 0Eh
	mov 	al, 0x08
	int 	0x10
	mov 	ah, 0Eh
	mov 	al, 0
	int 	0x10
	mov 	ah, 0Eh
	mov 	al, 0x08
	int 	0x10
	mov 	al, 0
	xor 	bx, bx
	dec 	byte[offset_char]
	mov 	bl, [offset_char]
	mov 	[es:di + bx + 2], al
	dec 	byte[es:di + 1]
	dec 	cx
	jmp 	read_str
	
return_read_wpop:
	pop 	cx
	pop 	di

return_read_str:
	mov 	byte[offset_char], 0
	pop 	ds
	iret

offset_char db 0

dos_open_file:
	pop 	ax
	pop 	bx
	
	;add 	dx, [SHELL.DOS_HEADER_BYTES]
	mov 	si, dx
	
	mov 	bx, ds
	mov 	gs, bx
	mov 	bx, SHELL.CD_SEGMENT
	
	pop 	ds
	
	push 	es
	push 	WORD[gs:bx]
	push 	ax
	
	mov 	ax, 0x3000
	mov 	es, ax
	
	mov 	di, SHELL.BufferAux2
	call 	SHELL.Copy_Buffers
	
	mov 	ds, ax
	mov 	si, SHELL.BufferAux2
	mov 	di, SHELL.BufferKeys
	mov 	byte[SHELL.IsCommand], 0
	call 	SHELL.Format_Command_Line
	
	call 	SHELL.Store_Dir
	
	mov 	cx, 1
	call 	SHELL.Load_File_Path
	mov 	ax, 03h
	pop 	dx
	jc 		open_error
	
	mov 	dh, 2
	mov 	ax, [SHELL.CD_SEGMENT]
	call 	FAT16.OpenThisFile
	jc 		open_error
	
	clc
	jmp 	return_dos_open
	
open_error:
	mov 	[handler], ax
	pop 	WORD[SHELL.CD_SEGMENT]
	call 	SHELL.Restore_Dir
	mov 	ax, [handler]
	pop 	es
	mov 	bx, es
	mov 	ds, bx
	push 	bp
	mov 	bp, sp
	or	 	WORD [bp + 6], 1
	pop 	bp
	iret
return_dos_open:
	mov 	[handler], ax
	pop 	WORD[SHELL.CD_SEGMENT]
	call 	SHELL.Restore_Dir
	mov 	ax, [handler]
	pop 	es
	mov 	bx, es
	mov 	ds, bx
	push 	bp
	mov 	bp, sp
	and	 	WORD [bp + 6], 0xFFFE
	pop 	bp
	iret
handler dw 0x0000

dos_read_file:
	pop 	ax
	pop 	bx
	
	mov 	ax, es
	mov 	[FAT16.DirSegments], ax
	mov 	ax, 0x6800
	mov 	[FAT16.FileSegments], ax
	mov 	byte[FAT16.LoadingDir], 0
	
	push 	es
	call 	FAT16.LoadFile
	pop 	es
	jc 		read_error
	
	pop 	ds
	push 	bp
	mov 	bp, sp
	and	 	WORD [bp + 6], 0xFFFE
	pop 	bp
	iret
	
read_error:
	pop 	ds
	push 	bp
	mov 	bp, sp
	or	 	WORD [bp + 6], 1
	pop 	bp
	iret
	
dos_seek_file:
	pop 	ax
	pop 	bx
	
	call 	FAT16.SetSeek
	jc 		seek_error
	
	pop 	ds
	push 	bp
	mov 	bp, sp
	and	 	WORD [bp + 6], 0xFFFE
	pop 	bp
	iret
	
seek_error:
	pop 	ds
	push 	bp
	mov 	bp, sp
	or	 	WORD [bp + 6], 1
	pop 	bp
	iret
	
dos_close_file:
	pop 	ax
	pop 	bx
	
	mov 	WORD [FAT16.FileSegments], 0x6800
	call 	FAT16.CloseFile
	jc 		close_error
	
	pop 	ds
	push 	bp
	mov 	bp, sp
	and	 	WORD [bp + 6], 0xFFFE
	pop 	bp
	iret
	
close_error:
	pop 	ds
	push 	bp
	mov 	bp, sp
	or	 	WORD [bp + 6], 1
	pop 	bp
	iret
	
	
	
	

dos_exit_prog:
	pop 	ax
	pop 	bx
	pop 	ds
	
	add 	sp, 6
retf

; ---------------------------------------------------------

; --------------------------------------------------------


END:
; Zera na reinicialização todos os endereços de memória utilizados
	; ________________________________________________________________
	mov word[fs:POSITION_X], 0000h
	mov word[fs:POSITION_Y], 0000h
	mov word[fs:QUANT_FIELD], 0000h
	mov word[fs:LIMIT_COLW], 0000h
	mov word[fs:LIMIT_COLX], 0000h
	mov word[fs:QuantPos], 0000h
	mov word[CountPositions], 0000h
	mov byte[fs:StatusLimitW], 0
	mov byte[fs:StatusLimitX], 0
	mov byte[fs:CursorTab], 0
	; ________________________________________________________________
	; Reinicia sistema
	; _________________________________________
	mov ax, 0040h
	mov ds, ax
	mov ax, 1234h
	mov [0072h], ax
	jmp 0FFFFh:0000h
; _____________________________________________
; _____________________________________________
