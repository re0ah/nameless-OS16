RTC_SELECT_PORT	equ 0x70
RTC_RW_PORT		equ 0x71

RTC_SECOND	equ 0x00
RTC_MINUTE	equ 0x02
RTC_HOUR 	equ 0x04
RTC_WEEK	equ 0x06
RTC_DAY		equ 0x07
RTC_MONTH	equ 0x08
RTC_YEAR	equ 0x09
RTC_CENTURY equ 0x09

rtc_get_sec:
;out: al = seconds from CMOS
;	mov		al,		RTC_SECONDS
	xor		al,		al
	out		RTC_SELECT_PORT,	al

	in		al,		RTC_RW_PORT
	retn

rtc_get_min:
;out: al = minutes from CMOS
	mov		al,		RTC_MINUTE
	out		RTC_SELECT_PORT,	al

	in		al,		RTC_RW_PORT
	retn

rtc_get_hour:
;out: al = hour from CMOS
	mov		al,		RTC_HOUR
	out		RTC_SELECT_PORT,	al

	in		al,		RTC_RW_PORT
	retn

rtc_get_week:
;out: al = week from CMOS
	mov		al,		RTC_WEEK
	out		RTC_SELECT_PORT,	al

	in		al,		RTC_RW_PORT
	retn

rtc_get_day:
;out: al = day from CMOS
	mov		al,		RTC_DAY
	out		RTC_SELECT_PORT,	al

	in		al,		RTC_RW_PORT
	retn

rtc_get_month:
;out: al = month from CMOS
	mov		al,		RTC_MONTH
	out		RTC_SELECT_PORT,	al

	in		al,		RTC_RW_PORT
	retn

rtc_get_year:
;out: al = year from CMOS
	mov		al,		RTC_YEAR
	out		RTC_SELECT_PORT,	al

	in		al,		RTC_RW_PORT
	retn

rtc_get_century:
;out: al = century from CMOS
	mov		al,		108
	out		RTC_SELECT_PORT,	al

	in		al,		RTC_RW_PORT
	test	al,		al
	jne		.if_have_field
	cmp		al,		0x90
	jl		.if_less
	mov		al,		0x20
	retn
.if_less:
	mov		al,		0x90
	retn
.if_have_field:
	out		RTC_SELECT_PORT,	al
	in		al,		RTC_RW_PORT
	retn

rtc_get_ascii_sec:
;in:  si = address where save time
;out: al = century from CMOS
	call	rtc_get_sec
	jmp		BCD_to_ascii_2_bytes

rtc_get_ascii_min:
;in:  si = address where save time
;out: al = century from CMOS
	call	rtc_get_min
	jmp		BCD_to_ascii_2_bytes

rtc_get_ascii_hour:
;in:  si = address where save time
;out: al = century from CMOS
	call	rtc_get_hour
	jmp		BCD_to_ascii_2_bytes

rtc_get_ascii_week:
;in:  si = address where save time
;out: al = century from CMOS
	call	rtc_get_week
	jmp		BCD_to_ascii_2_bytes

rtc_get_ascii_day:
;in:  si = address where save time
;out: al = century from CMOS
	call	rtc_get_day
	jmp		BCD_to_ascii_2_bytes

rtc_get_ascii_month:
;in:  si = address where save time
;out: al = century from CMOS
	call	rtc_get_month
	jmp		BCD_to_ascii_2_bytes

rtc_get_ascii_year:
;in:  si = address where save time
;out: al = century from CMOS
	call	rtc_get_year
	jmp		BCD_to_ascii_2_bytes

rtc_get_ascii_century:
;in:  si = address where save time
;out: al = century from CMOS
	call	rtc_get_century
;	jmp		BCD_to_ascii_2_bytes

BCD_to_ascii_2_bytes:
;in:  al = BCD byte
;	  si = address where save time
;out: al = century from CMOS
	mov		ah,		al
	and		ah,		0x0F
	shr		al,		4
	add		ax,		0x3030

	mov		word[si],	ax
	retn
