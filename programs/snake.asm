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
	mov		bx,		SYSCALL_PIT_SET_FREQUENCY
	int		0x20
	mov		bx,		SYSCALL_VGA_CLEAR_SCREEN
	int		0x20
	call	draw_wall
	mov		di,		pit_handler
	mov		bx,		SYSCALL_SET_PIT_INT
	int		0x20
	call	draw_score
	call	fruit_generate
	mov		byte[game_end],	0
.lp:
	sti
	hlt
	cli
	movzx	cx,		byte[game_end]
	jcxz	.lp
.if_lose:
	sti
	call	draw_menu
	mov		si,		game_end_str
	mov		di,		GAME_END_STR_POS
	mov		cx,		GAME_END_STR_LEN
	rep		movsw

	mov		si,		draw_end_str
	mov		di,		DRAW_END_STR_POS
	mov		cx,		DRAW_END_STR_LEN
	rep		movsw

	mov		si,		draw_end_str2
	mov		di,		DRAW_END_STR2_POS
	mov		cx,		DRAW_END_STR2_LEN
	rep		movsw
.wait_keyboard_data:
	hlt
	mov		bx,		SYSCALL_GET_KEYBOARD_DATA
	int		0x20
	test	al,		al
	je		.wait_keyboard_data
	cmp		al,		0x1C	;scancode enter
	jne		.not_enter
	mov		word[snake_pos], SNAKE_POS_DEFAULT
	mov		word[snake_direction], SNAKE_TO_STOP
	mov		word[score],	0
	jmp		.start
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

game_end db 0

SNAKE_POS_DEFAULT equ 910
snake_pos dw SNAKE_POS_DEFAULT ;x=16,y=15,vga_char_size=2
snake_direction dw SNAKE_TO_STOP

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
	mov		cx,		0x0720
	mov		word[es:bx],	cx

	add		bx,		word[snake_direction]
	mov		word[snake_pos], bx
	mov		ax,		0x0743
	mov		word[es:bx],	ax
.exit:
	retn

divisor_vga_row_size dw VGA_ROW_SIZE
check_wall_collision:
;in:  bx=snake pos
	mov		bx,		word[snake_pos]
	cmp		bx,		ROW_SIZE ;check up border
	jl		.lose

	cmp		bx,		FINAL_ROW_POS ;check bottom border
	jge		.lose

	xor		dx,		dx ;check right border
	mov		ax,		bx
	add		ax,		18
	div		word[divisor_vga_row_size]
	test	dx,		dx
	je		.lose

	xor		dx,		dx ;check left border
	mov		ax,		bx
	div		word[divisor_vga_row_size]
	test	dx,		dx
	je		.lose
	retn
.lose:
	mov		byte[game_end],		1
	retn

fruit_pos dw 0
fruit_generate:
	mov		ah,		0x02
	int		0x1A		;read time
	mov		ah,		cl
	mov		al,		dh
	or		ax,		0x0001
	mov		bx,		SYSCALL_SET_RAND_SEED
	int		0x20
.again_get_y:
	mov		bx,		SYSCALL_GET_RAND_INT
	int		0x20
	and		ax,		0x0016
	test	ax,		ax
	je		.again_get_y
	shl		ax,		4
	mov		cx,		ax	;y pos, need mul to 80
	shl		cx,		2
	add		cx,		ax
.again_get_x:
	mov		bx,		SYSCALL_GET_RAND_INT
	int		0x20
	and		ax,		0x001E
	shl		ax,		1
	test	ax,		ax
	je		.again_get_x
	add		ax,		cx	;x pos
	cmp		ax,		word[fruit_pos]
	je		fruit_generate
	mov		bx,		ax
	mov		word[fruit_pos],	bx
	mov		ax,		0x0746	;black bg, gray fg, char=F
	mov		word[es:bx],	ax
	retn

check_fruit_collision:
;in: bx=snake pos
	cmp		bx,		word[fruit_pos]
	jne		.collision_false
	call	fruit_generate
	inc		word[score]
	call	draw_score
.collision_false:
	retn

keyboard_routine:
	mov		bx,		SYSCALL_GET_KEYBOARD_DATA
	int		0x20
	test	al,		al
	je		.end

	cmp		al,		0x01 ;ESC
	je		.pause
	cmp		al,		0x20 ;scancode D
	ja		.not_wasd
.wasd:
	movzx	bx,		al
	sub		bx,		0x11 ;scancode W
	jl		.end
	movsx	bx,		byte[.data_table_wasd + bx]
	test	bx,		bx
	jne		.processing
	retn
.not_wasd:
	movzx	bx,		al
	cmp		bx,		0xEC
	ja		.end
	sub		bx,		0xE9
	jl		.end
	movsx	bx,		byte[.data_table_arrow + bx]
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
.data_table_wasd:
	db		SNAKE_TO_DOWN	;0, up
	times 12 db 0
	db		SNAKE_TO_RIGHT	;1, left
	db		SNAKE_TO_UP		;2, down
	db		SNAKE_TO_LEFT	;3, right
.data_table_arrow:
	db		SNAKE_TO_DOWN	;0, up
	db		SNAKE_TO_RIGHT	;1, left
	db		SNAKE_TO_UP		;2, down
	db		SNAKE_TO_LEFT	;3, right

score_str db "S", 0x07, "C", 0x07, "O", 0x07, "R", 0x07, "E", 0x07
	SCORE_STR_SIZE equ $-score_str
	SCORE_STR_LEN  equ SCORE_STR_SIZE / 2
	SCORE_STR_POS  equ 146
score dw 0
	SCORE_POS  equ 226
score_uint_str times 5 db 0
draw_score:
	push	bx
	mov		ax,		word[score]
	mov		si,		score_uint_str
	mov		bx,		SYSCALL_UINT_TO_ASCII
	int		0x20
	pop		bx

	shl		cx,		1
	add		cx,		SCORE_POS
	
	mov		ah,		0x07
	mov		di,		SCORE_POS
.lp:
	mov		al,		byte[ds:si]
	mov		word[es:di],	ax
	inc		si
	add		di,		2
	cmp		di,		cx
	jne		.lp
	retn

speed_choose_str db "C", 0x07, "h", 0x07, "o", 0x07, "o", 0x07, "s", 0x07
				 db "e", 0x07, " ", 0x07, "g", 0x07, "a", 0x07, "m", 0x07
				 db "e", 0x07, " ", 0x07, "s", 0x07, "p", 0x07, "e", 0x07
				 db "e", 0x07, "d", 0x07
	SPEED_CHOOSE_STR_SIZE equ $-speed_choose_str
	SPEED_CHOOSE_STR_LEN equ SPEED_CHOOSE_STR_SIZE / 2
	SPEED_CHOOSE_STR_POS equ 334 ;4 row, 7 char

speed_mode_str_1 db "1", 0x07, ")", 0x07, " ", 0x07, "V", 0x07, "e", 0x07
			 	 db "r", 0x07, "y", 0x07, " ", 0x07, "f", 0x07, "a", 0x07
				 db "s", 0x07, "t", 0x07
	SPEED_MODE_STR_1_SIZE equ $-speed_mode_str_1 
	SPEED_MODE_STR_1_LEN equ SPEED_MODE_STR_1_SIZE / 2
	SPEED_MODE_STR_1_POS equ 648 ;8 row, 4 char

speed_mode_str_2 db "2", 0x07, ")", 0x07, " ", 0x07, "F", 0x07, "a", 0x07
				 db "s", 0x07, "t", 0x07
	SPEED_MODE_STR_2_SIZE equ $-speed_mode_str_2 
	SPEED_MODE_STR_2_LEN equ SPEED_MODE_STR_2_SIZE / 2
	SPEED_MODE_STR_2_POS equ 808 ;10 row, 4 char

speed_mode_str_3 db "3", 0x07, ")", 0x07, " ", 0x07, "M", 0x07, "e", 0x07
			 	 db "d", 0x07, "i", 0x07, "u", 0x07, "m", 0x07
	SPEED_MODE_STR_3_SIZE equ $-speed_mode_str_3
	SPEED_MODE_STR_3_LEN equ SPEED_MODE_STR_3_SIZE / 2
	SPEED_MODE_STR_3_POS equ 968 ;12 row, 4 char

speed_mode_str_4 db "4", 0x07, ")", 0x07, " ", 0x07, "S", 0x07, "l", 0x07
			 	 db "o", 0x07, "w", 0x07
	SPEED_MODE_STR_4_SIZE equ $-speed_mode_str_4
	SPEED_MODE_STR_4_LEN equ SPEED_MODE_STR_4_SIZE / 2
	SPEED_MODE_STR_4_POS equ 1128 ;14 row, 4 char

speed_mode_str_5 db "5", 0x07, ")", 0x07, " ", 0x07, "V", 0x07, "e", 0x07
			 	 db "r", 0x07, "y", 0x07, " ", 0x07, "s", 0x07, "l", 0x07
				 db "o", 0x07, "w", 0x07
	SPEED_MODE_STR_5_SIZE equ $-speed_mode_str_5
	SPEED_MODE_STR_5_LEN equ SPEED_MODE_STR_5_SIZE / 2
	SPEED_MODE_STR_5_POS equ 1288 ;16 row, 4 char
choose_snake_speed:
	mov		si,		speed_choose_str
	mov		di,		SPEED_CHOOSE_STR_POS
	mov		cx,		SPEED_CHOOSE_STR_LEN
	rep		movsw

	mov		ax,		0x0723	;bg=black, fg=gray, char='#'
	mov		cx,		34
	mov		di,		486	;6 row, 3 char
	rep		stosw	;ax -> es:di

	mov		ax,		0x0723	;bg=black, fg=gray, char='#'
	mov		cx,		36
	mov		di,		164	;3 row, 3 char
	rep		stosw	;ax -> es:di

	sub		di,		2
.lp_right:
	add		di,		80
	mov		word[es:di],	ax
	cmp		di,		1834 ;22 row, 37 char
	jne		.lp_right

.lp_left:
	sub		di,		2
	mov		word[es:di],	ax
	cmp		di,		1764 ;22 row, 3 char
	jne		.lp_left

.lp_up:
	sub		di,		80
	mov		word[es:di],	ax
	cmp		di,		244 ;5 row, 4 char
	jne		.lp_up

	mov		si,		speed_mode_str_1
	mov		di,		SPEED_MODE_STR_1_POS
	mov		cx,		SPEED_MODE_STR_1_LEN
	rep		movsw

	mov		si,		speed_mode_str_2
	mov		di,		SPEED_MODE_STR_2_POS
	mov		cx,		SPEED_MODE_STR_2_LEN
	rep		movsw

	mov		si,		speed_mode_str_3
	mov		di,		SPEED_MODE_STR_3_POS
	mov		cx,		SPEED_MODE_STR_3_LEN
	rep		movsw

	mov		si,		speed_mode_str_4
	mov		di,		SPEED_MODE_STR_4_POS
	mov		cx,		SPEED_MODE_STR_4_LEN
	rep		movsw

	mov		si,		speed_mode_str_5
	mov		di,		SPEED_MODE_STR_5_POS
	mov		cx,		SPEED_MODE_STR_5_LEN
	rep		movsw
.wait_keyboard_data:
	hlt
	mov		bx,		SYSCALL_GET_KEYBOARD_DATA
	int		0x20
	sub		al,		2 ;scancode '1'
	cmp		al,		0
	jl		.wait_keyboard_data
	cmp		al,		4
	ja		.wait_keyboard_data

	movzx	bx,		al
	xor		al,		al
	mov		ah,		byte[.data_table + bx]
	retn
.data_table:
	db		0x90
	db		0xA0
	db		0xC0
	db		0xB0
	db		0xF0

game_end_str db "Y", 0x07, "o", 0x07, "u", 0x07, " ", 0x07, "l", 0x07
			 db "o", 0x07, "s", 0x07, "e", 0x07
	GAME_END_STR_SIZE equ $-game_end_str
	GAME_END_STR_LEN  equ GAME_END_STR_SIZE / 2
	GAME_END_STR_POS equ 344 ;4 row, 11 char
draw_end_str db "F", 0x07, "o", 0x07, "r", 0x07, " ", 0x07, "r", 0x07
			 db "e", 0x07, "s", 0x07, "t", 0x07, "a", 0x07, "r", 0x07,
			 db "t", 0x07, " ", 0x07, "p", 0x07, "u", 0x07, "s", 0x07,
			 db "h", 0x07, " ", 0x07, "E", 0x07, "N", 0x07, "T", 0x07,
			 db "E", 0x07, "R", 0x07
	DRAW_END_STR_SIZE equ $-draw_end_str
	DRAW_END_STR_LEN  equ DRAW_END_STR_SIZE / 2
	DRAW_END_STR_POS equ 490 ;6 row, 5 char
draw_end_str2 db "F", 0x07, "o", 0x07, "r", 0x07, " ", 0x07, "e", 0x07
			  db "x", 0x07, "i", 0x07, "t", 0x07, " ", 0x07, "p", 0x07,
			  db "u", 0x07, "s", 0x07, "h", 0x07, " ", 0x07, "E", 0x07,
			  db "S", 0x07, "C", 0x07
	DRAW_END_STR2_SIZE equ $-draw_end_str2
	DRAW_END_STR2_LEN  equ DRAW_END_STR2_SIZE / 2
	DRAW_END_STR2_POS equ 654 ;8 row, 7 char
draw_menu:
	mov		ax,		0x0723	;bg=black, fg=gray, char='#'
	mov		cx,		28
	mov		di,		164	;3 row, 3 char
	rep		stosw	;ax -> es:di

	sub		di,		2
.lp_right:
	add		di,		80
	mov		word[es:di],	ax
	cmp		di,		1818 ;22 row, 29 char
	jne		.lp_right

.lp_left:
	sub		di,		2
	mov		word[es:di],	ax
	cmp		di,		1764 ;22 row, 3 char
	jne		.lp_left

.lp_up:
	sub		di,		80
	mov		word[es:di],	ax
	cmp		di,		244 ;5 row, 4 char
	jne		.lp_up
	retn

draw_wall:
	mov		ax,		0x0723	;bg=black, fg=gray, char='#'
	mov		cx,		VGA_WIDTH
	xor		di,		di
	rep		stosw	;ax -> es:di

	sub		di,		2
.lp_right2:
	add		di,		80
	mov		word[es:di],	ax
	cmp		di,		VGA_PAGE_SIZE - VGA_CHAR_SIZE
	jne		.lp_right2

	mov		di,		VGA_ROW_SIZE	;1-st row pos
.lp_left:
	mov		word[es:di],	ax
	add		di,		VGA_ROW_SIZE
	cmp		di,		FINAL_ROW_POS
	jne		.lp_left

	mov		cx,		VGA_ROW_SIZE
	rep		stosw	;ax -> es:di

	mov		di,		ROW_SIZE - 2
.lp_right:
	mov		word[es:di],	ax
	add		di,		VGA_ROW_SIZE
	cmp		di,		FINAL_ROW_POS
	jle		.lp_right

	mov		si,		score_str
	mov		di,		SCORE_STR_POS
	mov		cx,		SCORE_STR_LEN
	rep		movsw
	retn
