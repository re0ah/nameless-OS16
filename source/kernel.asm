bits 16

ISR_SIZE	  equ 0x0400	;1KiB
ISR_OFFSET	  equ 0x0000
STACK_OFFSET  equ ISR_OFFSET + ISR_SIZE
KERNEL_OFFSET equ STACK_OFFSET + 0x1000
DISK_BUFFER	  equ 0x6000

kernel:
;init stack segment & stack pointer
	mov		ax,		STACK_OFFSET
	mov		ss,		ax
	mov		sp,		0xFFFF

	mov		ax,		KERNEL_OFFSET
	mov		ds,		ax

	call	load_isr
.to_tty:
	call	tty_start

	jmp		.to_tty

PROCESS_OFFSET equ KERNEL_OFFSET + KERNEL_SIZE
execve:
;in: ds:si = name of file
;	 ??? args? later
;out:
;need load the fat12, found entry and load to bin to memory on PROCESS_OFFSET
;also DOESN'T CHANGE SEGMENT
;kernel functions calls throught [KERNEL_OFFSET:FUNC_ADDR], list of the func
;															on the kernel.inc
	call	fat12_find_entry
	cmp		ax,		FAT12_ENTRY_NOT_FOUND
	je		.end
	call	save_interrupts
	push	es
	mov		si,		PROCESS_OFFSET
	mov		es,		si
	xor		si,		si
	call	fat12_load_entry
	pop		es
	mov		ax,		PROCESS_OFFSET
	mov		ds,		ax
	call	PROCESS_OFFSET:0x0000
	cli
	mov		ax,		KERNEL_OFFSET
	mov		ds,		ax
	call	restore_interrupts
	sti
	xor		ax,		ax	;normal state exit
.end:
	retn

%include "vga.asm"
%include "tty.asm"
%include "fs.asm"
%include "isr.asm"
%include "string.asm"
%include "random.asm"

KERNEL_SIZE equ $
