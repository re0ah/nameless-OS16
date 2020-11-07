%include "../source/syscall.inc"

date:
;use BIOS 0x1A, system clock interrupt
;date's and time return in BCD
	mov		bx,		SYSCALL_TTY_NEXT_ROW
	int		0x20
	mov		ah,		0x04	;read date
	int		0x1A
;ch = century
;cl = year
;dh = month
;dl = day
	mov		si,		print_date_buf

	call	write_2_chars_from_bcd

	mov		ch,		cl
	call	write_2_chars_from_bcd
	inc		si

	mov		ch,		dh
	call	write_2_chars_from_bcd
	inc		si

	mov		ch,		dl
	call	write_2_chars_from_bcd
	inc		si

	mov		ah,		0x02	;read time
	int		0x1A
;ch = hours
;cl = minutes
;dh = seconds
	call	write_2_chars_from_bcd
	inc		si

	mov		ch,		cl
	call	write_2_chars_from_bcd
	inc		si

	mov		ch,		dh
	call	write_2_chars_from_bcd
	
	mov		si,		print_date_buf
	mov		cx,		PRINT_DATE_BUF_SIZE
	mov		bx,		SYSCALL_TTY_PRINT_ASCII
	int		0x20
	retf
print_date_buf db "year-mn-dy h :m :s "
	PRINT_DATE_BUF_SIZE equ $-print_date_buf

write_2_chars_from_bcd:
;in: si = buf
;	 ch = BCD number
	;call	bcd_to_ascii
	mov		ah,		ch
	and		ah,		0x0F
	mov		al,		ch
	shr		al,		4
	add		ax,		0x3030

	mov		word[si],	ax
	add		si,		2
	retn

bcd_to_ascii:
;convert 1 byte BCD to 2 char's ascii
;in:  ch = BCD number
;out: al = low  BCD number converted in ascii
;	  ah = high BCD number converted in ascii
;	retn
