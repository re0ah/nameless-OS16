PICM				equ	0x20	;master PIC
PICS				equ	0xA0	;slave PIC
PIC_EOI				equ	0x20	;end of interrupt code

%include "pit.asm"
%include "keyboard.asm"

ISR_ADDR_PIT_FUNC		  equ 0x0020
ISR_ADDR_PIT_SEGMENT	  equ 0x0022

ISR_ADDR_KEYBOARD_FUNC	  equ 0x0024
ISR_ADDR_KEYBOARD_SEGMENT equ 0x0026

ISR_ADDR_SYSCALL_FUNC	  equ 0x0080 ;int 0x20 
ISR_ADDR_SYSCALL_SEGMENT  equ 0x0082
load_isr:
;in:
;out: ax = KERNEL_OFFSET
;init devices and set isr function and segment, set syscall
	cli
	call	pit_init
	call	keyboard_init
	xor		ax,		ax	;ISR offset
	mov		gs,		ax
	mov		ax,		KERNEL_OFFSET
	mov		word[gs:ISR_ADDR_PIT_FUNC],			pit_int
	mov		word[gs:ISR_ADDR_PIT_SEGMENT],		ax
	mov		word[gs:ISR_ADDR_KEYBOARD_FUNC],	keyboard_int
	mov		word[gs:ISR_ADDR_KEYBOARD_SEGMENT],	ax
	mov		word[gs:ISR_ADDR_SYSCALL_FUNC],		syscall
	mov		word[gs:ISR_ADDR_SYSCALL_SEGMENT],	ax
	sti
	retn

pit_interrupt_handler dw pit_int
pit_interrupt_segment dw KERNEL_OFFSET
keyboard_interrupt_handler dw keyboard_int
keyboard_interrupt_segment dw KERNEL_OFFSET
save_interrupts:
;save current PIT and keyboard interrupt ISR function & segment
;in variable's above
	pusha
	push	es
	push	ds

	mov		ax,		ds
	mov		es,		ax
	xor		ax,		ax	;ISR segment
	mov		ds,		ax
	mov		si,		ISR_ADDR_PIT_FUNC
	mov		di,		pit_interrupt_handler
	movsw	;word[ds:si] -> word[es:di], si+=2, di+=2
	movsw	;word[ds:si] -> word[es:di], si+=2, di+=2
	movsw	;word[ds:si] -> word[es:di], si+=2, di+=2
	movsw	;word[ds:si] -> word[es:di], si+=2, di+=2
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

	xor		ax,		ax	;ISR segment
	mov		es,		ax
	mov		si,		pit_interrupt_handler
	mov		di,		ISR_ADDR_PIT_FUNC
	movsw	;word[ds:si] -> word[es:di], si+=2, di+=2
	movsw	;word[ds:si] -> word[es:di], si+=2, di+=2
	movsw	;word[ds:si] -> word[es:di], si+=2, di+=2
	movsw	;word[ds:si] -> word[es:di], si+=2, di+=2

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

%include "syscall.inc"
;bx - number of syscall
syscall:
;in:  bx = number of syscall
;out: depending on syscall
	push	gs
	push	ax
	mov		ax,		KERNEL_OFFSET
	mov		gs,		ax	;throught gs segment get address from table
	pop		ax
	mov		bx,		word[gs:bx + .jump_table]
	pop		gs
	call	bx
	iret
.jump_table:
	dw		_interrupt_vga_clear_screen		;#0
	dw		vga_cursor_disable				;#1
	dw		vga_cursor_enable				;#2
	dw		_interrupt_vga_cursor_move		;#3
	dw		vga_set_video_mode				;#4
	dw		_interrupt_tty_putchar_ascii	;#5
	dw		_interrupt_tty_print_ascii		;#6
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

_interrupt_vga_clear_screen:
;in: 
;out: ah = byte[vga_color]
;	  al = 0
;     di = 0
;     cx = 0
;	  bx = 0
;	  dx = 0x03D5
	push	ds
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
	call	vga_clear_screen
	pop		ds
	retn

_interrupt_pit_set_frequency:
;in:  ax = frequency
;out: al = ah
;	  bx = KERNEL_OFFSET
	push	ds
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
	call	pit_set_frequency
	pop		ds
	retn

_interrupt_pit_get_frequency:
;in:
;out: ax = word[pit_frequency]
;	  bx = KERNEL_OFFSET
	push	ds
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
	mov		ax,		word[pit_frequency]
	pop		ds
	retn

_interrupt_vga_cursor_move:
;in:  cx = cursor position
;out: bx = word[vga_pos_cursor] / 2
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
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
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
	call	_interrupt_tty_putchar_ascii
	pop		cx
	loop	.lp
	retn

_interrupt_tty_next_row:
;in:
;out: al = bh
;     bx = word[vga_pos_cursor] / 2
;     cx = (num_of_row + 1) * 80
;     dx = 0x03D5
;need calc the row now, inc and mul to 80 * VGA_CHAR_SIZE
	push	ds
	mov		ax,		KERNEL_OFFSET
	mov		ds,		ax
	call	tty_next_row
	pop		ds
	retn

KB_EMPTY equ 0x00	;this scancode don't used in XT set
_interrupt_get_keyboard_input:
;in:
;out: al = 0 if buffer empty, else scancode
	push	ds
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
	call	pop_kb_buf
	pop		ds
	retn

_interrupt_scancode_to_ascii:
;in:  al = scancode
;out: al = 0 if char not printable, else ascii
;	  bx = al
	push	ds
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
	call	scancode_to_ascii
	pop		ds
	retn

_interrupt_int_to_ascii:
;in:  ax = int
;	  si = ptr on str
;out: si = ascii str from number
;	  cx = len of si
;	  di = num_to_ascii_buffer
;	  al = high char in str
;	  dx = high sign in int
	push	ds
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
	call	int_to_ascii
	pop		ds
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
	mov		bx,		KERNEL_OFFSET
	mov		gs,		bx

	mov		di,		num_to_ascii_buf
	mov		cx,		10		;divisor
	mov		bl,		0x30	;need add for transform to ascii
.lp:
	xor		dx,		dx	;clear, because used in div instruction (dx:ax)
	div		cx			;ax = quotient, dx = remainder
	add		dl,		bl	;transform to ascii
	mov		byte[di],	dl
	inc		di
	test	ax,		ax
	jne		.lp
.end_lp:
	lea		cx,		[di - num_to_ascii_buf] ;calc len of str
.lp2:	;invert copy from di to si
	dec		di
	mov		al,		byte[di]
	mov		byte[si],	al
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
;	  bx = KERNEL_OFFSET
	push	ds
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
	call	rand_int
	pop		ds
	retn

_interrupt_set_rand_seed:
;in:  ax = seed
;out: ax = seed
;	  bx = KERNEL_OFFSET
	push	ds
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
	call	set_rand_seed
	pop		ds
	retn
