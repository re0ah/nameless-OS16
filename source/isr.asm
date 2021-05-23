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

PICM	equ	0x20	;master PIC port
PICS	equ	0xA0	;slave PIC  port
PIC_EOI	equ	0x20	;end of interrupt code

IVT_ADDR_PIT_FUNC		  equ 0x0020
IVT_ADDR_PIT_SEGMENT	  equ 0x0022

IVT_ADDR_KEYBOARD_FUNC	  equ 0x0024
IVT_ADDR_KEYBOARD_SEGMENT equ 0x0026

IVT_ADDR_COM1_FUNC		  equ 0x0030
IVT_ADDR_COM1_SEGMENT	  equ 0x0032

IVT_ADDR_SYSCALL_FUNC	  equ 0x0080 ;int 0x20 
IVT_ADDR_SYSCALL_SEGMENT  equ 0x0082
load_isr:
;in:
;out: ax = KERNEL_SEGMENT
;init devices and set isr function and segment, set syscall
	cli
	call	pit_init
	call	keyboard_init
	xor		ax,		ax	;ISR offset
	mov		gs,		ax
	mov		ax,		KERNEL_SEGMENT
	mov		word[gs:IVT_ADDR_PIT_FUNC],			pit_int
	mov		word[gs:IVT_ADDR_PIT_SEGMENT],		ax
	mov		word[gs:IVT_ADDR_KEYBOARD_FUNC],	keyboard_int
	mov		word[gs:IVT_ADDR_KEYBOARD_SEGMENT],	ax
	mov		word[gs:IVT_ADDR_COM1_FUNC],		com1_int
	mov		word[gs:IVT_ADDR_COM1_SEGMENT],		ax
	mov		word[gs:IVT_ADDR_SYSCALL_FUNC],		syscall
	mov		word[gs:IVT_ADDR_SYSCALL_SEGMENT],	ax
	sti
	retn

pit_interrupt_handler dw pit_int
pit_interrupt_segment dw KERNEL_SEGMENT
keyboard_interrupt_handler dw keyboard_int
keyboard_interrupt_segment dw KERNEL_SEGMENT
save_interrupts:
;save current PIT and keyboard interrupt ISR function & segment
;in variable's above
	pusha
	push	es
	push	ds

;es = ds (KERNEL_SEGMENT)
	push	ds
	pop		es
;ds = ISR_SEGMENT
	xor		ax,		ax	;ISR segment
	mov		ds,		ax
;copy from IVT to list above values of 2 interrupts
	mov		si,		IVT_ADDR_PIT_FUNC
	mov		di,		pit_interrupt_handler
	movsw	;word[es:di] = word[ds:si]
	movsw	;word[es:di] = word[ds:si]
	movsw	;word[es:di] = word[ds:si]
	movsw	;word[es:di] = word[ds:si]
	;mov		ax,		word[gs:0x0020]
	;mov		word[pit_interrupt_handler], ax
	;mov		ax,		word[gs:0x0022]
	;mov		word[pit_interrupt_segment], ax
	;mov		ax,		word[gs:0x0024]
	;mov		word[keyboard_interrupt_handler], ax
	;mov		ax,		word[gs:0x0026]
	;mov		word[keyboard_interrupt_segment], ax
	pop		ds
	pop		es
	popa
	retn

restore_interrupts:
;load PIT and keyboard interrupts ISR values (function & segment)
;from saved before values in variables above
	cli
	pusha
	push	es

;es = ISR_SEGMENT
	xor		ax,		ax	;ISR segment
	mov		es,		ax
;copy from list above to IVT values of 2 interrupts
	mov		si,		pit_interrupt_handler
	mov		di,		IVT_ADDR_PIT_FUNC
	movsw	;word[es:di] = word[ds:si]
	movsw	;word[es:di] = word[ds:si]
	movsw	;word[es:di] = word[ds:si]
	movsw	;word[es:di] = word[ds:si]

	;xor		ax,		ax
	;mov		gs,		ax
	;mov		ax,		word[pit_interrupt_handler]
	;mov		word[gs:0x0020],	ax
	;mov		ax,		word[pit_interrupt_segment]
	;mov		word[gs:0x0022],	ax
	;mov		ax,		word[keyboard_interrupt_handler]
	;mov		word[gs:0x0024],	ax
	;mov		ax,		word[keyboard_interrupt_segment]
	;mov		word[gs:0x0026],	ax

	pop		es
	popa
	sti
	retn

;bx - number of syscall
syscall:
;in:  bx = number of syscall
;out: depending on syscall
	push	ds
	push	gs
;gs = KERNEL_SEGMENT
	push	KERNEL_SEGMENT
	pop		gs		;throught gs segment get address from table
;getting address of function
	mov		bx,		word[gs:bx + .jump_table]
	pop		gs
	call	bx
	pop		ds
	iret
.jump_table:
	dw		_interrupt_vga_clear_screen		;#0
	dw		vga_cursor_disable				;#1
	dw		vga_cursor_enable				;#2
	dw		_interrupt_vga_cursor_move		;#3
	dw		_interrupt_tty_putchar_ascii	;#4
	dw		_interrupt_tty_print_ascii		;#5
	dw		_interrupt_tty_print_ascii_c	;#6
	dw		_interrupt_tty_next_row			;#7
	dw		fat12_read_root					;#8
	dw		fat12_find_entry				;#9
	dw		fat12_load_entry				;#10
	dw		fat12_file_size					;#11
	dw		fat12_file_entry_size			;#12
	dw		_interrupt_pit_set_frequency	;#13
	dw		_interrupt_pit_get_frequency	;#14
	dw		_interrupt_get_keyboard_input	;#15
	dw		_interrupt_scancode_to_ascii	;#16
	dw		_interrupt_int_to_ascii			;#17
	dw		_interrupt_uint_to_ascii		;#18
	dw		_interrupt_set_pit_int			;#19
	dw		_interrupt_set_keyboard_int		;#20
	dw		_interrupt_rand_int				;#21
	dw		_interrupt_set_rand_seed		;#22
	dw		rtc_get_sec						;#23
	dw		rtc_get_min						;#24
	dw		rtc_get_hour					;#25
	dw		rtc_get_day						;#26
	dw		rtc_get_month					;#27
	dw		rtc_get_year					;#28
	dw		rtc_get_century					;#29
	dw		rtc_get_week					;#30
	dw		rtc_get_ascii_sec				;#31
	dw		rtc_get_ascii_min				;#32
	dw		rtc_get_ascii_hour				;#33
	dw		rtc_get_ascii_day				;#34
	dw		rtc_get_ascii_month				;#35
	dw		rtc_get_ascii_year				;#36
	dw		rtc_get_ascii_century			;#37
	dw		rtc_get_ascii_week				;#38
	dw		_interrupt_execve				;#39

_interrupt_vga_clear_screen:
;in: 
;out: ah = byte[vga_color]
;	  al = 0
;     di = 0
;     cx = 0
;	  bx = 0
;	  dx = 0x03D5
	push	KERNEL_SEGMENT
	pop		ds
	call	vga_clear_screen
	retn

_interrupt_pit_set_frequency:
;in:  ax = frequency
;out: al = ah
;	  bx = KERNEL_SEGMENT
	push	KERNEL_SEGMENT
	pop		ds
	call	pit_set_frequency
	retn

_interrupt_pit_get_frequency:
;in:
;out: ax = word[pit_frequency]
;	  bx = KERNEL_SEGMENT
	push	KERNEL_SEGMENT
	pop		ds
	mov		ax,		word[pit_frequency]
	retn

_interrupt_vga_cursor_move:
;in:  cx = cursor position
;out: bx = word[vga_pos_cursor] / 2
;     dx = 0x03D5
;     al = bh
	push	KERNEL_SEGMENT
	pop		ds
	mov		word[vga_pos_cursor],	cx
	call	vga_cursor_move
	retn

_interrupt_tty_putchar_ascii:
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
	push	ds
	cmp		al,		0x0A ;'\n'
	je		.new_line
	push	KERNEL_SEGMENT
	pop		ds
	mov		ah,		byte[vga_color] ;ax vga_char now
	mov		bx,		word[vga_pos_cursor]
	mov		word[es:bx],	ax
	add		bx,		VGA_CHAR_SIZE
	mov		word[vga_pos_cursor], bx
	call	vga_cursor_move.without_get_pos_cursor_with_div
	pop		ds
.end:
	retn
.new_line:
	call	_interrupt_tty_next_row
	pop		ds
	retn

_interrupt_tty_print_ascii:
;in:  si = ptr to str
;	  cx = len of str
;out: if last_char == 0, then:
;		 al = 0
;		 si = end of str
;		 cx = 0
;	  if last_char == 0x0A, then:
;		 al = bh
;		 bx = word[vga_pos_cursor] / 2
;		 cx = 0
;		 dx = 0x03D5
;		 si = end of str
;	  else:
;		 ah = byte[vga_color]
;		 al = bh
;		 bx = word[vga_pos_cursor] / 2
;		 cx = 0
;		 dx = 0x03D5
;		 si = end of str
.lp:
	lodsb	;al <- ds:si
	call	_interrupt_tty_putchar_ascii
	loop	.lp
	retn

_interrupt_tty_print_ascii_c:
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
	call	_interrupt_tty_putchar_ascii
	jmp		.lp
.end:
	retn


_interrupt_tty_next_row:
;in:
;out: al = bh
;     bx = word[vga_pos_cursor] / 2
;     dx = 0x03D5
;need calc the row now, inc and mul to 80 * VGA_CHAR_SIZE
	push	KERNEL_SEGMENT
	pop		ds
	call	tty_next_row
	retn

KB_EMPTY equ 0x00	;this scancode don't used in XT set
_interrupt_get_keyboard_input:
;in:
;out: al = 0 if buffer empty, else scancode
	push	KERNEL_SEGMENT
	pop		ds
	call	pop_kb_buf
	retn

_interrupt_scancode_to_ascii:
;in:  al = scancode
;out: al = 0 if char not printable, else ascii
;	  bx = al
	push	KERNEL_SEGMENT
	pop		ds
	call	scancode_to_ascii
	retn

_interrupt_int_to_ascii:
;in:  ax = int
;	  si = ptr on str
;out: si = ascii str from number
;	  cx = len of si
;	  di = num_to_ascii_buffer
;	  al = high char in str
;	  dx = high sign in int
	push	KERNEL_SEGMENT
	pop		ds
	call	int_to_ascii
	retn

_interrupt_uint_to_ascii:
;in:  ax = uint
;	  si = ptr on str
;out: si = ascii str from number
;	  cx = len of str
;	  di = num_to_ascii_buffer
;	  al = high char in str
;	  dx = high sign in uint
	push	gs
	push	KERNEL_SEGMENT
	pop		gs

	mov		di,		num_to_ascii_buf
	mov		cx,		10		;divisor
	mov		bl,		0x30	;need add for transform to ascii
.lp:
	xor		dx,		dx	;clear, because used in div instruction (dx:ax)
	div		cx			;ax = quotient, dx = remainder
	add		dl,		bl	;transform to ascii
	mov		byte[gs:di],	dl
	inc		di
	test	ax,		ax
	jne		.lp
.end_lp:
;	lea		cx,		[di - num_to_ascii_buf] ;calc len of str
	mov		cx,		di
	sub		cx,		num_to_ascii_buf
.lp2:	;invert copy from di to si
	dec		di
	mov		al,		byte[gs:di]
	mov		byte[ds:si],	al
	inc		si
	cmp		di,		num_to_ascii_buf
	jne		.lp2
	sub		si,		cx	;si = start of str

	pop		gs
	retn

_interrupt_set_pit_int:
;in:  di = pit_handler
;out: ax = 0
	cli
	xor		ax,		ax
	mov		gs,		ax
	mov		word[gs:0x0020],	di
	mov		word[gs:0x0022],	ds
	sti
	retn

_interrupt_set_keyboard_int:
;in:  di = keyboard_handler
;out: ax = 0
	cli
	xor		ax,		ax
	mov		gs,		ax
	mov		word[gs:0x0024],	di
	mov		word[gs:0x0026],	ds
	sti
	retn

_interrupt_rand_int:
;in:
;out: ax = pseudo random number
;	  dx = ???
;	  bx = KERNEL_SEGMENT
	push	KERNEL_SEGMENT
	pop		ds
	call	rand_int
	retn

_interrupt_set_rand_seed:
;in:  ax = seed
;out: ax = seed
;	  bx = KERNEL_SEGMENT
	push	KERNEL_SEGMENT
	pop		ds
	mov		word[rand_int_seed],	ax
	retn

_interrupt_execve:
;in: ds:si = name of file
;	 ?s:bp = args
;out:
;need load the fat12, found entry and load to bin to memory on PROCESS_SEGMENT
;kernel functions calls throught syscall 0x20, list in the kernel.inc
	call	fat12_find_entry
	cmp		ax,		FAT12_ENTRY_NOT_FOUND
	je		.not_found
	push	es
	push	PROCESS_SEGMENT
	pop		es
	xor		si,		si
	call	fat12_load_entry
	pop		es
;Now, file was load. Execute him
	mov		ax,		PROCESS_SEGMENT
	mov		ds,		ax
	jmp		PROCESS_SEGMENT:0x0000
.not_found:
	retn
