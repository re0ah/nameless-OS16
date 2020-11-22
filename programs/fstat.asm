bits 16
%include "../source/syscall.inc"

FAT12_ENTRY_NOT_FOUND equ 0xFFFF

fstat:
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
	retf

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
tst db "LS      BIN"
	db 0x0A
	STR_FNAME_SIZE equ $ - str_name
