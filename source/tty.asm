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

bits 16
tty_start:
;set vga buffer, segment es since he is pair with
;di, and it allow easy write data to VRAM
	push	VGA_BUFFER
	pop		es
;	mov		byte[vga_color], 0x07 ;bg: black, fg: gray

	call	vga_clear_screen

	mov		si,		HELLO_MSG
	call	tty_print_ascii_c
	call	tty_print_path
	mov		ax,		word[tty_input_start]
	mov		word[tty_input_end],	ax
	xor		ax,		ax
	mov		word[vga_offset_now],	ax

.input:
	call	wait_keyboard_input

	push	.input	;return address from function

	cmp		al,		0x1C ;scancode enter
	je		tty_push_enter

	cmp		al,		0x0E ;scancode backspace
	je		tty_push_backspace

	cmp		al,		SCANCODE_OS_MAKE_LEFT_ARROW
	je		tty_push_left_arrow

	cmp		al,		SCANCODE_OS_MAKE_RIGHT_ARROW
	je		tty_push_right_arrow

	cmp		al,		SCANCODE_OS_MAKE_PG_UP
	je		vga_line_up

	cmp		al,		SCANCODE_OS_MAKE_PG_DOWN
	je		vga_line_down

	call	scancode_to_ascii
	jmp		tty_putchar_ascii

tty_push_left_arrow:
	mov		ax,		word[tty_input_start]
	mov		bx,		word[vga_pos_cursor]
	cmp		ax,		bx
	je		.exit
	dec		bx
	dec		bx
	mov		word[vga_pos_cursor],	bx
	jmp		vga_cursor_move.without_get_pos_cursor_with_div
.exit:
	retn

tty_push_right_arrow:
	mov		ax,		word[tty_input_end]
	mov		bx,		word[vga_pos_cursor]
	cmp		ax,		bx
	je		.exit
	inc		bx
	inc		bx
	mov		word[vga_pos_cursor],	bx
	jmp		vga_cursor_move.without_get_pos_cursor_with_div
.exit:
	retn

tty_putchar_ascii:
;in:  al = ASCII
;out: if al == 0, then:
;		 al = 0
;	  if al == 0x0A, then:
;		 al = bh
;		 bx = word[vga_pos_cursor] / 2
;		 dx = 0x03D5
;	  else:
;		 ah = byte[vga_color]
;		 al = bh
;		 bx = word[vga_pos_cursor] / 2
;		 dx = 0x03D5
	test	al,		al
	je		.end
	cmp		al,		0x0A	;'\n'
	je		tty_next_row
	mov		ah,		byte[vga_color]		;ax vga_char now
	mov		bx,		word[vga_pos_cursor]

	pusha
	mov		bp,		word[tty_input_end]
	cmp		bx,		bp
	je		.left_move_to_right
	inc		bp
	inc		bp
.move_to_right:
	mov		ax,		word[es:bp - 2]
	mov		word[es:bp],	ax
	dec		bp
	dec		bp
	cmp		bp,		bx
	jne		.move_to_right

.left_move_to_right:
	mov		ax,		word[vga_pos_cursor]
	sub		ax,		3840
	jle		.exit_positioning
	call	vga_positioning_to_bottom
.exit_positioning:
	popa

	mov		bx,		word[vga_pos_cursor]
	mov		word[es:bx],	ax			;print in video buffer
	add		word[vga_pos_cursor],	2
	add		word[tty_input_end],	2
	call	vga_cursor_move

	mov     ax,		word[vga_memory_size]
	sub		ax,		160
	cmp		word[vga_pos_cursor],	ax
	jle		.not_free
	call	vga_free_top_line
.not_free:
.end:
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
;		 dx = 0x03D5
;		 si = end of str
;		 cx = 0
;	  else:
;		 ah = byte[vga_color]
;		 al = bh
;		 bx = word[vga_pos_cursor] / 2
;		 dx = 0x03D5
;		 si = end of str
;		 cx = 0
.lp:
	lodsb	;al <- ds:si
	call	tty_putchar_ascii
	loop	.lp
	retn

tty_print_ascii_c:
;in:  si = ptr to str what end with \0
;out: al = 0
;	  ah = byte[vga_color]
;	  bx = word[vga_pos_cursor] / 2
;	  dx = 0x03D5
;	  si = end of str
.lp:
	lodsb	;al <- ds:si
	test	al,		al
	je		.end
	call	tty_putchar_ascii
	jmp		.lp
.end:
	retn

tty_next_row:
;in:  
;out: 
;	  ah = high byte of word[vga_pos_cursor] & word[tty_input_start]
;	  al = bh
;	  bx = word[vga_pos_cursor] / 2
;	  dx = 0x03D5
;need calc the row now, inc and mul to 80 * VGA_CHAR_SIZE
	mov		ax,		word[vga_pos_cursor]
	div		byte[vga_bytes_in_row]
	xor		ah,		ah
	inc		ax

	mul		byte[vga_bytes_in_row]

	mov		word[vga_pos_cursor],	ax
	mov		word[tty_input_start],	ax
	mov		word[tty_input_end],	ax

	jmp		vga_cursor_move

get_tty_input_ascii:
;in:  di = addr on stack where save ascii
;out: si = end of str
;	  cx = str len
;	  al = 0
;save ascii input from VRAM to ss:di
	mov		si,		word[tty_input_start]
.without_get_tty_input_start:
	mov		cx,		word[vga_pos_cursor]
.without_both:
	xor		bp,		bp		;word[argv_ptr]
.copy:
	mov		ax,		word[es:si]
	add		si,		VGA_CHAR_SIZE
	mov		byte[ss:di],	al
	inc		di
	cmp		al,		' '
	jne		.not_space
	test	bp,		bp
	jne		.already_set
	mov		bp,		di
	mov		word[argv_ptr], di
.already_set:
.not_space:
	cmp		si,		cx
	jl		.copy
;argv_ptr ending with 0
	xor		al,		al
	mov		byte[ss:di], al
	retn

tty_push_enter:
	mov		ax,		word[tty_input_start]
	mov		cx,		word[tty_input_end]
	cmp		ax,		cx
	je		.exit	;if has not input
;calc len of input
	mov		dx,		cx
	sub		dx,		ax
	shr		dx,		1	;need div on 2 because values above - positions on
						;VGA memory with VGA_CHAR_SIZE 2 bytes.

	sub		sp,		dx		;alloc dx bytes on stack
	sub		sp,		6		;also alloc 6 bytes for push segments further

;1. save user input on stack
	mov		si,		ax	;word[tty_input_start]
	mov		di,		sp
	call	get_tty_input_ascii.without_both

	mov		si,		sp
	mov		cx,		dx
	push	dx ;save for restore after execve and clean stack
	push	es ;save for restore after str_to_fat12_filename
	push	ds ;save for restore after str_to_fat12_filename
	;es = ds
	push	ds
	pop		es
	;ds = ss
	push	ss
	pop		ds
	call	str_to_fat12_filename
	pop		ds
	pop		es

;	mov		si,		FAT12_STR
;	mov		cx,		FAT12_STRLEN
;	call	tty_print_ascii

;	mov		si,		FAT12_STR ;already in si after str_to_fat12_filename call
	call	execve
	pop		dx		;for clean stack
;clean stack
	mov		di,		sp
	push	es
	push	ss
	pop		es
	mov		cx,		dx
	xor		al,		al
	rep		stosb
	pop		es
;free stack
	add		sp,		dx
	add		sp,		6

	mov		ax,		word[last_exit_status]
	cmp		ax,		FAT12_ENTRY_NOT_FOUND
	je		.not_found
;	test	ax,		ax
;	je		.execve_success
.error_success:
	jmp		.exit
.not_found:
	mov		si,		PROGRAM_NOT_FOUND
	call	tty_print_ascii_c

.execve_success:
.exit:
	call	tty_next_row
	jmp		tty_print_path

tty_push_backspace:
;in:  
;out: al = bh
;	  bx = word[vga_pos_cursor] / 2
;	  cx = (num_of_row + 1) * 80
;	  dx = 0x03D5
;if start of input equal current position cursor then don't moving cursor
	mov		ax,		word[tty_input_start]
	mov		bx,		word[vga_pos_cursor]
	cmp		ax,		bx
	je		.exit
;shifting pos cursor on 1 char and fill these position with space

	pusha
	mov		bx,		word[tty_input_end]
	mov		bp,		word[vga_pos_cursor]
	dec		bp
	dec		bp
.move_to_left:
	mov		ax,		word[es:bp + 2]
	mov		word[es:bp],	ax
	inc		bp
	inc		bp
	cmp		bp,		bx
	jne		.move_to_left
	popa
	
	dec		word[vga_pos_cursor]
	dec		word[vga_pos_cursor]
	dec		word[tty_input_end]
	dec		word[tty_input_end]
	jmp		vga_cursor_move
.exit:
	retn

tty_print_path:
	mov		si,		pre_path_now
	call	tty_print_ascii_c
	add		word[tty_input_start], 10
	retn

