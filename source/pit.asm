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

;more on http://www.scs.stanford.edu/10wi-cs140/pintos/specs/8254.pdf
;control word register:
;	0    bit : BCD
;		0   = 16-bit binary counter
;		1   = 16-bit BCD    counter
;	1..3 bits: modes
;		000 = mode 0: interrupt on terminal count
; 		001 = mode 1: hardware retriggerable one-shot
; 		010 = mode 2: rate generator
; 		011 = mode 3: square wave
; 		100 = mode 4: software triggered strobe
; 		101 = mode 5: harware  triggered strobe (retriggerable)
; 	4..5 bits: read_write
;		00  = counter latch commands
;		01  = read/write least significant byte only
;		10  = read/write most  significant byte only
;		11  = read/write least significant byte first, them most significant byte
; 	6..7 bits: select counter
;		00  = counter 0
; 		01  = counter 1
; 		10  = counter 2
; 		11  = read-back command
PIT_0_PORT equ 0x40
PIT_COMMAND_PORT equ 0x43
PIT_MODE3 equ 0x06
PIT_RW4	  equ 0x30
PIT_CONTROL_WORD_FORMAT equ PIT_MODE3 | PIT_RW4
PIT_DEFAULT_FREQUENCY equ 1193182 ;that is 0x001234DE, 32bit value.
								  ;need to be careful with him

pit_init:
;just set frequency of PIT
	mov		ax,		PIT_DEFAULT_FREQUENCY / 32
pit_set_frequency:
;in:  ax = frequency
;out: al = ah
	mov		word[pit_frequency],	ax
	push	ax
	mov		al,		PIT_CONTROL_WORD_FORMAT
	out		PIT_COMMAND_PORT,	al
	pop		ax
	out		PIT_0_PORT,		al
	mov		al,		ah
	out		PIT_0_PORT,		al
	retn

pit_int:
	jmp		return_from_interrupt
