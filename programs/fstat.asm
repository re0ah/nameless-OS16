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

FAT12_ENTRY_NOT_FOUND equ 0xFFFF

fstat:
	call	get_fname_from_argv
	mov		bx,		SYSCALL_FAT12_FILE_SIZE
	mov		si,		tst
	int		0x20
	cmp		ax,		FAT12_ENTRY_NOT_FOUND
	je		.not_found

	push	ax
	push	dx
	mov		si,		str_name
	mov		cx,		STR_FNAME_SIZE
	mov		bx,		SYSCALL_TTY_PRINT_ASCII
	int		0x20
	pop		dx
	pop		ax

	test	dx,		dx
	je		.if_high_bytes_zero
	push	ax
	mov		ax,		dx
	call	print_fsize
	pop		ax
.if_high_bytes_zero:
	call	print_fsize
	retf

.not_found:
	mov		si,		FILE_NOT_FOUND
	mov		cx,		FILE_NOT_FOUND_SIZE 
	mov		bx,		SYSCALL_TTY_PRINT_ASCII
	int		0x20

	mov		ax,		-1	;exit status
	retf

get_fname_from_argv:
	mov		si,		bp
	mov		di,		tst
.count:
	mov		al,		byte[ss:si]
	mov		byte[ds:di],	al
	inc		di
	inc		si
	test	al,		al
	je		.end
	cmp		al,		' '
	jne		.count
.end:
	sub		si,		bp
	mov		cx,		si
	mov		si,		tst

	retn

print_fsize:
;in: ax = size
	mov		si,		str1
	mov		bx,		SYSCALL_UINT_TO_ASCII
	int		0x20
	mov		si,		str_size
	mov		cx,		STR_SIZE_SIZE
	mov		bx,		SYSCALL_TTY_PRINT_ASCII
	int		0x20
	retn

FILE_NOT_FOUND db 0x0A, "file not found"
	FILE_NOT_FOUND_SIZE equ $-FILE_NOT_FOUND

str_size db "Size: "
str1 db "       " ;2097152 = 2^12 * 512
	 STR_SIZE_SIZE equ $ - str_size

str_name db 0x0A, "File: "
tst db "FNAME   BIN"
	db 0x0A
	STR_FNAME_SIZE equ $ - str_name
