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

%include "../source/syscall.inc"

newfile:
;	push	ds
;	push	ss
;	pop		ds
	
;	mov		si,		bp
;	xor		cx,		cx
;.copy_from_argv:
;	lodsb
;	mov		di,		FAT12_STR
;	add		di,		cx
;	mov		byte[ds:di], al
;	inc		cx
;	cmp		cx,		11
;	je		.fat12_fname_len_max_12_chars
;	test	al,		al
;	jne		.copy_from_argv

;	pop		ds
;	mov		si,		FAT12_STR
;	mov		bx,		SYSCALL_TTY_PRINT_ASCII_C
;	int		0x20

	mov		bx,		SYSCALL_FAT12_WRITE_FILE
	mov		si,		testfname
	mov		dx,		fdata
	mov		cx,		1
	push	ds
	pop		fs
	int		0x20
	xor		ax,		ax
	retf
.fat12_fname_len_max_12_chars:
	pop		ds
	mov		si,		error_len_max_12_chars
	mov		bx,		SYSCALL_TTY_PRINT_ASCII_C
	int		0x20
	retf

testfname: db "TESTTESTBIN"
error_len_max_12_chars: db 0x0A, "In FAT12 max lenght of filename is 11 chars: 8 to name and 3 to ext."
fdata: db 0

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

FAT12_STR_ONLY_BIN db "BIN"
FAT12_STR equ $
FAT12_STRLEN equ 11
FAT12_STRLEN_WITHOUT_EXT equ 8
FAT12_EXT equ FAT12_STR + 8
