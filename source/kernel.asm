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
bits 16

;memory map
;|---------------|0xFFFFF
;|      BIOS     |		 64KiB
;|---------------|0xF0000
;| EXTENDED BIOS |		 64KiB
;|---------------|0xE0000
;|      ROM      | 		 64KiB
;|---------------|0xD0000
;|  VIDEO BIOS   | 		 64KiB
;|---------------|0xC0000
;|      VGA      |		 128KiB
;|---------------|0xA0000
;|      EBDA     |		 1-128KiB. Extended BIOS data area.
;|---------------|0x80000
;|     STACK     | 		 64KiB
;|---------------|0x70000
;|  DISK BUFFER  |
;|---------------|0x60000
;|      USER     |
;|---------------|0x00500 + KERNEL_SIZE
;|     KERNEL    |
;|---------------|0x00500
;|   BIOS DATA   |
;|---------------|0x00400
;|      IVT      |
;|---------------|0x00000

ISR_SEGMENT	  equ 0x0000
KERNEL_SEGMENT equ 0x0050 ;IVT_SIZE + BIOS_DATA = 0x500 bytes, with considering
						  ;4 bits shift right segment for make address kernel
						  ;will be placed behind bios dat
;PROCESS_SEGMENT equ KERNEL_SEGMENT + ((KERNEL_SIZE + 1) / 16)
		;error: division operator may only be applied to scalar values
PROCESS_SEGMENT equ 0x1200
DISK_BUFFER	equ 0x6000
STACK_SEGMENT equ 0x8000

kernel:
;init stack segment & stack pointer
	mov		ax,		STACK_SEGMENT
	mov		ss,		ax
	mov		sp,		0xFFFF
;init data segment
	call	load_isr ;from load_isr return ax = KERNEL_SEGMENT
;	mov		ax,		KERNEL_SEGMENT
	mov		ds,		ax
	call	serial_init
.to_tty:
	call	tty_start
	jmp		0xFFFF:0000 ;reboot

last_exit_status dw 0
execve:
;in: ds:si = name of file
;	 ss:bp = args
;out:
;need load the fat12, found entry and load to bin to memory on PROCESS_SEGMENT
;kernel functions calls throught syscall 0x20, list in the kernel.inc
	call	fat12_find_entry
	cmp		ax,		FAT12_ENTRY_NOT_FOUND
	je		.not_found
	call	save_interrupts ;pit & keyboard
	push	es
	mov		si,		PROCESS_SEGMENT
	mov		es,		si
	xor		si,		si
	call	fat12_load_entry
	pop		es
;Now, file was load. Execute him
	mov		bp,		word[argv_ptr]
	mov		ax,		PROCESS_SEGMENT
	mov		ds,		ax
	call	PROCESS_SEGMENT:0x0000
	cli
	mov		word[last_exit_status],	ax
	mov		ax,		KERNEL_SEGMENT
	mov		ds,		ax
	call	restore_interrupts
	sti
	retn
.not_found:
	mov		word[last_exit_status],	FAT12_ENTRY_NOT_FOUND
	retn

%include "vga.asm"
%include "tty.asm"
%include "fs.asm"
%include "isr.asm"
%include "string.asm"
%include "random.asm"
%include "serial.asm"
%include "rtc.asm"

KERNEL_SIZE equ $
