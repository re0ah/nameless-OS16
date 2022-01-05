;This is free and unencumbered software released into the public domain.

;Anyone is free to copy, modify, publish, use, compile, sell, or
;distribute this software, either in source code form or as a compiled
;binary, for any purpose, commercial or non-commercial, and by any
;means.

;In jurisdictions that recognize copyright laws, the author or authors
;of this software dedicate any and all copyright interest in the
;software to the public domain. We make this dedication for the benefit
;of the public at large and to the detriment of our heirs and
;successors. We intend this dedication to be an overt act of
;relinquishment in perpetuity of all present and future rights to this
;software under copyright law.

;THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
;IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
;OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
;ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
;OTHER DEALINGS IN THE SOFTWARE.

;For more information, please refer to <http://unlicense.org/>
%include "../source/syscall.inc"

PICM	equ 0x20 ;master PIC
PIC_EOI	equ 0x20 ;end of interrupt code

VGA_BUFFER		equ 0xB800
VGA_WIDTH       equ 40
VGA_HEIGHT      equ 25
VGA_CHAR_SIZE   equ 2 ;bytes
VGA_ROW_SIZE    equ VGA_CHAR_SIZE * VGA_WIDTH
VGA_PAGE_SIZE	equ	VGA_ROW_SIZE * VGA_HEIGHT
VGA_PAGE_NUM_CHARS equ VGA_WIDTH * VGA_HEIGHT ;1000 chars
FINAL_ROW_POS	equ (VGA_HEIGHT - 1) * VGA_WIDTH * VGA_CHAR_SIZE
ROW_WIDTH       equ 32
ROW_SIZE		equ VGA_CHAR_SIZE * ROW_WIDTH

SNAKE_TO_STOP	equ 0x00
SNAKE_TO_UP		equ -(VGA_WIDTH * VGA_CHAR_SIZE)
SNAKE_TO_LEFT	equ -VGA_CHAR_SIZE
SNAKE_TO_DOWN	equ VGA_WIDTH * VGA_CHAR_SIZE
SNAKE_TO_RIGHT	equ VGA_CHAR_SIZE

SNAKE_POS_DEFAULT equ 910

snake:
.init:
;set video mode
	mov		ax,		0x0001 ;set video mode, 40x25
						   ;why this mode? In them symbols are square, x=y
	int		0x10

	mov		bx,		SYSCALL_VGA_CURSOR_DISABLE
	int		0x20
.start:
	mov		bx,		SYSCALL_VGA_CLEAR_SCREEN
	int		0x20

	call	choose_snake_speed
	
	mov		al,		' '
	mov		byte[score_uint_str + 1], al
	mov		byte[score_uint_str + 2], al
	mov		byte[score_uint_str + 3], al

	mov		bx,		SYSCALL_VGA_CLEAR_SCREEN ;0
	mov		word[score],	0
	mov		word[snake_direction], bx
	mov		byte[game_end],	bl
	mov		word[snake_pos], SNAKE_POS_DEFAULT
	int		0x20

	call	draw_wall

	mov		di,		pit_handler
	mov		bx,		SYSCALL_SET_PIT_INT
	int		0x20

	call	draw_score
	call	fruit_generate
.lp:
	sti
	hlt
	cli
	movzx	cx,		byte[game_end]
	jcxz	.lp
.if_lose:
	sti
	call	draw_menu

.wait_keyboard_data:
	hlt
	call	get_keyboard_data
	je		.wait_keyboard_data
	cmp		al,		0x1C	;scancode enter
	je		.start
.not_enter:
	cmp		al,		0x01	;scancode esc
	jne		.wait_keyboard_data
.exit:
	mov		bx,		SYSCALL_VGA_CURSOR_ENABLE
	int		0x20

;set back video mode
	mov		ax,		0x0003
	int		0x10

	xor		ax,		ax	;exit status
	retf

pit_handler:
	cmp		byte[game_end],		1
	je		.end

	call	keyboard_routine
	call	snake_move
	call	check_wall_collision
	call	check_fruit_collision
.end:
	mov     al,     PICM
	out     PIC_EOI, al
	iret

snake_move:
.clear_prev:
	mov		bx,		word[snake_pos]
	mov		ax,		0x0720
	mov		word[es:bx],	ax

	add		bx,		word[snake_direction]
	mov		word[snake_pos], bx
	mov		al,		0x43
	mov		word[es:bx],	ax
.exit:
	retn

check_wall_collision:
;in:  bx=snake pos
	mov		bx,		word[snake_pos]
	cmp		bx,		ROW_SIZE ;check up border
	jl		.lose

	cmp		bx,		FINAL_ROW_POS ;check bottom border
	jge		.lose

	lea		ax,		[bx + 18]
	call	.div_check

	mov		ax,		bx
	jmp		.div_check
.lose:
	mov		byte[game_end],		1
.not_lose:
	retn
.div_check:
	xor		dx,		dx ;check right border
	div		word[divisor_vga_row_size]
	test	dx,		dx
	je		.lose
	retn

fruit_generate:
.again_get_y:
	mov		bx,		SYSCALL_GET_RAND_INT
	int		0x20
	and		ax,		0x0016
;	test	ax,		ax
	jz		.again_get_y
;	shl		ax,		4
;	mov		cx,		ax	;y pos, need mul to 80
;	shl		cx,		2
;	add		cx,		ax
	imul	cx,		ax,		80
.again_get_x:
	mov		bx,		SYSCALL_GET_RAND_INT
	int		0x20
	and		ax,		0x001E
	shl		ax,		1
;	test	ax,		ax
	jz		.again_get_x
	add		ax,		cx	;x pos
	cmp		ax,		word[fruit_pos]
	jz		fruit_generate
	mov		di,		ax
	mov		word[fruit_pos],	di
	mov		ax,		0x0746	;black bg, gray fg, char=F
	stosw
.check_fruit_collision_false:
	retn

get_keyboard_data:
	mov		bx,		SYSCALL_GET_KEYBOARD_DATA
	int		0x20
	test	al,		al
	retn

keyboard_routine:
	call	get_keyboard_data
	je		.end

	cmp		al,		0x01 ;ESC
	je		.pause
	cmp		al,		0x20 ;scancode D
	ja		.not_wasd
.wasd:
	movzx	bx,		al
	sub		bx,		0x11 ;scancode W
	jl		.end
	movsx	bx,		byte[data_table_wasd + bx]
	test	bx,		bx
	jne		.processing
	retn
.not_wasd:
	movzx	bx,		al
	cmp		bx,		0xEC
	ja		.end
	sub		bx,		0xE9
	jl		.end
	movsx	bx,		byte[data_table_arrow + bx]
.processing:
	cmp		word[snake_direction],	bx
	je		.end
	neg		bx
	mov		word[snake_direction],	bx
	retn
.pause:
	xor		ax,		ax
	mov		word[snake_direction],	ax
.end:
	retn

check_fruit_collision:
;in: bx=snake pos
	cmp		bx,		word[fruit_pos]
	jne		fruit_generate.check_fruit_collision_false
	call	fruit_generate
	inc		word[score]

draw_score:
	mov		ax,		word[score]
	mov		si,		score_uint_str
	mov		bx,		SYSCALL_UINT_TO_ASCII
	int		0x20
	mov		di,		SCORE_POS

draw_text:
;si: C string
;di: dest
	mov		ah,		0x07
.lp_speed_choose:
	lodsb
	stosw
	test	al,		al
	jne		.lp_speed_choose
	retn

choose_snake_speed:
	mov		ax,		0x0723	;bg=black, fg=gray, char='#'
	mov		cx,		34
	mov		di,		486	;6 row, 3 char
	rep		stosw	;ax -> es:di

	mov		cx,		36
	mov		di,		164	;3 row, 3 char
	rep		stosw	;ax -> es:di

.lp_right:
	add		di,		78
	stosw
	cmp		di,		1836 ;22 row, 37 char
	jne		.lp_right

.lp_left:
	dec		di
	dec		di
	mov		word[es:di],	ax
	cmp		di,		1764 ;22 row, 3 char
	jne		.lp_left

.lp_up:
	sub		di,		80
	mov		word[es:di],	ax
	cmp		di,		244 ;5 row, 4 char
	jne		.lp_up

	mov		si,		speed_choose_str
	xor		bx,		bx
.lp228:
	mov		di,		word[speed_str_addresses + bx]
	call	draw_text
	inc		bx
	inc		bx
	cmp		bx,		12
	jne		.lp228

.wait_keyboard_data:
	hlt
	call	get_keyboard_data
	cmp		al,		0x01 ;scancode ESC
	jne		.continue
	pop		ax
	jmp		snake.exit
.continue:
	sub		al,		2 ;scancode '1'
	jl		.wait_keyboard_data
	cmp		al,		4
	ja		.wait_keyboard_data

	movzx	bx,		al
	xor		al,		al
	mov		ah,		byte[speed_frequency_data_table + bx]
	mov		bx,		SYSCALL_PIT_SET_FREQUENCY
	int		0x20
	retn

draw_menu:
	mov		ax,		0x0723	;bg=black, fg=gray, char='#'
	mov		cx,		28
	mov		di,		164	;3 row, 3 char
	rep		stosw	;ax -> es:di

.lp_right:
	add		di,		78
	stosw
	cmp		di,		1820 ;22 row, 29 char
	jne		.lp_right

.lp_left:
	dec		di
	dec		di
	mov		word[es:di],	ax
	cmp		di,		1764 ;22 row, 3 char
	jne		.lp_left

.lp_up:
	sub		di,		80
	mov		word[es:di],	ax
	cmp		di,		244 ;5 row, 4 char
	jne		.lp_up

	mov		si,		game_end_str
	mov		di,		GAME_END_STR_POS
	call	draw_text

	mov		di,		DRAW_END_STR_POS
	call	draw_text

	mov		di,		DRAW_END_STR2_POS
	jmp		draw_text

draw_wall:
	mov		ax,		0x0723	;bg=black, fg=gray, char='#'
	mov		cx,		VGA_WIDTH
	xor		di,		di
	rep		stosw	;ax -> es:di

.lp_right2:
	add		di,		78
	stosw
	cmp		di,		VGA_PAGE_SIZE
	jne		.lp_right2

	mov		di,		VGA_ROW_SIZE	;1-st row pos
.lp_left:
	stosw
	add		di,		VGA_ROW_SIZE - 2
	cmp		di,		FINAL_ROW_POS
	jne		.lp_left

	mov		cx,		VGA_ROW_SIZE
	rep		stosw	;ax -> es:di

	mov		di,		ROW_SIZE - 2
.lp_right:
	stosw
	add		di,		VGA_ROW_SIZE - 2
	cmp		di,		FINAL_ROW_POS
	jle		.lp_right

	mov		si,		score_str
	mov		di,		SCORE_STR_POS
	jmp		draw_text

;-----------------------------------------------------------------------------
data_table_wasd:
	db		SNAKE_TO_DOWN	;0, up
	times 12 db 0
	db		SNAKE_TO_RIGHT	;1, left
	db		SNAKE_TO_UP		;2, down
	db		SNAKE_TO_LEFT	;3, right
data_table_arrow:
	db		SNAKE_TO_DOWN	;0, up
	db		SNAKE_TO_RIGHT	;1, left
	db		SNAKE_TO_UP		;2, down
	db		SNAKE_TO_LEFT	;3, right
;-----------------------------------------------------------------------------
score_str db "SCORE", 0
	SCORE_STR_POS  equ 146
speed_choose_str db "Choose game speed", 0
	SPEED_CHOOSE_STR_POS equ 342 ;4 row, 11 char

speed_mode_str_1 db "1) very fast", 0
	SPEED_MODE_STR_1_POS equ 648 ;8 row, 4 char

speed_mode_str_2 db "2) fast", 0
	SPEED_MODE_STR_2_POS equ 808 ;10 row, 4 char

speed_mode_str_3 db "3) medium", 0
	SPEED_MODE_STR_3_POS equ 968 ;12 row, 4 char

speed_mode_str_4 db "4) slow", 0
	SPEED_MODE_STR_4_POS equ 1128 ;14 row, 4 char

speed_mode_str_5 db "5) very slow", 0
	SPEED_MODE_STR_5_POS equ 1288 ;16 row, 4 char
speed_str_addresses:
	dw SPEED_CHOOSE_STR_POS
	dw SPEED_MODE_STR_1_POS
	dw SPEED_MODE_STR_2_POS
	dw SPEED_MODE_STR_3_POS
	dw SPEED_MODE_STR_4_POS
	dw SPEED_MODE_STR_5_POS
speed_frequency_data_table:
	db		0x80
	db		0xA0
	db		0xB0
	db		0xC0
	db		0xF0
;-----------------------------------------------------------------------------
game_end_str db "You lose", 0
	GAME_END_STR_POS equ 344 ;4 row, 11 char

draw_end_str db "For restart push ENTER", 0
	DRAW_END_STR_POS equ 490 ;6 row, 5 char

draw_end_str2 db "For exit push ESC", 0
	DRAW_END_STR2_POS equ 654 ;8 row, 7 char
;-----------------------------------------------------------------------------
divisor_vga_row_size dw VGA_ROW_SIZE

BSS_START equ $

score_uint_str equ BSS_START
;score_uint_str times 5 db 0
score equ BSS_START + 5
;score dw 0
	SCORE_POS  equ 226
fruit_pos equ BSS_START + 7
;fruit_pos dw 0
snake_pos equ BSS_START + 9
;snake_pos dw 0 ;SNAKE_POS_DEFAULT ;x=16,y=15,vga_char_size=2
snake_direction equ BSS_START + 11
;snake_direction dw 0;SNAKE_TO_STOP
game_end equ BSS_START + 13
;game_end db 0
snake_poses equ BSS_START + 14
