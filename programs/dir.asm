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
bits 16
%include "../source/syscall.inc"

DISK_BUFFER equ 0x6000
WINDOWS_MARKER equ 0x0F
DIR_ENTRY_SIZE equ 32 ;in bytes
FAT12_FILE_SIZE_POS equ 28
FAT12_DATE_POS equ 16
FAT12_TIME_POS equ 14

dir:
	mov     bx,     SYSCALL_FAT12_READ_ROOT
	int     0x20
;ds = DISK_BUFFER
;structure of one string for input: (numbers - bytes)
;|       12      | 1 |    11    | 1 | 10 | 1 |   8  |
;|fname, ' ', ext|' '|   fsize  |' '|date|' '| time |
;|---------------|---|----------|---|----|---|------|
;ds = disk buffer
	push	DISK_BUFFER
	pop		ds
;es = ss
	push	es	;store es
	push	ss
	pop		es

;commented, because bx = 0 after syscall fat12_read_root
;	xor		bx,		bx	;ptr on FAT12 entry
	sub		sp,		0x2010	;alloc 8 KiB on stack for create output message
							;also 16 bytes for function calls and interrupts
	mov		di,		sp
	add		di,		0x10
.lp:
	mov		al,		byte[ds:bx + 11] ;get file attributes
	cmp		al,		WINDOWS_MARKER
	je		.inc_cmp
;new line
	mov		al,		0x0A	;strings start with new line
	stosb	;byte[es:di] = al
;fname
	mov		si,		bx		;set ptr on start FAT12 entry. It's filename & ext
	mov		cx,		8	;fname
	rep		movsb	;byte[es:di] = byte[ds:si]
;space
	mov		al,		' '
	stosb	;byte[es:di] = al
;ext
	mov		cx,		3	;ext
	rep		movsb
	mov		ax,		' '
	stosb	;byte[es:di] = al
;fsize
	mov		ax,		word[ds:bx + FAT12_FILE_SIZE_POS]
	push	ax
	call	to_num
	sub		di,		cx
	mov		ax,		cx
	mov		cx,		11
	sub		cx,		ax
	mov		al,		' '
	rep		stosb
	pop		ax
	call	to_num
;2 space
	mov		ax,		0x2020
	stosw	;word[es:di] = ax
;year
	mov		ax,		word[ds:bx + FAT12_DATE_POS]
	push	ax
	shr		ax,		9
	add		ax,		1980	;DOS timestamp
	call	to_num
	mov		al,		'-'
	stosb	;byte[es:di] = al
;month
	pop		ax
	push	ax
	and		ax,		0x01FF
	shr		ax,		5
	call	if_less_then_ten
	call	to_num
	mov		al,		'-'
	stosb	;byte[es:di] = al
;day
	pop		ax
	and		ax,		0x001F
	call	if_less_then_ten
	call	to_num
;space
	mov		ax,		0x2020
	stosw	;word[es:di] = ax
;hour
	mov		ax,		word[ds:bx + FAT12_TIME_POS]
	push	ax
	shr		ax,		11
	call	if_less_then_ten
	call	to_num
;delim
	mov		al,		':'
	stosb	;byte[es:di] = al
;minute
	pop		ax
	push	ax
	shl		ax,		5
	shr		ax,		10
	call	if_less_then_ten
	call	to_num
;delim
	mov		al,		':'
	stosb	;byte[es:di] = al
;seconds
	pop		ax
	and		ax,		0x001F
	call	if_less_then_ten
	call	to_num
.inc_cmp:
	add		bx,		DIR_ENTRY_SIZE
	mov		al,		byte[ds:bx]
	test	al,		al
	jne		.lp
	stosb	;byte[es:di] = al
			;push \0 for output as C string

	push	ss
	pop		ds
	mov		si,		sp
	add		sp,		0x2010	;free stack
	pop		es

	add		si,		0x10
	mov		bx,		SYSCALL_TTY_PRINT_ASCII_C
	int		0x20

	xor		ax,		ax	;exit status
	retf

if_less_then_ten:
;in: ax = uint
	cmp		ax,		10
	jge		.not_less_ten_h
.less_ten_h:
	push	ax
	mov		al,		'0'
	stosb
	pop		ax
.not_less_ten_h:
	retn

to_num:
;in:  ax = uint 
;	  di = ptr on str
;out: di = ascii str from number
;	  cx = len of str
;	  si = num_to_ascii_buffer
;	  al = high char in str
;	  dx = high sign in uint
	push	bx
	push	ds
	mov		si,		cs
	mov		ds,		si
	mov		si,		num_to_ascii_buf
	mov		cx,		10		;divisor
	mov		bl,		0x30	;need add for transform to ascii
.lp:
	xor		dx,		dx	;clear, because used in div instruction (dx:ax)
	div		cx			;ax = quotient, dx = remainder
	add		dl,		bl	;transform to ascii
	mov		byte[ds:si],	dl
	inc		si
	test	ax,		ax
	jne		.lp
.end_lp:
	lea		cx,		[si - num_to_ascii_buf] ;calc len of str
.lp2:	;invert copy from di to si
	dec		si
	mov		al,		byte[ds:si]
	mov		byte[es:di],	al
	inc		di
	cmp		si,		num_to_ascii_buf
	jne		.lp2
	pop		ds
	pop		bx
	retn
num_to_ascii_buf:
