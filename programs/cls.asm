bits 16
%include "../source/syscall.inc"

cls:
	mov		bx,		SYSCALL_VGA_CLEAR_SCREEN
	int		0x20
	xor		cx,		cx
	mov		bx,		SYSCALL_VGA_CURSOR_MOVE
	int		0x20
	retf
