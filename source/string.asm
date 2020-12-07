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
	neg		ax
	mov		byte[si],	'-'
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
	retn
num_to_ascii_buf times 6 db " "

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

	mov		ax,		KERNEL_OFFSET
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
	mov		si,		KERNEL_OFFSET
	mov		ds,		si
	mov		si,		FAT12_STR
	mov		di,		FAT12_STRLEN
	call	str_to_caps
	pop		ds
	retn

FAT12_STR times 11 db ' '
	FAT12_STRLEN equ $-FAT12_STR
	FAT12_STRLEN_WITHOUT_EXT equ FAT12_STRLEN - 3
	FAT12_EXT equ FAT12_STR + 8
FAT12_STR_ONLY_BIN	db "BIN"

str_to_caps:
;in:  si = str
;	  di = len
;out: si = caps str
;	  di = si
;	  al = first char si
	add		di,		si
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
	cmp		al,		0x35
	ja		.not_printable
	movzx	bx,		al
	mov		al,		byte[bx + SCANCODE_SET_WITH_SHIFT]
	call	if_caps
	jcxz	.caps_not_set
	call	caps_to_char
	retn
.if_shift_not_pressed:
	cmp		al,		0x53
	ja		.not_printable
	movzx	bx,		al
	mov		al,		byte[bx + SCANCODE_SET]
	call	if_caps
	jcxz	.caps_not_set
	call	char_to_caps
.caps_not_set:
	retn
.not_printable:
	xor		al,		al
	retn
