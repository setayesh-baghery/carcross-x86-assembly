; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
;
; author:	David Blinder, Stijn Bettens
; date:		23/10/2018
; program:	Video mode 13h
; -------------------------------------------------------------------

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "keyb.inc"
INCLUDE "rand.inc"

; compile-time constants (with macros)
VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen witdth
SCRHEIGHT EQU 200	; screen height
BG_COLOR EQU 0

PLAYER_HEIGHT EQU 50
STARTPOS_PLAYER EQU 2

ENEMY_HEIGHT EQU 50
ENEMY_START_SPEED EQU 1
STARTPOS_ENEMY EQU 0

START_CONTACT_PLAYER EQU 150
END_CONTACT_PLAYER EQU 190


; -------------------------------------------------------------------
CODESEG

; Set the video mode
PROC setVideoMode
 ARG @@VM:byte
 USES eax

 movzx ax,[@@VM]
 int 10h
ret
ENDP setVideoMode

; ; Fill the background (for mode 13h)
PROC fillBackground
ARG 	@@fillcolor:byte
USES 	eax, ecx, edi

; Initialize video memory address.
mov	edi, VMEMADR

; Scan the whole video memory and assign the background colour.
mov	ecx, SCRWIDTH*SCRHEIGHT
mov	al,[@@fillcolor]
rep	stosb

ret
ENDP fillBackground

; Read Bin file
PROC ReadFile
	ARG	 @@filepathptr:dword, @@dataptr:dword, @@noofbytes:dword
	USES eax, ebx, ecx, edx, esi, edi

	; open file, get filehandle in AX
	mov al, 0 ; read only
	mov edx, [@@filepathptr]
	mov ah, 3dh
	int 21h

	mov  edx, offset openErrorMsg
	jc @@print_error ; carry flag is set if error occurs

	; read file data
	mov bx, ax ; move filehandle to bx
	mov ecx, [@@noofbytes]
	mov edx, [@@dataptr]
	mov ah, 3fh
	int 21h

	mov  edx, offset readErrorMsg
	jc @@print_error

	; close file
	mov ah, 3Eh
	int 21h

	mov  edx, offset closeErrorMsg
	jc @@print_error

	ret

@@print_error:
	call setVideoMode, 03h
	mov  ah, 09h
	int  21h

	mov	ah,00h
	int	16h
	call terminateProcess
ENDP ReadFile

; Draw sprite
PROC drawSprite
ARG @@spritePtr :dword, @@dstPtr:dword, @@x:dword, @@y: dword
LOCAL @@w:dword, @@h:dword
USES eax, ebx, ecx, edx, esi , edi


mov esi , [@@spritePtr]
xor eax, eax
lodsw ; read width in AX
shr ax, 1 ; divide by 2
mov [@@w], eax

lodsw ; read height in AX
; shl eax, 1 ; multiply by 2
mov [@@h], eax

mov edi, [@@dstPtr]
mov eax, [@@y]
mov ebx, SCRWIDTH
mul ebx
add edi, eax
add edi, [@@x]
mov ecx, [@@h]
@@drawLine:
push ecx
mov ecx, [@@w]
rep movsb

add edi , SCRWIDTH
sub edi, [@@w] ; edi now points to the next line in dst

pop ecx
dec ecx
jnz @@drawLine

ret
ENDP drawSprite

; delay
proc wait_VBLANK
	ARG @@framecount: word
	USES eax, ecx, edx
	mov dx, 03dah 					; Wait for screen refresh
	movzx ecx, [@@framecount]

		@@VBlank_phase1:
		in al, dx
		and al, 8
		jnz @@VBlank_phase1
		@@VBlank_phase2:
		in al, dx
		and al, 8
		jz @@VBlank_phase2
	loop @@VBlank_phase1

	ret
endp wait_VBLANK

; random integer from 0 to 4, stored in edx
PROC random
USES eax, ebx

	call rand

	xor edx, edx
	mov ebx, 5
	div ebx

	ret

ENDP random

; draw a line
PROC drawLine
ARG @@x0:word, @@y0:word, @@h:word, @@col:byte
USES 	eax, ecx, edx, edi

; Compute the index of the rectangle's top left corner
movzx eax, [@@y0]
mov edx, SCRWIDTH
mul edx
add	ax, [@@x0]

; Compute top left corner address
mov edi, VMEMADR
add edi, eax

; plot the line
mov	al,[@@col]
movzx ecx,[@@h]
@@vertLoop:
	mov	[edi],al
	add	edi, SCRWIDTH
	loop @@vertLoop

ret

ENDP drawLine

; ; Draw a rectangle (video mode 13h)
PROC drawRectangle
ARG 	@@x0:dword, @@y0:dword, @@w:dword, @@h:dword, @@col: byte
USES 	eax, ecx, edx, edi ; note: MUL uses edx!

; Compute the index of the rectangle's top left corner
mov eax, [@@y0]
mov edx, SCRWIDTH
mul edx
add	eax, [@@x0]

; Compute top left corner address
mov edi, VMEMADR
add edi, eax


mov ecx,[@@h]
height:
push ecx

; Plot the top horizontal edge.
mov edx, [@@w]	; store width in edx for later reuse
mov	ecx, edx
mov	al,[@@col]
rep stosb ; edi start point, ecx width
sub edi, edx		; reset edi to left-top corner
add edi, SCRWIDTH

pop ecx
loop height

ret
ENDP drawRectangle

; Wait for a specific keystroke.
PROC waitForSpecificKeystroke
	ARG 	@@key:byte
	USES 	eax

	@@waitForKeystroke:
		mov	ah,00h
		int	16h
		cmp	al,[@@key]
	jne	@@waitForKeystroke

	ret
ENDP waitForSpecificKeystroke

; Terminate the program.
PROC terminateProcess
	USES eax
	call setVideoMode, 03h
	mov	ax,04C00h
	int 21h
	ret
ENDP terminateProcess

PROC updateCarImage
	ARG @@pos:dword, @@prevpos:dword
	USES eax, ebx

	;remove old car
	mov eax, [@@prevpos]
	mov ebx, 64
	mul ebx
	add eax, 5
	call drawRectangle, eax, START_CONTACT_PLAYER, PLAYER_HEIGHT, PLAYER_HEIGHT, BG_COLOR

    ;draw new car
	mov eax, [@@pos]
	mov ebx, 64
	mul ebx
	add eax, 5
	call drawSprite, offset car_sprite, VMEMADR, eax, START_CONTACT_PLAYER

	ret

ENDP updateCarImage

PROC updateEnemyImage
	ARG @@pos:dword, @@prevpos:dword, @@lane:dword
	USES eax, ebx, ecx

	;remove old enemy
	mov eax, [@@lane]
	mov ebx, 64 ; lane offset
	mul ebx
	add eax, 5
	mov edx, [@@prevpos]
	sub edx, ENEMY_HEIGHT
	call drawRectangle, eax, edx, ENEMY_HEIGHT, ENEMY_HEIGHT, BG_COLOR

    ;draw new enemy
	mov eax, [@@lane]
	mov ebx, 64 ; lane offset
	mul ebx
	add eax, 5
	mov edx, [@@pos]
	sub edx, ENEMY_HEIGHT
	call drawSprite, offset enemy_sprite, VMEMADR, eax, edx

	ret

ENDP updateEnemyImage

PROC displayString
    ARG @@row:dword, @@column:dword, @@offset:dword
    USES eax, ebx, edx
	
    mov edx, [@@row]    ; row in edx
    mov ebx, [@@column] ; column in ebx
	mov ah, 02h
	shl edx, 08h
	mov dl, bl
	mov bh, 0
	int 10h
	; set cursor position
	; row in dh (00h is top)
	; column in dl (00h is left)
	; page number in bh
	; raise interrupt
	; write string to standard output
	mov ah, 09h
	mov edx, [@@offset] ; offset of ’$’-terminated string in edx
	int 21h             ; raise interrupt
	ret
ENDP displayString

PROC setup
USES edx

	call	setVideoMode,13h
	call	fillBackground, BG_COLOR


	; draw lanes
	call	drawLine, 64, 0, 200, 15
	call	drawLine, 128, 0, 200, 15
	call	drawLine, 192, 0, 200, 15
	call	drawLine, 256, 0, 200, 15


	; load and draw car sprite
	mov edx, offset car_sprite
	add edx, 8
	call ReadFile, offset car_file, edx, 5000
	call drawSprite, offset car_sprite, VMEMADR, 133, START_CONTACT_PLAYER

	; load enemy sprite
	mov edx, offset enemy_sprite
	add edx, 8
	call ReadFile, offset car_file, edx, 5000

	; display control instruction
	call displayString, [row_text], [column_text], offset startMsg
	call wait_VBLANK, 200
	call drawRectangle, 0, 0, 400, 100, BG_COLOR

  ; draw lanes again
  	call	drawLine, 64, 0, 200, 15
  	call	drawLine, 128, 0, 200, 15
  	call	drawLine, 192, 0, 200, 15
  	call	drawLine, 256, 0, 200, 15


	call __keyb_installKeyboardHandler
	mov esi, 0 ; set game counter

	ret

ENDP setup

; Update car position + sprite
PROC moveCar

	ARG @@direction:dword

	mov eax, [player_lane]
	mov ebx, eax
	add ebx, [@@direction]
	mov [player_lane], ebx
	call updateCarImage, ebx, eax
	call wait_VBLANK, 5
	ret

ENDP moveCar

PROC keyStrokes
USES eax, ebx

	@checkKeys:
	mov al, [__keyb_rawScanCode]
	cmp al, 4BH
	je @moveLeft

	cmp al, 4DH
	je @moveRight
	ret

	@moveLeft:
	mov ebx, [player_lane]
	cmp ebx, 0
	je @return
	call moveCar, -1
	ret

	@moveRight:
	mov ebx, [player_lane]
	cmp ebx, 4
	je @return
	call moveCar, 1
	ret

	@return:
	ret

ENDP keyStrokes

; Update enemy position + sprite, check for endgame
PROC moveEnemy
	ARG @@pos_address:dword, @@lane:dword, @@active_address:dword
	USES eax, ebx, ecx, edx, edi

	mov edx, [@@active_address]
	mov eax, [edx]
	cmp eax, 0
	je return

	mov edx, [@@pos_address]
	mov eax, [edx]

	cmp eax, START_CONTACT_PLAYER
	jl checkReset
	mov ebx, END_CONTACT_PLAYER
	add ebx, ENEMY_HEIGHT
	cmp eax, ebx
	jg checkReset

	mov edi, [player_lane]
	cmp [@@lane], edi
	jne checkReset

	endGame: ; display game over message and stop the game
	call displayString, [row_text], [column_text], offset gameOverMsg
	call wait_VBLANK, 250
	call __keyb_uninstallKeyboardHandler
	call terminateProcess

	checkReset:
	mov edi, SCRHEIGHT
	add edi, ENEMY_HEIGHT ; height car
	cmp eax, edi
	jg reset

	mov ebx, eax
	add ebx, [enemy_speed]
	jmp updateImage

	reset:
	mov ecx, [@@active_address]
	mov [ecx], 0
	mov ebx, 0

	updateImage:
	mov [edx], ebx
	call updateEnemyImage, ebx, eax, [@@lane]

	return:
	ret

ENDP moveEnemy

PROC activateEnemy
ARG @@enemy_number:dword
USES eax

	mov eax, [@@enemy_number]

	cmp eax, 4
	je activate_4
	cmp eax, 3
	je activate_3
	cmp eax, 2
	je activate_2
	cmp eax, 1
	je activate_1
	cmp eax, 0
	je activate_0


	activate_4:
	mov [enemy4_active], 1
	jmp end_proc


	activate_3:
	mov [enemy3_active], 1
	jmp end_proc


	activate_2:
	mov [enemy2_active], 1
	jmp end_proc


	activate_1:
	mov [enemy1_active], 1
	jmp end_proc


	activate_0:
	mov [enemy0_active], 1

	end_proc:
	ret

ENDP activateEnemy

PROC moveEnemies
USES eax, ecx, ebx

	mov ecx, 4

	enemies:

	cmp ecx, 4
	je enemy4
	cmp ecx, 3
	je enemy3
	cmp ecx, 2
	je enemy2
	cmp ecx, 1
	je enemy1
	cmp ecx, 0
	je enemy0


	enemy4:
	mov ebx, offset enemy4_position
	mov eax, offset enemy4_active
	call moveEnemy, ebx, ecx, eax
	loop enemies


	enemy3:
	mov ebx, offset enemy3_position
	mov eax, offset enemy3_active
	call moveEnemy, ebx, ecx, eax
	loop enemies


	enemy2:
	mov ebx, offset enemy2_position
	mov eax, offset enemy2_active
	call moveEnemy, ebx, ecx, eax
	loop enemies


	enemy1:
	mov ebx, offset enemy1_position
	mov eax, offset enemy1_active
	call moveEnemy, ebx, ecx, eax
	loop enemies


	enemy0:
	mov ebx, offset enemy0_position
	mov eax, offset enemy0_active
	call moveEnemy, ebx, ecx, eax


	call wait_VBLANK, 1
	ret

ENDP moveEnemies

PROC activateEnemies
USES edx

	call random
	call activateEnemy, edx

	ret

ENDP activateEnemies

PROC maybeIncreaseLevel
USES eax

	mov eax, [level_delay]
	cmp eax, esi
	jg continue

	;increase level
	add [enemy_speed], 1

	mov eax, [enemy_spawn_delay]
	cmp eax, 1
	je reset_and_continue

	shr [enemy_spawn_delay], 1

	reset_and_continue:
	mov esi, 0

	continue:
	ret

ENDP maybeIncreaseLevel

PROC main
	sti
	cld

	push ds
	pop	es

	call setup
	call rand_init


reset_spawn_delay:

	mov ecx, [enemy_spawn_delay]

reactivate_delay:

	call keyStrokes
	call moveEnemies
	add esi, 1

	mov al, [__keyb_rawScanCode] ; last pressed key
	cmp al, 01h
	je @@escape ; check if ESC is pressed, otherwise keep looping

loop reactivate_delay

	;(maybe) add an enemy to the screen
	call activateEnemies
	call maybeIncreaseLevel
	jmp reset_spawn_delay


@@escape:

 	call __keyb_uninstallKeyboardHandler
	call	terminateProcess

ENDP main

; -------------------------------------------------------------------

DATASEG

	player_lane dd STARTPOS_PLAYER

	enemy0_position dd STARTPOS_ENEMY
	enemy0_active dd 0

	enemy1_position dd STARTPOS_ENEMY
	enemy1_active dd 0

	enemy2_position dd STARTPOS_ENEMY
	enemy2_active dd 0

	enemy3_position dd STARTPOS_ENEMY
	enemy3_active dd 0

	enemy4_position dd STARTPOS_ENEMY
	enemy4_active dd 0

	enemy_speed dd ENEMY_START_SPEED

	level_delay dd 2000
	enemy_spawn_delay dd 50


	car_file db "CAR.bin", 0
	car_sprite DW 100,50
		DB 5000 DUP(?)

	enemy_file db "ENEMY.bin", 0 ; could not open file
	enemy_sprite DW 100,50
		DB 5000 DUP(?)


; text displays:
    row_text      dd 00H
    column_text   dd 00H
    gameOverMsg  db "Game Over!$", 0
    startMsg  db "Press left/right key to play$", 0

; readFile error messages:
  	openErrorMsg db "could not open file", 13, 10, '$'
  	readErrorMsg db "could not read data", 13, 10, '$'
  	closeErrorMsg db "error during file closing", 13, 10, '$'

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
