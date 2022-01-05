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
RTC_CENTURY equ 0x32


rtc_get_data_bcd:
;in:  al = RTC code for get data from CMOS
;out: al = BCD data from CMOS
	cmp		al,		RTC_CENTURY
	je		rtc_get_century
rtc_get_info:
	out		RTC_SELECT_PORT,	al
	in		al,		RTC_RW_PORT
	retn

rtc_get_data_bin:
;in:  al = RTC code for get data from CMOS
;out: al = bin data from CMOS
	call	rtc_get_data_bcd
	jmp		bcd_to_number

rtc_get_century:
;out: al = century from CMOS
	mov		al,		108
	out		RTC_SELECT_PORT,	al

	in		al,		RTC_RW_PORT
	test	al,		al
	jne		rtc_get_info
	cmp		al,		0x90
	jl		.if_less
	mov		al,		0x20
	retn
.if_less:
	mov		al,		0x90
	retn

bcd_to_number:
;in:  al = BCD
;out: al = number
	push	bx
	mov		bh,		al
	and		bh,		0x0F
	shr		al,		3
	mov		bl,		al
	shl		bl,		2
	add		al,		bl
	add		al,		bh
	pop		bx
	retn

set_timezone_utc:
;in: al = timezone
	mov		byte[timezone_utc],		al
	retn

get_timezone_utc:
;out: al = timezone
	mov		al,		byte[timezone_utc]
	retn
