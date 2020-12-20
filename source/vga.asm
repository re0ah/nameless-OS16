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

vga_pos_cursor  dw 0
vga_color		db 0x07 ;bg: black, fg: gray
vga_memory_size dw 0

vga_init:
;find out of number VRAM
	retn

vga_set_video_mode:
;al - video mode
	xor		ah,		ah
	int		0x10
	retn

vga_clear_screen:
;in:
;out: ah = byte[vga_color]
;	  al = 0
;	  di = 0
;	  cx = 0
;	  bx = 0
;	  dx = 0x03D5
	mov		ah,		byte[vga_color]
	mov		al,		' '
;fill with ax first page of VGA_BUFFER
	xor		di,		di
	mov		cx,		VGA_PAGE_NUM_CHARS
	rep		stosw	;ax -> es:di

	xor		bx,		bx
	mov		word[vga_pos_cursor], bx
	jmp		vga_cursor_move.without_get_pos_cursor

vga_page_now db 0
vga_page_set:
;in: al=page
	mov		ah,		0x05
	int		0x10
	retn

vga_page_up:
	mov		al,		byte[vga_page_now]
	test	al,		al
	je		.page_top
	dec		al
	mov		byte[vga_page_now],	al
	jmp		vga_page_set
.page_top:
	retn

vga_page_down:
	mov		al,		byte[vga_page_now]
	cmp		al,		VGA_PAGES - 1
	je		.page_down
	inc		al
	mov		byte[vga_page_now],	al
	jmp		vga_page_set
.page_down:
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
