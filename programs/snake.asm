%include "../source/syscall.inc"

VGA_START_ADDR  equ 0xB800
VGA_WIDTH       equ 80
VGA_HEIGHT      equ 25
VGA_CHAR_SIZE   equ 2 ;bytes
VGA_PAGE_NUM_CHARS equ VGA_WIDTH * VGA_HEIGHT ;2000 chars
FINAL_ROW_POS	equ 3840
ROW_SIZE		equ VGA_CHAR_SIZE * VGA_WIDTH

snake:
	mov		ah,		SYSCALL_CLEAR_SCREEN
	int		0x20
	mov		ah,		SYSCALL_CURSOR_HIDE
	int		0x20
	call	draw_wall
	retf

draw_wall:
	mov		ax,		0x0723	;bg=black, fg=gray, char='#'
	mov		cx,		VGA_WIDTH
	xor		di,		di
	rep		stosw	;ax -> es:di

	mov		di,		ROW_SIZE	;1-st row pos
.lp_left:
	mov		word[es:di],	ax
	add		di,		ROW_SIZE
	cmp		di,		FINAL_ROW_POS
	jne		.lp_left

	mov		cx,		VGA_WIDTH
	rep		stosw	;ax -> es:di

	mov		di,		ROW_SIZE - 2
.lp_right:
	mov		word[es:di],	ax
	add		di,		ROW_SIZE
	cmp		di,		FINAL_ROW_POS - 2
	jle		.lp_right
	retn

snake_pos dw 486 ;x=3,y=3,vga_char_size=2
