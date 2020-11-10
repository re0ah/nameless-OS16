int_to_ascii:
;in: ax=int 
;	 si=ptr on str
;out:si=ascii str from number
	cmp		ax,		0
	jnl		.not_neg_num
	neg		ax
	mov		bl,		'-'
	mov		byte[si],	bl
	inc		si
.not_neg_num:
	call	uint_to_ascii
	retn

divinder_int_to_ascii dw 10
uint_to_ascii:
;in: ax=uint 
;	 si=ptr on str
;out:si=ascii str from number
	push	si
	mov		di,		num_to_ascii_buf
.lp:
	xor		dx,		dx
	div		word[divinder_int_to_ascii]
	test	ax,		ax
	je		.end
	mov		bx,		ax
	add		dl,		0x30
	mov		byte[di],	dl
	mov		ax,		bx
	inc		di
	jmp		.lp
.end:
	add		dl,		0x30
	mov		byte[di],	dl
	inc		di
	mov		cx,		di
	sub		cx,		num_to_ascii_buf
.lp2:
	dec		di
	mov		al,		byte[di]
	mov		byte[si],	al
	inc		si
	cmp		di,		num_to_ascii_buf
	jne		.lp2
	pop		si
	retn
num_to_ascii_buf db "      "

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
	mov		ax,		KERNEL_OFFSET
	mov		ds,		ax
	rep		movsb	;ds:si -> es:di

	mov		si,		FAT12_STR
	mov		di,		FAT12_STRLEN_WITHOUT_EXT
	call	str_to_caps
	pop		ds

	retn

FAT12_STR db 0x20, 0x20, 0x20, 0x20, 0x20, 0x20
		  db 0x20, 0x20, 0x20, 0x20, 0x20
	FAT12_STRLEN equ $-FAT12_STR
	FAT12_STRLEN_WITHOUT_EXT equ FAT12_STRLEN - 3
	FAT12_EXT equ FAT12_STR + 8
FAT12_STR_ONLY_BIN	db "        BIN"

str_to_caps:
;in:  si = str
;	  di = len
;out: si = caps str
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

scancode_to_ascii:
;in:  al = scancode
;out: al = ascii
	cmp		al,		0x53
	ja		.not_printable
	mov		bl,		al
	xor		bh,		bh
	add		bx,		SCANCODE_SET
	mov		al,		byte[bx]
	call	if_caps
	jcxz	.caps_not_set
	call	char_to_caps
.caps_not_set:
	retn
.not_printable:
	xor		al,		al
	retn
