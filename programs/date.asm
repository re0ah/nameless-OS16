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

RTC_SELECT_PORT	equ 0x70
RTC_RW_PORT		equ 0x71

RTC_SECOND	equ 0x00
RTC_MINUTE	equ 0x02
RTC_HOUR 	equ 0x04
RTC_WEEK	equ 0x06
RTC_DAY		equ 0x07
RTC_MONTH	equ 0x08
RTC_YEAR	equ 0x09
RTC_CENTURY equ 0x32

date:
;print date now in format YEAR-MONTH-DAY HOUR:MIN:SEC + TIMEZONE
;date get from RTC
	mov		si,		print_date_buf_end - 4
	xor		ah,		ah
	mov		bx,		SYSCALL_RTC_GET_TIMEZONE_UTC
	int		0x20
	mov		bx,		SYSCALL_UINT_TO_ASCII
	int		0x20
	add		si,		cx
	mov		byte[si],	')'

	mov		si,		print_date_buf_end - 12
	mov		bp,		call_list
.lp:
	mov		al,		byte[ds:bp]
	mov		bx,		SYSCALL_RTC_GET_DATA_BCD
	int		0x20
	call	BCD_to_ascii
	sub		si,		3
	inc		bp
	cmp		bp,		CALL_LIST_END
	jne		.lp
	inc		si		;pos on 'y'
	mov		al,		RTC_CENTURY
	mov		bx,		SYSCALL_RTC_GET_DATA_BCD
	int		0x20
	call	BCD_to_ascii
	dec		si		;pos on '\n'
	
	mov		bx,		SYSCALL_TTY_PRINT_ASCII_C
	int		0x20
	xor		ax,		ax	;exit status
	retf

BCD_to_ascii:
;in:  al = BCD byte
;	  si = address where save time
;out: al = century from CMOS
	mov		ah,		al
	and		ah,		0x0F
	shr		al,		4
	add		ax,		0x3030

	mov		word[ds:si],	ax
	retn

print_date_buf db 0x0A, "year-mn-dy h :m :s  UTC(+t", 0x00, 0x00, 0x00
	print_date_buf_end equ $
	PRINT_DATE_BUF_SIZE equ $-print_date_buf

call_list:
	db RTC_SECOND
	db RTC_MINUTE
	db RTC_HOUR
	db RTC_DAY
	db RTC_MONTH
	db RTC_YEAR
CALL_LIST_END equ $
