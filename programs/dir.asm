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

dir:
	mov     bx,     SYSCALL_FAT12_READ_ROOT
	int     0x20
	mov		ax,		DISK_BUFFER
	mov		fs,		ax
	xor		bx,		bx
.lp:
	mov		al,		byte[fs:bx + 11]
	cmp		al,		WINDOWS_MARKER
	je		.inc_cmp
	push	bx
	push	ds
	mov		ax,		DISK_BUFFER
	mov		ds,		ax
	mov		si,		bx
	mov		bx,		SYSCALL_TTY_NEXT_ROW
	int		0x20
	mov		cx,		8
	mov		bx,		SYSCALL_TTY_PRINT_ASCII
	int		0x20
	mov		al,		' '
	mov		bx,		SYSCALL_TTY_PUTCHAR_ASCII
	int		0x20
	mov		cx,		3
	mov		bx,		SYSCALL_TTY_PRINT_ASCII
	int		0x20
	pop		ds

	mov		al,		' '
	mov		bx,		SYSCALL_TTY_PUTCHAR_ASCII
	int		0x20
	pop		bx

.print_fsize:
	push	bx
	mov		si,		bx
	add		si,		FAT12_FILE_SIZE_POS
	mov		ax,		word[fs:si]
	add		si,		2
	mov		bx,		word[fs:si]
	push	bx
	mov		si,		FAT12_FNAME
	mov		bx,		SYSCALL_UINT_TO_ASCII
	int		0x20
	mov		bx,		SYSCALL_TTY_PRINT_ASCII
	int		0x20
	mov		si,		FAT12_FNAME
	pop		ax
	test	ax,		ax
	je		.if_fsize_null
	mov		bx,		SYSCALL_UINT_TO_ASCII
	int		0x20
	mov		bx,		SYSCALL_TTY_PRINT_ASCII
	int		0x20
.if_fsize_null:
	mov		al,		' '
	mov		bx,		SYSCALL_TTY_PUTCHAR_ASCII
	int		0x20
	pop		bx
.print_date:
	push	bx
	call	print_date
	mov		al,		' '
	mov		bx,		SYSCALL_TTY_PUTCHAR_ASCII
	int		0x20
	pop		bx

	push	bx
	call	print_time
	pop		bx
	
.inc_cmp:
	add     bx,     DIR_ENTRY_SIZE
	mov		al,		byte[fs:bx]
	test	al,		al
	jne		.lp
	
	xor		ax,		ax	;exit status
	retf

print_date:
	mov		si,		bx
	add		si,		FAT12_DATE_POS
	mov		ax,		word[fs:si]
.year:
	push	ax
	shr		ax,		9
	add		ax,		1980	;DOS timestamp
	call	print_number
	mov		al,		'-'
	mov		bx,		SYSCALL_TTY_PUTCHAR_ASCII
	int		0x20
	pop		ax
.month:
	push	ax
	and		ax,		0x01FF
	shr		ax,		5
	call	print_number
	mov		al,		'-'
	mov		bx,		SYSCALL_TTY_PUTCHAR_ASCII
	int		0x20
	pop		ax
.day:
	push	ax
	and		ax,		0x001F
	call	print_number
	pop		ax
	retn

print_time:
	mov		si,		bx
	add		si,		FAT12_TIME_POS
	mov		ax,		word[fs:si]
.hour:
	push	ax
	shr		ax,		11
	call	print_number
	mov		al,		':'
	mov		bx,		SYSCALL_TTY_PUTCHAR_ASCII
	int		0x20
	pop		ax
.minute:
	push	ax
	shl		ax,		5
	shr		ax,		10
	call	print_number
	mov		al,		':'
	mov		bx,		SYSCALL_TTY_PUTCHAR_ASCII
	int		0x20
	pop		ax
.seconds_div_2:
	push	ax
	and		ax,		0x001F
	call	print_number
	pop		ax
	retn

print_number:
	mov		si,		FAT12_FNAME
	cmp		ax,		10
	jl		.with_null
	mov		bx,		SYSCALL_UINT_TO_ASCII
	int		0x20
.back:
	mov		bx,		SYSCALL_TTY_PRINT_ASCII
	int		0x20
	retn
.with_null:
	mov		bl,		'0'
	mov		byte[si],	bl
	inc		si
	mov		bx,		SYSCALL_UINT_TO_ASCII
	int		0x20
	dec		si
	inc		cx
	jmp		.back

FAT12_FNAME db "           "
	FAT12_END equ $
	FAT12_SIZE equ $ - FAT12_FNAME
	db "     "
	FSIZE_SIZE equ $ - FAT12_FNAME
	FSIZE_END equ $
	
DIR_ENTRY_SIZE equ 32 ;in bytes
FAT12_FILE_SIZE_POS equ 28
FAT12_DATE_POS equ 16
FAT12_TIME_POS equ 14
