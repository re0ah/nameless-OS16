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
	mov		al,		0x01 ;set video mode, 40x25
						 ;why this mode? In them symbols are square, x=y
	mov		bx,		SYSCALL_VGA_SET_VIDEO_MODE
	int		0x20
	mov		bx,		SYSCALL_VGA_CLEAR_SCREEN
	xor		bx,		bx
	int		0x20
	mov		bx,		SYSCALL_VGA_CURSOR_DISABLE
	int		0x20
.start:
	call	draw_wall
	mov		di,		pit_handler
	mov		bx,		SYSCALL_SET_PIT_INT
	int		0x20
	;mov		di,		pit_handler
	m;ov		bx,		SYSCALL_SET_KEYBOARD_INT
	;int		0x20
	mov		ax,		0xFF00
	mov		bx,		SYSCALL_PIT_SET_FREQUENCY
	int		0x20
	call	draw_score
	call	fruit_generate
.lp:
	hlt
	movzx	cx,		byte[game_end]
	jcxz	.lp
.exit:
	mov		bx,		SYSCALL_VGA_CURSOR_ENABLE
	int		0x20
	mov		al,		0x03
	mov		bx,		SYSCALL_VGA_SET_VIDEO_MODE
	int		0x20
	retf

game_end db 0

SNAKE_POS_DEFAULT equ 910
snake_pos dw SNAKE_POS_DEFAULT ;x=16,y=15,vga_char_size=2
snake_direction dw SNAKE_TO_STOP

pit_handler:
	call	keyboard_routine
	call	snake_move

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

	pusha
	call	check_wall_collision
	popa
	call	check_fruit_collision
.exit:
	retn

divisor_vga_row_size dw VGA_ROW_SIZE
check_wall_collision:
;in:  bx=snake pos
	cmp		bx,		ROW_SIZE ;check up border
	jl		.lose_window

	cmp		bx,		FINAL_ROW_POS ;check bottom border
	jge		.lose_window

	xor		dx,		dx ;check right border
	mov		ax,		bx
	add		ax,		18
	div		word[divisor_vga_row_size]
	test	dx,		dx
	je		.lose_window

	xor		dx,		dx ;check left border
	mov		ax,		bx
	div		word[divisor_vga_row_size]
	test	dx,		dx
	je		.lose_window
	retn
.lose_window:
	call	lose_window
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
	cmp		al,		0x01	;ESC
	jne		.if_not_esc
	mov		word[snake_direction],	SNAKE_TO_STOP
	jmp		.end
.if_not_esc:
	cmp		al,		0x11	;'W'
	jne		.if_not_up
	cmp		word[snake_direction],	SNAKE_TO_DOWN
	je		.end
	mov		word[snake_direction],	SNAKE_TO_UP
	jmp		.end
.if_not_up:
	cmp		al,		0x1E	;'A'
	jne		.if_not_left
	cmp		word[snake_direction],	SNAKE_TO_RIGHT
	je		.end
	mov		word[snake_direction],	SNAKE_TO_LEFT
	jmp		.end
.if_not_left:
	cmp		al,		0x1F	;'S'
	jne		.if_not_down
	cmp		word[snake_direction],	SNAKE_TO_UP
	je		.end
	mov		word[snake_direction],	SNAKE_TO_DOWN
	jmp		.end
.if_not_down:
	cmp		al,		0x20	;'D'
	jne		.end
	cmp		word[snake_direction],	SNAKE_TO_LEFT
	je		.end
	mov		word[snake_direction],	SNAKE_TO_RIGHT
	jmp		keyboard_routine
.end:
	retn

score_str db "S", 0x07, "C", 0x07, "O", 0x07, "R", 0x07, "E", 0x07
	SCORE_STR_SIZE equ $-score_str
	SCORE_STR_LEN  equ SCORE_STR_SIZE / 2
	SCORE_STR_POS  equ 146
score dw 0
	SCORE_POS  equ 226
draw_score:
	push	bx
	mov		ax,		word[score]
	mov		si,		score_str
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

lose_window:
	mov		byte[game_end],		1

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
