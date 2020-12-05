bits 16
%include "kernel.inc"
tty_start:
	mov		ax,		VGA_BUFFER
	mov		es,		ax
	mov		byte[vga_color], 0x07

	call	vga_clear_screen
	
	mov		si,		HELLO_MSG
	mov		cx,		HELLO_MSG_SIZE
	call	tty_print_ascii

	call	tty_print_path
.input:
	call	wait_keyboard_input
	cmp		al,		0x1C ;scancode enter
	jne		.not_enter
	call	tty_push_enter
	jmp		.input
.not_enter:
	cmp		al,		0x0E ;scancode backspace
	jne		.not_backspace
	call	tty_push_backspace
	jmp		.input
.not_backspace:
	cmp		al,		SCANCODE_OS_MAKE_PG_UP
	jne		.not_page_up
	call	vga_page_up
	jmp		.input
.not_page_up:
	cmp		al,		SCANCODE_OS_MAKE_PG_DOWN
	jne		.not_page_down
	call	vga_page_down
	jmp		.input
.not_page_down:
	call	scancode_to_ascii
	call	tty_putchar_ascii

	jmp		.input
	retn

tty_putchar_ascii:
;in:  al = ASCII
;out: ax = vga_char (al = ASCII, ah = color)
;	  bx = word[vga_pos_cursor]
	test	al,		al
	je		.end
	cmp		al,		0x0A	;'\n'
	je		.new_line
	mov		ah,		byte[vga_color]
	mov		bx,		word[vga_pos_cursor]
	mov		word[es:bx],	ax
	add		word[vga_pos_cursor], VGA_CHAR_SIZE
	call	vga_cursor_move
.end:
	retn
.new_line:
	pusha
	call	tty_next_row
	popa
	retn

tty_print_ascii:
;in:  si = ptr to str
;	  cx = len of str
;out: si = end of str
;	  cx = 0
;	  ax = vga_char of last symbol in si (al = ASCII, ah = color)
;	  bx = word[vga_pos_cursor]
.lp:
	lodsb	;al <- ds:si
	call	tty_putchar_ascii
	loop	.lp
	retn

tty_next_row_div_v db 160
tty_next_row:
;in:  
;out: al = bh
;	  bx = word[vga_pos_cursor]
;	  cx = (num_of_row + 1) * 32
;	  dx = 0x03D5
;need calc the row now, inc and mul to 80 * VGA_CHAR_SIZE
	mov		ax,		word[vga_pos_cursor]
	div		byte[tty_next_row_div_v]
	xor		ah,		ah

	inc		ax

	shl		ax,		5
	mov		cx,		ax
	shl		ax,		2
	add		ax,		cx

	mov		word[vga_pos_cursor],	ax
	mov		word[tty_input_start],	ax

	mov		bx,		ax
	call	vga_cursor_move.without_get_pos_cursor
	retn

get_tty_input_ascii:
;in:  di = addr where save ascii
;	  es = segment where save ascii
;out: si = str
;	  cx = str len
;     bp = word[tty_input_start]
	mov		si,		word[tty_input_start]
.without_get_tty_input_start:
	mov		cx,		word[vga_pos_cursor]
.without_both:
	mov		bp,		si
	push	ds

	mov		ax,		VGA_BUFFER	
	mov		ds,		ax
.lp:
	lodsw	;ax (vga char)   <- ds:si, si += 2
	stosb	;al (ascii char) -> es:di, di += 1
	cmp		si,		cx
	jl		.lp

	pop		ds
;	sub		cx,		word[tty_input_start]
	sub		cx,		bp
	shr		cx,		1
	retn

tty_push_enter:
	mov		ax,		word[tty_input_start]
	cmp		ax,		word[vga_pos_cursor]
	je		.exit	;if has not input

	sub		sp,		0x400	;alloc 1024 bytes on stack

;1. save user input on stack
	mov		si,		ax	;tty_input_start
	mov		ax,		STACK_OFFSET
	mov		es,		ax
	mov		di,		sp
	call	get_tty_input_ascii.without_get_tty_input_start
	mov		ax,		VGA_BUFFER
	mov		es,		ax

	mov		si,		sp
	push	es
	push	ds
	mov		ax,		ds
	mov		es,		ax
	mov		ax,		ss
	mov		ds,		ax
	call	str_to_fat12_filename
	pop		ds
	;clear stack
	mov		ax,		ss
	mov		es,		ax
	mov		cx,		0x400
	mov		di,		sp
	add		di,		2
	xor		al,		al
	rep		stosb
	pop		es
	add		sp,		0x400	;free stack

	mov		si,		FAT12_STR
	mov		cx,		FAT12_STRLEN
	call	tty_print_ascii

	mov		si,		FAT12_STR
	call	execve
	test	ax,		ax
	je		.execve_success

	mov		si,		BAD_COMMAND_MSG
	mov		cx,		BAD_COMMAND_MSG_SIZE
	call	tty_print_ascii
.execve_success:

.exit:
	call	tty_next_row
	call	tty_print_path
	retn

tty_push_backspace:
	mov		ax,		word[tty_input_start]
	cmp		ax,		word[vga_pos_cursor]
	je		.exit
	sub		word[vga_pos_cursor],	VGA_CHAR_SIZE
	mov		al,		' '
	mov		ah,		byte[vga_color]
	mov		bx,		word[vga_pos_cursor]
	mov		word[es:bx],	ax
	call	vga_cursor_move
.exit:
	retn

tty_print_path:
	mov		si,		pre_path_now
	inc		si
	mov		byte[si],	'\'
	inc		si
	mov		word[si],	0x3A5D ;"]:"
	add		si,		2
	mov		byte[si],	' '
	mov		si,		pre_path_now
	mov		cx,		5
	call	tty_print_ascii
	mov		cx,		10
	add		word[tty_input_start], cx
	retn

HELLO_MSG db "namelessOS16 v 4", 0x0A
	HELLO_MSG_SIZE equ $-HELLO_MSG

BAD_COMMAND_MSG db 0x0A, "command not found"
	BAD_COMMAND_MSG_SIZE equ $-BAD_COMMAND_MSG

tty_input_start dw 0
pre_path_now	db '['	;dont touch!
path_now		times 83 db 0 ;80 on path and 3 to "]: "
