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
PICM		   equ 0x20	;master PIC
PIC_EOI		   equ 0x20	;end of interrupt code
KB_DATA_PORT   equ 0x60
KB_STATUS_PORT equ 0x64

KB_BUF_SIZE   equ 64
kb_buf		  times KB_BUF_SIZE db 0
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
;	mov		al,		KB_WRITE_SET_SCANCODE
;	call	keyboard_wait_port
;	out		KB_DATA_PORT,	al

;	mov		al,		KB_SCANCODE_SET
;	call	keyboard_wait_port
;	out		KB_DATA_PORT,	al
;	mov		al,		KB_WRITE_SET_SCANCODE
;	call	keyboard_wait_port
;	out		KB_DATA_PORT,	al

;	mov		al,		KB_SCANCODE_SET
;	call	keyboard_wait_port
;	out		KB_DATA_PORT,	al

;	call	keyboard_wait_port
;	in		al,		KB_DATA_PORT
	retn

keyboard_int:
;push scancode to kb_buf, set led, caps...
	push	ds
	push	ax
	mov		ax,		KERNEL_SEGMENT
	mov		ds,		ax
	pop		ax

	call	keyboard_wait_port
	in		al,		KB_DATA_PORT ;get scancode

	cmp		al,		0xFF
	je		.exit
	cmp		al,		0xFE
	je		.exit
	cmp		al,		0x00
	je		.exit
	cmp		al,		0xEE
	je		.exit
	cmp		al,		0xFA
	je		.exit

	cmp		al,		0xE0	;spec scancode
	je		kb_spec_scancode
	cmp		al,		0xE1
	je		kb_pause

	call	keyboard_set_led
	call	check_shift_pressed
	call	push_kb_buf
.exit:
	pop		ds
	mov		al,		PICM
	out		PIC_EOI, al
	iret

kb_pause:
	in		al,		KB_DATA_PORT
	in		al,		KB_DATA_PORT
	in		al,		KB_DATA_PORT
	in		al,		KB_DATA_PORT

	mov		al,		SCANCODE_OS_MAKE_PAUSE
	call	push_kb_buf
	
	pop		ds
	mov		al,		PICM
	out		PIC_EOI, al
	iret

kb_make_print:
	in		al,		KB_DATA_PORT
	in		al,		KB_DATA_PORT

	mov		al,		SCANCODE_OS_MAKE_PRINT
	call	push_kb_buf
	
	pop		ds
	mov		al,		PICM
	out		PIC_EOI, al
	iret

kb_break_print:
	in		al,		KB_DATA_PORT
	in		al,		KB_DATA_PORT

	mov		al,		SCANCODE_OS_BREAK_PRINT
	call	push_kb_buf
	
	pop		ds
	mov		al,		PICM
	out		PIC_EOI, al
	iret

kb_spec_scancode:
	call	keyboard_wait_port
	in		al,		KB_DATA_PORT

	cmp		al,		0x2A
	je		kb_make_print
	cmp		al,		0xB7
	je		kb_break_print

	movzx	bx,		al
	mov		al,		byte[.data_table + bx]
	call	push_kb_buf

	pop		ds
	mov		al,		PICM
	out		PIC_EOI, al
	iret
.data_table:
		times 29 db 0
		db		SCANCODE_OS_MAKE_KP_EN			;0x1C
		db		SCANCODE_OS_MAKE_R_CTRL			;0x1D
		times 23 db 0
		db		SCANCODE_OS_MAKE_KP_DIV			;0x35
		times 2 db 0
		db		SCANCODE_OS_MAKE_R_ALT			;0x38
		times 13 db 0
		db		SCANCODE_OS_MAKE_HOME			;0x47
		db		SCANCODE_OS_MAKE_UP_ARROW		;0x48
		db		SCANCODE_OS_MAKE_PG_UP			;0x49
		times 1 db 0
		db		SCANCODE_OS_MAKE_LEFT_ARROW		;0x4B
		times 1 db 0
		db		SCANCODE_OS_MAKE_RIGHT_ARROW	;0x4D
		times 1 db 0
		db		SCANCODE_OS_MAKE_END			;0x4F
		db		SCANCODE_OS_MAKE_DOWN_ARROW		;0x50
		db		SCANCODE_OS_MAKE_PG_DOWN		;0x51
		db		SCANCODE_OS_MAKE_INSERT			;0x52
		db		SCANCODE_OS_MAKE_DELETE			;0x53
		times 7 db 0
		db		SCANCODE_OS_MAKE_L_GUI			;0x5B
		db		SCANCODE_OS_MAKE_R_GUI			;0x5C
		times 1 db 0
		db		SCANCODE_OS_MAKE_POWER			;0x5E
		db		SCANCODE_OS_MAKE_SLEEP			;0x5F
		times 3 db 0
		db		SCANCODE_OS_MAKE_WAKE			;0x63
		times 51 db 0
		db		SCANCODE_OS_BREAK_HOME			;0x97
		times 4 db 0
		db		SCANCODE_OS_BREAK_KP_EN			;0x9C
		db		SCANCODE_OS_BREAK_R_CTRL		;0x9D
		times 23 db 0
		db		SCANCODE_OS_BREAK_KP_DIV		;0xB5
		times 3 db 0
		db		SCANCODE_OS_BREAK_R_ALT			;0xB9
		times 14 db 0
		db		SCANCODE_OS_BREAK_UP_ARROW		;0xC8
		db		SCANCODE_OS_BREAK_PG_UP			;0xC9
		times 1 db 0
		db		SCANCODE_OS_BREAK_LEFT_ARROW	;0xCB
		times 1 db 0
		db		SCANCODE_OS_BREAK_RIGHT_ARROW	;0xCD
		times 1 db 0
		db		SCANCODE_OS_BREAK_END			;0xCF
		db		SCANCODE_OS_BREAK_DOWN_ARROW	;0xD0
		db		SCANCODE_OS_BREAK_PG_DOWN		;0xD1
		db		SCANCODE_OS_BREAK_INSERT		;0xD2
		db		SCANCODE_OS_BREAK_DELETE		;0xD3
		times 7 db 0
		db		SCANCODE_OS_BREAK_L_GUI			;0xDB
		db		SCANCODE_OS_BREAK_R_GUI			;0xDC
		times 1 db 0
		db		SCANCODE_OS_BREAK_POWER			;0xDE
		db		SCANCODE_OS_BREAK_SLEEP			;0xDF
		times 3 db 0
		db		SCANCODE_OS_BREAK_WAKE			;0xE3

KB_OVERFLOW equ 0x00	;this scancode don't used in XT set
push_kb_buf:
;in:  al = scancode
;out: al = KB_OVERFLOW if error, else scancode
;	  bx = byte[kb_buf_pos - 1]
	movzx	bx,		byte[kb_buf_pos]
	cmp		bx,		KB_BUF_SIZE
	je		.end_overflow
	mov		byte[bx + kb_buf],	al
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
;	  bx = byte[kb_buf_pos]
	movzx	bx,		byte[kb_buf_pos]
	test	bx,		bx
	je		.end_empty
	dec		bl
	mov		byte[kb_buf_pos],	bl
	mov		al,		byte[bx + kb_buf]
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

;	mov		al,		KB_WRITE_LEDS
;	call	keyboard_wait_port
;	out		KB_DATA_PORT,	al

;	mov		al,		byte[kb_led_status]
;	call	keyboard_wait_port
;	out		KB_DATA_PORT,	al

;set LED response: 0xFA(Acknowledge) or 0xFE(Resend) 
;	call	keyboard_wait_port
;	in		al,		KB_DATA_PORT ;get scancode
;	cmp		al,		0xFA
;	je		.end
;	cmp		al,		0xFE
;	je		.end
;	jmp		0xFFFF:0x0000
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
	jmp		pop_kb_buf

kb_shift_pressed db 0
check_shift_pressed:
;in: al=scancode
;set/reset if scancode will shift
	cmp		al,		0x2A	;left shift  make
	je		.shift_make
	cmp		al,		0xAA	;left shift  break
	je		.shift_break
	cmp		al,		0x36	;right shift make
	je		.shift_make
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
;out: cl = caps or not
	mov		cl,		byte[kb_led_status]
	and		cx,		KB_LED_CAPS
	retn

KB_SCANCODE:;That not scancode's of hardware, that scancodes OS.
			;Need for simple store spec scancodes.
			;Used scancodes what's not used by hardware
			;All another scancodes same as hardware
SCANCODE_OS_MAKE_L_GUI equ 0x5B
	db SCANCODE_OS_MAKE_L_GUI ;hardware=(E0, 5B)

SCANCODE_OS_BREAK_L_GUI equ 0xDB
	db SCANCODE_OS_BREAK_L_GUI ;hardware=(E0, DB)

SCANCODE_OS_MAKE_R_CTRL equ 0xA9
	db SCANCODE_OS_MAKE_R_CTRL ;hardware=(E0, 1D)

SCANCODE_OS_BREAK_R_CTRL equ 0xD4
	db SCANCODE_OS_BREAK_R_CTRL ;hardware=(E0, 9D)

SCANCODE_OS_MAKE_R_GUI equ 0x5C
	db SCANCODE_OS_MAKE_R_GUI ;hardware=(E0, 5C)

SCANCODE_OS_BREAK_R_GUI equ 0xDC
	db SCANCODE_OS_BREAK_R_GUI ;hardware=(E0, DC)

SCANCODE_OS_MAKE_R_ALT equ 0xD5
	db SCANCODE_OS_MAKE_R_ALT ;hardware=(E0, 38)

SCANCODE_OS_BREAK_R_ALT equ 0xD6
	db SCANCODE_OS_BREAK_R_ALT ;hardware=(E0, B9)

SCANCODE_OS_MAKE_HOME equ 0xD9
	db SCANCODE_OS_MAKE_HOME ;hardware=(E0, 47)

SCANCODE_OS_BREAK_HOME equ 0xDA
	db SCANCODE_OS_BREAK_HOME ;hardware=(E0, 97)

SCANCODE_OS_MAKE_INSERT equ 0xDE
	db SCANCODE_OS_MAKE_INSERT ;hardware=(E0, 52)

SCANCODE_OS_BREAK_INSERT equ 0xDF
	db SCANCODE_OS_BREAK_INSERT ;hardware=(E0, D2)

SCANCODE_OS_MAKE_PG_UP equ 0xE1
	db SCANCODE_OS_BREAK_INSERT ;hardware=(E0, 49)

SCANCODE_OS_BREAK_PG_UP equ 0xE2
	db SCANCODE_OS_BREAK_INSERT ;hardware=(E0, C9)

SCANCODE_OS_MAKE_DELETE equ 0xE3
	db SCANCODE_OS_MAKE_DELETE ;hardware=(E0, 53)

SCANCODE_OS_BREAK_DELETE equ 0xE4
	db SCANCODE_OS_BREAK_DELETE ;hardware=(E0, D3)

SCANCODE_OS_MAKE_END equ 0xE5
	db SCANCODE_OS_MAKE_END ;hardware=(E0, 4F)

SCANCODE_OS_BREAK_END equ 0xE6
	db SCANCODE_OS_BREAK_END ;hardware=(E0, CF)

SCANCODE_OS_MAKE_PG_DOWN equ 0xE7
	db SCANCODE_OS_MAKE_PG_DOWN ;hardware=(E0, 51)

SCANCODE_OS_BREAK_PG_DOWN equ 0xE8
	db SCANCODE_OS_BREAK_PG_DOWN ;hardware=(E0, D1)

SCANCODE_OS_MAKE_UP_ARROW equ 0xE9
	db SCANCODE_OS_MAKE_UP_ARROW ;hardware=(E0, 48)

SCANCODE_OS_MAKE_LEFT_ARROW equ 0xEA
	db SCANCODE_OS_MAKE_LEFT_ARROW ;hardware=(E0, 4B)

SCANCODE_OS_MAKE_DOWN_ARROW equ 0xEB
	db SCANCODE_OS_MAKE_DOWN_ARROW ;hardware=(E0, 50)

SCANCODE_OS_MAKE_RIGHT_ARROW equ 0xEC
	db SCANCODE_OS_MAKE_RIGHT_ARROW ;hardware=(E0, 4D)

SCANCODE_OS_BREAK_UP_ARROW equ 0xED
	db SCANCODE_OS_BREAK_UP_ARROW ;hardware=(E0, C8)

SCANCODE_OS_BREAK_LEFT_ARROW equ 0xEF
	db SCANCODE_OS_BREAK_LEFT_ARROW ;hardware=(E0, CB)

SCANCODE_OS_BREAK_DOWN_ARROW equ 0xF0
	db SCANCODE_OS_BREAK_DOWN_ARROW ;hardware=(E0, D0)

SCANCODE_OS_BREAK_RIGHT_ARROW equ 0xF1
	db SCANCODE_OS_BREAK_RIGHT_ARROW ;hardware=(E0, CD)

SCANCODE_OS_MAKE_KP_DIV equ 0xF2
	db SCANCODE_OS_MAKE_KP_DIV ;hardware=(E0, 35)

SCANCODE_OS_BREAK_KP_DIV equ 0xF3
	db SCANCODE_OS_BREAK_KP_DIV ;hardware=(E0, B5)

SCANCODE_OS_MAKE_KP_EN equ 0xF4
	db SCANCODE_OS_MAKE_KP_EN ;hardware=(E0, 1C)

SCANCODE_OS_BREAK_KP_EN equ 0xF5
	db SCANCODE_OS_BREAK_KP_EN ;hardware=(E0, 9C)

SCANCODE_OS_MAKE_PRINT equ 0xF6
	db SCANCODE_OS_MAKE_PRINT ;hardware=(E0, 2A, E0, 37)

SCANCODE_OS_BREAK_PRINT equ 0xF7
	db SCANCODE_OS_BREAK_PRINT ;hardware=(E0, B7, E0, AA)

SCANCODE_OS_MAKE_PAUSE equ 0xF8
	db SCANCODE_OS_MAKE_PAUSE ;hardware=(E1, 1D, 45, E1, 9D, C5)

SCANCODE_OS_MAKE_POWER equ 0xF9
	db SCANCODE_OS_MAKE_POWER ;hardware=(E0, 5E)

SCANCODE_OS_BREAK_POWER equ 0xFA
	db SCANCODE_OS_BREAK_POWER ;hardware=(E0, DE)

SCANCODE_OS_MAKE_SLEEP equ 0xFB
	db SCANCODE_OS_MAKE_SLEEP ;hardware=(E0, 5F)

SCANCODE_OS_BREAK_SLEEP equ 0xFC
	db SCANCODE_OS_BREAK_SLEEP ;hardware=(E0, DF)

SCANCODE_OS_MAKE_WAKE equ 0xFD
	db SCANCODE_OS_MAKE_WAKE ;hardware=(E0, 63)

SCANCODE_OS_BREAK_WAKE equ 0xFE
	db SCANCODE_OS_BREAK_WAKE ;hardware=(E0, E3)

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
