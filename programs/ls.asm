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

ls:
	mov     bx,     SYSCALL_FAT12_READ_ROOT
	int     0x20
	push	es	;save es for restore
	add		sp,		0x2000	;8 KiB
	;set es as ss, ds as DISK_BUFFER for movsw instruction
	push	ss
	pop		es
	mov		ax,		DISK_BUFFER
	mov		ds,		ax

	mov		di,		sp
;output start with new line
	mov		al,		0x0A
	stosb
	xor		bx,		bx
.lp:
	mov		si,		bx
	mov		al,		byte[ds:si + 11] ;attributes 
	cmp		al,		WINDOWS_MARKER
	je		.next
	xor		bp,		bp
.cp_fname:
	lodsb
	cmp		al,		' '
	je		.skip_spaces
	inc		bp
	stosb
	cmp		bp,		8
	jne		.cp_fname
.skip_spaces:
	lodsb
	cmp		al,		' '
	je		.skip_spaces
	dec		si
	mov		al,		'.'
	stosb
	xor		bp,		bp
.cp_ext:
	lodsb
	cmp		al,		' '
	je		.end_ext
	inc		bp
	stosb
	cmp		bp,		3
	jne		.cp_ext
.end_ext:
	mov		ax,		0x202C	;', '
	stosw
.next:
	add		bx,		DIR_ENTRY_SIZE	;to next entry
;check last file in directory or not
	mov		al,		byte[ds:bx]
	test	al,		al
	jne		.lp
	sub		di,		2
	stosb

;set ds as stack segment (because es was set as ss) for output
	push	es
	pop		ds
	mov		si,		sp
	sub		sp,		0x2000	;free stack
;restore es
	pop		es
	mov		bx,		SYSCALL_TTY_PRINT_ASCII_C
	int		0x20
	xor		ax,		ax	;exit status
	retf
