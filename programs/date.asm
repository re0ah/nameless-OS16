%include "../source/syscall.inc"

date:
	mov		bx,		SYSCALL_TTY_NEXT_ROW
	int		0x20

	mov		si,		print_date_buf_end - 2
	mov		bx,		SYSCALL_RTC_GET_ASCII_SEC - 2
.lp:
	add		bx,		0x02	;size of syscall, rtc 
							;syscalls located consistenly
	push	bx
	int		0x20
	pop		bx
	sub		si,		3
	cmp		bx,		SYSCALL_RTC_GET_ASCII_CENTURY - 2
	jne		.lp
	mov		si,		print_date_buf
	int		0x20
	
	mov		cx,		PRINT_DATE_BUF_SIZE
	mov		bx,		SYSCALL_TTY_PRINT_ASCII
	int		0x20
	retf
print_date_buf db "year-mn-dy h :m :s "
	print_date_buf_end equ $
	PRINT_DATE_BUF_SIZE equ $-print_date_buf
