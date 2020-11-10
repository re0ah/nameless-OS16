bits 16
%include "../source/syscall.inc"

DISK_BUFFER equ 0x6000

ls:
	mov		bx,		SYSCALL_TTY_NEXT_ROW
	int		0x20
	mov     bx,     SYSCALL_FAT12_READ_ROOT
	int     0x20
	mov		ax,		DISK_BUFFER
	mov		fs,		ax
	mov		dx,		DIR_ENTRY_SIZE 
	jmp		.lp_in
.lp:
	push	dx
	mov		si,		COMMA
	mov		cx,		COMMA_SIZE
	mov		bx,		SYSCALL_TTY_PRINT_ASCII
	int		0x20
	pop		dx
.lp_in:
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
