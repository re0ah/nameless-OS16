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
PIT_DEFAULT_FREQUANCY equ 1193182 ;that is 0x001234DE, 32bit value.
								;need to be careful with him

pit_init:
	mov		al,		PIT_CONTROL_WORD_FORMAT
	out		PIT_COMMAND_PORT,	al
	mov		ax,		PIT_DEFAULT_FREQUANCY / 32
	out		PIT_0_PORT,		al
	mov		al,		ah
	out		PIT_0_PORT,		al
	retn

pit_int:
;	push	gs
;	push	ds
;	mov		ax,		KERNEL_OFFSET
;	mov		ds,		ax
;	mov		ax,		word[ds:pit_handler_segment]
;	mov		gs,		ax
;	mov		ax,		word[gs:pit_handler]
;	pop		ds
;	call	gs:ax
;	pop		gs
	mov		al,		PICM
	out		PIC_EOI, al
	iret

pit_handler			dw void_func
pit_handler_segment dw KERNEL_OFFSET

void_func:
	retn

_interrupt_set_pit_handler:
;in: cx = addr of func
	push	ds
	push	ds
	mov		ax,		KERNEL_OFFSET
	mov		ds,		ax
	mov		word[ds:pit_handler], cx
	pop		ax
	mov		word[ds:pit_handler_segment], ax
	pop		ds
	retn
