bits 16
fm:
	xor		si,		si

	retf

VGA_START_ADDR	equ 0xB800
VGA_BUF_SIZE	equ 32768 ;bytes
VGA_WIDTH		equ 80
VGA_HEIGHT		equ 25
VGA_CHAR_SIZE	equ 2 ;bytes
VGA_LINE_SIZE	equ VGA_WIDTH * VGA_CHAR_SIZE
VGA_PAGES		equ 8 ;page 0 for show, 1..7 for stored
VGA_PAGE_NUM_CHARS equ VGA_WIDTH * VGA_HEIGHT ;2000 chars
VGA_PAGE_SIZE equ VGA_PAGE_NUM_CHARS * VGA_CHAR_SIZE ;4000 bytes

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
tty_start:
	mov		ax,		VGA_START_ADDR
	mov		es,		ax		;es - video segment now
	mov		byte[vga_color], 0x07

	call	clear_screen

	mov		si,		HELLO_MSG
	mov		cx,		HELLO_MSG_SIZE
	call	vga_print_ascii

	mov		word[vga_pos_cursor], VGA_LINE_SIZE
	call	cursor_move
	mov		word[tty_input_start], VGA_LINE_SIZE

	call	print_path

.input:
	call	bios_wait_keyboard_input
	cmp		ah,		0x1C ;scancode '\n'
	jne		.not_enter
	call	tty_push_enter
	jmp		.input
.not_enter:
	cmp		ah,		0x0E ;scancode backspace
	jne		.not_backspace
	call	tty_push_backspace
	jmp		.input
.not_backspace:
	cmp		al,		0x20
	jl		.input
	cmp		al,		0x7E
	jg		.input
	call	vga_putchar_ascii

	jmp		.input
	retn

clear_screen:
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
	call	cursor_move
	retn

CURSOR_DATA		equ	0x03D4	;this port get high byte cursor position
CURSOR_OFFSET	equ	0x03D5	;this port get low  byte cursor position
HIGH_BYTE_NOW	equ	0x0E	;next byte in CURSOR_OFFSET will be high
LOW_BYTE_NOW	equ	0x0F	;next byte in CURSOR_OFFSET will be low
cursor_move:
;in:  
;out: bx = word[vga_pos_cursor]
;	  dx = 0x03D5
;	  al = bh
	mov		bx,		word[vga_pos_cursor]
	shr		bx,		1	;div to VGA_CHAR_SIZE

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

vga_putchar_ascii:
;in:  al = ASCII
;out: ax = vga_char (al = ASCII, ah = color)
;	  bx = word[vga_pos_cursor]
	mov		ah,		byte[vga_color]
	mov		bx,		word[vga_pos_cursor]
	mov		word[es:bx],	ax
	add		word[vga_pos_cursor], VGA_CHAR_SIZE
	call	cursor_move
	retn

;vga_char_to_ascii:
;in: ax = vga_char (al = ASCII, ah = color)
;	retn
;just read al, why need this function?

vga_print_ascii:
;in:  si = ptr to str
;	  cx = len of str
;out: si = end of str
;	  cx = 0
;	  ax = vga_char of last symbol in si (al = ASCII, ah = color)
;	  bx = word[vga_pos_cursor]
.lp:
	lodsb	;al <- ds:si
	call	vga_putchar_ascii
	loop	.lp
	retn

vga_next_row:
;in:  
;out: al = bh
;	  bx = word[vga_pos_cursor]
;	  cx = (num_of_row + 1) * 32
;	  dx = 0x03D5
;need calc the row now, inc and mul to 80 * VGA_CHAR_SIZE
	mov		ax,		word[vga_pos_cursor]
	mov		bl,		160
	div		bl
	and		ax,		0x00FF

	inc		ax

	;mov		bl,		160
	;mul		bl
	shl		ax,		5
	mov		cx,		ax
	shl		ax,		2
	add		ax,		cx

	mov		word[vga_pos_cursor],	ax
	mov		word[tty_input_start],	ax
	
	call	cursor_move
	retn

get_vga_input_ascii:
;in:  di = addr where save ascii
;	  es = segment where save ascii
;out: si = str
;	  cx = str len
;vga_pos_cursor  dw 0
;vga_color	    db 0
;tty_input_start dw 0
;path_now		db 0
	push	ds

	mov		cx,		word[vga_pos_cursor]
	mov		si,		word[tty_input_start]
	mov		ax,		VGA_START_ADDR	
	mov		ds,		ax
.lp:
	lodsw	;ax (vga char)   <- ds:si, si += 2
	stosb	;al (ascii char) -> es:di, di += 1
	cmp		si,		cx
	jl		.lp

	pop		ds
	sub		cx,		word[tty_input_start]
	shr		cx,		1
	retn

tty_push_enter:
	mov		ax,		word[tty_input_start]
	cmp		ax,		word[vga_pos_cursor]
	je		.exit	;if has not input

	sub		sp,		0x400	;alloc 1024 bytes on stack

;1. save user input on stack
	mov		es,		ax
	mov		di,		sp
	call	get_vga_input_ascii
	mov		ax,		VGA_START_ADDR
	mov		es,		ax

	mov		si,		sp
	push	es
	push	ds
	pop		es
	push	ds
	mov		ax,		ss
	mov		ds,		ax
	call	str_to_fat12_filename
	pop		ds
	pop		es

	mov		si,		FAT12_STR
	test	ax,		ax
	je		.execve_success
;test input on screen
;	mov		cx,		11
;	mov		si,		FAT12_STR
;.lp:
;	mov		al,		byte[ds:si]
;	inc		si
;	call	vga_putchar_ascii
;	loop	.lp
;	mov		ax,		KERNEL_OFFSET
;	mov		ds,		ax
	call	vga_next_row
	mov		si,		BAD_COMMAND_MSG
	mov		cx,		BAD_COMMAND_MSG_SIZE
	call	vga_print_ascii
.execve_success:
	add		sp,		0x400	;free stack

.exit:
	call	vga_next_row
	call	print_path
	retn

tty_push_backspace:
	mov		ax,		word[tty_input_start]
	cmp		ax,		word[vga_pos_cursor]
	je		.exit
	sub		word[vga_pos_cursor],	VGA_CHAR_SIZE
	mov		al,		' '
	mov		ah,		byte[vga_color]
	mov		bx,		word[vga_pos_cursor]
	mov		word[es:bx],	ax
	call	cursor_move
.exit:
	retn

print_path:
	mov		si,		pre_path_now
	inc		si
	mov		byte[si],	'\'
	inc		si
	mov		word[si],	0x3A5D ;"]:"
	add		si,		2
	mov		byte[si],	' '
	mov		si,		pre_path_now
	mov		cx,		5
	call	vga_print_ascii
	mov		cx,		10
	add		word[tty_input_start], cx
	retn

str_to_fat12_filename:
;in:  si = str (in format name.ext or name (in this case will add BIN as ext))
;	  cx = len
;	if have not ext then add ext as BIN
;out: si = FAT12 name
;if cx > 8, then cx = 8
	cmp		cx,		FAT12_STRLEN_WITHOUT_EXT
	jle		.check_strlen
	mov		cx,		FAT12_STRLEN_WITHOUT_EXT
.check_strlen:
;cp data input to FAT12_STR
	mov		ax,		cx
	mov		bx,		FAT12_STRLEN
	sub		bx,		cx
	mov		di,		FAT12_STR
	mov		cx,		FAT12_STRLEN_WITHOUT_EXT 
	rep		movsb	;ds:si -> es:di

	mov		si,		FAT12_STR_ONLY_BIN
	mov		cx,		bx
	add		si,		ax
	mov		di,		FAT12_STR
	add		di,		ax
	push	ds
	mov		ds,		ax
	rep		movsb	;ds:si -> es:di

	mov		si,		FAT12_STR
	mov		di,		FAT12_STRLEN_WITHOUT_EXT
	call	str_to_caps
	pop		ds

	retn

str_to_caps:
;in:  si = str
;	  di = len
;out: si = caps str
	add		di,		si
.lp:
	mov		al,		byte[ds:di]
	cmp		al,		'a'
	jnge	.lp_cmp
	cmp		al,		'z'
	jnle	.lp_cmp
	and		byte[ds:di],	0xDF
.lp_cmp:
	dec		di
	cmp		di,		si
	jge		.lp
	retn

bios_wait_keyboard_input:
;in:
;out: ah = scancode key
;	  al = ASCII    key
	xor		ax,		ax	;ah=0x00, wait input from keyboard and get value
	int		0x16	;BIOS, keyboard
	retn

HELLO_MSG db "Hello to tty, username"
	HELLO_MSG_SIZE equ $-HELLO_MSG

BAD_COMMAND_MSG db "command not found"
	BAD_COMMAND_MSG_SIZE equ $-BAD_COMMAND_MSG

FAT12_STR db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20
		  db 0x20, 0x20, 0x20, 0x20, 0x20
	FAT12_STRLEN equ $-FAT12_STR
	FAT12_STRLEN_WITHOUT_EXT equ FAT12_STRLEN - 3
	FAT12_EXT equ FAT12_STR + 8
FAT12_STR_ONLY_BIN	db "        BIN"

vga_pos_cursor  dw 0
vga_color	    db 0
tty_input_start dw 0
pre_path_now	db '['	;dont touch!
path_now		times 83 db 0 ;80 on path and 3 to "]: "
