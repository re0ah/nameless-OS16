SYSCALL_VGA_CLEAR_SCREEN 	  equ 0x00 ;#0
SYSCALL_VGA_CURSOR_DISABLE	  equ 0x02 ;#1
SYSCALL_VGA_CURSOR_ENABLE	  equ 0x04 ;#2
SYSCALL_VGA_CURSOR_MOVE		  equ 0x06 ;#3
SYSCALL_TTY_PUTCHAR_ASCII	  equ 0x08 ;#4
SYSCALL_TTY_PRINT_ASCII		  equ 0x0A ;#5
SYSCALL_TTY_PRINT_ASCII_C	  equ 0x0C ;#6
SYSCALL_TTY_NEXT_ROW		  equ 0x0E ;#7
SYSCALL_FAT12_READ_ROOT	  	  equ 0x10 ;#8
SYSCALL_FAT12_FIND_ENTRY  	  equ 0x12 ;#9
SYSCALL_FAT12_LOAD_ENTRY  	  equ 0x14 ;#10
SYSCALL_FAT12_FILE_SIZE		  equ 0x16 ;#11
SYSCALL_FAT12_FILE_ENTRY_SIZE equ 0x18 ;#12
SYSCALL_PIT_SET_FREQUENCY 	  equ 0x1A ;#13
SYSCALL_PIT_GET_FREQUENCY 	  equ 0x1C ;#14
SYSCALL_GET_KEYBOARD_DATA	  equ 0x1E ;#15
SYSCALL_SCANCODE_TO_ASCII 	  equ 0x20 ;#16
SYSCALL_INT_TO_ASCII		  equ 0x22 ;#17
SYSCALL_UINT_TO_ASCII		  equ 0x24 ;#18
SYSCALL_SET_PIT_INT			  equ 0x26 ;#19
SYSCALL_SET_KEYBOARD_INT	  equ 0x28 ;#20
SYSCALL_GET_RAND_INT		  equ 0x2A ;#21
SYSCALL_SET_RAND_SEED		  equ 0x2C ;#22
SYSCALL_RTC_GET_SEC			  equ 0x2E ;#23
SYSCALL_RTC_GET_MIN			  equ 0x30 ;#24
SYSCALL_RTC_GET_HOUR		  equ 0x32 ;#25
SYSCALL_RTC_GET_DAY			  equ 0x34 ;#26
SYSCALL_RTC_GET_MONTH		  equ 0x36 ;#27
SYSCALL_RTC_GET_YEAR		  equ 0x38 ;#28
SYSCALL_RTC_GET_CENTURY		  equ 0x3A ;#29
SYSCALL_RTC_GET_WEEK		  equ 0x3C ;#30
SYSCALL_RTC_GET_ASCII_SEC	  equ 0x3E ;#31
SYSCALL_RTC_GET_ASCII_MIN	  equ 0x40 ;#32
SYSCALL_RTC_GET_ASCII_HOUR	  equ 0x42 ;#33
SYSCALL_RTC_GET_ASCII_DAY	  equ 0x44 ;#34
SYSCALL_RTC_GET_ASCII_MONTH	  equ 0x46 ;#35
SYSCALL_RTC_GET_ASCII_YEAR	  equ 0x48 ;#36
SYSCALL_RTC_GET_ASCII_CENTURY equ 0x4A ;#37
SYSCALL_RTC_GET_ASCII_WEEK	  equ 0x4C ;#38
SYSCALL_EXECVE				  equ 0x4E ;#39
