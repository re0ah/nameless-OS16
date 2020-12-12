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
rtc_get_info:
;in: al = rtc register address
	out		RTC_SELECT_PORT,	al
	in		al,		RTC_RW_PORT
	retn

rtc_get_min:
;out: al = minutes from CMOS
	mov		al,		RTC_MINUTE
	jmp		rtc_get_info

rtc_get_hour:
;out: al = hour from CMOS
	mov		al,		RTC_HOUR
	jmp		rtc_get_info

rtc_get_week:
;out: al = week from CMOS
	mov		al,		RTC_WEEK
	jmp		rtc_get_info

rtc_get_day:
;out: al = day from CMOS
	mov		al,		RTC_DAY
	jmp		rtc_get_info

rtc_get_month:
;out: al = month from CMOS
	mov		al,		RTC_MONTH
	jmp		rtc_get_info

rtc_get_year:
;out: al = year from CMOS
	mov		al,		RTC_YEAR
	jmp		rtc_get_info

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
	jmp		rtc_get_info

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
