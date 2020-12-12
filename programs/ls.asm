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

ls:
	mov		bx,		SYSCALL_TTY_NEXT_ROW
	int		0x20
	mov     bx,     SYSCALL_FAT12_READ_ROOT
	int     0x20
	mov		ax,		DISK_BUFFER
	mov		fs,		ax
;	xor		dx,		dx
	mov		dx,		32
	jmp		.lp_in
.lp:
	mov		bx,		dx
	mov		al,		byte[fs:bx + 11]
	cmp		al,		WINDOWS_MARKER
	je		.inc_cmp
	push	dx
	mov		si,		COMMA
	mov		cx,		COMMA_SIZE
	mov		bx,		SYSCALL_TTY_PRINT_ASCII
	int		0x20
	pop		dx
.lp_in:
	mov		bx,		dx
	mov		al,		byte[fs:bx + 11]
	cmp		al,		WINDOWS_MARKER
	je		.inc_cmp
	mov		si,		dx
	mov		cx,		dx
	add		cx,		FAT12_SIZE
	mov		di,		FAT12_FNAME
.cp_fname:
	mov		al,		byte[fs:si]
	cmp		al,		' '
	je		.if_space
	mov		byte[ds:di], al
	inc		di
	jmp		.if_not_space
.if_space:
	inc		si
	mov		al, 	byte[fs:si]
	cmp		al,		' '
	je		.if_space2
	mov		al,		'.'
	mov		byte[ds:di], al
	inc		di
	jmp		.if_space2
.if_not_space:
	inc		si
.if_space2:
	cmp		si,		cx
	jne		.cp_fname

	push	dx
	mov		si,		FAT12_FNAME
	mov		cx,		di
	sub		cx,		FAT12_FNAME
	mov		bx,		SYSCALL_TTY_PRINT_ASCII
	int		0x20
	pop		dx
.inc_cmp:	
	add     dx,     DIR_ENTRY_SIZE
	mov		bx,		dx
	mov		al,		byte[fs:bx]
	test	al,		al
	jne		.lp
	
	retf

FAT12_FNAME db "           "
	FAT12_END equ $
	FAT12_SIZE equ $ - FAT12_FNAME
COMMA db ", "
	COMMA_SIZE equ $ - COMMA
	
DIR_ENTRY_SIZE equ 32 ;in bytes
