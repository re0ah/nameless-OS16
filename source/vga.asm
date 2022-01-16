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

;very thanks https://web.stanford.edu/class/cs140/projects/pintos/specs/freevga/vga/vga.htm
VGA_BUFFER		equ 0xB800
VGA_BUF_SIZE	equ 32768 ;bytes
VGA_WIDTH		equ 80
VGA_HEIGHT		equ 25
VGA_CHAR_SIZE	equ 2 ;bytes
VGA_LINE_SIZE	equ VGA_WIDTH * VGA_CHAR_SIZE
VGA_PAGES		equ 8 ;page 0 for show, 1..7 for stored
VGA_PAGE_NUM_CHARS equ VGA_WIDTH * VGA_HEIGHT ;2000 chars
VGA_PAGE_SIZE	equ VGA_PAGE_NUM_CHARS * VGA_CHAR_SIZE ;4000 bytes

VGA_BUFFER_0 equ 0xB800
VGA_BUFFER_1 equ 0
VGA_BUFFER_2 equ 0
VGA_BUFFER_3 equ 0
VGA_BUFFER_4 equ 0
VGA_BUFFER_5 equ 0
VGA_BUFFER_6 equ 0
VGA_BUFFER_7 equ 0

;==================================COLORS======================================
;struct of VGA_CHAR (2 bytes):
	;low  byte: code of char
	;high byte: 4 bits(low)  foreground color
	;			4 bits(high) background color
;==============================================================================
VGA_BLACK		 equ 0x00 ;color: #00 00 00
VGA_BLUE		 equ 0x01 ;color: #00 00 AA
VGA_GREEN		 equ 0x02 ;color: #00 AA 00
VGA_CYAN		 equ 0x03 ;color: #00 AA AA
VGA_RED			 equ 0x04 ;color: #AA 00 00
VGA_PURPLE		 equ 0x05 ;color: #AA 00 AA
VGA_BROWN		 equ 0x06 ;color: #AA 55 00
VGA_GRAY		 equ 0x07 ;color: #AA AA AA
VGA_DARK_GRAY	 equ 0x08 ;color: #55 55 55
VGA_LIGHT_BLUE	 equ 0x09 ;color: #55 55 FF
VGA_LIGHT_GREEN	 equ 0x0A ;color: #55 FF 55
VGA_LIGHT_CYAN	 equ 0x0B ;color: #55 FF FF
VGA_LIGHT_RED	 equ 0x0C ;color: #FF 55 55
VGA_LIGHT_PURPLE equ 0x0D ;color: #FF 55 FF
VGA_YELLOW		 equ 0x0E ;color: #FF FF 55
VGA_WHITE		 equ 0x0F ;color: #FF FF FF
;==============================================================================
CURSOR_DATA		equ	0x03D4	;this port get high byte cursor position
CURSOR_OFFSET	equ	0x03D5	;this port get low  byte cursor position

VGA_CRTC			equ	0x03D4	;for hardware scrolling
VGA_CRTC_HIGH_BYTE	equ	0x0C	;next byte in CURSOR_OFFSET will be high
VGA_CRTC_LOW_BYTE	equ	0x0D	;next byte in CURSOR_OFFSET will be low

HIGH_BYTE_NOW	equ	0x0E	;next byte in CURSOR_OFFSET will be high
LOW_BYTE_NOW	equ	0x0F	;next byte in CURSOR_OFFSET will be low

;thanks osdev for this table
;from https://wiki.osdev.org/Drawing_In_Protected_Mode
;|_____________________________|
;|_____standard VGA modes______|
;|00|text 40*25 16 color (mono)|
;|01|text 40*25 16 color       |
;|02|text 80*25 16 color (mono)|
;|03|text 80*25 16 color       |
;|04|CGA 320*200 4 color       |
;|05|CGA 320*200 4 color (mono)|
;|06|CGA 640*200 2 color       |
;|07|MDA monochrome text 80*25 |
;|08|PCjr                      |
;|09|PCjr                      |
;|0A|PCjr                      |
;|0B|reserved                  |
;|0C|reserved                  |
;|0D|EGA 320*200 16 color      |
;|0E|EGA 640*200 16 color      |
;|0F|EGA 640*350 mono          |
;|10|EGA 640*350 16 color      |
;|11|VGA 640*480 mono          |
;|12|VGA 640*480 16 color      |
;|13|VGA 320*200 256 color     |
;-------------------------------
;I will not make constants for these values, because...
;Well, what should I name them?
;VGA_CGA_320_200_4? VGA_VGA_640_480_16?
;In my spirit, but perhaps not

vga_init:
;find out of number VRAM
;I didn't understand how to find out of number VRAM... Let it be 16 KiB
	mov		word[vga_memory_size],	VGA_PAGE_SIZE * 4
	retn

vga_positioning_to_bottom:
;out: ax = ((word[vga_pos_cursor] - 3840) // 160 * 80) & 0x00FF
;	  bx = (word[vga_pos_cursor] - 3840) // 160 * 80
;	  dx = 0x03D5
;	  word[vga_offset_now] = offset from IN ax
	mov		ax,     word[vga_pos_cursor]
	sub		ax,     3840
	div     byte[vga_bytes_in_row]
	xor		ah,     ah
	mov		bl,     80
	mul		bl
	jmp		vga_update_line

vga_free_top_line:
;move memory for free vram
;
;out: al = bh
;	  bx = word[vga_pos_cursor] / 2
;	  dx = 0x03D5

	push	es
	push	ds

	pusha
	mov		cx,		word[vga_memory_size]
	push	VGA_BUFFER
	pop		es
	push	VGA_BUFFER
	pop		ds
	xor		di,		di
	mov		si,		160
	rep		movsw
	popa

	pop		ds
	pop		es

	mov		ax,		160
	sub		word[vga_pos_cursor],	ax
	sub		word[tty_input_start],	ax
	sub		word[tty_input_end],	ax
	jmp		vga_cursor_move

vga_clear_screen:
;in:
;out: ax = 0
;	  bx = 0
;	  di = word[vga_memory_size]
;	  cx = 0
;	  dx = 0x03D5
;	  word[vga_pos_cursor] = 0
;	  word[vga_offset_now] = 0
	mov		ax,		word[vga_space]
;	mov		ah,		byte[vga_color]
;	mov		al,		' '
;fill with ax first page of VGA_BUFFER
	xor		di,		di
	mov		word[vga_pos_cursor], di
	mov		cx,		word[vga_memory_size]
	rep		stosw	;word[es:di] = ax

	call	vga_cursor_move
	xor		ax,		ax
	jmp		vga_update_line

vga_calc_offset_line_move:
;out: if byte[kb_shift_pressed] == 1:
;			ax = 2000
;	  else:
;			ax = 80
;	  bl = byte[kb_shift_pressed]
	mov		ax,		80
	mov		bl,		byte[kb_shift_pressed]
	test	bl,		bl
	je		.not_pressed_shift
	add		ax,		1920
.not_pressed_shift:
	retn

vga_line_down:
;Scroll the screen down. If the shift is pressed, then scrolling
;by 25 lines (1 screen), if not pressed, then by 1 line. 
;
;out: if word[vga_pos_cursor] < 3840:
;			bx = word[vga_pos_cursor] - 3840;
;	  else:
;	  		if byte[kb_shift_pressed] == 1:
;				ax = 2000 =>
;				if (((word[vga_pos_cursor] - 3840) / 2) <= (2000 + word[vga_offset_now)):
;					ax = ((word[vga_pos_cursor] - 3840) // 160 * 80) & 0x00FF;
;					bx = (word[vga_pos_cursor] - 3840) // 160 * 80;
;					word[vga_offset_now] = ((word[vga_pos_cursor] - 3840) // 160 * 80) & 0x00FF;
;				else:
;					ax = 2000 + word[vga_offset_now];
;					bx = 2000 + word[vga_offset_now];
;					word[vga_offset_now] = 2000 + word[vga_offset_now];
;	  		else:
;				ax = 80 =>
;				if (word[vga_offset_now] - 80) <= (80 + word[vga_offset_now]):
;					ax = ((word[vga_pos_cursor] - 3840) // 160 * 80) & 0x00FF;
;					bx = (word[vga_pos_cursor] - 3840) // 160 * 80;
;					word[vga_offset_now] = ((word[vga_pos_cursor] - 3840) // 160 * 80) & 0x00FF;
;				else:
;					ax = 80 + word[vga_offset_now];
;					bx = 80 + word[vga_offset_now];
;					word[vga_offset_now] = 80 + word[vga_offset_now];
;	  		dx = 0x03D5

	mov     bx,     word[vga_pos_cursor]
	sub		bx,		3840
	jl		.exit
	shr		bx,		1
	call	vga_calc_offset_line_move
	add		ax,		word[vga_offset_now]
	sub		bx,		ax
	jle		vga_positioning_to_bottom

	jmp		vga_update_line
.exit:
	retn

vga_line_up:
;Scroll the screen up. If the shift is pressed, then scrolling
;by 25 lines (1 screen), if not pressed, then by 1 line. 
;
;out: if byte[kb_shift_pressed] == 1:
;			ax = 2000 =>
;			if (word[vga_offset_now] - 2000) >= 80:
;				ax = (word[vga_offset_now] - 2000) & 0x00FF;
;				bx = word[vga_offset_now] - 2000;
;				word[vga_offset_now] -= 2000;
;			else:
;				ax = 0;
;				bx = 0;
;				word[vga_offset_now] = 0;
;	  else:
;			ax = 80 =>
;			if (word[vga_offset_now] - 80) >= 80:
;				ax = (word[vga_offset_now] - 80) & 0x00FF;
;				bx = word[vga_offset_now] - 80;
;				word[vga_offset_now] -= 80;
;			else:
;				ax = 0;
;				bx = 0;
;				word[vga_offset_now] = 0;
;	  dx = 0x03D5

	call	vga_calc_offset_line_move
	mov		bx,		word[vga_offset_now]
	sub		bx,		ax
	mov		ax,		bx
	cmp		ax,		80
	jge		.greater_or_eq_than_80
	xor		ax,		ax
.greater_or_eq_than_80:
;	jmp		vga_update_line

vga_update_line:
;hardware scrolling
;
;in:  ax = offset
;out: ax = ax & 0x00FF
;	  bx = ax
;	  dx = 0x03D5
;	  word[vga_offset_now] = offset from IN ax
	mov		word[vga_offset_now],   ax
	mov		bx,		ax

	mov		dx,		VGA_CRTC
	mov		al,		VGA_CRTC_HIGH_BYTE
	out		dx,		al
	
	inc		dx
	mov		al,		bh
	out		dx,		al
	
	dec		dx
	mov		al,		VGA_CRTC_LOW_BYTE
	out		dx,		al

	inc		dx
	mov		al,		bl
	out		dx,		al
	retn

vga_cursor_move:
;in:  
;out: bx = word[vga_pos_cursor] / 2
;	  dx = 0x03D5
;	  al = bh
	mov		bx,		word[vga_pos_cursor]
.without_get_pos_cursor_with_div:
	shr		bx,		1	;div to VGA_CHAR_SIZE
.without_get_pos_cursor:
	mov		dx,		CURSOR_DATA
	mov		al,		LOW_BYTE_NOW
	out		dx,		al

	inc		dx	;CURSOR_OFFSET
	mov		al,		bl
	out		dx,		al

	dec		dx	;CURSOR_DATA
	mov		al,		HIGH_BYTE_NOW
	out		dx,		al
	
	inc		dx	;CURSOR_OFFSET
	mov		al,		bh
	out		dx,		al
	retn

vga_cursor_disable:    
;in:  
;out: bx = word[vga_pos_cursor]
;     dx = 0x03D5
;     al = bh
	mov     dx,     CURSOR_DATA
	mov     al,     0x0A
	out     dx,     al

	inc     dx  ;CURSOR_OFFSET
	mov     al,     0x20
	out     dx,     al
	retn

vga_cursor_enable:    
	mov		dx,		CURSOR_DATA
	mov		al,		0x0A
	out		dx,		al

	inc		dx	;CURSOR_OFFSET
	in		al,		dx
	and		al,		0xC0
	or		al,		15
	out		dx,		al

	dec		dx	;CURSOR_DATA
	mov		al,		0x0A
	out		dx,		al

;	mov		dx,		CURSOR_DATA
	mov		al,		0x0B
	out		dx,		al

	inc		dx	;CURSOR_OFFSET
	in		al,		dx
	and		al,		0xE0
	or		al,		15
	out		dx,		al
	retn
