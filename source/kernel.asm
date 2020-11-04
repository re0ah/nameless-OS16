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
	mov		si,		PROCESS_OFFSET
	call	fat12_load_entry
	mov		ax,		PROCESS_OFFSET
	mov		ds,		ax
	call	PROCESS_OFFSET:0x0000
	mov		ax,		KERNEL_OFFSET
	mov		ds,		ax
	xor		ax,		ax	;normal state exit
.end:
	retn

%include "tty.asm"
%include "fs.asm"
%include "isr.asm"

KERNEL_SIZE equ $
