bits 16
%include "../source/syscall.inc"

DISK_BUFFER equ 0x6000
VGA_BUFFER	equ 0xB800

ls:
	mov		bx,		SYSCALL_NEXT_ROW
	int		0x20
	mov     bx,     SYSCALL_FAT12_READ_ROOT
	int     0x20
	mov		ax,		DISK_BUFFER
	mov		fs,		ax
;	xor		bx,		bx
	mov		bx,		32
	jmp		.lp_in
.lp:
	push	bx
	mov		si,		COMMA
	mov		cx,		2
	mov		bx,		SYSCALL_PRINT_ASCII
	int		0x20
	pop		bx
.lp_in:
	mov		si,		bx
	mov		di,		FAT12
.cp_fname:
	mov		al,		byte[fs:si]
	mov		byte[ds:di], al
	inc		si
	inc		di
	cmp		di,		FAT12_END
	jne		.cp_fname

	push	bx
	mov		si,		FAT12
	mov		cx,		11
	mov		bx,		SYSCALL_PRINT_ASCII
	int		0x20
	pop		bx
	
	add     bx,     DIR_ENTRY_SIZE * 2 ;to next entry
	mov		al,		byte[fs:bx]
	test	al,		al
	jne		.lp
	
	retf

FAT12 db "           "
	FAT12_END equ $
COMMA db ", "
FAT12_FULLNAME_SIZE equ 11
NUM_OF_ENTRIES_ROOT_DIR equ 224
DIR_ENTRY_SIZE equ 32 ;in bytes
ROOT_DIR_SIZE equ NUM_OF_ENTRIES_ROOT_DIR * DIR_ENTRY_SIZE
