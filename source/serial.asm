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

;thanks for information:
;https://www.youtube.com/watch?v=Fi2IU2TxKhI (отличные лекции)
;https://wiki.osdev.org/Serial_Ports
;https://en.wikipedia.org/wiki/Serial_port
;http://users.utcluj.ro/~baruch/media/siee/labor/Serial-Port.pdf

;base address COM port + offset = address of the register.
COM1_PORT equ 0x03F8
COM2_PORT equ 0x02F8
COM3_PORT equ 0x03E8
COM4_PORT equ 0x02E8

COM_THR equ 0x00 ;write, Transmitter Holding Register
COM_RBR equ 0x00 ;read,  Receiver Buffer Register
COM_LSB equ 0x00 ;r/w,   Divisor Latch Register LSB low
COM_IER equ 0x01 ;r/w,   Interrupt Enable Register
COM_MSB equ 0x01 ;r/w,   Divisor Latch Register MSB high
COM_IIR equ 0x02 ;read,  Interrupt Identification Register
COM_FCR equ 0x02 ;write, FIFO Control Register
COM_LCR equ 0x03 ;r/w,   Line Control Register
COM_MCR equ 0x04 ;r/w,   Modem Control Register
COM_LSR equ 0x05 ;read,  Line Status Register
COM_MSR equ 0x06 ;read,  Modem Status Register
COM_SCR equ 0x07 ;r/w,   Scratch Register

SYNC_CHAR equ 0x16

IRQ_COM1 equ 0x04
IRQ_COM2 equ 0x03
IRQ_COM3 equ 0x04
IRQ_COM4 equ 0x03

PICM	equ	0x20	;master PIC port
PICS	equ	0xA0	;slave PIC  port
PIC_EOI	equ	0x20	;end of interrupt code

serial_init:
;in:  
;out: al = 0x0B
;	  dx = COM1_PORT + COM_MCR
;disable interrupts of com port
	mov		al,		0x00
	mov		dx,		COM1_PORT + COM_IER
	out		dx,		al
;enable DLAB
	mov		al,		0x80
	mov		dx,		COM1_PORT + COM_LCR
	out		dx,		al
;set Baud rate (0x0003) 38,400 bits/s
	mov		al,		0x03
	mov		dx,		COM1_PORT + COM_LSB
	out		dx,		al

	mov		al,		0x00
	mov		dx,		COM1_PORT + COM_MSB
	out		dx,		al
;clear Baud rate bit and set (8 bits one message,
;                             one stop bit,
;                             no parity)
	mov		al,		0x03
	mov		dx,		COM1_PORT + COM_LCR
	out		dx,		al
;    enable FIFO, clear FIFO, reset FIFO, DMA off,
;interrupt requst generated after 14 chars
	mov		al,		0xC7
	mov		dx,		COM1_PORT + COM_FCR
	out		dx,		al
;RTS & DTR enable, IRQ enable, loop disable
	mov		al,		0x0B
	mov		dx,		COM1_PORT + COM_MCR
	out		dx,		al
	retn

serial_received:
;check if data ready (LSR bit 0)
;in:  
;out: al = 0x00 if have not data, 0x01 if have
;	  dx = COM1_PORT + COM_LSR
	mov		dx,		COM1_PORT + COM_LSR
	in		al,		dx
	and		al,		0x01
	retn

read_serial:
;read while data ready
;in:  
;out: al = data from com port
;	  dx = COM1_PORT + COM_RBR
	call	serial_received
	test	al,		al
	je		read_serial
	mov		dx,		COM1_PORT + COM_RBR
	in		al,		dx
	retn

is_transmit_empty:
;in:  
;out: al = 0x00 if transmit is empty, else 0x20
;	  dx = COM1_PORT + COM_LSR
	mov		dx,		COM1_PORT + COM_LSR
	in		al,		dx
	and		al,		0x20
	retn

write_serial:
;in:  al = char
;out: al = char
;	  dx = COM1_PORT + COM_THR
	push	ax
	call	is_transmit_empty
	test	al,		al
	je		write_serial
	pop		ax
	mov		dx,		COM1_PORT + COM_THR
	out		dx,		al
	retn

com1_int:
;for this interruption need buffer where will be stored received data.
;	in case of overflow data will be lost. In future, maybe, data will be saved
;in disk
	mov		bx,		word[com1_buffer_pos]
	cmp		bx,		COM1_BUFFER_SIZE
	je		.buffer_overflow

	mov		dx,		COM1_PORT + COM_RBR
	in		al,		dx

	mov		byte[COM1_BUFFER + bx],	al
	inc		bx
	mov		word[com1_buffer_pos],	bx
.buffer_overflow:
	jmp		return_from_interrupt
