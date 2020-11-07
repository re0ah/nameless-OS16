PICM				equ	0x20	;master PIC
PICS				equ	0xA0	;slave PIC
PIC_EOI				equ	0x20	;end of interrupt code

%include "pit.asm"
%include "keyboard.asm"

;systemcalls
load_isr:
	cli
	call	pit_init
	call	keyboard_init
	xor		ax,		ax
	mov		gs,		ax
	mov		word[gs:0x0020],	pit_int
	mov		word[gs:0x0022],	KERNEL_OFFSET
	mov		word[gs:0x0024],	keyboard_int
	mov		word[gs:0x0026],	KERNEL_OFFSET
	mov		word[gs:0x0080],	syscall
	mov		word[gs:0x0082],	KERNEL_OFFSET
	sti
	retn

pit_interrupt_handler dw pit_int
pit_interrupt_segment dw KERNEL_OFFSET
keyboard_interrupt_handler dw keyboard_int
keyboard_interrupt_segment dw KERNEL_OFFSET
save_interrupts:
	pusha
	xor		ax,		ax
	mov		gs,		ax
	mov		ax,		word[gs:0x0020]
	mov		word[pit_interrupt_handler], ax
	mov		ax,		word[gs:0x0022]
	mov		word[pit_interrupt_segment], ax
	mov		ax,		word[gs:0x0024]
	mov		word[keyboard_interrupt_handler], ax
	mov		ax,		word[gs:0x0026]
	mov		word[keyboard_interrupt_segment], ax
	popa
	retn

restore_interrupts:
	cli
	pusha
	xor		ax,		ax
	mov		gs,		ax
	mov		ax,		word[pit_interrupt_handler]
	mov		word[gs:0x0020],	ax
	mov		ax,		word[pit_interrupt_segment]
	mov		word[gs:0x0022],	ax
	mov		ax,		word[keyboard_interrupt_handler]
	mov		word[gs:0x0024],	ax
	mov		ax,		word[keyboard_interrupt_segment]
	mov		word[gs:0x0026],	ax
	popa
	sti
	retn

%include "syscall.inc"

;ah - number of function
syscall:
	add		bx,		syscall_jump_table
	push	gs
	push	ax
	mov		ax,		KERNEL_OFFSET
	mov		gs,		ax
	pop		ax
	mov		bx,		word[gs:bx]
	pop		gs
	call	bx
	iret

syscall_jump_table:
	dw		vga_clear_screen
	dw		vga_cursor_disable
	dw		vga_cursor_enable
	dw		_interrupt_vga_cursor_move
	dw		_interrupt_tty_putchar_ascii
	dw		_interrupt_tty_print_ascii
	dw		_interrupt_tty_next_row
	dw		fat12_read_root
	dw		fat12_find_entry
	dw		fat12_load_entry
	dw		_interrupt_pit_set_frequency
	dw		_interrupt_pit_get_frequency
	dw		_interrupt_wait_keyboard_input
	dw		_interrupt_scancode_to_ascii
	dw		_interrupt_int_to_ascii
	dw		_interrupt_uint_to_ascii
	dw		_interrupt_set_pit_int
	dw		_interrupt_set_keyboard_int
	dw		_interrupt_rand_int
	dw		_interrupt_set_rand_seed

_interrupt_pit_set_frequency:
;in: ax = frequency
	push	ds
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
	call	pit_set_frequency
	pop		ds
	retn

_interrupt_pit_get_frequency:
	push	ds
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
	mov		ax,		word[pit_frequency]
	pop		ds
	retn

_interrupt_vga_cursor_move:
;in:  cx = cursor position
;out: bx = word[vga_pos_cursor]
;     dx = 0x03D5
;     al = bh
	push	ds
	mov		ax,		KERNEL_OFFSET
	mov		ds,		ax
	mov		word[vga_pos_cursor],	cx
	call	vga_cursor_move
	pop		ds
	retn

_interrupt_tty_putchar_ascii:
;in:  al = ASCII
;out: ax = vga_char (al = ASCII, ah = color)
;     bx = word[vga_pos_cursor]
	test	al,		al
	je		.end
	push	ds
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
	mov		ah,		byte[vga_color]
	mov		bx,		word[vga_pos_cursor]
	mov		word[es:bx],	ax
	add		word[vga_pos_cursor], VGA_CHAR_SIZE
	call	vga_cursor_move
	pop		ds
.end:
	retn

_interrupt_tty_print_ascii:
;in:  si = ptr to str
;     cx = len of str
;out: si = end of str
;     cx = 0
;     ax = vga_char of last symbol in si (al = ASCII, ah = color)
;     bx = word[vga_pos_cursor]
	mov		ax,		ds
	mov		gs,		ax
	push	ds
	mov		ax,		KERNEL_OFFSET
	mov		ds,		ax
	mov		di,		word[vga_pos_cursor]
	mov		bx,		cx
	shl		bx,		1
	add     word[vga_pos_cursor], bx
	call    vga_cursor_move.without_get_pos_cursor
	mov     ah,     byte[vga_color]
	pop		ds
.lp:
	mov		al,		byte[gs:si]
	mov     word[es:di],    ax
	inc		si
	add		di,		2
	loop    .lp
	retn

_interrupt_tty_next_row:
;in:
;out: al = bh
;     bx = word[vga_pos_cursor]
;     cx = (num_of_row + 1) * 32
;     dx = 0x03D5
;need calc the row now, inc and mul to 80 * VGA_CHAR_SIZE
	push	ds
	mov		ax,		KERNEL_OFFSET
	mov		ds,		ax
	call	tty_next_row
	pop		ds
	retn

_interrupt_wait_keyboard_input:
	push	ds
	mov		ax,		KERNEL_OFFSET
	mov		ds,		ax

	jmp     .wait_in
.wait:
	;hlt
.wait_in:
	cmp     byte[kb_buf_pos],   0
	je      .wait

	mov     bl,     byte[kb_buf_pos]
	test    bl,     bl
	je      .end_empty
	dec     bl
	mov     byte[kb_buf_pos],   bl
	xor     bh,     bh
	add     bx,     kb_buf
	mov     al,     byte[bx]
	retn
.end_empty:
	;   mov     al,     KB_EMPTY
	xor     al,     al
	retn
	
	mov		al,		'g'

	pop		ds
	retn

_interrupt_scancode_to_ascii:
	push	ds
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
	call	scancode_to_ascii
	pop		ds
	retn

_interrupt_int_to_ascii:
	push	ds
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
	call	int_to_ascii
	pop		ds
	retn

_interrupt_uint_to_ascii:
	push	gs
	mov		bx,		KERNEL_OFFSET
	mov		gs,		bx

	push	si
	mov		di,		num_to_ascii_buf
.lp:
	xor		dx,		dx
	div		word[gs:divinder_int_to_ascii]
	test	ax,		ax
	je		.end
	mov		bx,		ax
	add		dl,		0x30
	mov		byte[gs:di],	dl
	mov		ax,		bx
	inc		di
	jmp		.lp
.end:
	add		dl,		0x30
	mov		byte[gs:di],	dl
	inc		di
	mov		cx,		di
	sub		cx,		num_to_ascii_buf
.lp2:
	dec		di
	mov		al,		byte[gs:di]
	mov		byte[ds:si],	al
	inc		si
	cmp		di,		num_to_ascii_buf
	jne		.lp2
	pop		si

	pop		gs
	retn

_interrupt_set_pit_int:
;in: di=pit_handler
	cli
	xor		ax,		ax
	mov		gs,		ax
	mov		word[gs:0x0020],	di
	mov		word[gs:0x0022],	ds
	sti
	retn

_interrupt_set_keyboard_int:
	cli
	xor		ax,		ax
	mov		gs,		ax
	mov		word[gs:0x0024],	di
	mov		word[gs:0x0026],	ds
	sti
	retn

_interrupt_rand_int:
	push	ds
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
	call	rand_int
	pop		ds
	retn

_interrupt_set_rand_seed:
	push	ds
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
	call	set_rand_seed
	pop		ds
	retn
