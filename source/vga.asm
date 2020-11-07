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

vga_pos_cursor  dw 0
vga_color		db 0

vga_clear_screen:
;in:
;out: ax = 0x0720
;	  di = 0
;	  cx = 0
;	  bx = word[vga_pos_cursor]
;	  dx = 0x03D5
	mov		ax,		0x0720 ;bg=black, fg=gray, char=' '
	xor		di,		di
	mov		cx,		VGA_PAGE_NUM_CHARS
	rep		stosw	;ax -> es:di

	mov		word[vga_pos_cursor], 0
	call	vga_cursor_move
	retn

vga_cursor_move:
;in:  
;out: bx = word[vga_pos_cursor]
;	  dx = 0x03D5
;	  al = bh
	mov		bx,		word[vga_pos_cursor]
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
