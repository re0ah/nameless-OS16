bits 16
%include "kernel.inc"
tty_start:
	mov		ax,		VGA_BUFFER
	mov		es,		ax		;es - video segment now
	mov		byte[vga_color], 0x07

	call	vga_clear_screen

	mov		si,		HELLO_MSG
	mov		cx,		HELLO_MSG_SIZE
	call	tty_print_ascii

	call	tty_next_row
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
	mov		ah,		byte[vga_color]
	mov		bx,		word[vga_pos_cursor]
	mov		word[es:bx],	ax
	add		word[vga_pos_cursor], VGA_CHAR_SIZE
	call	vga_cursor_move
.end:
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

tty_next_row:
;in:  
;out: al = bh
;	  bx = word[vga_pos_cursor]
;	  cx = (num_of_row + 1) * 32
;	  dx = 0x03D5
;need calc the row now, inc and mul to 80 * VGA_CHAR_SIZE
	mov		ax,		word[vga_pos_cursor]
	mov		bl,		160
	div		bl
	and		ax,		0x00FF

	inc		ax

	;mov		bl,		160
	;mul		bl
	shl		ax,		5
	mov		cx,		ax
	shl		ax,		2
	add		ax,		cx

	mov		word[vga_pos_cursor],	ax
	mov		word[tty_input_start],	ax
	
	call	vga_cursor_move
	retn

get_tty_input_ascii:
;in:  di = addr where save ascii
;	  es = segment where save ascii
;out: si = str
;	  cx = str len
;vga_pos_cursor  dw 0
;vga_color	    db 0
;tty_input_start dw 0
;path_now		db 0
	push	ds

	mov		cx,		word[vga_pos_cursor]
	mov		si,		word[tty_input_start]
	mov		ax,		VGA_BUFFER	
	mov		ds,		ax
.lp:
	lodsw	;ax (vga char)   <- ds:si, si += 2
	stosb	;al (ascii char) -> es:di, di += 1
	cmp		si,		cx
	jl		.lp

	pop		ds
	sub		cx,		word[tty_input_start]
	shr		cx,		1
	retn

tty_push_enter:
	mov		ax,		word[tty_input_start]
	cmp		ax,		word[vga_pos_cursor]
	je		.exit	;if has not input

	sub		sp,		0x400	;alloc 1024 bytes on stack

;1. save user input on stack
	mov		ax,		STACK_OFFSET
	mov		es,		ax
	mov		di,		sp
	call	get_tty_input_ascii
	mov		ax,		VGA_BUFFER
	mov		es,		ax

	mov		si,		sp
	push	es
	push	ds
	pop		es
	push	ds
	mov		ax,		ss
	mov		ds,		ax
	call	str_to_fat12_filename
	pop		ds
	pop		es
	add		sp,		0x400	;free stack

	mov		si,		FAT12_STR
	call	execve
	test	ax,		ax
	je		.execve_success
;test input on screen
;	mov		cx,		11
;	mov		si,		FAT12_STR
;.lp:
;	mov		al,		byte[ds:si]
;	inc		si
;	call	tty_putchar_ascii
;	loop	.lp
;	mov		ax,		KERNEL_OFFSET
;	mov		ds,		ax
	call	tty_next_row
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

HELLO_MSG db "namelessOS16 v [3]"
	HELLO_MSG_SIZE equ $-HELLO_MSG

BAD_COMMAND_MSG db "command not found"
	BAD_COMMAND_MSG_SIZE equ $-BAD_COMMAND_MSG

tty_input_start dw 0
pre_path_now	db '['	;dont touch!
path_now		times 83 db 0 ;80 on path and 3 to "]: "
