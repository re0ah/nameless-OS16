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
;|  DISK BUFFER  |       64KiB
;|---------------|0x60000
;|      USER     |
;|---------------|0x00500 + KERNEL_SIZE
;| KERNEL BUFFERS|
;|               |
;|     KERNEL    |
;|---------------|0x00500
;|   BIOS DATA   |
;|---------------|0x00400
;|      IVT      |
;|---------------|0x00000

ISR_SEGMENT	  equ 0x0000
KERNEL_SEGMENT equ 0x0050 ;IVT_SIZE + BIOS_DATA = 0x500 bytes, with considering
						  ;4 bits shift right segment for make address kernel
						  ;will be placed behind bios data
PROCESS_SEGMENT equ (KERNEL_SIZE_WITH_BUFFER / 16) + KERNEL_SEGMENT + 1
DISK_BUFFER	equ 0x6000
STACK_SEGMENT equ 0x8000

;.code segment
kernel:
;init stack segment & stack pointer
	push	STACK_SEGMENT
	pop		ss
	mov		sp,		0xFFFF
	call	load_isr
;init data segment
;from load_isr return ax = KERNEL_SEGMENT
;	mov		ax,		KERNEL_SEGMENT
	mov		ds,		ax
	call	serial_init
	call	vga_init

;	mov		si,		testfrom
;	mov		di,		testto
;	call	fat12_copy_file

;	mov		si,		testto
;	call	fat12_remove_file

	push	ds
	pop		fs
	mov		si,		testto2
	mov		bx,		testfromdata
	mov		cx,		8
	call	fat12_create_file
;	call	fat12_write_file

;	push	es

;	push	ds
;	pop		es
;	mov		si,		testfrom
;	mov		di,		test_data_file
;	call	fat12_load_file
;
;	pop		es
;
;	mov		si,		testto
;	mov		bx,		test_data_file
;	mov		cx,		TEST_DATA_FILE_SIZE
;	push	ds
;	pop		fs
;	call	fat12_create_file
;	mov		si,		testto2
;	mov		bx,		test_data_file
;	mov		cx,		1
;	call	fat12_create_file
;	mov		si,		testfrom
;	mov		di,		testto3
;	call	fat12_rename_file
.to_tty:
	call	tty_start
	jmp		0xFFFF:0000 ;reboot

testfrom db "SNAKE   BIN"
testto db "TESTTO  BIN"
testto2 db "TESTTESTBIN"
testto3 db "RENAMED BIN"
testfromdata db 0xBB, 0x00, 0x00, 0xCD, 0x20, 0x31, 0xC0, 0xCB

test_data_file times 1024 db 0
	TEST_DATA_FILE_SIZE equ $ - test_data_file

execve:
;in: ds:si = name of file
;	 ss:bp = args
;out:
;need load the fat12, found entry and load to bin to memory on PROCESS_SEGMENT
;kernel functions calls throught syscall 0x20, list in the kernel.inc
	push	es
	push	PROCESS_SEGMENT
	pop		es
	xor		di,		di
	call	fat12_load_file
	pop		es
	cmp		ax,		FAT12_ENTRY_NOT_FOUND
	je		.not_found
	call	save_interrupts ;pit & keyboard
;Now, file was load. Execute him
	mov		bp,		word[argv_ptr]
	push	PROCESS_SEGMENT
	pop		ds
	call	PROCESS_SEGMENT:0x0000
	cli
	push	KERNEL_SEGMENT
	pop		ds
	mov		word[last_exit_status],	ax
	call	restore_interrupts
	sti
	retn
.not_found:
	mov		word[last_exit_status],	FAT12_ENTRY_NOT_FOUND
return_from_function:
	retn

%include "vga.asm"
%include "tty.asm"
%include "fs.asm"
%include "isr.asm"
%include "string.asm"
%include "random.asm"
%include "serial.asm"
%include "rtc.asm"
%include "pit.asm"
%include "keyboard.asm"




;.data segment
;vga
vga_space:
		  db 0x20
vga_color db 0x07 ;bg: black, fg: gray

vga_bytes_in_row db 160

;tty
HELLO_MSG db "namelessOS16 v 9", 0x0A, 0x00
HELLO_MSG_SIZE equ $-HELLO_MSG

PROGRAM_NOT_FOUND db 0x0A, "program not found", 0x00
PROGRAM_NOT_FOUND_SIZE equ $-PROGRAM_NOT_FOUND

pre_path_now	db '[\]: ', 0

;fs
sector_size		dw 512

;isr
pit_interrupt_handler dw pit_int
pit_interrupt_segment dw KERNEL_SEGMENT
keyboard_interrupt_handler dw keyboard_int
keyboard_interrupt_segment dw KERNEL_SEGMENT

syscall_jump_table:
    dw      _interrupt_vga_clear_screen     ;#0
    dw      vga_cursor_disable              ;#1
    dw      vga_cursor_enable               ;#2
    dw      _interrupt_vga_cursor_move      ;#3
    dw      _interrupt_tty_putchar_ascii    ;#4
    dw      _interrupt_tty_print_ascii      ;#5
    dw      _interrupt_tty_print_ascii_c    ;#6
    dw      _interrupt_tty_next_row         ;#7
    dw      fat12_read_root                 ;#8
    dw      fat12_find_entry                ;#9
    dw      fat12_load_entry                ;#10
    dw      fat12_load_file                 ;#11
    dw      fat12_file_size                 ;#12
    dw      fat12_file_entry_size           ;#13
    dw      fat12_create_file               ;#14
    dw      fat12_remove_entry              ;#15
    dw      fat12_remove_file               ;#16
    dw      fat12_copy_file                 ;#17
    dw      fat12_rename_file               ;#18
    dw      fat12_write_file                ;#19
    dw      _interrupt_pit_set_frequency    ;#20
    dw      _interrupt_pit_get_frequency    ;#21
    dw      _interrupt_get_keyboard_input   ;#22
    dw      _interrupt_scancode_to_ascii    ;#23
    dw      _interrupt_int_to_ascii         ;#24
    dw      _interrupt_uint_to_ascii        ;#25
    dw      _interrupt_set_pit_int          ;#26
    dw      _interrupt_set_keyboard_int     ;#27
    dw      _interrupt_rand_int             ;#28
    dw      _interrupt_set_rand_seed        ;#29
    dw      rtc_get_data_bcd                ;#30
    dw      rtc_get_data_bin                ;#31
    dw      bcd_to_number                   ;#32
    dw      set_timezone_utc                ;#33
    dw      get_timezone_utc                ;#34
    dw      _interrupt_execve               ;#35

;string
FAT12_STR_ONLY_BIN db "BIN" ;READ ONLY!

;random
rand_int_seed dw 1

;pit
pit_frequency dw PIT_DEFAULT_FREQUENCY / 32

;keyboard
kb_buf_ptr_write dw kb_buf
kb_buf_ptr_read  dw kb_buf



BSS_START equ KERNEL_SIZE + 1
;.bss segment
;kernel main
;last_exit_status dw 0
last_exit_status equ BSS_START

;vga
;vga_pos_cursor  dw 0
vga_pos_cursor equ last_exit_status + 2
;vga_memory_size dw 0
vga_memory_size equ vga_pos_cursor + 2
;vga_offset_now dw 0
vga_offset_now equ vga_memory_size + 2

;tty
;argv_ptr dw 0
argv_ptr equ vga_offset_now + 2
;tty_input_start dw 0
tty_input_start equ argv_ptr + 2
;tty_input_end dw 0
tty_input_end equ tty_input_start + 2

;fs
;fat12_write_file_size   	dw 0
fat12_write_file_size equ tty_input_end + 2
;fat12_write_file_cluster    dw 0
fat12_write_file_cluster equ fat12_write_file_size + 2
;fat12_write_file_count      dw 0
fat12_write_file_count equ fat12_write_file_cluster + 2
;fat12_write_file_location   dw 0
fat12_write_file_location equ fat12_write_file_count + 2
;fat12_write_file_clusters_needed    dw 0
fat12_write_file_clusters_needed equ fat12_write_file_location + 2
;fat12_write_file_filename   dw 0
fat12_write_file_filename equ fat12_write_file_clusters_needed + 2
;fat12_write_file_free_clusters  times 128 dw 0
fat12_write_file_free_clusters equ fat12_write_file_filename + 2

;string
;num_to_ascii_buf times 6 db " "
num_to_ascii_buf equ fat12_write_file_free_clusters + 256
;FAT12_STR times 11 db 0
FAT12_STR equ num_to_ascii_buf + 6
FAT12_STRLEN equ 11
FAT12_STRLEN_WITHOUT_EXT equ 8
FAT12_EXT equ FAT12_STR + 8

;serial
;COM1_BUFFER times 512 db 0 
COM1_BUFFER equ FAT12_STR + 11
COM1_BUFFER_SIZE equ 512
;com1_buffer_pos dw 0
com1_buffer_pos equ COM1_BUFFER + COM1_BUFFER_SIZE

;rtc
;timezone_utc db 0
timezone_utc equ com1_buffer_pos + 2

;keyboard
KB_BUF_SIZE   equ 64
;kb_buf        times KB_BUF_SIZE db 0
kb_buf        equ timezone_utc + 1
KB_BUF_END	 equ kb_buf + KB_BUF_SIZE
;kb_led_status db 0
kb_led_status equ KB_BUF_END + 1
;kb_shift_pressed db 0
kb_shift_pressed equ kb_led_status + 1


BSS_SIZE equ kb_shift_pressed + 1








KERNEL_SIZE equ 4495
BUFFERS_SIZE equ BSS_SIZE
KERNEL_SIZE_WITH_BUFFER equ KERNEL_SIZE + BUFFERS_SIZE
