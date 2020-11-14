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
;init devices and set isr function and segment, set syscall
	cli
	call	pit_init
	call	keyboard_init
	xor		ax,		ax
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

;bx - number of function
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

%include "rtc.asm"

syscall_jump_table:
	dw		vga_clear_screen				;#1
	dw		vga_cursor_disable				;#2
	dw		vga_cursor_enable				;#3
	dw		_interrupt_vga_cursor_move		;#4
	dw		vga_set_video_mode				;#5
	dw		_interrupt_tty_putchar_ascii	;#6
	dw		_interrupt_tty_print_ascii		;#7
	dw		_interrupt_tty_next_row			;#8
	dw		fat12_read_root					;#9
	dw		fat12_find_entry				;#10
	dw		fat12_load_entry				;#11
	dw		fat12_file_size					;#12
	dw		fat12_file_entry_size			;#13
	dw		_interrupt_pit_set_frequency	;#14
	dw		_interrupt_pit_get_frequency	;#15
	dw		_interrupt_get_keyboard_input	;#16
	dw		_interrupt_wait_keyboard_input	;#17
	dw		_interrupt_scancode_to_ascii	;#18
	dw		_interrupt_int_to_ascii			;#19
	dw		_interrupt_uint_to_ascii		;#20
	dw		_interrupt_set_pit_int			;#21
	dw		_interrupt_set_keyboard_int		;#22
	dw		_interrupt_rand_int				;#23
	dw		_interrupt_set_rand_seed		;#24
	dw		rtc_get_sec						;#25
	dw		rtc_get_min						;#26
	dw		rtc_get_hour					;#27
	dw		rtc_get_day						;#28
	dw		rtc_get_month					;#29
	dw		rtc_get_year					;#30
	dw		rtc_get_century					;#31
	dw		rtc_get_week					;#32
	dw		rtc_get_ascii_sec				;#33
	dw		rtc_get_ascii_min				;#34
	dw		rtc_get_ascii_hour				;#35
	dw		rtc_get_ascii_day				;#36
	dw		rtc_get_ascii_month				;#37
	dw		rtc_get_ascii_year				;#38
	dw		rtc_get_ascii_century			;#39
	dw		rtc_get_ascii_week				;#40
	dw		_interrupt_get_argc				;#41
	dw		_interrupt_get_argv				;#42

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
	cmp		al,		0x0A ;'\n'
	je		.new_line
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
.new_line:
	pusha
	call	_interrupt_tty_next_row
	popa
	pop		ds
	retn

_interrupt_tty_print_ascii:
;in:  si = ptr to str
;     cx = len of str
;out: si = end of str
;     cx = 0
;     ax = vga_char of last symbol in si (al = ASCII, ah = color)
;     bx = word[vga_pos_cursor]
.lp:
	lodsb	;al <- ds:si
	call	_interrupt_tty_putchar_ascii
	loop	.lp
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

KB_EMPTY equ 0x00	;this scancode don't used in XT set
_interrupt_get_keyboard_input:
;in:  al = scancode
;out: al = KB_EMPTY if error, else scancode
	push	ds
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
	call	pop_kb_buf
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
