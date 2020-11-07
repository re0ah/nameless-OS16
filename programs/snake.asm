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
snake_direction dw SNAKE_TO_STOP

KB_DATA_PORT   equ 0x60
KB_STATUS_PORT equ 0x64

snake:
	mov		ax,		0x0001 ;set video mode, 40x25
	int		0x10
;	mov		bx,		SYSCALL_VGA_CLEAR_SCREEN
	xor		bx,		bx
	int		0x20
	mov		bx,		SYSCALL_VGA_CURSOR_DISABLE
	int		0x20
	call	draw_wall
	mov		ax,		0x0743
	mov		bx,		SNAKE_POS_DEFAULT
	mov		word[es:bx],	ax
	mov		di,		pit_handler
	mov		bx,		SYSCALL_SET_PIT_INT
	int		0x20
	mov		ax,		0xFF00
	mov		bx,		SYSCALL_PIT_SET_FREQUENCY
	int		0x20
	mov		di,		keyboard_handler
	mov		bx,		SYSCALL_SET_KEYBOARD_INT
	int		0x20
	call	draw_score
	call	fruit_generate
.lp:
	hlt
	jmp		.lp
	mov		bx,		SYSCALL_VGA_CURSOR_ENABLE
	int		0x20
	mov		ax,		0x0003 ;set back video mode
	int		0x10
	retf

SNAKE_POS_DEFAULT equ 910
snake_pos dw SNAKE_POS_DEFAULT ;x=16,y=15,vga_char_size=2

pit_handler:
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

	call	check_wall_collision
	jcxz	.if_wall_collision
	call	check_fruit_collision
.exit:
	retn
.if_wall_collision:
	call	lose_window
	retn

divisor_vga_row_size dw VGA_ROW_SIZE
check_wall_collision:
;in:  bx=snake pos
;out: cx=1 if not collision, cx=0 if collision
	cmp		bx,		ROW_SIZE
	jl		.if_collision
	cmp		bx,		FINAL_ROW_POS
	jg		.if_collision
	xor		dx,		dx
	mov		ax,		bx
	add		ax,		18
	div		word[divisor_vga_row_size]
	test	dx,		dx
	je		.if_collision
	xor		dx,		dx
	mov		ax,		bx
	div		word[divisor_vga_row_size]
	test	dx,		dx
	je		.if_collision
	jmp		.if_not_collision
.if_collision:
	mov		word[snake_direction],	SNAKE_TO_STOP
	xor		cx,		cx
.if_not_collision:
	mov		cx,		0x01
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
	mov		bx,		SYSCALL_GET_RAND_INT
	int		0x20
	mov		bx,		ax
	and		bx,		0x0540 ;mask of arena
						   ;2000 & 1380 = 1344 = 0x540
						   ;where 1380 = arena_width(30) *
						   ;			 arena_height(23) *
						   ;			 vga_char_size(2)
						   ;where 2000 = vga_width(40) *
						   ;			 vga_height(25) *
						   ;			 vga_char_size(2)
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

keyboard_handler:
	in		al,		KB_DATA_PORT
	cmp		al,		0x01	;ESC
	jne		.if_not_esc
	mov		word[snake_direction],	SNAKE_TO_STOP
	jmp		.end
.if_not_esc:
	cmp		al,		0x11	;'W'
	jne		.if_not_up
	mov		word[snake_direction],	SNAKE_TO_UP
	jmp		.end
.if_not_up:
	cmp		al,		0x1E	;'A'
	jne		.if_not_left
	mov		word[snake_direction],	SNAKE_TO_LEFT
	jmp		.end
.if_not_left:
	cmp		al,		0x1F	;'S'
	jne		.if_not_down
	mov		word[snake_direction],	SNAKE_TO_DOWN
	jmp		.end
.if_not_down:
	cmp		al,		0x20	;'D'
	jne		.end
	mov		word[snake_direction],	SNAKE_TO_RIGHT
.end:
	mov     al,     PICM
	out     PIC_EOI, al
	iret

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
