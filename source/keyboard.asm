PICM		   equ 0x20	;master PIC
PIC_EOI		   equ 0x20	;end of interrupt code
KB_DATA_PORT   equ 0x60
KB_STATUS_PORT equ 0x64

KB_BUF_SIZE   equ 32
kb_buf		  db KB_BUF_SIZE 
kb_buf_pos	  db 0

;LED status bitset:
	;0:    scroll lock
	;1:    num lock
	;2:    caps lock
	;3..7: unused
kb_led_status db 0

KB_LED_SCRL			   equ 0x01
KB_LED_MASK_SET_SCRL   equ 0x01
KB_LED_MASK_RESET_SCRL equ 0x06

KB_LED_NUM			   equ 0x02
KB_LED_MASK_SET_NUM	   equ 0x02
KB_LED_MASK_RESET_NUM  equ 0x05

KB_LED_CAPS			   equ 0x04
KB_LED_MASK_SET_CAPS   equ 0x04
KB_LED_MASK_RESET_CAPS equ 0x03

KB_WRITE_LEDS		  equ 0xED
KB_WRITE_SET_SCANCODE equ 0xF0
KB_SCANCODE_SET		  equ 0x00

keyboard_init:
;set scancode set
;	call	keyboard_wait_port
;
;	mov		al,		KB_WRITE_SET_SCANCODE
;	out		KB_DATA_PORT,	al

;	call	keyboard_wait_port

;	mov		al,		KB_SCANCODE_SET
;	out		KB_DATA_PORT,	al
	retn

keyboard_int:
	push	ds
	push	ax
	mov		ax,		KERNEL_OFFSET
	mov		ds,		ax
	pop		ax

	in		al,		KB_DATA_PORT ;get scancode

	cmp		al,		0xE0	;spec scancode
	je		kb_spec_scancode

	call	keyboard_set_led
	call	check_shift_pressed
	call	push_kb_buf
	pop		ds
	mov		al,		PICM
	out		PIC_EOI, al
	iret

kb_spec_scancode:
	in		al,		KB_DATA_PORT
	;pg up make = e0, 49
	;pg dn make = e0, 51
	cmp		al,		0x49
	jne		.not_pg_up_make
	call	vga_page_up
	mov		al,		PICM
	out		PIC_EOI, al
	iret
.not_pg_up_make:
	cmp		al,		0x51
	jne		.not_page_down_make
	call	vga_page_down
.not_page_down_make:
.end:
	mov		al,		PICM
	out		PIC_EOI, al
	iret

KB_OVERFLOW equ 0x00	;this scancode don't used in XT set
push_kb_buf:
;in:  al = scancode
;out: al = KB_OVERFLOW if error, else scancode
	movzx	bx,		byte[kb_buf_pos]
	cmp		bx,		KB_BUF_SIZE
	je		.end_overflow
	add		bx,		kb_buf
	mov		byte[bx],	al
	inc		byte[kb_buf_pos]
	retn
.end_overflow:
;	mov		al,		KB_OVERFLOW
	xor		al,		al
	retn

KB_EMPTY equ 0x00	;this scancode don't used in XT set
pop_kb_buf:
;in:  al = scancode
;out: al = KB_EMPTY if error, else scancode
	movzx	bx,		byte[kb_buf_pos]
	test	bx,		bx
	je		.end_empty
	dec		bl
	mov		byte[kb_buf_pos],	bl
	add		bx,		kb_buf
	mov		al,		byte[bx]
	retn
.end_empty:
;	mov		al,		KB_EMPTY
	xor		al,		al
	retn

keyboard_set_led:
;in:  al = scancode
;out:
;check if scancode equal of caps/num/scrl lock. Set/Reset them and
;set LED state
	mov		bl,		byte[kb_led_status]
	mov		cl,		bl
	not		cl
	cmp		al,		0x3A	;caps lock
	je		.caps
	cmp		al,		0x45	;num lock
	je		.num
	cmp		al,		0x46	;scroll lock
	jne		.end
		and		bl,		0xFE
		and		cl,		KB_LED_SCRL
		jmp		.write_to_led
.caps:
		and		bl,		0xFB
		and		cl,		KB_LED_CAPS
		jmp		.write_to_led
.num:
		and		bl,		0xFD
		and		cl,		KB_LED_NUM
.write_to_led:
	or		bl,		cl
	mov		byte[kb_led_status],	bl
.write_port:

;	call	keyboard_wait_port

;	mov		al,		KB_WRITE_LEDS
;	out		KB_DATA_PORT,	al

;	call	keyboard_wait_port

;	mov		al,		byte[kb_led_status]
;	out		KB_DATA_PORT,	al
;I commented this, maybe i deal with this later
.end:
	retn

keyboard_wait_port:
.wait:
	in		al,		KB_STATUS_PORT
	and		al,		0x02	;bit 1: controller current processing data
	jnz		.wait
	retn

wait_keyboard_input:
;in:
;out: al = scancode
;wait when will pass data in keyboard buffer.
	jmp		.wait_in
.wait:
	hlt
.wait_in:
	cmp		byte[kb_buf_pos],	0
	je		.wait
	call	pop_kb_buf
	retn

kb_shift_pressed db 0
check_shift_pressed:
;in: al=scancode
;set/reset if scancode will shift
	cmp		al,		0x2A	;left shift  make
	je		.shift_make
	cmp		al,		0x36	;right shift make
	je		.shift_make
	cmp		al,		0xAA	;left shift  break
	je		.shift_break
	cmp		al,		0xB6	;right shift break
	je		.shift_break
	retn
.shift_make:
	mov		byte[kb_shift_pressed],	1
	retn
.shift_break:
	mov		byte[kb_shift_pressed],	0
	retn

if_caps:
;also check shift pressed
;out: cl = caps or not
;C = caps  state
;S = shift state
;RES = result for return
;_____________
;| C | S |RES|
;| 0 | 0 | 0 |
;| 0 | 1 | 1 |
;| 1 | 0 | 1 |
;| 1 | 1 | 0 |
;-------------
;it's !(==)
	;mov		cl,		byte[kb_led_status]
	;and		cl,		KB_LED_CAPS
	;cmp		cl,		byte[kb_shift_pressed]
	;setne	cl
	;retn
	mov		cl,		byte[kb_led_status]
	and		cl,		KB_LED_CAPS
	retn

SCANCODE_SET:;(XT SCANCODE SET)
	db 0x00	;				 #00
	db 0x00	;MAKE ESC,		 #01
	db '1'	;MAKE 1,		 #02
	db '2'	;MAKE 2,		 #03
	db '3'	;MAKE 3,		 #04
	db '4'	;MAKE 4,		 #05
	db '5'	;MAKE 5,		 #06
	db '6'	;MAKE 6,		 #07
	db '7'	;MAKE 7,		 #08
	db '8'	;MAKE 8,		 #09
	db '9'	;MAKE 9,		 #0A
	db '0'	;MAKE 0,		 #0B
	db '-'	;MAKE -,		 #0C
	db '='	;MAKE =,		 #0D
	db 0x00	;MAKE BAKESPACE, #0E
	db 0x00 ;MAKE TAB,		 #0F
	db 'q'	;MAKE Q,		 #10
	db 'w'	;MAKE W,		 #11
	db 'e'	;MAKE E,		 #12
	db 'r'	;MAKE R,		 #13
	db 't'	;MAKE T,		 #14
	db 'y'	;MAKE Y,		 #15
	db 'u'	;MAKE U,		 #16
	db 'i'	;MAKE I,		 #17
	db 'o'	;MAKE O,		 #18
	db 'p'	;MAKE P,		 #19
	db '['	;MAKE [,		 #1A
	db ']'	;MAKE ],		 #1B
	db 0x00	;MAKE ENTER,	 #1C
	db 0x00	;MAKE L CONTROL, #1D
	db 'a'	;MAKE A,		 #1E
	db 's'	;MAKE S,		 #1F
	db 'd'	;MAKE D,		 #20
	db 'f'	;MAKE F,		 #21
	db 'g'	;MAKE G,		 #22
	db 'h'	;MAKE H,		 #23
	db 'j'	;MAKE J,		 #24
	db 'k'	;MAKE K,		 #25
	db 'l'	;MAKE L,		 #26
	db 0x3B	;MAKE ;,		 #27
	db 0x27	;MAKE ',		 #28
	db '`'	;MAKE `,		 #29
	db 0x00	;MAKE L SHIFT,	 #2A
	db '\'	;MAKE \,		 #2B
	db 'z'	;MAKE Z,		 #2C
	db 'x'	;MAKE X,		 #2D
	db 'c'	;MAKE C,		 #2E
	db 'v'	;MAKE V,		 #2F
	db 'b'	;MAKE B,		 #30
	db 'n'	;MAKE N,		 #31
	db 'm'	;MAKE M,		 #32
	db ','	;MAKE ,,		 #33
	db '.'	;MAKE .,		 #34
	db '/'	;MAKE /,		 #35
	db 0x00	;MAKE R SHIFT,	 #36
	db '*'	;MAKE KP *,		 #37
	db 0x00	;MAKE L ALT,	 #38
	db ' '	;MAKE SPACE,	 #39
	db 0x00	;MAKE CAPS,		 #3A
	db 0x00	;MAKE F1,		 #3B
	db 0x00	;MAKE F2,		 #3C
	db 0x00	;MAKE F3,		 #3D
	db 0x00	;MAKE F4,		 #3E
	db 0x00	;MAKE F5,		 #3F
	db 0x00	;MAKE F6,		 #40
	db 0x00	;MAKE F7,		 #41
	db 0x00	;MAKE F8,		 #42
	db 0x00	;MAKE F9,		 #43
	db 0x00	;MAKE F10,		 #44
	db 0x00 ;MAKE NUM LOCK,	 #45
	db 0x00	;MAKE SCROLL LCK,#46
	db '7'	;MAKE KP 7,		 #47
	db '8'	;MAKE KP 8,		 #48
	db '9'	;MAKE KP 9,		 #49
	db '-'	;MAKE KP -,		 #4A
	db '4'	;MAKE KP 4,		 #4B
	db '5'	;MAKE KP 5,		 #4C
	db '6'	;MAKE KP 6,		 #4D
	db '+'	;MAKE KP +,		 #4E
	db '1'	;MAKE KP 1,		 #4F
	db '2'	;MAKE KP 2,		 #50
	db '3'	;MAKE KP 3,		 #51
	db '0'	;MAKE KP 0,		 #52
	db '.'	;MAKE KP .,		 #53
	;no more printable chars, only BREAKS and UNUSED

SCANCODE_SET_WITH_SHIFT:;(XT SCANCODE SET)
	db 0x00	;				 #00
	db 0x00	;MAKE ESC,		 #01
	db '!'	;MAKE 1,		 #02
	db '@'	;MAKE 2,		 #03
	db '#'	;MAKE 3,		 #04
	db '$'	;MAKE 4,		 #05
	db '%'	;MAKE 5,		 #06
	db '^'	;MAKE 6,		 #07
	db '&'	;MAKE 7,		 #08
	db '*'	;MAKE 8,		 #09
	db '('	;MAKE 9,		 #0A
	db ')'	;MAKE 0,		 #0B
	db '_'	;MAKE -,		 #0C
	db '+'	;MAKE =,		 #0D
	db 0x00	;MAKE BAKESPACE, #0E
	db 0x00 ;MAKE TAB,		 #0F
	db 'Q'	;MAKE Q,		 #10
	db 'W'	;MAKE W,		 #11
	db 'E'	;MAKE E,		 #12
	db 'R'	;MAKE R,		 #13
	db 'T'	;MAKE T,		 #14
	db 'Y'	;MAKE Y,		 #15
	db 'U'	;MAKE U,		 #16
	db 'I'	;MAKE I,		 #17
	db 'O'	;MAKE O,		 #18
	db 'P'	;MAKE P,		 #19
	db '{'	;MAKE [,		 #1A
	db '}'	;MAKE ],		 #1B
	db 0x00	;MAKE ENTER,	 #1C
	db 0x00	;MAKE L CONTROL, #1D
	db 'A'	;MAKE A,		 #1E
	db 'S'	;MAKE S,		 #1F
	db 'D'	;MAKE D,		 #20
	db 'F'	;MAKE F,		 #21
	db 'G'	;MAKE G,		 #22
	db 'H'	;MAKE H,		 #23
	db 'J'	;MAKE J,		 #24
	db 'K'	;MAKE K,		 #25
	db 'L'	;MAKE L,		 #26
	db ':'	;MAKE ;,		 #27
	db '"'	;MAKE ',		 #28
	db '~'	;MAKE `,		 #29
	db 0x00	;MAKE L SHIFT,	 #2A
	db '|'	;MAKE \,		 #2B
	db 'Z'	;MAKE Z,		 #2C
	db 'X'	;MAKE X,		 #2D
	db 'C'	;MAKE C,		 #2E
	db 'V'	;MAKE V,		 #2F
	db 'B'	;MAKE B,		 #30
	db 'N'	;MAKE N,		 #31
	db 'M'	;MAKE M,		 #32
	db '<'	;MAKE ,,		 #33
	db '>'	;MAKE .,		 #34
	db '?'	;MAKE /,		 #35
