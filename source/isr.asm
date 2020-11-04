PICM				equ	0x20	;master PIC
PICS				equ	0xA0	;slave PIC
PIC_EOI				equ	0x20	;end of interrupt code

%include "pit.asm"
%include "keyboard.asm"

;systemcalls
load_isr:
	cli
	xor		ax,		ax
	mov		gs,		ax
	call	pit_init
	call	keyboard_init
	mov		word[gs:0x0020],	pit_int
	mov		word[gs:0x0022],	KERNEL_OFFSET
	mov		word[gs:0x0024],	keyboard_int
	mov		word[gs:0x0026],	KERNEL_OFFSET
	mov		word[gs:0x0080],	syscall
	mov		word[gs:0x0082],	KERNEL_OFFSET
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
	dw		clear_screen
	dw		cursor_hide
	dw		_interrupt_cursor_move
	dw		_interrupt_vga_putchar_ascii
	dw		_interrupt_vga_print_ascii
	dw		_interrupt_vga_next_row
	dw		_interrupt_set_pit_handler
	dw		fat12_read_root
	dw		fat12_find_entry
	dw		fat12_load_entry

_interrupt_cursor_move:
;in:  cx = cursor position
;out: bx = word[vga_pos_cursor]
;     dx = 0x03D5
;     al = bh
	push	ds
	mov		ax,		KERNEL_OFFSET
	mov		ds,		ax
	mov		word[vga_pos_cursor],	cx
	call	cursor_move
	pop		ds
	retn

_interrupt_vga_putchar_ascii:
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
	call	cursor_move
	pop		ds
.end:
	retn

_interrupt_vga_print_ascii:
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
	call    cursor_move.without_get_pos_cursor
	mov     ah,     byte[vga_color]
	pop		ds
.lp:
	mov		al,		byte[gs:si]
	mov     word[es:di],    ax
	inc		si
	add		di,		2
	loop    .lp
	retn

_interrupt_vga_next_row:
;in:
;out: al = bh
;     bx = word[vga_pos_cursor]
;     cx = (num_of_row + 1) * 32
;     dx = 0x03D5
;need calc the row now, inc and mul to 80 * VGA_CHAR_SIZE
	push	ds
	mov		ax,		KERNEL_OFFSET
	mov		ds,		ax
	call	vga_next_row
	pop		ds
	retn
