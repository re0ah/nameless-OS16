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

int_to_ascii:
;in:  ax = int 
;	  si = ptr on str
;out: si = ascii str from number
;	  cx = len of str
;	  di = num_to_ascii_buffer
;	  al = high char in str
;	  dx = high sign in int
	cmp		ax,		0
	jnl		.not_neg_num
;if int < 0, make them positive (neg on negative numbers
;make positive numbers), write '-' in string buffer
	neg		ax
	mov		byte[ds:si],	'-'
	inc		si
.not_neg_num:
	call	uint_to_ascii
	dec		si
	inc		cx
	retn

uint_to_ascii:
;in:  ax = uint 
;	  si = ptr on str
;out: si = ascii str from number
;	  cx = len of str
;	  di = num_to_ascii_buffer
;	  al = high char in str
;	  dx = high sign in uint
	mov		di,		num_to_ascii_buf
	mov		cx,		10		;divisor
	mov		bl,		0x30	;need add for transform to ascii
.lp:
	xor		dx,		dx	;clear, because used in div instruction (dx:ax)
	div		cx			;ax = quotient, dx = remainder
	add		dl,		bl	;transform to ascii
	mov		byte[ds:di],	dl
	inc		di
	test	ax,		ax
	jne		.lp
.end_lp:
;	lea		cx,		[ds:di - num_to_ascii_buf] ;calc len of str
	mov		cx,		di
	sub		cx,		num_to_ascii_buf
.lp2:	;invert copy from di to si
	dec		di
	mov		al,		byte[ds:di]
	mov		byte[ds:si],	al
	inc		si
	cmp		di,		num_to_ascii_buf
	jne		.lp2
	sub		si,		cx	;si = start of str
	retn

str_to_fat12_filename:
;in:  si = str (in format name.ext or name (in this case will add BIN as ext))
;	  cx = len
;	if have not ext then add ext as BIN
;out: si = FAT12_STR
;	  cx = str len + FAT12_STR
;	  di = FAT12_STR + FAT12_STRLEN
	push	ds
;if cx > 8, then cx = 8
	cmp		cx,		FAT12_STRLEN_WITHOUT_EXT
	jle		.check_strlen
	mov		cx,		FAT12_STRLEN_WITHOUT_EXT
.check_strlen:
;cp data input to FAT12_STR
	mov		di,		FAT12_STR
	add		cx,		di ;end of str
.cp:
	lodsb	;ds:si -> al
	cmp		al,		'.'
	je		.if_ext
	cmp		al,		' '
	je		.end_cp
	stosb	;es:di <- al
	cmp		di,		cx
	jne		.cp
.end_cp:
	mov		ax,		KERNEL_SEGMENT
	mov		ds,		ax
	mov		si,		FAT12_STR_ONLY_BIN
.if_ext:
	mov		al,		' '
.fill_space:
	stosb
	cmp		di,		FAT12_STR + FAT12_STRLEN
	jne		.fill_space
	mov		di,		FAT12_EXT
.cp_ext:
	movsb
	cmp		di,		FAT12_STR + FAT12_STRLEN
	jne		.cp_ext
	mov		si,		KERNEL_SEGMENT
	mov		ds,		si
	mov		si,		FAT12_STR
	mov		di,		FAT12_STRLEN
	call	str_to_caps
	pop		ds
	retn

str_to_caps:
;in:  si = str
;	  di = len
;out: si = caps str
;	  di = si
;	  al = first char si
	add		di,		si ;make ptr to end of str
.lp:
	mov		al,		byte[ds:di]
	call	char_to_caps
	mov		byte[ds:di],	al
	dec		di
	cmp		di,		si
	jge		.lp
	retn

char_to_caps:
;in:  al = ascii
;out: al = caps ascii
	cmp		al,		'a'
	jnge	.end
	cmp		al,		'z'
	jnle	.end
	and		al,		0xDF
.end:
	retn

caps_to_char:
;in:  al = ascii
;out: al = caps ascii
	cmp		al,		'A'
	jnge	.end
	cmp		al,		'Z'
	jnle	.end
	or		al,		0x20
.end:
	retn

scancode_to_ascii:
;in:  al = scancode
;out: al = 0 if char not printable, else ascii
;	  bx = al
	mov		bl,		byte[kb_shift_pressed]
	test	bl,		bl
	je		.if_shift_not_pressed
	cmp		al,		0x53
	ja		.not_printable
	movzx	bx,		al
	mov		al,		byte[bx + SCANCODE_SET_WITH_SHIFT]
	call	if_caps
	jcxz	.caps_not_set
	jmp		caps_to_char
.if_shift_not_pressed:
	cmp		al,		0x53
	ja		.not_printable
	movzx	bx,		al
	mov		al,		byte[bx + SCANCODE_SET]
	call	if_caps
	jcxz	.caps_not_set
	jmp		char_to_caps
.not_printable:
	xor		al,		al
.caps_not_set:
	retn

;cstr_to_uint:
;in: si = C str
;    
;	movzx   cx,     byte[ss:bp]
;	sub     cx,     0x30
;	imul    cx,     di
;	imul    di,     10
;	add     bx,     cx
;	dec     bp
;	dec     al
;	test    al,     al
;	jne     .str_to_uint
