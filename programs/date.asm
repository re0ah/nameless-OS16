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
