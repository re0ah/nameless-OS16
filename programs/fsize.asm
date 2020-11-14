bits 16
%include "../source/syscall.inc"

FAT12_ENTRY_NOT_FOUND equ 0xFFFF

fsize:
	mov		bx,		SYSCALL_FAT12_FILE_SIZE
	mov		si,		tst
	int		0x20
	cmp		ax,		FAT12_ENTRY_NOT_FOUND
	je		.not_found

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
	mov		si,		tst
	mov		bx,		SYSCALL_UINT_TO_ASCII
	int		0x20
	mov		bx,		SYSCALL_TTY_PRINT_ASCII
	int		0x20
	retn

FILE_NOT_FOUND db 0x0A, "file not found"
	FILE_NOT_FOUND_SIZE equ $-FILE_NOT_FOUND

tst db "LS     BIN"
