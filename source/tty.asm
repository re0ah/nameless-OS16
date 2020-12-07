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
;out: if al == 0, then:
;		 al = 0
;	  if al == 0x0A, then:
;		 al = bh
;		 bx = word[vga_pos_cursor] / 2
;		 cx = (num_of_row + 1) * 80
;		 dx = 0x03D5
;	  else:
;		 ah = byte[vga_color]
;		 al = bh
;		 bx = word[vga_pos_cursor] / 2
;		 dx = 0x03D5
	test	al,		al
	je		.end
	cmp		al,		0x0A	;'\n'
	je		.new_line
	mov		ah,		byte[vga_color]		;ax vga_char now
	mov		bx,		word[vga_pos_cursor]
	mov		word[es:bx],	ax			;print in video buffer
	add		bx,		VGA_CHAR_SIZE
	mov		word[vga_pos_cursor], bx
	call	vga_cursor_move.without_get_pos_cursor_with_div
.end:
	retn
.new_line:
	call	tty_next_row
	retn

tty_print_ascii:
;in:  si = ptr to str
;	  cx = len of str
;out: if last_char == 0, then:
;		 al = 0
;		 si = end of str
;		 cx = 0
;	  if last_char == 0x0A, then:
;		 al = bh
;		 bx = word[vga_pos_cursor] / 2
;		 cx = (num_of_row + 1) * 80
;		 dx = 0x03D5
;		 si = end of str
;	  else:
;		 ah = byte[vga_color]
;		 al = bh
;		 bx = word[vga_pos_cursor] / 2
;		 dx = 0x03D5
;		 si = end of str
;		 cx = 0
.lp:
	lodsb	;al <- ds:si
	push	cx
	call	tty_putchar_ascii
	pop		cx
	loop	.lp
	retn

tty_next_row_div_v db 160
tty_next_row:
;in:  
;out: al = bh
;	  bx = word[vga_pos_cursor] / 2
;	  cx = (num_of_row + 1) * 80
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
;     bx = word[tty_input_start]
;	  al = 0
	mov		si,		word[tty_input_start]
.without_get_tty_input_start:
	mov		cx,		word[vga_pos_cursor]
.without_both:
	mov		bx,		si
	push	es
	mov		ax,		STACK_OFFSET
	mov		es,		ax
	push	ds

	xor		bp,		bp		;for args
	mov		ax,		VGA_BUFFER	
	mov		ds,		ax
.lp:
	lodsw	;ax (vga char)   <- ds:si, si += 2
	cmp		al,		' '
	jne		.not_space
	test	bp,		bp
	jne		.already_set
	lea		bp,		[di + 1] ;set bp after space now
.already_set:
.not_space:
	stosb	;al (ascii char) -> es:di, di += 1
	cmp		si,		cx
	jl		.lp
	xor		al,		al
	stosb

	pop		ds
	pop		es
	retn

tty_push_enter:
;it's very very very bad code kill me
	mov		ax,		word[tty_input_start]
	mov		cx,		word[vga_pos_cursor]
	cmp		ax,		cx
	je		.exit	;if has not input
	mov		dx,		cx	;len of input
	sub		dx,		ax
	shr		dx,		1

	sub		sp,		dx		;alloc dx bytes on stack
	sub		sp,		6

;1. save user input on stack
	mov		si,		ax	;word[tty_input_start]
	mov		di,		sp
	call	get_tty_input_ascii.without_both

	mov		si,		sp
	mov		cx,		dx
	push	dx
	push	es
	push	ds
	mov		ax,		ds
	mov		es,		ax
	mov		ax,		ss
	mov		ds,		ax
	call	str_to_fat12_filename
	pop		ds
	pop		es

;	mov		si,		FAT12_STR
;	mov		cx,		FAT12_STRLEN
;	call	tty_print_ascii

	mov		si,		FAT12_STR
	call	execve
	mov		bp,		ax
	pop		dx
	;clear stack
	mov		di,		sp
	push	es
	mov		ax,		ss
	mov		es,		ax
	mov		cx,		dx
	xor		al,		al
	rep		stosb
	pop		es
	add		sp,		dx
	add		sp,		6

	mov		ax,		bp
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
